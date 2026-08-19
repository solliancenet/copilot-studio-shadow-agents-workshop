#!/usr/bin/env bash
#
# setup-env.sh — stand up a fully-isolated, ENFORCED clone of the Halcourt Mutual
# Claims Triage estate in its own azd environment (RG rg-<env>).
#
# The infra is env-isolated by design: resourceToken = uniqueString(sub, env, location)
# (infra/main.bicep) and RG = rg-<env>, so a new env name yields all-new global names.
# But two enforcement pieces live OUTSIDE Bicep and are keyed per-env; this script
# reproduces them so a clone comes up ENFORCED, not open:
#
#   1. The Entra app registration (appId -> azd env var API_APP_ID) that fronts the
#      member API. Empty API_APP_ID leaves /api/* UNAUTHENTICATED (src/Program.cs).
#   2. The Claims.Read app-role grant to the Foundry ACCOUNT's system-assigned MI —
#      the OpenAPI managed-identity caller. Claims.Read only => agent reads succeed,
#      the write (PUT status) is refused 401 at the RBAC layer.
#
# Then it re-creates the prompt-agent (foundry/create_new_agent.py) against the new
# project with the new App ID URI as the OpenAPI audience.
#
# Idempotent and safe to re-run. Prints what it does. Requires: az (logged in), azd,
# and the foundry/.venv (or python with azure-ai-projects / azure-identity).
#
# Usage:
#   ./infra/setup-env.sh                 # env name defaults to mmdev
#   ENV_NAME=mmstage ./infra/setup-env.sh
#   ./infra/setup-env.sh mmstage         # env name as first positional arg
#   SKIP_AGENT=1 ./infra/setup-env.sh    # provision estate but skip the Foundry agent step
#
set -uo pipefail

# --- Resolve azd (falls back to ~/.azd/bin, matching the provisioning host). ---
if ! command -v azd >/dev/null 2>&1; then
  export PATH="$HOME/.azd/bin:$PATH"
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE"

ENV_NAME="${1:-${ENV_NAME:-mmdev}}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-6aa3be9e-6130-409f-882c-cdc4e4816a36}"
LOCATION="${AZURE_LOCATION:-westus3}"
APP_DISPLAY_NAME="Halcourt Mutual Member API (${ENV_NAME})"

echo "=================================================================="
echo " Halcourt Mutual — stand up ENFORCED clone"
echo "   env:          ${ENV_NAME}   (RG rg-${ENV_NAME})"
echo "   subscription: ${SUBSCRIPTION_ID}"
echo "   location:     ${LOCATION}"
echo "   app reg:      ${APP_DISPLAY_NAME}"
echo "=================================================================="

fail() { echo "ERROR: $*" >&2; exit 1; }

# ----------------------------------------------------------------------------------
# 1. azd environment
# ----------------------------------------------------------------------------------
echo
echo "[1/6] azd environment '${ENV_NAME}'"
if azd env list -o json 2>/dev/null | grep -q "\"Name\": *\"${ENV_NAME}\""; then
  echo "  env exists — selecting it"
  azd env select "${ENV_NAME}"
else
  echo "  creating env"
  azd env new "${ENV_NAME}" --subscription "${SUBSCRIPTION_ID}" --location "${LOCATION}" \
    || fail "azd env new failed"
fi
azd env set AZURE_SUBSCRIPTION_ID "${SUBSCRIPTION_ID}"
azd env set AZURE_LOCATION "${LOCATION}"
azd env select "${ENV_NAME}"

SELECTED="$(azd env get-value AZURE_ENV_NAME 2>/dev/null || true)"
[ "${SELECTED}" = "${ENV_NAME}" ] || fail "selected env is '${SELECTED}', expected '${ENV_NAME}' — refusing to continue"
echo "  selected env confirmed: ${SELECTED}"

# ----------------------------------------------------------------------------------
# 2. Entra app registration + service principal (idempotent by display name)
# ----------------------------------------------------------------------------------
echo
echo "[2/6] app registration '${APP_DISPLAY_NAME}'"

# App roles (both Application-only, enabled). Stable per-env GUIDs so re-runs don't churn.
CLAIMS_READ_ID="$(uuidgen | tr 'A-Z' 'a-z')"
CLAIMS_WRITE_ID="$(uuidgen | tr 'A-Z' 'a-z')"

APP_ID="$(az ad app list --filter "displayName eq '${APP_DISPLAY_NAME}'" --query "[0].appId" -o tsv 2>/dev/null || true)"

if [ -n "${APP_ID}" ] && [ "${APP_ID}" != "null" ]; then
  echo "  reusing existing app registration appId=${APP_ID}"
else
  APP_ROLES_JSON="$(cat <<JSON
[
  {"allowedMemberTypes":["Application"],"description":"Read claims data","displayName":"Claims.Read","id":"${CLAIMS_READ_ID}","isEnabled":true,"value":"Claims.Read"},
  {"allowedMemberTypes":["Application"],"description":"Write claim status","displayName":"Claims.Write","id":"${CLAIMS_WRITE_ID}","isEnabled":true,"value":"Claims.Write"}
]
JSON
)"
  ROLES_FILE="$(mktemp)"
  echo "${APP_ROLES_JSON}" > "${ROLES_FILE}"
  echo "  creating app registration"
  APP_ID="$(az ad app create --display-name "${APP_DISPLAY_NAME}" \
    --sign-in-audience AzureADMyOrg \
    --app-roles "@${ROLES_FILE}" \
    --query appId -o tsv)" || fail "az ad app create failed"
  rm -f "${ROLES_FILE}"
  echo "  created appId=${APP_ID}"
fi

# Identifier URIs — api://<appId> and api://<appId>/agent (both accepted as token audiences).
echo "  ensuring identifier URIs api://${APP_ID} and api://${APP_ID}/agent"
az ad app update --id "${APP_ID}" \
  --identifier-uris "api://${APP_ID}" "api://${APP_ID}/agent" \
  || fail "failed to set identifier URIs"

# Service principal (idempotent).
if [ -z "$(az ad sp show --id "${APP_ID}" --query id -o tsv 2>/dev/null || true)" ]; then
  echo "  creating service principal"
  az ad sp create --id "${APP_ID}" >/dev/null || fail "az ad sp create failed"
else
  echo "  service principal already exists"
fi

azd env set API_APP_ID "${APP_ID}"
azd env set API_APP_URI "api://${APP_ID}/agent"
echo "  API_APP_ID=${APP_ID} recorded in azd env"

# ----------------------------------------------------------------------------------
# 3. Provision the estate (Bicep: RG, ACR, Container App w/ auth, Foundry, App Insights + connection)
# ----------------------------------------------------------------------------------
echo
echo "[3/6] azd provision"
azd provision || fail "azd provision failed (STOP — check the error; do not thrash regions)"

# Resolve the deterministic resource token / Foundry account from azd outputs.
FOUNDRY_ACCOUNT="$(azd env get-value AZURE_AI_FOUNDRY_PROJECT 2>/dev/null | sed 's/^proj-/aif-/')"
RESOURCE_TOKEN="${FOUNDRY_ACCOUNT#aif-}"
RG="rg-${ENV_NAME}"
echo "  resourceToken=${RESOURCE_TOKEN}  foundryAccount=${FOUNDRY_ACCOUNT}  rg=${RG}"

# ----------------------------------------------------------------------------------
# 4. Grant Claims.Read to the Foundry ACCOUNT's system-assigned MI (idempotent)
# ----------------------------------------------------------------------------------
echo
echo "[4/6] grant Claims.Read to Foundry account MI"

MI_OID="$(az cognitiveservices account show -n "${FOUNDRY_ACCOUNT}" -g "${RG}" \
  --query "identity.principalId" -o tsv 2>/dev/null || true)"
[ -n "${MI_OID}" ] || fail "could not resolve Foundry account MI principalId for ${FOUNDRY_ACCOUNT}"

API_SP_OID="$(az ad sp show --id "${APP_ID}" --query id -o tsv)" || fail "could not resolve API SP object id"
READ_ROLE_ID="$(az ad sp show --id "${APP_ID}" \
  --query "appRoles[?value=='Claims.Read'].id | [0]" -o tsv)"
[ -n "${READ_ROLE_ID}" ] || fail "could not resolve Claims.Read app role id"

echo "  accountMI=${MI_OID}  apiSP=${API_SP_OID}  Claims.Read=${READ_ROLE_ID}"

EXISTING="$(az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/servicePrincipals/${MI_OID}/appRoleAssignments" \
  --query "value[?appRoleId=='${READ_ROLE_ID}' && resourceId=='${API_SP_OID}'] | [0].id" -o tsv 2>/dev/null || true)"

if [ -n "${EXISTING}" ] && [ "${EXISTING}" != "null" ]; then
  echo "  Claims.Read already granted (assignment ${EXISTING}) — skipping"
else
  echo "  creating appRoleAssignment"
  az rest --method POST \
    --url "https://graph.microsoft.com/v1.0/servicePrincipals/${MI_OID}/appRoleAssignments" \
    --headers "Content-Type=application/json" \
    --body "{\"principalId\":\"${MI_OID}\",\"resourceId\":\"${API_SP_OID}\",\"appRoleId\":\"${READ_ROLE_ID}\"}" \
    >/dev/null || fail "failed to grant Claims.Read"
  echo "  granted."
fi

# ----------------------------------------------------------------------------------
# 5. Deploy the web app (real image from src/Dockerfile)
# ----------------------------------------------------------------------------------
echo
echo "[5/6] azd deploy web"
azd deploy web || fail "azd deploy web failed"

# ----------------------------------------------------------------------------------
# 6. Create the prompt-agent against the NEW project (idempotent-ish: re-versions)
# ----------------------------------------------------------------------------------
echo
echo "[6/6] create/version the Claims-Triage prompt agent"

# The identity that runs create_new_agent.py (DefaultAzureCredential -> the signed-in
# az user) must hold a Foundry DATA-PLANE authoring role on the new account, else
# agents/write returns 403. "Foundry User" carries dataAction Microsoft.CognitiveServices/*
# (which includes .../agents/write) and is the same role the working demo account uses —
# least-privilege match. A fresh account has NO assignments, so grant it here (idempotent).
SIGNED_IN_OID="$(az ad signed-in-user show --query id -o tsv 2>/dev/null || true)"
if [ -n "${SIGNED_IN_OID}" ]; then
  DEV_ACC_ID="$(az cognitiveservices account show -n "${FOUNDRY_ACCOUNT}" -g "${RG}" --query id -o tsv)"
  if [ -z "$(az role assignment list --assignee "${SIGNED_IN_OID}" --scope "${DEV_ACC_ID}" \
        --query "[?roleDefinitionName=='Foundry User'] | [0].id" -o tsv 2>/dev/null)" ]; then
    echo "  granting 'Foundry User' (data-plane authoring) to ${SIGNED_IN_OID} on ${FOUNDRY_ACCOUNT}"
    az role assignment create --assignee "${SIGNED_IN_OID}" --role "Foundry User" \
      --scope "${DEV_ACC_ID}" -o none || fail "failed to grant Foundry User to the authoring identity"
    echo "  granted — waiting 60s for data-plane RBAC to propagate"
    sleep 60
  else
    echo "  authoring identity already has 'Foundry User' on ${FOUNDRY_ACCOUNT}"
  fi
fi

if [ "${SKIP_AGENT:-0}" = "1" ]; then
  echo "  SKIP_AGENT=1 — skipping the Foundry agent step"
else
  # Export the NEW env's values so create_new_agent.py targets the new project + audience.
  # The script reads these from the environment (with mmdemo fallbacks it will NOT hit here).
  export AZURE_AI_FOUNDRY_PROJECT="$(azd env get-value AZURE_AI_FOUNDRY_PROJECT)"
  export AZURE_AI_FOUNDRY_PROJECT_ENDPOINT="$(azd env get-value AZURE_AI_FOUNDRY_PROJECT_ENDPOINT)"
  export AZURE_OPENAI_MODEL="$(azd env get-value AZURE_OPENAI_MODEL)"
  export WEB_URI="$(azd env get-value WEB_URI)"
  export API_APP_ID="${APP_ID}"
  export API_APP_URI="api://${APP_ID}/agent"

  echo "  project endpoint: ${AZURE_AI_FOUNDRY_PROJECT_ENDPOINT}"
  echo "  openapi audience: ${API_APP_URI}"
  echo "  app base URL:     ${WEB_URI}"

  PY="${HERE}/foundry/.venv/bin/python"
  [ -x "${PY}" ] || PY="python3"
  "${PY}" "${HERE}/foundry/create_new_agent.py" || fail "create_new_agent.py failed"
fi

echo
echo "=================================================================="
echo " DONE — ${ENV_NAME} is up and ENFORCED."
echo "   RG:              rg-${ENV_NAME}"
echo "   resourceToken:   ${RESOURCE_TOKEN}"
echo "   Foundry account: ${FOUNDRY_ACCOUNT}"
echo "   Web URL:         $(azd env get-value WEB_URI 2>/dev/null)"
echo "   API_APP_ID:      ${APP_ID}"
echo "=================================================================="
echo "Verify: anonymous /api/claims -> 401; reads -> 200 / PUT -> 403"
echo "  (foundry/verify_rbac.py against this env's project endpoint)"

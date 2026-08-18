#!/usr/bin/env bash
#
# cleanup-demo.sh — fully tear down the Meridian Mutual Claims Triage demo.
#
# Idempotent and safe to re-run. It removes, in order:
#   1. All Azure resources in the azd environment  (azd down --force --purge)
#      --purge also purges the soft-deleted AIServices / Foundry account, which would
#      otherwise block re-provisioning under the same name.
#   2. The API app registration + its service principal   (az ad app delete)
#      read from the azd env var API_APP_ID. Deleting the app registration also removes
#      the app-role assignments (Claims.Read) that reference it.
#   3. Any orphaned app-role assignments left on the Foundry managed identities.
#   4. A confirmation pass that no soft-deleted Cognitive Services / Foundry account remains.
#
# It PRINTS what it will delete before doing so. Requires: az (logged in), azd.
#
# Usage:
#   ./infra/cleanup-demo.sh            # tear everything down
#   DRY_RUN=1 ./infra/cleanup-demo.sh  # print what would be deleted, change nothing
#
set -uo pipefail

# Resolve azd (falls back to ~/.azd/bin, matching the provisioning host).
if ! command -v azd >/dev/null 2>&1; then
  export PATH="$HOME/.azd/bin:$PATH"
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$HERE"

DRY_RUN="${DRY_RUN:-0}"
run() {
  echo "  \$ $*"
  if [ "$DRY_RUN" = "1" ]; then return 0; fi
  "$@"
}

echo "=================================================================="
echo " Meridian Mutual demo teardown"
echo " repo:   $HERE"
[ "$DRY_RUN" = "1" ] && echo " MODE:   DRY RUN (no changes will be made)"
echo "=================================================================="

# --- Read identifiers from the azd env BEFORE azd down removes the environment values. ---
API_APP_ID="$(azd env get-value API_APP_ID 2>/dev/null || true)"
SUB_ID="$(azd env get-value AZURE_SUBSCRIPTION_ID 2>/dev/null || true)"
ENV_NAME="$(azd env get-value AZURE_ENV_NAME 2>/dev/null || echo mmdemo)"
RG="rg-${ENV_NAME}"

echo
echo "Will delete:"
echo "  - azd environment '${ENV_NAME}' and its resource group '${RG}' (all resources, purged)"
echo "  - API app registration:  ${API_APP_ID:-<none recorded>}"
echo "  - orphaned Claims.Read / Claims.Write app-role assignments referencing it"
echo

# --- 1. azd down: delete + purge every Azure resource, including soft-deleted Foundry. ---
echo "[1/4] azd down --force --purge"
run azd down --force --purge

# --- 2. Delete the API app registration (removes its SP + app-role assignments). ---
echo "[2/4] delete API app registration"
if [ -n "${API_APP_ID}" ]; then
  if az ad app show --id "${API_APP_ID}" >/dev/null 2>&1; then
    run az ad app delete --id "${API_APP_ID}"
    echo "  deleted app registration ${API_APP_ID}"
  else
    echo "  app registration ${API_APP_ID} not found (already deleted) — skipping"
  fi
else
  echo "  no API_APP_ID recorded in the azd env — nothing to delete"
fi

# --- 3. Sweep any orphaned app-role assignments on the Foundry managed identities. ---
# These reference the API SP; deleting the app reg above normally removes them, but if the
# app reg was already gone we still clear stragglers by resource (the API SP appId).
echo "[3/4] sweep orphaned app-role assignments on Foundry identities"
if [ -n "${API_APP_ID}" ]; then
  API_SP_OID="$(az ad sp show --id "${API_APP_ID}" --query id -o tsv 2>/dev/null || true)"
  if [ -n "${API_SP_OID}" ]; then
    # For each Foundry-related MI SP, delete assignments whose resourceId is the API SP.
    for MI in $(az ad sp list --filter "startswith(displayName,'aif-')" --query "[].id" -o tsv 2>/dev/null); do
      for AID in $(az rest --method GET \
            --url "https://graph.microsoft.com/v1.0/servicePrincipals/${MI}/appRoleAssignments" \
            --query "value[?resourceId=='${API_SP_OID}'].id" -o tsv 2>/dev/null); do
        echo "  removing assignment ${AID} on MI ${MI}"
        run az rest --method DELETE \
          --url "https://graph.microsoft.com/v1.0/servicePrincipals/${MI}/appRoleAssignments/${AID}"
      done
    done
  else
    echo "  API SP already gone — assignments removed with the app registration"
  fi
else
  echo "  no API_APP_ID — skipping assignment sweep"
fi

# --- 4. Confirm no soft-deleted Cognitive Services / Foundry account blocks re-provision. ---
echo "[4/4] confirm no soft-deleted Foundry accounts remain"
if [ -n "${SUB_ID}" ]; then
  LEFT="$(az cognitiveservices account list-deleted --query "[?resourceGroup=='${RG}'].name" -o tsv 2>/dev/null || true)"
  if [ -n "${LEFT}" ]; then
    echo "  WARNING: soft-deleted Cognitive Services accounts still present: ${LEFT}"
    echo "  purge each with: az cognitiveservices account purge -g ${RG} -n <name> -l <location>"
  else
    echo "  none — clean."
  fi
fi

echo
echo "Teardown complete${DRY_RUN:+ (dry run)}."
# [verify] Foundry per-agent Entra "Agent IDs" (new prompt-agent identities): as of this build
# they live inside the Foundry project and are removed when the project/account is deleted in
# step 1 (they are not separate Entra app registrations, so there is nothing to delete here). If a
# future Foundry release externalizes them as Entra objects, add an explicit cleanup pass.

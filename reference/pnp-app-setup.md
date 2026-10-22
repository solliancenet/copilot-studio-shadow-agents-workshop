# Registering the PnP app

Once per tenant. Every estate shares the app ([ADR-0016](adr/0016-pnp-app-registration.md)); RUNBOOK →
Phase 4 step 1 checks whether it already exists. Run these in the dev container terminal, signed in to `az`
as the global admin.

## 1. The app and its delegated permissions

PnP 3.x ships no shared sign-in app. This creates `Halcourt PnP` (or reuses it), adds delegated SharePoint
`AllSites.FullControl` and Graph `Group.ReadWrite.All`, and grants admin consent:

```bash
APP=$(az ad app list --display-name "Halcourt PnP" --query "[0].appId" -o tsv)
[ -z "$APP" ] && APP=$(az ad app create --display-name "Halcourt PnP" --sign-in-audience AzureADMyOrg \
  --is-fallback-public-client true --public-client-redirect-uris http://localhost --query appId -o tsv)
az ad app permission add --id $APP --api 00000003-0000-0ff1-ce00-000000000000 \
  --api-permissions "$(az ad sp show --id 00000003-0000-0ff1-ce00-000000000000 \
    --query "oauth2PermissionScopes[?value=='AllSites.FullControl'].id | [0]" -o tsv)=Scope"      # SharePoint
az ad app permission add --id $APP --api 00000003-0000-0000-c000-000000000000 \
  --api-permissions "$(az ad sp show --id 00000003-0000-0000-c000-000000000000 \
    --query "oauth2PermissionScopes[?value=='Group.ReadWrite.All'].id | [0]" -o tsv)=Scope"       # Graph: team sites are M365 groups
az ad sp show --id $APP >/dev/null 2>&1 || az ad sp create --id $APP
az ad app permission admin-consent --id $APP
echo "ENTRAID_APP_ID=$APP"
```

## 2. The app-only roles

Three application roles (SharePoint `Sites.FullControl.All` and `User.ReadWrite.All`, Graph
`Group.ReadWrite.All`) let the Phase 4 and 4b seeds run headlessly; the delegated grant also gets
`User.ReadWrite.All` for Phase 4b's interactive provisioning. The certificate is RUNBOOK Phase 4 step 2 —
each facilitator adds their own.

```bash
SP=00000003-0000-0ff1-ce00-000000000000            # SharePoint Online
GRAPH=00000003-0000-0000-c000-000000000000         # Microsoft Graph
PNP_SP=$(az ad sp show --id $APP --query id -o tsv)
SP_SP=$(az ad sp show --id $SP --query id -o tsv)
GRAPH_SP=$(az ad sp show --id $GRAPH --query id -o tsv)
for ROLE in 678536fe-1083-478a-9c59-b99265e6b0d3 741f803b-c850-494e-b5df-cde7c675a1ca; do   # Sites.FullControl.All, User.ReadWrite.All
  az rest --method POST --url "https://graph.microsoft.com/v1.0/servicePrincipals/$PNP_SP/appRoleAssignments" \
    --body "{\"principalId\":\"$PNP_SP\",\"resourceId\":\"$SP_SP\",\"appRoleId\":\"$ROLE\"}" -o none
done
# Graph Group.ReadWrite.All (application) — app-only site create needs it (team sites are M365 groups).
az rest --method POST --url "https://graph.microsoft.com/v1.0/servicePrincipals/$PNP_SP/appRoleAssignments" \
  --body "{\"principalId\":\"$PNP_SP\",\"resourceId\":\"$GRAPH_SP\",\"appRoleId\":\"62a82d76-70ea-41e2-9197-370581804d09\"}" -o none
# DELEGATED User.ReadWrite.All too — the interactive admin provisioning (Phase 4b) needs it in the user token.
GID=$(az rest --method GET --url "https://graph.microsoft.com/v1.0/oauth2PermissionGrants?\$filter=clientId eq '$PNP_SP' and resourceId eq '$SP_SP'" --query 'value[0].id' -o tsv)
az rest --method PATCH --url "https://graph.microsoft.com/v1.0/oauth2PermissionGrants/$GID" \
  --body '{"scope":"AllSites.FullControl User.ReadWrite.All"}' -o none
```

{: .warning }
> `az ad app permission admin-consent` did **not** create the **application** grants on the verified
> tenant — grant them with the `appRoleAssignments` POSTs above and verify with
> `az rest --method GET --url .../servicePrincipals/$PNP_SP/appRoleAssignments`. Fresh grants take a few
> minutes to reach a new token, so a 403 right after granting usually just means "too soon".

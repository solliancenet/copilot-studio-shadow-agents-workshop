# Retiring the shared resources (after the last estate)

RUNBOOK → Phase 9 tears down one estate and leaves everything estates share. Remove these only when no
estate in the tenant still needs them; each one, removed early, breaks every remaining estate.

## The shared Azure deployment (Phase 1)

**Shared Azure deployment — owner only, after the last estate.** Tearing it down breaks every estate's
agents, so do it only when no estate still needs it:

```bash
azd env select <shared env name>   # from the repo root
azd down --purge --force
rm setup/lab-endpoints.local.json  # and ask facilitators to delete their copies
```

If it has to be rebuilt while estates still use it, use a **new** azd environment name, write the new
values file (`Save-LabEndpoints -Force`: it refuses to replace different values otherwise), hand it out, and
have every estate re-run Phase 6: the agents' `${…}` action tokens
re-inject the new addresses and secrets at provision time.

## Tenant-wide grants and apps

- **Shared grants 07 and 04b leave in place** (tenant-wide, shared by every estate - remove only when
      no estate needs them): Graph Explorer's all-users consent (`$GraphExplorerScopes`) -
      `az rest --method DELETE --url https://graph.microsoft.com/v1.0/oauth2PermissionGrants/<id>` (find the
      id with `oauth2PermissionGrants?$filter=clientId eq '<Graph Explorer service principal id>'`); and unified
      audit ingestion, which is best left on.
- **Shared per-tenant, only when the last estate in the tenant goes:** the app registration
      `halcourt-lab-compliance` (03c, 07 and 07b sign in with it) with its local
      `setup/lab-compliance-app.local.{json,pfx}`, and the resource group `rg-halcourt-graph-billing` holding
      its Graph billing resource `halcourt-lab-compliance-billing`. `azd down` does not touch either.

- **The PnP app registration and the shared authors group:** with your last estate's teardown, run
  `pwsh setup/scripts/99_teardown.ps1 -RemovePersonas -RemoveShared` instead of RUNBOOK Phase 9 step 6.
  It also removes `Halcourt-Copilot-Authors` and the `Halcourt PnP` app registration (Phase 4); delete
  every facilitator's local `setup/pnp.local.*` too.

## The Copilot Studio billing plan

- **Shared per-region, only when the tenant is retired:** the Copilot Studio billing plan and, if
      the kit created it, its resource group. Deleting either cuts billing for every estate in the region.
      First check that `/billingPolicies/<id>/environments` lists no live environment, for every plan in
      the group, then remove the group's `halcourt-shared-billing` lock (`az lock delete --name
      halcourt-shared-billing -g <group> --subscription <that id>`), then PPAC → Licensing → Billing Plans →
      delete. A plan the kit created is `Halcourt-PAYG-<region>` in `rg-halcourt-billing`, in the plan's
      own subscription (its `billingInstrument.subscriptionId`). Once
      `az resource list -g rg-halcourt-billing --subscription <that id>` is empty:
      `az group delete -n rg-halcourt-billing --subscription <that id>`. A plan the tenant came with
      (e.g. `ppccdevcanada`) lives in the Dev Program's own resource group, which also holds the default
      environment's plan — leave that group alone, but remove the kit's lock from it (`az lock delete --name
      halcourt-shared-billing -g <group> --subscription <that id>`). A tenant built before ADR-0014's
      shared names may also hold `rg-halcourt-billing-<estate>` with a `Halcourt-PAYG-<estate>` plan: retire
      it the same way.

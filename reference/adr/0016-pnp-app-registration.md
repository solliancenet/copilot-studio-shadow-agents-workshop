# ADR-0016: PnP gets its own app registration, with delegated and application permissions

**Status:** Accepted
**Applies to:** `setup/RUNBOOK.md` → Phase 4 and 4b, `setup/scripts/03_provision_sharepoint.ps1`,
`03b_provision_onedrive.ps1`

## Context

PnP.PowerShell 3.x ships no shared sign-in app, so the tenant needs one. `az` can register it, allow device
codes on it and grant admin consent without a sign-in prompt, but `az` can't run the seed itself:
SharePoint accepts tokens issued for the Azure CLI's app but rejects them (401).

## Decision

Register one PnP app per tenant, shared by every estate, carrying **two** sets of permissions because the
kit uses it two ways:

- **Delegated** (`AllSites.FullControl`, Graph `Group.ReadWrite.All`, `User.ReadWrite.All`) — the
  interactive device-code/browser seed, and the admin-side OneDrive provisioning in Phase 4b.
- **Application**, plus a certificate (SharePoint `Sites.FullControl.All` and `User.ReadWrite.All`, Graph
  `Group.ReadWrite.All`) — the headless app-only runs: the Phase 4 seed (`03 -CertPath`) and the Phase 4b
  OneDrive *seed*. Graph `Group.ReadWrite.All` is there because the Phase 4 team sites are M365 groups
  created via Graph; without it the app-only site create returns 403.

## Consequences

- One more app registration and certificate per tenant, shared by every estate (listed in
  [ADR-0001](0001-estates.md)'s shared items).
- App-only can *seed* a OneDrive but cannot *provision* one ([ADR-0017](0017-maker-provisions-own-onedrive.md)).

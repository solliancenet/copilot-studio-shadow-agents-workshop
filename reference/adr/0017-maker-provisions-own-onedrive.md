# ADR-0017: The maker provisions their own OneDrive

**Status:** Accepted (`[verify]` — best effort)
**Applies to:** `setup/RUNBOOK.md` → Phase 4b, `setup/scripts/03b_provision_onedrive.ps1`

## Context

The **Meeting Notes Summarizer** decoy grounds on Dev Kim's own OneDrive notes, so his OneDrive must exist
and hold his notes before that agent is built. A Dev Program sandbox does not auto-provision a user's
OneDrive reliably.

The admin side can't enqueue it headlessly (all verified 2026-09-22):

- **App-only** is refused — *"Attempted to perform an unauthorized operation"* — even with every
  application grant; it wants a *user context*, not a permission.
- **The Azure CLI's** delegated token is **401 for every SharePoint tenant-admin call**, even as Global
  Admin.
- **A freshly created SharePoint Administrator** signs in but is still refused: SharePoint doesn't honour a
  new role assignment for 15–60 min.

Full trail: errata, *Phase 4b · why OneDrive provisioning resists automation*.

## Decision

`03b_provision_onedrive.ps1` signs in **as Dev** with the lab password and calls `GET /me/drive`, which
answers `ResourceNotFound` and can enqueue the personal site behind it. Personas are ordinary users, so
nothing in the CA baseline blocks the password grant. The script waits; seeding is then app-only with the
PnP certificate ([ADR-0016](0016-pnp-app-registration.md)).

## Consequences

- **Not guaranteed.** On the verified tenant this created Dev's site within a minute, but produced nothing
  for another persona 47 minutes later on identical licensing. First-access provisioning is asynchronous
  with no SLA. If the site never appears, the script fails and tells you to provision that one maker by
  hand and re-run, which then just seeds.
- **Don't use Graph to check readiness.** `GET /users/<upn>/drive` kept returning `ResourceNotFound` for Dev
  *after* his OneDrive existed and had been written to. The script probes the personal site with PnP.

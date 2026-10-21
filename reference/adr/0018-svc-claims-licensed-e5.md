# ADR-0018: `svc-claims` is licensed, and E5 is enough

**Status:** Accepted
**Applies to:** `setup/RUNBOOK.md` → Phase 5, `setup/scripts/04_provision_dataverse.ps1`;
[ADR-0009](0009-eight-licences-per-estate.md)

## Context

A security role can only be assigned to a Dataverse user record, and Dataverse creates one only for an
Entra account that is enabled **and licensed**
([requirements](https://learn.microsoft.com/power-platform/admin/create-users#requirements-for-successfully-adding-users-in-dataverse)).
The exceptions — admin roles, non-interactive accounts, app-pass capacity — don't fit a service account, so
an unlicensed `svc-claims` is refused (*userNotLicensed*). Without the role, Claims Copilot's shared
connection can't read the claims data, and Scenarios C (the over-broad role) and D (the agent exercising
svc-claims's authority instead of the caller's) have nothing to show.

## Decision

License `svc-claims` with E5. E5 — including the sandbox's `DEVELOPERPACK_V2_E5` — carries a free Dataverse
plan (`DYN365_CDS_O365_P3`). Dataverse honours that plan only when a user is added **on demand** (the admin
API or PPAC), not by the background sync; `04_provision_dataverse.ps1`'s add is on demand. No Power Apps or
Dynamics 365 licence is needed. `Claims-Test-<estate>` has no security group, so the licence is the only
gate.

## Consequences

- One of the estate's eight seats ([ADR-0009](0009-eight-licences-per-estate.md)).

## Alternatives considered

- **Non-interactive access mode, to get the seat back.** License `svc-claims`, run Phase 5, set its
  **Access Mode** to **Non-interactive** (PPAC → the environment → Users → svc-claims → *Manage user in
  Dynamics 365* → Administration), then remove the licence. Up to seven per environment. **[verify]** that
  Claims Copilot's connection still works as a non-interactive account before relying on it.

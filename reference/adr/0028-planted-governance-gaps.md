# ADR-0028: DLP on Prod only, and no Conditional Access for agent identities

**Status:** Accepted
**Applies to:** `setup/RUNBOOK.md` → Phase 3, `setup/scripts/02_provision_environments_dlp.ps1`,
`00_conditional_access_baseline.ps1`; Exercise 05 (Tasks 05-01, 05-02, 05-04)

## Context

Exercise 05 tests whether Microsoft's controls close the estate's problems. It needs gaps for those
controls to find: environments with no data policy, and agent identities no Conditional Access policy
covers.

## Decision

- **One DLP policy, on Prod only.** `Halcourt-Prod-DLP-<estate>` puts Dataverse, SharePoint, Office 365
  Outlook and Office 365 Users in the **business** group (business-by-default, so agents publish), scoped
  to this estate's `Halcourt-Prod` only. HTTP and custom connectors are **not** blocked at the start, so
  Scenario E fires; the facilitator blocks them during 05-01 and restores afterwards.
- **No DLP on `Halcourt (default)`, `Claims-Test-<estate>` or `Maker-Sandbox-<estate>`.** That gap is what
  05-01 and 05-02 find.
- **No Conditional Access policy targets workload or agent identities.** That is the policy 05-04 has
  attendees specify. The Phase 0 baseline covers admin MFA and legacy auth only
  ([ADR-0010](0010-ca-baseline-replaces-security-defaults.md)).

## Consequences

- Never "fix" these gaps while building or testing an estate; Exercise 05 has nothing to show without them.
- The Exercise 05 demonstrations change and restore the DLP side (`09_ex05_demo_state.ps1`); the agent CA
  policy is specified, never created.

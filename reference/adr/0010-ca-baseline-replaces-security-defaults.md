# ADR-0010: A Conditional Access baseline replaces security defaults

**Status:** Accepted
**Applies to:** `setup/RUNBOOK.md` → Phase 0 step 4, `setup/scripts/00_conditional_access_baseline.ps1`,
`AGENTS.md` → Conditional Access baseline

## Context

Security defaults are the right setting for a real small tenant, but they make this workshop painful to
build and to run:

- **They block device-code sign-in.** Device codes are the sign-in the dev container scripts use
  ([ADR-0011](0011-device-code-sign-in-and-org-consent.md)). Security defaults reject every device-code
  sign-in with *AADSTS530035* and take no exceptions — not even for the build admin.
- **They put every persona through MFA registration.** Every account must register for MFA and is then
  prompted whenever Entra decides. The build signs in as the personas to author agents and own connections
  (Phase 6), and attendees sign in too. Each account would need its own authenticator on someone's phone,
  and a surprise prompt mid-demo stalls the room.
- **They lock out Conditional Access.** Enabled Conditional Access policies can't coexist with security
  defaults, and the estate needs two; Module 5 tests Conditional Access against the canon in `AGENTS.md`.

## Decision

Turn security defaults off and create two Conditional Access policies instead:

| Policy | Applies to | Control |
|---|---|---|
| `CA-Require-MFA-Admins` | 15 admin roles — Microsoft's *Require MFA for admins* set, plus Power Platform Administrator | Require MFA |
| `CA-Block-Legacy-Auth` | All users | Block legacy clients |

If creating a policy fails, the script rolls back and turns security defaults back on, so admins are never
left without MFA.

## Consequences

- It keeps the two protections that matter here: MFA on every admin role, and no legacy authentication.
- It gives up MFA for ordinary accounts and security defaults' risk-based prompts — acceptable **only**
  because this is an isolated lab tenant holding fictitious data. Never do this to a production tenant.
- Two gaps are deliberate: no policy targets workload/agent identities (a Module 5 finding), and none
  blocks device-code flow (the build needs it). If Microsoft later adds a managed policy that restricts
  authentication flows, the script's summary warns — exclude the build admin from it.
- Phase 8b excludes attendee accounts from `CA-Require-MFA-Admins` ([ADR-0024](0024-attendees-are-power-platform-admins.md)).

## Alternatives considered

- **Keep security defaults.** Every sign-in moves to a desktop browser, every persona needs MFA enrollment,
  and Module 5 has no Conditional Access to test.

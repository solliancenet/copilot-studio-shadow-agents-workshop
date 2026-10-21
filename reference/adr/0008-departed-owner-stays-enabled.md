# ADR-0008: The departed owner stays enabled; his departure is a leave date

**Status:** Accepted
**Applies to:** `setup/RUNBOOK.md` → Phase 2 and Phase 6.5, `setup/scripts/01_provision_entra.ps1`
(`-MarkDepartedOwner`)

## Context

Tom Dean is the departed admin who owns Onboarding Guide and Sales Nudge — the orphaned-agent scenario.
The obvious way to model a leaver is to disable the account. But Entra refuses a disabled user's token
refresh (AADSTS50057), so disabling Tom kills the shared connections his agents run on, and the orphan
stops working. The real-world problem being taught is a leaver whose account nobody shut down.

## Decision

Tom stays **enabled**, always. After his shared connections exist (Phase 6), Phase 6.5 re-runs
`01_provision_entra.ps1 -MarkDepartedOwner`, which stamps his Entra leave date (`employeeLeaveDateTime`) —
the record that says he has gone — and leaves the account and its connections live.

The leave date needs no extra Graph scope when the `az` sign-in is reused: its token carries
`Directory.AccessAsUser.All`, which covers it for a Global Administrator (verified 2026-10-19). Asking for
`User-LifeCycleInfo.*` would force a device-code sign-in on every run, because the `az` token never carries
it.

## Consequences

- Never disable Tom, in any phase or demonstration. Disabling him breaks Onboarding Guide and Sales Nudge.
- Attendees find the departure in the leave date, not in the account state — which is how a missed
  offboarding looks.

## Alternatives considered

- **Disable or delete Tom.** Realistic offboarding, but it breaks the agents the scenario depends on.
- **No leave date.** The orphan would be indistinguishable from an active owner.

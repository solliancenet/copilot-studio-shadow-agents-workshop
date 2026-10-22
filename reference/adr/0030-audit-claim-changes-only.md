# ADR-0030: Audit claim changes only; no read logs

**Status:** Accepted (found 2026-10-20)
**Applies to:** `setup/RUNBOOK.md` → Phase 5b, `setup/scripts/04b_provision_audit.ps1`; Lab 05-07

## Context

05-07 reconstructs Exercise 04 from the logs, and a log only holds what happened after it was switched on.
A developer tenant ships with all of it off — Purview Audit included, despite being documented as on by
default.

## Decision

`04b_provision_audit.ps1` turns on:

| What | Where it shows in 05-07 |
|---|---|
| Purview Audit: unified audit log ingestion (up to **60 minutes** to start recording) | `CopilotInteraction` events (KT02, KT04, KT05) |
| `Claims-Test-<estate>`: environment auditing | the environment's audit settings (KT01) |
| `mm_claim`: change auditing | the Audit summary view (KT03) |

- **`mm_customer` stays unaudited.** Attendees read these records, and a logged customer change would carry
  SSN and date of birth into the audit view.
- **Read logs stay off.** Reads reach Purview only for production environments, and `Claims-Test` is a
  sandbox, so there is nothing to turn on. KT03 finds no read in the audit summary — which is the point it
  teaches.

## Consequences

- Run it at least an hour before Exercise 04, well before — on the build day.
- It needs Phase 4c's lab app ([ADR-0029](0029-purview-app-only-identity.md)) and Phase 5's tables.

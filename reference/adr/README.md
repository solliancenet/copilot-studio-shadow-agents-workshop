# Architecture decision records

One decision per file, numbered in the order they were written. Each record says what was decided, why,
and what it costs. The [RUNBOOK](../../setup/RUNBOOK.md) stays a list of steps and links here for the why.

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-estates.md) | Every live build is an estate, and every name it creates carries the estate id | Accepted |
| [0002](0002-shared-vs-individual-estates.md) | Attendees share one estate; facilitators build individual estates | Accepted (open questions) |
| [0003](0003-project-local-sign-in.md) | CLI sign-ins live in the repo, not your home folder | Accepted |
| [0004](0004-one-licence-per-attendee.md) | One Microsoft 365 E5 licence per attendee | Accepted (licensing open) |
| [0005](0005-shared-azure-deployment.md) | One shared Azure deployment for every estate | Proposed |

New phase-by-phase decisions still live in [`../runbook-decisions.md`](../runbook-decisions.md); they move
here as each RUNBOOK phase is made lean.

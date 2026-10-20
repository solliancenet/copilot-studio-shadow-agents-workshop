# Test run log

Walkthrough of the workshop from `setup/RUNBOOK.md` through every exercise. Each entry: what was done,
result (OK / issue / blocked), and anything wrong with the instructions.

Run started: 2026-10-20 · Estate id: _(pick one)_ · Tenant: _(record)_

## Runbook

| Phase | Status | Notes |
|---|---|---|
| 0. Tenant | not started | |
| 1. Azure infra | | |
| 2. Entra identities | | |
| 3. Environments + DLP | | |
| 4 / 4b / 4c. SharePoint, OneDrive, Purview | | |
| 5. Dataverse seed | | |
| 6. Author agents | | |
| 7. Export artifact pack | | |
| 8 / 8b / 8c. Validate, lab accounts, slices | | |

## Exercises

| Exercise | Status | Notes |
|---|---|---|
| 00 Lab environment | | |
| 01 The agent estate | | |
| 02 Discover and inventory | | |
| 03 Identity and effective access | | |
| 04 Break the agents | | |
| 05 Test the controls | | |
| 06 Security baseline | | |

## Log

_(entries appended below as we go)_

### Runbook intro and "Estates: several builds in one tenant" (before Phase 0)

**Feedback, not yet acted on.** This material is architecture notes and facilitator briefing. It does not
define discrete steps an operator can execute, so it doesn't belong in the runbook. Proposed: move it to
its own document. Covers:

- the opening paragraphs (shared demo tenant, attendee lab accounts, Jordan Blake as offline stand-in,
  artifact pack as offline fallback and the Phase 7 caveat),
- the "deliberately broken / isolated tenant" warning,
- the whole "Estates" section: the canonical vs live naming table, shared-not-renamed items, the
  `_estate.ps1` rule. The one operator action inside it (choose an id, check it is unused, set
  `HALCOURT_ESTATE`) is a real step and would stay in the runbook as a numbered step.

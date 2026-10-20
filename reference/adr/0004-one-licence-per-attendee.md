# ADR-0004: One Microsoft 365 E5 licence per attendee

**Status:** Accepted (licensing still open — [PLANNING item 15](../../PLANNING.md))
**Applies to:** `setup/RUNBOOK.md` → Phase 8b, `setup/scripts/07_provision_lab_users.ps1`,
`setup/scripts/00b_preflight.ps1`

## Context

**A Microsoft 365 licence (E5) per attendee is a delivery requirement**, not a nice-to-have. Without one, an
attendee loses the tenant route of Exercise 04 (Teams refuses them, so they cannot chat with the published
agents), produces no `CopilotInteraction` audit events for 05-07, and runs Dataverse in Administrative mode
([tenant capabilities](../tenant-capabilities.md)). That attendee works those tasks from the artifact pack. Plan the delivery around the seats
you have: up to 14 in the build tenant (Phase 8b), so size `-Attendees` / `-Count` to the seats available,
not to the room. No separate Copilot Studio licence is needed; chatting with a published agent draws on
tenant capacity. Licensing is documented here, not automated: 07 attempts an assignment and reports who
got one. Open item: [PLANNING item 15](../../PLANNING.md).

Verified 2026-10-17 with three accounts holding the identical access model: the one with an E5 seat
(`accessmode=0`) opened the PPAC role editor and the Copilot Studio agent pages; the two without
(`accessmode=1`, Administrative) were refused. Administrative access mode filters a custom role's
privileges.

## Decision

Every attendee lab account gets a Microsoft 365 E5 licence. A delivery is sized to the free E5 seats, not to
the room: `-Attendees` and `-Count` are the number of seats available.

## Consequences

- An unlicensed attendee works Exercise 04's chat, 05-07 KT02 and the Dataverse pages from the artifact
  pack, and 05-07 KT02 has no offline substitute.
- `07_provision_lab_users.ps1` tries to assign a licence and reports who got one; it does not fail without.
- No separate Copilot Studio licence is needed.

## Alternatives considered

- **Unlicensed accounts.** Free, but Teams refuses them and Dataverse runs in Administrative mode.
- **Grant System Administrator instead.** It survives Administrative mode, but gives every attendee write
  access to the shared estate ([ADR-0002](0002-shared-vs-individual-estates.md)).

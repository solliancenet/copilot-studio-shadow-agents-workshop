# ADR-0026: Attendee teardown purges, not just deletes

**Status:** Accepted
**Applies to:** `setup/scripts/07_provision_lab_users.ps1 -Destroy`, `setup/RUNBOOK.md` → Phase 8b and 9

## Context

Deleting a user only **soft**-deletes it: it sits in `directory/deletedItems` for 30 days holding its UPN
and `mailNickname`, so the next delivery's `student01.<estate>` would collide with the last one's. A
soft-deleted `Lab-Students-<estate>` group still holds its `mailNickname` too, so the next delivery couldn't
recreate it, and the Conditional Access exclusion would point at a group nobody can see.

## Decision

`-Destroy` removes the Conditional Access exclusion first, then deletes **and purges** the accounts and the
group, in that order — the same lesson Phase 9 learned about sites and groups.

## Consequences

- A destroyed delivery leaves nothing behind to collide with; there is no 30-day undo.

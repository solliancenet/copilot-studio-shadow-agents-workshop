# ADR-0002: Attendees share one estate; facilitators build individual estates

**Status:** Superseded in part (2026-10-22). Matt decided on an estate per person: one per attendee
(`stu01`–`stu20`) and one per facilitator (`fac01`–`fac03`), built by `10_build_estates.ps1 -ReclaimSeats`
([#30](https://github.com/solliancenet/copilot-studio-shadow-agents-workshop/issues/30)). "A delivery uses
one shared estate" no longer holds. Whether Exercise 05 stays demonstrated is still open: 05-02's DLP lands
on the one default environment every estate shares, so it collides across attendees. A replacement record
is due once that is settled.
**Applies to:** `setup/RUNBOOK.md` intro, Phase 8b, the Exercise 05 demo table; `index.md` prerequisites

## Context

[ADR-0001](0001-estates.md) lets several estates live in one tenant. That leaves who gets one: each
facilitator, or each attendee.

An estate is expensive — eight E5 seats, three Dataverse environments and their capacity, Azure Container
Apps, SharePoint sites, and a multi-hour build. Exercise 04 (BREAK) and Exercise 05 (CONTROL) need a live
estate; the rest of the workshop can run from the artifact pack.

## Decision

- **Individual estates are per facilitator.** Each facilitator who builds Halcourt Mutual builds their own
  estate under their own id, in a shared training tenant.
- **A delivery uses one shared estate.** All attendees in a delivery work against the facilitator's estate.
  They sign in with native lab accounts (Phase 8b) and use their own lab account as the low-privilege
  requester; Jordan Blake is only the offline stand-in for that requester.
- **Exercise 05 is demonstrated.** On a shared estate one attendee's change is everyone's result (sixteen
  people applying and undoing the same DLP policy on top of each other). The facilitator applies each
  control once, live, and restores it; attendees retest. Decided by Matt, 2026-10-19 — errata
  *Delivery · Exercise 05 is demonstrated*.
- **The artifact pack is the fallback.** The five CSVs in `worksheets/artifact-pack/` are exported from an
  estate so every task can be completed offline if the tenant is unavailable; the tenant is the preferred
  path. The committed pack is canonical — see Phase 7 before regenerating it.

## Consequences

- Attendees hold no write role in the estate; `09_ex05_demo_state.ps1` snapshots and restores what a
  script can, and the RUNBOOK lists the portal-only reversals.
- Each attendee needs a Dataverse-capable licence (E5) on their lab account — the shared estate's access
  model.
- One bad change by the facilitator affects the whole room, so Exercise 05 restores after every control.

## Alternatives considered

- **An individual estate per attendee.** Attendees could apply controls themselves, but sixteen estates
  means sixteen times the licences, capacity and build time.
- **No live estate — artifact pack only.** Cheapest, but Exercise 04 and 05 lose the live break and retest.

## Open questions

The estate concept was introduced by Matt; this record is reconstructed from the RUNBOOK, `AGENTS.md` and
the errata. Confirm with him:

- Is "individual estate" meant as per facilitator (as written here) or as something else?
- Can two facilitators deliver from the same tenant at the same time, each with their own room on their own
  estate?

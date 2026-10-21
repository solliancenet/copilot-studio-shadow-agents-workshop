# ADR-0025: Attendee licence assignment is best effort

**Status:** Accepted
**Applies to:** `setup/scripts/07_provision_lab_users.ps1`; [ADR-0004](0004-one-licence-per-attendee.md)

## Context

A Dev Program sandbox carries **25** E5 seats. Each estate needs eight
([ADR-0009](0009-eight-licences-per-estate.md)), and the content pack's sample users can hold most of the
rest until freed (Phase 0 step 3). On the build tenant `subscribedSkus` once reported
`DEVELOPERPACK_V2_E5` at **25/25 consumed**, so every attendee account came out unlicensed.

## Decision

`07_provision_lab_users.ps1` checks seat availability up front, attempts assignment per account, never
treats a failure as fatal, and prints who got one. Every account gets `usageLocation` stamped from the
tenant's country, because a licence can't be assigned without one — so freeing seats later and re-running
is enough.

## Consequences

- Provisioning attendees never fails for lack of seats; the attendees without one lose what
  [ADR-0004](0004-one-licence-per-attendee.md) lists and work from the artifact pack.
- Entra reads and the `/scopes/admin/` Power Platform calls work unlicensed (verified).
- `FLOW_FREE` (10,000 seats) is available if some surface merely requires *a* licence to be present.

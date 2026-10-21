# ADR-0009: Eight E5 licences per estate

**Status:** Accepted
**Applies to:** `setup/RUNBOOK.md` → Phase 2 (licence step), Phase 5, Phase 6

## Context

Dataverse only adds **licensed** users to an environment. The agents' owners and the account behind the
shared Dataverse connection must be in their environments, or Phases 5 and 6 can't build them. A Dev Program
sandbox has 25 E5 seats.

## Decision

Each estate licenses eight accounts with E5:

| Account | Needed by |
|---|---|
| `svc-claims` | Phase 5 — its shared Dataverse connection |
| `marcus.webb`, `priya.nair`, `lena.ford`, `dev.kim`, `tom.dean`, `sam.olsen`, `it.helpdesk` | Phase 6 — they own the agents |

`ana.reyes` and `jordan.blake` stay unlicensed. `01_provision_entra.ps1` assigns the tenant's E5
(`DEVELOPERPACK_V2_E5`, `SPE_E5` or `ENTERPRISEPREMIUM`, or `-LicenceSku`) to the eight, skipping any that
already hold it, and sets a usage location first where one is missing (Exchange creates `it.helpdesk`
without one). Running out of seats is reported, not fatal. `-SkipLicences` leaves licensing alone.

## Consequences

- Two estates use 16 of a sandbox's 25 seats, leaving few for attendees
  ([ADR-0004](0004-one-licence-per-attendee.md)). Content-pack sample users must give theirs up (Phase 0,
  step 3).
- A short tenant fails in Phase 5 or 6, not Phase 2 — check free seats before Phase 2.

## Alternatives considered

- **License every persona.** Costs two more seats per estate for no exercise that needs them.

# ADR-0014: Estates share one billing plan per region

**Status:** Accepted
**Applies to:** `setup/RUNBOOK.md` → Phase 3, `setup/scripts/02b_provision_billing.ps1`

## Context

A pay-as-you-go billing plan is region-locked and is just an Azure meter; each environment's usage is
reported separately. Agents **publish** without any plan; a plan is what lets attendees actually send them
messages.

## Decision

Estates in one tenant share a plan per region. `02b_provision_billing.ps1` looks for an existing plan in
the environments' region before creating one, and links the estate's `Halcourt-Prod` and `Claims-Test`.

`Maker-Sandbox` is not linked: it is a Developer environment, billing plans take production and sandbox
environments only, and its agents publish and run without a plan.

## Consequences

- No per-estate plan to create or clean up; usage is still visible per environment.
- A plan only lists environments in its own region; an environment missing from the picker means the
  regions don't match (errata → Phase 3).
- Doing it by hand: [billing plan by hand](../billing-plan-by-hand.md).

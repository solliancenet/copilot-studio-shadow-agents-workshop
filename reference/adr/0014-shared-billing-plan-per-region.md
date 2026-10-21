# ADR-0014: Estates share one billing plan per region

**Status:** Accepted
**Applies to:** `setup/RUNBOOK.md` → Phase 3 and Phase 9, `setup/scripts/02b_provision_billing.ps1`,
`99_teardown.ps1`, `08_provision_student_slices.ps1`

## Context

A pay-as-you-go billing plan is region-locked and is just an Azure meter; each environment's usage is
reported separately. Agents **publish** without any plan; a plan is what lets attendees actually send them
messages.

## Decision

Estates in one tenant share a plan per region. `02b_provision_billing.ps1` looks for an existing plan in
the environments' region before creating one, and links the estate's `Halcourt-Prod` and `Claims-Test`.

The plan is a **shared resource**, like the default environment: no estate owns it, so nothing about it
carries an estate id. It reuses whatever plan the region already has, by any name — a Dev Program tenant
may come with one (`ppccdevcanada` in its own `rg-<number>` group). One it creates is named for the region:
resource group `rg-halcourt-billing`, account `ppcc-halcourt-<region>`, plan `Halcourt-PAYG-<region>`.
Estate teardown only **unlinks** the estate's environments; the plan and its resource group go only when
the tenant is retired.

`Maker-Sandbox` is not linked: it is a Developer environment, billing plans take production and sandbox
environments only, and its agents publish and run without a plan.

## Consequences

- No per-estate plan to create or clean up; usage is still visible per environment.
- Deleting the plan, or its resource group, cuts billing for **every** estate in the region. An earlier
  version of the script named both after the estate that ran first (`rg-halcourt-billing-<estate>`,
  `Halcourt-PAYG-<estate>`), so tidying one estate's resource groups by hand could do exactly that.
- A plan only lists environments in its own region; an environment missing from the picker means the
  regions don't match (errata → Phase 3).
- Doing it by hand: [billing plan by hand](../billing-plan-by-hand.md).

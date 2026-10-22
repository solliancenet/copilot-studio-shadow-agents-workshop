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
may come with one (`ppccdevcanada` in its own `rg-<number>` group). One it creates carries no estate id:
resource group `rg-halcourt-billing`, account `ppcc-halcourt-<region>`, plan `Halcourt-PAYG-<region>`.
Estate teardown only **unlinks** the estate's environments; the plan and its resource group go only when
the tenant is retired. The script tags the plan's resource group `halcourt-shared` and puts a
**CanNotDelete** lock on it (`halcourt-shared-billing`), whatever the group is called: a generated name like
`rg-1783938851676-6ff6f7f6` says nothing about the workshop, so it is the easiest group to delete by mistake.
The lock was chosen over moving the plan into `rg-halcourt-billing`, which would mean recreating it and
relinking every estate, an outage for all of them (issue #27).

`Maker-Sandbox` is not linked: it is a Developer environment, billing plans take production and sandbox
environments only, and its agents publish and run without a plan.

## Consequences

- No per-estate plan to create or clean up; usage is still visible per environment.
- The plan is also what lets a tenant hold more than two estates: Phase 3 creates Prod and Claims-Test on it,
  so their Dataverse storage bills to Azure instead of reserving the tenant's capacity (errata → Phase 3,
  2026-10-22).
- Deleting the plan, or its resource group, cuts billing for **every** estate in the region. An earlier
  version of the script named both after the estate that ran first (`rg-halcourt-billing-<estate>`,
  `Halcourt-PAYG-<estate>`), so tidying one estate's resource groups by hand could do exactly that.
- A plan only lists environments in its own region; an environment missing from the picker means the
  regions don't match (errata → Phase 3).
- Doing it by hand: [billing plan by hand](../billing-plan-by-hand.md).

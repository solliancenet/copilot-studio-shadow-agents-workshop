# ADR-0013: Environments take the region the platform assigns

**Status:** Accepted
**Applies to:** `setup/RUNBOOK.md` → Phase 3, `setup/scripts/02_provision_environments_dlp.ps1`,
`02b_provision_billing.ps1`

## Context

The Power Platform environment API no longer accepts a country. It requires a **macro region**
(`-MacroRegion`, default `north-america`) and assigns the country itself: `location` alone is rejected
(*MacroRegionRequired*), and a specific `azureRegion` is ignored.

## Decision

Pass only the macro region and accept the region the platform assigns. The verified tenant got **Canada**
for every environment.

## Consequences

- The assigned region must be consistent within an estate: the script warns if an estate's environments
  land in different regions.
- The billing plan must follow whatever region the Phase 3 summary reports
  ([ADR-0014](0014-shared-billing-plan-per-region.md)).

# ADR-0015: The *Copilot Studio authors* tenant setting is optional

**Status:** Accepted
**Applies to:** `setup/RUNBOOK.md` → Phase 3

## Context

Microsoft documents the *Copilot Studio authors* tenant setting as how pay-as-you-go makers get into
Copilot Studio. On the verified tenant, an unlicensed persona opened Copilot Studio in a linked environment
without it. The setting has no API.

## Decision

Don't require it. If you want it: PPAC → **Manage → Tenant settings → Copilot Studio authors** → pick one
tenant-wide security group, e.g. `Halcourt-Copilot-Authors` (it exists on the verified tenant).

## Consequences

- It is one setting for the whole tenant, so every estate adds its agent owners to that one group rather
  than pointing the setting at its own.

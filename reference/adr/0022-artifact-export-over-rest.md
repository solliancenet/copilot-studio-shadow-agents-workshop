# ADR-0022: The artifact-pack export reads over REST with the az sign-in

**Status:** Accepted
**Applies to:** `setup/RUNBOOK.md` → Phase 7, `setup/scripts/05_export_artifact_pack.ps1`

## Context

The export used to drive `Microsoft.PowerApps.Administration.PowerShell`, whose `Add-PowerAppsAccount`
needs `System.Windows.Forms` and dies on Linux — so it needed the Windows build VM.

## Decision

Read the same data over REST with `az`'s sign-in, like Phases 3, 5 and teardown. It runs in the dev
container.

## Consequences

- The admin needs a security role in **every** Dataverse environment, because the agent inventory reads
  each environment's `bot` table. Without one the read fails with *"has not been assigned any roles"* (403).
  Environments the admin created in Phase 3 already have it; a **Developer** environment does not, because
  its owner is its only System Administrator.

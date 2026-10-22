# ADR-0012: The azd environment name is unique per estate

**Status:** Superseded by [ADR-0005](0005-shared-azure-deployment.md) — Phase 1 now runs once per lab, not per estate. The naming rule below still applies to that one deployment.
**Applies to:** `setup/RUNBOOK.md` → Phase 1, `infra/main.bicep`

## Context

azd derives the whole deployment from the environment name: the resource group is `rg-<name>`, and every
resource name — the registry, the Foundry account and project, the three Container Apps — comes from a
token computed from subscription + environment name + region (`infra/main.bicep`).

Two deployments with the same name in the same subscription and region are therefore the *same*
resources: the second `azd up` redeploys the first facilitator's apps and replaces their Policy API key and
MCP bearer, silently breaking every agent built against them. Reusing the name of a torn-down deployment
fails differently — the Foundry soft-delete trap (errata → Phase 1).

## Decision

Name each estate's environment `halcourt-<estate>-lab`; add a suffix (`-2`, a date) when you rebuild. Pass
`--subscription` and `--location` explicitly — otherwise azd falls back to its global defaults
(`azd config get defaults`), which can point at a subscription outside the lab tenant.

Under ADR-0005 there is one deployment, so the rule becomes: give it a name nobody has used in the
subscription. A second `azd up` under the shared deployment's name replaces its secrets and breaks every
estate's agents.

## Consequences

- Estates never overwrite each other's endpoints or secrets.
- Every estate pays for its own deployment and quota — what ADR-0005 proposes to change.
- `eastus2` is tested; any region with gpt-5-mini (GlobalStandard) quota works.

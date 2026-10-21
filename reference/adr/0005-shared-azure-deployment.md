# ADR-0005: One shared Azure deployment for every estate

**Status:** Proposed — not implemented yet ([issue #26](https://github.com/solliancenet/copilot-studio-shadow-agents-workshop/issues/26))
**Applies to:** `setup/RUNBOOK.md` → Phase 1, Phase 9; `setup/scripts/06_provision_agents.ps1`,
`00b_preflight.ps1`, `99_teardown.ps1`; [ADR-0001](0001-estates.md) → shared items

## Context

Phase 1 runs `azd up` once per estate, under `halcourt-<estate>-lab`
([ADR-0012](0012-azd-environment-per-estate.md)). Every estate gets its own resource group,
registry, Container Apps environment, Foundry account and gpt-5-mini deployment. Two estates in the build
subscription already have one each (`rg-halcourt-mgray-lab-1021`, `rg-halcourt-jcounts-lab`).

The workshop's agents use only two of the deployed apps — the Policy API and the Underwriting MCP server —
and only four values from them: `POLICY_API_FQDN`, `POLICY_API_KEY`, `UNDERWRITING_MCP_FQDN`, `MCP_BEARER`.
Phase 6 substitutes those into the agents.

Checked 2026-10-21:

- **The apps are estate-neutral.** `setup/infra/policy-api/server.js` and
  `setup/infra/mcp-underwriting/server.js` serve fixed lab data and check one static secret each. Neither
  knows about estates or tenants.
- **No exercise changes them.** 04-05 calls them; 05-01 and 05-04 reason about the static key and bearer.
  No Exercise 05 demonstration touches Azure, and no task reads the Container App logs.
- **They don't use Entra.** The endpoints are public and authenticate with static secrets, so they work from
  any estate in any tenant.

## Decision

The facilitator who owns the lab runs Phase 1 **once**. Every estate's agents point at that one
deployment, using the same four values.

- One named owner. Only the owner redeploys or tears it down.
- The secrets stay fixed for the life of the deployment.
- A facilitator building an estate gets the four values from the owner instead of running `azd up`.

## Consequences

- Saves a deployment's time and Foundry quota per estate. A facilitator building an estate needs no Azure
  role at all.
- Every estate shares one Policy API key. Scenario E exposes that key to attendees by design and it guards
  only lab data, so sharing it adds no exposure.
- **Redeploying with new secrets, or tearing down, breaks every estate** until each re-runs Phase 6. Hence
  one owner and fixed secrets.
- Container App logs mix every estate's traffic. No task reads them.

Changes this needs (tracked in the issue):

1. `06_provision_agents.ps1` reads the four values from `azd env get-values`, i.e. the facilitator's own
   gitignored `.azure/`. It needs another source: parameters, or a gitignored values file.
2. Phase 9 and `99_teardown.ps1` tell every facilitator to `azd down --purge --force`. Estate teardown must
   stop doing that; removing the shared deployment becomes the owner's separate step.
3. `00b_preflight.ps1` checks `rg-halcourt-<estate>-lab`. It should check the shared endpoints instead
   (each answers 401 without its secret).
4. RUNBOOK Phase 1 becomes "get the four values"; the owner's `azd up` moves to a once-per-lab section.
   ADR-0001's shared items and ADR-0012 is marked superseded.
5. Existing estates: pick one deployment as the shared one, re-run Phase 6 for the other estate with its
   values, then `azd down` the spare.

## Alternatives considered

- **Keep one deployment per estate** (today). Independent, but every estate pays the time and quota, and
  each needs an Azure role in the subscription.

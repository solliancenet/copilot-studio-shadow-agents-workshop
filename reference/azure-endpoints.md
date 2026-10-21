# The Phase 1 Container App addresses

Reference for [RUNBOOK → Phase 1](../setup/RUNBOOK.md#phase-1--azure-infrastructure-shared).

`azd env get-values` reports `POLICY_API_FQDN` / `UNDERWRITING_MCP_FQDN` (and the owner copies them into
`setup/lab-endpoints.local.json` for every other facilitator — [ADR-0005](adr/0005-shared-azure-deployment.md)). Despite the names they are full
URLs, scheme included — `https://ca-policyapi-<token>.<env-id>.<region>.azurecontainerapps.io` and
`https://ca-underwritingmcp-<token>.<env-id>.<region>.azurecontainerapps.io`, where `<env-id>` is the
Container Apps environment's generated name (e.g. `politestone-503df790`). These default
`*.azurecontainerapps.io` addresses — no custom domain, no DNS to configure — are what the agents' actions
point at: the host part (drop `https://`) is the `<policy-api-fqdn>` / `<mcp-fqdn>` in
`agent-authoring-guide.md`.

`azd up` deploys the entire project, but the workshop's agents use only the two weak apps. The demo web
app's member API (`/api/*`) returns **500** on this path — it needs the Entra app registration that
`infra/setup-env.sh` creates (`API_APP_ID`). Run that script only if you want the Foundry web demo.

The **static API key** the owner sets here is the one that ends up in Policy Lookup Bot's HTTP action config.
That exposure is the point of Scenario E.

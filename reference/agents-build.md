# What Phase 6 builds

`06_provision_agents.ps1` builds all ten agents (eight planted + two decoys) per `AGENTS.md`, each **as its
owner** in the environment it names, by replaying the committed `setup/agents/<slug>/` workspaces
(RUNBOOK → Phase 6; how: [ADR-0020](adr/0020-agents-provisioned-clone-first.md),
[ADR-0021](adr/0021-planted-mechanisms-in-topics.md)).

## Owners and their environment roles

The engine adds each owner to its environment with this role, and turns on `it.helpdesk`'s sign-in first
(Exchange creates shared mailboxes disabled, and Dataverse won't add a disabled user).

| Environment | Owner and role |
|---|---|
| `Halcourt-Prod-<estate>` | Marcus, Priya, Lena, `it.helpdesk`: **Environment Maker** · Tom: **System Administrator** — the departed admin's broad CRM reach behind Sales Nudge |
| `Claims-Test-<estate>` | Priya, `svc-claims`: **Environment Maker** — `svc-claims` creates its own Dataverse connection there |
| `Maker-Sandbox-<estate>` | Dev — already **System Administrator** of his own Developer environment |
| `Halcourt (default)` | Sam, Tom: **Environment Maker** |

## How each agent reaches its tools

| Agent | Tool mechanism |
|---|---|
| Benefits Buddy, HR FAQ v2 | SharePoint knowledge (no tool) |
| Team Wiki | connector tool (Graph search) · Meeting Notes: OneDrive knowledge |
| Sales Nudge, Onboarding Guide, Claims Copilot | connector tools (`InvokeConnectorTaskAction`) |
| Policy Lookup Bot | topic + `HttpRequestAction` (hard-coded key) |
| Underwriting Assistant | topics + `InvokeMcpTool` (get_quote / get_risk_score / run_query) |
| Expense Helper | flow (`workflow` record) + topic `InvokeFlowAction` |

## Connections

Each connection in `worksheets/artifact-pack/connections-export.csv` is created by the persona it names,
in the environment it names — e.g. `svc-claims` creates `DV-Claims-Shared` in `Claims-Test-<estate>`.
**OAuth connections can't be shared**, so the pack's
`shared_with` values for `DV-Claims-Shared` and `DV-CRM-Shared` can't appear in a live export; the agent
is what "shares" them.

Building one agent by hand: [building-one-agent.md](building-one-agent.md) and
[`agent-authoring-guide.md`](../setup/agent-authoring-guide.md).

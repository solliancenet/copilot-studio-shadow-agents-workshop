---
title: "Estate Binder (worksheets)"
layout: default
nav_order: 11
has_children: false
---

# Your Estate Binder

Across the day you build one running binder — a deliverable per phase. Each template below is meant to
be copied into your own notes (or printed) and filled in as you work. Work from the live tenant where you
can: it is the preferred, hands-on path. Everything can also be completed from the filled-in **artifact
pack** (exported estate data), so you are never blocked when the tenant is slow or out of reach.

## The artifact pack

Five CSVs that describe the Halcourt Mutual estate, plus `files-export.csv`, which only Task 05-06 uses. If you can reach the tenant, start from the blank
copies and fill them in from the portal and APIs as you go. If you can't, use the filled-in set: exports
of the estate, tidied for the lab. Its connectors carry friendly names, the agent descriptions were written
by hand, and `connections-export.csv` also lists three integrations that aren't Power Platform connections
(an HTTP action, an MCP server and a cloud flow) so every credential sits in one file. Either way, join
across them to answer *how many agents, who owns them, what can they reach*.

| Export | What's in it | Blank | Filled in |
|---|---|---|---|
| `agents-export.csv` | Every agent, environment, owner, status, dates | [download]({% link worksheets/artifact-pack/blank/agents-export.csv %}) | [download]({% link worksheets/artifact-pack/agents-export.csv %}) |
| `connections-export.csv` | Connections, connectors, connection owners, sharing, auth type | [download]({% link worksheets/artifact-pack/blank/connections-export.csv %}) | [download]({% link worksheets/artifact-pack/connections-export.csv %}) |
| `agent-identities-export.csv` | Each agent's auto-created Entra identity. The pack labels it `cs-agent-<slug>-<env>`; in Entra it is named `<agent name> (Microsoft Copilot Studio)`, and the app ids won't match the tenant's | [download]({% link worksheets/artifact-pack/blank/agent-identities-export.csv %}) | [download]({% link worksheets/artifact-pack/agent-identities-export.csv %}) |
| `users-export.csv` | Accounts: enabled/disabled, leave date, last sign-in, service/shared | [download]({% link worksheets/artifact-pack/blank/users-export.csv %}) | [download]({% link worksheets/artifact-pack/users-export.csv %}) |
| `environments-export.csv` | Environments, type, DLP applied, managed | [download]({% link worksheets/artifact-pack/blank/environments-export.csv %}) | [download]({% link worksheets/artifact-pack/environments-export.csv %}) |
| `files-export.csv` | The knowledge sites' files and the sensitivity label each carries | [download]({% link worksheets/artifact-pack/blank/files-export.csv %}) | [download]({% link worksheets/artifact-pack/files-export.csv %}) |

### Where each column comes from

If you're working in the tenant, you fill in each blank CSV at the task that first reads it:

| CSV | Where to look in the tenant | Filled in at |
|---|---|---|
| `environments-export.csv` | Power Platform admin center: **Environments**, **Data policy**, and each environment's **Security roles** | [Task 00-02]({% link docs/00_lab_environment/00_02.md %}) |
| `agents-export.csv` | Power Platform admin center: **Inventory**, filtered to Copilot Studio agents. Microsoft 365 admin center: the agent **Registry** | [Task 01-01]({% link docs/01_the_agent_estate/01_01.md %}) |
| `users-export.csv` | Microsoft Entra admin center: **Users**, and the users query (`az rest`) for leave dates and sign-ins. Exchange admin center: **Mailboxes**, filtered to shared mailboxes | [Task 01-01]({% link docs/01_the_agent_estate/01_01.md %}) |
| `connections-export.csv` | The Power Platform admin API, through `az rest`. Copilot Studio: each agent's **Tools** and **Topics**. Power Platform admin center: each environment's **Flows** | [Task 01-01]({% link docs/01_the_agent_estate/01_01.md %}) |
| `agent-identities-export.csv` | Microsoft Entra admin center: **Agent identities** (or Graph Explorer) | [Task 01-02]({% link docs/01_the_agent_estate/01_02.md %}) |
| `files-export.csv` | SharePoint: each knowledge site's libraries; a file's **Details** panel shows its **Sensitivity**. You can't open `Leadership/`, so your facilitator shows that folder | [Task 05-06]({% link docs/05_test_the_controls/05_06.md %}) |

A few columns have no field in the tenant, so you write them yourself: `maker_access` (who holds the maker
roles), `is_service_account`, `auth_type` (whose credential a call carries), and `description` where an
agent has none.

{: .tip }
> The clues are all here, but no single file tells the whole story. The findings live in the **joins** —
> an agent whose owner has left, a connection owned by someone who left, an agent in an environment
> with no DLP.

## The deliverables

| Phase | Deliverable | Template |
|---|---|---|
| DISCOVER | Agent Estate Inventory | [01-agent-estate-inventory]({% link worksheets/templates/01-agent-estate-inventory.md %}) |
| MAP | Agent Access Map | [02-agent-access-map]({% link worksheets/templates/02-agent-access-map.md %}) |
| BREAK | Agent Threat Model | [03-agent-threat-model]({% link worksheets/templates/03-agent-threat-model.md %}) |
| CONTROL / RETEST | Control Efficacy Matrix | [04-control-efficacy-matrix]({% link worksheets/templates/04-control-efficacy-matrix.md %}) |
| OPERATIONALIZE | Agent Security Review Checklist | [05-agent-security-review-checklist]({% link worksheets/templates/05-agent-security-review-checklist.md %}) |
| TAKE HOME | Own-Estate Assessment | [06-own-estate-assessment]({% link worksheets/templates/06-own-estate-assessment.md %}) |

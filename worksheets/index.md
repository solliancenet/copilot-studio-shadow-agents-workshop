---
title: "Estate Binder (worksheets)"
layout: default
nav_order: 11
has_children: false
---

# Your Estate Binder

Across the day you build one running binder — a deliverable per phase. Each template below is meant to
be copied into your own notes (or printed) and filled in as you work. Everything can be completed from
the **artifact pack** (exported estate data), so you are never blocked when the live tenant is slow.

## The artifact pack

Raw exports of the Meridian Mutual estate — analyze these offline exactly as you would a real tenant
export. Join across them to answer *how many agents, who owns them, what can they reach*.

| Export | What's in it |
|---|---|
| [`agents-export.csv`]({% link worksheets/artifact-pack/agents-export.csv %}) | Every agent, environment, owner, status, dates |
| [`connections-export.csv`]({% link worksheets/artifact-pack/connections-export.csv %}) | Connections, connectors, connection owners, sharing, auth type |
| [`agent-identities-export.csv`]({% link worksheets/artifact-pack/agent-identities-export.csv %}) | Each agent's auto-created Entra identity |
| [`users-export.csv`]({% link worksheets/artifact-pack/users-export.csv %}) | Accounts: enabled/disabled, last sign-in, service/shared |
| [`environments-export.csv`]({% link worksheets/artifact-pack/environments-export.csv %}) | Environments, type, DLP applied, managed |

{: .tip }
> The clues are all here, but no single file tells the whole story. The findings live in the **joins** —
> an agent whose owner is disabled, a connection owned by someone who left, an agent in an environment
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

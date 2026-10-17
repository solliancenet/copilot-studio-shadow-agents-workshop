---
title: "01 — Agent Estate Inventory"
layout: default
parent: "Estate Binder (worksheets)"
nav_exclude: true
search_exclude: true
---

# Agent Estate Inventory

**Deliverable for Exercise 02 (DISCOVER).** One row per agent you find — across *every* environment, not
just the ones you were told about. Build it from the live tenant: the CSVs you filled in from it, plus
Copilot Studio and the admin portals for what they don't hold. If you can't reach the tenant, use the
filled-in [artifact pack]({% link worksheets/index.md %}#the-artifact-pack).

| # | Agent | Environment | Owner | Status | Identity | Connections | Connectors | Tools / actions | Grounding / data | Permissions (summary) | External systems |
|---|-------|-------------|-------|--------|----------|-------------|------------|-----------------|------------------|-----------------------|------------------|
| 1 |       |             |       |        |          |             |            |                 |                  |                       |                  |
| 2 |       |             |       |        |          |             |            |                 |                  |                       |                  |
| … |       |             |       |        |          |             |            |                 |                  |                       |                  |

## Flags — the problem estate

Mark each agent against these. (Some agents hit several; some are clean.)

| Agent | Orphaned? | Shadow? | Test→Prod? | Shared connection? | Unknown / ambiguous owner? | Nobody realizes it exists? |
|-------|-----------|---------|------------|--------------------|----------------------------|----------------------------|
|       |           |         |            |                    |                            |                            |

{: .note }
> A "clean" agent is a finding too. If you can't justify *why* an agent is fine, it isn't cleared yet.

## Count

- Agents found: ______
- Environments covered: ______
- Agents with a disabled or ambiguous owner: ______
- Agents on a shared/service-account connection: ______

---
title: "03 — Agent Threat Model"
layout: default
parent: "Estate Binder (worksheets)"
nav_exclude: true
search_exclude: true
---

# Agent Threat Model

**Deliverable for Exercise 04 (BREAK).** One row per scenario you run. Record what you actually observed,
not what you expected. After you write each row, compare it with the suggested row in that task's reveal.

| Scenario | Attack | Asset | Trust boundary crossed | Impact | Existing control (if any) |
|---|---|---|---|---|---|
| A — Grounding / indirect injection |  |  |  |  |  |
| B — Data exfiltration |  |  |  |  |  |
| C — Excessive connector / tool |  |  |  |  |  |
| D — Identity / confused deputy |  |  |  |  |  |
| E — HTTP / MCP / tool boundary |  |  |  |  |  |
| F — Lifecycle |  |  |  |  |  |

## For each scenario, capture the two hard questions

- **D (confused deputy):** *Who requested the action? Which credential did the call carry, and which system
  authorized it? Did anything check the requester's entitlement? Whose identity was recorded as the actor?*
  → ____________________
- **E (boundary):** answer the four questions for each outbound integration.

  | Integration | Authentication | Authorization | Inputs that cross | Outputs that return |
  |---|---|---|---|---|
  |  |  |  |  |  |
  |  |  |  |  |  |

{: .note }
> This table is your rudimentary threat model. In Exercise 05 you return to every row and test whether a
> control **CLOSES IT / DENTS IT / MISSES IT**.

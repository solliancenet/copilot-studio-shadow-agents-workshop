---
title: "03 — Agent Threat Model"
layout: default
parent: "Estate Binder (worksheets)"
nav_exclude: true
search_exclude: true
---

# Agent Threat Model

**Deliverable for Module 4 (BREAK).** One row per scenario you run. Record what you actually observed,
not what you expected.

| Scenario | Attack | Asset | Trust boundary crossed | Impact | Existing control (if any) |
|---|---|---|---|---|---|
| A — Grounding / indirect injection |  |  |  |  |  |
| B — Data exfiltration |  |  |  |  |  |
| C — Excessive connector / tool |  |  |  |  |  |
| D — Identity / confused deputy |  |  |  |  |  |
| E — HTTP / MCP / tool boundary |  |  |  |  |  |
| F — Lifecycle |  |  |  |  |  |

## For each scenario, capture the two hard questions

- **D (confused deputy):** *Who authorized the action? Whose identity actually performed it?*
  → ____________________
- **E (boundary):** *What auth exists? What authorization? What inputs cross? What comes back?*
  → ____________________

{: .note }
> This table is your rudimentary threat model. In Module 5 you return to every row and test whether a
> control **CLOSES IT / DENTS IT / MISSES IT**.

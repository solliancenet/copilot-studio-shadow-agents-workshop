---
title: "05 — Agent Security Review Checklist"
layout: default
parent: "Estate Binder (worksheets)"
nav_exclude: true
search_exclude: true
---

# Agent Security Review Checklist

**Deliverable for Exercise 06 (OPERATIONALIZE).** The operating model:
**KNOW IT → OWN IT → SCOPE IT → CONTROL IT → WATCH IT.** Use this as the gate an agent must pass before
it is promoted to production.

## KNOW IT — inventory, classify, understand purpose
- [ ] Agent is in the inventory, across all environments.
- [ ] Purpose and intended users are documented.
- [ ] Data sensitivity of what it touches is classified.

## OWN IT — accountable owners
- [ ] Named **business owner**.
- [ ] Named **technical owner**.
- [ ] **Security accountability** assigned.
- [ ] Owner is an enabled account; connection owners are enabled and known.

## SCOPE IT — identity, permissions, data, connectors, tools, APIs
- [ ] Acting identity is understood (agent / user-context / service).
- [ ] Permissions are least-privilege (Dataverse role + RLS where relevant).
- [ ] Connectors limited to what the job needs; no shared/service-account connections without review.
- [ ] Grounding scoped to the minimum necessary content.
- [ ] HTTP/MCP integrations authenticate per-user where possible; **no secrets in configuration**.

## CONTROL IT — environment, DLP, identity, authorization, data controls
- [ ] Lives in an environment with appropriate DLP.
- [ ] Authorization enforced against the **requesting user**, not a shared identity.
- [ ] Sensitivity labels / Purview applied to the data it can reach.
- [ ] Conditional Access considered for the agent/workload identity.

## WATCH IT — logging, detection, lifecycle
- [ ] Actions are logged and attributable to the real requester.
- [ ] Detection exists for anomalous behavior / exfiltration.
- [ ] Scheduled lifecycle + permission review; orphan detection on owner departure.

## Production promotion gate
> An agent may be promoted to production only when every KNOW/OWN/SCOPE box is checked, and CONTROL/WATCH
> have a named owner and a date. Sign-off: ________________  Date: __________

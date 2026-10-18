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
- [ ] Data sensitivity of what it can reach is classified (the inventory's **Data sensitivity** column).

## OWN IT — accountable owners
- [ ] Named **business owner**.
- [ ] Named **technical owner**.
- [ ] **Security accountability** assigned.
- [ ] Agent owner is an enabled account.
- [ ] Each connection's owner is recorded, enabled and known — separately from the agent owner.

## SCOPE IT — identity, permissions, data, connectors, tools, APIs
- [ ] Acting credential is recorded for every knowledge source, connector, tool, flow, HTTP and MCP
      integration.
- [ ] Permissions are least-privilege (scoped Dataverse role + narrowed record-level access).
- [ ] Connectors limited to what the job needs; no shared/service-account connections without review.
- [ ] Grounding scoped to the minimum necessary content.
- [ ] HTTP/MCP integrations authenticate per-user where possible; **no secrets in configuration**.

## CONTROL IT — environment, DLP, identity, authorization, data controls
- [ ] Lives in an environment with appropriate DLP.
- [ ] Authorization enforced against the **requesting user**, not a shared identity.
- [ ] Data protection verified: label applied, encryption and VIEW/EXTRACT rights checked, any label-keyed
      DLP policy checked, retest result recorded.
- [ ] Conditional Access applicability recorded per path (principal, Entra token or not, channel,
      applicable policy).

## WATCH IT — logging, detection, lifecycle
- [ ] Actions are logged; attribution tested and recorded (complete / cross-log only / partial /
      unavailable).
- [ ] Detection exists for anomalous behavior / exfiltration.
- [ ] Scheduled lifecycle + permission review; owner departure triggers role reassignment and connection
      review; the agent's identity is retired with the agent.

## Production promotion gate

### Required before production
- [ ] Every KNOW IT, OWN IT and SCOPE IT box above is checked.
- [ ] Authorization is operating against the requesting user.
- [ ] DLP and environment controls are operating.
- [ ] No secrets in configuration.
- [ ] Required logging is enabled.
- [ ] Monitoring and lifecycle owner is set.

### Accepted residual risk
- Risk: ______________________________
- Why it can't be eliminated: ______________________________
- Accepted by: ________________  Date: __________

### Formal temporary exception
- Reason: ______________________________
- Compensating controls: ______________________________
- Approver: ________________
- Remediation owner: ________________  Remediation date: __________
- Expiry date: __________ (an expired exception blocks production use)

Sign-off: ________________  Date: __________

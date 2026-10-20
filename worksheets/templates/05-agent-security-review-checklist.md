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
- [ ] Agent is in the inventory, across all environments — including the default and personal ones.
- [ ] The inventory is refreshed on a set cadence (it is a point-in-time snapshot), with the Agent 365
      registry (**Microsoft 365 admin center → Agents → All agents → Registry**) as its ongoing source.
- [ ] Purpose and intended users are documented *before* the agent is considered for promotion.
- [ ] Data sensitivity of what it can reach is classified (the inventory's **Data sensitivity** column).

## OWN IT — accountable owners
- [ ] Named **business owner**.
- [ ] Named **technical owner**.
- [ ] Named **security reviewer** — all three roles named at registration. The maker who built the
      agent is not the security reviewer by default.
- [ ] Agent owner is a current employee (no leave date) with an enabled account.
- [ ] Each connection's owner is recorded, current, enabled and known — separately from the agent owner.
- [ ] No departed or disabled owner, and no unreviewed shared-mailbox or service-account owner, on the agent or any
      connection it uses. Either one is an automatic fail until a live, named person is accountable.

## SCOPE IT — identity, permissions, data, connectors, tools, APIs
- [ ] Acting credential is recorded for every knowledge source, connector, tool, flow, HTTP and MCP
      integration.
- [ ] Permissions are least-privilege (scoped Dataverse role + narrowed record-level access, not a broad
      customizer or admin role).
- [ ] Connectors, tools and MCP operations limited to what the purpose needs; no shared/service-account
      connections without review.
- [ ] Grounding scoped to the minimum necessary content.
- [ ] HTTP/MCP integrations authenticate per-user where possible, validate input, and hold **no secrets in
      configuration**.
- [ ] The agent's data reach is bounded by its intended users' reach.

{: .note }
> A shared service identity has one fixed security context: scoping it shrinks the blast radius, but
> requester-specific access needs on-behalf-of authorization.

{: .note }
> What an MCP server advertises, what the agent has switched on, and what the token is authorized to invoke
> are three different lists. What the agent can actually do is where all three overlap: check them together.
> A token authorized for more than the agent's job is its own finding, even if no tool calls it yet.

## CONTROL IT — environment, DLP, identity, authorization, data controls
- [ ] Lives in an environment whose DLP policy matches its inventoried **Data sensitivity**.
- [ ] Not in the default environment if it handles sensitive data.
- [ ] Not in a sandbox doing production work unless that sandbox has production DLP; otherwise the agent
      moves to a managed production environment.
- [ ] Authorization enforced against the **requesting user**, not a shared identity, for any agent that
      can change state or read PII.
- [ ] Data protection verified: label applied, encryption and VIEW/EXTRACT rights checked, any label-keyed
      DLP policy checked, retest result recorded.
- [ ] Conditional Access applicability recorded per path (principal, Entra token or not, channel,
      applicable policy).

{: .note }
> Neither DLP nor Conditional Access changes whose credential acts. Conditional Access on an agent's
> Agent ID is enforced only when the agent runs in Teams, and requires Microsoft Agent 365 (or E7).

## WATCH IT — logging, detection, lifecycle
- [ ] Actions are logged; attribution (the `CopilotInteraction` event correlated with the downstream
      event) tested and recorded as complete / cross-log only / partial / unavailable.
- [ ] Partial or unavailable attribution is flagged for the requesting-user authorization fix under
      CONTROL IT.
- [ ] Detection and Defender real-time protection are specified for this agent's sensitivity class (a
      PII-handling agent gets both; a public-FAQ agent does not).
- [ ] Detection covers unusual record volumes, access to a rarely touched sensitive store, a new
      connector, and actions far outside normal hours or patterns, watched through Defender for Cloud
      Apps, Purview audit and Power Platform activity logs.
- [ ] A lifecycle and permission review is scheduled. Review owner: ____________  Frequency: ________
- [ ] The permission review re-runs the SCOPE IT checks on the same cadence.
- [ ] Owner departure triggers orphan detection immediately: business, technical and security roles
      reassigned; connections backed by the departed owner's credentials reviewed, then replaced,
      reassigned or retired.
- [ ] When the agent is retired or deleted, its Agent ID is confirmed gone (it follows the agent, not the
      owner).

{: .note }
> Most of the estate's worst findings are lifecycle failures a calendar would have caught. Orphan
> detection is the same owner and connection-owner lookup, run on a schedule.

## Gate record

**Production promotion gate.** Every box above is checked — or the failure is covered by one of these,
recorded in the Gate record below. A required control that is in place but can't remove all of the risk
passes with a layered control or an accepted residual risk signed by the security reviewer. A required
control that isn't in place passes only with a valid, unexpired formal temporary exception: residual-risk
sign-off can't stand in for a control that was never implemented.

One row per agent you run through the gate. **Production?** applies the exposure definition (others use
it, it reaches PII or Compensation, or it acts). **Stalls at** is the first stage that fails, or *passes*.

| Agent | Production? | Stalls at | Why |
|---|---|---|---|
| | | | |
| | | | |

**DENTS IT failures** — one row per dented control in your Exercise 05 matrix for this agent:

| Agent | Dented control | Layered control *or* accepted residual risk (and why it can't be removed) | Accepted by | Date |
|---|---|---|---|---|
| | | | | |

**Formal temporary exception** (only if a required control isn't yet implemented; an expired exception
blocks production use):

| Agent | Reason | Compensating controls | Accountable approver | Remediation owner | Remediation date | Expiry date |
|---|---|---|---|---|---|---|
| | | | | | | |

**Security reviewer sign-off:** Name ________________  Date __________

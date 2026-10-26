---
title: "Exercise 03: Identity, Authorization & Effective Access"
layout: default
nav_order: 5
has_children: true
---

# Exercise 03: Identity, Authorization & Effective Access

## Scenario

Exercise 02 gave you a census: which agents exist, in which environments, and who nominally owns them. That
answers *what is out there*. It does not answer the question a security reviewer has to answer before
signing off on an agent: **whose authority is this agent exercising, and what can it reach when it does?**

An agent is not a user. When a low-privilege employee asks an agent to fetch a record, the call that
reaches the data may carry that employee's credential, a maker-provided connection, a service account, or
a static key. If it carries more authority than the employee holds, the employee has just borrowed it —
the confused-deputy pattern — and an inventory row can't show you that.

In this exercise you separate three things people routinely conflate:

- **Acting credential** — *whose* authority a call carries: the requesting user's, the maker's or
  connection owner's, a service account's, a flow owner's, or a static key or token. The agent's own Entra
  identity is a separate thing: what governance and identity policies target.
- **Authorization** — *what* that actor is permitted to do, and — just as important — *where* that decision
  is actually made (Dataverse record-level access, a SharePoint permission, a connector scope, the API
  behind a key, the MCP server behind a token).
- **Effective access** — what actually becomes reachable once you combine who can invoke the agent, the
  acting credential, what that credential is authorized to do, the operations its tools expose, and the
  data they reach — steered by user input and grounding. Each layer can look harmless alone.

You work the Halcourt Mutual estate in the live tenant, or from the filled-in artifact pack if you can't
reach it, and produce an Access Map for three agents that answers one blunt question for each: **can this
agent obtain data, or cause an action, that its intended users could not?**

In this lab, treat every agent as available to every employee. In a real estate, you'd read each agent's
sharing.

## Objectives

After this exercise you will be able to:

- Distinguish the **acting credential** (whose authority a call carries) from **authorization** (what that
  actor may do), and both from **effective access** (what is actually reachable once the layers combine).
- Enumerate the kinds of acting credential a runtime path can carry — end user, maker or connection owner,
  service account, flow owner, API key, bearer token — tell them apart from the agent's own Entra identity,
  and determine which one each downstream system sees.
- Locate **where authorization is actually decided** for each path: Dataverse record-level access,
  SharePoint/site permissions, connector scopes, the API behind an HTTP credential, and the MCP server
  behind a token.
- Compute effective access for an agent by combining the layers, and name the confused-deputy and
  excessive-permission gaps it exposes.

## Duration

**Estimated time:** 45 minutes

## Deliverable

The **Agent Access Map** — one completed map per agent, worked for three agents in the final task.

- Template: [02 — Agent Access Map]({% link worksheets/templates/02-agent-access-map.md %})

{: .note }
> The live tenant is the preferred way through this exercise: its portals show what the exports can't,
> such as a Dataverse role's breadth or how much of a site an agent grounds on. If you can't reach the
> tenant, everything here is still completable **offline** from the filled-in artifact pack in the
> [Estate Binder]({% link worksheets/index.md %}#the-artifact-pack). Record whatever you can't determine as
> an open question to verify — a SharePoint site's membership, an API key's server-side scope, or, from the
> pack alone, a role's breadth or an agent's grounding scope. That gap is itself a finding.

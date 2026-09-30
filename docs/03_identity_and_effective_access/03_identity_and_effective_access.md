---
title: "Exercise 03: Identity, Authorization & Effective Access"
layout: default
nav_order: 5
has_children: true
---

# Exercise 03: Identity, Authorization & Effective Access

## Scenario

Module 2 gave you a census: which agents exist, in which environments, and who nominally owns them. That
answers *what is out there*. It does not answer the question a security reviewer has to answer before
signing off on an agent: **whose authority is this agent exercising, and what can it reach when it does?**

An agent is not a user. When Jordan Blake — an employee personally entitled to almost nothing — opens a
chat with Claims Copilot and asks for a claim, the identity that actually reaches into Dataverse is not
Jordan. It is whatever identity the agent's connection runs as. If that identity is a broadly-permissioned
service account, Jordan has just borrowed authority he does not hold. That is the confused-deputy pattern,
and you cannot see it in an inventory row — the row says "Claims Copilot, owner Priya Nair" and stops.

In this exercise you separate three things people routinely conflate:

- **Identity** — *who* is acting: the agent's own Entra identity, a user's delegated context, a service
  account, a connection owner, or a static credential baked into an action.
- **Authorization** — *what* that actor is permitted to do, and — just as important — *where* that decision
  is actually made (a Dataverse security role, a SharePoint permission, a connector scope, an API key, an
  MCP tool schema).
- **Effective access** — what actually becomes reachable once you **stack** identity, permissions,
  connector, tool, accessible data, and user input together. Each layer can look harmless alone.

You work the Halcourt Mutual estate in the live tenant, or from the filled-in artifact pack if you can't
reach it, and produce an Access Map for three agents that answers one blunt question for each: **can this
agent obtain data, or cause an action, that its intended users could not?**

## Objectives

After this exercise you will be able to:

- Distinguish **identity** (who is acting) from **authorization** (what that actor may do), and both from
  **effective access** (what is actually reachable once the layers combine).
- Enumerate the identity types an agent can act as — auto-created agent identity, delegated user context,
  service account, connection owner, and API/tool credentials — and determine which one authenticates to
  each downstream system.
- Locate **where authorization is actually decided** for each path: Dataverse security roles and row-level
  security, SharePoint/site permissions, connector scopes, HTTP/API credentials, and MCP tool schemas.
- Compute effective access for an agent by stacking the layers, and name the confused-deputy and
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

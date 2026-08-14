---
title: "Exercise 01: The Agent Estate You Didn't Know You Had"
layout: default
nav_order: 3
has_children: true
---

# Exercise 01: The Agent Estate You Didn't Know You Had

## Scenario

You are Ana Reyes, platform admin and CoE lead at **Meridian Mutual**, a mid-size regulated insurer.
Over the last few months your makers have been shipping Copilot Studio agents — a benefits helper, a
claims assistant, an underwriting tool, a policy lookup bot, and more you have not seen. Leadership asks
the obvious governance questions and nobody in the room can answer them: *How many agents do we have? Who
owns them? What can they actually reach?*

The reason it is hard is recent and structural. **Since March 2026, Copilot Studio has created an Entra
identity for every new agent automatically** — so each agent is now a first-class workload identity that
authenticates, holds connections, and calls systems on someone's behalf. **Agent 365 went GA in May
2026**, adding an admin and governance surface on top. The catch: the governance *surface* arrived faster
than any governance *practice* did. You have hundreds of new security principals, spread across
environments you do not all control, and no map of what they can touch.

Before you can inventory, map, or secure any of this, you need a shared mental model of what an agent
*is* as a security object — the hops a request travels, the identities involved, and the trust boundaries
it crosses. That model is the whole point of this first exercise. Everything else in the day builds on it.

## Objectives

After this exercise you will be able to:

- Ask the three governance questions — *how many, who owns them, what can they access* — and explain why
  most organizations cannot answer them today.
- Describe the agent security model as a chain of hops: **user → agent → identity → connectors/tools →
  data & systems**, plus grounding as a separate ingress.
- Distinguish the **agent's** identity and authority from the **user's**, and articulate the recurring
  review question: *whose authority is this agent exercising, and what can it reach when it does?*
- Locate the **trust boundaries** in a real estate and sketch, for a specific agent, exactly where trust
  is crossed.

## Duration

**Estimated time:** 30 minutes

## Deliverable

There is no formal Estate Binder artifact for this exercise. Instead you produce a rough **trust-boundary
sketch** — for one or two agents, the hops and the boundaries each request crosses. Keep it; it seeds two
later deliverables directly: the [Agent Estate Inventory]({% link worksheets/templates/01-agent-estate-inventory.md %})
in Module 2 and the [Agent Threat Model]({% link worksheets/templates/03-agent-threat-model.md %}) in
Module 4. The vocabulary you build here — *identity, connection, grounding, boundary* — is the vocabulary
you use for the rest of the day.

{: .note }
> Work these tasks from the exported [artifact pack]({% link worksheets/index.md %}#the-artifact-pack).
> A live tenant is optional here — the goal is the mental model, and the CSV exports carry everything you
> need to build it.

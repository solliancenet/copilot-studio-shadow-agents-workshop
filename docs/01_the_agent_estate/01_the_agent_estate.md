---
title: "Exercise 01: The Agent Estate You Didn't Know You Had"
layout: default
nav_order: 3
has_children: true
---

# Exercise 01: The Agent Estate You Didn't Know You Had

## Scenario

You are Ana Reyes, platform admin and CoE lead at **Halcourt Mutual**, a mid-size regulated insurer.
Over the last few months your makers have been shipping Copilot Studio agents — a benefits helper, a
claims assistant, an underwriting tool, a policy lookup bot, and more you have not seen. Leadership asks
the obvious governance questions and nobody in the room can answer them: *How many agents do we have? Who
owns them? What can they actually reach?*

The reason it is hard is recent and structural. **Since March 2026, Copilot Studio has created an Entra
identity for every new agent automatically** — so each agent is now a first-class workload identity in
Entra. But that identity is only half the answer to "who is acting?": every tool call also carries its
own credential — the user's, the maker's, a service account's, or a static key — and grounding reads
with its own scope. **Agent 365 went GA in May 2026**, adding an admin and governance surface on top.
The catch: the governance *surface* arrived faster than any governance *practice* did. In a real tenant
these identities quickly number in the hundreds. At Halcourt they're already spread across environments
you don't all control, with no map of what they can touch.

Before you can inventory, map, or secure any of this, you need a shared mental model of what an agent
*is* as a security object — the hops a request travels, the identities involved, and the trust boundaries
it crosses. That model is the whole point of this first exercise. Everything else in the day builds on it.

## Objectives

After this exercise you will be able to:

- Ask the three governance questions — *how many, who owns them, what can they access* — and explain why
  most organizations cannot answer them today.
- Describe the agent security model: the agent and its Entra identity, the **acting credential** behind
  each tool call, the data and systems those calls reach, and **grounding** as a separate path in.
- Distinguish the **agent's** identity and authority from the **user's**, and articulate the recurring
  review question: *whose authority is this agent exercising, and what can it reach when it does?*
- Locate the **trust boundaries** in a real estate and sketch, for a specific agent, exactly where trust
  is crossed.

## Duration

**Estimated time:** 20 minutes

## Deliverable

There is no formal Estate Binder artifact for this exercise. Instead you produce a rough **trust-boundary
sketch** — for one or two agents, the hops and the boundaries each request crosses. Keep it; it seeds two
later deliverables directly: the [Agent Estate Inventory]({% link worksheets/templates/01-agent-estate-inventory.md %})
in Exercise 02 and the [Agent Threat Model]({% link worksheets/templates/03-agent-threat-model.md %}) in
Exercise 04. The vocabulary you build here — *identity, credential, grounding, boundary* — is the vocabulary
you use for the rest of the day.

{: .note }
> Work these tasks in the live tenant if you can reach it: Task 01-01 has you fill in your agents, users,
> and connections CSVs from the portals and APIs, and Task 01-02 your agent identities. If you can't, the
> filled-in [artifact pack]({% link worksheets/index.md %}#the-artifact-pack) carries everything you need
> to build the mental model.

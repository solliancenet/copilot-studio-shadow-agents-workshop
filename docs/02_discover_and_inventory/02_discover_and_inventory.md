---
title: "Exercise 02: Discover & Inventory the Agent Estate"
layout: default
nav_order: 4
has_children: true
---

# Exercise 02: Discover & Inventory the Agent Estate

## Scenario

You are Ana Reyes, the platform owner and CoE lead at Halcourt Mutual. Leadership has asked a simple
question that turns out to be hard to answer: **"what do we actually have?"** Copilot Studio has been
open to makers for months. IT can name a handful of production agents — the customer service and HR bots
everyone talks about — but nobody has a defensible count, and nobody can say who owns each one, what it
can reach, or which identity it acts as.

A security review cannot start from a partial picture. The first trust boundary you have to name is the
one between the **sanctioned inventory** (the agents IT believes exist) and the **actual inventory**
(every agent in every environment, including the personal and "test" ones nobody registered). Agents you
cannot see are agents you cannot govern. Before you assess a single control, you build the map.

In this exercise you work from the exported **artifact pack** — five CSVs pulled from the Halcourt Mutual
tenant — and, where the live tenant is available, the Power Platform admin center and CoE inventory. You
join those exports into a single inventory, one row per agent, across **all four environments**: `Halcourt
(default)`, `Halcourt-Prod`, `Claims-Test`, and `Maker-Sandbox`. Then you start flagging the conditions
that will drive the rest of the day — while keeping the discipline that an agent which only *looks* risky
is not a finding until you can say why.

## Objectives

After this exercise you will be able to:

- Enumerate the discovery surfaces available for a Copilot Studio estate — the Power Platform admin center
  Agents view, the CoE Starter Kit inventory, Microsoft Graph for agent and workload identities, the Agent
  365 admin experience, and an exported artifact pack — and state what each **reveals** and what it
  **misses**.
- Join the artifact-pack exports (agents, connections, agent identities, users, environments) into one
  complete inventory row per agent, covering every environment including the sandbox and personal ones.
- Distinguish the **agent owner** from the **connection owner** and from the **effective actor**, and
  explain why recording only the agent owner hides real authority.
- Flag the problem conditions — orphaned, shadow, test-became-prod, shared connection, and unknown or
  ambiguous owner — and justify **clearing** the agents that look risky but are clean.

## Duration

**Estimated time:** 40 minutes

## Deliverable

The **Agent Estate Inventory** — one row per agent, every column filled, flags set, counts computed.
Build it in the take-home template: [01 — Agent Estate Inventory]({% link worksheets/templates/01-agent-estate-inventory.md %}).

Everything in this exercise is completable offline from the [artifact pack]({% link worksheets/index.md %}#the-artifact-pack),
so you are never blocked when the live tenant is slow or unavailable.

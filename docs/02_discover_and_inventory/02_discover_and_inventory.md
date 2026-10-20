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
(every agent in every environment, including the personal and "test" ones nobody reviews). Agents you
cannot see are agents you cannot govern. Before you assess a single control, you build the map.

In this exercise you work in the live Halcourt Mutual tenant. You start from the five CSVs you filled in
from it in Exercises 00 and 01, and go back to the admin portals and Copilot Studio for what a CSV can't hold,
such as what an agent grounds on and whose credentials its tools use. You join the CSVs into a single
inventory, one row per agent, across **all four environments**: `Halcourt (default)`, `Halcourt-Prod`,
`Claims-Test`, and `Maker-Sandbox`. Then you start flagging the conditions that will drive the rest of the
day — while keeping the discipline that an agent which only *looks* risky is not a finding until you can
say why.

## Objectives

After this exercise you will be able to:

- Enumerate the discovery surfaces available for a Copilot Studio estate — the Microsoft 365 admin center
  agent registry, the Power Platform admin center Inventory page, the CoE Starter Kit inventory, Microsoft
  Graph for agent identities, and your five CSVs — and state what each **reveals** and what it
  **misses**.
- Join your five CSVs (agents, connections, agent identities, users, environments) into one complete
  inventory row per agent, covering every environment including the sandbox and personal ones, and
  classify each agent by the most sensitive data it can reach.
- Distinguish the **agent owner** from the **connection owner**, and explain why recording only the agent
  owner hides who is accountable for the connections an agent uses.
- Flag the problem conditions — orphaned, shadow, test-became-prod, shared connection, and unknown or
  ambiguous owner — and justify **clearing** the agents that look risky but are clean.

## Duration

**Estimated time:** 40 minutes

## Deliverable

The **Agent Estate Inventory** — one row per agent, no blank cells, flags set, counts computed.
Build it in the take-home template: [01 — Agent Estate Inventory]({% link worksheets/templates/01-agent-estate-inventory.md %}).

The live tenant is the preferred way through this exercise. If it is slow or unavailable, everything here
is completable offline from the filled-in [artifact pack]({% link worksheets/index.md %}#the-artifact-pack),
so you are never blocked.

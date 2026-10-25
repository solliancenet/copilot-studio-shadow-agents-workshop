---
title: "Exercise 02: Discover & Inventory the Agent Estate"
layout: default
nav_order: 4
has_children: true
---

# Exercise 02: Discover & Inventory the Agent Estate

## Scenario

You are still Ana Reyes. Exercises 00 and 01 gave you evidence: five CSVs, each from one source, none
answering a question on its own. This exercise turns that evidence into judgements. You combine the five
into one row per agent, flag the conditions that make an agent a problem, and clear, with a reason, the
agents that only look risky. The result is the inventory you'd hand leadership: not what each portal
shows, but what you have and which of it needs attention.

Your CSVs hold almost everything you need, including whose credentials each agent's tools use. The one
thing they don't record is what an agent grounds on: for that, you reopen the agent's **Knowledge** page
in Copilot Studio. Every agent gets a row, across **all four environments**: `Halcourt (default)`,
`Halcourt-Prod`, `Claims-Test`, and `Maker-Sandbox`, including the personal and "test" ones a routine
review would skip. And an agent that only *looks* risky is not a finding until you can say why.

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

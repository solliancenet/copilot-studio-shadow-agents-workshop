---
title: "Exercise 00: Lab Environment & Orientation"
layout: default
nav_order: 2
has_children: true
---

# Exercise 00: Lab Environment & Orientation

## Scenario

**Halcourt Mutual** is a mid-size, regulated US insurer. Like most of its peers, it runs on Microsoft
365 — Outlook, SharePoint, Teams, Dataverse — and it has leaned hard into Power Platform and Copilot
Studio to move faster. HR, Claims, Sales, Finance, and IT all have makers who can build. Over the last
few months those makers shipped a fleet of Copilot Studio agents: benefits helpers, a claims lookup
bot, a policy lookup bot, an underwriting assistant, an onboarding guide, and more. Every one of them
has an Entra identity of its own. What each agent can access depends on its grounding sources, tools,
and the credentials behind its connections.

Nobody at Halcourt Mutual can answer three simple questions about that estate:

1. **How many agents do you have?**
2. **Who owns them?**
3. **What can they actually access?**

You are joining as a **platform owner and security reviewer**. You can see the environments, the agents,
the connections, and the identities. This orientation is about getting in and getting your bearings, not
fixing anything.

You work in two places, and the difference matters all day:

- **Your estate:** Halcourt Mutual's environments, agents, connections and identities, built for you and
  named with your estate id. You *observe* it: your lab account has the access the tasks need to read it,
  and you leave it as built, because every later exercise depends on finding it broken. The same account
  can reach other attendees' estates too, so leave theirs alone as well. The default environment,
  `Halcourt (default)`, is shared by every estate in the tenant. In Exercise 05, your facilitator
  demonstrates each control, and you record the retest.
- **Your own lab environment:** an environment provisioned for you alone, named `Lab-<estate_id>-NN`. It
  carries a copy of the Claims Dataverse set-up: the `Claim` and `Customer` tables with their seeded rows,
  and the same role on the same service account. You are its **administrator**. Exercise 03 sends you there
  to open that security role and read its scope, which works whether or not your lab account has a
  license.

The rule that follows: **observe your estate; make changes only in your own lab environment.** Over the day you will build a running **Estate Binder** that answers all three
questions and says whether each of Microsoft's controls **CLOSES IT**, **DENTS IT**, or **MISSES IT**.

This exercise gets you access and oriented. No findings yet — just terrain. If live tenant access is
unavailable, use the artifact pack for the discovery and analysis tasks.

## Objectives

After this exercise you will be able to:

- Sign in to the shared Halcourt Mutual demo tenant with the lab account the facilitator hands out, open
  the **Power Platform admin center**, and tell your estate apart from your own lab environment.
- Download the **artifact pack** — the blank CSVs you fill in from the tenant, or the filled-in set if you
  can't reach it — and confirm all five CSVs open.
- Name Halcourt Mutual's **four Power Platform environments** and read their type, DLP, and managed status
  in the Power Platform admin center, or from the filled-in export if you can't reach the tenant.
- Describe the day's arc — **DISCOVER → MAP → BREAK → CONTROL → RETEST → OPERATIONALIZE** — and restate
  the three questions in your own words.
- Find the **Estate Binder** templates you will fill in as you work.

## Duration

**Estimated time:** 15 minutes (part of the opening).

{: .warning }
> Everything you touch runs against a **training estate that was deliberately built to be broken.** It
> lives on facilitator-controlled, safe lab infrastructure. Do not apply any technique from this workshop
> to a tenant or system you are not explicitly authorized to test.

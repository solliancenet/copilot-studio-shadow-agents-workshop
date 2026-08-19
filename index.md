---
title: Introduction
layout: home
nav_order: 1
---

# Nobody Knows How Many Agents You Have
{: .fs-9 }

Your makers are shipping Copilot Studio agents faster than anyone is tracking them. Each one gets an
identity. Each one carries permissions for every connector it touches. Each one can reach Dataverse,
SharePoint, and whatever that HTTP action points at. This workshop teaches you to find out what your
agents can actually access, reach, and do — and whether the controls around them are enough.
{: .fs-6 .fw-300 }

[Get started]({% link docs/00_lab_environment/00_lab_environment.md %}){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-2 }
[View the estate model]({% link docs/01_the_agent_estate/01_the_agent_estate.md %}){: .btn .fs-5 .mb-4 .mb-md-0 }

---

## Three questions

Ask most organizations three simple questions and nobody has the answers:

1. **How many agents do you have?**
2. **Who owns them?**
3. **What can they access?**

Since March 2026, Copilot Studio has created an Entra identity for every new agent automatically. Agent
365 went GA in May. **The governance surface arrived faster than the governance did.** By the end of the
day you will be able to answer all three questions for a real estate — and know which controls actually
reduce the risk.

## The through-line

> **DISCOVER → MAP → BREAK → CONTROL → RETEST → OPERATIONALIZE**

You will work an intentionally imperfect agent estate for a fictional insurer, **Halcourt Mutual**,
building a running **Estate Binder** of deliverables as you go. For every failure you find, you will say
plainly whether a control **CLOSES IT**, **DENTS IT**, or **MISSES IT**.

## Who this is for

Platform owners, CoE leads, Power Platform admins, and security teams who need to understand what their
agents can actually access — and whether the controls around them are enough. No red-team background is
assumed; comfort with the Microsoft 365 / Power Platform admin surfaces helps.

## Agenda

| # | Module | Focus | Est. |
|---|--------|-------|------|
| 0 | [Lab environment]({% link docs/00_lab_environment/00_lab_environment.md %}) | Access the estate + orient | — |
| 1 | [The agent estate you didn't know you had]({% link docs/01_the_agent_estate/01_the_agent_estate.md %}) | The security model & trust boundaries | 20 min |
| 2 | [Discover & inventory]({% link docs/02_discover_and_inventory/02_discover_and_inventory.md %}) | What do I actually have? | 40 min |
| 3 | [Identity, authorization & effective access]({% link docs/03_identity_and_effective_access/03_identity_and_effective_access.md %}) | Whose authority, and what can it reach? | 45 min |
| — | _Break_ | | 15 min |
| 4 | [Break the agents]({% link docs/04_break_the_agents/04_break_the_agents.md %}) | Failure modes & attack paths | 60 min |
| — | _Lunch / longer break_ | | 30 min |
| 5 | [Put the controls to the test]({% link docs/05_test_the_controls/05_test_the_controls.md %}) | CLOSES IT / DENTS IT / MISSES IT | 60 min |
| 6 | [Build an agent security baseline]({% link docs/06_security_baseline/06_security_baseline.md %}) | KNOW → OWN → SCOPE → CONTROL → WATCH | 25 min |
| 7 | [Assess your own estate]({% link docs/07_assess_your_estate/07_assess_your_estate.md %}) | Your tenant, Monday morning | 20 min |
| 8 | [Wrap-up & hand-off]({% link docs/08_wrap_up_and_handoff/08_wrap_up_and_handoff.md %}) | Resources & next steps | — |

{: .note }
> The exercises (Modules 1–7) total ~270 minutes (~4.5 hours). The remaining ~90 minutes of the six-hour
> day is reserved for the opening and orientation, brief lecture segments between modules, and the
> wrap-up. Breaks are in addition to instructional time.

## Your Estate Binder (deliverables)

You leave with a completed binder, one artifact per phase:

| Phase | Deliverable |
|-------|-------------|
| DISCOVER | Agent Estate Inventory |
| MAP | Agent Access Map |
| BREAK | Agent Threat Model |
| CONTROL / RETEST | Control Efficacy Matrix |
| OPERATIONALIZE | Agent Security Review Checklist |
| Take-home | Own-Estate Assessment Worksheet + top-3 actions |

Templates are in the [Estate Binder]({% link worksheets/index.md %}).

## Prerequisites

- A modern browser and the lab access details handed out at the start of Module 0.
- The downloadable **artifact pack** (exported inventory + screenshots) — used whenever you are working
  offline or tenant access is slow.
- Read access to the shared **Halcourt Mutual** demo tenant (guest account provided by the facilitator).
- Optional: a Copilot-enabled editor for the analysis tasks (see `.github/copilot-instructions.md`).

{: .warning }
> Everything you do runs against a **training estate that was deliberately built to be broken**. Do not
> apply these techniques to any system you are not explicitly authorized to test.

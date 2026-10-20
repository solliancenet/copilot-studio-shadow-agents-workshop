---
title: Introduction
layout: home
nav_order: 1
---

# Nobody Knows How Many Agents You Have
{: .fs-9 }

Your makers are shipping Copilot Studio agents faster than anyone is tracking them. Each one gets an
identity of its own, but what it can reach comes from its grounding, its tools, and whose credentials sit
behind its connections. This workshop teaches you to find out what your agents can actually reach and
do — and whether the controls around them are enough.
{: .fs-6 .fw-300 }

[Get started]({% link docs/00_lab_environment/00_lab_environment.md %}){: .btn .btn-primary .fs-5 .mb-4 .mb-md-0 .mr-2 }
[View the estate model]({% link docs/01_the_agent_estate/01_the_agent_estate.md %}){: .btn .fs-5 .mb-4 .mb-md-0 }

---

## Three questions

Ask most organizations three simple questions and nobody has the answers:

1. **How many agents do you have?**
2. **Who owns them?**
3. **What can they access?**

Every new Copilot Studio agent now gets its own Entra Agent ID, and Microsoft Agent 365 (generally
available since May 1, 2026) gives admins a registry of their agents: owners and, where available,
knowledge sources and tools. That list is where a review starts. By the end of the day you will be able to
determine whose credentials each tool runs on, what access those credentials allow, and which controls
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

| # | Exercise | Focus | Est. |
|---|--------|-------|------|
| 0 | [Lab environment]({% link docs/00_lab_environment/00_lab_environment.md %}) | Access the estate + orient | — |
| 1 | [The agent estate you didn't know you had]({% link docs/01_the_agent_estate/01_the_agent_estate.md %}) | The security model & trust boundaries | 20 min |
| 2 | [Discover & inventory]({% link docs/02_discover_and_inventory/02_discover_and_inventory.md %}) | What do I actually have? | 40 min |
| 3 | [Identity, authorization & effective access]({% link docs/03_identity_and_effective_access/03_identity_and_effective_access.md %}) | Whose authority, and what can it reach? | 45 min |
| — | _Break_ | | 15 min |
| 4 | [Break the agents]({% link docs/04_break_the_agents/04_break_the_agents.md %}) | Failure modes & attack paths | 60 min |
| — | _Lunch / longer break_ | | 30 min |
| 5 | [Put the controls to the test]({% link docs/05_test_the_controls/05_test_the_controls.md %}) | CLOSES IT / DENTS IT / MISSES IT | 60 min |
| 6 | [Apply an agent security baseline]({% link docs/06_security_baseline/06_security_baseline.md %}) | KNOW → OWN → SCOPE → CONTROL → WATCH | 10 min |

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

Templates are in the [Estate Binder]({% link worksheets/index.md %}). Where to look in your own tenant, a
first-week starting list and further reading are in the [Appendix]({% link appendix.md %}).

## Prerequisites

- A modern browser.
- For the preferred, hands-on path:
  - At the start of Exercise 00 the facilitator hands you a lab account (username and password), the lab
    tenant's domain and your estate id.
  - Install the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli){:target="_blank"}
    for the few facts only an API returns.
  - The account has the access the tasks need to read the whole estate, and administers **your own lab
    environment**. You don't change the shared estate: in Exercise 05, your facilitator applies each
    control to it, and you retest.
  - You gather the estate's data into blank CSVs from the
    [Estate Binder]({% link worksheets/index.md %}#the-artifact-pack).
- Without tenant access: the filled-in **artifact pack** in the same place, which covers every hands-on task.
- Optional: a Copilot-enabled editor for the analysis tasks — see
  [`.github/copilot-instructions.md`](https://github.com/solliancenet/copilot-studio-shadow-agents-workshop/blob/main/.github/copilot-instructions.md){:target="_blank"}
  in the workshop repo.

{: .warning }
> Everything you do runs against a **training estate that was deliberately built to be broken**. Do not
> apply these techniques to any system you are not explicitly authorized to test.

---
title: "Appendix: GCC tenants"
layout: default
nav_order: 10
---

# Appendix: GCC tenants

What changes when you take the learnings from this workshop back to a home tenant in the US Government Community Cloud
(GCC). This page covers regular GCC, not GCC High or DoD. It reflects the documentation as of October
2026; government-cloud availability changes often, so check each item in your own tenant.

## Summary

The method carries over unchanged: inventory the agents, find whose credential acts, and test each control.
Most of the platform carries over too. Power Platform data policies (DLP), environments, Dataverse security
roles, SharePoint permissions, sensitivity labels and Conditional Access are all available in GCC, which,
unlike GCC High, uses the public Microsoft Entra ID.

The gaps are in the newest agent-security layer: the Agent 365 registry and its risk signals, Conditional
Access for agent identities, Defender real-time protection, and audit and DSPM coverage of Copilot Studio
chats. In Exercise 05 that's the **Agent 365**, **Conditional Access** and **Defender / audit** columns. In
GCC these features are either licensed through Agent 365, which reached GCC on October 1, 2026 as a phased
rollout with known gaps, or documented only for commercial tenants.

{: .important }
> Treat those three columns as **confirm in your own tenant before you rely on it**.

## Gaps by area

**Available** means no documented gap. **Partial** means it works with limits. **Unconfirmed** means
Microsoft hasn't said either way. **Unavailable** means Microsoft documents that it's missing. **Reported
missing** means only analysts say so; treat it as unavailable until your own tenant shows otherwise. Each row
names where its status comes from, and was last checked on 2026-10-26.

| Lab area | GCC status | What it means in your tenant |
|---|---|---|
| **Portals and URLs** (all exercises) | **Different.** GCC uses its own endpoints, such as `gcc.powerva.microsoft.us` and `gcc.admin.powerplatform.microsoft.us`. | Links from the lab pages won't open your GCC tenant. GCC data sits in separate Azure Government infrastructure. |
| **Copilot Studio features** | **Partial.** Microsoft lists these as unavailable in GCC: triggers and autonomous agents, Generative Answers enhanced search, preview models, and Azure AI Search as a knowledge source. | The lab's agents don't depend on any of these, but you can't build or test an autonomous agent in GCC. |
| **Teams channel** (Exercises 04 and 05) | **Unconfirmed.** Copilot Studio's GCC page lists the Teams channel as available, but the same page says its client apps aren't available in Teams. | In GCC, the only way to approve an agent for Teams is to submit it to an admin (same page), so the lab's "open it from its Teams link" step depends on that approval. Try the Teams path before you plan retests around it. |
| **Power Platform inventory** (Exercise 02) | **Partial.** Inventory covers standard agents, flows and environments. **Connector inventory isn't available in GCC**, and Agent Builder agents aren't covered. | To find which agents use a connector, open each agent's connections or use the API. |
| **DLP and environments** (Tasks 05-01, 05-02) | **Available.** | The GCC connector catalog is smaller. Check each connector's government availability before you write policy, including how MCP tools and custom connectors behave. |
| **Least privilege** (Task 05-03) | **Available.** Dataverse roles and SharePoint permissions work the same way. | Carries over directly. |
| **Conditional Access for agents** (Task 05-04) | **Unconfirmed.** GCC uses the public Microsoft Entra ID (Copilot Studio's GCC page), so Conditional Access itself is the commercial service. Targeting agents needs Microsoft 365 E7, or Agent 365 plus Entra P1, and needs agent identities to target (next row). | Conditional Access for users works. Policies that target agent identities or agent risk depend on your Agent 365 licensing in GCC, and on your agents having Entra agent identities. |
| **Entra Agent ID** (Exercises 01 and 03) | **Unconfirmed.** In commercial tenants, Copilot Studio has created an agent identity for each new agent since May 2026. The Entra directory is the same public one in GCC, but Copilot Studio's GCC page doesn't say whether GCC agents get one. | GCC agents may still use app registrations, so the identity lookup can look different. |
| **Agent 365 registry** (Task 05-05) | **Partial.** Agent 365 has been available to buy in GCC since October 1, 2026 (Microsoft's G7 announcement). The registry documentation covers only the worldwide and 21Vianet clouds. Directions on Microsoft reports missing Purview and Defender protections in the GCC release. | Expect the inventory and **Block**. Don't count on the **Agents at risk** tile or risk signals until the GCC service description lists them. |
| **Purview labels and sensitive info types** (Task 05-06) | **Available.** | Carries over directly. Label changes take just as long to apply. |
| **Purview Audit, `CopilotInteraction`** (Task 05-07) | **Unavailable.** Copilot Studio's audit documentation lists "Your tenant isn't a FedRAMP tenant" as a prerequisite, and its GCC page says the GCC environment complies with FedRAMP High. | The agent-layer record you used for attribution may not exist in GCC. **Confirm it before you build a detection plan on it.** |
| **DSPM for AI** (Task 05-07) | **Unconfirmed.** Purview's Copilot Studio page lists DSPM for AI support for Copilot Studio agents but says nothing about GCC. DSPM reads the same `CopilotInteraction` events as Audit, which the row above says FedRAMP tenants don't get. | The Activity explorer record you read may not appear. |
| **Dataverse read logs** (Task 05-07) | **Partial.** Read logs reach Purview from production environments only, the same as in commercial tenants. | The same limit you met in the lab. |
| **Defender real-time protection** (Task 05-07) | **Reported missing.** Since July 2026 it needs an Agent 365 license and onboarding. Microsoft's Defender XDR for US Government page doesn't list agent protection either way, and Directions on Microsoft reports Defender agent protections missing from Agent 365 for GCC. | Treat it as unavailable until you've shown otherwise. It doesn't change the lab's Scenario A result: real-time protection inspects tool calls, so it **MISSES** an injection that only changes the answer text. |

## What to do in a GCC tenant

1. **Use the method even where a source is missing.** Every task has an artifact-pack path, so the
   reasoning works without any one portal feature. Where a control isn't available, record it in the
   matrix as *unavailable in GCC* instead of a verdict.
2. **Before you test controls, check three things:**
   - whether you hold Agent 365 or Microsoft 365 G7 licenses, and what the GCC service description for
     Agent 365 lists today;
   - whether `CopilotInteraction` events appear in Purview Audit for one of your Copilot Studio agents;
   - which connectors each agent uses, checked agent by agent, since connector inventory isn't available.
3. **Put the weight on the controls that carry over.** Where attribution and real-time protection are
   missing, the remaining fixes are upstream: least privilege, and per-user (on-behalf-of) authorization so
   the credential that acts belongs to the person asking. Both work fully in GCC.

{: .note }
> The Copilot Studio feature list, the Power Platform inventory coverage and the audit prerequisite come
> from Microsoft Learn. The Agent 365 dates come from Microsoft's G7 announcement; the Agent 365 and
> Defender gaps come from one analyst report, so they're the rows most likely to change. Microsoft's own
> government documentation is the authority; check it first.

## Sources

**Microsoft Learn**

- [US Government customers (Copilot Studio)](https://learn.microsoft.com/microsoft-copilot-studio/requirements-licensing-gcc){:target="_blank"}
- [View Copilot Studio audit logs in Purview](https://learn.microsoft.com/microsoft-copilot-studio/admin-logging-copilot-studio){:target="_blank"}
- [Power Platform inventory](https://learn.microsoft.com/power-platform/admin/power-platform-inventory){:target="_blank"} — see *Sovereign clouds*.
- [Power Apps US Government](https://learn.microsoft.com/power-platform/admin/powerapps-us-government){:target="_blank"}
- [Conditional Access for agents](https://learn.microsoft.com/entra/identity/conditional-access/agent-id){:target="_blank"}
- [Manage Entra Agent IDs (Copilot Studio)](https://learn.microsoft.com/microsoft-copilot-studio/admin-use-entra-agent-identities){:target="_blank"}
- [Agent Registry in the Microsoft 365 admin center](https://learn.microsoft.com/microsoft-365/admin/manage/agent-registry){:target="_blank"}
- [Protect AI agents in real time using Microsoft Defender](https://learn.microsoft.com/defender-xdr/security-for-ai/ai-agent-real-time-protection){:target="_blank"}
- [Agent security moves to Microsoft Agent 365](https://learn.microsoft.com/defender-xdr/security-for-ai/transition-agent-security-to-agent-365){:target="_blank"}
- [Microsoft Purview for Copilot Studio](https://learn.microsoft.com/purview/ai-copilot-studio){:target="_blank"}

- [Microsoft Defender XDR for US Government](https://learn.microsoft.com/defender-xdr/usgov){:target="_blank"} — its feature-parity table doesn't mention agent protection.

**Microsoft announcement**

- [Introducing Microsoft 365 G7 (Microsoft, September 2026)](https://www.microsoft.com/en-us/microsoft-cloud/blog/us-government/2026/09/15/introducing-microsoft-365-g7-intelligence-trust-for-the-mission-ahead/){:target="_blank"}

**Analyst report (second-hand, paywalled)**

- [Agent 365 for GCC has gaps with commercial (Directions on Microsoft, October 2026)](https://www.directionsonmicrosoft.com/reports/agent-365-for-gcc-is-available-but-it-has-security-compliance-and-other-gaps-with-commercial/){:target="_blank"}

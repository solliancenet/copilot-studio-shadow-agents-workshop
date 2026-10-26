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
Microsoft hasn't said either way. **High risk** means it's likely missing.

| Lab area | GCC status | What it means in your tenant |
|---|---|---|
| **Portals and URLs** (all exercises) | **Different.** GCC uses its own endpoints, such as `gcc.powerva.microsoft.us` and `gcc.admin.powerplatform.microsoft.us`. | Links from the lab pages won't open your GCC tenant. GCC data sits in separate Azure Government infrastructure. |
| **Copilot Studio features** | **Partial.** Microsoft lists these as unavailable in GCC: triggers and autonomous agents, Generative Answers enhanced search, preview models, and Azure AI Search as a knowledge source. | The lab's agents don't depend on any of these, but you can't build or test an autonomous agent in GCC. |
| **Teams channel** (Exercises 04 and 05) | **Unconfirmed.** Microsoft's GCC feature table lists the Teams channel as available; the same page also says client apps aren't available in Teams. | Approving an agent for Teams is only possible by submitting it to an admin. Try the Teams path before you plan retests around it. |
| **Power Platform inventory** (Exercise 02) | **Partial.** Inventory covers standard agents, flows and environments. **Connector inventory isn't available in GCC**, and Agent Builder agents aren't covered. | To find which agents use a connector, open each agent's connections or use the API. |
| **DLP and environments** (Tasks 05-01, 05-02) | **Available.** | The GCC connector catalog is smaller. Check each connector's government availability before you write policy, including how MCP tools and custom connectors behave. |
| **Least privilege** (Task 05-03) | **Available.** Dataverse roles and SharePoint permissions work the same way. | Carries over directly. |
| **Conditional Access for agents** (Task 05-04) | **Unconfirmed.** It needs Microsoft 365 E7, or Agent 365 plus Entra P1. Microsoft hasn't published GCC availability. | Conditional Access for users works. Policies that target agent identities or agent risk depend on the Agent 365 rollout in GCC. |
| **Entra Agent ID** (Exercises 01 and 03) | **Unconfirmed.** In commercial tenants, Copilot Studio has created an agent identity for each new agent since May 2026. | GCC agents may still use app registrations, so the identity lookup can look different. |
| **Agent 365 registry** (Task 05-05) | **Partial.** Agent 365 has been available to buy in GCC since October 1, 2026. Analysts report missing Purview and Defender protections and a pending final FedRAMP authorization. The registry documentation covers only the worldwide and 21Vianet clouds. | Expect the inventory and **Block**. Don't count on the **Agents at risk** tile or risk signals until the GCC service description lists them. |
| **Purview labels and sensitive info types** (Task 05-06) | **Available.** | Carries over directly. Label changes take just as long to apply. |
| **Purview Audit, `CopilotInteraction`** (Task 05-07) | **High risk.** The prerequisites for Copilot Studio audit logs include "Your tenant isn't a FedRAMP tenant", and GCC is FedRAMP High. | The agent-layer record you used for attribution may not exist in GCC. **Confirm it before you build a detection plan on it.** |
| **DSPM for AI** (Task 05-07) | **Partial.** Available in GCC since 2025. With G3 it's reported to cover Microsoft 365 Copilot only, without prompts or responses; full coverage needs G5. Copilot Studio coverage isn't confirmed. | The Activity explorer record you read may not appear. |
| **Dataverse read logs** (Task 05-07) | **Partial.** Read logs reach Purview from production environments only, the same as in commercial tenants. | The same limit you met in the lab. |
| **Defender real-time protection** (Task 05-07) | **High risk.** Since July 2026 it needs an Agent 365 license and onboarding, and analysts report Defender agent protections missing from Agent 365 for GCC. | Treat it as unavailable until you've shown otherwise. It doesn't change the lab's Scenario A result: real-time protection inspects tool calls, so it **MISSES** an injection that only changes the answer text. |

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
> from Microsoft Learn. The Agent 365 gaps come from Microsoft's Microsoft 365 G7 announcement and analyst
> reports. The GCC service description for Agent 365 is the authority; check it first.

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

**Announcements and analysis**

- [Introducing Microsoft 365 G7 (Microsoft, September 2026)](https://www.microsoft.com/en-us/microsoft-cloud/blog/us-government/2026/09/15/introducing-microsoft-365-g7-intelligence-trust-for-the-mission-ahead/){:target="_blank"}
- [Agent 365 for GCC has gaps with commercial (Directions on Microsoft)](https://www.directionsonmicrosoft.com/reports/agent-365-for-gcc-is-available-but-it-has-security-compliance-and-other-gaps-with-commercial/){:target="_blank"}
- [Agent 365 reaches GCC with FedRAMP authorization pending (WindowsForum)](https://windowsforum.com/news/microsoft-agent-365-reaches-gcc-with-fedramp-authorization-pending-and-key-governance-gaps.447004/){:target="_blank"}
- [DSPM for AI for GCC (2025)](https://kurtsh.com/2025/03/13/release-microsoft-purview-data-security-posture-management-dspm-for-ai-for-gcc/){:target="_blank"}
- [Copilot Studio audit, monitoring and encryption (Valantis)](https://valantisond365.com/copilot-studio-governance-series-audit-monitoring-and-encryption-for-copilot-studio/){:target="_blank"} — reports that FedRAMP tenants can't see Copilot Studio audit logs in Purview.

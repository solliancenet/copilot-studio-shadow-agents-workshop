---
title: "Appendix: Resources"
layout: default
nav_order: 9
---

# Appendix: Resources

Everything you can take with you after the lab: the in-repo worksheets and data, where to look in your own
tenant, a first-week starting list, and further reading.

{: .warning }
> Keep any live tenant details — agent names, owners, connection strings, data locations — in your own
> private notes, not in shared workshop materials. Never paste real secrets or customer data into them.

## In this repository

- [Estate Binder]({% link worksheets/index.md %}) — all the worksheet templates in one place.
  - [01 — Agent Estate Inventory]({% link worksheets/templates/01-agent-estate-inventory.md %})
  - [02 — Agent Access Map]({% link worksheets/templates/02-agent-access-map.md %})
  - [03 — Agent Threat Model]({% link worksheets/templates/03-agent-threat-model.md %})
  - [04 — Control Efficacy Matrix]({% link worksheets/templates/04-control-efficacy-matrix.md %})
  - [05 — Agent Security Review Checklist]({% link worksheets/templates/05-agent-security-review-checklist.md %})
    — the gate's rules, ready to apply to your own agents.
  - [06 — Own-Estate Assessment]({% link worksheets/templates/06-own-estate-assessment.md %}) — a
    take-home worksheet for your own tenant: seven questions, three first-week actions, and one sentence
    for leadership.
- [The artifact pack]({% link worksheets/index.md %}#the-artifact-pack) — the five estate CSVs. The
  blank copies in `worksheets/artifact-pack/blank/` are the schema to export from your own tenant.

## Where to look in your own tenant

| Question | Where to look |
|---|---|
| **Discovery** — how will we inventory our agents? | The Agent 365 registry (**Microsoft 365 admin center → Agents → All agents → Registry**), then the Power Platform admin center (Agents view), the CoE Starter Kit agent inventory, and Microsoft Graph for agent identities — no single source is complete |
| **Ownership** — who is responsible? | Agent owner in PPAC / Copilot Studio; connection owner under Connections; for each knowledge source, tool, flow, HTTP or MCP call, whether it uses **End user** or **Maker-provided** credentials and whose credential acts; cross-check every owner against Entra account status |
| **Identity** — which identities need review? | Entra Agent IDs for newer agents, and legacy app-registration service principals tagged `AgentCreatedBy:CopilotStudio` for older ones; each agent's GUID under Copilot Studio → **Settings → Advanced → Metadata → Entra Agent ID**; match active agents against agent identities and investigate any that don't match; plus the service accounts and shared mailboxes behind connections |
| **Access** — which systems/data are highest risk? | For Dataverse: which principal authorizes the call, its security-role privilege depth, and which records it reaches through ownership, business units, teams, and sharing; the SharePoint scope each agent grounds on; custom connectors, HTTP actions, and MCP servers, and how each authenticates |
| **Controls** — what do we already have? | Power Platform DLP policies (and which environments they cover); your environment strategy; Purview labels and DLP; for Conditional Access, per path: the access pattern and token subject (user on-behalf-of, agent identity, or agent user), the resource, the channel, your licenses, and which policy can actually evaluate the request — user-delegated calls fall under user policies; API keys bypass Conditional Access; agent Conditional Access needs E7, or Agent 365 plus Entra P1 / M365 E3; for Copilot Studio, Conditional Access on the Agent ID's connector scopes is evaluated only in Teams |
| **Detection** — would we know if something went wrong? | The `CopilotInteraction` event in Purview Audit; the downstream Dataverse, flow, API, or MCP log and the credential it records; Defender for Cloud Apps; classify attribution as complete, cross-log only, partial, or unavailable |
| **Gaps** — what do we investigate first? | Your own ranked list — rank by blast radius first; anything severe you can contain right away goes to the top |

{: .note }
> New Copilot Studio agents created since May 2026 get an Entra Agent ID; older Copilot Studio agents may
> still use a legacy app registration until Microsoft migrates them. Agent 365 went GA on May 1, 2026.
> Which Agent 365 views you get, which agents are migrated, and how completely Defender sees Copilot
> Studio activity depend on your licensing and tenant — verify them in yours.

## Your first week

**Rank by blast radius first.** Blast radius is how much sensitive data, or how many write and approve
actions, an agent can reach. Anything severe you can contain right away goes to the top — for example,
disabling a connection or unsharing an agent. Effort only breaks ties. Make at least one action a quick
win.

**Quick wins** you can start yourself, at no cost:

- Pull the five estate exports for your tenant.
- List the agents whose owner account is disabled.
- Find the connections owned by departed users or running as service accounts.
- Check which environments have no DLP applied.
- Match your active agents against the agent identities in Entra, and investigate any that don't match.

{: .tip }
> **Making the case.** Name the asset in business terms ("customer PII", not "a Dataverse connector"), name
> the moment, and make the ask small. For example: *"Anyone in the company can now build an agent that
> quietly acts with someone else's access to [our most sensitive data], and today we can't say how many
> exist or what they can reach — I need [two weeks / one analyst] to inventory and scope them before that
> becomes an incident."*

## Further reading

Start from the two hubs, then the topic that matches your top gap. Bookmark these root pages; deeper pages
move.

- [Copilot Studio security & governance](https://learn.microsoft.com/microsoft-copilot-studio/security-and-governance){:target="_blank"}
- [OWASP Top 10 for LLM applications](https://genai.owasp.org/llm-top-10/){:target="_blank"} — the
  vendor-neutral names for prompt injection, sensitive information disclosure, and excessive agency.

**Discovery and governance**

- [Environments overview](https://learn.microsoft.com/power-platform/admin/environments-overview){:target="_blank"}
- [Environment strategy](https://learn.microsoft.com/power-platform/guidance/adoption/environment-strategy){:target="_blank"}
- [Use connectors in Copilot Studio agents](https://learn.microsoft.com/microsoft-copilot-studio/advanced-connectors){:target="_blank"}
- [CoE Starter Kit](https://learn.microsoft.com/power-platform/guidance/coe/starter-kit){:target="_blank"} — automates the tenant-wide inventory, including orphaned-resource detection.

**Identity and access**

- [Manage Entra Agent IDs (Copilot Studio)](https://learn.microsoft.com/microsoft-copilot-studio/admin-use-entra-agent-identities){:target="_blank"}
- [App registration, agent identities, and authentication (Copilot Studio)](https://learn.microsoft.com/microsoft-copilot-studio/govern-agents-identities-overview){:target="_blank"}
- [Dataverse security roles & privileges](https://learn.microsoft.com/power-platform/admin/security-roles-privileges){:target="_blank"}
- [Conditional Access for agents](https://learn.microsoft.com/entra/identity/conditional-access/agent-id){:target="_blank"}

**Data controls**

- [Power Platform data loss prevention](https://learn.microsoft.com/power-platform/admin/wp-data-loss-prevention){:target="_blank"}
- [Create a DLP policy](https://learn.microsoft.com/power-platform/admin/create-dlp-policy){:target="_blank"}
- [Purview sensitivity labels](https://learn.microsoft.com/purview/sensitivity-labels){:target="_blank"}
- [Purview data loss prevention](https://learn.microsoft.com/purview/dlp-learn-about-dlp){:target="_blank"}

**Detection and audit**

- [View Copilot Studio audit logs in Purview](https://learn.microsoft.com/microsoft-copilot-studio/admin-logging-copilot-studio){:target="_blank"}
- [Microsoft Purview audit](https://learn.microsoft.com/purview/audit-solutions-overview){:target="_blank"}
- [Power Platform activity logging](https://learn.microsoft.com/power-platform/admin/logging-powerapps){:target="_blank"}
- [Microsoft Defender for Cloud Apps](https://learn.microsoft.com/defender-cloud-apps/what-is-defender-for-cloud-apps){:target="_blank"}

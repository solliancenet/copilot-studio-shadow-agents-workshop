# Tenant capabilities the exercises assume

Some things the exercises reach for cannot be provisioned by any script in this kit: the tenant either has
them or it does not. `setup/scripts/00b_preflight.ps1` checks every one of them, plus the estate itself and
the attendee access model, and names the exercise steps each check protects. You run it the day before a
delivery — [RUNBOOK → Before delivery](../setup/RUNBOOK.md#before-delivery--preflight-audit-and-exercise-04-notes).

The licence rows follow from [ADR-0004](adr/0004-one-licence-per-attendee.md).

| Capability | Without it | Fallback |
|---|---|---|
| **Agent 365** (Microsoft 365 admin center → Agents) | 01-01 KT01 s3, 02-01 KT01 s1, 04-06 KT01 s1 and 05-05 KT01 read the agent registry there. Present in the build tenant on `DEVELOPERPACK_V2_E5`, but the page appears only for an admin role that can read it: attendees get **AI Reader** (RUNBOOK Phase 8b) - without it the Agents page is simply missing from the nav, which looks exactly like a tenant without Agent 365. | each step falls back to `agents-export.csv`, inline |
| **A Dataverse-capable licence per attendee** (E5) | The access model in the *shared* estate. Unlicensed accounts run in Administrative mode, which filters the custom role: the PPAC role editor (03-01 KT02 s2, 04-03 KT02 s2) and the Copilot Studio agent pages (01-01 KT02 s6, 01-02, 01-03, 02-01..03, 03-01, 03-02, 04-01..06, 05-01 KT02 s2, 05-03 KT01 s1, 05-04 KT06 s2) refuse them. | the role editor in 03-01 and 03-02: the attendee's own slice, where System Administrator survives the filter; everything else: the artifact pack |
| **A Microsoft 365 licence per attendee** (E5): Exercise 04 chat | The tenant route of Exercise 04: chatting with the published agents in Teams (04-01, 04-02, 04-04, and 04-05 KT02 s2's one Policy Lookup Bot lookup). Teams is the agents' only working channel and refuses an unlicensed account outright. | the reveal blocks and the artifact pack |
| **A Microsoft 365 licence per attendee** (E5): `CopilotInteraction` audit | 05-07 KT02: Copilot Studio records `CopilotInteraction` events only for licensed users, so an unlicensed attendee's Exercise 04 chat leaves nothing to find in Purview Audit. | the artifact pack for the Dataverse side (KT03 s3); the pack holds no audit events, so KT02 itself has no offline substitute |
| **Container Apps endpoints** (Policy API, Underwriting MCP) | 04-03, 04-05 and the 05-01 retests have nothing to call. | none - RUNBOOK Phase 1 |
| **SharePoint site** `HR-Benefits-<estate>` | 04-01 / 04-02 grounding, 05-03, 05-06. | none - RUNBOOK Phase 4 |

The access model itself - every Dataverse privilege an attendee holds and the exercise step it serves - is
[`setup/scripts/_access_model.ps1`](../setup/scripts/_access_model.ps1). Phase 8b enforces it; the preflight verifies it.

# ADR-0031: Defender real-time protection for agents is not used

**Status:** Accepted (checked 2026-10-20). Amended 2026-10-26: an Agent 365 trial (2026-10-24) removed the
licence blocker, and the setup in RUNBOOK Phase 5b was run for the `jrc` estate. KT06 still reasons it
through (Jim, 2026-10-26).
**Applies to:** `setup/RUNBOOK.md` → Phase 5b; Lab 05-07 KT06; PLANNING item 16

## Context

05-07 KT06 is about Defender's real-time protection for agents. On the build tenant two prerequisites were
missing on 2026-10-20 (checked as the facilitator with Security Administrator active):

- **A Microsoft Agent 365 licence.** Since 1 July 2026, Copilot Studio agent protection in Defender requires
  it; E5 alone is not enough. The tenant had only `DEVELOPERPACK_V2_E5`, and **Settings → Security for AI**
  said *"You don't have permission to view this page"*. An admin-led trial gives 25 seats for 30 days — it
  expires, so time it to the delivery.
- **Defender for Cloud Apps opened once.** Its settings showed *"Hang on! We're preparing new spaces for
  your data"*. Microsoft doesn't document that page or how long it lasts; Learn's steps are to open the
  portal and Defender for Cloud Apps once (RUNBOOK Phase 5b step 2). On 2026-10-26 it didn't appear.

## Decision

05-07 KT06 reasons it through instead of exercising it live. Setting it up is optional (RUNBOOK Phase 5b)
and changes nothing in KT06.

## Consequences

- Nothing to provision or tear down for KT06.
- Where it is set up, a connected estate's tool calls go through Defender: RUNBOOK Phase 5b step 7.

## Alternatives considered

**Show it live in KT06.** The setup is RUNBOOK Phase 5b, steps 2–7 (Learn: *Real-time protection for AI
agents*, *External security provider*). On and off is the checkbox in step 6. Only generative-orchestration
agents are checked, and only their tool calls, so Benefits Buddy never reaches Defender.

# ADR-0031: Defender real-time protection for agents is not used

**Status:** Accepted (checked 2026-10-20)
**Applies to:** `setup/RUNBOOK.md` → Phase 5b; Lab 05-07 KT06; PLANNING item 16

## Context

05-07 KT06 is about Defender's real-time protection for agents. On the build tenant two prerequisites are
missing (checked as the facilitator with Security Administrator active):

- **A Microsoft Agent 365 licence.** Since 1 July 2026, Copilot Studio agent protection in Defender requires
  it; E5 alone is not enough. The tenant has only `DEVELOPERPACK_V2_E5`, and **Settings → Security for AI**
  says *"You don't have permission to view this page"*. An admin-led trial gives 25 seats for 30 days — it
  expires, so time it to the delivery.
- **Defender for Cloud Apps initialised.** Its pages show *"Hang on! We're preparing new spaces for your
  data"*; the first visit starts it and it takes hours.

## Decision

Don't set it up. 05-07 KT06 reasons it through instead of exercising it live.

## Consequences

- Nothing to provision or tear down for KT06.

## Alternatives considered

**Turn it on** (Learn: *Real-time protection for AI agents*, *External security provider*), once both
prerequisites are in place:

1. Microsoft Defender portal → **Settings → Security for AI → Get started**: enable, connect the **Microsoft
   365** connector, then in the **Copilot Studio** step turn **Real-time protection** on and copy the endpoint
   URL. Security Administrator. Portal only.
2. An Entra app with a **federated credential** for that endpoint (no secret) — scriptable
   (`Create-CopilotWebhookApp.ps1` from the PowerShell Gallery, or Graph `applications` +
   `federatedIdentityCredentials`).
3. Power Platform admin center → **Security → Threat detection → Additional threat detection** →
   `Halcourt-Prod-<estate>` (Benefits Buddy's environment): share data with the provider, the app ID and the
   endpoint. Power Platform Administrator. Portal only, per environment.
4. Paste the app ID back into the Defender pane and save; it should show **Connected**.

On and off is then the checkbox in step 3. Only generative-orchestration agents are checked, and only their
tool calls.

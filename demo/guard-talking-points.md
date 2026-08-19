# GUARD — Speaker Talking Points (Jim's segment)

> Internal facilitator notes for the GUARD Foundry call. Lives in `demo/` (excluded from the site).
> Companion to `claims-triage-demo-script.md` (the live-demo runbook). **Slides presented in deck order:
> 8 → 9 → 10 → 11 (demo).** ~12-min segment total.

**Narrative shape (in this order):** *foundation → fleet governance → live proof.* Slide 8 is where agents
get their facts; Slides 9–10 are how you govern the whole fleet of them; the demo is the concrete proof that
it actually holds — ending on the live 403. Slides 9 and 10 have body text written as "the demo shows…" — in
this order the demo comes *after*, so say **"you're about to see"** / **"in a moment"** where noted.

---

## Slide 8 — Foundry IQ + Fabric IQ  (~2 min)

**Say first:** *"Before any agent is trustworthy, it has to ground on the right facts — and every agent has
to ground on the **same** facts."*

- The failure mode on the left: **grounding per agent** — each agent hand-wired to its own sources (File
  Search + an API). Fine for one. Across GUARD's **6–8 domains** the answers **drift and diverge** —
  consistency doesn't scale that way, and every team rebuilds the same plumbing.
- The pattern on the right: agents ground on **governed data products** — the domains' certified,
  lineage-tracked outputs. **Fabric IQ** puts semantic models / business concepts over those products;
  **Foundry IQ** is where the Foundry agents ground; Copilot Studio and M365 Copilot ground on the *same*
  products via Work IQ.
- **The line:** *"One governed source. Every agent agrees. Grounding isn't per-agent plumbing — it's a shared
  governed data-product layer."*
- This ties straight back to the data-mesh slides: the domains **own** the products; this is what every agent
  consumes.

**Transition →** *"So that's how they get consistent facts. Now — how do you govern a whole fleet of these
agents?"*

---

## Slide 9 — Microsoft Agent 365: Control All Agents  (~1.5 min)

**Say first:** *"Govern the fleet the way you govern people: **identify it, scope it, watch it.**"*

- **Identify** — every agent gets its own **identity** (Entra), not a shared service account. You can name
  who each agent is.
- **Scope** — **least privilege** per agent: it can touch only what its job needs.
- **Watch** — continuous oversight across the estate.
- **The bridge (forward-reference):** *"In a moment I'll show you **one** agent done exactly this way — its
  own identity, least privilege, a human in the loop. **Agent 365 makes that one-agent discipline the
  standard** for every agent across all 6–8 domains."*
- Frame it as the control plane: **Entra · Agent 365 · Purview · Defender** — identity, fleet, data, threat.

**Transition →** *"Identity and scope govern what an agent can do. The other half is proving what it did —
that's Purview."*

---

## Slide 10 — Microsoft Purview: Visibility & Compliance Across All Data  (~1.5 min)

**Say first:** *"Classify it, protect it, **prove it.**"*

- **Classify / protect** — sensitivity **labels** and **DLP** on the data the agents touch, so the controls
  travel with the data, not the app.
- **Prove** — unified **audit** across all data: what was read, cited, and returned — as **enterprise
  evidence**, not a screenshot.
- **The bridge (forward-reference):** *"You're about to see a collapsible **audit trail** inside the app for
  one claim. **Purview is that same idea at estate scale** — every agent, every data source, audited and
  compliant."*
- Same control plane again — **Entra · Agent 365 · Purview · Defender** — so it lands as one coherent story,
  not four products.

**Transition →** *"That's the governance model. Let me show you it actually working — one agent, one claim,
live."*

---

## Slide 11 — Agentic AI Demo with Microsoft Foundry  (~5 min)

> Full runbook in `claims-triage-demo-script.md`. Two tabs pre-loaded: the app on claim **CLM-2026-00841**,
> and the Foundry playground on **`Claims-Triage-Unsafe`**. Below is the spine only.

**Say first:** *"Everything I just described — grounded, identity-scoped, audited — here it is on a real
claim."*

- **The briefing (app, safe agent).** Adjuster opens a new FNOL claim → *Generate briefing* → in seconds a
  **cited** triage briefing (coverage, standing, history, recommended next steps). *"All reads. And notice —
  there's no button that lets the agent approve or deny. The action isn't even on the surface."*
- **The enforcement — three independent layers (defense in depth).**
  1. **Surface** — the app has no free chat; a user can't even *ask* the agent to act.
  2. **Agent (prompt)** — the agent is instructed to brief only; human-in-the-loop.
  3. **API permissions (RBAC)** — the identity holds `Claims.Read` **only**.
- **The 403 money-shot (playground, unsafe agent).** *"Let me remove the prompt guard entirely."* Switch tabs
  → tell `Claims-Triage-Unsafe`: **"Approve claim CLM-2026-00841."** It genuinely tries — `PUT …/status` —
  and the trace shows **HTTP 403 Forbidden**. Claim stays `UnderReview`. **The line:** *"That's not the model
  refusing — it's the API's least-privilege identity. Even a willing agent cannot write. The permission is
  the control, not the prompt."*
- **Scale in one glance.** Azure Monitor **AI Agents** view — every run and tool call, including that denied
  write, in one place. *"This is Agent 365 and Purview from the last two slides — made concrete."*

**Close the segment:** *"One agent, done right — its own identity, least privilege, human in the loop, and a
permission wall that holds even when the prompt doesn't. Agent 365 and Purview make that the standard across
GUARD's whole estate."*

---

### Timing cheat-sheet

| Slide | Time | One-line job |
|---|---|---|
| 8 Foundry IQ + Fabric IQ | ~2:00 | Agents ground on shared governed data products |
| 9 Agent 365 | ~1:30 | Govern the fleet: identity · scope · watch |
| 10 Purview | ~1:30 | Prove it: labels · DLP · estate-wide audit |
| 11 Demo | ~5:00 | Live: briefing + the 403 hard-stop + AI Agents view |
| **Total** | **~10:00** | (leaves ~2 min slack in a ~12-min slice) |

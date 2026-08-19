# Claims Triage Briefing — Demo Scenario & Script (GUARD · Wednesday)

> Internal facilitator script for the GUARD Foundry pursuit. Lives with the other demo assets in
> `demo/` (excluded from the published workshop site). Presenters: Jim + Michele.

## Why this demo

- Maps directly to GUARD's live **Claims Domain initiative**: "AI-Powered Claims Triage Briefing" after
  **FNOL**, with human oversight for every decision.
- Hits Microsoft's insurance use case **"Modernize claims operations."**
- Backed by the **Halcourt Mutual Claims & Policy API** we built — a Foundry **Claims-Triage** agent
  points at it; no rebuild.
- **The wedge is enforced governance, not observability.** The competing vendor didn't bring a working
  demo. Ours doesn't just *show* what the agent did — it *prevents* what the agent must not do, at the
  identity layer. The agent **briefs; it cannot decide or write**, and that boundary is proven live with a
  **403**, not asserted by a prompt.

## The scenario (one sentence)

A new claim is reported (FNOL); instead of an adjuster manually assembling context, a Foundry
**Claims-Triage agent** returns a structured, cited briefing in seconds — what happened, the policy &
coverage context, whether the policy is in good standing, prior-claim signals, a grounded coverage
assessment, and recommended next steps — all "for adjuster review," and with **no ability to act on the
claim itself**.

## The estate (live)

- **App:** internal **Claims Triage Console** (adjuster tool) — triage queue → claim detail →
  *Generate triage briefing*. .NET 8 MVC + REST API.
  Live (demo env `mmdemo`): `https://ca-web-ieveiacpjsr6g.thankfulglacier-039daedb.westus3.azurecontainerapps.io`
- **Agent:** Foundry new-API prompt agent **`Claims-Triage` (v4)**, model `gpt-4.1`. Grounded via File
  Search over a policy declarations doc + a claims-handling guide.
- **Enforcement (the point):** `/api/*` is secured with Entra ID + app roles `Claims.Read` / `Claims.Write`.
  The agent's OpenAPI tool authenticates with a **managed identity** that holds **`Claims.Read` only**. A
  write it attempts (approve/deny a claim) is refused with **403 at the RBAC layer** — regardless of what
  any prompt says. **The app cannot drive this** (it has no prompt box and no write path); the 403 is shown
  live in the Foundry playground with the **`Claims-Triage-Unsafe`** agent (see the demo arc).

## What the agent does (steps → tools)

1. **Trigger:** triage the seeded claim **CLM-2026-00841** (parking-lot collision, status `UnderReview`).
2. **Pull structured facts** (read tool calls to the Halcourt Mutual API, all `roles=[Claims.Read]` → 200):
   - `GET /api/claims/{claimNumber}` — the claim
   - `GET /api/policies/{policyNumber}` — policy + coverage summary (limits, deductible, dates)
   - `GET /api/policies/{policyNumber}/premium-payments` — is the policy paid-up / in good standing?
   - `GET /api/claims?policyNumber={n}` — prior claims (history / frequency signal)
   - `GET /api/policyholders/{id}` — the policyholder
3. **Ground on documents** (File Search): policy declarations + claims-handling guideline → assess likely
   coverage and the handling path, with citations.
4. **Synthesize the Triage Briefing** (the output):
   - Claim summary · Policy & coverage context · Policy standing · Claims history / anomaly note ·
     Coverage assessment (grounded + cited) · Recommended next steps ·
     **"Human review required — no decision made by the agent."**
5. **Show the audit trail** — in-app collapsible "what the agent did & why" (steps, grounding hits, the
   read-only/managed-identity banner), and the Azure Monitor **AI Agents** view for the estate-wide record.

## Illustrative output (what the agent returns)

> **Claims Triage Briefing — CLM-2026-00841**
> **Summary:** Parking-lot collision — rear bumper and tailgate damage — filed 2026-07-10; estimate $2,350
> (Weller Auto Body estimate on file; adjuster inspection completed).
> **Policy:** MM-AUTO-004417 (Auto) — Active. Named insured Dana Whitfield, 2019 Subaru Outback. Coverage B
> collision ($500 deductible); Coverage A liability 100/300; rental reimbursement included. Renews
> 2027-04-01.
> **Standing:** Premium current (monthly $128.40). No lapse.
> **History:** No prior claims on this policy. No frequency flag.
> **Coverage assessment:** A parking-lot impact to the rear bumper and tailgate is a **Coverage B collision**
> loss; the **$500 collision deductible** applies. *(cited: Declarations p.1 — Coverage B; Claims-Handling
> Guide §3.2)*
> **Recommended next steps:** route to the collision queue; estimate and inspection are on file, so confirm
> the $500 deductible with the insured and hand to the adjuster for the settlement decision. Rental
> reimbursement available while the vehicle is in an approved shop.
> **Human review required — no decision made by the agent.**

## Timing — this is a ~5-min demo inside a ~12-min segment (NOT 30 min)

The meeting is **one hour** for the whole deck, so the old 30-minute demo is unrealistic. Jim's segment is
**~12 min**: three slides + the live demo, sequenced so the slides carry the *scale* story and the demo stays
short and concrete. (Adjust the 12 if the real slice differs.)

| Beat | Time | Notes |
|---|---|---|
| **Slide 8 — Foundry IQ + Fabric IQ** | ~2 min | *Where* the agent grounds: governed data products, not per-agent plumbing. Sets up the demo. |
| **LIVE DEMO** (Slide 11 divider) | **~5 min** | one agent done right — arc below |
| **Slide 9 — Agent 365** | ~1.5 min | "one governed agent → a governed fleet" — pays off the demo. |
| **Slide 10 — Purview** | ~1.5 min | "the in-app audit trail → estate-wide evidence" — pays off the demo. |

**Ordering note:** Slides 9 and 10 reference the demo in the past tense, so present them **after** the demo:
**8 → demo → 9 → 10**. The demo is the pivot between "one agent grounded right" and "govern the fleet."

## Live demo arc (~5 min, TWO surfaces)

The demo spans **two browser tabs** — the app and the Foundry playground. The **403 hard-stop cannot happen
in the app**: the app has a single *Generate briefing* button wired to the **safe** `Claims-Triage` agent and
**no free-text chat and no write path**, so it can never even ask for a write. The 403 is proven in the
**playground** with the unsafe agent.

That's the story — **defense in depth, three layers**, each independent:
1. **Surface** — the app has no free chat; a user can't ask the agent to act. The action isn't exposed.
2. **Agent (prompt)** — the safe agent is instructed to brief only, human-in-the-loop; it won't attempt a
   write.
3. **API permissions (RBAC)** — even if the prompt guard is removed, the agent's least-privilege identity
   holds `Claims.Read` only, so the write returns **403**.

The unsafe-agent step deliberately **strips layer 2** (drops the prompt guard) to prove **layer 3** is a real
control, not the model "asking nicely" — the identity permission is what actually stops it.

- **(0:45) Scene — app.** Open the FNOL claim **CLM-2026-00841** in the Claims Triage Console.
- **(1:30) Briefing — app, safe agent.** Click *Generate briefing* → one line as it works ("it's pulling the
  claim, policy, standing, history — all reads"), the cited briefing appears; open the collapsible audit
  trail. Land it: *"The app hands the adjuster a briefing. Notice there's no button that lets the agent
  approve or deny — the action isn't even on the surface. Reads only; the human decides."*
- **(0:20) Switch tabs → Foundry playground** (pre-opened on **`Claims-Triage-Unsafe`**). *"Suppose an agent
  were built to act — same tools, no human-in-the-loop guard. Can it?"*
- **(1:30) The 403 money-shot — playground, unsafe agent.** Type *"Approve claim CLM-2026-00841."* It calls
  `PUT /api/claims/CLM-2026-00841/status` (`newStatus: Approved`) and the trace shows **HTTP 403 Forbidden**;
  reads still returned 200; the claim stays `UnderReview`. *"That's not the prompt refusing — it's the API's
  least-privilege identity. Even a willing agent cannot write."* **The app never calls this agent** — it
  always points at `Claims-Triage`; `Claims-Triage-Unsafe` exists only for this live permissions demo.
- **(0:30) Scale — one glance.** Azure Monitor **AI Agents** view: every run and tool call, **including the
  denied write**, in one place. This is the handoff line into Slide 9 (Agent 365).

**Pre-flight (do before you present):** two tabs loaded and signed in — (1) the app on the CLM-2026-00841
detail page, (2) the Foundry portal playground with **`Claims-Triage-Unsafe`** already selected — so the
mid-demo switch is one click, not a hunt through the portal. Keep the fallback screen-recording ready.

## Talking points to weave (GUARD's stated interests)

- **Agent identity & least-privilege effective access** — the agent runs as its own governed identity with a
  scoped, read-only grant; the write path is closed at the RBAC layer (demonstrated, not claimed).
- **Human-in-the-loop / no autonomous decisions** — the agent proposes; a licensed adjuster decides.
- **Observability & audit at scale** — reconstruct what any agent did and why, estate-wide, in the AI Agents
  view.
- How the *same* orchestration + governance pattern carries their **engineering-role agents** (Data/BI
  Engineer, Data Modeler, Analytics Engineer) on Fabric.

## Honest scope (do not overstate)

- **In / live:** the claims-triage briefing over the Halcourt Mutual API + grounding, the in-app audit trail,
  the **enforced 403 RBAC hard-stop**, and the App Insights **AI Agents** view. Enforcement here is
  **GA** (Entra RBAC + managed-identity OpenAPI auth + Azure Monitor tracing).
- **Represented on the slide, not live:** real **Fabric Data Agent** integration and their actual **IIS/FNOL**
  system — the Halcourt Mutual API stands in as the claims/policy system of record.
- **Roadmap / preview (flag as such):** **Foundry Guardrails** = preview; **Agent 365** depth over
  Foundry-hosted agents = to-verify — present as the tenant control-plane direction, not a live control.

## Environments

- **`mmdemo`** — the **default / primary demo estate** you present from (URL above); the selected azd env.
  Do **not** re-provision before the call.
- **`mmdev`** — the **fallback / failsafe** isolated clone (`rg-mmdev`); kept intact as a backup and for
  phase development. See `PLANNING.md` for identifiers and `infra/setup-env.sh` to stand up more.
- Both estates carry the same two agents (`Claims-Triage` + the playground-only `Claims-Triage-Unsafe`),
  since `setup-env.sh` runs `create_new_agent.py`.

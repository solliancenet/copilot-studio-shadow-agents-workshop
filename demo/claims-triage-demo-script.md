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
  any prompt says.

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

## Live 30-minute arc

- **(2 min)** Set the scene: "an adjuster just received a new FNOL claim."
- **(6 min)** Run the agent live → the structured briefing appears; narrate each read tool call as it fires.
- **(5 min)** **The governance money-shot — enforced, not asserted:**
  - Open the in-app audit trail: "here's exactly what it touched and why," running as a **read-only managed
    identity**.
  - **The 403 hard-stop:** show that when the agent is pushed to *act* — approve/deny the claim, a
    `Claims.Write` — the API refuses it with **403** because the agent's identity holds `Claims.Read` only.
    The claim never changes state. *"The boundary is enforced by identity, not by asking the model nicely."*
  - Flip to the Azure Monitor **AI Agents** view: every run, every tool call, **including the denied write**,
    in one place — the "review all agent activity at once" answer.
- **(remainder)** Architecture slide (`demo/guard-foundry-fabric-architecture.svg`) → how this generalizes to
  their **Foundry + Fabric multi-agent estate** on a governed foundation; what's next
  (`demo/guard-next-*.svg`, `demo/guard-next-minideck.pptx`).

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

- **`mmdemo`** — the frozen estate you demo from (URL above). Do **not** re-provision before the call.
- **`mmdev`** — an isolated enforced clone (`rg-mmdev`) for phase development; never touch `mmdemo`. See
  `PLANNING.md` for identifiers and `infra/setup-env.sh` to stand up more.

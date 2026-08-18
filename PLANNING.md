# PLANNING.md — Internal working notes (maintainers / PM)

> **Internal — not published, not for delivery.** Excluded from the site in `_config.yml`; kept as a
> `FACILITATOR-ONLY` tripwire (the CI leak-check greps that marker). Audience: the workshop
> **owners/authors and the PM process** — not attendees, and not something the delivering facilitator
> needs to read. Holds build status, the work backlog, timing, open product verifications, and
> delivery risks.

## PM backlog / open issues

This repo is run PM-style: items are executed by assigned agents (a prompt is produced per item), not directly. This table is the canonical backlog. Do **not** execute `deferred` items without an explicit go.

| # | Item | Status | Notes |
|---|------|--------|-------|
| 1 | Make the workshop public and enable GitHub Pages | OPEN — deferred | Repo stays **private** for now. Decide first: making the repo public exposes `AGENTS.md`, `PLANNING.md`, `setup/`, and `worksheets/answer-keys/` in **source** — the Pages `exclude:` only affects the rendered site, not the public repo tree. |
| 2 | Resolve the `[verify]` 2026 product-surface items | OPEN | Agent 365 admin/Graph surfaces, Conditional Access for workload identities, Purview coverage of Copilot Studio, `pac solution` agent portability, licensing. Feeds the Module 5 verdicts (see the verification list below). |
| 3 | Dry-run `setup/RUNBOOK.md` in a live tenant | OPEN | Confirm every planted problem reproduces and every CLOSES/DENTS/MISSES verdict holds; regenerate the artifact pack and diff against the committed CSVs. |
| 4 | Capture the 13 screenshots | OPEN | Referenced by the labs; list in `setup/screenshot-capture-list.md`. |
| 5 | Reconcile ~7h of content into the 6h slot | OPEN | Compression plan already drafted below (Timing reconciliation). |

_Status legend:_ OPEN · IN PROGRESS · BLOCKED · DONE. `deferred` = agreed not to execute yet.

## GUARD Foundry demo (separate pursuit) — progress

A customer pursuit (GUARD, insurance) for the **Wednesday** Azure AI Foundry call — distinct from the
workshop, but its assets live in this repo and are all excluded from the site (`src/`, `infra/`,
`azure.yaml`, `foundry/`, `demo/`). Slack: `#customer-guard-ins-foundry-opp`. Presenters: Jim + Michele.
The demo is an internal **Claims Triage Console** (adjuster tool) that calls a Foundry agent to produce a
grounded, post-FNOL claim-triage briefing — mapping to GUARD's Claims Domain initiative + Microsoft's
"Modernize claims operations." **Governance is the wedge** (agent identity, least-privilege,
human-in-the-loop, audit).

**Built & deployed** (Azure sub `6aa3be9e…` "AI Practice Development", RG `rg-mmdemo`, **westus3**):
- **Meridian Mutual app** — .NET 8 MVC + REST API + EF/SQLite; internal Claims Triage Console (triage
  queue → claim detail → *Generate triage briefing*), branded (navy/teal, meridian logo), collapsible
  audit trail + governance banner. Live:
  `https://ca-web-ieveiacpjsr6g.thankfulglacier-039daedb.westus3.azurecontainerapps.io`. Deployed via
  `azd` (Bicep in `infra/`, ACR remote build).
- **Azure AI Foundry** — account `aif-ieveiacpjsr6g`, project `proj-ieveiacpjsr6g`, model `gpt-4.1`
  (GlobalStandard). Agent **`Claims-Triage`** = NEW-API prompt agent (File Search grounding + OpenAPI
  tool over the app `/api/*`). Grounding docs + create scripts in `foundry/`.
- **App-driven flow** — the app calls the agent via REST `responses`/`agent_reference`
  (scope `https://ai.azure.com/.default`) using its **managed identity** (`id-ieveiacpjsr6g`), which
  holds the **Foundry User** role on the account.
- **Seed scenarios** — `CLM-2026-00841` collision (Coverage B, $500), `00842` hail + `00845` deer-strike
  (Coverage D comprehensive, $250), plus others — three distinct coverage reasonings to demo.

**Demo-prep checklist (Wednesday):**

| # | Item | Status | Owner |
|---|------|--------|-------|
| 1 | Live click-through verified from the deployed URL | DONE | Jim |
| 2 | Fallback screen-recording of the flow | TODO | Jim |
| 3 | 30-min narrative + governance talking points | in progress | Michele |
| 4 | Governance "money-shot" audit trail | DONE | — |
| 5 | Deck (reference-arch + topology slides in `demo/`) | shared w/ Michele | Michele |
| 6 | Scenario variety (collision / hail / deer-strike) | DONE | — |
| 7 | Brand + style polish (palette, logo, collapsible trace) | DONE | — |

**Key facts / redeploy:** Foundry project endpoint
`https://aif-ieveiacpjsr6g.services.ai.azure.com/api/projects/proj-ieveiacpjsr6g` · agent `Claims-Triage`
· model `gpt-4.1`. Redeploy the app with `azd deploy web` (or `azd up` to re-provision); azd env `mmdemo`.
Demo script = Slack canvas `F0BQQN9JPB7`.

**Caveats / `[verify]`:** New Foundry uses the AIServices-account + `accounts/projects` model, and the
agent must be a NEW-API prompt agent (classic Assistants don't surface in the new playground). The app
calls the agent over REST because the .NET SDK doesn't yet expose the new prompt-agent Responses surface
— revisit when it does. Briefing is rendered via Markdig as raw HTML (fine for the demo; sanitize for
production). The app-flow **topology slide** still needs a correct rework (a prompt for that was handed to
a separate thread).

## Status

First full authoring pass. The estate design, module map, worksheets, and provisioning kit are drafted.
Everything references `AGENTS.md` (the single source of truth). **Before any delivery**, walk
`setup/RUNBOOK.md` end-to-end in the demo tenant and confirm every **PLANTED PROBLEM** reproduces and
every **CONTROL EFFICACY** verdict holds — several verdicts carry `[verify]` (below).

## Timing reconciliation (important)

The outline's module durations sum to **420 minutes of instruction** (30+60+75+90+90+45+30) plus a
15-min break and a 30-min lunch → ~7h45m wall-clock. The slot is billed as **six hours**.

**How to fit six hours:** the *hands-on core* of each module is sized to fit; the discussion/demo
padding is what to trim. Suggested compression if the room is tight:

| Module | Full | Compressed | What to cut |
|---|---|---|---|
| 1 | 30 | 20 | Shorten the model walk-through; keep the trust-boundary sketch. |
| 2 | 60 | 45 | Pre-stage the exported artifact pack; less live-portal clicking. |
| 3 | 75 | 55 | Map 2 agents live, assign the 3rd as stretch. |
| 4 | 90 | 75 | Demo A + D live; B/C/E/F as guided walk-throughs from the pack. |
| 5 | 90 | 70 | Configure 3 controls live (DLP, least-priv, Purview); table the rest. |
| 6 | 45 | 30 | Baseline is mostly discussion; hand out the checklist. |
| 7 | 30 | 25 | Keep — this is the payoff. |

Compressed ≈ 320 min + 45 min breaks ≈ 6h5m. Announce the compression choice at the start.

## Open verifications ([verify] items — confirm against the delivery-date tenant)

These 2026 product specifics change the honesty of the Module 5 verdicts and the export scripts. Confirm
before delivery and update `AGENTS.md` if reality differs:

1. **Inventory/identity surfaces:** exact fields exposed by PPAC "Agents", CoE Starter Kit agent
   inventory, **Agent 365** admin, and Graph for agent/workload identities. Confirm the Entra
   app/service-principal listing for the auto-created agent identities ("since March 2026").
2. **Solution portability:** whether Copilot Studio agents export/import as solutions (`pac solution`)
   cleanly enough to cut manual RUNBOOK authoring steps.
3. **DLP granularity** for agents/connectors; whether **Conditional Access for workload identities**
   applies to agent identities and how.
4. **Purview coverage** for Copilot Studio (does Copilot honor sensitivity labels on grounded files;
   auto-labeling latency).
5. **Defender / audit signal:** which agent activities actually surface (Defender for Cloud Apps /
   Copilot detections; unified audit log schema for agent actions; the confused-deputy attribution gap).
6. **Licensing** for the shared demo tenant: Copilot Studio, M365 E5 / Agent 365, Purview.

## Delivery risks

- **Answer-key leak.** `AGENTS.md`/`PLANNING.md`/`CLAUDE.md`/`setup/` are excluded and CI leak-checks
  `_site/`. Re-verify after any `_config.yml` change. Never screenshot this file's content into `docs/`.
- **Tenant/wifi fragility.** Hybrid model exists for this reason — the exported **artifact pack** must be
  downloadable so DISCOVER/MAP/BREAK-analysis/ASSESS continue offline. Only the live BREAK and CONTROL
  demos strictly need the tenant.
- **Feature drift.** Copilot Studio / Agent 365 move fast; re-run the verifications above per delivery.
- **Over-running Module 4.** It's the centerpiece and the time sink. Keep a hard stop; push spillover
  into the Module 5 retest.

## Numbering rationale

Exercises `00`–`08`; `00` is environment/orientation (not counted in the six hours), `08` is wrap-up.
Modules `01`–`07` map 1:1 to the outline's seven modules. Task pages are numeric `NN_MM.md`, title in
front matter (matches `github-workshop` / TWL400).

## Pre-delivery checklist

- [ ] `setup/RUNBOOK.md` walked end-to-end; estate validated.
- [ ] Every PLANTED PROBLEM reproduced; every verdict confirmed or `[verify]` resolved.
- [ ] Exported artifact pack regenerated and download link works from `index.md` / worksheets.
- [ ] `bundle exec jekyll build` clean; CI leak-check green; no `AGENTS/PLANNING/CLAUDE` in `_site/`.
- [ ] Guest access to the demo tenant tested from a non-admin account (Jordan Blake persona path).
- [ ] Timing plan (full vs compressed) chosen and announced.

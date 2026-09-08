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
| 6 | **TOP BLOCKER — Dataverse capacity (Copilot Studio billing now resolved)** | PARTIALLY RESOLVED | Copilot Studio billing is **handled**: a **PAYG billing policy (`ppcc-dev`)** was created on the dev sandbox after fixing **RBAC** (self-elevate in Entra → Access management for Azure resources → Contributor on the existing subscription). Remaining blocker = **Dataverse ≥ 1 GB** (E5 sandbox ships **0 GB** → no Dataverse-backed env → no agents, Phase 3/6 hard-stop); resolve with the now-usable Azure subscription. Per-env Copilot Studio link happens in Phase 3. |
| 7 | Validate/dry-run on a **developer sandbox** tenant first (do NOT build the paid conference tenant yet) | IN PROGRESS | Sequencing decision recorded below. Fix the Azure-plan linkage, dry-run `setup/RUNBOOK.md` end-to-end on a throwaway dev sandbox, prove the estate reproduces — *then* decide on a permanent paid tenant. |
| 8 | **Agent 365** — not a provisioning prerequisite; a govern-the-fleet concern for a future module | DEFERRED | Cut from RUNBOOK Phase 0 (not on the build/publish critical path). If a future "govern the fleet" module is added, check Agent 365 licensing (bundled vs add-on) and admin/identity surfaces then. Relevant to the GUARD "what's next" governance story, not the estate build. |

_Status legend:_ OPEN · IN PROGRESS · BLOCKED · DONE. `deferred` = agreed not to execute yet.

### Sequencing decision + top blocker (live-tenant walkthrough findings)

**Decision — validate on a dev sandbox first; do not build a paid permanent conference tenant yet.** A live
walkthrough of the Dev Program E5 sandbox surfaced hard gates that must be proven out before we commit money
or a permanent tenant. Sequence:
1. Stand up the isolated **E5 Developer sandbox** (throwaway), using the **Add-on-purchases-enabled** variant.
2. **Fix the Azure-plan linkage** — an MCA billing account with a billing profile + invoice section still
   won't appear in the Dev Program setup dropdown until it has an **active Azure Plan**; create the Azure Plan
   subscription under that profile/invoice section (Azure portal → Subscriptions → Add). This same Azure Plan
   also carries the Phase 1 Container Apps spend and enables Copilot Studio credits — one setup, done once.
3. **Dry-run `setup/RUNBOOK.md`** end-to-end on that sandbox; confirm every PLANTED PROBLEM reproduces and
   the artifact pack diffs clean.
4. Only after that passes, decide whether to build a permanent paid conference tenant.

**Top blocker (current):** **Dataverse database capacity** — the E5 dev sandbox ships with **0 GB**, and
without ≥ 1 GB you cannot create a Dataverse-backed environment or any agent (RUNBOOK Phase 3/6 fail with
*"org needs at least 1 GB of database capacity"*). **Copilot Studio billing is no longer blocking** — a PAYG
billing policy (`ppcc-dev`) was created on the sandbox after fixing **RBAC** (self-elevate in Entra → Access
management for Azure resources → Contributor on the existing subscription); the subscription that carries it
also covers the Dataverse capacity need. Obtaining ≥ 1 GB Dataverse capacity is itself `[verify]` — likely a
paid per-GB capacity add-on under the billing account, or drawn against that PAYG Azure subscription.

## GUARD Foundry demo (separate pursuit) — progress

A customer pursuit (GUARD, insurance) for the **Wednesday** Azure AI Foundry call — distinct from the
workshop, but its assets live in this repo and are all excluded from the site (`src/`, `infra/`,
`azure.yaml`, `foundry/`, `demo/`). Slack: `#customer-guard-ins-foundry-opp`. Presenters: Jim + Michele.
The demo is an internal **Claims Triage Console** (adjuster tool) that calls a Foundry agent to produce a
grounded, post-FNOL claim-triage briefing — mapping to GUARD's Claims Domain initiative + Microsoft's
"Modernize claims operations." **Governance is the wedge** (agent identity, least-privilege,
human-in-the-loop, audit).

**Built & deployed** (Azure sub `6aa3be9e…` "AI Practice Development", RG `rg-mmdemo`, **westus3**):
- **Halcourt Mutual app** — .NET 8 MVC + REST API + EF/SQLite; internal Claims Triage Console (triage
  queue → claim detail → *Generate triage briefing*), branded (navy/teal, halcourt logo), collapsible
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
| 8 | **Phase 0 — enforced RBAC hard-stop + scale audit** | DONE | — |

**Phase 0 (enforced governance) — DONE.** Flips the demo from "we can *see* what the agent did"
(observability) to "we can *prevent* what the agent does" (enforced control). Proven live end-to-end:

- **RBAC hard-stop:** `/api/*` secured with Entra JWT bearer + app roles `Claims.Read`/`Claims.Write`
  (`Microsoft.Identity.Web`). New `PUT /api/claims/{n}/status` gated by `Claims.Write`; GETs/POST require
  `Claims.Read`. The Foundry OpenAPI tool now authenticates with **managed identity**
  (`OpenApiManagedAuthDetails`, audience = App ID URI). Granted `Claims.Read` **only** → an agent write
  attempt returns **403/401 at the identity layer**, not by prompt. Verified: read-only identity → GET 200 /
  PUT 403; anonymous → 401 (confirmed live on the deployed URL); claim never mutated. Reads still produce a
  full briefing; 23/23 tests pass.
- **Scale audit:** App Insights `appi-ieveiacpjsr6g` provisioned + a Foundry project↔App Insights
  connection wired → the Azure Monitor **AI Agents** view / `AppDependencies` shows all runs incl. the
  denied write span (`execute_tool …put_api_claims_claimNumber_status`) — the "review all at once" answer.
- **Teardown:** `infra/cleanup-demo.sh` (idempotent, dry-run-able): `azd down --force --purge` +
  `az ad app delete --id $API_APP_ID` + orphaned app-role-assignment sweep. `API_APP_ID` captured in the
  azd env (`3016ef29-…`).

**Phase 0 `[verify]` corrections (important — the plan's assumptions were wrong):**
1. **Caller identity:** the OpenAPI managed-identity caller is the **Foundry *account*'s system-assigned
   MI** (`appid 779379ac-…`), **not** the project MI (plan assumed project MI) and **not** a per-agent
   Entra Agent ID. `Claims.Read` was granted to the account MI; the mistaken project-MI grant was revoked.
2. **App-role claim mapping:** app roles arrive mapped inbound to `ClaimTypes.Role`, not the short `roles`
   claim — overriding `RoleClaimType="roles"` breaks the match (caused 403 on reads until removed).
3. **MI token cache (~24h):** the account MI cached a role-less token; fix = a second App ID URI
   (`api://<appId>/agent`) as a distinct resource → cache-miss → fresh token carrying the role. API accepts
   both audiences.
4. **Per-agent Entra Agent IDs:** none exist as separate Entra objects in this build — prompt-agents live
   in the project and are removed with it (documented in `cleanup-demo.sh`).

Agent re-versioned to **v4** (managed-identity OpenAPI auth). **Later phases** (1: Azure SQL + Blob/AI-Search
grounding · 2: `propose_claim_decision` fn tool + Approvals queue + Foundry Guardrails · 3: Entra Agent ID
inventory + Purview + Agent 365) remain planned, not started.

**Two-environment model (default + failsafe).** `mmdemo` is the **default/primary demo estate** we present
from (hand-built, now the selected azd env). `mmdev` is the **fallback/failsafe** — an isolated clone kept
intact as a backup and for phase development; never let a stray `azd` command take it down. The infra is
env-isolated by design: `resourceToken = uniqueString(subscription().id, environmentName, location)`
(`infra/main.bicep:18`), RG = `rg-${environmentName}` — so a new env name yields all-new global names
automatically, zero collision.

| Env | RG / token | Purpose | URL |
|---|---|---|---|
| **`mmdemo`** | `rg-mmdemo` / `ieveiacpjsr6g` | **Default/primary demo estate** — present from here (selected env) | `ca-web-ieveiacpjsr6g…westus3.azurecontainerapps.io` |
| **`mmdev`** | `rg-mmdev` / `32zp4ye7fj5ay` | **Fallback/failsafe** clone — kept intact as backup + for phase work | `ca-web-32zp4ye7fj5ay.redground-76ccf3ae.westus3.azurecontainerapps.io` |

`mmdev` identifiers: Foundry account `aif-32zp4ye7fj5ay` / project `proj-32zp4ye7fj5ay`; app registration
`Halcourt Mutual Member API (mmdev)` appId `f37e43a4-e687-4e72-9f2f-e49ff1867f42`; App Insights
`appi-32zp4ye7fj5ay`; account MI (Claims.Read grantee) principalId `c2ee4d27-…`. Verified enforced
(anonymous → 401, read-only identity → GET 200 / PUT 403, reads succeed, 23/23 tests); `rg-mmdemo` confirmed
untouched (10 resources) throughout.

- **`infra/setup-env.sh <env>`** (new, idempotent, default `mmdev`) stands up an enforced clone end to end:
  `azd env new/select` → create per-env app registration (roles + App ID URIs) + set `API_APP_ID` →
  `azd provision` → grant `Claims.Read` to the new Foundry **account** MI → `azd deploy web` → grant the
  signed-in authoring identity **Foundry User** on the new account → run `create_new_agent.py` + upload
  grounding. Aborts loudly on any step failure (never prints DONE unless all pass).
- **`[verify]` correction:** "Foundry User" (`53ca6127-…`) is **not** read-only — its dataAction wildcard
  `Microsoft.CognitiveServices/*` includes `agents/write`, so it's what authors agents. A fresh Foundry
  account has NO role assignments, so `create_new_agent.py` 403s until the authoring identity is granted
  this role — now handled in `setup-env.sh`.
- **Selected env:** `mmdemo` is now the selected/default azd env (`azd env list` shows it DEFAULT) — it is
  the primary demo estate we present from. `azd env select mmdev` before doing phase work against the
  fallback clone, and switch back to `mmdemo` when done. `setup-env.sh` still selects the env it builds
  (default `mmdev`), so re-select `mmdemo` after running it.
- **Permanent playground unsafe agent:** `create_new_agent.py` now creates BOTH `Claims-Triage` (safe; the
  app calls this) and `Claims-Triage-Unsafe` (permissions-demo, **Foundry playground only** — the app never
  references or calls it). The unsafe agent has the *same* File Search grounding and the *same*
  managed-identity OpenAPI tool (incl. the write op `PUT /api/claims/{n}/status`); only its instructions
  differ — the human-in-the-loop guard is dropped and it is told to carry out an approve/deny when asked.
  Because the OpenAPI tool authenticates as the Foundry managed identity holding **Claims.Read only**, the
  write returns **403** — proving least-privilege by identity, not by prompt. Verified on `mmdemo`:
  `project.agents.list()` shows both agents; a playground-equivalent "Approve CLM-2026-00841" run traces
  `PUT …/status` → **HTTP 403 Forbidden** (reads still 200, claim stays `UnderReview`). Because
  `setup-env.sh` runs this script, all future clones (incl. `mmdev`) get both agents too — consistent
  estates by design.

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
6. **Licensing** for the shared demo tenant — de-bundled: **E5** (incl. Developer SKU) covers most
   **Purview**; **Copilot Studio is separate and publish-capable via three models** (standalone prepaid
   Copilot Credit pack / pay-as-you-go / CCCU prepurchase). **RESOLVED — a trial license CANNOT publish**
   (create + test-chat only), so the estate needs one of the three publish-capable models; full detail in
   [`reference/copilot-studio-billing.md`](reference/copilot-studio-billing.md). Still `[verify]`: how to
   **obtain ≥ 1 GB Dataverse capacity** (0 GB in the E5 dev sandbox; likely a paid per-GB add-on or drawn
   against the PAYG Azure subscription).

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

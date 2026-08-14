# PLANNING.md — Instructor working notes

> **FACILITATOR-ONLY. Not attendee-facing, not published** (excluded in `_config.yml`). Working doc for
> delivery: status, timing, open product-detail verifications, and delivery risks.

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

---
title: "04 — Control Efficacy Matrix"
layout: default
parent: "Estate Binder (worksheets)"
nav_exclude: true
search_exclude: true
---

# Control Efficacy Matrix

**Deliverable for Module 5 (CONTROL / RETEST).** Return to every failure from Module 4. Configure the
control, **re-run the attack**, and record the honest verdict.

**The verdicts:**

- **CLOSES IT** — after the control, the attack no longer works.
- **DENTS IT** — harder or lower-impact, but a real gap remains.
- **MISSES IT** — the control does not address this failure at all.

## Matrix

Fill a verdict in each cell you test (leave blank if not applicable / not tested).

| Failure ↓  \  Control → | DLP | Env strategy | Least privilege / identity | Conditional Access | Agent 365 | Purview | Defender / audit |
|---|---|---|---|---|---|---|---|
| A — Grounding injection |  |  |  |  |  |  |  |
| B — Exfiltration |  |  |  |  |  |  |  |
| C — Excess connector |  |  |  |  |  |  |  |
| D — Confused deputy |  |  |  |  |  |  |  |
| E — HTTP / MCP boundary |  |  |  |  |  |  |  |
| F — Lifecycle |  |  |  |  |  |  |  |

## Retest log (Attack → Control → Retest)

Copy per test.

**Failure:** ______  **Control configured:** ______
**Before:** what worked ______
**After:** what happened on re-run ______
**Verdict:** ☐ CLOSES IT ☐ DENTS IT ☐ MISSES IT
**Remaining risk:** ______________________

{: .important }
> The gaps are the point. A wall of CLOSES IT is a sign you're not testing hard enough — indirect
> injection and confused-deputy rarely fully close with a platform toggle.

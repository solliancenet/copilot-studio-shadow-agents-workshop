---
title: "Exercise 05: Put the Controls to the Test"
layout: default
nav_order: 7
has_children: true
---

# Exercise 05: Put the Controls to the Test

## Scenario

You spent Module 4 breaking things. Every scenario ended the same way: you reproduced a failure, wrote
down what worked, and moved on. That was the point — you now hold a list of concrete, demonstrated ways
the Meridian Mutual estate misbehaves.

This module returns to that list. For each failure you take a Microsoft control, **configure it against
the real estate**, then **re-run the exact same attack** and see what changed. You are not here to admire
a feature list. You are here to answer one honest question per cell: after this control is on, does the
attack still work?

Three verdicts, and you will use them constantly:

- **CLOSES IT** — after the control is configured, the attack no longer works. The failure is gone.
- **DENTS IT** — the attack is harder, or lower-impact, but a real gap remains. You made the attacker
  work more; you did not stop them.
- **MISSES IT** — the control does not address this failure at all. It may be a fine control for other
  reasons, but for *this* failure it is irrelevant.

The rhythm of the whole module is **Attack → Control → Retest**:

```mermaid
flowchart LR
  A["Attack<br/>a Module 4 failure<br/>you reproduced"] --> C["Control<br/>configure it<br/>against the estate"]
  C --> R["Retest<br/>re-run the<br/>same attack"]
  R --> V{"Honest<br/>verdict"}
  V -->|CLOSES IT| Rec["Record verdict +<br/>remaining risk<br/>in the matrix"]
  V -->|DENTS IT| Rec
  V -->|MISSES IT| Rec
  Rec -.->|the gaps are the point| A
```

{: .important }
> **The gaps are the point.** A column of all-green *CLOSES IT* is not a win — it is a sign you stopped
> testing too early. Some failures (indirect prompt injection, the confused-deputy pattern) do not fully
> close with any single platform toggle, and the workshop is built to make you feel exactly where that
> boundary sits. Recording an honest *DENTS IT* or *MISSES IT* is worth more than a hopeful *CLOSES IT*.

Each task in this exercise takes one control family, explains what it actually governs (and where its
boundary lies), walks you through configuring it against the Meridian Mutual estate, and sends you back to
the specific Module 4 scenario to retest. You will not be told the verdict — you have to reach it. You
*will* be told what to look for and where the control stops being able to help.

Every task has an **offline path**: if the live tenant is slow or unavailable, you can reason each verdict
from the [artifact pack]({% link worksheets/index.md %}#the-artifact-pack) — the same exports you have
used all day — because the exports already tell you which environment carries which DLP policy, which
connection runs as a service account, and which identity actually authenticates.

## Objectives

After this exercise you will be able to:

- Configure the core Microsoft controls — DLP, environment strategy, Dataverse least privilege,
  Conditional Access, Agent 365 / CoE governance, Purview, and Defender / audit — against a live
  Copilot Studio estate.
- Re-run a reproduced attack against a configured control and reach a defensible **CLOSES IT / DENTS IT /
  MISSES IT** verdict rather than assuming the control worked.
- Name the *boundary* of each control — the trust boundary or processing stage it structurally cannot
  reach — so you can predict, before testing, which failures it will miss.
- Explain why over-permission and lifecycle failures are closable while indirect injection and
  confused-deputy are, at best, dented by platform settings.
- Complete the Control Efficacy Matrix: a verdict and a remaining-risk note for every failure you tested.

## Duration

**Estimated time:** 60 minutes

## Deliverable

The **Control Efficacy Matrix** — a verdict in every cell you test, plus a one-line remaining-risk note
per test. Use the template: [Control Efficacy Matrix]({% link worksheets/templates/04-control-efficacy-matrix.md %}).

Bring your completed [Agent Threat Model]({% link worksheets/templates/03-agent-threat-model.md %}) from
Module 4 — its list of reproduced failures is your worklist for this module.

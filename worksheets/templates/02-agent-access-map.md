---
title: "02 — Agent Access Map"
layout: default
parent: "Estate Binder (worksheets)"
nav_exclude: true
search_exclude: true
---

# Agent Access Map

**Deliverable for Module 3 (MAP).** Pick several agents and work the chain that determines *effective
access*. The question you must answer for each:

> **Can this agent access something its intended users shouldn't be able to obtain or cause to happen?**

## Per-agent map

Copy this block per agent.

**Agent:** ____________________  **Environment:** ____________________

| Layer | Value |
|---|---|
| Acting identity (agent / service / connection / user) |  |
| User context (delegated? or lost?) |  |
| Permission scopes |  |
| Connector permissions |  |
| Tool / action authorization |  |
| Accessible data (what it can actually read/write) |  |
| Untrusted input paths (chat, grounding, parameters) |  |

**Effective access =** identity **+** permissions **+** connector **+** tool **+** accessible data **+** user input

**Intended users:** ____________________
**Can it exceed them?**  ☐ No  ☐ Yes → how: ____________________
**Type of gap:**  ☐ Excessive permission  ☐ Confused deputy  ☐ Both  ☐ Other: __________

{: .tip }
> If the acting identity is a service account or a shared connection, you have almost certainly found a
> confused-deputy path — the agent exercises authority the requesting user does not personally hold.

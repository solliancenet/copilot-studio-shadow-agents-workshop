---
title: "02 — Agent Access Map"
layout: default
parent: "Estate Binder (worksheets)"
nav_exclude: true
search_exclude: true
---

# Agent Access Map

**Deliverable for Exercise 03 (MAP).** Pick several agents and work the chain that determines *effective
access*. The question you must answer for each:

> **Can this agent access something its intended users shouldn't be able to obtain or cause to happen?**

## Per-agent map

Copy this block per agent.

**Agent:** ____________________  **Environment:** ____________________

| Layer | Value |
|---|---|
| Acting credential (end user / maker or connection owner / service account / flow owner / key / token) |  |
| User context (is the requester's own entitlement checked?) |  |
| Permission scopes |  |
| Connector permissions |  |
| Tool / action authorization |  |
| Accessible data (what it can actually read/write) |  |
| Untrusted input paths (chat, grounding, parameters) |  |

**Effective access** is where these overlap: who can invoke the agent, the credential it acts with, what that
credential is authorized to do, the operations its tools expose, and the data they reach — steered by user
input and grounding.

| Who | Value |
|---|---|
| Intended users |  |
| Actual audience (who can chat with it) |  |
| Representative requester |  |
| Requester's direct entitlement |  |

**Unknowns** — record a hypothesis here, never as a fact in the tables above:

| Open question | Risk hypothesis (if it resolves broadly) | Evidence to verify |
|---|---|---|
|  |  |  |

**Can it exceed its intended users?**  ☐ No  ☐ Yes → how: ____________________
**Type of gap:**  ☐ Excessive permission  ☐ Confused deputy  ☐ Both  ☐ Other: __________

{: .tip }
> A confused deputy needs all three: a requester can invoke the path; the acting credential holds authority
> the requester lacks; and no per-user check blocks the operation. Test each one — a service account or a
> shared connection is a reason to look, not a verdict.

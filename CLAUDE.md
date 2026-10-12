# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A six-hour, hands-on security workshop that teaches attendees to assess a **Microsoft Copilot Studio
agent estate** as a security problem: discover it, map effective access, break it in controlled
scenarios, then test whether Microsoft's controls **CLOSE IT / DENT IT / MISS IT**. The published
attendee experience is a **Jekyll + `just-the-docs`** site (`index.md` + `docs/`). The sample estate,
answer key, and provisioning kit are facilitator-only and excluded from the site.

The narrative arc is **DISCOVER → MAP → BREAK → CONTROL → RETEST → OPERATIONALIZE** against a fictional
insurer, **Halcourt Mutual**.

## Questions are questions

When I ask a question, answer it. That is the only action.

- A question is not permission to act. Do not edit files, run commands, or start a process
  because a question mentioned it. "Do you understand how the process works?" gets an answer,
  not the process.
- Do not read files or do research to answer unless I asked for it. If you need to, ask first.
- If you see a next step, offer it in one line after the answer. I decide whether you do it.

## Environment

`az` and `pac` sign-in state is **project-local**: `.azure/` and `.pac/` in the repo root (gitignored),
not your home directory. It applies automatically in a VS Code terminal opened on this repo folder, in
Claude Code, and in `infra/*.sh`; in any other shell run `source scripts/env.sh` first. Sign in from
such a shell, or the scripts won't see your login.

## Commands

```bash
bundle install                 # install Jekyll + just-the-docs (see .ruby-version, Gemfile)
bundle exec jekyll serve       # local preview at http://localhost:4000/copilot-studio-shadow-agents-workshop/
bundle exec jekyll build       # production build into _site/
```

Dev container: `.devcontainer/` (Jekyll image + the `setup/RUNBOOK.md` provisioning tooling — az/Bicep,
azd, pac, PowerShell 7 + modules, pandoc, Playwright/Chromium) runs `bundle install` on create. **Every
provisioning phase runs in it** — no phase needs Windows. `setup/windows-vm/` is an *optional* Windows 11
desktop, useful only when you want a real browser for interactive sign-in and MFA; it always runs on the
host's Docker daemon, which the container's `docker` CLI drives (`setup/windows-vm/compose.yaml`).

## Architecture

```
index.md                 # attendee home: narrative, audience, prerequisites, agenda (layout: home, nav_order 1)
docs/                    # lab content — one folder per exercise
  NN_snake_case/
    NN_snake_case.md     # exercise LANDING page (has_children: true)
    NN_01.md, NN_02.md   # numbered TASK pages (parent: <landing title>)
worksheets/              # take-home "Estate Binder" templates + CSV/JSON seeds (published)
  artifact-pack/         # exported estate CSVs — the offline substitute for a live tenant
  answer-keys/           # filled versions (EXCLUDED)
media/                   # screenshots: ex##_t##_kt##_s##.png
setup/                   # facilitator provisioning kit (EXCLUDED)
reference/               # background research + runbook errata; agent-readable (EXCLUDED)
AGENTS.md                # canonical estate spec + ANSWER KEY (EXCLUDED — single source of truth)
PLANNING.md              # instructor notes (EXCLUDED)
```

## Authoring conventions (follow exactly — matches TWL400 / github-workshop house style)

**Exercise landing page** (`docs/NN_name/NN_name.md`):
```yaml
---
title: "Exercise NN: <Title>"
layout: default
nav_order: <N>          # 1 = intro; exercises increment
has_children: true
---
```
Body: `## Scenario` (narrative) → `## Objectives` ("After this exercise you'll be able to…") →
`## Duration` (`**Estimated time:** N minutes`). Optionally `## Deliverable` naming the Estate Binder
artifact the exercise produces.

**Task page** (`docs/NN_name/NN_MM.md`):
```yaml
---
title: "M. <Action-phrase title>"
layout: default
parent: "Exercise NN: <Title>"   # MUST match the landing title string exactly
nav_order: <M>
---
```
Body skeleton — use these headings, in this order:
```
# Task NN-MM — <Title>
## Introduction        # why this matters (1–3 sentences)
## Description         # what the attendee will do
## Success Criteria    # a checklist — the checkpoint
## Learning Resources  # bulleted external links, each with {:target="_blank"}
## Key Tasks           # ### 01:, ### 02: … each wraps detailed steps in a collapsible block:
## Summary             # the "what you learned" recap
```
Collapsible detailed steps inside a Key Task:
```markdown
<details markdown="block">
<summary>Expand this section for detailed steps</summary>

1. Step one …
2. Step two …

</details>
```

**Callouts** (just-the-docs): `{: .note }`, `{: .tip }`, `{: .important }`, `{: .warning }`,
`{: .caution }` applied to a blockquote.

**Diagrams:** Mermaid in a fenced ```mermaid block (enabled in `_config.yml`).

**Screenshots:** `media/ex##_t##_kt##_s##.png` (exercise, task, key-task, step). Reference with a
relative path and alt text: `![Alt](../../media/ex04_t01_kt01_s01.png)`.

**Navigation:** never hand-author next/prev links — `nav_order`/`parent`/`has_children` drive it.

## Key Patterns

- **Single source of truth:** every fact about the estate lives in `AGENTS.md`. Lab pages send attendees
  to *discover* facts; they never restate the answer key.
- **Spoiler discipline:** the strings `ANSWER KEY`, `PLANTED PROBLEM`, `FACILITATOR-ONLY`, `SPOILER`
  appear **only** in excluded files. CI (`.github/workflows/jekyll-gh-pages.yml`) fails the build if they
  (or a rendered `AGENTS/PLANNING/CLAUDE` page) reach `_site/`. Do not use these strings in `docs/`.
  Excluded files are listed in `_config.yml` `exclude:` and CI re-checks `_site/` every build, so VERIFY
  THE EXCLUDE LIST BEFORE EVERY DEPLOY — a prior workshop shipped its answer key to the live site.
- **Plain vs live names:** `AGENTS.md`, `docs/` and the artifact pack use plain names
  (`marcus.webb@halcourtmutual.onmicrosoft.com`, `Claims-Test`). A live build is an *estate* whose names
  carry an estate id and the tenant's own domain (`marcus.webb.mgray@<domain>`, `Claims-Test-mgray`) so
  several can share a tenant — rule in `AGENTS.md` → *Live estate naming*, code in `setup/scripts/_estate.ps1`.
  Never hard-code live names in `docs/`, and never explain in `docs/` that the pack's account domain
  differs from the tenant's: attendees only know the lab tenant, so there is nothing to explain.
- **CLOSES IT / DENTS IT / MISSES IT** is the Module 5 verdict vocabulary and *is* allowed in published
  pages (attendees fill blank verdict cells). The *filled* answer matrix stays in `AGENTS.md`.
- **Artifact-pack parity:** every task must be completable with direct tenant access *or* from the
  **artifact pack** (`worksheets/artifact-pack/`); the portal and APIs are the preferred path and the pack
  is the fallback. Before a task tells an attendee to read something from the portal, check the fact is in
  the pack. The pack holds only what someone with tenant access could find in the portal or APIs, plus
  fields an analyst would write themselves (descriptions, notes, calls like `is_service_account`).
  `worksheets/artifact-pack/blank/` holds the same five CSVs with headers only, for attendees to fill in
  from the tenant. Phase 7 of `setup/RUNBOOK.md` regenerates the filled set.
- **House voice:** direct, plainspoken, security-review tone. Name trust boundaries explicitly. Prefer
  "whose authority is this agent exercising?" framing.

## Important Files

| File | Purpose |
|---|---|
| `index.md` | Attendee entry point + agenda |
| `AGENTS.md` | Canonical estate spec + answer key (EXCLUDED) |
| `PLANNING.md` | Instructor notes, timing, open verifications (EXCLUDED) |
| `_config.yml` | Theme, callouts, mermaid, **exclude list** |
| `.github/workflows/jekyll-gh-pages.yml` | Build + deploy + **answer-key leak check** |
| `setup/RUNBOOK.md` | Facilitator provisioning, Phase 0–9 (EXCLUDED) |
| `reference/runbook-errata.md` | Every trap a real build hit, phase-keyed: symptom, evidence, fix (EXCLUDED) |

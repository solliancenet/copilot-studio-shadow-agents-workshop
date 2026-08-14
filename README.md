# Copilot Studio Shadow Agents Workshop

**Nobody Knows How Many Agents You Have.** A six-hour, hands-on workshop that teaches platform owners,
CoE leads, admins, and security teams to treat a Microsoft Copilot Studio agent estate as a *security
problem*: discover what agents exist, map what they can actually reach, prove where they fail, and then
test — honestly — whether Microsoft's controls close the gap, dent it, or miss it entirely.

> This repo is the **maintainer / facilitator** entry point. The **attendee** experience is the
> published site (`index.md` + `docs/`). Audience, prerequisites, and the agenda live in `index.md`.

## The through-line

**DISCOVER → MAP → BREAK → CONTROL → RETEST → OPERATIONALIZE**

Attendees work an intentionally imperfect estate for the fictional insurer **Meridian Mutual**, build a
running "Estate Binder" of deliverables, and leave with a repeatable method and a top-3 Monday-morning
action list for their own tenant.

## Repository layout

| Path | What it is |
|---|---|
| `index.md` | Attendee home: narrative, audience, prerequisites, agenda TOC |
| `docs/` | Lab content — exercises `00`–`08`, each a landing page + `NN_MM.md` task pages |
| `worksheets/` | "Estate Binder" deliverable templates + CSV/JSON seeds |
| `media/` | Screenshots (`ex##_t##_kt##_s##.png`) |
| `AGENTS.md` | **Canonical estate spec + answer key** — single source of truth |
| `PLANNING.md` | Internal maintainer/PM notes — backlog, delivery risks, open items |
| `CLAUDE.md` | Maintainer conventions (house style, authoring rules) |
| `setup/` | Facilitator provisioning kit — `RUNBOOK.md`, Bicep, PowerShell, Python |

## Local development

Prerequisites: Ruby (see `.ruby-version`) + Bundler, or open the repo in the included dev container
(`.devcontainer/devcontainer.json`, Jekyll image).

```bash
bundle install
bundle exec jekyll serve
# → http://localhost:4000/copilot-studio-shadow-agents-workshop/
```

The site auto-reloads on edit. Diagrams use Mermaid; callouts use `just-the-docs` classes
(`{: .note }`, `{: .warning }`, `{: .important }`, …).

## Facilitator setup

Provisioning the shared demo tenant and the exported artifact pack is documented in
[`setup/RUNBOOK.md`](setup/RUNBOOK.md). Read it end-to-end before a delivery, and re-run the validation
phase after any change to the estate. The lab uses a **hybrid** model: a shared instructor-provisioned
tenant for the live break/control demos, plus a downloadable artifact pack so discovery, mapping, and
threat-modeling continue even if tenant access drops.

## Presenters

Jim Counts · Michele Leroux Bustamante — Power Platform Conference.

## Contributing & conduct

Follow the authoring conventions in `CLAUDE.md`. This content is provided for **defensive security
education** against an intentionally-vulnerable training estate; keep contributions scoped to that
purpose.

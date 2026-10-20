# Copilot / agent context for this workshop

This repository is the attendee lab guide for **"Nobody Knows How Many Agents You Have"** — a hands-on
workshop on securing a Microsoft Copilot Studio agent estate. If you are an AI assistant helping an
attendee work through these labs, use the framing below.

## The scenario

The workshop centers on a fictional mid-size regulated insurer, **Halcourt Mutual**, whose makers have
shipped Copilot Studio agents faster than anyone tracked them. Attendees play the role of a platform
owner / security reviewer who must **discover, map, break, and then test the controls around** that
agent estate.

The day follows one arc: **DISCOVER → MAP → BREAK → CONTROL → RETEST → OPERATIONALIZE.**

## Where things live

- `docs/` — the lab content (published site). Exercises are numbered `00`–`06`; each folder has a
  landing page plus numbered `NN_MM.md` task pages.
- `appendix.md` — take-home material and further reading: where to look in your own tenant, a first-week
  starting list, and links.
- `worksheets/` — the take-home deliverable templates ("Estate Binder") attendees fill in as they go, and
  the artifact pack (`worksheets/artifact-pack/`: the filled-in estate CSVs, with blank copies in `blank/`).
- `media/` — screenshots referenced by the labs.

## How to help an attendee

- Help them **reason about** identity, authorization, effective access, trust boundaries, and control
  efficacy. Explain *why* a finding matters, not just *what* to click.
- When they analyze the sample estate, help them think like a reviewer: whose authority is the agent
  exercising, and what can it reach when it does?
- Do **not** invent tenant-specific facts. If a value depends on the live lab tenant or the exported
  artifact pack, tell them to read it from there.

## What NOT to do

- This is a **defensive security** workshop conducted against an intentionally-vulnerable sample estate
  that the facilitator provisioned for training. Keep guidance educational and scoped to the lab.
- Do not help exfiltrate, or act against, any system that is not part of the supplied lab environment.

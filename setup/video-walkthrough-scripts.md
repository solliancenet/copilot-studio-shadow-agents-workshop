# Video walkthrough scripts

> **FACILITATOR-ONLY.** Narration scripts for recorded walkthroughs of the lab exercises. Shots are keyed
> `exNN_tMM_ktKK_sSS` — exercise, task, key task, step — the same convention as
> `setup/screenshot-capture-list.md`, so every shot points at the instruction it demonstrates and a
> reviewer can diff a script against a page.

Each shot carries four things, and the last two are the point of the exercise:

| Field | What it holds |
|---|---|
| **On screen** | what the recorder does, in order |
| **Say** | the narration, close to verbatim |
| **Why** | the explanation an attendee needs to understand the action, not just repeat it |
| **Instruction** | the page and step the shot satisfies |

---

## Before you film anything

Read this first. Video is the most expensive asset in the kit to re-cut, and three things will force a
re-shoot if you skip them.

1. **The audience is the ATTENDEE** (decided 2026-10-13), and that decides the content rule: a shot shows
   **where the data lives and what to record**, never what the record turns out to say. No agent is named
   as orphaned, over-permissioned or shared; no owner is called out; no count is given as an answer. An
   attendee who watches should be able to *start* the task, not skip it.

   This is not a softer version of a facilitator walkthrough — it is a different product. A walkthrough
   that correlates actions to instructions *and* explains why each finding matters is an answer key in
   video form, and the lab pages deliberately send attendees to discover those facts. If a facilitator cut
   is ever wanted, record it separately and host it where attendees cannot reach it.

   One useful consequence: because an attendee cut stops short of the findings, it does **not** depend on
   the estate being complete. It can be recorded against an estate that is missing agents, and it does not
   have to be re-cut when the estate is fixed.
2. **Do not put video in `media/`.** That folder is published with the site. `_config.yml`'s exclude list
   does not cover it, and the CI leak check greps `_site/` for answer-key strings — it cannot read an MP4,
   so a spoiler video would ship silently. Facilitator recordings belong outside the repo entirely, or
   under a path added to `exclude:` first.
3. **Film against a complete estate.** On the build tenant today the two default-environment agents are
   missing, so the tenant shows 8 agents across 3 environments where the canon has 10 across 4. Ex 00 does
   not count agents, so it is filmable now — but Ex 01 and Ex 02 are not, and Task 02-03's orphaned-owner
   hunt returns nothing until those two agents are rebuilt.

Also settle the exercise text before filming it. Ex 00-02 are under review on
`docs/exercises-rebuild-findings`; a script written against moving prose goes stale faster than the prose.

### Recording conventions

- **Private browser window**, as Task 00-01 step 2 tells attendees. It also keeps your own tenant out of
  the frame.
- **Say the estate id once, early.** Every name on screen carries it; the lab pages use the plain names.
  Attendees get confused here more than anywhere else, so name the rule rather than letting them infer it.
- **Never show another estate's objects.** The environments list and the default environment both hold
  other people's builds. Scroll past them deliberately and say why you are ignoring them.
- **Redact nothing that is canon; redact everything that is not** — the tenant domain is fine, a real
  bearer token or API key is not.
- Target **6–8 minutes** for Ex 00. The exercise itself is 15 minutes of attendee time; a walkthrough that
  runs longer than the task it explains will not get watched.

---

## Ex 00 — Lab Environment & Orientation

Total target: **7 minutes**. Findings-free, so this recording is safe for attendees and facilitators alike.

### Shot ex00_t00_kt00_s00 — cold open

- **On screen:** the Ex 00 landing page.
- **Say:** "Three questions run through this whole day: how many agents do we have, who owns them, and
  what can they actually access. Halcourt Mutual cannot answer any of them. This first exercise is not
  about finding problems — it is about getting in and getting your bearings. No findings yet, just
  terrain."
- **Why:** Sets the expectation that nothing is wrong yet. Attendees who arrive hunting for problems
  mis-read the orientation data as findings and get ahead of the material.
- **Instruction:** `00_lab_environment.md` — Scenario, Duration.

### Shot ex00_t01_kt01_s01 — sign in, and what your account really is

- **On screen:** open a private window → `admin.powerplatform.microsoft.com` → sign in with the lab
  account → **Manage** → **Environments**. Then open an environment's **…** menu so the create/edit/delete
  controls are visibly available.
- **Say:** "Private window, so your own work account does not sign you in to the wrong tenant. Your
  facilitator gave you three things: a username, a password, and an estate id. Now — look at what this
  account can do. Creation, edit and delete are all available to you. That is deliberate, and it is worth
  understanding before you touch anything."
- **Why:** This is the one place the lab breaks its own stance, so explain it rather than glossing it. A
  security reviewer observes and changes nothing — that discipline holds all day. But in Module 1 you have
  to list every connection in an environment and name its owner, and the platform will only tell a
  **tenant administrator** who owns someone else's connection; a per-environment role returns only the
  connections you own yourself. There is no read-only role that answers "whose credentials sit behind this
  agent?". So the account carries the admin role the question needs, and you supply the restraint the role
  no longer enforces. Then say the part that makes it a lesson rather than an apology: *a review you cannot
  run without elevating the reviewer is itself worth writing down.*
- **Instruction:** `00_01.md` — Key Task 01 steps 1–4 and the `.important` callout.

### Shot ex00_t01_kt01_s02 — the estate id rule

- **On screen:** point at one environment whose name carries the estate id, then at a persona in the list.
- **Say:** "Everything your copy of the estate owns carries your estate id. The lab pages show the plain
  name — `Claims-Test` — and your tenant shows `Claims-Test-` plus your id. Same for accounts and the
  SharePoint sites."
- **Why:** One tenant holds several copies of this estate. Without this rule, attendees either hunt for
  names that do not exist or, worse, start recording another estate's objects as their own.
- **Instruction:** `00_01.md` — Key Task 01 step 1; `00_01.md` — Description, paragraph 2.

### Shot ex00_t01_kt02_s01 — the artifact pack, blank and filled

- **On screen:** the Estate Binder → **The artifact pack** → download the five blank CSVs → open
  `agents-export.csv` showing a header row only → then show the filled version of the same file.
- **Say:** "Two ways through this lab. In the tenant, you fill these five blank CSVs in yourself as you
  go — right now they are nothing but headers. If you cannot reach the tenant, you take the filled-in set
  instead and work offline. The tenant is the better experience; the pack covers every task."
- **Why:** Attendees need to know the offline path exists *before* they hit a slow portal, or they sit
  blocked and lose the exercise. Show the header-only file explicitly — people assume a download failed
  when they open a one-line CSV.
- **Instruction:** `00_01.md` — Key Task 02 steps 1–4.

### Shot ex00_t01_kt02_s02 — the joins, named early

- **On screen:** three CSVs side by side; highlight `environment` and `owner_upn` in `agents-export.csv`,
  then the matching `environment` column and `upn` column in the other two.
- **Say:** "Notice these columns. The agent file names an environment and an owner. The environments file
  lists environments. The users file lists UPNs. You will join across them in Module 2."
- **Why:** The whole method of this workshop is that no single file answers a question — the findings live
  in the joins. Planting that 20 minutes early makes Module 2 feel inevitable instead of arbitrary.
- **Instruction:** `00_01.md` — Key Task 02 step 5; `00_02.md` — the `.tip` callout.

### Shot ex00_t02_kt01_s01 — read the four environments

- **On screen:** **Manage** → **Environments**. Identify the three carrying the estate id plus
  `Halcourt (default)`. Scroll past the others deliberately. Then **…** → managed state;
  **Security** → **Data and privacy** → **Data policy** and the **Applied to** column;
  **Settings** → **Users + permissions** → **Security roles** → **Environment Maker** → **…** →
  **Members**.
- **Say:** "Four environments are yours: three carry your estate id, and the default environment, which
  every estate in this tenant shares. The others in this list belong to other people — leave them out.
  Now read four facts about each one: its type, whether a DLP policy covers it, whether it is managed, and
  who is allowed to build in it."
- **Why:** Two things are being taught at once. First, scoping: an inventory is only as good as its
  boundary, and the shared default environment is where that boundary gets blurry. Second, the habit of
  reading an environment as a set of *controls* rather than a name — a sandbox with no DLP and open maker
  access is a different risk surface from a managed production environment, and that difference drives
  everything in Module 2.
- **Instruction:** `00_02.md` — Key Task 01 steps 1–3.

### Shot ex00_t02_kt01_s02 — record facts, not findings

- **On screen:** type the four rows into the blank `environments-export.csv`, then stop.
- **Say:** "Four rows, five columns. Type what you see and nothing else. You might already be forming an
  opinion about the sandbox with no DLP policy — hold it. Whether any of this is a problem is a call you
  make in Module 2, with a second piece of evidence."
- **Why:** The discipline the exercise is built on. A reviewer who records conclusions instead of
  observations cannot show their work later, and cannot tell the difference between an agent that *looks*
  risky and one that *is*. Saying "hold it" out loud is more effective than the page's written warning,
  because the temptation lands exactly here.
- **Instruction:** `00_02.md` — Key Task 01 steps 4–5; Description ("You record facts here, not findings").

### Shot ex00_t02_kt02_s01 — the day's arc and the binder

- **On screen:** the DISCOVER → OPERATIONALIZE diagram, then the Estate Binder index.
- **Say:** "The day runs along one arc: discover, map, break, control, retest, operationalize. Each phase
  produces one deliverable in your Estate Binder, and the first is the Agent Estate Inventory in Module 2.
  Keep the binder open — you fill it in as you work, not at the end."
- **Why:** Attendees who treat the binder as homework finish the day with nothing to take back. Framing it
  as the running artifact is what makes the last module — doing this against their own estate — feel
  reachable.
- **Instruction:** `00_02.md` — Key Task 02 steps 1–4.

### Shot ex00_t02_kt02_s02 — close

- **Say:** "You are in, you know what your account can and cannot be trusted to do, you have the five
  files, and you have read your four environments. Next: how many agents are there, who owns them, and
  what can they reach."
- **Why:** Restates the three questions against the terrain just mapped, so Ex 01 opens on a question the
  attendee already feels rather than a new topic.
- **Instruction:** `00_01.md` and `00_02.md` — Summary sections.

---

## Ex 01 and beyond

Not scripted yet, and deliberately so: the audience decision in **Before you film anything** changes
almost every *Why* line from Ex 01 onward, and Task 01-01's own text is still under review. Ex 02 is also
unfilmable until the default-environment agents are rebuilt — Task 02-03's orphaned-owner hunt returns no
candidates without them, and a walkthrough that demonstrates a hunt finding nothing teaches the wrong
lesson.

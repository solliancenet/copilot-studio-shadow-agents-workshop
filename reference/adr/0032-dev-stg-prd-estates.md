# ADR-0032: Three estates — dev, stg, prd — and every attendee works in prd

**Status:** Accepted (Jim, 2026-11-09). Supersedes [ADR-0002](0002-shared-vs-individual-estates.md) and the
estate per person of [#30](https://github.com/solliancenet/copilot-studio-shadow-agents-workshop/issues/30).
**Applies to:** `setup/RUNBOOK.md` → *Before Phase 2*, Phases 8b and 8c, *Before delivery*, Phase 9;
`reference/building-many-estates.md`; `setup/scripts/10_build_estates.ps1`, `07`, `07c`, `07d`, `99_teardown.ps1`;
Exercise 00 and the
estate-id wording in `docs/`

## Context

[ADR-0002](0002-shared-vs-individual-estates.md) had attendees share the facilitator's estate, with
Exercise 05 demonstrated. On 2026-10-22, #30 replaced that with an estate per person (`stu01`–`stu20`,
`fac01`–`fac03`) so that attendees could apply Exercise 05's controls themselves.

That never happened. The Exercise 05 pages still have the facilitator apply each control in the
facilitator's estate, and say so: the attendee's own estate never gets the change, so the facilitator runs
each retest on screen. 05-02 would collide anyway, because its DLP change lands on the one default
environment every estate shares. An attendee can see a control's *before* in their own estate, but never
its *after*.

Everything else attendees do is reading. Exercises 01–03 read the estate. Exercise 04 chats with the
published agents, and the two that look like writers don't write: Claims Copilot has only *List rows*
tools, and Expense Helper's flow only replies to the agent. Twenty estates meant twenty people reading the
same facts in twenty places.

And the twenty estates cost:

- **Builds.** 40–50 minutes per estate, almost all of it Phase 6, with transient failures to resume (errata
  *Many-estate build*, 2026-11-03).
- **Noise.** The admin lists hold every estate's agents — several hundred — and the default environment holds
  a copy of every default-environment flow per estate (24 of the expense flow). Attendees filter by estate
  id at nearly every step.
- **Checks.** The estates delivered in 2026-10 were not each preflighted; at that count it isn't practical.
- **Teardown.** Twenty-three estates to take down after each delivery.

One estate with no id at all was considered and rejected (below): it leaves nowhere to develop or rehearse
a change without touching the estate attendees use.

## Decision

- **A tenant holds three estates, with fixed ids:**

  | Estate | For |
  |---|---|
  | `dev` | Developing and trying changes to the kit and the lab |
  | `stg` | Rehearsal: changes are promoted here and the delivery is rehearsed against them |
  | `prd` | Delivery. **Every attendee works in prd** |

- **Promotion is re-running the changed phase script with the next estate id** — for example
  `06_provision_agents.ps1 -Estate stg -Agents <slug>`, then the same with `-Estate prd`. The scripts stay as
  they are: [ADR-0001](0001-estates.md)'s id mechanism serves three estates as it served twenty-three.
  A re-run only adds what is missing, though. It creates a new agent, topic, flow or row, but it leaves
  an existing one as it was: `Ensure-Flow` passes over an active flow, a removed topic stays unless it is
  listed as retired in 06, and Phase 5 skips the tables, columns and seed rows it finds. A change to
  something that already exists in stg or prd needs its own update step, or a remove-and-recreate, worked
  out in dev and recorded with the change, or the promotion reports success and changes nothing.
- **The three are built with** `10_build_estates.ps1 -Estates dev,stg,prd -ReclaimSeats`.
- **Attendee accounts and slices live in prd** (`student01.prd`, `Lab-prd-01`, …). stg gets one or two
  accounts for rehearsal.
- **Attendees keep Power Platform Administrator, as an accepted risk.** 01-01's connection list needs it
  ([ADR-0024](0024-attendees-are-power-platform-admins.md)). The role is tenant-wide, so it reaches dev and
  stg as well as prd, and with the whole room in one estate, one attendee's change is everyone's result. The
  pages tell attendees to look and not change; nothing enforces it.

## Consequences

- **A control applied in prd is applied to the estate attendees use,** so they can retest its *after*
  themselves — in Teams, against the same agents they broke in Exercise 04. How Exercise 05 uses that is
  for its rewrite to decide, separately.
- **05-02 no longer collides between attendees.** Its change still lands on the shared default environment,
  so it also reaches dev's and stg's agents there.
- **Lists shrink to three estates.** The filter-by-estate-id steps stay, because dev and stg are visible in
  the same tenant; the lines that describe a many-estate tenant change.
- **The delivery estate can be checked.** The preflight and the Teams chat probe cover prd, the one estate
  attendees use.
- **A fault in prd stops the whole room,** not one attendee: a broken agent, a Teams channel that's off, or a
  stray change by anyone holding Power Platform Administrator.
- **Seats** follow [ADR-0009](0009-eight-licences-per-estate.md) and [ADR-0004](0004-one-licence-per-attendee.md):
  each estate's eight persona seats while it builds, reclaimed after; one seat per prd attendee.
- **Build stg and prd days before they are needed:** Phase 4c's label can take a day to reach SharePoint.
- **The per-person estates go.** Their ids are in every name they created, so none can be renamed into dev,
  stg or prd: tear them down (Phase 9) and build the three.
- **The kit's docs change, not its scripts:** the RUNBOOK's *Before Phase 2* describes the three estates and
  promotion; `building-many-estates.md` is rewritten around them; Phases 8b and 8c, `07c` and `07d` run for
  prd; Exercise 00 says the estate is shared by the room.

## Alternatives considered

- **An estate per person (#30).** Its purpose was a hands-on Exercise 05, which never arrived, and 05-02
  could not have been hands-on in it anyway. It costs twenty times the builds, the noise above, and estates
  nobody preflights.
- **One estate, no id.** Plain names, and no filtering at all. But there is then nowhere to develop or
  rehearse a change except the delivery estate, and every script would have to change, since each refuses to
  run without an id today.
- **Pull attendees back toward read-only.** Their only write role in the estate is Power Platform
  Administrator. Dropping it would send 01-01's connection list to the artifact pack, because nothing weaker
  can read it ([ADR-0024](0024-attendees-are-power-platform-admins.md)). Kept, and the risk accepted.

## Open questions

- **Does prd live between deliveries?** Recommended: keep it, rotate only the attendee accounts and their
  slices each delivery (attendee accounts are deleted right after each one, Phase 9), and preflight before
  every delivery. Keeping it also keeps whatever the last delivery changed: put Exercise 05's controls back
  (`09_ex05_demo_state.ps1 -Action Restore`), and treat any change attendees made with Power Platform
  Administrator that the preflight doesn't check as a reason to rebuild. The alternative is rebuilding prd for each delivery, about an hour plus Phase 4c's wait.

# Before delivery: the audit and Purview checks in detail

Background for [RUNBOOK → Before delivery](../setup/RUNBOOK.md#before-delivery--preflight-audit-and-exercise-04-notes).
Phase 5b turns auditing on and Phase 8b grants the Purview role; these notes explain what each check
protects and what the room should expect.

Manual, not scripted. **Do these before Exercise 04 runs**: 05-07 reconstructs Exercise 04 from the logs,
and nothing recorded before auditing was on can be found afterwards ([PLANNING item 16](../PLANNING.md)).

- [ ] **Dataverse auditing in `Claims-Test-<estate>`** - Phase 5b's `04b_provision_audit.ps1` turns it on
      for the environment and the `Claim` table - **not** `Customer`, whose changes would carry SSN and date
      of birth into records attendees can read (by hand: PPAC → the environment → **Settings** → **Audit and
      logs** → **Audit settings**, then the table's properties). This records **changes** (create, update,
      delete, sharing), which is what the 05-03 demonstration makes.
- [ ] **Attendees can search Purview Audit** (05-07 KT01, KT02, KT05). Global Reader is enough once
      ingestion is on: as an attendee, run a search covering the Exercise 04 rehearsal, filtered to record
      type `CopilotInteraction`. Verified 2026-10-21 as student03 (jobs finish in 4-7 minutes).
- [ ] **No setting makes Claims Copilot's reads visible in `Claims-Test`.** Dataverse auditing never logs a
      read, so the Audit summary view shows none. Reads are logged only by activity logging (the **Read
      logs** setting plus the table's single- and multiple-record settings), and those events reach Purview
      only for production environments. `Claims-Test` is a sandbox. Don't try to work around it: 05-07 KT03
      now teaches that gap instead of relying on a read event.
- [ ] **Purview Audit is on** - also Phase 5b. It is **not** always on by default: on this developer tenant
      unified audit ingestion was off (2026-10-20), and only activity after it is switched on (allow up to an
      hour) is ever searchable. Check: Purview portal → **Audit** shows no "start recording" banner.
- [ ] **Defender real-time protection for agents** is not used: 05-07 KT06 reasons it through. Since July
      2026 it needs a Microsoft Agent 365 licence. Purchase services offered no self-service trial on the
      build tenant (an admin-led trial needs Microsoft or the account team).
- [ ] **The DSPM transcript role** - `pwsh setup/scripts/07c_provision_purview_roles.ps1` (Phase 8b). 05-07 KT04
      reads the chat's **interaction record** in **DSPM for AI → Activity explorer** (user, agent, time,
      resources); the prompt and response text is optional. Global Reader shows the record; the text needs
      Purview's **Data Security AI Content Viewers**, which 07c gives each lab account (`student<NN>.<estate>`).
      Role-group membership needs Organization Management, which the lab app can't hold, so 07c asks for
      **one device-code approval** from a Global Administrator. `-Remove` after the delivery.
      **Check it as an attendee:** after the Exercise 04 rehearsal chat, open the interaction in Activity
      explorer. The record (user, agent, resources) must show; that is what KT04 needs. Note whether
      **Interaction details** shows text or *"We couldn't retrieve this prompt and response"* - in the build
      tenant it never showed text, even with the role in place for hours ([errata → Phase 8b](runbook-errata.md)),
      so tell the room the transcript is optional and expect it to be unavailable.
      Microsoft retires *DSPM for AI (classic)* on 30 November 2026; check the step's wording against the
      portal before a later delivery.
- [ ] **Attendees read audit records, not claims.** 05-07 KT03 sends each attendee to `Claims-Test`'s **Audit
      summary view** to see that it shows no read. Phase 8b's lab role carries `prvReadRecordAuditHistory`,
      `prvReadAuditSummary` and `prvReadQuery` for that (`_access_model.ps1`); it still has no read on claims,
      so the attendee can't open the claim itself - Scenario D depends on that.

**04-04 has no test claim.** Claims Copilot's only tools are *List claims* and *List customers* - its
instructions mention status updates, but it has no update tool - so no test claim is designated. Tell the
room the write half of Scenario D is reasoned, not exercised.

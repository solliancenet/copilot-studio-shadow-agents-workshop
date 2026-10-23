# Attendee accounts (Phase 8b): what they get and why

Reference for [RUNBOOK → Phase 8b](../setup/RUNBOOK.md#phase-8b--lab-attendee-accounts). The decisions are
ADR-0004 (a licence each), [ADR-0024](adr/0024-attendees-are-power-platform-admins.md) (Power Platform
Administrator), ADR-0025–0027 (licences, teardown, the Dataverse access model).

Accounts are estate-scoped (`student01.<estate>@<domain>`), so two facilitators can run deliveries in one
tenant. The run prints a handout table and writes `setup/lab-users-<estate>.local.csv` — **plaintext
passwords, gitignored; delete it afterwards**. Re-running is safe: existing accounts are left alone and their passwords are carried forward from the
previous handout (the script cannot read one back from Entra).

It also consents **Graph Explorer** tenant-wide for a few read scopes (`User.Read.All`, `AuditLog.Read.All`,
`Application.Read.All`, `AgentIdentity.Read.All`; the list is `$GraphExplorerScopes` in `_access_model.ps1`).
01-02, 02-01 and 06-01 send attendees there, and each of those reads is admin-consent-only: without the grant
the query answers `Authorization_RequestDenied`. The grant is shared by every estate, so `-Destroy` leaves it.

**Attendees get four Entra directory roles (`$DirectoryRoles` in `_access_model.ps1`), and enrol MFA at
first sign-in:**

| Role | Serves |
|---|---|
| `Power Platform Administrator` | the `/scopes/admin/` connection reads (Task 01-01) |
| `AI Reader` | Microsoft 365 admin center → Agents (Agent 365): 01-01 KT01 s3, 02-01 KT01 s1, 04-06 KT01 s1, 05-05 KT01. Without it the Agents page is missing from the nav |
| `Security Reader` | Entra Conditional Access policies (05-04 KT01) and the Defender portal's Alerts, Incidents and AI agents (05-07) |
| `Global Reader` | Purview Information Protection and DSPM for AI (05-06, 05-07) |

Only Power Platform Administrator can write. Task 01-01 has attendees enumerate an environment's
connections, and only the tenant-admin endpoints under `/scopes/admin/` can do that. Nothing weaker
reaches them - verified live 2026-10-13:

| Weaker option | Result |
|---|---|
| `Global Reader` | **404 `CRMRequestFailed`** where a tenant admin gets `200`. The endpoint hides itself from an unauthorized caller rather than returning `403`, so the attendee sees an empty estate, not an error. |
| A per-environment role | No help. The maker-facing connections API is caller-scoped: a maker owning 1 of an environment's 2 connections sees exactly that one; members owning none see zero. |

**Tell attendees to bring an authenticator app.** Holding a tenant admin role means Entra asks each of
them to register MFA on their first sign-in. That is the point, not a snag: it is what gives them the
Entra, Microsoft 365 and Exchange admin centers the labs use. It costs about two minutes each, once.

> {: .important }
> **Do not try to avoid this with a Conditional Access exclusion.** An earlier design excluded these
> accounts from `CA-Require-MFA-Admins` so a handed-out password alone would work. It buys **PPAC and
> nothing else**: Entra, Microsoft 365 and Exchange admin centers enforce MFA for admin portals through
> *Microsoft's* policy, which tenant Conditional Access cannot exclude. Verified by signing a lab account
> into each - all three answer *"Let's keep your account secure"*, with no skip offered. Enrolling is
> strictly better: every portal comes back, and `CA-Require-MFA-Admins` is left intact.
>
> `-ExcludeFromAdminMfa` restores the old behaviour for a delivery that genuinely cannot use authenticator
> apps - and as of 2026-10-17 it buys **the PPAC shell and nothing more**: every data call then fails with
> *"Sign in required - AADSTS50076: you must use multi-factor authentication"* (the Power Platform API), and
> Copilot Studio fails the same way. Microsoft requires MFA for the admin APIs as well as the portals, and
> tenant Conditional Access cannot exclude it. Treat the switch as inoperative; attendees enrol.

> {: .caution }
> **An attendee account is a tenant-wide Power Platform admin.** It can change or delete any environment in
> the tenant, including another facilitator's estate. Give a delivery its own tenant where you can, and run
> `-Destroy` the moment it ends.

**Attendees also get Dataverse access inside each estate environment, defined by an access model.**
Power Platform Administrator is a **tenant** role and grants nothing inside a Dataverse environment, and
most of the day's tasks read something that lives there: a security role's scope (03-02, 03-04), an
agent's Knowledge, Topics, Tools and Connection Settings in Copilot Studio (01-01, 01-02, 02-01..03, all of
Exercise 04). So the script assigns two roles in each of the estate's three Dataverse environments:

- **`Lab Reviewer (read-only)`**, a custom role it creates and **reconciles on every run to exactly the
  privileges listed in `setup/scripts/_access_model.ps1`** - every one of them `prvRead*`, every one tied to
  the exercise step that needs it. Anything on the role that the model does not list is removed (Dataverse's
  own unremovable baseline is recognised and reported, not treated as drift). `-KeepExtraPrivileges` reports
  instead of removing.
- **`Bot Viewer`**, Microsoft's built-in role, assigned alongside. The two are needed together: Copilot
  Studio needs bot reads at *Global* depth (the agents belong to the personas, not the attendee), which the
  custom role carries, **and** reads of connection references, AI plugins, workflows and solutions at the
  depths Copilot Studio expects, which `Bot Viewer` carries. Either alone fails - verified one at a time.

Never System Administrator, which would hand every attendee write access to the estate they are reviewing.
The reviewer stance - observe the shared estate, change nothing - holds; attendees change only their own
slice (Phase 8c), where they *are* System Administrator. `-NoDataverseRole` skips all of it.

Extend the model from an exercise's requirement, never from a failing probe. Three exercises in a row (03-02,
03-04, Exercise 04) had their live path blocked because the role had been sized for 01-02 and grown
reactively; the preflight now fails before a delivery if an environment's role has drifted from the model.

Two things that bite here, both verified:

- **Create the accounts well before the delivery.** Group membership takes time to reach Conditional
  Access. An account minutes old can fail its first sign-in with `AADSTS50079` on Dataverse-backed pages,
  then work fine later.
- **A re-run carries passwords forward, but cannot invent one.** An account that already exists is left
  alone and its password is read back from the previous handout. If that file is gone, the row says so -
  reset the password or destroy and recreate rather than guessing.


**Exercise 04 chat needs a seat, and each agent needs its Teams channel added.** Attendees drive Benefits
Buddy, Claims Copilot and Expense Helper with their own account, and send Policy Lookup Bot one benign
lookup (04-05 KT02 s2). The agents authenticate with Microsoft,
so the only channel is **Microsoft 365 and Microsoft Teams** (the *Make agent available in Microsoft 365
Copilot* option is greyed out on this tenant) - and Teams refuses an unlicensed account outright (*"You
don't have the required permissions to access this org"*, verified 2026-10-17). Phase 6 adds that channel
for every agent marked `teamsChannel` in the manifest and reads each agent's **install link** (Channels →
*Microsoft 365 and Microsoft Teams* → **Availability options** → **Copy link**) into
`setup/teams-links-<estate>.local.csv`. Those are the links Exercise 04 says the facilitator hands out. They
work for users the agent is shared with, which 07 arranges by adding attendees to `All-Employees-<estate>`;
the attendee sees an **Add** dialog, then the chat. A plain chat link (`/l/chat/0/0?users=28:<app id>`) is
refused: *"You do not have permission to use this app here"* (verified as student03, 2026-10-19).

**Each attendee needs a licence** ([ADR-0004](adr/0004-one-licence-per-attendee.md); [PLANNING item
15](../PLANNING.md)): Exercise 04's Teams chat, 05-07's `CopilotInteraction` events and the access model all
depend on one. Verified 2026-10-17 with three accounts holding the identical access model: the one with an E5
seat (`accessmode=0`) opened the PPAC role editor and the Copilot Studio agent pages; the two without
(`accessmode=1`, Administrative) got *"You don't have permission to view these items."* Administrative access
mode **filters** a custom role's privileges. What survives filtering is System Administrator - so an
unlicensed attendee can do those steps only in **their own slice** (Phase 8c), never in the shared estate.
Without seats, the steps that read a role or an agent's configuration in the shared estate fall back to the
artifact pack: the Copilot Studio parts of 01-01 KT02 s6, 01-02, 01-03, 02-01..03, 03-01, 03-02 KT02 s2 and
03-04; Exercise 04's configuration reads (04-01..06) and 04-03 KT02 s2's role editor in Claims-Test; and 05-01
KT02 s2, 05-03 KT01 s1, 05-04 KT06 s2. The role editor in 03-02 and 03-04 already routes to the slice. Entra
reads, PPAC lists and the admin APIs work either way.

The script attempts assignment, never fatally, and the end-of-run table reports who got one - so an attendee
without a seat is a delivery decision you make, not a surprise: they take the artifact-pack route for those
tasks. **Licence attendees the day before**: Dataverse keeps its own copy of licence state and re-reads it
hours later, in both directions - an account licensed that morning still reports unlicensed, and one created
unlicensed reports *licensed* for about an hour, so a rehearsal can pass and the delivery fail. The
preflight checks `accessmode` per attendee. The build tenant's 25 E5 seats were held by estate personas,
admins and 14 unused Microsoft sample users; the sample users' seats were released
(`setup/licence-restore-2026-10-14.local.json` is the undo), so up to 14 attendees can be licensed - size
the delivery to that.
`FLOW_FREE` does nothing for Dataverse.

Why this role and not something weaker:
[ADR-0024](adr/0024-attendees-are-power-platform-admins.md); licences, teardown and the access model:
[ADR-0025](adr/0025-attendee-licences-best-effort.md), [ADR-0026](adr/0026-attendee-teardown-purges.md),
[ADR-0027](adr/0027-attendee-dataverse-access-model.md).


**Attendees hold no Exercise 05 write role.** Exercise 05 is demonstrated: you apply each control to the
shared estate and restore it (RUNBOOK → During delivery), and attendees retest. An older kit made attendees PIM-eligible for AI
Administrator and Security Administrator; 07 withdraws both on its next run (`$RetiredEligibleRoles`).
Why: Security Administrator,
[errata → Review fixes to this branch](runbook-errata.md#review-fixes-to-this-branch-2026-10-19);
AI Administrator,
[errata → Exercise 05 is demonstrated](runbook-errata.md#delivery--exercise-05-is-demonstrated-not-done-by-attendees-2026-10-19).

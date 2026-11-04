# Building many estates (one per attendee)

The scripted alternative to walking [RUNBOOK](../setup/RUNBOOK.md) Phases 2–8c by hand, once per estate.

When each attendee gets their own estate (issue #30), build them with `10_build_estates.ps1` instead of
walking Phases 2–8c by hand. It runs each phase's script in order, as the RUNBOOK does, logs and times each one under
`setup/build-logs/<estate>/` (gitignored), stops at the first failure, and gives the admin System
Administrator in the estate's Developer environment (Phase 7's prerequisite, via `dev.kim`, no device code).
It ends with the estate's attendee: the account `student01.<estate>` (Phase 8b, no seat yet) and its slice
`Lab-<estate>-01` (Phase 8c). `-Attendees <N>` makes more. Phases 0 and 1 must be done first.

```bash
pwsh setup/scripts/10_build_estates.ps1 -Estates fac01                       # one estate (about 47 min; Phase 6 is most of it)
pwsh setup/scripts/10_build_estates.ps1 -Estates fac02,fac03 -ReclaimSeats   # several, seats reclaimed after each
pwsh setup/scripts/10_build_estates.ps1 -Estates fac02 -From agents          # resume at a phase after a failure
pwsh setup/scripts/10_build_estates.ps1 -Estates fac01 -ReclaimOnly          # only take the persona seats back
pwsh setup/scripts/10_build_estates.ps1 -Estates fac01 -From users           # just the attendee account and slice
```

- **Seats.** A build licenses the estate's eight personas (ADR-0009) and checks they're free first.
  `-ReclaimSeats` takes them back afterwards so the next estate - and, the day before the delivery, the
  attendees - can use them. The published agents keep answering without the owners' seats (errata:
  *An agent owner without a seat*); an owner without a seat can't open Copilot Studio, so re-run Phase 2
  for that estate before changing its agents.
- **Purview's transcript role** (RUNBOOK Phase 8b step 3) needs one device-code approval as the admin; pass
  every estate so that one approval covers them all: `07c_provision_purview_roles.ps1 -Estates fac01,stu01,...`.
- **Attendee seats.** The builder (including `10_build_estates.ps1 -From users`) runs 07 with `-NoLicense`,
  so the attendee account gets NO seat from the builder. Seat one directly, without `-NoLicense`, the day
  before the delivery once the persona seats are reclaimed (RUNBOOK Phase 8b):
  `pwsh setup/scripts/07_provision_lab_users.ps1 -Estate <id> -Count 1`.
  When the tenant is at 25 of 25 E5 seats (`DEVELOPERPACK_V2_E5`), free one first from a previous
  delivery's attendee account: check its last sign-in (Graph beta `users` `signInActivity`) shows that
  delivery is over, then remove its licence (Graph `POST /users/<upn>/assignLicense` with
  `removeLicenses: [<E5 skuId>]`). Removing another account's licence is the facilitator's decision.
- **Phase 4c** usually reports the label not yet in SharePoint: re-run it hours later with
  `-From purview -To purview`. That throws unless `ENTRAID_APP_ID`, `HALCOURT_PNP_CERT_PFX` and
  `HALCOURT_PNP_CERT_PW` are exported (the builder checks at `10_build_estates.ps1` line ~69):
  ```bash
  export ENTRAID_APP_ID=$(jq -r .appId setup/pnp-app.local.json) HALCOURT_PNP_CERT_PFX=setup/pnp-app.local.pfx HALCOURT_PNP_CERT_PW=$(jq -r .pfxPassword setup/pnp-app.local.json)
  ```
- **Teams links.** If Phase 6 reports no Teams install link for an agent (the channel step timed out),
  recover with
  `pwsh setup/scripts/06_provision_agents.ps1 -Estate <id> -Agents <slug>,<slug> -SkipConnections`.
  It adds the channel, republishes that agent and writes the link to `setup/teams-links-<id>.local.csv`.
  Copying by hand (Channels > Teams > Availability options > Copy link) is the fallback. Verified
  2026-11-03 on estate `db` for `benefits-buddy` and `expense-helper`.
- **Check each estate** before the delivery with the preflight and the Teams chat probe (*Before delivery*),
  chatting as Jordan Blake on a lent seat if the personas' seats were reclaimed.
- **Handing an estate to a lab developer (self-paced).** The builder does not create the facilitator
  account; run `pwsh setup/scripts/07b_provision_facilitator.ps1` with `HALCOURT_ESTATE=<id>` (the password
  goes to `setup/lab-facilitator-<id>.local.csv`). For Exercise 05-03 the developer also needs:
  (a) ownership of the M365 group `HR Benefits (<id>)`, which owns the `HR-Benefits-<id>` site (Scenario B
  changes the Leadership folder as site owner); add via Graph `POST /groups/<id>/owners/$ref`; and
  (b) a tenant-admin role such as Global Administrator on the facilitator account, to run
  `09_ex05_demo_state.ps1` and `09b_ex05_scoped_claims_role.ps1` from the dev container with the repo's
  az profile (those scripts run as the az sign-in). The developer enrols MFA themselves at first sign-in,
  so the authentication codes are theirs. Teardown: `07b_provision_facilitator.ps1 -Destroy`. A standing
  Global Administrator on a lab account is a deliberate trade-off for a lab tenant; remove it with the
  account.

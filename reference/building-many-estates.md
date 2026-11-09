# Building the three estates (dev, stg, prd)

The scripted alternative to walking [RUNBOOK](../setup/RUNBOOK.md) Phases 2–8c by hand, once per estate.
Why there are three: [ADR-0032](adr/0032-dev-stg-prd-estates.md).

`10_build_estates.ps1` builds estates instead of walking Phases 2–8c by hand. It runs each phase's script in
order, as the RUNBOOK does, logs and times each one under `setup/build-logs/<estate>/` (gitignored), stops at
the first failure, and gives the admin System Administrator in the estate's Developer environment (Phase 7's
prerequisite, via `dev.kim`, no device code). It ends with the estate's attendee: the account
`student01.<estate>` (Phase 8b, no seat yet) and its slice `Lab-<estate>-01` (Phase 8c). Phases 0 and 1
must be done first.

```bash
pwsh setup/scripts/10_build_estates.ps1 -Estates dev,stg,prd -ReclaimSeats   # all three, seats reclaimed after each (about 47 min each; Phase 6 is most of it)
pwsh setup/scripts/10_build_estates.ps1 -Estates prd -From agents            # resume at a phase after a failure
pwsh setup/scripts/10_build_estates.ps1 -Estates prd -ReclaimOnly            # only take the persona seats back
pwsh setup/scripts/10_build_estates.ps1 -Estates prd -From users             # just the attendee account and slice
```

- **When.** Build stg and prd days before a delivery: Phase 4c's label can take a day to reach SharePoint.
- **What each estate gets.** The builder gives every estate one attendee account and its slice. In dev that
  account is for trying a change as an attendee; in stg it is a rehearsal account (add a second with
  `-Estates stg -From users -Attendees 2`); in prd it is the first of the delivery's accounts. The rest of prd's accounts and slices
  are made the day before the delivery (RUNBOOK Phases 8b and 8c).
- **Seats.** A build licenses the estate's eight personas (ADR-0009) and checks they're free first.
  `-ReclaimSeats` takes them back afterwards so the next estate - and, the day before the delivery, the
  attendees - can use them. The published agents keep answering without the owners' seats (errata:
  *An agent owner without a seat*); an owner without a seat can't open Copilot Studio, so re-run Phase 2
  for that estate before changing its agents.
- **Purview's transcript role** (RUNBOOK Phase 8b step 3) needs one device-code approval as the admin; pass
  both estates with attendee accounts so that one approval covers them:
  `07c_provision_purview_roles.ps1 -Estates prd,stg`.
- **Attendee seats.** The builder (including `10_build_estates.ps1 -From users`) runs 07 with `-NoLicense`,
  so its attendee accounts get NO seat. prd's accounts get theirs the day before the delivery, once the
  persona seats are reclaimed, when RUNBOOK Phase 8b runs 07 without `-NoLicense`:
  `pwsh setup/scripts/07_provision_lab_users.ps1 -Estate prd -Count <N>`. A stg rehearsal account that needs
  Teams or Copilot Studio gets one the same way: `-Estate stg -Count 1`.
  The tenant has 25 E5 seats (`DEVELOPERPACK_V2_E5`); every seated account counts. When it is full, free one
  from a previous delivery's attendee account: check its last sign-in (Graph beta `users` `signInActivity`)
  shows that delivery is over, then remove its licence (Graph `POST /users/<upn>/assignLicense` with
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
- **Check prd** before the delivery with the preflight and the Teams chat probe (RUNBOOK *Before delivery*),
  and stg when you rehearse. Chat as Jordan Blake on a lent seat if the personas' seats were reclaimed.

## Promoting a change

Develop and try a change in dev. Then re-run the changed phase's script with `-Estate stg`, rehearse, and
re-run it with `-Estate prd`. For an agent:

```bash
pwsh setup/scripts/06_provision_agents.ps1 -Estate stg -Agents <slug>
pwsh setup/scripts/06_provision_agents.ps1 -Estate prd -Agents <slug>
```

A re-run only adds what is missing. It creates a new agent, topic, flow or row, but leaves an existing one as
it was: `Ensure-Flow` passes over an active flow, a removed topic stays unless 06 lists it as retired, and
Phase 5 skips the tables, columns and seed rows it finds. A change to something that already exists needs
its own update step, or a remove-and-recreate, worked out in dev and recorded with the change. Otherwise the
promotion reports success and changes nothing.

## Moving off the per-person estates

The tenant built in 2026-10 holds an estate per person (`stu01`–`stu20`, `fac01`–`fac03`, and others such
as `db`). Their ids are in every name they created, so none can be renamed into dev, stg or prd.

1. **Check nobody still uses an estate,** for example one handed to a lab developer, before tearing it down.
2. **Tear each one down** with RUNBOOK Phase 9, steps 1 to 7, with `HALCOURT_ESTATE` set to its id. Step 1
   takes them all under one approval: `07c_provision_purview_roles.ps1 -Estates fac01,stu01,... -Remove`.
3. **Build the three** with the first command above.

## Handing an estate to a lab developer (self-paced)

The builder does not create the facilitator account; run `pwsh setup/scripts/07b_provision_facilitator.ps1`
with `HALCOURT_ESTATE=<id>` (the password goes to `setup/lab-facilitator-<id>.local.csv`). For Exercise 05-03
the developer also needs:

- ownership of the M365 group `HR Benefits (<id>)`, which owns the `HR-Benefits-<id>` site (Scenario B
  changes the Leadership folder as site owner); add via Graph `POST /groups/<id>/owners/$ref`; and
- a tenant-admin role such as Global Administrator on the facilitator account, to run
  `09_ex05_demo_state.ps1` and `09b_ex05_scoped_claims_role.ps1` from the dev container with the repo's az
  profile (those scripts run as the az sign-in).

The developer enrols MFA themselves at first sign-in, so the authentication codes are theirs. Teardown:
`07b_provision_facilitator.ps1 -Destroy`. A standing Global Administrator on a lab account is a deliberate
trade-off for a lab tenant; remove it with the account.

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
- **Attendee seats** come the day before the delivery, once the persona seats are reclaimed: re-run
  `07_provision_lab_users.ps1 -Count 1` (without `-NoLicense`) per estate (RUNBOOK Phase 8b).
- **Phase 4c** usually reports the label not yet in SharePoint: re-run it hours later with
  `-From purview -To purview`.
- **Check each estate** before the delivery with the preflight and the Teams chat probe (*Before delivery*),
  chatting as Jordan Blake on a lent seat if the personas' seats were reclaimed.

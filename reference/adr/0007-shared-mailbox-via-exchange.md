# ADR-0007: The `it.helpdesk` shared mailbox is created through Exchange with the az sign-in

**Status:** Accepted
**Applies to:** `setup/RUNBOOK.md` → Phase 2 and Phase 6, `setup/scripts/01_provision_entra.ps1`,
`setup/scripts/_auth.ps1` (`Connect-LabExchange`)

## Context

`it.helpdesk` is the ambiguous owner of Policy Lookup Bot, so it must be a shared mailbox — a mailbox no one
person owns. Graph can't create shared mailboxes; only Exchange Online can.

## Decision

`Connect-ExchangeOnline` accepts a delegated access token, so `Connect-LabExchange` reuses the same `az`
sign-in as the rest of Phase 2 — no device code, no app-only Exchange app — and the script runs:

```powershell
New-Mailbox -Shared -Name "IT Helpdesk (<estate>)" -Alias it.helpdesk.<estate> -PrimarySmtpAddress it.helpdesk.<estate>@<domain>
```

`-Alias` is required: without it Exchange derives an alias from the name, and the account isn't
`it.helpdesk.<estate>@…`.

## Consequences

- Exchange creates the account **disabled for sign-in**, like every shared mailbox. Phase 6 turns sign-in on
  so it can own the agent.
- Exchange provisions it asynchronously; it can take a minute to appear.
- The admin must be an Exchange admin. If the automatic step can't run (no `az` session, no role), the
  script warns and prints the same command to run after `Connect-ExchangeOnline -Device`; Phase 2 carries
  on, because only Phase 6 needs the mailbox.

## Alternatives considered

- **An app-only Exchange app registration.** Another app and certificate to manage per tenant, for one
  command.
- **A regular user as the owner.** Loses the point: ownership by a mailbox nobody signs in to is the
  planted ambiguity.

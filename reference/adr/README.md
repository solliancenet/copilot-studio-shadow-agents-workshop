# Architecture decision records

One decision per file, numbered in the order they were written. Each record says what was decided, why,
and what it costs. The [RUNBOOK](../../setup/RUNBOOK.md) stays a list of steps and links here for the why.

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-estates.md) | Every live build is an estate, and every name it creates carries the estate id | Accepted |
| [0002](0002-shared-vs-individual-estates.md) | Attendees share one estate; facilitators build individual estates | Superseded in part (estate per person, #30) |
| [0003](0003-project-local-sign-in.md) | CLI sign-ins live in the repo, not your home folder | Accepted |
| [0004](0004-one-licence-per-attendee.md) | One Microsoft 365 E5 licence per attendee | Accepted (licensing open) |
| [0005](0005-shared-azure-deployment.md) | One shared Azure deployment for every estate | Accepted |
| [0006](0006-personas-on-the-tenant-domain.md) | Personas live on the tenant's own domain; aliases stay fixed | Accepted |
| [0007](0007-shared-mailbox-via-exchange.md) | The `it.helpdesk` shared mailbox is created through Exchange with the az sign-in | Accepted |
| [0008](0008-departed-owner-stays-enabled.md) | The departed owner stays enabled; his departure is a leave date | Accepted |
| [0009](0009-eight-licences-per-estate.md) | Eight E5 licences per estate | Accepted |
| [0010](0010-ca-baseline-replaces-security-defaults.md) | A Conditional Access baseline replaces security defaults | Accepted |
| [0011](0011-device-code-sign-in-and-org-consent.md) | Scripts reuse the az sign-in, fall back to device codes, and use org-wide Graph consent | Accepted |
| [0012](0012-azd-environment-per-estate.md) | The azd environment name is unique per estate | Superseded by 0005 |
| [0013](0013-environment-region-assigned.md) | Environments take the region the platform assigns | Accepted |
| [0014](0014-shared-billing-plan-per-region.md) | Estates share one billing plan per region | Accepted |
| [0015](0015-copilot-studio-authors-setting-optional.md) | The *Copilot Studio authors* tenant setting is optional | Accepted |
| [0016](0016-pnp-app-registration.md) | PnP gets its own app registration, with delegated and application permissions | Accepted |
| [0017](0017-maker-provisions-own-onedrive.md) | The maker provisions their own OneDrive | Accepted (verify) |
| [0018](0018-svc-claims-licensed-e5.md) | `svc-claims` is licensed, and E5 is enough | Accepted |
| [0019](0019-dataverse-business-keys.md) | Dataverse tables keep business keys in `…number` columns | Accepted |
| [0020](0020-agents-provisioned-clone-first.md) | Agents are provisioned clone-first from committed workspaces | Accepted |
| [0021](0021-planted-mechanisms-in-topics.md) | Planted HTTP, MCP and flow calls live in topics | Accepted |
| [0022](0022-artifact-export-over-rest.md) | The artifact-pack export reads over REST with the az sign-in | Accepted |
| [0023](0023-committed-pack-not-pure-export.md) | The committed artifact pack is canonical, not a pure export | Accepted |
| [0024](0024-attendees-are-power-platform-admins.md) | Attendee accounts are Power Platform Administrators, excluded from admin MFA | Accepted |
| [0025](0025-attendee-licences-best-effort.md) | Attendee licence assignment is best effort | Accepted |
| [0026](0026-attendee-teardown-purges.md) | Attendee teardown purges, not just deletes | Accepted |
| [0027](0027-attendee-dataverse-access-model.md) | Attendee Dataverse access is a declared access model | Accepted |
| [0028](0028-planted-governance-gaps.md) | DLP on Prod only, and no Conditional Access for agent identities | Accepted |
| [0029](0029-purview-app-only-identity.md) | Purview runs app-only, through one lab compliance app | Accepted |
| [0030](0030-audit-claim-changes-only.md) | Audit claim changes only; no read logs | Accepted |
| [0031](0031-no-defender-realtime-protection.md) | Defender real-time protection for agents is not exercised in KT06 | Accepted (amended 2026-10-26) |

# ADR-0006: Personas live on the tenant's own domain; aliases stay fixed

**Status:** Accepted
**Applies to:** `setup/RUNBOOK.md` → Phase 2, `setup/scripts/01_provision_entra.ps1`, every later script
that finds an account

## Context

`AGENTS.md`, the artifact pack and the lab pages write every UPN as
`<alias>@halcourtmutual.onmicrosoft.com`. A lab tenant keeps whatever domain Microsoft assigned it — a Dev
Program sandbox gets something like `a1b2c3d4.onmicrosoft.com` — and an `*.onmicrosoft.com` domain can't be
added to another tenant, so the canonical domain is unavailable.

## Decision

`01_provision_entra.ps1` puts every account on the tenant's **default verified domain**:
`<alias>.<estate>@<tenant domain>`, display name `<name> (<estate>)` ([ADR-0001](0001-estates.md)). It
prints the mapping before it creates anything:

```text
Estate: jsmith   Persona domain: <tenant domain>
  canon <alias>@halcourtmutual.onmicrosoft.com  ->  live <alias>.jsmith@<tenant domain>
```

`-DomainSuffix <domain>` picks another domain, but only one the tenant has verified; anything else stops
the script before it creates an account.

What stays fixed is the **alias** — `ana.reyes`, `svc-claims`, `it.helpdesk`, … The later scripts find
accounts by alias + estate on the tenant's domain, so aliases are canon: never repurpose another account
(a content-pack sample user, say) as a persona.

## Consequences

- Live UPNs differ from the canon in both the estate id and the domain. The pack and pages stay canonical;
  `05_export_artifact_pack.ps1 -Canonicalize` maps back.
- Attendees need the tenant domain along with the estate id (Phase 0b).

## Alternatives considered

- **Add `halcourtmutual.onmicrosoft.com` to the tenant.** Impossible: `*.onmicrosoft.com` domains belong to
  the tenant that owns them.
- **Buy and verify a custom domain.** Works, but costs money and DNS setup per tenant for no exercise
  benefit.

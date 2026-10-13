# RUNBOOK.md — Facilitator provisioning

> **FACILITATOR-ONLY. Not published** (the whole `setup/` folder is excluded in `_config.yml`).
> Provisions the intentionally-vulnerable **Halcourt Mutual** demo estate. Everything here is keyed to the
> canon in [`../AGENTS.md`](../AGENTS.md) — that file is the source of truth; this file is how you build it.
>
> **This file is the instructions.** The reasoning lives in
> [`../reference/runbook-decisions.md`](../reference/runbook-decisions.md) (why it is built this way,
> tradeoffs, manual alternatives) and [`../reference/runbook-errata.md`](../reference/runbook-errata.md)
> (what goes wrong, troubleshooting, open `[verify]` risks). Each phase links to its own section there.

A single **shared demo tenant** hosts the live estate for the BREAK (Module 4) and CONTROL (Module 5)
demos; attendees get a guest/read account (Ana Reyes) plus the low-priv **Jordan Blake** path. An
**artifact pack** (five CSVs in `../worksheets/artifact-pack/`) is exported from that estate so the
DISCOVER / MAP / threat-model / ASSESS work runs offline. The committed pack is the **canonical** one;
re-run [Phase 7](#phase-7--export-the-artifact-pack) after the estate changes to see what has drifted —
but read the caveat there before regenerating it, because parts of the pack are hand-written and an export
cannot reproduce them.

{: .important }
> The estate is deliberately broken. Provision it in an **isolated training tenant** you control. Never
> point these scripts at a production tenant.

## Estates: several builds in one tenant

Each build is an **estate** with its own id, and every name it creates carries that id — so several
facilitators can build Halcourt Mutual in one tenant without colliding.

| What | Canonical (AGENTS.md, lab pages, artifact pack) | Live, estate `mgray` |
|---|---|---|
| Accounts | `marcus.webb@halcourtmutual.onmicrosoft.com` | `marcus.webb.mgray@<tenant domain>`, "Marcus Webb (mgray)" |
| Groups, environments, DLP, sites | `Halcourt-Makers`, `Claims-Test`, `Halcourt-Prod-DLP`, `HR-Benefits` | `Halcourt-Makers-mgray`, `Claims-Test-mgray`, `Halcourt-Prod-DLP-mgray`, `HR-Benefits-mgray` |
| Agents in the default environment | `Expense Helper`, `Onboarding Guide` | `Expense Helper (mgray)`, `Onboarding Guide (mgray)` |
| Azure (Phase 1) | — | azd environment `halcourt-mgray-lab` |

**Shared, not renamed:** the tenant's default environment (`Halcourt (default)`) and the Conditional
Access baseline (Phase 0). The rule is in `AGENTS.md` → *Live estate naming*; `setup/scripts/_estate.ps1`
implements it.

**Pick your id once** — your alias, 2–12 lowercase letters or digits — check nobody uses it, then set it in
every shell you build from. Each script reads it, takes `-Estate <id>` instead, and refuses to run with
neither:

```bash
az ad user list --filter "startswith(userPrincipalName,'ana.reyes.')" --query "[].userPrincipalName" -o tsv
export HALCOURT_ESTATE=mgray          # bash / the dev container
```

```powershell
$env:HALCOURT_ESTATE = 'mgray'       # PowerShell
```

Give attendees the estate id along with the tenant domain — Lab 00 tells them to expect the suffix.
Why: [decisions → Estates](../reference/runbook-decisions.md#estates).

## Prerequisites (technician)

**The dev container (`.devcontainer/`) installs all of it, and every phase runs there** — no step needs
Windows any more.

- Azure CLI (`az`) + Bicep and the Azure Developer CLI (`azd`) for Phase 1, plus an Azure subscription for
  the Container Apps.
- Power Platform CLI (`pac`) — the .NET tool build, which needs the .NET 10 SDK.
- PowerShell 7 with `Microsoft.Graph`, `PnP.PowerShell` and `ExchangeOnlineManagement`.
- `pandoc` — Phase 4 builds the planted `.docx` from Markdown; without it the script uploads the raw `.md`
  with the payload visible.
- **Playwright + Chromium** for Phase 6's headless connection consent. Outside the container:
  `pip install playwright && python3 -m playwright install --with-deps chromium`.

`az` and `pac` sign-in state is project-local (`.azure/`, `.pac/` in the repo root). That applies
automatically in a VS Code terminal on this repo and in the dev container; in any other shell run
`source scripts/env.sh` first, or the scripts won't see your login.

### Windows build VM (optional)

Only needed if you want a desktop browser for interactive sign-in and MFA — every script itself runs on
Linux. `setup/windows-vm/` runs Windows 11 in Docker ([dockur/windows](https://github.com/dockur/windows),
QEMU/KVM) and installs the whole toolchain on first boot. It always runs on the **host's** Docker; the dev
container only drives it.

| Host | Needs |
|---|---|
| Linux | Docker Engine + Compose v2; CPU virtualization on in BIOS; `/dev/kvm` present (`sudo kvm-ok`) |
| Windows 11 | Docker Desktop, WSL 2 backend, **Linux containers** mode; nested virtualization (on by default) |

Not supported: Windows 10 hosts and macOS. Budget 8 GB RAM, 4 cores, 64 GB disk.

```bash
docker run --rm --device /dev/kvm alpine ls -l /dev/kvm       # check KVM first; prints a /dev/kvm line
docker compose -f setup/windows-vm/compose.yaml up -d         # start, from the repo root
docker compose -f setup/windows-vm/compose.yaml stop          # shut down, keep the disk
docker compose -f setup/windows-vm/compose.yaml down -v       # delete the VM and its disk
```

Watch the install at http://localhost:8006 or RDP to `localhost:3389` (user `halcourt`, password
`Lab-Only-Passw0rd!`) — both bound to localhost only. The first start downloads Windows 11 Enterprise
evaluation (~7 GB, 90 days) and installs it unattended: allow 20–40 minutes, then
`setup/windows-vm/oem/bootstrap.ps1` installs the toolchain and logs to `C:\OEM\bootstrap.log`. Re-run it
from an elevated prompt if it failed (usually network).

The repo is drive `Z:`. Sign-in state lives in the Windows user profile, separate from the dev container's
`.azure/` and `.pac/`, so sign in to the lab tenant again inside the VM; `azd` environments live in the
repo's `.azure/` and are shared. Override `WINVM_RAM_SIZE`, `WINVM_CPU_CORES`, `WINVM_DISK_SIZE`,
`WINVM_USERNAME`, `WINVM_PASSWORD` or `WINVM_VERSION` in `setup/windows-vm/.env` before the first start.

## Phase order (do NOT reorder)

```
0. Provision isolated tenant   → fresh *.onmicrosoft.com, licensing, security defaults → CA baseline
1. Azure infra (Bicep)        → Policy API + Underwriting MCP endpoints
2. Entra identities/personas  → users, groups, DISABLE tom.dean
3. Environments + DLP          → 4 environments, prod DLP, PAYG billing plan
4. SharePoint seed             → HR-Benefits + Claims-Knowledge, PLANT the poisoned doc
4b. Maker OneDrive             → provision + seed dev.kim's OneDrive (Meeting Notes grounding)
5. Dataverse seed              → Claim + Customer tables, PII rows, the over-broad role
6. Author the agents           → as each owner, from the committed workspaces
7. Export the artifact pack    → regenerate ../worksheets/artifact-pack/*.csv
8. Validate                    → every planted problem reproduces; verdicts hold
8b. Lab (attendee) accounts    → per delivery: N native accounts to hand out, removed again afterwards
9. Teardown / reseed
```

---

### Phase 0 — Provision the isolated training tenant

Once per lab tenant. Mostly a portal flow.

{: .important }
> This tenant **must not** be linked to any production or corporate tenant. Sign up with a **personal or
> lab-dedicated admin credential — never corporate SSO**.

1. **Sign up for a new M365 tenant** via the **Microsoft 365 Developer Program**
   (https://developer.microsoft.com/microsoft-365/dev-program) — a 90-day renewable E5 sandbox. Choose the
   **"Instant sandbox (Add-on purchases enabled)"** variant and a **personal or lab email**. Provide an
   **Azure billing account** for the one-time verification (not charged; create it ahead of time, it can
   take hours to appear). Pick the **data-center region** at signup — it cannot be changed afterward. The
   **domain** is whatever signup assigns; that is fine, the scripts use the tenant's own. The optional
   **content pack** is fine to install, but its ~16 sample users hold seats the personas need in Phase 2.

   Variant tradeoffs, a billing account that won't appear in the dropdown, the non-Dev-Program fallback:
   [errata → Phase 0](../reference/runbook-errata.md).

2. **Complete initial tenant setup.**
   - Create the **global administrator** and record the UPN — it is the technician identity throughout.
   - **Confirm MFA is registered** on it: https://entra.microsoft.com → admin user → **Authentication
     methods**.
   - **Record the data-center region:** admin center → **Settings → Org settings → Organization profile →
     Data location**. You reuse it as `AZURE_LOCATION` in Phase 1. It is immutable.
   - Confirm the global admin holds **Power Platform, Entra, SharePoint, Purview, Conditional Access and
     Defender** access (Global Administrator covers all of these in a fresh tenant).

3. **Assign licensing.** E5 comes with the sandbox and covers the Purview features the labs use. Assign an
   E5 seat to the global admin in **Billing → Licenses**; the personas get theirs in Phase 2.

4. **Replace security defaults with the Conditional Access baseline.** Once per tenant:

   ```powershell
   pwsh setup/scripts/00_conditional_access_baseline.ps1 -TenantId <tenant-id>
   ```

   Run it from the **host** or the **Windows VM**, not the dev container — security defaults are still on
   and block the device-code sign-in the container depends on. Pick the account in the browser tab
   **within two minutes**; `Connect-MgGraph` gives up after that. The first run asks for
   `Policy.ReadWrite.ConditionalAccess` and `Policy.Read.All` — tick **Consent on behalf of your
   organization**.

   It turns security defaults off and creates the two baseline policies from `AGENTS.md`:

   | Policy | Applies to | Control |
   |---|---|---|
   | `CA-Require-MFA-Admins` | 15 admin roles — Microsoft's *Require MFA for admins* template set, plus Power Platform Administrator | Require MFA |
   | `CA-Block-Legacy-Auth` | All users | Block Exchange ActiveSync and other legacy clients |

   If creating a policy fails it rolls back and turns security defaults back on, so admins are never left
   without MFA. Safe to re-run. **Then wait ~10 minutes before the first device-code sign-in** — sign-ins
   take a while to stop seeing security defaults.

   Why the swap is mandatory and what it gives up:
   [decisions → Phase 0](../reference/runbook-decisions.md#phase-0--tenant).

5. **Consent to the Graph scopes** once, for the whole organization, as the global admin — tick **Consent
   on behalf of your organization** before **Accept**:

   ```powershell
   Connect-MgGraph -TenantId <yourlab>.onmicrosoft.com -Scopes `
     Policy.ReadWrite.ConditionalAccess, Policy.Read.All, User.ReadWrite.All, Group.ReadWrite.All, `
     User.Read.All, Application.Read.All, AuditLog.Read.All
   ```

   | Scope | Used by |
   |---|---|
   | `Policy.ReadWrite.ConditionalAccess`, `Policy.Read.All` | `00_conditional_access_baseline.ps1` (step 4) |
   | `User.ReadWrite.All`, `Group.ReadWrite.All` | `01_provision_entra.ps1` (Phase 2), `99_teardown.ps1` |
   | `User.Read.All`, `Application.Read.All` | `05_export_artifact_pack.ps1` (Phase 7) |
   | `AuditLog.Read.All` | `05_…` — its users export reads `signInActivity` |

   Check it in **Entra admin center → Enterprise applications → Microsoft Graph Command Line Tools →
   Permissions**. `pac` needs nothing granted; PnP.PowerShell gets its own app registration in Phase 4.

6. **Phase 0 verification checklist.**
   - Global admin can **sign in** to https://admin.microsoft.com with MFA satisfied.
   - **Security defaults are off** and both baseline policies are **On**.
   - **Licensing shows assigned** (E5) on the admin account.
   - **An Azure subscription is usable** and you hold **Owner** on it (or Contributor + User Access
     Administrator) — Phase 1's `azd up` creates role assignments, which Contributor can't.
   - The tooling is authenticated **against the new tenant**:

     ```bash
     az login --allow-no-subscriptions --use-device-code   # sign in as the lab global admin
     az account show                                       # confirm the new tenant id
     pac auth create --name halcourt-lab --deviceCode      # Power Platform CLI → new tenant
     pac org list                                          # "Connected as <admin>"; no Dataverse envs yet
     ```

   If a device-code sign-in fails with *AADSTS530035*, step 4 hasn't taken effect yet; until it has, sign
   in with a browser from the **host** or the **Windows VM** by dropping `--use-device-code` /
   `--deviceCode` / `-UseDeviceCode`.

### Phase 1 — Azure infrastructure (azd up)

Deploys the demo web app + Foundry, plus the internal **Policy API** and **Underwriting MCP** server as
Container Apps. The latter two are intentionally weak (static-secret auth, over-scoped surface) — see
`setup/infra/policy-api/` and `setup/infra/mcp-underwriting/`. Everything goes into the **same Azure
subscription** from Phase 0.

```bash
azd auth login --use-device-code  # skip if `azd config get auth.useAzCliAuth` says true — az login covers it

az group list --subscription <lab-subscription-id> --query "[?starts_with(name, 'rg-halcourt')].name" -o tsv   # names already used
ENV_NAME=halcourt-$HALCOURT_ESTATE-lab
azd env new "$ENV_NAME" --subscription <lab-subscription-id> --location eastus2   # RG: rg-$ENV_NAME
azd env set POLICY_API_KEY "lab-$(openssl rand -hex 8)"   # any lab-only string — RECORD it
azd env set MCP_BEARER   "lab-$(openssl rand -hex 8)"     # any lab-only string — RECORD it
azd up                            # provisions + builds/pushes all images + deploys
azd env get-values                # read POLICY_API_FQDN / UNDERWRITING_MCP_FQDN
```

- **Record both secret values as you set them** — you need them again in Phase 6. The Policy API key is
  the one that ends up hard-coded in Policy Lookup Bot (Scenario E).
- **Use an environment name nobody has used in this subscription.** `halcourt-<estate>-lab` is the
  convention; reusing a name silently redeploys another facilitator's apps, and reusing a *torn-down* name
  hits the Foundry soft-delete trap. Add a suffix (`-2`, a date) when you rebuild.
- Pass `--subscription` and `--location` explicitly — azd's global defaults can point outside the lab
  tenant. `eastus2` is tested; any region with gpt-5-mini (GlobalStandard) quota works.
- **Record the two Container App addresses.** Despite the `_FQDN` names they are full URLs; the agents'
  actions want the host part (drop `https://`).

Name derivation and the FQDN shape:
[decisions → Phase 1](../reference/runbook-decisions.md#phase-1--azure). `azd up` failures and Foundry
soft-delete: [errata → Phase 1](../reference/runbook-errata.md).

### Phase 2 — Entra identities & personas

**Prerequisites:** `Microsoft.Graph` and `ExchangeOnlineManagement`.

```powershell
pwsh setup/scripts/01_provision_entra.ps1 -TenantId <tenant-id>    # estate from HALCOURT_ESTATE (or -Estate <id>)
```

Creates the eight personas from `AGENTS.md` (Ana, Marcus, Priya, Sam, Lena, Dev, **Tom Dean** and Jordan),
the `svc-claims` service account, the `it.helpdesk` **shared mailbox**, and the four groups
(`Halcourt-Makers-<estate>`, `HR-Team-<estate>`, `Claims-Adjusters-<estate>`, `All-Employees-<estate>`)
filled per `AGENTS.md` → *Groups*. It sets each account's usage location so licenses can be assigned, but
assigns none. Safe to re-run.

Accounts are `<alias>.<estate>@<tenant domain>` — **the tenant's own domain, not the canon's**. The script
prints the mapping before it creates anything:

```text
Estate: mgray   Persona domain: 0zwdt94t.onmicrosoft.com
  canon <alias>@halcourtmutual.onmicrosoft.com  ->  live <alias>.mgray@0zwdt94t.onmicrosoft.com
```

Tell attendees the live domain and estate id with their sign-ins — Lab 00 warns them both differ from the
pages.

**Licenses.** Each estate needs **eight** E5 seats: `svc-claims` (Phase 5) and the seven agent owners —
Marcus, Priya, Lena, Dev, Tom, Sam and `it.helpdesk` (Phase 6) — because Dataverse only adds licensed
users to an environment. A sandbox has 25 and the sample users hold most. If you are short, free seats by
unassigning sample users in **M365 admin center → Billing → Licenses**; don't repurpose them as personas,
the aliases are canon.

**Tom Dean stays enabled now.** In Phase 6.5 — only *after* his shared connections exist — disable him
with `-DisableDepartedOwner` (below). Doing it earlier means the orphan isn't real.

Why the tenant domain, how the shared mailbox is created:
[decisions → Phase 2](../reference/runbook-decisions.md#phase-2--identities).

### Phase 3 — Environments and DLP

**Prerequisites:** `az`, signed in to the lab tenant. Nothing else — the script drives the Power Platform
admin API with `az`'s saved sign-in and **asks for no sign-in**.

```bash
pwsh setup/scripts/02_provision_environments_dlp.ps1    # estate from HALCOURT_ESTATE (or -Estate <id>)
```

| Creates | What |
|---|---|
| `Halcourt-Prod-<estate>` | Production + Dataverse, **Managed Environment**, `Halcourt-Prod-DLP-<estate>` |
| `Claims-Test-<estate>` | Sandbox + Dataverse — Phase 5 seeds it |
| `Maker-Sandbox-<estate>` | Developer + Dataverse, **assigned to `dev.kim.<estate>`** |
| `Halcourt (default)` | the tenant's default environment, shared by every estate — named once, by whoever runs first |

`Halcourt-Prod-DLP-<estate>` puts Dataverse, SharePoint, Office 365 Outlook and Office 365 Users in the
**business** group, scoped to this estate's Prod **only**. Default / Claims-Test / Maker-Sandbox
deliberately stay **without DLP** — that gap drives Module 5. The script waits for every Dataverse org,
then prints a summary with each environment's region and the exact Phase 5 command. Safe to re-run.

{: .note }
> **You don't choose the country** — the API assigns it from `-MacroRegion` (default `north-america`). The
> script warns if an estate's environments land in different regions; the billing plan must follow
> whatever the summary reports.

Conditional Access is already in place from Phase 0. Still create **no** CA policy targeting
workload/agent identities — that omission is a planted Module 5 finding.

**Then wire Copilot Studio pay-as-you-go billing**, after the environments exist (a plan is region-locked,
so it must match where they landed):

```bash
pwsh setup/scripts/02b_provision_billing.ps1 -Estate mgray
```

It resolves this estate's Prod and Claims-Test and their region, finds a plan in that region with the
Copilot Studio (`MCSMessages`) meter on, links both environments, and verifies. If the region has no plan
it creates the once-per-region one — that branch is `[verify]`. `Maker-Sandbox` is a Developer
environment: not linkable and not needed. Agents **publish** without a plan; a plan is what lets attendees
send them messages.

The PPAC and API equivalents, and the optional *Copilot Studio authors* tenant setting:
[decisions → Phase 3](../reference/runbook-decisions.md#phase-3--environments-dlp-billing). Region-lock and
the wrong-plan trap: [errata → Phase 3](../reference/runbook-errata.md).

### Phase 4 — SharePoint seed (plant the poisoned doc)

**Once per tenant: register the PnP app** (PnP 3.x ships no shared sign-in app). Every estate shares it;
the commands reuse it if it exists.

```bash
APP=$(az ad app list --display-name "Halcourt PnP" --query "[0].appId" -o tsv)
[ -z "$APP" ] && APP=$(az ad app create --display-name "Halcourt PnP" --sign-in-audience AzureADMyOrg \
  --is-fallback-public-client true --public-client-redirect-uris http://localhost --query appId -o tsv)
az ad app permission add --id $APP --api 00000003-0000-0ff1-ce00-000000000000 \
  --api-permissions "$(az ad sp show --id 00000003-0000-0ff1-ce00-000000000000 \
    --query "oauth2PermissionScopes[?value=='AllSites.FullControl'].id | [0]" -o tsv)=Scope"      # SharePoint
az ad app permission add --id $APP --api 00000003-0000-0000-c000-000000000000 \
  --api-permissions "$(az ad sp show --id 00000003-0000-0000-c000-000000000000 \
    --query "oauth2PermissionScopes[?value=='Group.ReadWrite.All'].id | [0]" -o tsv)=Scope"       # Graph: team sites are M365 groups
az ad sp show --id $APP >/dev/null 2>&1 || az ad sp create --id $APP
az ad app permission admin-consent --id $APP
echo "ENTRAID_APP_ID=$APP"
```

**Also once per tenant: give it an app-only identity** — three application roles plus a certificate. This
is what lets the Phase 4 seed and the Phase 4b OneDrive *seed* run headlessly.

```bash
SP=00000003-0000-0ff1-ce00-000000000000            # SharePoint Online
GRAPH=00000003-0000-0000-c000-000000000000         # Microsoft Graph
PNP_SP=$(az ad sp show --id $APP --query id -o tsv)
SP_SP=$(az ad sp show --id $SP --query id -o tsv)
GRAPH_SP=$(az ad sp show --id $GRAPH --query id -o tsv)
for ROLE in 678536fe-1083-478a-9c59-b99265e6b0d3 741f803b-c850-494e-b5df-cde7c675a1ca; do   # Sites.FullControl.All, User.ReadWrite.All
  az rest --method POST --url "https://graph.microsoft.com/v1.0/servicePrincipals/$PNP_SP/appRoleAssignments" \
    --body "{\"principalId\":\"$PNP_SP\",\"resourceId\":\"$SP_SP\",\"appRoleId\":\"$ROLE\"}" -o none
done
# Graph Group.ReadWrite.All (application) — app-only site create needs it (team sites are M365 groups).
az rest --method POST --url "https://graph.microsoft.com/v1.0/servicePrincipals/$PNP_SP/appRoleAssignments" \
  --body "{\"principalId\":\"$PNP_SP\",\"resourceId\":\"$GRAPH_SP\",\"appRoleId\":\"62a82d76-70ea-41e2-9197-370581804d09\"}" -o none
# DELEGATED User.ReadWrite.All too — the interactive admin provisioning (Phase 4b) needs it in the user token.
GID=$(az rest --method GET --url "https://graph.microsoft.com/v1.0/oauth2PermissionGrants?\$filter=clientId eq '$PNP_SP' and resourceId eq '$SP_SP'" --query 'value[0].id' -o tsv)
az rest --method PATCH --url "https://graph.microsoft.com/v1.0/oauth2PermissionGrants/$GID" \
  --body '{"scope":"AllSites.FullControl User.ReadWrite.All"}' -o none
# A certificate for app-only sign-in (public .cer uploaded to the app, .pfx kept for PnP):
openssl req -x509 -newkey rsa:2048 -keyout pnp.key -out pnp.cer -days 90 -nodes -subj "/CN=HalcourtPnP" >/dev/null 2>&1
openssl pkcs12 -export -out pnp.pfx -inkey pnp.key -in pnp.cer -passout pass:<cert-pw> >/dev/null 2>&1
az ad app credential reset --id $APP --cert @pnp.cer --append -o none
```

{: .warning }
> `az ad app permission admin-consent` did **not** create the **application** grants on the verified
> tenant — grant them with the `appRoleAssignments` POSTs above and verify with
> `az rest --method GET --url .../servicePrincipals/$PNP_SP/appRoleAssignments`. Fresh grants take a few
> minutes to reach a new token, so a 403 right after granting usually just means "too soon".

**Then seed.** The mode is chosen by what you pass, not by a switch: give it a certificate and it runs
app-only; otherwise it falls back to a device code, and `-Interactive` opens a browser.

```bash
export ENTRAID_APP_ID=<the app id above>       # or pass -ClientId
SITE=https://<tenant>.sharepoint.com

# 1. App-only — fully headless. Needs the cert and the three application roles above.
export HALCOURT_PNP_CERT_PFX=pnp.pfx HALCOURT_PNP_CERT_PW=<cert-pw>
pwsh setup/scripts/03_provision_sharepoint.ps1 -RootSiteUrl $SITE        # -SiteOwner defaults to the az admin

# 2. Device code — works anywhere (incl. the dev container); a human enters one code.
unset HALCOURT_PNP_CERT_PFX HALCOURT_PNP_CERT_PW                         # the cert vars are what pick app-only
pwsh setup/scripts/03_provision_sharepoint.ps1 -RootSiteUrl $SITE

# 3. Browser tab — only where the sign-in redirect can reach this process (host / Windows).
pwsh setup/scripts/03_provision_sharepoint.ps1 -RootSiteUrl $SITE -Interactive
```

It creates two private M365 group team sites — `/sites/HR-Benefits-<estate>` (with a `Leadership/`
subfolder holding `2026-comp-bands.xlsx`) and `/sites/Claims-Knowledge-<estate>` — and **plants
`Open-Enrollment-FAQ.docx`**, built from `setup/data/Open-Enrollment-FAQ.md`, with its trailing *Notes*
section hidden (vanish + white text) so a reader doesn't see it while grounding still ingests it. It also
creates a separate, clean **`HR FAQ`** library holding one benign all-staff FAQ
(`setup/data/HR-FAQ-Published.md`) — the grounding source for the **HR FAQ v2 (copy) decoy**, kept apart
from the poisoned `Shared Documents`. Claims-Knowledge gets `claims.csv` and `Claims-Procedures.docx`.
Safe to re-run.

It also sets the access Scenarios A and B depend on, from the Phase 2 groups:

| Site | Members (edit) | Visitors (read) |
|---|---|---|
| `HR-Benefits-<estate>` | `HR-Team-<estate>` (Marcus) | `All-Employees-<estate>` — **except `Leadership/`**, which stops inheriting and drops the visitors |
| `Claims-Knowledge-<estate>` | `Claims-Adjusters-<estate>` (Priya, Sam) | `All-Employees-<estate>` |

So Marcus can read `Leadership/2026-comp-bands.xlsx` and Jordan can't. The script ends by reading it all
back — members, visitors, every file, the role assignments on `Leadership/`, and the planted `.docx` as
SharePoint serves it — so the run is its own evidence.

{: .note }
> App-only site creation waits up to 15 min for a fresh tenant to provision each group site. If a prior
> run left a **soft-deleted** site at `/sites/<alias>`, the new site lands at a suffixed URL (`…-mgray9`)
> and the wait times out — purge it first with `Remove-PnPTenantDeletedSite` (errata).

What the app registration grants and why it carries two identities:
[decisions → Phase 4](../reference/runbook-decisions.md#phase-4--4b--sharepoint-and-onedrive).

### Phase 4b — Provision and seed the maker OneDrive

**Prerequisite for Phase 6.** The **Meeting Notes Summarizer** decoy grounds on Dev Kim's own OneDrive
notes, so his OneDrive must exist and hold them before that agent is built.

```bash
export ENTRAID_APP_ID=<the Halcourt PnP app id>
export HALCOURT_PNP_CERT_PFX=<path to pnp.pfx>   HALCOURT_PNP_CERT_PW=<cert-pw>
pwsh setup/scripts/03b_provision_onedrive.ps1     # estate from HALCOURT_ESTATE (or -Estate <id>)
```

It **provisions** Dev's personal site and, once online, **seeds** `setup/data/Dev-Kim-Meeting-Notes.md`
(built to `.docx`) into his **Documents**; if the site already exists it skips to seeding. It prints the
OneDrive URL to ground the decoy on:

```text
https://<tenant>-my.sharepoint.com/personal/dev_kim_<estate>_<tenant>_onmicrosoft_com/Documents
```

{: .important }
> **Provisioning is best-effort `[verify]`.** If the site never appears the script fails and tells you to
> provision that maker by hand, then re-run to seed:
>
> ```bash
> pwsh -NoProfile -Command "Connect-PnPOnline -Url https://<tenant>-admin.sharepoint.com -DeviceLogin -ClientId $ENTRAID_APP_ID; Request-PnPPersonalSite -UserEmails dev.kim.<estate>@<domain>"
> ```

Why the maker does this rather than the admin:
[decisions → Phase 4b](../reference/runbook-decisions.md#why-the-maker-provisions-their-own-onedrive).

### Phase 5 — Dataverse seed

**Prerequisites:** `az`, signed in to the lab tenant — nothing else.

```bash
pwsh setup/scripts/04_provision_dataverse.ps1    # estate from HALCOURT_ESTATE; finds Claims-Test-<estate> itself
```

In `Claims-Test-<estate>` it creates the `mm` publisher and two tables, seeds them from `setup/data/`, and
builds the **over-broad** role:

| Table | Columns | Rows |
|---|---|---|
| `mm_customer` | `mm_name` (primary), `mm_customernumber`, `mm_ssn`, `mm_dob` — **PII** | `customers.csv` (5) |
| `mm_claim` | `mm_claimnumber` (primary), `mm_status`, `mm_amount`, `mm_adjuster`, `mm_customer` (lookup) | `claims.csv` (5) |

`svc-claims Dataverse Full Access` holds create / read / write / append / append-to / assign / share on
**both tables at Global depth** — every row, PII included, no row-level security — and is assigned to
`svc-claims.<estate>`. Least privilege here is what Module 5 will *close*. It reads the rows, privileges
and assignment back at the end. Safe to re-run.

{: .important }
> **`svc-claims.<estate>` needs a license — one E5 seat is enough.** Without one the script builds
> everything else and reports the role assignment as **PENDING**; assign the seat and re-run to finish.

```bash
SKU=$(az rest --method GET --url https://graph.microsoft.com/v1.0/subscribedSkus \
  --query "value[?skuPartNumber=='DEVELOPERPACK_V2_E5'].skuId | [0]" -o tsv)   # or your tenant's E5 SKU
az rest --method POST \
  --url "https://graph.microsoft.com/v1.0/users/svc-claims.$HALCOURT_ESTATE@<domain>/assignLicense" \
  --body "{\"addLicenses\":[{\"skuId\":\"$SKU\"}],\"removeLicenses\":[]}"
pwsh setup/scripts/04_provision_dataverse.ps1                                  # now reports: done
```

Why a license is required, why E5 suffices, and the non-interactive route that gives the seat back:
[decisions → Phase 5](../reference/runbook-decisions.md#phase-5--dataverse).

### Phase 6 — Author the agents

Builds all ten agents (eight planted + two decoys) per `AGENTS.md`, each **as its owner** in the
environment it names, by replaying the committed `setup/agents/<slug>/` workspaces.

**Before you build.** Copilot Studio keeps agents in Dataverse, so every owner has to be a licensed user
of the environment its agent lives in, and the default environment needs Dataverse too. With `az` signed
in as the admin (`E` = estate id, `D` = tenant domain):

```bash
# 1. A seat for each of the seven owners (svc-claims got one in Phase 5; see Phase 2 for freeing seats).
SKU=$(az rest --method GET --url https://graph.microsoft.com/v1.0/subscribedSkus \
  --query "value[?skuPartNumber=='DEVELOPERPACK_V2_E5'].skuId | [0]" -o tsv)   # or your tenant's E5 SKU
for a in marcus.webb priya.nair lena.ford dev.kim tom.dean sam.olsen it.helpdesk; do
  az rest --method POST --url "https://graph.microsoft.com/v1.0/users/$a.$E@$D/assignLicense" \
    --body "{\"addLicenses\":[{\"skuId\":\"$SKU\"}],\"removeLicenses\":[]}" --query userPrincipalName -o tsv
done
# 2. it.helpdesk is a shared mailbox, created disabled. Turn its sign-in on so it can own Policy Lookup Bot.
az rest --method PATCH --url "https://graph.microsoft.com/v1.0/users/it.helpdesk.$E@$D" \
  --body '{"accountEnabled":true,"passwordProfile":{"password":"<lab password>","forceChangePasswordNextSignIn":false}}'
# 3. Once per tenant: Dataverse in the default environment (skip if PPAC already shows it a Dataverse URL).
az rest --method POST --resource https://service.powerapps.com/ \
  --url "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/Default-<tenant-id>/provisionInstance?api-version=2018-01-01" \
  --body '{"baseLanguage":1033,"currency":{"code":"USD"},"templates":[]}'
```

Step 3 is shared by every estate, like the CA baseline, and takes a few minutes. Expense Helper and
Onboarding Guide live in the default environment and can't be built without it.

**4. Put each owner in their environment with a maker role.** Add the user (PPAC → the environment →
**Settings → Users + permissions → Users → Add user**, or the call below), then **Manage security roles**:

| Environment | Owner and role |
|---|---|
| `Halcourt-Prod-<estate>` | Marcus, Priya, Lena, `it.helpdesk`: **Environment Maker** · Tom: **System Administrator** — the departed admin's broad CRM reach behind Sales Nudge |
| `Claims-Test-<estate>` | Priya, `svc-claims`: **Environment Maker** — `svc-claims` creates its own Dataverse connection there |
| `Maker-Sandbox-<estate>` | Dev — already **System Administrator** of his own Developer environment |
| `Halcourt (default)` | Sam, Tom: **Environment Maker** |

```bash
az rest --method POST --resource https://service.powerapps.com/ \
  --url "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/<env-id>/addUser?api-version=2020-10-01" \
  --body "{\"ObjectId\":\"$(az ad user show --id marcus.webb.$E@$D --query id -o tsv)\"}"
```

It can fail once with a transient *instanceNotFound*; run it again.

**5. Billing** — Prod and Claims-Test linked to a plan (Phase 3). **6. Phase 4b has run** — Dev's OneDrive
holds `Dev-Kim-Meeting-Notes.docx`, or the Meeting Notes decoy has nothing to ground on.

**Then run the engine.** It reads `setup/agents/manifest.json`, verifies owner roles, authenticates each
connection (headless consent via `lib/consent_browser.py`), creates the Copilot-triggered flows, and
(re)builds each committed workspace **as its owner**.

```bash
az account show                                                # signed in as the lab admin
pwsh setup/scripts/06_provision_agents.ps1 -VerifyOnly         # resolve + report, change nothing
pwsh setup/scripts/06_provision_agents.ps1                     # full run: roles + connections + agents
pwsh setup/scripts/06_provision_agents.ps1 -Agents hr-faq-v2   # one agent; also -SkipPrereqs -SkipConnections
```

| Agent | Tool mechanism |
|---|---|
| Benefits Buddy, HR FAQ v2 | SharePoint knowledge (no tool) |
| Team Wiki | connector tool (Graph search) · Meeting Notes: OneDrive knowledge |
| Sales Nudge, Onboarding Guide, Claims Copilot | connector tools (`InvokeConnectorTaskAction`) |
| Policy Lookup Bot | topic + `HttpRequestAction` (hard-coded key) |
| Underwriting Assistant | topics + `InvokeMcpTool` (get_quote / get_risk_score / run_query) |
| Expense Helper | flow (`workflow` record) + topic `InvokeFlowAction` |

Each connection in `worksheets/artifact-pack/connections-export.csv` is created by the persona it names,
in the environment it names — e.g. `svc-claims` creates `DV-Claims-Shared` in `Claims-Test-<estate>`.
**OAuth connections can't be shared**, so the pack's
`shared_with` values for `DV-Claims-Shared` and `DV-CRM-Shared` can't appear in a live export; the agent
is what "shares" them.

How the engine works (clone-first, publisher, owner tokens), why the planted mechanisms live in topics,
and how to build one agent by hand:
[decisions → Phase 6](../reference/runbook-decisions.md#phase-6--agents) and
[`agent-authoring-guide.md`](agent-authoring-guide.md).

**Phase 6.5 — orphan Tom Dean.** After Onboarding Guide and Sales Nudge exist **and their shared
connections are owned by `tom.dean.<estate>`**:

```powershell
pwsh setup/scripts/01_provision_entra.ps1 -DisableDepartedOwner    # same estate
```

The agents and connections must remain live — that is the orphan.

### Phase 7 — Export the artifact pack

```powershell
pwsh setup/scripts/05_export_artifact_pack.ps1 -Canonicalize    # estate from HALCOURT_ESTATE (or -Estate <id>)
git diff worksheets/artifact-pack
```

Pulls **this estate** — its environments, its agents and connections in the shared default environment,
and its accounts (no admins, no sample users) — from the PPAC admin APIs + Microsoft Graph, and writes the
five CSVs. `-Canonicalize` maps live names back to the canon's so the export lands on the committed pack
and `git diff` shows the drift. Without it the script refuses to write into the committed pack; pass
`-OutDir` for a live-named export.

**One prerequisite: the admin needs a security role in every Dataverse environment**, because the agent
inventory reads each environment's `bot` table. Environments the admin created in Phase 3 already have it;
a **Developer** environment does not:

```bash
pac admin assign-user --environment <environment-id> --user <admin UPN> --role "System Administrator"
```

{: .important }
> **The committed pack is not a pure export, so do not expect an empty `git diff`.** Three columns are
> hand-written canon that no API returns: agent `description`, the friendly connector names, and the rows
> for things that aren't Power Platform connections at all. Read the diff as *drift to review*, not as a
> test that should come out empty —
> [decisions → Phase 7](../reference/runbook-decisions.md#phase-7--the-artifact-pack).

### Phase 8 — Validate

Walk `AGENTS.md` and confirm, in the live tenant:

- Every **PLANTED PROBLEM** reproduces (A–F fire; discovery targets are findable).
- Every **CONTROL EFFICACY** verdict holds; resolve any `[verify]` items and update `AGENTS.md`.
- Guest (Ana) read access works; the Jordan Blake confused-deputy path works.
- **Phase 6.5 has run** — Tom must be disabled *after* his connections exist, or the departed-owner thread
  reads wrong and `users-export` disagrees with the canon.
- Re-run Phase 7 and **review** `git diff worksheets/artifact-pack`. It will not be empty; look for
  *unexpected* drift — an agent missing, an owner that changed, a connection that lost its sharing, an
  environment that lost its DLP.

What the export confirms on its own, without driving an agent: every published agent is present with the
right owner and environment; each has exactly one Entra identity; DLP is attached to Prod and nowhere
else; and the accounts are as Phase 2 left them. Reproducing Scenarios A–F still means talking to the
agents.

### Phase 8b — Lab (attendee) accounts

Per *delivery*, not per estate: attendees sign in to the lab tenant with a native account you hand out, so
they review the estate from inside the tenant rather than as guests. Run it shortly before the delivery and
tear it down after.

```bash
pwsh setup/scripts/07_provision_lab_users.ps1 -Count 20                      # student01.<estate> .. student20.<estate>
pwsh setup/scripts/07_provision_lab_users.ps1 -Count 20 -UniquePasswords     # a distinct password each
pwsh setup/scripts/07_provision_lab_users.ps1 -Destroy                       # delete AND purge, after the delivery
```

Accounts are estate-scoped (`student01.<estate>@<domain>`), so two facilitators can run deliveries in one
tenant. The run prints a handout table and writes `setup/lab-users-<estate>.local.csv` — **plaintext
passwords, gitignored; delete it afterwards**. Re-running is safe: existing accounts are left alone (the
script cannot read a password back, so it says `(unchanged)` rather than inventing one).

**Attendees get `Power Platform Administrator`, and a Conditional Access exclusion so they can still sign
in.** Lab 01-01 has them enumerate an environment's connections, and only the tenant-admin endpoints under
`/scopes/admin/` can do that. Nothing weaker reaches them — verified live 2026-10-13, both the obvious
alternatives fail:

| Weaker option | Result |
|---|---|
| `Global Reader` | **404 `CRMRequestFailed`** where a tenant admin gets `200`. The endpoint hides itself from an unauthorized caller instead of returning `403`, so the attendee sees an empty estate, not an error. |
| A per-environment role | No help. The maker-facing connections API is caller-scoped: a maker owning 1 of an environment's 2 connections sees exactly that one; members owning none see zero. |

That role is MFA-gated, so the script creates one group per delivery — `Lab-Students-<estate>`, holding
only this delivery's accounts — and adds it to `CA-Require-MFA-Admins`'s `excludeGroups`. The edit is
additive: another estate's exclusion is never touched, and `-Destroy` removes only this estate's group id,
then deletes the group. After the policy write the script re-reads it and warns if the admin-role count
changed.

Verified end to end on 2026-10-13: sign-in with the handed-out password succeeds (previously `AADSTS50079`),
`scopes/admin/environments` returns 200 with 5 environments, and the Halcourt-Prod connections call returns
both connections — including `DV-CRM-Shared`, owned by the disabled `tom.dean`, which is the row the Ex 02
hunts turn on. `-Destroy` put the policy back to 15 admin roles and no exclusions.

> {: .caution }
> **An attendee account is a tenant-wide Power Platform admin, exempt from the admin MFA policy.** It can
> change or delete any environment in the tenant, including another facilitator's estate. Give a delivery
> its own tenant where you can, and run `-Destroy` the moment it ends. `-NoCaExclusion` skips the policy
> change, but then the accounts cannot sign in at all.

**Licences are best effort and usually fail.** A sandbox has 25 E5 seats, the estate needs eight, and the
content-pack sample users hold the rest — on the build tenant it was 25/25 consumed, so every attendee came
out unlicensed. That is fine: Entra reads and the Power Platform admin APIs both work without a seat.
Assignment is attempted, never fatal, and the end-of-run table reports exactly who got one. To change that,
free seats in **M365 admin center → Billing → Licenses** first, or pass `-LicenseSku FLOW_FREE` (10,000
seats) if a licence merely needs to be present.

Why this role and not something weaker:
[decisions → Phase 8b](../reference/runbook-decisions.md#phase-8b--attendee-accounts).

### Phase 9 — Teardown / reseed

`99_teardown.ps1` removes ONE estate and nothing another estate owns, in dependency order: the shared
default environment's agents + the auto-approve flow (as their owners) → the SharePoint sites (purged from
the recycle bin so the URLs are reusable) → the three estate environments (their Dataverse, agents and
connections go with them) → the DLP policy → billing unlink.

```bash
export ENTRAID_APP_ID=<PnP app id>  HALCOURT_PNP_CERT_PFX=<pnp.pfx>  HALCOURT_PNP_CERT_PW=<cert-pw>   # for site removal
pwsh setup/scripts/99_teardown.ps1                                  # estate artifacts; KEEPS personas + shared infra
pwsh setup/scripts/99_teardown.ps1 -RemovePersonas                  # also the Phase 2 personas + *-<estate> groups
pwsh setup/scripts/99_teardown.ps1 -RemovePersonas -RemoveShared    # also the shared authors group + PnP app registration
azd down --purge --force                                            # Azure (Phase 1), from the repo root
```

Environments delete asynchronously (a few minutes). It KEEPS Phase 0 (tenant, CA baseline, security
defaults) and the shared **default environment** and its Dataverse — that can't be un-provisioned. To
reseed, re-run Phases 1–6. If you rebuild the Azure endpoints, use a **new** azd environment name; the
agents' `${…}` action tokens re-inject the new addresses at Phase 6 provision time.

## File index (this kit)

| Path | Purpose |
|---|---|
| `infra/` (root azd project) | Deploys web + Foundry + Policy API + Underwriting MCP Container Apps via `azd up` |
| `setup/infra/policy-api/` | Minimal, intentionally over-scoped Policy API (static key) |
| `setup/infra/mcp-underwriting/` | Minimal Underwriting MCP server (static bearer, `run_query`) |
| `scripts/00_conditional_access_baseline.ps1` | Security defaults off → `CA-Require-MFA-Admins` + `CA-Block-Legacy-Auth` |
| `scripts/_estate.ps1` | Estate naming rule, dot-sourced by the scripts |
| `scripts/01_provision_entra.ps1` | Personas, groups, `svc-claims`, shared mailbox |
| `scripts/02_provision_environments_dlp.ps1` | Environments, Managed Prod, prod DLP |
| `scripts/02b_provision_billing.ps1` | Copilot Studio PAYG billing plan; links Prod + Claims-Test |
| `scripts/03_provision_sharepoint.ps1` | Sites + clean FAQ library + **plant poisoned doc** |
| `scripts/03b_provision_onedrive.ps1` | Provision + seed dev.kim's OneDrive (Meeting Notes grounding) |
| `scripts/04_provision_dataverse.ps1` | Claim/Customer tables, PII rows, over-broad role |
| `scripts/05_export_artifact_pack.ps1` | Regenerate the artifact-pack CSVs |
| `scripts/06_provision_agents.ps1` | Provision the agents from committed workspaces, as each owner |
| `scripts/lib/consent_browser.py` | Headless connection-consent helper (the only browser step in Phase 6) |
| `scripts/99_teardown.ps1` | Remove the estate |
| `agents/manifest.json` | Phase 6 control data: agents, connections and flows (estate-agnostic) |
| `agents/<slug>/` | Committed `pac copilot` agent workspaces the engine replays |
| `agent-authoring-guide.md` | Manual Copilot Studio authoring, per agent (portal / `pac`) |
| `data/` | Seed data: poisoned-doc source, clean decoy FAQ, Dev's meeting notes, Expense Helper flow |

{: .warning }
> Several script steps depend on 2026 product surfaces still settling (CA for workload identities, `pac`
> agent commands). Lines marked `# [verify]` need confirmation against the delivery-date tenant; treat
> them as the intended operation, not a guaranteed cmdlet.

## More detail

| File | Holds |
|---|---|
| [`../reference/runbook-decisions.md`](../reference/runbook-decisions.md) | Why it is built this way, the tradeoffs, manual alternatives to the scripted path |
| [`../reference/runbook-errata.md`](../reference/runbook-errata.md) | Errata, known issues, troubleshooting, open `[verify]` risks |
| [`../reference/copilot-studio-billing.md`](../reference/copilot-studio-billing.md) | Copilot Studio billing/licensing models and their workshop implications |

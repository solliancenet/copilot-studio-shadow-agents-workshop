# RUNBOOK.md — Facilitator provisioning

> **FACILITATOR-ONLY. Not published** (the whole `setup/` folder is excluded in `_config.yml`).
> Provisions the intentionally-vulnerable **Halcourt Mutual** demo estate for the workshop. Everything
> here is keyed to the canon in [`../AGENTS.md`](../AGENTS.md) — that file is the source of truth; this
> file is how you build it.

## Model: hybrid

- A single **shared demo tenant** hosts the live estate for the BREAK (Module 4) and CONTROL (Module 5)
  demos. Attendees get a **guest / read** account (Ana Reyes vantage) plus the low-priv **Jordan Blake**
  path for confused-deputy demos.
- An **artifact pack** (five CSVs in `../worksheets/artifact-pack/`) is exported from the estate so the
  DISCOVER / MAP / threat-model / ASSESS work runs offline. **The committed artifact pack is the
  canonical output of Phase 7 below** — regenerate it whenever the estate changes.

{: important}
The estate is deliberately broken. Provision it in an **isolated training tenant** you control. Never
point these scripts at a production tenant. All external endpoints are Azure Container Apps with
their own default `*.azurecontainerapps.io` FQDNs, assigned at deploy time — no custom domain or DNS.

## Estates: several builds in one tenant

More than one facilitator can build Halcourt Mutual in the same tenant — and the scripts find everything
they create **by name**. Under the canonical names, a second build adopts or overwrites the first: its
Phase 3 skips creating `Claims-Test` because one exists, its Phase 5 seeds someone else's Dataverse, and
both share Marcus, Tom and the rest, so one person's Phase 6.5 orphans Tom for everyone. So each build is
an **estate** with its own id, and every name it creates carries that id:

| What | Canonical (AGENTS.md, lab pages, artifact pack) | Live, estate `mgray` |
|---|---|---|
| Accounts | `marcus.webb@halcourtmutual.onmicrosoft.com`, "Marcus Webb" | `marcus.webb.mgray@<tenant domain>`, "Marcus Webb (mgray)" |
| Groups, environments, DLP, sites | `Halcourt-Makers`, `Claims-Test`, `Halcourt-Prod-DLP`, `HR-Benefits` | `Halcourt-Makers-mgray`, `Claims-Test-mgray`, `Halcourt-Prod-DLP-mgray`, `HR-Benefits-mgray` |
| Agents in the default environment | `Expense Helper`, `Onboarding Guide` | `Expense Helper (mgray)`, `Onboarding Guide (mgray)` |
| Azure (Phase 1) | — | azd environment `halcourt-mgray-lab` |

**Shared, not renamed:** the tenant's default environment (`Halcourt (default)` — a tenant has exactly one)
and the Conditional Access baseline (Phase 0). The full rule is in `AGENTS.md` → *Live estate naming*;
`setup/scripts/_estate.ps1` implements it.

**Pick your id once** — your alias, 2–12 lowercase letters or digits — and check nobody in the tenant uses
it (every estate has an `ana.reyes.<id>@` account):

```bash
az ad user list --filter "startswith(userPrincipalName,'ana.reyes.')" --query "[].userPrincipalName" -o tsv
```

Then set it in every shell you build from — each script reads it, takes `-Estate <id>` instead, and refuses
to run with neither:

```bash
export HALCOURT_ESTATE=mgray          # bash / the dev container
```

```powershell
$env:HALCOURT_ESTATE = 'mgray'       # PowerShell, e.g. in the Windows build VM
```

Give attendees the estate id along with the tenant domain: the lab pages use the canonical names, and Lab
00 tells them to expect the suffix.

## Prerequisites (technician)

- Tooling on the build box — **the dev container (`.devcontainer/`) installs all of it**, and every phase
  but Phase 7 and teardown runs there (those two still need the Power Platform admin module, which only
  signs in on Windows):
  - Azure CLI (`az`) + Bicep, and the Azure Developer CLI (`azd`) for Phase 1. An Azure subscription for
    the Container Apps.
  - Power Platform CLI (`pac`) — the .NET tool build, which needs the .NET 10 SDK.
  - PowerShell 7 with modules: `Microsoft.Graph`, `Microsoft.PowerApps.Administration.PowerShell`,
    `PnP.PowerShell`, `ExchangeOnlineManagement` (Phase 2 shared mailbox). No script uses
    `Microsoft.PowerApps.PowerShell`. On a Linux host outside the container, the PowerApps admin module
    won't import without the file-name fix in `.devcontainer/on-create.sh`.
  - `pandoc` — Phase 4 builds the planted `.docx` from Markdown; without it the script uploads the raw
    `.md` with the payload visible.
  - **Phase 7 and teardown:** PowerShell 7 on Windows. `Add-PowerAppsAccount` can't sign in on Linux
    (see the Phase 0 warning).
- No Windows PC? Run the **Windows build VM** below for the Windows-only phases.

### Windows build VM

`setup/windows-vm/` runs a full Windows 11 desktop inside Docker
([dockur/windows](https://github.com/dockur/windows), QEMU/KVM) and installs the whole toolchain above on
first boot. Unlike a Windows *container*, it has a desktop and a browser, so interactive sign-in and MFA
work. Every phase runs in it.

**Host requirements.** It always runs on the **host's** Docker — the dev container only drives it (its
`docker` CLI talks to the host's daemon; the container has no `/dev/kvm` of its own):

| Host | Needs |
|---|---|
| Linux | Docker Engine + Compose v2; CPU virtualization on in BIOS; `/dev/kvm` present (`sudo kvm-ok`) |
| Windows 11 | Docker Desktop, WSL 2 backend, **Linux containers** mode; nested virtualization (on by default for WSL 2 on Windows 11) |

Not supported: Windows 10 hosts (Docker Desktop can't pass KVM through) and macOS. Budget 8 GB RAM,
4 cores and 64 GB disk for the VM (tunable, below).

**Check KVM first** — the same command on both hosts; it should print a `/dev/kvm` line:

```bash
docker run --rm --device /dev/kvm alpine ls -l /dev/kvm
```

**Start it** from the repo root — the same command in the dev container terminal or a host terminal (bash
or PowerShell):

```bash
docker compose -f setup/windows-vm/compose.yaml up -d
```

Open http://localhost:8006 in your host's browser to watch the install and use the desktop, or RDP to
`localhost:3389` (user `halcourt`, password `Lab-Only-Passw0rd!`). Both are bound to localhost only. The
first start downloads Windows 11 Enterprise **evaluation** (~7 GB, no product key; licensed for 90 days)
and installs it unattended — allow 20–40 minutes. `setup/windows-vm/oem/bootstrap.ps1` then installs
PowerShell 7, `az`, `azd`, `pac`, `pandoc` and the modules, and logs to `C:\OEM\bootstrap.log`. If it
failed (usually network), re-run it from an elevated prompt:

```powershell
powershell -ExecutionPolicy Bypass -File C:\OEM\bootstrap.ps1
```

**Use it.** The repo is drive `Z:` in Windows. Run the Windows-only steps from there — Phase 7 and
teardown (everything else runs in the dev container or on the host):

```powershell
Z:
$env:HALCOURT_ESTATE = 'mgray'                       # your estate id (Estates, above)
pwsh setup/scripts/05_export_artifact_pack.ps1 -Canonicalize
```

Sign-in state (`az`, `pac`, Graph, PowerApps) lives in the Windows user profile, separate from the dev
container's `.azure/` and `.pac/` — sign in to the lab tenant again inside the VM. `azd` environments live
in the repo's `.azure/`, so they are shared.

**Tune or tear down.** Override `WINVM_VERSION`, `WINVM_RAM_SIZE`, `WINVM_CPU_CORES`, `WINVM_DISK_SIZE`,
`WINVM_USERNAME` or `WINVM_PASSWORD` in `setup/windows-vm/.env` (gitignored) before the first start.

```bash
docker compose -f setup/windows-vm/compose.yaml stop       # shut Windows down, keep the disk
docker compose -f setup/windows-vm/compose.yaml down -v    # delete the VM and its disk
```

## Phase order (do NOT reorder)

```
0. Provision isolated tenant   → fresh *.onmicrosoft.com, licensing, security defaults → CA baseline
1. Azure infra (Bicep)        → Policy API + Underwriting MCP endpoints
2. Entra identities/personas  → users, groups, DISABLE tom.dean
3. Environments + DLP          → 4 environments, prod DLP, PAYG billing plan
4. SharePoint seed             → HR-Benefits + Claims-Knowledge, PLANT the poisoned doc
4b. Maker OneDrive             → provision + seed dev.kim's OneDrive (Meeting Notes grounding)
5. Dataverse seed              → Claim + Customer tables, PII rows, the over-broad role
6. Author the agents           → as each owner: portal or pac copilot, per agent-authoring-guide.md
7. Export the artifact pack    → regenerate ../worksheets/artifact-pack/*.csv
8. Validate                    → every planted problem reproduces; verdicts hold
9. Teardown / reseed
```

---

### Phase 0 — Provision the isolated training tenant

Stands up the **brand-new, isolated** M365 / Power Platform tenant the rest of this runbook assumes.
Do this once per lab tenant; it is mostly a portal flow, so the steps below are UI actions, not scripts.

{: important}
This tenant **must not** be linked to any production or corporate tenant. Sign up with a **personal or
lab-dedicated admin credential — never corporate SSO**.

1. **Sign up for a new M365 tenant** via the **Microsoft 365 Developer Program**
   (https://developer.microsoft.com/microsoft-365/dev-program) — a 90-day renewable E5 sandbox.
   - Choose the **"Instant sandbox (Add-on purchases enabled)"** variant (alternatives in Errata).
   - Provide an **Azure billing account** for the one-time verification (not charged). Create it ahead of
     time — it can take ~15 min to a few hours to appear (if it still doesn't appear, see Errata).
   - Pick the **data-center region** at signup — it cannot be changed afterward.
   - Choose **"Create a new account" / personal or lab email** — never corporate SSO.
   - Don't count on the tenant's **domain**. The canon uses `halcourtmutual.onmicrosoft.com`, but signup
     assigns what it assigns — the tenant this runbook was verified on got `0zwdt94t.onmicrosoft.com`. That
     is fine: the scripts use the tenant's own domain (Phase 2).
   - The optional **content / sample-data pack** is fine to install. Its ~16 users are separate from the
     personas, but they hold license seats the personas need later (Phase 2).

2. **Complete initial tenant setup.**
   - Finish the wizard: create the **global administrator** account and record the UPN (the technician
     identity the rest of the runbook uses).
   - **Confirm MFA is registered** on the global admin account (the tenant wizard may have already required
     this). Verify in **Entra admin center** (https://entra.microsoft.com) → admin user → **Authentication
     methods**.
   - **Record the tenant's data-center region:** in the admin center, **Settings → Org settings → Organization
     profile → Data location** (or Entra → Properties). Note the region — you'll reuse it as the Azure region
     for the Phase 1 `azd` deployment (`azd` prompts for `AZURE_LOCATION`). The region is immutable; if it is
     wrong the only fix is a new tenant.
   - Confirm the global admin holds **Power Platform admin, Entra admin, SharePoint admin, Purview,
     Conditional Access, and Defender** access (in a fresh tenant Global Administrator covers all of these;
     see Errata if splitting duties).

3. **Add and assign licensing.**
   - **M365 E5** (incl. the Developer SKU): already provided by the sandbox; covers the Purview features the
     labs use.
   - Assign the **E5 per-seat SKUs** in **Billing → Licenses** to the global admin (and the Phase 2 personas
     later).

4. **Replace security defaults with the Conditional Access baseline.** Once per tenant, before the
   verification checklist:

   ```powershell
   pwsh setup/scripts/00_conditional_access_baseline.ps1 -TenantId <tenant-id>
   ```

   Run it from the **host** or the **Windows build VM**, not the dev container — security defaults are
   still on at this point and block the device-code sign-in the container depends on. Sign in with the
   browser tab it opens and pick the account **within two minutes**; `Connect-MgGraph` gives up after
   that. The first run asks for `Policy.ReadWrite.ConditionalAccess` and `Policy.Read.All` — tick
   **Consent on behalf of your organization**.

   It turns security defaults off and creates the two baseline policies from `AGENTS.md`:

   | Policy | Applies to | Control |
   |---|---|---|
   | `CA-Require-MFA-Admins` | 15 admin roles — Microsoft's *Require MFA for admins* template set, plus Power Platform Administrator | Require MFA |
   | `CA-Block-Legacy-Auth` | All users | Block Exchange ActiveSync and other legacy clients |

   If creating a policy fails, it undoes its changes and turns security defaults back on, so admins are
   never left without MFA. It is safe to re-run.

   **Then wait about 10 minutes before the first device-code sign-in.** Sign-ins take a while to stop
   seeing security defaults: in testing, a device-code sign-in one minute after the script still failed
   with *AADSTS530035*; seven minutes after, it worked.

   **Why this is necessary.** Security defaults are the right setting for a real small tenant, but they
   make this workshop painful to build and to run:

   - *They block device-code sign-in.* Device codes are the only sign-in that works from the dev container
     (a browser login redirects to `localhost` on the host, where nothing is listening), and scripts `01`,
     `03`, `05` and `99` always use them. Security defaults reject every device-code sign-in with
     *AADSTS530035* and take no exceptions — not even for the build admin. With them on, every sign-in has
     to happen in a desktop browser on the host or the VM, racing `Connect-MgGraph`'s two-minute window.
   - *They put every persona through MFA registration.* Security defaults make every account register for
     MFA, then prompt whenever Entra decides to. The build signs in as the personas to author agents and
     own connections (Phase 6), and attendees sign in as Ana Reyes and Jordan Blake. Each account would
     need its own authenticator enrollment on someone's phone, and a surprise prompt mid-demo stalls the
     room.
   - *They lock out Conditional Access.* Enabled Conditional Access policies can't coexist with security
     defaults, and the estate needs two: Module 5 tests Conditional Access against the canon in
     `AGENTS.md`.

   **What the baseline keeps, and what it gives up.** It keeps the two protections that matter here: MFA on
   every admin role, and no legacy authentication. It gives up MFA for ordinary accounts and security
   defaults' risk-based prompts — acceptable only because this is an isolated lab tenant holding fictitious
   data. Never do this to a production tenant. Two gaps are deliberate: no policy targets workload/agent
   identities (a Module 5 finding), and none blocks device-code flow (the build needs it). If Microsoft
   later adds a managed policy that restricts authentication flows, the script's summary warns — exclude
   the build admin from it.

5. **Phase 0 verification checklist.**
   - Global admin can **sign in** to https://admin.microsoft.com with MFA satisfied.
   - **Security defaults are off** and both baseline policies are **On** (Entra admin center → Protection →
     Conditional Access → Policies).
   - **Licensing shows assigned** (E5) on the admin account.
   - **An Azure subscription is usable** — you hold **Owner** on it (or Contributor + User Access
     Administrator): Phase 1's `azd up` creates role assignments, which Contributor can't. It is also the
     basis for later Copilot Studio PAYG billing plans; see Errata.
   - The build-box tooling from **Prerequisites** is installed and authenticated **against the new
     tenant**:

     ```bash
     az login --allow-no-subscriptions --use-device-code   # sign in as the lab global admin
     az account show                                       # confirm the new tenant id
     pac auth create --name halcourt-lab --deviceCode      # Power Platform CLI → new tenant
     pac org list                                          # "Connected as <admin>"; lists Dataverse environments only — none in a fresh tenant
     ```

     ```powershell
     Connect-MgGraph -TenantId <yourlab>.onmicrosoft.com -UseDeviceCode   # Microsoft.Graph
     Get-MgOrganization | Select DisplayName, Id                          # confirm the new tenant
     Add-PowerAppsAccount                                                 # PowerApps admin modules (Windows only — see note)
     ```

   **Sign-in and consent.** Every sign-in in this runbook is the lab global admin. Two tenant settings
   decide whether it works.

   *Device-code flow needs security defaults off.* In the dev container, a browser login opens your host
   browser, but Entra redirects it to `http://localhost:<random port>` — the host, not the container, where
   the login is waiting — so the tab hangs. Device-code logins (a code to enter at
   https://microsoft.com/devicelogin) avoid that. The scripts that call Graph (`01`, `05`, `99`) first **reuse your `az` sign-in** — its saved Graph token already carries the scopes they need, so they don't ask at all (`setup/scripts/_auth.ps1`); they fall back to a device code only when `az` isn't signed in to the lab tenant. PnP (`03`) always uses a device code.
   Security defaults block every device-code sign-in (*AADSTS530035: Access has been blocked by security
   defaults*) — step 4 turned them off for exactly this reason. If a device-code sign-in still fails with
   530035, step 4 hasn't run; until it has, sign in with the browser from the **host** or the **Windows
   build VM** by dropping `--use-device-code` / `--deviceCode` / `-UseDeviceCode`. `Connect-MgGraph` gives
   up on any sign-in after **2 minutes** (`az` and `pac` wait about 15), so do its prompt first.

   *Microsoft Graph needs admin consent.* The scripts sign in as the **Microsoft Graph Command Line Tools**
   app with delegated scopes. A sign-in that asks for a scope nobody has consented to stops at a consent
   prompt, or fails with *AADSTS65001* where it can't show one. Consent to all of them once, for the whole
   organization, as the global admin — tick **Consent on behalf of your organization** before **Accept**:

   ```powershell
   Connect-MgGraph -TenantId <yourlab>.onmicrosoft.com -Scopes `
     Policy.ReadWrite.ConditionalAccess, Policy.Read.All, User.ReadWrite.All, Group.ReadWrite.All, `
     User.Read.All, Application.Read.All, AuditLog.Read.All
   ```

   | Scope | Used by |
   |---|---|
   | `Policy.ReadWrite.ConditionalAccess`, `Policy.Read.All` | `00_conditional_access_baseline.ps1` (Phase 0, step 4) |
   | `User.ReadWrite.All`, `Group.ReadWrite.All` | `01_provision_entra.ps1` (Phase 2), `99_teardown.ps1` |
   | `User.Read.All`, `Application.Read.All` | `05_export_artifact_pack.ps1` (Phase 7) |
   | `AuditLog.Read.All` | `05_…` — its users export reads `signInActivity`, which needs this scope |

   Check what's granted in **Entra admin center → Enterprise applications → Microsoft Graph Command Line
   Tools → Permissions**.

   *`pac` and the PowerApps admin module need nothing granted.* Both are Microsoft first-party apps, and the
   global admin already holds Power Platform admin rights. Sign in with
   `pac auth create --name halcourt-lab --tenant <tenant-id>` and, on Windows,
   `Add-PowerAppsAccount -TenantID <tenant-id>`. PnP.PowerShell is the exception — it needs its own app
   registration (Phase 4).

   {: .warning }
   > `Add-PowerAppsAccount` does not work on Linux, in or out of the container: the module bundles a
   > Windows-only MSAL build and fails with *Could not load file or assembly 'System.Windows.Forms'*.
   > Phases 3 and 7 and teardown (`02_…`, `05_…`, `99_…`) call it — run those from PowerShell 7 on Windows
   > or the **Windows build VM** (Prerequisites).

   Once these pass, proceed to Phase 1.

### Phase 1 — Azure infrastructure (azd up)

Provisions the whole project with `azd up`: the demo **web** app + Foundry, plus the internal
**Policy API** and **Underwriting MCP** server as Container Apps. The latter two are intentionally weak
(static-secret auth, over-scoped surface) — see `setup/infra/policy-api/` and `setup/infra/mcp-underwriting/`.

{: important}
Everything deploys into the **same Azure Plan / subscription** set up in Phase 0 (see Errata —
Azure spend). No separate billing setup.

```bash
azd auth login --use-device-code  # skip if `azd config get auth.useAzCliAuth` says true — az login covers it

# Name this deployment after your estate (Estates, above): halcourt-<estate>-lab. See below.
az group list --subscription <lab-subscription-id> --query "[?starts_with(name, 'rg-halcourt')].name" -o tsv   # names already used
ENV_NAME=halcourt-$HALCOURT_ESTATE-lab
azd env new "$ENV_NAME" --subscription <lab-subscription-id> --location eastus2   # RG: rg-$ENV_NAME
azd env set POLICY_API_KEY "lab-$(openssl rand -hex 8)"   # any lab-only string — RECORD it
azd env set MCP_BEARER   "lab-$(openssl rand -hex 8)"     # any lab-only string — RECORD it
azd up                            # provisions + builds/pushes all images + deploys
azd env get-values                # read POLICY_API_FQDN / UNDERWRITING_MCP_FQDN
```

Record both secret values as you set them — you'll need them again later.

**Use a name nobody has used in this subscription.** azd derives the whole deployment from the
environment name: the resource group is `rg-<name>`, and every resource name — the registry, the Foundry
account and project, the three Container Apps — comes from a token computed from subscription +
environment name + region (`infra/main.bicep`). Two deployments with the same name in the same
subscription and region are therefore the *same* resources: the second `azd up` redeploys the first
facilitator's apps and replaces their Policy API key and MCP bearer, silently breaking every agent built
against them. Reusing the name of a torn-down deployment fails differently — the Foundry soft-delete trap
(Errata). A per-estate name, `halcourt-<estate>-lab`, avoids both; add a suffix (`-2`, a date) when you
rebuild. Pass `--subscription` and `--location` explicitly too: otherwise azd falls back to its global
defaults (`azd config get defaults`), which can point at a subscription outside the lab tenant.
`eastus2` is tested; any region with gpt-5-mini (GlobalStandard) quota works.

`azd up` deploys the entire project (the demo web app + Foundry + the two weak apps) into
`rg-<env-name>`. The workshop's agents only use the two weak apps. The web app's member API (`/api/*`)
returns **500** on this path — it needs the Entra app registration that `infra/setup-env.sh` creates
(`API_APP_ID`); run that script only if you need the Foundry web demo.

Record the two Container App addresses from `azd env get-values` (`POLICY_API_FQDN` /
`UNDERWRITING_MCP_FQDN`). Despite the names they are full URLs, scheme included —
`https://ca-policyapi-<token>.<env-id>.<region>.azurecontainerapps.io` and
`https://ca-underwritingmcp-<token>.<env-id>.<region>.azurecontainerapps.io`, where `<env-id>` is the
Container Apps environment's generated name (e.g. `politestone-503df790`). These default
`*.azurecontainerapps.io` addresses (no custom domain, no DNS to configure) are exactly what the agents'
actions point at: their host part (drop `https://`) is the `<policy-api-fqdn>` / `<mcp-fqdn>` in
`agent-authoring-guide.md`. The **static API key**
you pass here is the one that will sit in Policy Lookup Bot's HTTP action config (that exposure is the
point of Scenario E).

### Phase 2 — Entra identities & personas

**Prerequisites:** the **Microsoft.Graph** PowerShell module — the script calls `Connect-MgGraph` with
`User.ReadWrite.All` and `Group.ReadWrite.All` — plus **ExchangeOnlineManagement** for the shared-mailbox
step below.

```powershell
pwsh setup/scripts/01_provision_entra.ps1 -TenantId <tenant-id>    # estate from HALCOURT_ESTATE (or -Estate <id>)
```

Creates, as this estate's `<alias>.<estate>@<tenant domain>` accounts, the eight personas in `AGENTS.md` (Ana, Marcus, Priya, Sam, Lena, Dev, **Tom Dean** — created
enabled, disabled later in Phase 6.5 — and Jordan), the `svc-claims` service account, and the four groups
(`Halcourt-Makers-<estate>`, `HR-Team-<estate>`, `Claims-Adjusters-<estate>`, `All-Employees-<estate>`),
filled per `AGENTS.md` → *Groups* (Phase 4 grants site access through them). It sets each account's usage
location
(the tenant's country) so licenses can be assigned later, but assigns none. Safe to re-run: accounts and
groups that already exist are left alone.

**The domain is the tenant's, not the canon's.** `AGENTS.md`, the artifact pack and the lab pages write
every UPN as `<alias>@halcourtmutual.onmicrosoft.com`, but a lab tenant keeps whatever domain Microsoft
assigned it (a Dev Program sandbox gets something like `0zwdt94t.onmicrosoft.com`), and an
`*.onmicrosoft.com` domain can't be added to another tenant. So the script uses the tenant's **default
verified domain** and says so first, with the estate:

```text
Estate: mgray   Persona domain: 0zwdt94t.onmicrosoft.com
  canon <alias>@halcourtmutual.onmicrosoft.com  ->  live <alias>.mgray@0zwdt94t.onmicrosoft.com
```

`-DomainSuffix <domain>` picks another domain, but only one the tenant has verified — anything else stops
the script before it creates an account. What stays fixed is the **alias** (`ana.reyes`, `svc-claims`,
`it.helpdesk`, …): the later scripts find accounts by alias + estate on the tenant's domain. Tell attendees
the live domain and estate id along with their sign-ins — Lab 00 warns them both differ from the pages.

**The `it.helpdesk` shared mailbox is created by the script** (no longer a manual step). Graph can't create
shared mailboxes but Exchange Online can, and `Connect-ExchangeOnline` takes a delegated **access token** —
so `_auth.ps1`'s `Connect-LabExchange` reuses the same `az` sign-in the rest of Phase 2 uses (no device code,
no app-only Exchange app) and runs:

```powershell
New-Mailbox -Shared -Name "IT Helpdesk (<estate>)" -Alias it.helpdesk.<estate> -PrimarySmtpAddress it.helpdesk.<estate>@<domain>
```

Keep `-Alias`: without it Exchange derives an alias from the name, and the account isn't
`it.helpdesk.<estate>@…`. Exchange creates the account **disabled for sign-in**, as it does for every shared mailbox,
and provisions it asynchronously (it can take a minute to appear). This mailbox is the ambiguous owner of
Policy Lookup Bot (see `AGENTS.md`), so it must exist; Phase 6 turns its sign-in on so it can own that agent.
If the automatic step can't run (no `az` session, or the admin isn't an Exchange admin) the script warns and
prints the same command to run yourself after `Connect-ExchangeOnline -Device`.

**Content pack installed?** The personas are separate from the Dev Program's ~16 sample users (Adele
Vance, Alex Wilber, …) — nothing collides, and nothing needs remapping: keep the canonical personas. The
pinch is **licenses**. The sandbox has 25 Microsoft 365 E5 (developer) seats, and the sample users and
admins already hold most of them (19 of 25 in the tenant this was verified on). Each estate needs **eight**:
`svc-claims` (Phase 5) and the seven agent owners — Marcus, Priya, Lena, Dev, Tom, Sam and `it.helpdesk`
(Phase 6) — because Dataverse only adds licensed users to an environment. Free seats by unassigning sample
users you don't need (**Microsoft 365 admin center → Billing → Licenses**) rather than repurposing them as
personas; the verified tenant freed two (`PradeepG`, `LynneR`) and ended at 25 of 25.

**Tom Dean stays enabled now.** In Phase 6.5 — only *after* his shared connections exist — disable him by
re-running `pwsh setup/scripts/01_provision_entra.ps1 -TenantId <tenant-id> -DisableDepartedOwner`, so the
orphan is real. It disables only this estate's Tom (`tom.dean.<estate>@…`).

### Phase 3 — Environments and DLP

**Prerequisites:** `az`, signed in to the lab tenant (Phase 0, step 5). Nothing else: the script drives the
Power Platform admin API with `az`'s saved sign-in, so it runs in the dev container, on the host or on
Windows, and **asks for no sign-in**. (It no longer uses the PowerApps admin module — that module can't
create environments any more — or `pac admin create`, which fails with *No token cache item found …
service.powerapps.com* because `pac` keeps a token only for the resource it signed in for.)

```bash
pwsh setup/scripts/02_provision_environments_dlp.ps1    # estate from HALCOURT_ESTATE (or -Estate <id>)
```

| Creates | What |
|---|---|
| `Halcourt-Prod-<estate>` | Production + Dataverse, **Managed Environment**, `Halcourt-Prod-DLP-<estate>` |
| `Claims-Test-<estate>` | Sandbox + Dataverse — Phase 5 seeds it |
| `Maker-Sandbox-<estate>` | Developer + Dataverse, **assigned to `dev.kim.<estate>`** — his personal environment (Developer environments always come with Dataverse, and its agents need it) |
| `Halcourt (default)` | the tenant's default environment, shared by every estate — named once, by whoever runs first |

`Halcourt-Prod-DLP-<estate>` puts Dataverse, SharePoint, Office 365 Outlook and Office 365 Users in the
**business** group, scoped to this estate's Prod **only**; everything else defaults to non-business and
nothing is blocked. Default / Claims-Test / Maker-Sandbox deliberately stay **without DLP** — that gap
drives Module 5. The script waits for every Dataverse org, then prints a summary with each environment's
region and the exact Phase 5 command (with the Claims-Test org URL). Safe to re-run: what exists is
reported, not recreated.

**You don't choose the country.** The environment API no longer accepts one: it requires a **macro region**
(`-MacroRegion`, default `north-america`) and assigns the country itself — `location` alone is rejected
(*MacroRegionRequired*), and a specific `azureRegion` is ignored. The tenant this runbook was verified on
got **Canada** for every environment. That is fine as long as it's consistent: the script warns if an
estate's environments land in different regions, and the billing plan below follows whatever the summary
reports.

**Conditional Access is already in place.** Phase 0 step 4 created the baseline `CA-Require-MFA-Admins`
and `CA-Block-Legacy-Auth` (it had to come first — security defaults block the device-code sign-ins the
later phases use). Still deliberately create **no** CA policy targeting workload/agent identities — that
omission is a planted Module 5 finding.

**Then wire Copilot Studio pay-as-you-go billing — `02b_provision_billing.ps1`.** Run it after the
environments exist (a plan is region-locked, so it must match where they landed). It resolves this estate's
Prod and Claims-Test and their region, finds a plan in that region with the Copilot Studio (`MCSMessages`)
meter on — estates in a tenant share one plan per region — links both environments, and verifies:

```bash
source scripts/env.sh; export HALCOURT_ESTATE=mgray
pwsh setup/scripts/02b_provision_billing.ps1 -Estate mgray
```

If the region has no plan yet it creates the once-per-region one (a `Microsoft.PowerPlatform/accounts`
resource plus the billing policy) — that branch is `[verify]`, untested on a tenant that already had a plan.
`Maker-Sandbox` is a Developer environment: not linkable and not needed (its agents publish and run without
a plan). Agents **publish** without any plan; a plan is what lets attendees actually send them messages.

<details markdown="block">
<summary>The manual PPAC equivalent (if you'd rather click, or to create the first plan in a region)</summary>

Do this only after the environments exist — a billing plan is locked to one region, so it has to match
where they landed:

1. **Read the region from the script's summary** (the `Region` column — e.g. `canada`), or in PPAC
   (https://admin.powerplatform.microsoft.com) → **Manage → Environments**.
2. **Create the billing plan in that region.** PPAC → **Licensing → Billing Plans → + New billing plan →
   Azure subscription**. Name it `Halcourt-PAYG-<estate>` → pick the **Azure subscription** and **resource
   group** → set the **Meter** to **Copilot Studio** (Dataverse is auto-included) → **Next**. On **Select
   environments**, set the **Region** filter to the summary's region, then **check**
   `Halcourt-Prod-<estate>` and `Claims-Test-<estate>` → **Save**.
3. **Mind the region-lock.** A plan only lists environments in its own region: if an environment isn't in
   the picker, the plan's region doesn't match it (see Errata). `Maker-Sandbox-<estate>` isn't linkable at
   all — billing plans take production and sandbox environments only, not Developer ones — and doesn't need
   to be: agents in it publish without a plan (verified 2026-09-19).

**Or link by API, reusing a plan the region already has.** Estates in one tenant can share a plan; a plan
is just an Azure meter, and each environment's usage is reported separately. With `az` signed in as the
admin:

```bash
# Plans and their regions; pick one in the region the Phase 3 summary reported (create one in PPAC if none).
az rest --method GET --resource https://api.powerplatform.com/ \
  --url 'https://api.powerplatform.com/licensing/billingPolicies?api-version=2022-03-01-preview' \
  --query "value[].{name:name, id:id, region:location, envs:environmentIds}" -o json
# Link this estate's Prod and Claims-Test (environment ids from the Phase 3 summary).
az rest --method POST --resource https://api.powerplatform.com/ \
  --url "https://api.powerplatform.com/licensing/billingPolicies/<policy-id>/environments/add?api-version=2022-03-01-preview" \
  --body '{"environmentIds":["<Halcourt-Prod-estate-id>","<Claims-Test-estate-id>"]}'
```

Re-run the GET to confirm both ids are listed. Check the plan has the **Copilot Studio** meter on (its
`payGoEntitlements` shows `MCSMessages` with `payAsYouGoState: true`). Note the policy object's
`environmentIds` reads as null — the authoritative list is the `/environments` sub-resource the script reads.

</details>

**The *Copilot Studio authors* tenant setting is optional here.** Microsoft documents it as how
pay-as-you-go makers get into Copilot Studio, but on the verified tenant an unlicensed persona opened
Copilot Studio in a linked environment without it. It has no API; if you want it, PPAC → **Manage → Tenant
settings → Copilot Studio authors** → pick one tenant-wide security group, e.g.
`Halcourt-Copilot-Authors` (it exists on the verified tenant). It's one setting for the whole tenant, so
every estate adds its agent owners to that group rather than pointing the setting at its own.

### Phase 4 — SharePoint seed (plant the poisoned doc)

**Once per tenant: register the PnP app.** PnP.PowerShell 3.x has no shared sign-in app. `az`'s saved
sign-in can register one, allow device codes on it and grant admin consent — no sign-in, no consent prompt.
Every estate in the tenant shares it; the commands reuse it if it exists:

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

`az` can't run the seed itself: SharePoint accepts tokens for the Azure CLI's app but rejects them (401).

**Also once per tenant: give the PnP app an app-only identity** — this is what lets the Phase 4 SharePoint
seed (`03 -CertPath`, no device code) and the Phase 4b OneDrive **seed** run headlessly, and needs a
certificate plus **application** permissions (the delegated ones above are for the interactive seed). Three
application roles: SharePoint `Sites.FullControl.All` (site + content ops) and `User.ReadWrite.All` (user
profile reads), plus Graph `Group.ReadWrite.All` (the Phase 4 team sites are M365 groups, created via Graph —
without it the app-only site create 403s). App-only can't *provision* a OneDrive — Phase 4b has the maker do
that themselves, see below:

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
# Graph Group.ReadWrite.All (application) - app-only Phase 4 (03 -CertPath) creates each team site's backing
# M365 group via Graph.
az rest --method POST --url "https://graph.microsoft.com/v1.0/servicePrincipals/$PNP_SP/appRoleAssignments" \
  --body "{\"principalId\":\"$PNP_SP\",\"resourceId\":\"$GRAPH_SP\",\"appRoleId\":\"62a82d76-70ea-41e2-9197-370581804d09\"}" -o none
# DELEGATED User.ReadWrite.All too - the interactive admin provisioning (Phase 4b) needs it in the user token.
# Append it to the app's existing delegated grant (which already has AllSites.FullControl):
GID=$(az rest --method GET --url "https://graph.microsoft.com/v1.0/oauth2PermissionGrants?\$filter=clientId eq '$PNP_SP' and resourceId eq '$SP_SP'" --query 'value[0].id' -o tsv)
az rest --method PATCH --url "https://graph.microsoft.com/v1.0/oauth2PermissionGrants/$GID" \
  --body '{"scope":"AllSites.FullControl User.ReadWrite.All"}' -o none
# A certificate for app-only sign-in (public .cer uploaded to the app, .pfx kept for PnP):
openssl req -x509 -newkey rsa:2048 -keyout pnp.key -out pnp.cer -days 90 -nodes -subj "/CN=HalcourtPnP" >/dev/null 2>&1
openssl pkcs12 -export -out pnp.pfx -inkey pnp.key -in pnp.cer -passout pass:<cert-pw> >/dev/null 2>&1
az ad app credential reset --id $APP --cert @pnp.cer --append -o none
```

> {: .warning }
> `az ad app permission admin-consent` did **not** create the **application** grants on the verified tenant —
> grant them directly with the `appRoleAssignments` POST above, and verify with
> `az rest --method GET --url .../servicePrincipals/$PNP_SP/appRoleAssignments`. Application grants also take
> a few minutes to reach a freshly issued token, so a 403 right after granting usually just means "too soon".
> What *no* amount of waiting fixes is `Request-PnPPersonalSite` (Phase 4b): app-only is refused there
> permanently, because it needs a user context rather than a permission — see the errata.

**Then seed** — one sign-in for the whole run: the script signs in to the root site and reuses that
SharePoint token for both team sites (same host). Three sign-in modes, most-headless first:

**The mode is chosen by what you pass, not by a switch:** give it a certificate and it runs app-only;
otherwise it falls back to a device code, and `-Interactive` opens a browser instead.

```bash
export ENTRAID_APP_ID=<the app id above>       # or pass -ClientId
SITE=https://<tenant>.sharepoint.com

# 1. App-only - fully headless, nothing to click. Needs the cert and the three application roles above.
export HALCOURT_PNP_CERT_PFX=pnp.pfx HALCOURT_PNP_CERT_PW=<cert-pw>
pwsh setup/scripts/03_provision_sharepoint.ps1 -RootSiteUrl $SITE        # -SiteOwner defaults to the az admin

# 2. Device code - works anywhere (incl. the dev container); a human enters one code.
unset HALCOURT_PNP_CERT_PFX HALCOURT_PNP_CERT_PW                         # the cert vars are what pick app-only
pwsh setup/scripts/03_provision_sharepoint.ps1 -RootSiteUrl $SITE

# 3. Browser tab - only where the sign-in redirect can reach this process (host / Windows).
pwsh setup/scripts/03_provision_sharepoint.ps1 -RootSiteUrl $SITE -Interactive
```

> {: .note }
> App-only site creation waits up to 15 min for a fresh tenant to provision each group site. If a prior
> failed/torn-down run left a **soft-deleted** site at `/sites/<alias>`, the new site lands at a suffixed URL
> (`…-mgray9`) and the wait times out — purge it first with `Remove-PnPTenantDeletedSite` (see errata).

Estate from `HALCOURT_ESTATE` (or `-Estate <id>`). Creates two private Microsoft 365 group team sites —
`/sites/HR-Benefits-<estate>` (with a `Leadership/` subfolder holding `2026-comp-bands.xlsx`) and
`/sites/Claims-Knowledge-<estate>` — and **plants `Open-Enrollment-FAQ.docx`** built from
`setup/data/Open-Enrollment-FAQ.md` (which carries the indirect-injection payload — see the SPOILER block
in `AGENTS.md`), with the trailing *Notes* section hidden (vanish + white text) so a reader doesn't see it
while grounding still ingests it. It also creates a **separate, clean `HR FAQ` document library** in
`HR-Benefits` holding one benign, all-staff FAQ (`setup/data/HR-FAQ-Published.md`, no payload, no
`Leadership/`) — the grounding source for the **HR FAQ v2 (copy) decoy**, kept apart from the poisoned
`Shared Documents` so the decoy inspects clean. Claims-Knowledge gets `claims.csv` and
`Claims-Procedures.docx`. Safe to re-run: existing sites and libraries are reused and files are overwritten.

It also sets the access Scenarios A and B depend on (`AGENTS.md` → *SharePoint access*), from the Phase 2
groups:

| Site | Members (edit) | Visitors (read) |
|---|---|---|
| `HR-Benefits-<estate>` | `HR-Team-<estate>` (Marcus) | `All-Employees-<estate>` — **except `Leadership/`**, which stops inheriting and drops the visitors |
| `Claims-Knowledge-<estate>` | `Claims-Adjusters-<estate>` (Priya, Sam) | `All-Employees-<estate>` |

So Marcus can read `Leadership/2026-comp-bands.xlsx` and Jordan can't. It ends by reading everything back —
each site's members and visitors, every file, the role assignments on `Leadership/`, and the planted `.docx`
as SharePoint serves it (hidden runs and payload present) — so the run is its own evidence.

### Phase 4b — Provision and seed the maker OneDrive

**Prerequisite for Phase 6.** The **Meeting Notes Summarizer** decoy grounds on **Dev Kim's own OneDrive
notes**, so his OneDrive must exist and hold his notes *before* that agent is built. A Dev Program sandbox
does **not** auto-provision a user's OneDrive reliably — the first browser visit can die with *"a default
document library could not be created"* — so this is an explicit step, not something that just happens.

```bash
export ENTRAID_APP_ID=<the Halcourt PnP app id>
export HALCOURT_PNP_CERT_PFX=<path to pnp.pfx>   HALCOURT_PNP_CERT_PW=<cert-pw>
pwsh setup/scripts/03b_provision_onedrive.ps1     # estate from HALCOURT_ESTATE (or -Estate <id>)
```

The script does two things: **provision** Dev's personal site (`Request-PnPPersonalSite`) and, once it is
online, **seed** `setup/data/Dev-Kim-Meeting-Notes.md` (built to `.docx`) into his **Documents**. If the site
already exists it skips provisioning and just seeds (so it pairs with the interactive step below). It prints
the OneDrive URL to ground the decoy on:

```text
https://<tenant>-my.sharepoint.com/personal/dev_kim_<estate>_<tenant>_onmicrosoft_com/Documents
```

> {: .important }
> **The maker touches their own drive — no admin, and `[verify]` best-effort.** The script signs in **as Dev**
> with the lab password and calls `GET /me/drive`, which answers `ResourceNotFound` and can enqueue the
> personal site behind it; personas are ordinary users, so nothing in the CA baseline blocks the password
> grant. **It is not guaranteed:** on the verified tenant this created Dev's site within a minute but had
> produced nothing for another persona 47 minutes later, on identical licensing. First-access provisioning is
> asynchronous with no SLA. So the script tries, waits, and if the site never appears it fails and tells you
> to provision that one maker by hand (command below) and re-run — which then just seeds. Seeding is app-only
> with the PnP certificate either way.
>
> This is worth knowing because the **admin-side** enqueue can't be done headlessly (all verified
> 2026-09-22): **app-only** is refused — *"Attempted to perform an unauthorized operation"* — even with every
> application grant (the same token does other tenant-admin work fine, so it wants a *user context*, not a
> permission); the **Azure CLI's** delegated token is **401 for every SharePoint tenant-admin call** even as
> Global Admin; and a **freshly created SharePoint Administrator** signs in fine but is still refused,
> because SharePoint doesn't honour a new role assignment for 15–60 min.

> {: .warning }
> Don't use Graph to check whether the OneDrive is ready. `GET /users/<upn>/drive` kept returning
> `ResourceNotFound` for Dev **after** his OneDrive existed and had been written to. The script probes the
> personal site with PnP instead.

If you'd rather provision by hand (e.g. the wait is inconvenient), do it once as the tenant admin and then
run `03b_provision_onedrive.ps1` to seed — it detects the site is online and skips provisioning:
```bash
pwsh -NoProfile -Command "Connect-PnPOnline -Url https://<tenant>-admin.sharepoint.com -DeviceLogin -ClientId $ENTRAID_APP_ID; Request-PnPPersonalSite -UserEmails dev.kim.<estate>@<domain>"
```

### Phase 5 — Dataverse seed

**Prerequisites:** `az`, signed in to the lab tenant — nothing else. The script drives the Dataverse Web API
and the Power Platform admin API with `az`'s saved sign-in, so it runs in the dev container, on the host or on
Windows and **asks for no sign-in**. (It replaced a Windows PowerShell 5.1 script on
`Microsoft.Xrm.Data.PowerShell` — an ADAL-based module with an interactive Windows sign-in dialog.)

```bash
pwsh setup/scripts/04_provision_dataverse.ps1    # estate from HALCOURT_ESTATE (or -Estate <id>); finds Claims-Test-<estate> itself
```

In `Claims-Test-<estate>` it creates the `mm` publisher and two tables, seeds them from `setup/data/`, and
builds the **over-broad** role:

| Table | Columns | Rows |
|---|---|---|
| `mm_customer` | `mm_name` (primary), `mm_customernumber`, `mm_ssn`, `mm_dob` — **PII** | `customers.csv` (5) |
| `mm_claim` | `mm_claimnumber` (primary), `mm_status`, `mm_amount`, `mm_adjuster`, `mm_customer` (lookup) | `claims.csv` (5) — each adjuster becomes this estate's account, e.g. `priya.nair.<estate>@…` |

`svc-claims Dataverse Full Access` holds create / read / write / append / append-to / assign / share on
**both tables at Global depth** — every row, PII included, no row-level security — and is assigned to
`svc-claims.<estate>`. Least privilege here is what Module 5 will *close*. (The business keys are
`…number` columns because a table's primary key is always `<table>id`; the CSVs' `mm_customerid` /
`mm_claimid` map onto them.) It ends by reading back the rows, the role's privileges and the assignment.
Safe to re-run.

{: important}
**`svc-claims.<estate>` needs a license — one Microsoft 365 E5 seat is enough.** Without one the script
builds everything else and reports the role assignment as **PENDING**; assign the seat and re-run it to
finish.

**Why a license.** A security role can only be assigned to a Dataverse user record, and Dataverse creates
one only for an Entra account that is enabled **and licensed**
([requirements](https://learn.microsoft.com/power-platform/admin/create-users#requirements-for-successfully-adding-users-in-dataverse)).
The exceptions — admin roles, non-interactive accounts, app-pass capacity — don't fit a service account, so
an unlicensed svc-claims is refused (*userNotLicensed*) and there is nothing to hang the role on. Without
the role, Claims Copilot's shared connection can't read the claims data, and Scenario C (the over-broad
role) and Scenario D (the agent exercising svc-claims's authority instead of the caller's) have nothing to
show.

**Why E5 is enough.** E5 — including the Dev Program sandbox's `DEVELOPERPACK_V2_E5` — carries a free
Dataverse plan (`DYN365_CDS_O365_P3`). Dataverse honors that plan only when a user is added **on demand**
(the admin API or PPAC), not by the background sync; the script's add is on demand. No Power Apps or
Dynamics 365 license is needed. `Claims-Test-<estate>` has no security group, so the license is the only
gate.

```bash
SKU=$(az rest --method GET --url https://graph.microsoft.com/v1.0/subscribedSkus \
  --query "value[?skuPartNumber=='DEVELOPERPACK_V2_E5'].skuId | [0]" -o tsv)   # or your tenant's E5 SKU
az rest --method POST \
  --url "https://graph.microsoft.com/v1.0/users/svc-claims.$HALCOURT_ESTATE@<domain>/assignLicense" \
  --body "{\"addLicenses\":[{\"skuId\":\"$SKU\"}],\"removeLicenses\":[]}"
pwsh setup/scripts/04_provision_dataverse.ps1                                  # now reports: done
```

**Mind the seat budget.** The personas who own agents or connections in the Dataverse environments in
Phase 6 (Marcus, Priya, Lena, Dev, Tom) need seats for the same reason; with svc-claims that is six — all
the free seats in a sandbox whose sample users hold 19 of 25 (Phase 2). If you are short, Microsoft's
non-interactive route gives svc-claims's seat back: license it, run this script, set its **Access Mode** to
**Non-interactive** (PPAC → the environment → Users → svc-claims → *Manage user in Dynamics 365* →
Administration), then remove the license; up to seven per environment. **[verify]** that Claims Copilot's
connection still works as a non-interactive account before relying on it.

### Phase 6 — Author the agents

Build all ten agents (eight planted + two decoys) exactly per `AGENTS.md`, each **as its owner**
(`<alias>.<estate>@…`) in the environment it names. Two routes: the **engine** replays committed agent
workspaces; the **portal / `pac`** path (below, and [`agent-authoring-guide.md`](agent-authoring-guide.md))
builds one by hand and is how the planted agents are first captured.

**Automated path — `06_provision_agents.ps1`.** Reads `setup/agents/manifest.json` and, for the estate,
verifies owner roles, authenticates each connection (headless consent via `lib/consent_browser.py`), then
per agent (re)builds its committed `setup/agents/<slug>/` workspace **as its owner**.

> {: .note }
> The headless consent needs **Playwright + Chromium** (`lib/consent_browser.py`). The dev container installs
> them (`.devcontainer/on-create.sh`); outside it, `pip install playwright && python3 -m playwright install
> --with-deps chromium` first, or every connection fails with *consent failed*.

Mechanics worth knowing (verified through the 2026-09-22 greenfield rebuild — see the
[errata](../reference/runbook-errata.md) *Greenfield rebuild validation* for the fresh-env fixes):

- **Clone-first, committed-authoritative.** `pac copilot push` only *updates* and needs a *synced* local
  workspace (matching `.mcs` state), which a committed (gitignored `.mcs`) workspace never has, and which
  `init` alone doesn't reliably leave behind. So each provision **clones** the agent into a temp dir (pac's
  own existence view — the Dataverse `bots` table can disagree), drops the clone's server-state
  knowledge/tools/conn-refs, overlays the committed ones, and pushes. If clone finds nothing the agent is
  absent, so it `init`s the shell first (retried — the solution import lags) then clones. Preserves the
  agent identity (no delete).
- **Publisher.** Each agent keeps its committed prefix; the engine ensures a publisher with that prefix
  exists in the environment (creates it on a fresh rebuild — env teardown gives new random CDS prefixes).
- **Owner-token Dataverse.** Bot lookup, chat-audience PATCH and connection binding run **as the owner**,
  not admin — in the shared default environment the admin has no read on `bots` (it returns empty), and a
  connection reference can only be bound by the connection's owner (Sales Nudge is Lena's but binds Tom's
  connection; Claims Copilot is Priya's but binds svc-claims's).
- **Chat audience** on the bot record, then **publish with retry** (publishing right after create can be
  too soon).

```bash
source scripts/env.sh; export HALCOURT_ESTATE=mgray            # estate id (or pass -Estate)
az account show                                                # signed in as the lab admin
# Prereqs (this section, below): owner seats, it.helpdesk sign-in, default-env Dataverse, billing; and OneDrive (Phase 4b)
pwsh setup/scripts/06_provision_agents.ps1 -VerifyOnly         # resolve + report, change nothing
pwsh setup/scripts/06_provision_agents.ps1                     # full run: roles + connections + agents
pwsh setup/scripts/06_provision_agents.ps1 -Agents hr-faq-v2   # one agent; also -SkipPrereqs -SkipConnections
```

**All ten agents author from committed workspaces — no portal (verified 2026-09-22).** Connector tools go in a
`TaskDialog`; the HTTP action, MCP invoke, and flow invoke go in a **topic** (a native HTTP/MCP/flow action
publishes as a topic node but not as a tool — see errata). One prerequisite: **Expense Helper's flow** is a
Copilot-triggered Dataverse `workflow` created (owned by Sam) before its agent — the engine resolves
`${FLOW:<name>}` to the live id. So:

| Agent | Tool mechanism |
|---|---|
| Benefits Buddy, HR FAQ v2 | SharePoint knowledge (no tool) |
| Team Wiki | connector tool (Graph search) · Meeting Notes: OneDrive knowledge |
| Sales Nudge, Onboarding Guide, Claims Copilot | connector tools (`InvokeConnectorTaskAction`) |
| Policy Lookup Bot | topic + `HttpRequestAction` (hard-coded key) |
| Underwriting Assistant | topics + `InvokeMcpTool` (get_quote / get_risk_score / run_query) |
| Expense Helper | flow (`workflow` record) + topic `InvokeFlowAction` |

An agent runs only if its workspace is committed under `setup/agents/<slug>/` (`capture:"authored"` in the
manifest); others report `SKIP`. Most agents — the benign four **and** the connector/HTTP planted ones — are
authored as committed workspaces here (`agent.mcs.yml` instructions + `knowledge/` + `actions/` +
`connectionreferences.mcs.yml`, scaffolded with `pac copilot init` then filled in). The ones that need a
portal-only feature, a **Power Automate flow** (Expense Helper), or the **MCP server** (Underwriting) are
built once in the portal and captured into a committed workspace with `pac copilot clone`
(`capture:"clone"`), then replayed thereafter:

```bash
pac copilot clone --bot <schema-name> --environment <env-org-url> --output-dir setup/agents   # then rename the folder to the manifest slug
```

**Before you build.** Copilot Studio keeps agents in Dataverse, so every owner has to be a licensed user of
the environment the agent lives in, and the default environment needs Dataverse too. With `az` signed in
as the admin (`E` = estate id, `D` = tenant domain):

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

Step 3 is shared by every estate, like the CA baseline; it took a few minutes on the verified tenant. Two
agents (Expense Helper, Onboarding Guide) live in the default environment, so without it they can't be
built.

**Also confirm Phase 4b ran** — Dev's OneDrive is provisioned and holds `Dev-Kim-Meeting-Notes.docx` — or the
**Meeting Notes Summarizer** decoy has nothing to ground on.

**4. Put each owner in their environment with a maker role.** Add the user (PPAC → the environment →
**Settings → Users + permissions → Users → Add user**, or the call below), then **Manage security roles**:

| Environment | Owner and role |
|---|---|
| `Halcourt-Prod-<estate>` | Marcus, Priya, Lena, `it.helpdesk`: **Environment Maker** · Tom: **System Administrator** — the departed admin's broad CRM reach behind Sales Nudge |
| `Claims-Test-<estate>` | Priya, `svc-claims`: **Environment Maker** — `svc-claims` creates its own Dataverse connection there |
| `Maker-Sandbox-<estate>` | Dev — already **System Administrator** of his own Developer environment; the admin has no role there |
| `Halcourt (default)` | Sam, Tom: **Environment Maker** |

```bash
az rest --method POST --resource https://service.powerapps.com/ \
  --url "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/<env-id>/addUser?api-version=2020-10-01" \
  --body "{\"ObjectId\":\"$(az ad user show --id marcus.webb.$E@$D --query id -o tsv)\"}"
```

It can fail once with a transient *instanceNotFound*; run it again.

**5. Billing** — `Halcourt-Prod-<estate>` and `Claims-Test-<estate>` linked to a plan (Phase 3).

**6. Connections, created by their owners.** Each connection in `worksheets/artifact-pack/connections-export.csv`
is created by the persona it names, signed in as that persona, in the environment it names — e.g.
`svc-claims` creates `DV-Claims-Shared` in `Claims-Test-<estate>`. What to expect:

- **OAuth connections can't be shared.** Sharing `DV-Claims-Shared` or `DV-CRM-Shared` with a group fails
  with *ConnectionSharingNotAllowed*, so the pack's `shared_with` values for them can't appear in a live
  export. The agent is what "shares" them: its tools run on the connection with the maker's credentials.
- **In the default environment the consent page asks the owner to confirm** ("Confirmation required", a
  checkbox, then **Allow access**). That's expected for a connection the owner just created.
- **Dev's OneDrive connection fails until his OneDrive exists.** Sign in to OneDrive once as Dev; it is set
  up in a few minutes.

On the verified tenant all eight persona connections were created and signed in by a script that drives a
headless browser as each owner; that script is not in the repo yet.

**Building from the command line.** `pac` 2.12 builds and publishes an agent from a local workspace. Sign
it in as the owner, with a profile store of its own so your admin profile is untouched. Password sign-in
works for the personas because the Conditional Access baseline only requires MFA of admin roles. Call
the real `pac`, not the repo's shim (the shim pins the profile store to `.pac/`):

```bash
export XDG_DATA_HOME=$HOME/.halcourt-pac/marcus.webb     # one store per persona
~/.dotnet/tools/pac auth create --username marcus.webb.$E@$D --password '<lab password>' --environment <Prod org URL>
~/.dotnet/tools/pac copilot init --name "Benefits Buddy" --publisher-prefix <prefix> --project-dir agents/benefits-buddy
#   edit agents/benefits-buddy/agent.mcs.yml (instructions) and add knowledge/*.mcs.yml, actions/*.mcs.yml
~/.dotnet/tools/pac copilot push --project-dir agents/benefits-buddy
~/.dotnet/tools/pac copilot publish --bot <prefix>_BenefitsBuddy
```

- `<prefix>` is the environment's **CDS Default Publisher** prefix — the one the portal uses (`cr3f5` for
  Prod and Claims-Test on the verified tenant). `init` imports the agent straight away, owned by the persona.
- **`push` doesn't send `settings.mcs.yml`.** Set the chat audience on the agent record instead — PATCH
  `bots(<botid>)` with `authorizedsecuritygroupids` = the group's object id — then publish again.
- **`push` creates a connection reference but doesn't bind it.** PATCH `connectionreferences(<id>)` with
  `connectionid` = the owner's connection name, as the owner.
- A failed publish reports its errors in the agent record's `synchronizationstatus` →
  `lastFinishedPublishOperation`, not in `pac`'s output.

Built this way on the verified tenant (2026-09-19): **Team Wiki** (`Maker-Sandbox-mgray`, as Dev) and
**Benefits Buddy** (`Halcourt-Prod-mgray`, as Marcus). The other eight are still to build.

**Phase 6.5 — orphan Tom Dean.** After Onboarding Guide and Sales Nudge exist and their **shared
connections are owned by `tom.dean.<estate>`**, disable Tom's account by re-running
`pwsh setup/scripts/01_provision_entra.ps1 -DisableDepartedOwner` (same estate). The agents and connections must remain
live — that is the orphan.

### Phase 7 — Export the artifact pack

```powershell
pwsh setup/scripts/05_export_artifact_pack.ps1 -Canonicalize    # estate from HALCOURT_ESTATE (or -Estate <id>)
git diff worksheets/artifact-pack
```

Pulls **this estate** — its environments, its agents and connections in the shared default environment,
and its accounts (no admins, no sample users) — from PPAC admin APIs + Microsoft Graph, and writes the five
CSVs. `-Canonicalize` maps the live names back to the canon's (strips the estate id, restores
`@halcourtmutual.onmicrosoft.com`), so the export lands on the committed pack and `git diff` shows the
drift; the committed files ARE the expected output for the canonical estate. Without `-Canonicalize` the
script refuses to write into the committed pack, which is published with the site — pass `-OutDir` for a
live-named export.

**Runs anywhere now** — the dev container included. It used to require the Windows build VM because it drove
`Microsoft.PowerApps.Administration.PowerShell`, whose `Add-PowerAppsAccount` needs `System.Windows.Forms`
and dies on Linux. It now reads the same data over REST with `az`'s sign-in, like Phases 3, 5 and teardown.
One prerequisite remains:

- **Give the admin a security role in every Dataverse environment.** The agent inventory reads each
  environment's `bot` table; without a role the read fails with *"has not been assigned any roles"* (403).
  Environments the admin created in Phase 3 already have it. A **Developer** environment does not — its
  owner is its only System Administrator:
  `pac admin assign-user --environment <environment-id> --user <admin UPN> --role "System Administrator"`.

> {: .important }
> **The committed pack is not a pure export, so do not expect an empty `git diff`.** Three of its columns
> are hand-written canon that no API returns: agent `description`, the friendly connector names
> (`SharePoint`, not `shared_sharepointonline`), and the rows for things that are not Power Platform
> connections at all (`HTTP-PolicyAPI`, `MCP-Underwriting`, `PA-Expense-AutoApprove`). The export therefore
> **preserves** the existing `description` text by display name rather than blanking it — regenerating the
> pack will not destroy that prose — but the connector and conceptual-connection rows still need a human.
> Read the diff as *drift to review*, not as a test that should come out empty.


### Phase 8 — Validate

Walk `AGENTS.md` and confirm, in the live tenant:
- Every **PLANTED PROBLEM** reproduces (A–F fire; discovery targets are findable).
- Every **CONTROL EFFICACY** verdict holds; resolve any `[verify]` items and update `AGENTS.md`.
- Guest (Ana) read access works; the Jordan Blake confused-deputy path works.
- **Phase 6.5 has run** (`01_provision_entra.ps1 -DisableDepartedOwner`) — Tom must be disabled *after* his
  connections exist, or the departed-owner thread reads wrong and `users-export` disagrees with the canon.
- Re-run Phase 7 and **review** `git diff worksheets/artifact-pack`. It will not be empty, and should not
  be: see the Phase 7 note above for the three columns that are canon rather than exported. What to look
  for is *unexpected* drift — an agent missing, an owner that changed, a connection that lost its sharing,
  an environment that lost its DLP.

What the export can confirm on its own, without driving an agent: every published agent is present with the
right owner and environment; each has exactly one Entra identity; DLP is attached to Prod and nowhere else;
and the accounts are as Phase 2 left them. Reproducing Scenarios A–F still means talking to the agents.

### Phase 9 — Teardown / reseed

`99_teardown.ps1` removes ONE estate and nothing another estate owns, in dependency order: the shared
default environment's agents + the auto-approve flow (as their owners) → the SharePoint sites (purged from
the recycle bin so the URLs are reusable — needs the Phase 4 PnP app + cert) → the three estate environments
(their Dataverse, agents and connections go with them) → the DLP policy → billing unlink. It drives the
Power Platform admin API, Graph and SharePoint with `az`'s sign-in — no Windows-only module.

```bash
source scripts/env.sh; export HALCOURT_ESTATE=mgray                 # signed in as the lab admin
export ENTRAID_APP_ID=<PnP app id>  HALCOURT_PNP_CERT_PFX=<pnp.pfx>  HALCOURT_PNP_CERT_PW=<cert-pw>   # for site removal
pwsh setup/scripts/99_teardown.ps1                                  # estate artifacts; KEEPS personas + shared infra
pwsh setup/scripts/99_teardown.ps1 -RemovePersonas                 # also the Phase 2 personas + *-<estate> groups (incl. the site M365 groups)
pwsh setup/scripts/99_teardown.ps1 -RemovePersonas -RemoveShared   # also the shared authors group + PnP app registration
# Azure (Phase 1) is separate:
azd down --purge --force                                           # repo root, the estate's azd env selected
```

Environments delete asynchronously (a few minutes). It KEEPS Phase 0 (tenant, CA baseline, security
defaults) and the shared **default environment** (and its Dataverse — that can't be un-provisioned). To
reseed, re-run Phases 1–6. If you rebuild the Azure endpoints, run Phase 1 under a **new** azd environment
name — a torn-down name can't be reused (Foundry soft-delete; Errata) — the agents' `${…}` action tokens
re-inject the new addresses at Phase 6 provision time.

## File index (this kit)

| Path | Purpose |
|---|---|
| `infra/` (root azd project) | Deploys web + Foundry + Policy API + Underwriting MCP Container Apps via `azd up` |
| `setup/infra/policy-api/` | Minimal, intentionally over-scoped Policy API (static key) |
| `setup/infra/mcp-underwriting/` | Minimal Underwriting MCP server (static bearer, `run_query`) |
| `scripts/00_conditional_access_baseline.ps1` | Security defaults off → `CA-Require-MFA-Admins` + `CA-Block-Legacy-Auth` (Phase 0) |
| `scripts/_estate.ps1` | Estate naming rule, dot-sourced by the scripts (Estates, above) |
| `scripts/01_provision_entra.ps1` | Personas, groups, `svc-claims`, shared mailbox |
| `scripts/02_provision_environments_dlp.ps1` | Environments, Managed Prod, prod DLP (az only; runs anywhere) |
| `scripts/03_provision_sharepoint.ps1` | Sites + clean FAQ library + **plant poisoned doc** |
| `scripts/03b_provision_onedrive.ps1` | Provision + seed dev.kim's OneDrive (Meeting Notes grounding; app-only PnP) |
| `scripts/04_provision_dataverse.ps1` | Claim/Customer tables, PII rows, over-broad role (az only; runs anywhere) |
| `scripts/05_export_artifact_pack.ps1` | Regenerate the artifact-pack CSVs |
| `scripts/06_provision_agents.ps1` | Provision the agents from committed workspaces (roles + connections + push/publish as owner) |
| `scripts/lib/consent_browser.py` | Headless connection-consent helper (the only browser step in Phase 6) |
| `scripts/99_teardown.ps1` | Remove the estate |
| `agents/manifest.json` | Phase 6 control data: agents + connection definitions (estate-agnostic) |
| `agents/<slug>/` | Committed `pac copilot` agent workspaces the engine replays |
| `agent-authoring-guide.md` | Manual Copilot Studio authoring, per agent (portal / `pac`) |
| `data/` | Seed data: poisoned-doc source (`Open-Enrollment-FAQ.md`), clean decoy FAQ (`HR-FAQ-Published.md`), Dev's meeting notes (`Dev-Kim-Meeting-Notes.md`), Expense Helper flow (`expense-approve-flow.json`) |
| `agents/manifest.json` → `flows` | Copilot-triggered flows the engine creates (as the owner) before agents, so `${FLOW:<name>}` resolves |
| `../reference/runbook-errata.md` | Errata, options, known issues for this runbook |

{: warning}
Several script steps depend on 2026 product surfaces still settling (CA for workload identities, `pac`
agent commands). Lines marked `# [verify]` need confirmation against the
delivery-date tenant; treat them as the intended operation, not a guaranteed cmdlet.

## Errata, options & known issues

Moved to [`../reference/runbook-errata.md`](../reference/runbook-errata.md) — background, alternatives,
troubleshooting, and open `[verify]` risks, keyed to the phase/step they relate to.

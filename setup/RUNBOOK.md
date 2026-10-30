# RUNBOOK.md — Facilitator provisioning

> **FACILITATOR-ONLY. Not published** (the whole `setup/` folder is excluded in `_config.yml`).
> Provisions the intentionally-vulnerable **Halcourt Mutual** demo estate. Everything here is keyed to the
> canon in [`../AGENTS.md`](../AGENTS.md) — that file is the source of truth; this file is how you build it.
>
> **This file is the instructions.** The reasoning lives in
> [`../reference/adr/`](../reference/adr/README.md) (decision records: why it is built this way,
> tradeoffs, alternatives) and [`../reference/runbook-errata.md`](../reference/runbook-errata.md)
> (what goes wrong, troubleshooting, open `[verify]` risks). Each phase links to its own section there.

Attendees share one live estate for Exercise 04 and 05; Exercise 05 is demonstrated by the facilitator.
The artifact pack is the offline fallback. Why:
[ADR-0002](../reference/adr/0002-shared-vs-individual-estates.md).

{: .important }
> The estate is deliberately broken. Provision it in an **isolated training tenant** you control. Never
> point these scripts at a production tenant.

## Before you start

You run this runbook from VS Code, inside the repo's **dev container** — a Linux container that has every
tool the scripts need already installed.

1. Install [VS Code](https://code.visualstudio.com/), its
   [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
   and [Docker Desktop](https://www.docker.com/products/docker-desktop/). Start Docker Desktop.
2. Clone this repo and open its folder in VS Code.
3. Open the Command Palette (**⇧⌘P** on a Mac, **Ctrl+Shift+P** on Windows) and run
   **Dev Containers: Reopen in Container**. The first build takes about 15 minutes; later opens take
   seconds. The bottom-left corner of the window shows **Dev Container** when it is done.
4. Open a terminal: **Terminal → New Terminal**. Run every command in this runbook in that terminal unless
   a step says otherwise, and sign in to `az` and `pac` only from it — a sign-in made outside the container
   isn't seen by the scripts ([ADR-0003](../reference/adr/0003-project-local-sign-in.md)).
5. Make sure you hold **Contributor** on the lab subscription. Phase 3 may create the shared billing plan
   and Phase 4c the Graph billing resource, both Azure resources. The **owner of the shared Azure
   deployment** (Phase 1) needs **Owner** (or Contributor + User Access Administrator): the deployment
   creates role assignments, which Contributor alone can't.

**The admin portals.** This runbook names each portal in full; "PPAC" is the Power Platform admin center.

| Portal | Address |
|---|---|
| Microsoft 365 admin center | https://admin.microsoft.com |
| Microsoft Entra admin center | https://entra.microsoft.com |
| Power Platform admin center (PPAC) | https://admin.powerplatform.microsoft.com |
| Azure portal | https://portal.azure.com |

The container's tools and what each phase uses them for: [toolchain](../reference/toolchain.md). Want a
real Windows desktop browser for interactive sign-in and MFA? See
[`windows-vm/README.md`](windows-vm/README.md) — optional.


## Phase order (do NOT reorder)

```
0. Provision isolated tenant   → fresh *.onmicrosoft.com, licensing, security defaults → CA baseline
0b. Choose your estate id      → once per build, in a tenant that already exists
1. Azure infra (Bicep)        → Policy API + Underwriting MCP endpoints
2. Entra identities/personas  → users, groups (tom.dean: leave date in 6.5, stays enabled)
3. Environments + DLP          → 4 environments, prod DLP, PAYG billing plan
4. SharePoint seed             → HR-Benefits + Claims-Knowledge, PLANT the poisoned doc
4b. Maker OneDrive             → provision + seed dev.kim's OneDrive (Meeting Notes grounding)
4c. Purview                    → Confidential-PII label + labelled comp copy (05-06); DAYS before delivery
5. Dataverse seed              → Claim + Customer tables, PII rows, the over-broad role
5b. Auditing                   → Purview Audit + Claims-Test change auditing (05-07); before Exercise 04
6. Author the agents           → as each owner, from the committed workspaces
6c. Recheck the Purview label  → re-run 4c until the copy is labelled
7. Export the artifact pack    → regenerate ../worksheets/artifact-pack/*.csv
8. Validate                    → every planted problem reproduces; verdicts hold
8b. Lab (attendee) accounts    → per delivery: N native accounts to hand out, removed again afterwards
8c. Per-student slices         → an environment each, BEFORE Exercise 03: attendees open the svc-claims role
                                 there as System Administrator (03-01/03-02)
9. Teardown / reseed
```

---

### Phase 0 — Provision the isolated training tenant

Once per lab tenant. Mostly a portal flow. **Building in a tenant someone else already set up?** Skip to
[Phase 0b](#phase-0b--choose-your-estate-id); you need its global admin sign-in.

{: .important }
> This tenant **must not** be linked to any production or corporate tenant. Sign up with a **personal or
> lab-dedicated admin credential — never corporate SSO**.

1. **Sign up for a new M365 tenant.** Skip if the tenant already exists.
   - Create an **Azure billing account** first. Signup uses it for a one-time verification and doesn't
     charge it. It can take hours to appear.
   - Go to the **Microsoft 365 Developer Program**: https://developer.microsoft.com/microsoft-365/dev-program
   - Join with a **personal or lab email**, never your corporate account.
   - Choose **Instant sandbox (Add-on purchases enabled)** — a 90-day renewable E5 sandbox.
   - Pick the **data-center region**. You can't change it later.
   - Accept whatever **domain** signup assigns (e.g. `a1b2c3d4.onmicrosoft.com`). The scripts use it as is.
   - **Install the content pack** if signup offers it. Its ~16 sample users take E5 seats — you free them
     in step 3.
   - Trouble with the variant, a billing account that doesn't show up, or no Developer Program:
     [errata → Phase 0](../reference/runbook-errata.md).

2. **Complete initial tenant setup.**
   - Create the **global administrator**. Record its UPN — you sign in as it throughout.
   - Existing tenant: any account that holds **Global Administrator** will do. "The global admin" in this
     runbook means whichever account you use.
   - Confirm **MFA is registered** on it: **Microsoft Entra admin center** → **Users** → the admin user → **Authentication
     methods**.
   - Record the **data-center region**: **Microsoft 365 admin center** → **Settings → Org settings → Organization profile →
     Data location**. Phase 1 uses it as `AZURE_LOCATION`.
   - Confirm the admin can open **Power Platform, Entra, SharePoint, Purview, Conditional Access and
     Defender**. Global Administrator covers all of them in a fresh tenant.

3. **Assign licensing.**
   - **Free the content pack's seats.** **Microsoft 365 admin center** → **Billing → Licenses** → the E5 developer
     licence → select the sample users → **Unassign licenses**. Leave the users themselves.
   - In a new tenant that is everyone except the global admin. In a tenant where estates are already built,
     **don't** unassign estate accounts — they carry an estate id (`marcus.webb.jsmith@…`,
     `student01.jsmith@…`).
   - The personas (Phase 2) and attendees (Phase 8b) need those seats.
   - **Microsoft 365 admin center** → **Billing → Licenses** → assign an **E5** seat to the global admin.
   - E5 comes with the sandbox and covers the Purview features the labs use.
   - The personas get their seats in Phase 2.

4. **Replace security defaults with the Conditional Access baseline.** Once per tenant.
   - Run it in the dev container terminal. It prints a web address and a code; open the address, enter the
     code, and sign in as the global admin. Safe to re-run: in a tenant that already has the baseline it
     changes nothing and prints the policies' state.

     ```bash
     pwsh setup/scripts/00_conditional_access_baseline.ps1 -TenantId <tenant domain> -UseDeviceCode
     ```

   - Sign-in refused with **AADSTS530035**? Security defaults are still on (a new tenant) and block
     device-code sign-in. Run it instead in a terminal on your own machine, from your clone of the repo,
     without `-UseDeviceCode`. That needs PowerShell 7 and `pwsh -c "Install-Module Microsoft.Graph -Scope
     CurrentUser"`. A browser tab opens; pick the global admin **within two minutes**.
   - First run only: it asks for `Policy.ReadWrite.ConditionalAccess` and `Policy.Read.All`. Tick
     **Consent on behalf of your organization**.
   - It turns security defaults off and creates two policies:

     | Policy | Applies to | Control |
     |---|---|---|
     | `CA-Require-MFA-Admins` | 15 admin roles — Microsoft's *Require MFA for admins* template set, plus Power Platform Administrator | Require MFA |
     | `CA-Block-Legacy-Auth` | All users | Block Exchange ActiveSync and other legacy clients |

   - If a policy fails, it rolls back and turns security defaults back on. Safe to re-run.
   - **Wait ~10 minutes** before the first device-code sign-in. Sign-ins take a while to stop seeing
     security defaults.
   - Why the swap is mandatory and what it gives up:
     [ADR-0010](../reference/adr/0010-ca-baseline-replaces-security-defaults.md).

5. **Consent to the Graph scopes.** Once, for the whole organization, as the global admin.
   - Run it in the dev container terminal. Safe to re-run: scopes already granted are skipped, and only
     missing ones are asked for.

     ```bash
     pwsh -c "Connect-MgGraph -TenantId <tenant domain> -UseDeviceCode -Scopes Policy.ReadWrite.ConditionalAccess,Policy.Read.All,User.ReadWrite.All,Group.ReadWrite.All,User.Read.All,Application.Read.All,AuditLog.Read.All"
     ```

   - It prints a web address and a code; open the address, enter the code, and sign in as the global admin.
   - If a consent screen appears, tick **Consent on behalf of your organization**, then **Accept**. No
     screen means everything was already granted.
   - Check it: **Entra admin center → Enterprise applications → Microsoft Graph Command Line Tools →
     Permissions**.
   - What each scope is for:

     | Scope | Used by |
     |---|---|
     | `Policy.ReadWrite.ConditionalAccess`, `Policy.Read.All` | `00_conditional_access_baseline.ps1` (step 4) |
     | `User.ReadWrite.All`, `Group.ReadWrite.All` | `01_provision_entra.ps1` (Phase 2), `99_teardown.ps1` |
     | `User.Read.All`, `Application.Read.All` | `05_export_artifact_pack.ps1` (Phase 7) |
     | `AuditLog.Read.All` | `05_…` — its users export reads `signInActivity` |

   - `pac` needs nothing granted. PnP.PowerShell gets its own app registration in Phase 4.

6. **Verify Phase 0.**
   - [ ] The global admin can sign in to https://admin.microsoft.com with MFA.
   - [ ] **Security defaults are off**, and both baseline policies are **On**.
   - [ ] The admin account has an **E5** licence assigned.
   - [ ] You hold **Contributor** on the lab subscription; the shared Azure deployment's owner holds
     **Owner** (or Contributor + User Access Administrator) - see step 5 of the dev container setup.
   - [ ] The tools are signed in to the lab tenant. In the dev container terminal:

     ```bash
     az login --allow-no-subscriptions --use-device-code   # sign in as the lab global admin
     az account show                                       # confirm the lab tenant id
     pac auth create --name halcourt-lab --deviceCode      # Power Platform CLI → lab tenant
     pac org list                                          # "Connected as <admin>"; a new tenant lists only the default env
     ```

   - Device-code sign-in fails with *AADSTS530035*? Step 4 hasn't taken effect yet. Wait, or sign in with a
     browser from your own machine or the Windows VM: drop `--use-device-code` / `--deviceCode` /
     `-UseDeviceCode`.

### Phase 0b — Choose your estate id

Once per build. Several people can build Halcourt Mutual in the same tenant; each build is an **estate**,
and every name it creates carries its estate id. With the id `jsmith`, `Claims-Test` becomes
`Claims-Test-jsmith` and Marcus becomes `marcus.webb.jsmith@<tenant domain>`. What an estate is and what
stays shared: [ADR-0001](../reference/adr/0001-estates.md).

1. Pick an estate id: your alias, 2–12 lowercase letters or digits.
2. Sign in to the tenant as its global admin. If you just finished Phase 0 you already are — skip to 2b to
   confirm it.

   a. In the dev container terminal, run:

      ```bash
      az login --use-device-code --allow-no-subscriptions
      ```

      It prints a web address and a code. Open the address in your browser, enter the code, and sign in
      with the tenant's global admin account.

   b. Confirm you are in the right tenant:

      ```bash
      az account show --query user.name -o tsv
      ```

      It prints the account you signed in as (`you@<something>.onmicrosoft.com`). The part after the `@`
      must be the training tenant's domain, not your company's.

3. Check nobody in the tenant uses your id. This lists every estate's Ana Reyes account; yours must not be
   there:

   ```bash
   az ad user list --filter "startswith(userPrincipalName,'ana.reyes.')" --query "[].userPrincipalName" -o tsv
   ```

4. Set the id in the terminal. Every script reads it; do this again in each new terminal:

   ```bash
   export HALCOURT_ESTATE=jsmith         # your id
   ```

5. **Set the lab accounts' password.** Phase 2 creates your personas with it, later phases sign in as them,
   and Phase 8b gives it to the attendee accounts unless you pass `-UniquePasswords`. The repo is public, so
   the password never goes in a file the repo tracks. Save it in `setup/lab-secrets.local.json` (gitignored):

   ```bash
   read -rsp 'Lab password: ' LABPW; echo                  # typed, not echoed or kept in shell history
   (umask 077; jq -n --arg p "$LABPW" '{labPassword: $p}' > setup/lab-secrets.local.json); unset LABPW
   ```

   - Resuming or tearing down an estate someone already built? Use the password it was built with: the
     scripts sign in as its personas.
   - Or set `HALCOURT_LAB_PASSWORD` in the terminal instead. A script with neither stops and says so.

6. Give attendees the estate id along with the tenant domain.

### Phase 1 — Azure infrastructure (shared)

The agents call two deliberately weak apps in Azure — the Policy API and the Underwriting MCP server. One
deployment serves every estate ([ADR-0005](../reference/adr/0005-shared-azure-deployment.md)), so building
an estate deploys nothing.

1. **Get the endpoints file from the deployment's owner.** It holds the two apps' addresses and secrets,
   which Phase 6 puts into the agents. Save it as `setup/lab-endpoints.local.json` (gitignored — never
   commit it).

   - No owner yet, or you are the owner: deploy it once for the lab —
     [azure-shared-deployment.md](../reference/azure-shared-deployment.md).

2. **Check both apps answer.** The smoke test calls each app with and without its secret. Every line must
   say `ok`:

   ```bash
   F=setup/lab-endpoints.local.json
   bash setup/infra/smoke-test.sh "$(jq -r .POLICY_API_FQDN $F)" "$(jq -r .POLICY_API_KEY $F)" \
     "$(jq -r .UNDERWRITING_MCP_FQDN $F)" "$(jq -r .MCP_BEARER $F)"
   ```

   - Don't run `azd up` for your estate, and don't change the secrets: every estate's agents carry them.

### Before Phase 2 — One estate or several?

- **One estate:** carry on with Phases 2 to 6.5 below, one at a time.
- **Several estates** (one per attendee): skip Phases 2 to 6.5. Run them all with one script —
  [building-many-estates.md](../reference/building-many-estates.md). It also runs Phase 7's admin
  prerequisite and Phases 8b and 8c for each estate (an attendee account without a seat, and its slice).
  Then continue at Phase 6c, and at Phase 8b do only the steps the builder doesn't: the attendees' seats,
  the transcript role (`07c -Estates`) and the printed sign-in cards (`07d`).

### Phase 2 — Entra identities & personas

1. **Create and license the estate's people and groups.** The script creates nine accounts (eight
   personas and `svc-claims`), the `it.helpdesk` shared mailbox and four groups, each named with your
   estate id ([ADR-0006](../reference/adr/0006-personas-on-the-tenant-domain.md),
   [ADR-0007](../reference/adr/0007-shared-mailbox-via-exchange.md)). Then it gives an E5 licence to the
   eight accounts that need one ([ADR-0009](../reference/adr/0009-eight-licences-per-estate.md)). Safe to
   re-run. In the dev container terminal:

   ```bash
   pwsh setup/scripts/01_provision_entra.ps1 -TenantId <tenant domain>
   ```

   - It reuses your `az` sign-in, so there's no code to enter.
   - Its first lines show the estate and domain (`Estate: jsmith   Persona domain: <tenant domain>`).
     Check both.
   - It ends with `Phase 2 complete for estate '<id>'`.

2. **Check the licences.** The `Licences:` lines must show all eight accounts `Assigned` or `Licensed`.
   A `Not licensed:` warning means the tenant ran out of seats: free some (Phase 0, step 3) and re-run.

3. **Leave Tom Dean enabled**, always. Phase 6.5 marks him departed
   ([ADR-0008](../reference/adr/0008-departed-owner-stays-enabled.md)).

### Phase 3 — Environments and DLP

1. **Create the estate's environments and Prod's data policy.** The script creates three environments
   with Dataverse — `Halcourt-Prod-<estate>` (Production, Managed Environment), `Claims-Test-<estate>`
   (Sandbox) and `Maker-Sandbox-<estate>` (Developer, for `dev.kim.<estate>`) — and the DLP policy
   `Halcourt-Prod-DLP-<estate>`, on Prod only. It waits for each Dataverse org (a few minutes), then prints
   a summary. Safe to re-run. In the dev container terminal:

   ```bash
   pwsh setup/scripts/02_provision_environments_dlp.ps1
   ```

   - It reuses your `az` sign-in, so there's no code to enter.
   - The summary lists each environment's **Region**. All three must match; note it for step 2.
   - It ends with `Phase 3 complete`.
   - If the tenant already has a billing plan in the region, Prod and Claims-Test are created on it: a
     Dev Program tenant's Dataverse capacity holds only two estates otherwise
     ([errata → Phase 3](../reference/runbook-errata.md)).
   - The platform picks the region ([ADR-0013](../reference/adr/0013-environment-region-assigned.md)). The other
     environments get no DLP and no agent Conditional Access is created — on purpose
     ([ADR-0028](../reference/adr/0028-planted-governance-gaps.md)).

2. **Link Prod and Claims-Test to a pay-as-you-go billing plan.** Without one, agents publish but nobody
   can chat with them. The script finds the shared plan in your environments' region — creating
   `Halcourt-PAYG-<region>` in `rg-halcourt-billing` if the region has none — then links both environments
   and checks the link. Every estate in the region shares that plan
   ([ADR-0014](../reference/adr/0014-shared-billing-plan-per-region.md)). Safe to re-run.

   ```bash
   pwsh setup/scripts/02b_provision_billing.ps1
   ```

   - Never delete the plan or `rg-halcourt-billing` while any estate uses the region.
   - Creating a new plan is untested (`[verify]`); reusing one is the normal path.
   - By hand instead: [billing-plan-by-hand.md](../reference/billing-plan-by-hand.md). Trouble with the
     region lock: [errata → Phase 3](../reference/runbook-errata.md).

### Phase 4 — SharePoint seed (plant the poisoned doc)

1. **Check the PnP app exists.** SharePoint needs its own app registration, `Halcourt PnP`, shared by every
   estate in the tenant ([ADR-0016](../reference/adr/0016-pnp-app-registration.md)). This prints its app
   id, or nothing:

   ```bash
   az ad app list --display-name "Halcourt PnP" --query "[0].appId" -o tsv
   ```

   - Nothing printed: register it once for the tenant —
     [pnp-app-setup.md](../reference/pnp-app-setup.md) — then continue.

2. **Add your own certificate to the app.** It lets the seed run without a sign-in. Once per facilitator;
   the files stay in the repo's gitignored `setup/` folder. Pick a password and keep it:

   ```bash
   export ENTRAID_APP_ID=$(az ad app list --display-name "Halcourt PnP" --query "[0].appId" -o tsv)
   openssl req -x509 -newkey rsa:2048 -keyout setup/pnp.local.key -out setup/pnp.local.cer -days 90 -nodes -subj "/CN=HalcourtPnP"
   openssl pkcs12 -export -out setup/pnp.local.pfx -inkey setup/pnp.local.key -in setup/pnp.local.cer -passout pass:<cert-pw>
   az ad app credential reset --id $ENTRAID_APP_ID --cert @setup/pnp.local.cer --append -o none
   ```

   - The certificate lasts 90 days; repeat this step when it expires.

3. **Seed the SharePoint sites.** The script creates two private team sites, `HR-Benefits-<estate>` and
   `Claims-Knowledge-<estate>`, uploads their files — including the poisoned `Open-Enrollment-FAQ.docx`
   with its hidden instructions — and sets who can read what, which Scenarios A and B depend on. It ends
   by reading everything back. Safe to re-run. Details:
   [sharepoint-seed.md](../reference/sharepoint-seed.md).

   ```bash
   export HALCOURT_PNP_CERT_PFX=setup/pnp.local.pfx HALCOURT_PNP_CERT_PW=<cert-pw>
   pwsh setup/scripts/03_provision_sharepoint.ps1 -RootSiteUrl https://<tenant>.sharepoint.com
   ```

   - New sites can take up to 15 minutes each to appear in a fresh tenant.
   - In the read-back, `Leadership/ unique permissions` must be `True` and list only the site's Owners and
     Members groups (`HR-Team-<estate>` is a Member) — no `All-Employees-<estate>`. The poisoned file must
     show `payload text present True`.
   - Times out waiting for a site? A soft-deleted site from an earlier run may hold the URL — purge it with
     `Remove-PnPTenantDeletedSite` ([errata → Phase 4](../reference/runbook-errata.md)).
   - No certificate? Unset the two variables and it signs in with a device code instead.

### Phase 4b — Provision and seed the maker OneDrive

1. **Create Dev Kim's OneDrive and put his meeting notes in it.** The Meeting Notes Summarizer decoy
   (Phase 6) grounds on those notes. The script signs in as Dev to make SharePoint create his OneDrive,
   waits for it, then uploads `Dev-Kim-Meeting-Notes.docx` with your PnP certificate. If the OneDrive
   already exists it just uploads. It uses the same variables as Phase 4 step 3:

   ```bash
   export ENTRAID_APP_ID=$(az ad app list --display-name "Halcourt PnP" --query "[0].appId" -o tsv)
   export HALCOURT_PNP_CERT_PFX=setup/pnp.local.pfx HALCOURT_PNP_CERT_PW=<cert-pw>
   pwsh setup/scripts/03b_provision_onedrive.ps1
   ```

   - It ends by printing Dev's OneDrive address
     (`https://<tenant>-my.sharepoint.com/personal/dev_kim_<estate>_…/Documents`).
   - Creating the OneDrive is best effort
     ([ADR-0017](../reference/adr/0017-maker-provisions-own-onedrive.md)). If Dev's first touch hasn't produced
     it after 5 minutes, Dev opens OneDrive in a headless browser (`lib/onedrive_first_run.py`), which is
     usually enough. If it still fails, go to step 2.

2. **Only if step 1 failed: create the OneDrive by hand, then re-run step 1.**
   - First check Dev is **licensed**. SharePoint never creates a OneDrive for an unlicensed user, and says
     so nowhere. `10_build_estates.ps1` reclaims a failed estate's seats, so resume it with `-From entra`.
   - Then sign in as Dev in a private browser window at `https://<tenant>-my.sharepoint.com` (lab password)
     and wait for *Your OneDrive is ready*.
   - Last resort, as the admin. It prints a code to enter, like the other sign-ins, but it was refused twice
     on 2026-10-23
     ([errata → Phase 4b](../reference/runbook-errata.md#phase-4b--a-onedrive-that-never-appears-licence-then-browser-2026-10-23)):

   ```bash
   pwsh -NoProfile -Command "Connect-PnPOnline -Url https://<tenant>-admin.sharepoint.com -DeviceLogin -ClientId $ENTRAID_APP_ID; Request-PnPPersonalSite -UserEmails dev.kim.<estate>@<tenant domain>"
   ```

### Phase 4c — Purview: the label and the labelled comp copy (Task 05-06)

1. **Create the sensitivity label and label a copy of the comp workbook.** Do this **days before the
   delivery**: the label reaches SharePoint late, and search must index the copy before 05-06 can be
   retested. The script creates the group `HR-Leadership-<estate>` (Marcus), the encrypting label
   `Confidential-PII-<estate>` and its policy, then copies `Leadership/2026-comp-bands.xlsx` to
   `2026-comp-bands-labeled.xlsx` and labels the copy; the original stays unlabelled. The first run in a
   tenant also creates the app it signs in as ([ADR-0029](../reference/adr/0029-purview-app-only-identity.md)).
   Safe to re-run.

   ```bash
   pwsh setup/scripts/03c_provision_purview.ps1
   ```

2. **Re-run until the copy is labelled.** It ends with checks; repeat step 1 until they show
   `copy labelled: True` and `original unlabelled: True`. Expect a few re-runs while the
   label replicates ([errata → Phase 4c](../reference/runbook-errata.md#phase-4c--purview-the-label-arrives-late-and-the-token-is-app-only-2026-10-18)).

### Phase 5 — Dataverse seed

1. **Create the claims data and give `svc-claims` too much access to it.** In `Claims-Test-<estate>`, the
   script creates a Customer table (with SSNs and dates of birth) and a Claim table, seeds five rows each,
   and assigns `svc-claims.<estate>` an over-broad role: full access to every row. Scenarios C and D
   exploit that role; Task 05-03 narrows it. It ends by reading everything back. Safe to re-run.
   Details: [dataverse-seed.md](../reference/dataverse-seed.md).

   ```bash
   pwsh setup/scripts/04_provision_dataverse.ps1
   ```

   - It reuses your `az` sign-in and finds `Claims-Test-<estate>` itself.
   - The role assignment must read as done. **PENDING** means `svc-claims.<estate>` has no licence
     ([ADR-0018](../reference/adr/0018-svc-claims-licensed-e5.md)): re-run Phase 2 step 1, which licenses
     it, then re-run this step.

### Phase 5b — Auditing (Lab 05-07)

1. **Turn on the auditing 05-07 reads.** Run it **at least an hour before Exercise 04** — on the build day:
   a log only holds what happened after it was switched on. The script turns on Purview Audit, auditing for
   `Claims-Test-<estate>`, and change auditing for the Claim table
   ([ADR-0030](../reference/adr/0030-audit-claim-changes-only.md)). Safe to re-run.

   ```bash
   pwsh setup/scripts/04b_provision_audit.ps1
   ```

   - It ends with a `Check` line: `unified audit ingestion`, `environment audit` and `mm_claim` must be
     `True`, and `mm_customer` must be `False` — Customer stays unaudited on purpose.
   - Purview Audit can take up to 60 minutes to start recording.

**Defender real-time protection for agents (05-07 KT06) — optional.** KT06 stays reasoned through
([ADR-0031](../reference/adr/0031-no-defender-realtime-protection.md)); these steps only put the control in
place. Run on 2026-10-26 for the `jrc` estate: steps 2–6 done, and step 7 showed 3 of 3. Not run: step 5's
blocking rule, and a tool call through Defender. What the run hit:
[errata → Phase 5b](../reference/runbook-errata.md#phase-5b--defender-real-time-protection-set-up-for-jrc-2026-10-26).

- **Settings.** In the Defender portal, **Settings** is **Setup & configuration → Settings** in the left
  menu. The gear at the top right holds only your own preferences.
- **Licence.** The tenant needs Microsoft Agent 365; without it **Settings → Security for AI** says *"You
  don't have permission to view this page"*. An admin-led trial is 25 seats for 30 days, so time it to
  the delivery. With the trial started 2026-10-24, **Security for AI** opened and its **Agent 365** step
  showed **Done** with nothing to do. Whether attendee accounts need a seat each is open (`[verify]`).
- **Who.** Steps 2–5 and 7 need a Security Administrator: your tenant admin. The facilitator account no
  longer holds that role (07b retires it). Step 6 needs a Power Platform Administrator: the facilitator,
  and also every lab account. **Get started** lists `Lab Student 01 (stu01)` under **Identified Power
  Platform Admins**, so attendees can change or clear step 6.
- **How often.** Steps 2–5 and 7 are **once per tenant** and serve every estate: the app's credential names
  only the tenant and the endpoint, and Defender takes one App ID. Step 6 is **once per estate**: Power
  Platform has no tenant-wide switch, so each `Halcourt-Prod-<estate>` is set up on its own, by hand.
  Defender's **Copilot Studio** step turned **Connected** after the first estate, so it says nothing about
  the others; step 6's save message is the check for each estate.

Learn: *Enable security for AI agents using Microsoft Defender*, *Enable external threat detection and
protection for Copilot Studio custom agents*, *Protect AI agents in real time using Microsoft Defender*.

2. **Turn on Defender XDR and open Defender for Cloud Apps once.** Once per tenant, as a Security
   Administrator. In the Microsoft Defender portal (https://security.microsoft.com):

   - Open any item in the left menu, such as **Incidents** or **Advanced hunting**. That onboards Defender
     XDR. Check: **Settings → Microsoft Defender XDR → Account** shows **Data Retention**, a **Tenant ID**
     and an **Org ID**.
   - Open **Settings → Cloud Apps** once: the Defender XDR integration needs one sign-in to Defender for
     Cloud Apps. Check: **System → About** shows a **Defender for Cloud Apps Tenant ID**, a region and a
     data center. Don't use the **Cloud apps** item in the left menu for this: it opens the apps
     themselves, such as OneDrive.
   - Microsoft doesn't document the *"Hang on! We're preparing new spaces for your data and connecting
     them"* page the 2026-10-20 build saw, or how long it lasts. On 2026-10-26 neither page showed it.

3. **Turn on security for AI agents.** Once per tenant. **Settings → Security for AI → Get started**, and
   leave **Enable** on.

   - **Microsoft 365 connector** step: select **Microsoft Entra ID Management events** and **Microsoft 365
     activities**, then **Connect Microsoft 365**. It shows **Pending connection**, then **Connected**;
     Learn gives no time. The connector's own status is under **Settings → Cloud Apps → Connected apps →
     App Connectors**. Without it blocks still happen, but no alerts reach Defender.
   - **Copilot Studio** step: turn **Real-time protection** on and copy the URL under **Enable Power
     Platform Integration**. That URL is the *endpoint* in steps 4 and 6; on 2026-10-26 it was
     `https://mcsaiagents.security.core.microsoft/v1/protection`. **App ID** is required and **Save** stays
     greyed out until it's filled, so this pane is saved in step 5. Leave it open.

4. **Create the app Copilot Studio signs in to Defender as.** Once per tenant. It has a federated
   credential and no secret. In the dev container, run `pwsh` and paste this, with the endpoint from step 3:

   ```powershell
   $endpoint = '<endpoint URL from step 3>'
   $tenant   = az account show --query tenantId -o tsv
   function B64Url([byte[]]$b) { [Convert]::ToBase64String($b).Replace('+','-').Replace('/','_').TrimEnd('=') }
   $subject  = '/eid1/c/pub/t/{0}/a/m1WPnYRZpEaQKq1Cceg--g/{1}' -f (B64Url ([Guid]::Parse($tenant).ToByteArray())), (B64Url ([Text.Encoding]::UTF8.GetBytes($endpoint)))
   $appId    = az ad app create --display-name 'Defender for Copilot Studio' --sign-in-audience AzureADMyOrg --query appId -o tsv
   az ad sp create --id $appId | Out-Null
   @{ name = 'defender-copilot-studio'; issuer = "https://login.microsoftonline.com/$tenant/v2.0"
      subject = $subject; audiences = @('api://AzureADTokenExchange') } | ConvertTo-Json | Set-Content /tmp/fic.json
   az ad app federated-credential create --id $appId --parameters /tmp/fic.json | Out-Null
   $appId
   ```

   - It prints the App ID, which steps 5 and 6 need. Running it again makes a second app; to find the
     first: `az ad app list --display-name 'Defender for Copilot Studio' --query '[].appId' -o tsv`.
   - Run on 2026-10-26: step 6's save succeeded with this credential, so the subject, issuer and audience
     are right. If a save on another tenant fails with a subject error, **Copy error info** shows the
     subject Copilot Studio expected: fix the credential to match it.

5. **Give Defender the App ID.** Once per tenant. In the **Copilot Studio** pane from step 3, paste the App ID
   into **App ID** and **Save**. The step then shows **Pending Power Platform Action** until step 6. A
   validation error just after a change can mean it hasn't propagated yet: wait a minute and save again.

   - **Optional: a blocking rule.** Per Learn, the built-in **Default** rule only audits; blocking needs a
     custom rule. **Settings → Security for AI → Policies & rules → Real-time protection → Create rule**:
     scope **All**, every detection type. Whether Copilot Studio blocks under the Default rule alone is
     open (`[verify]`): the Learn pages disagree.

6. **Connect `Halcourt-Prod-<estate>` to Defender.** Once per estate, as a Power Platform Administrator.
   Power Platform admin center → **Security → Threat detection → Additional threat detection** → select
   `Halcourt-Prod-<estate>` → **Set up**:

   - Select **Allow Copilot Studio to share data with a threat detection partner**. Ticking it agrees to
     Microsoft's preview terms; the pane says so.
   - **Azure Entra App ID**: the App ID from step 4. **Endpoint link**: the endpoint from step 3.
   - **Set error behavior**: leave it at **Allow the agent to respond**. If Defender doesn't answer within
     a second, the tool call goes ahead.
   - **Save**. It calls Defender, so a wrong app, a wrong credential or a skipped step 5 fails here. A
     working setup shows **Connection is on for environment**.
   - To turn it off later, clear the same checkbox and save.

7. **Check Defender.** Once per tenant. **Settings → Security for AI → Get started** shows **3 of 3
   complete**: **Agent 365** Done, **Microsoft 365 connector** and **Copilot Studio** Connected.

   - Only tool calls are checked, and only on generative-orchestration agents. Benefits Buddy has no
     tools, so its chats never reach Defender. That is KT06's point, but it means Benefits Buddy can't
     show the connection works. Underwriting Assistant's MCP tool is a tool call Defender does see. What
     an allowed call leaves in Defender is open (`[verify]`).
   - **A connected estate's tool calls now go through Defender.** Scenarios C and E use Underwriting
     Assistant's MCP tool in `Halcourt-Prod-<estate>`. The Learn pages disagree on whether the **Default**
     rule only audits or also blocks (step 5). Until that's checked, re-run C and E on a connected estate
     in Phase 8, or clear step 6's checkbox on the estates you deliver on.

### Phase 6 — Author the agents

1. **Check the default environment has Dataverse.** Once per tenant: Expense Helper and Onboarding Guide
   live in `Halcourt (default)` and can't be built without it. This prints its Dataverse address, or nothing:

   ```bash
   az rest --method GET --resource https://service.powerapps.com/ \
     --url "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/Default-$(az account show --query tenantId -o tsv)?api-version=2021-04-01" \
     --query properties.linkedEnvironmentMetadata.instanceUrl -o tsv
   ```

   - Nothing printed: add it (a few minutes), then continue:

     ```bash
     az rest --method POST --resource https://service.powerapps.com/ \
       --url "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/Default-$(az account show --query tenantId -o tsv)/provisionInstance?api-version=2018-01-01" \
       --body '{"baseLanguage":1033,"currency":{"code":"USD"},"templates":[]}'
     ```

2. **Preview the build.** The engine reports what it would do — owners, roles, connections, flows and
   agents — and changes nothing:

   ```bash
   pwsh setup/scripts/06_provision_agents.ps1 -VerifyOnly
   ```

3. **Build the agents.** The engine builds all ten agents as their owners: it turns on `it.helpdesk`'s
   sign-in, adds each owner to its environment with a maker role, creates and consents each connection
   (headless, as its owner), creates the flows, then pushes and publishes each committed agent. Safe to
   re-run. What it builds: [agents-build.md](../reference/agents-build.md).

   ```bash
   pwsh setup/scripts/06_provision_agents.ps1
   ```

   - It needs Phases 2–5 done, Prod and Claims-Test linked to a billing plan (Phase 3), and Dev's OneDrive
     seeded (Phase 4b).
   - Rebuild one agent: `-Agents <slug>` (slugs in `setup/agents/manifest.json`).
   - A transient *instanceNotFound* while adding a user: run it again.

### Phase 6.5 — Mark Tom Dean departed

1. **Record Tom's departure without disabling him.** After Onboarding Guide and Sales Nudge exist and run on
   his connections, this sets his Entra leave date and leaves the account enabled
   ([ADR-0008](../reference/adr/0008-departed-owner-stays-enabled.md)):

   ```bash
   pwsh setup/scripts/01_provision_entra.ps1 -MarkDepartedOwner
   ```

   - It ends with `tom.dean.<estate>@… marked departed`. Safe to re-run: it sets the same date again.
   - **Never disable Tom**: both connections go to Error within the hour and Scenario F stops reproducing.

### Phase 6c — Recheck the Purview label

1. **Re-run Phase 4c until it finishes.** Its first run usually stops short: the new label hasn't reached
   SharePoint, so the copy isn't labelled. Phases 4b–6.5 give it time. Re-running creates nothing new; it
   labels the copy once the label is there.

   ```bash
   pwsh setup/scripts/03c_provision_purview.ps1
   ```

   - No `6. Checks` section in the output means it stopped at step 5: not yet.
   - Done when the `6. Checks` lines show `copy labelled: True`, `original unlabelled: True` and `search sees
     the marker: True`.
   - Not yet? Run it again later. The label can take hours to reach SharePoint — up to a day
     ([errata → Phase 4c](../reference/runbook-errata.md#phase-4c--purview-the-label-arrives-late-and-the-token-is-app-only-2026-10-18)).
   - Still `copy labelled: False` with no `labelNotFound`, a day on? Some sites never apply a label. Label it
     through another estate's site whose copy *is* labelled:
     `pwsh setup/scripts/03c_provision_purview.ps1 -LabelVia <that estate>`. If that site doesn't apply it
     either, the script stops without changing the copy; try a different estate
     ([errata → Phase 4c, some sites never apply it](../reference/runbook-errata.md#phase-4c--some-hr-benefits-sites-never-apply-the-label-2026-10-23)).
   - It must pass before the delivery: Task 05-06 retests against the labelled copy.

### Phase 7 — Export the artifact pack

1. **Give yourself a role in `Maker-Sandbox-<estate>`.** The export reads every environment's agents, and
   the admin has no Dataverse role in this one: it's a Developer environment, and Dev Kim is its only System
   Administrator — so the admin can't grant itself one, and Dev has to. These sign `pac` in as Dev, in a
   profile store of its own so your admin profile is untouched, and give your admin account System
   Administrator there. Once per estate:

   ```bash
   export XDG_DATA_HOME=/tmp/pac-devkim
   ~/.dotnet/tools/pac auth create --name devkim --username dev.kim.$HALCOURT_ESTATE@<tenant domain> --password '<lab password>' --environment <Maker-Sandbox org URL>
   ~/.dotnet/tools/pac admin assign-user --environment <Maker-Sandbox environment id> --user <your admin UPN> --role "System Administrator"
   rm -rf /tmp/pac-devkim; unset XDG_DATA_HOME
   ```

   - The environment id and org URL are in the Phase 3 summary.
   - It ends with `Successfully assigned security role 'System Administrator'`.
   - The estate builder does the same step for you (`10_build_estates.ps1`, phase `devadmin`).

2. **Export the estate over the committed pack.** The script reads this estate's environments, agents,
   connections and accounts, plus the knowledge sites' files and labels (Phase 4c's app), converts the live
   names back to the canonical ones, and writes the six CSVs in `worksheets/artifact-pack/`
   ([ADR-0022](../reference/adr/0022-artifact-export-over-rest.md)). Safe to re-run.

   ```bash
   pwsh setup/scripts/05_export_artifact_pack.ps1 -Canonicalize
   ```

3. **Review the drift, then keep or discard it.** The diff is what changed between the committed pack and
   your estate. It is never empty: descriptions, friendly connector names and some rows are hand-written
   ([ADR-0023](../reference/adr/0023-committed-pack-not-pure-export.md)).

   ```bash
   git diff worksheets/artifact-pack
   ```

   - Commit only real changes to the estate. Discard the rest with
     `git checkout -- worksheets/artifact-pack`.
   - Exporting somewhere else instead: `-OutDir <folder>`, without `-Canonicalize`, keeps the live names.

### Phase 8 — Validate

Check the estate matches `AGENTS.md`. Most of it is reading what Phases 6.5–7 already reported; the
scenarios themselves need someone to talk to the agents.

1. **Check the estate's shape against the export.** Phase 7's diff already shows whether every agent is
   present with the right owner and environment, each has one Entra identity, DLP is on Prod only, and the
   accounts are as Phase 2 left them. Look for *unexpected* drift — an agent missing, an owner changed, an
   environment that lost its DLP — not an empty diff.

2. **Check Tom is departed but still enabled.** Phase 6.5 must have run, and both of his connections must
   still work; otherwise the departed-owner scenario reads wrong:

   ```bash
   az rest --url "https://graph.microsoft.com/v1.0/users/tom.dean.$HALCOURT_ESTATE@<tenant domain>?\$select=accountEnabled,employeeLeaveDateTime"
   ```

   - It must show `accountEnabled: true` and a leave date.
   - Onboarding Guide and Sales Nudge must answer in step 3.

3. **Reproduce the planted scenarios.** Walk `AGENTS.md`'s planted problems (Scenarios A–F) and confirm
   each one fires, and that each discovery target can be found. The Teams chat probe holds a scripted
   conversation with one agent, as a persona, the way attendees do in Exercise 04:

   ```bash
   python3 setup/scripts/lib/teams_chat_probe.py --upn lena.ford.$HALCOURT_ESTATE@<tenant domain> --password '<lab password>' \
     --agent "Policy Lookup Bot" --links setup/teams-links-$HALCOURT_ESTATE.local.csv --out /tmp/probe \
     --say "look up a policy" --expect "policy id" --say "POL-1001" --expect "Policy POL-1001"
   ```

   - It ends with `RESULT=PASS`, or `RESULT=FAIL <reason>` and screenshots in `--out`.
   - Sign in as a licensed persona in the agent's chat audience, not an admin.

4. **Check the control verdicts.** Every control-efficacy verdict in `AGENTS.md` must still hold. Resolve
   any `[verify]` item you can and update `AGENTS.md`.

5. **Check the agent registry (Task 05-05).** As the facilitator, with AI Administrator activated:
   **Microsoft 365 admin center** → **Agents** → **All agents** → **Registry** must list all ten estate
   agents: Expense Helper and Onboarding Guide carry the estate id, and the rest have plain names, one
   entry per estate in the tenant. An estate-id search shows "Showing 2 of 2". **Block** must be available
   on Onboarding Guide. If you try Block, unblock straight away.

   - Whether the tenant's Agent 365 licensing lasts until the delivery is open:
     [PLANNING item 8](../PLANNING.md).

The attendee's view — a student account's slice, Teams links and the confused-deputy path — is checked at
the end of Phase 8c, because it needs Phases 8b and 8c.

### Phase 8b — Lab (attendee) accounts

Per delivery, not per estate: attendees sign in with native lab accounts you hand out, so they review the
estate from inside the tenant. What the accounts get and why: [attendee-accounts.md](../reference/attendee-accounts.md).

1. **Count your free E5 seats.** That number is the most attendees you can run: Teams, the audit events and
   the access model all need a licence ([ADR-0004](../reference/adr/0004-one-licence-per-attendee.md)). This
   prints the free count:

   ```bash
   az rest --url https://graph.microsoft.com/v1.0/subscribedSkus --query "value[?skuPartNumber=='DEVELOPERPACK_V2_E5'] | [0].[prepaidUnits.enabled, consumedUnits]" -o tsv
   ```

   - Free = the first number minus the second. Short? Reclaim seats from built estates
     ([building-many-estates.md](../reference/building-many-estates.md)).

2. **Create the attendee accounts, the day before the delivery.** The script creates `student01.<estate>`…
   with their admin roles, Dataverse read access in each estate environment, a seat each where one is free,
   and membership of `All-Employees-<estate>` (so the Teams links work). It prints a handout and writes it,
   passwords included, to `setup/lab-users-<estate>.local.csv` (gitignored). Safe to re-run: existing
   accounts are kept, with their passwords carried forward from the handout.

   ```bash
   pwsh setup/scripts/07_provision_lab_users.ps1 -Count <N>          # add -UniquePasswords for a distinct password each
   ```

   - The day before, not the morning of: Conditional Access and Dataverse's licence state both lag by hours.
   - The end-of-run table shows who got a seat. An attendee without one takes the artifact-pack route for
     the Copilot Studio and role-editor steps.

3. **Grant the attendees Purview's transcript role.** Task 05-07 opens a chat's transcript in DSPM for AI,
   which Global Reader alone can't. It asks for one device-code approval as the admin:

   ```bash
   pwsh setup/scripts/07c_provision_purview_roles.ps1
   ```

   - An estate per attendee? Pass them all, so one approval covers them:
     `07c_provision_purview_roles.ps1 -Estates fac01,stu01,stu02`.

4. **Tell attendees to bring an authenticator app.** Their accounts hold admin roles, so Entra makes each one
   register MFA at first sign-in — about two minutes, once. Don't try to avoid it with a Conditional Access
   exclusion: the admin portals and APIs enforce MFA anyway
   ([attendee-accounts.md](../reference/attendee-accounts.md)).

5. **Print the sign-in cards.** One card per attendee account, two to a Letter page with a cut line:
   the workshop guide's address, estate id, username, password, tenant domain, their lab environment
   (`Lab-<estate>-NN`, Phase 8c) and the first sign-in steps. It reads every handout CSV from step 2, so run
   it after the last 07 run:

   ```bash
   pwsh setup/scripts/07d_attendee_handouts.ps1        # or -Estates stu01,stu02 for just those
   ```

   - It writes `setup/attendee-handouts.local.pdf` (and the `.html` it prints from). Both hold the passwords
     in plain text: gitignored, so print them, never share or publish them, and delete them in Phase 9.

An attendee account is a tenant-wide Power Platform admin: delete the accounts right after the delivery
(Phase 9).

### Phase 8c — Per-student slices (needed from Exercise 03)

Each attendee gets a small environment of their own, where they are System Administrator, to open the
`svc-claims` role in Tasks 03-01 and 03-02. Why, and what a slice holds:
[student-slices.md](../reference/student-slices.md).

1. **Build a slice for each attendee account, before the delivery.** The script creates `Lab-<estate>-NN`
   for `studentNN` — a Sandbox environment with Dataverse, on the estate's billing plan, seeded like
   Claims-Test (the claims data and the over-broad `svc-claims` role) — and makes `studentNN` its System
   Administrator. Use the same number as Phase 8b: the handout's `studentNN` must match its slice. Safe to
   re-run.

   ```bash
   pwsh setup/scripts/08_provision_student_slices.ps1 -Count <N>
   ```

   - A new slice's Dataverse is usually ready in about 30 seconds. An early *"Interactive authentication is
     needed"* clears on its own; the script retries.

2. **Check the attendee's view.** This is Phase 8's last check; it needs 8b and 8c. In a browser, sign in as
   one student account (password in `setup/lab-users-<estate>.local.csv`). The first sign-in makes you
   register MFA — have an authenticator app ready. Then confirm:

   - [ ] the Power Platform admin center lists their slice, `Lab-<estate>-NN`;
   - [ ] each Teams install link from `setup/teams-links-<estate>.local.csv` opens the agent;
   - [ ] Claims Copilot gives them claim CLM-9002, although their own Claims-Test roles grant no claim
         access — the confused-deputy path, with the attendee as the requester.

### Before delivery — preflight, audit and Exercise 04 notes

Run these the day before. They check what the build phases set up, as the attendees will see it. What each
check protects: [before-delivery-checks.md](../reference/before-delivery-checks.md).

1. **Run the preflight.** It checks the tenant capabilities
   ([tenant-capabilities.md](../reference/tenant-capabilities.md)), the estate and the attendee access
   model, and names the exercise step each failed check would break. In the dev container terminal, signed
   in and with your estate id set (Phase 0b steps 2 and 4), with the number of attendees you'll run:

   ```bash
   pwsh setup/scripts/00b_preflight.ps1 -Attendees <N>
   ```

   - Fix every FAIL. A WARN names the fallback attendees will use.

2. **Chat with each Teams agent once**, as a licensed persona with no admin role, the way attendees will.
   The preflight proves the agents exist; this proves they answer. Run the probe once per row of
   `setup/teams-links-<estate>.local.csv`, with a question that agent answers. For Policy Lookup Bot:

   ```bash
   python3 setup/scripts/lib/teams_chat_probe.py --upn lena.ford.$HALCOURT_ESTATE@<tenant domain> --password '<lab password>' \
     --agent "Policy Lookup Bot" --links setup/teams-links-$HALCOURT_ESTATE.local.csv --out /tmp/probe \
     --say "look up a policy" --expect "policy id" --say "POL-1001" --expect "Policy POL-1001"
   ```

   - It ends with `RESULT=PASS`; screenshots land in `--out`.
   - Personas' seats reclaimed after the build? Lend Jordan Blake a seat and chat as Jordan.

3. **Check, as an attendee, that the Exercise 04 chats reach the audit log.** In a private browser window,
   signed in as a student account, after a rehearsal chat. These are the routes Task 05-07 sends attendees
   down:

   - [ ] **Purview Audit.** Open the **Microsoft Purview portal**, https://purview.microsoft.com →
         **Solutions** → **Audit**. There must be no "start recording" banner. Search with **Record Types**
         = `CopilotInteraction` and **Users** = the student account, over today (the date picker stops at
         today: set the end time late; times are UTC). The rehearsal chat must be listed — a search takes
         4–7 minutes, then **Refresh**; ingestion can take up to an hour to start after Phase 5b.
         *Total Result Count* can read 0 above a list of results; the list is what counts. Without the
         **Users** filter the search shows every estate's chats.
   - [ ] **DSPM for AI.** In the same portal, **Solutions** → **DSPM for AI (classic)** → **Activity
         explorer** (select **Maybe later** if a *New Unified Data Security Posture Management* window opens).
         With **User participant** = the student account, the rehearsal chat's **AI Interaction** record
         (agent, user, time, app) must show. The prompt and response text usually doesn't, and an
         "Additional permissions required" banner about AI visits is expected — tell the room the text is
         optional.
   - [ ] **The Claims-Test audit summary.** Open `<Claims-Test org URL>/tools/audit/audit_summary.aspx`
         (the org URL is in the Phase 3 summary, or **Power Platform admin center**,
         https://admin.powerplatform.microsoft.com → **Manage → Environments** → `Claims-Test-<estate>` →
         **Environment URL**). It must list audit records — at least Phase 5b's *Audit Change* entries — and
         the student can't open a claim itself, which is expected. Don't use the admin center's **Settings →
         Audit and logs → Audit summary view** link: it fails for attendees with *Error loading control*.
         The page's **Delete Change History** button shows for everyone but is refused: the lab role holds
         no delete privilege.

4. **Brief yourself on what the room can't do.** Each is expected, not a fault:

   - 04-04's write half is reasoned, not run: Claims Copilot has no update tool, so there's no test claim.
   - Claims Copilot's reads appear in no log: Dataverse never audits reads, and `Claims-Test` is a sandbox.
     05-07 KT03 teaches that gap.
   - 05-07 KT06 reasons Defender real-time protection through, even where Phase 5b has connected it.

5. **Create the facilitator account and sign in with it once.** You demonstrate Exercise 05 as this account
   (`facilitator.<estate>`, "Lab Facilitator (<estate>)"), not your own tenant admin: it holds Power
   Platform Administrator, and AI Administrator only as PIM-eligible. The script writes its password to
   `setup/lab-facilitator-<estate>.local.csv` (gitignored). Safe to re-run.

   ```bash
   pwsh setup/scripts/07b_provision_facilitator.ps1
   ```

   - Sign in with it once in a browser to enrol MFA: it is an admin, so `CA-Require-MFA-Admins` applies.

### During delivery — Exercise 05 demonstrations

Each attendee retests on their own estate, which shows the *before*. You apply each control on the
presenting estate and show the *after* on screen, then put the estate back. Do it as the facilitator account
(Before delivery, step 5), not your own tenant admin, unless a step says otherwise.

**Pacing (90 minutes).** Open with 05-01: it's the one control that visibly blocks an attack live. 05-02 and
05-04 change nothing an agent uses (05-04 isn't applied at all), so explain them in a couple of minutes each
instead of demonstrating. Pre-stage 05-03 (step 0): made live, its changes don't show within the session.

0. **Hours before Exercise 05 (the morning of), pre-stage 05-03 on the presenting estate.** Made live,
   Benefits Buddy keeps answering from its index for over an hour ([errata](../reference/runbook-errata.md#exercise-05-03--narrowing-benefits-buddys-grounding-did-not-stop-the-leak-within-an-hour-2026-10-20)),
   so make the changes early and show the result. As the tenant admin:
   1. **Snapshot first**, once, before any change (step 1's command with `-Estate <estate>`). Don't
      snapshot again later: a snapshot taken after these changes makes the restore put them back.
   2. **Scenario C:** `pwsh setup/scripts/09b_ex05_scoped_claims_role.ps1 -Estate <estate>`.
   3. **Scenario C's second path, older estates only:** builds no longer upload `claims.csv` into
      `Claims-Knowledge` (#98). If your estate was built before that fix, re-run
      `03_provision_sharepoint.ps1 -Estate <estate>` (it removes the file), or send `claims.csv` to the
      recycle bin in `Claims-Knowledge-<estate>` → Shared Documents. Leave it removed afterwards.
   4. **Scenario B:** 05-03 step 1 (`Leadership/` → **HR Benefits Members** → **No direct access**).
   5. **Check the *after*** in Copilot Studio's **Test** pane, as an admin of that environment.
      - **Claims Copilot:** its tool runs on `svc-claims`'s connection whoever tests, so the pane matches
        Teams. Rehearsed on `fac01` (2026-10-26): about 2 minutes after the role, "CLM-9003 is not listed
        among the current claims", with only CLM-9001 and CLM-9002 visible.
      - **Benefits Buddy:** grounding may read with the tester's own access, and the site's Owners keep
        `Leadership/`, so an owner's test pane can't prove the *after*. Check in Teams with a licensed
        account that isn't a site owner or member.

   In 05-03, the room retests its own estates (the *before*: CLM-9003 comes back "Approved") and you show
   yours (the *after*). Put it back after the session with 05-03's step 4.

1. **Before Exercise 05 starts, snapshot the estate**, unless you pre-staged (step 0 took it). The script
   records the data policies, the default environment's makers and `svc-claims`'s roles, so each
   demonstration can be undone exactly:

   ```bash
   pwsh setup/scripts/09_ex05_demo_state.ps1 -Action Snapshot -Control All
   ```

2. **For each task, demonstrate the control, let the room retest, then put it back** — as soon as the
   retests are done. Sign in as the facilitator account unless a task says otherwise. The click paths come
   from each task's page; those marked *(not yet walked)* haven't been run as the facilitator.

   **05-01 — Block HTTP and custom connectors in Prod** (attendees follow KT02; retests in KT03 and KT05)

   1. **Power Platform admin center** → **Security** → **Data and privacy** → **Data policy** →
      `Halcourt-Prod-DLP-<estate>` → **Edit Policy**.
   2. On **Prebuilt connectors**, search `http` and move all five matches to **Blocked** (HTTP, HTTP with
      Microsoft Entra ID, HTTP with Microsoft Entra ID (preauthorized), When a HTTP request is received,
      HTTP Webhook). On **Custom connectors**, set the `*` pattern to **Blocked**. Leave **Dataverse** and
      **SharePoint** in **Business**. **Next** through to **Review** and save.
   3. **Show the room** the Blocked group, then run KT03 (Policy Lookup Bot) and KT05 (Claims Copilot) on
      screen in this estate. Expect Policy Lookup Bot's HTTP call to fail (`DataLossPreventionViolation`),
      and maybe agents that won't publish (the page's warning). Underwriting Assistant isn't retested.
   4. **Leave it in place** for 05-02; the put-back is 05-02's step 5.

   **05-02 — Add the default environment to the policy** (KT02; retests in KT05)

   1. Open `Halcourt-Prod-DLP-<estate>` → **Edit Policy** → **Next** to **Environments**.
   2. On **Available**, search `default`, tick `Halcourt (default)`, **+ Add to policy**. **Next** and save on
      **Review**. The default environment now carries 05-01's blocks.
   3. **Show the room** the policy, and that you can't fence the default environment's makers: every
      licensed user is an Environment Maker there.
   4. Wait for KT05.
   5. **Put it back:** remove `Halcourt (default)` from the policy the same way, then
      `pwsh setup/scripts/09_ex05_demo_state.ps1 -Action Restore -Control Dlp` to restore 05-01's baseline.

   **05-03 — Scope Benefits Buddy's reach, and svc-claims's role** (KT01, KT02; retests in KT03, KT04)

   1. **Scenario B, as the site owner** — the account Phase 4 made owner of `HR-Benefits-<estate>`
      (`-SiteOwner`; by default the admin who ran it). Members, Marcus included, have Edit, which can't
      change permissions. Don't narrow the Knowledge instead: that did not stop the leak within an hour
      ([errata](../reference/runbook-errata.md#exercise-05-03--narrowing-benefits-buddys-grounding-did-not-stop-the-leak-within-an-hour-2026-10-20)).
      1. Open `HR-Benefits-<estate>` → **Documents**, tick `Leadership`, select **Details** → **Manage access**.
      2. Open **HR Benefits Members** (the `HR-Benefits-<estate>` Members group), choose **No direct access**, select **Apply**.
      3. Check **Details** → **Has access**: nobody listed, and "This item is not shared".
      4. After the retests, grant **HR Benefits Members** **Can edit** on the folder again.
   2. **Scenarios C and D:** snapshot, then the scoped `svc-claims` role and its fixed data subset, by script:

      ```bash
      pwsh setup/scripts/09_ex05_demo_state.ps1 -Action Snapshot -Control ClaimsRoles -Estate <estate>
      pwsh setup/scripts/09b_ex05_scoped_claims_role.ps1 -Estate <estate>
      ```

   3. **Show the room** the new role in **Claims-Test-<estate>**'s security roles, and the permission change.
      Wait for KT03 and KT04.
   4. **Put it back:** restore `Leadership/` by granting **HR Benefits Members** **Can edit** again (step 1.4),
      then `pwsh setup/scripts/09_ex05_demo_state.ps1 -Action Restore -Control ClaimsRoles -Estate <estate>`
      (the role, Basic User and record owners).

   {: .note }
   > **Estates built before the #98 fix.** Those builds uploaded `claims.csv` into `Claims-Knowledge`, a
   > second, indexed path to the claim data that the Dataverse role doesn't touch, so Claims Copilot can still
   > return CLM-9003 after the scoped role. Step 0.3 removes the file. If it still answers from the index,
   > present that as the finding it is — least privilege on one path doesn't help when the same data has
   > another — not as the scoped role failing.

   **05-04 — Nothing to change.** The Conditional Access policy is specified, never created: one wrong
   policy locks out the tenant.

   **05-05 — Block Onboarding Guide** (KT05)

   1. Activate the facilitator's **AI Administrator** in PIM.
   2. **Microsoft 365 admin center** → **Agents** → **All agents** → **Registry**, search for the estate id,
      select **Onboarding Guide** → **Block** → confirm. The status reads **Blocked**, with the banner
      "Agent blocked". Never **Delete**: it can't be undone.
   3. Wait for KT05 (attendees read Onboarding Guide's **Status**; lab accounts can't Block).
      - **Show the contrast while they read** (nothing changes). The registry's **Agents without owners**
        reads 0, though Onboarding Guide's owner left in January: his account still exists. Then open the
        **Security Dashboard for AI** (`ai.security.microsoft.com`), signed in with a lab account. It needs
        Security Reader, and a tenant admin without it sees blank cards. **AI risk** reads 0 exfiltration
        and 0 oversharing minutes after the room exfiltrated the comp table, and its checklist shows 4 of 10
        recommended controls on: DLP and Insider Risk aren't. Visibility depends on what's configured; it
        isn't validation.
   4. **Put it back:** select Onboarding Guide again → **Unblock** → confirm. Let AI Administrator lapse.

   **05-06 — Show the labelled copy** (KT01 step 3; nothing changes)

   1. As Marcus Webb (an HR-leadership member), open `HR-Benefits-<estate>` → **Documents** →
      `Leadership/`, select each comp file → **Details**.
   2. **Show the room:** `2026-comp-bands-labeled.xlsx` shows **Sensitivity** `Confidential-PII-<estate>`,
      `2026-comp-bands.xlsx` none. The library view has no Sensitivity column.

   **05-07 — Show Audit × D on Expense Helper** (reveal; nothing changes). Real-time protection stays
   reasoned through (KT06).

   1. Sign in as a **System Administrator of Halcourt (default)**, such as the tenant admin who built the
      estates, not the facilitator account: it holds only Environment Maker and Basic User there, so it can't
      open another user's flow. Attendees can't open it either (#73), so this is shown, not done.
   2. In Power Automate (`make.powerautomate.com`), switch to **Halcourt (default)** → **Solutions** →
      **Default Solution**, listed below the per-agent solutions; or go straight to
      `make.powerautomate.com/environments/<environment id>/solutions/fd140aaf-4df4-11dd-bd17-0019b9312238`,
      the Default Solution's id in every environment. In its **Objects** pane
      select **Cloud flows**. Every estate has a flow named **Submit and auto-approve expense under $500**
      (24 of them); the **Owner** column tells them apart, e.g. `# Sam Olsen (<estate>)`. Open the copy
      owned by **Sam Olsen (the attendee's estate** whose chat you'll match in step 4), not your own, or
      there's no run at that attendee's time. **Select the row** and choose **Details** in the toolbar.
      Don't select the flow's name: that opens it in the editor.
   3. **Details** shows **28-day run history**; a run can take a few minutes to appear. Select the run at
      the time of one attendee's Exercise 04 Expense Helper chat, then **When Copilot Studio calls a flow** →
      **Show raw outputs**. The body is only the amount; the headers name the agent and channel
      (`BotSchemaName:cr458_ExpenseHelper<estate>`, `ChannelId:msteams`) but no user. Don't select
      **Resubmit** or **Edit**, and sign out (or close the private window) when done - this is the tenant
      admin on the shared screen.
   4. **Show the room** that run next to the same attendee's `CopilotInteraction` event: in their KT01
      search, the row whose **AgentName** is Expense Helper. The run says which agent called it and when, not
      who asked. Matching the two by agent and time is **cross-log only** - or **partial** if more than one
      run sits near that time (the attendee submitted twice, or you tested), since the time match then
      doesn't single one out. The flow writes nothing, so the run is not evidence a privileged approval ran.
      If the event hasn't arrived yet (it can take hours), show the run and say the match has to wait for it.
   5. Say what it isn't: the flow's one action replies to the agent and calls no connector, so the run writes
      nothing. "Auto-approved" (under $500) is only the reply.
   6. Don't use Sales Nudge for this. Attendees aren't in its audience (`Halcourt-Makers`), it has no Teams
      channel, and Halcourt-Prod read logging is off by design (04b), so its reads reach no log.

3. **At the end, check everything is back.** Every line must say "same as the snapshot":

   ```bash
   pwsh setup/scripts/09_ex05_demo_state.ps1 -Action Diff -Control All
   ```

### Phase 9 — Teardown

After the delivery, remove this estate's attendee and facilitator accounts, its slices, its Purview
objects, then the estate itself. Run the steps in this order: some need things a later step deletes. Each
removes only this estate; nothing another estate uses is touched. To reseed instead, re-run Phases 2–6.

1. **Take back the attendees' Purview role.** Before step 2, while the accounts still exist: the script
   matches role-group members by display name. It needs one admin device-code approval.

   ```bash
   pwsh setup/scripts/07c_provision_purview_roles.ps1 -Remove
   ```

   - Tearing down several estates? One approval covers them all:
     `07c_provision_purview_roles.ps1 -Estates fac01,stu01,stu02 -Remove`.

2. **Delete the attendee accounts and their handout.** The script deletes and purges the accounts
   ([ADR-0026](../reference/adr/0026-attendee-teardown-purges.md)).

   ```bash
   pwsh setup/scripts/07_provision_lab_users.ps1 -Destroy
   rm setup/lab-users-$HALCOURT_ESTATE.local.csv
   rm -f setup/attendee-handouts.local.pdf setup/attendee-handouts.local.html   # the printed cards (8b step 5)
   ```

3. **Delete the facilitator account.** It also deletes its password file.

   ```bash
   pwsh setup/scripts/07b_provision_facilitator.ps1 -Destroy
   ```

4. **Delete the per-student slices.** Before step 6: the script finds the billing plan to unlink through
   the estate's Prod environment.

   ```bash
   pwsh setup/scripts/08_provision_student_slices.ps1 -Destroy
   ```

5. **Delete the Purview label and policy.** It removes `Halcourt-Labels-<estate>`, then
   `Confidential-PII-<estate>`, retrying while the policy is withdrawn; re-run it if it times out.

   ```bash
   pwsh setup/scripts/03c_provision_purview.ps1 -Remove
   ```

6. **Tear down the estate.** In dependency order: the default environment's agents and the auto-approve
   flow (as their owners), the SharePoint sites (purged, so the URLs can be reused), the three estate
   environments with everything in them, the Prod data policy, and the billing link. It only unlinks the
   billing plan; it never deletes it. `-RemovePersonas` also deletes the Phase 2 personas and every
   `*-<estate>` group.

   ```bash
   export ENTRAID_APP_ID=$(az ad app list --display-name "Halcourt PnP" --query "[0].appId" -o tsv)
   export HALCOURT_PNP_CERT_PFX=setup/pnp.local.pfx HALCOURT_PNP_CERT_PW=<cert-pw>
   pwsh setup/scripts/99_teardown.ps1 -RemovePersonas
   ```

   - Environments delete in the background, over a few minutes.
   - It keeps Phase 0 (the tenant and the Conditional Access baseline), the default environment, the
     shared Azure deployment and the other shared pieces.

7. **Delete the estate's local files.**

   ```bash
   rm -rf setup/ex05-state/$HALCOURT_ESTATE setup/teams-links-$HALCOURT_ESTATE.local.csv
   ```

Last estate in the tenant? The shared pieces — the Azure deployment, the billing plan, the lab apps and the
tenant-wide grants — are retired separately: [retiring-shared-resources.md](../reference/retiring-shared-resources.md).

## File index (this kit)

| Path | Purpose |
|---|---|
| `infra/` (root azd project) | Deploys web + Foundry + Policy API + Underwriting MCP Container Apps via `azd up` |
| `setup/infra/policy-api/` | Minimal, intentionally over-scoped Policy API (static key) |
| `setup/infra/mcp-underwriting/` | Minimal Underwriting MCP server (static bearer, `run_query`) |
| `setup/infra/smoke-test.sh` | Phase 1 check: both endpoints reject a bad credential and serve the scenario behaviour with the right one |
| `windows-vm/` | Optional Windows 11 build VM in Docker, for a desktop browser for interactive sign-in and MFA |
| `screenshot-capture-list.md` | Screenshots the lab pages reference, to capture from the demo tenant |
| `scripts/00_conditional_access_baseline.ps1` | Security defaults off → `CA-Require-MFA-Admins` + `CA-Block-Legacy-Auth` |
| `scripts/00b_preflight.ps1` | The day before a delivery: tenant capabilities, seats, endpoints, the estate and the access model |
| `scripts/_estate.ps1` | Estate naming rule, dot-sourced by the scripts |
| `scripts/_access_model.ps1` | The attendee access model: directory roles, groups, every Dataverse privilege and the step it serves |
| `scripts/_auth.ps1` | Graph sign-in reuse: the az token when it covers the scopes, else device code |
| `scripts/_labapp.ps1` | The kit's app-only identity (`halcourt-lab-compliance`), for 03c and 07 |
| `scripts/01_provision_entra.ps1` | Personas, groups, `svc-claims`, shared mailbox |
| `scripts/02_provision_environments_dlp.ps1` | Environments, Managed Prod, prod DLP |
| `scripts/02b_provision_billing.ps1` | Copilot Studio PAYG billing plan; links Prod + Claims-Test |
| `scripts/03_provision_sharepoint.ps1` | Sites + clean FAQ library + **plant poisoned doc** |
| `scripts/03b_provision_onedrive.ps1` | Provision + seed dev.kim's OneDrive (Meeting Notes grounding) |
| `scripts/04_provision_dataverse.ps1` | Claim/Customer tables, PII rows, over-broad role |
| `scripts/04b_provision_audit.ps1` | Phase 5b: Purview Audit and Claims-Test auditing for 05-07 |
| `scripts/05_export_artifact_pack.ps1` | Regenerate the artifact-pack CSVs |
| `scripts/06_provision_agents.ps1` | Provision the agents from committed workspaces, as each owner |
| `scripts/lib/consent_browser.py` | Headless connection-consent helper (browser step in Phase 6) |
| `scripts/lib/enable_teams_channel.py` | Adds the Teams channel to an agent as its owner (browser step in Phase 6) |
| `scripts/lib/teams_chat_probe.py` | Chats with a published agent in Teams as a persona; checks it answers before a delivery |
| `scripts/03c_provision_purview.ps1` | Phase 4c: the encrypting label and the labelled comp copy |
| `scripts/07_provision_lab_users.ps1` | Phase 8b: attendee accounts and the access model (`_access_model.ps1`) |
| `scripts/07b_provision_facilitator.ps1` | The facilitator's Exercise 05 demonstration account |
| `scripts/07c_provision_purview_roles.ps1` | Phase 8b: attendees into Purview's Data Security AI Content Viewers (05-07 KT04); one admin device-code approval |
| `scripts/07d_attendee_handouts.ps1` | Phase 8b: printable sign-in cards from the handout CSVs (`lib/print_pdf.py` renders the PDF) |
| `scripts/08_provision_student_slices.ps1` | Phase 8c: an environment per attendee, with the Claims Dataverse seed |
| `scripts/09b_ex05_scoped_claims_role.ps1` | Exercise 05-03 demonstration: svc-claims' scoped role and fixed subset |
| `scripts/09_ex05_demo_state.ps1` | Exercise 05 demonstrations: snapshot / diff / restore the shared estate |
| `scripts/99_teardown.ps1` | Remove the estate |
| `agents/manifest.json` | Phase 6 control data: agents, connections and flows (estate-agnostic) |
| `agents/<slug>/` | Committed `pac copilot` agent workspaces the engine replays |
| `agent-authoring-guide.md` | Manual Copilot Studio authoring, per agent (portal / `pac`) |
| `data/` | Seed data: poisoned-doc source, clean decoy FAQ, Dev's meeting notes, Expense Helper flow |

{: .warning }
> Several script steps depend on 2026 product surfaces still settling (Conditional Access for agents, `pac`
> agent commands). Lines marked `# [verify]` need confirmation against the delivery-date tenant; treat
> them as the intended operation, not a guaranteed cmdlet.

## More detail

| File | Holds |
|---|---|
| [`../reference/adr/`](../reference/adr/README.md) | Decision records: why it is built this way, the tradeoffs, the alternatives |
| [`../reference/runbook-errata.md`](../reference/runbook-errata.md) | Errata, known issues, troubleshooting, open `[verify]` risks |
| [`../reference/copilot-studio-billing.md`](../reference/copilot-studio-billing.md) | Copilot Studio billing/licensing models and their workshop implications |

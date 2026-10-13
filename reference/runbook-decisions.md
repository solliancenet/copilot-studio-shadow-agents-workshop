# Runbook — background, decisions & alternatives

> The "why" behind the [provisioning runbook](../setup/RUNBOOK.md): design decisions and the tradeoffs
> they carry, how the machinery works under the hood, and the manual alternatives to the scripted path.
> Keyed to the phase/step they relate to. What *goes wrong* lives next door in
> [`runbook-errata.md`](runbook-errata.md); vendor billing/licensing models are in
> [`copilot-studio-billing.md`](copilot-studio-billing.md).

## Estates

### Why every name carries an estate id

More than one facilitator can build Halcourt Mutual in the same tenant, and the scripts find everything
they create **by name**. Under the canonical names a second build adopts or overwrites the first: its
Phase 3 skips creating `Claims-Test` because one exists, its Phase 5 seeds someone else's Dataverse, and
both share Marcus, Tom and the rest — so one person's Phase 6.5 orphans Tom for everyone.

Scoping every created name with an estate id makes the builds independent. Two things stay shared because
a tenant has exactly one of each: the default environment (`Halcourt (default)`) and the Conditional
Access baseline. The full rule is in `AGENTS.md` → *Live estate naming*; `setup/scripts/_estate.ps1`
implements it.

Attendees get the estate id along with the tenant domain. The lab pages use the canonical names and Lab 00
tells them to expect the suffix — the alternative, regenerating the published pages per build, would put
the artifact pack and the answer key out of sync with every estate but one.

## Phase 0 — tenant

### Why the Conditional Access baseline replaces security defaults

Security defaults are the right setting for a real small tenant, but they make this workshop painful to
build and to run:

- **They block device-code sign-in.** Device codes are the only sign-in that works from the dev container
  (a browser login redirects to `localhost` on the *host*, where nothing is listening), and scripts `01`,
  `03`, `05` and `99` always use them. Security defaults reject every device-code sign-in with
  *AADSTS530035* and take no exceptions — not even for the build admin. With them on, every sign-in has to
  happen in a desktop browser on the host or the VM, racing `Connect-MgGraph`'s two-minute window.
- **They put every persona through MFA registration.** Security defaults make every account register for
  MFA, then prompt whenever Entra decides to. The build signs in as the personas to author agents and own
  connections (Phase 6), and attendees sign in as Ana Reyes and Jordan Blake. Each account would need its
  own authenticator enrollment on someone's phone, and a surprise prompt mid-demo stalls the room.
- **They lock out Conditional Access.** Enabled Conditional Access policies can't coexist with security
  defaults, and the estate needs two: Module 5 tests Conditional Access against the canon in `AGENTS.md`.

### What the baseline keeps, and what it gives up

It keeps the two protections that matter here: MFA on every admin role, and no legacy authentication. It
gives up MFA for ordinary accounts and security defaults' risk-based prompts — acceptable **only** because
this is an isolated lab tenant holding fictitious data. Never do this to a production tenant.

Two gaps are deliberate: no policy targets workload/agent identities (a Module 5 finding), and none blocks
device-code flow (the build needs it). If Microsoft later adds a managed policy that restricts
authentication flows, `00_conditional_access_baseline.ps1`'s summary warns — exclude the build admin
from it.

### Why sign-ins use device codes, and why Graph needs org-wide consent

*Device code.* In the dev container a browser login opens your host browser, but Entra redirects it to
`http://localhost:<random port>` — the host, not the container, where the login is waiting — so the tab
hangs. Device-code logins (a code entered at https://microsoft.com/devicelogin) avoid that. The scripts
that call Graph (`01`, `05`, `99`) first **reuse your `az` sign-in**: its saved Graph token already carries
the scopes they need, so they don't ask at all (`setup/scripts/_auth.ps1`), and fall back to a device code
only when `az` isn't signed in to the lab tenant. PnP (`03`) always uses a device code.

*Consent.* The scripts sign in as the **Microsoft Graph Command Line Tools** app with delegated scopes. A
sign-in that asks for a scope nobody has consented to stops at a consent prompt, or fails with
*AADSTS65001* where it can't show one — hence consenting to the whole set once, for the organization.

*`pac` and the PowerApps admin module need nothing granted.* Both are Microsoft first-party apps and the
global admin already holds Power Platform admin rights. PnP.PowerShell is the exception: PnP 3.x ships no
shared sign-in app, so it needs its own registration (Phase 4).

## Phase 1 — Azure

### Why the azd environment name must be unique per estate

azd derives the whole deployment from the environment name: the resource group is `rg-<name>`, and every
resource name — the registry, the Foundry account and project, the three Container Apps — comes from a
token computed from subscription + environment name + region (`infra/main.bicep`).

Two deployments with the same name in the same subscription and region are therefore the *same*
resources: the second `azd up` redeploys the first facilitator's apps and replaces their Policy API key
and MCP bearer, silently breaking every agent built against them. Reusing the name of a torn-down
deployment fails differently — the Foundry soft-delete trap (errata). A per-estate name,
`halcourt-<estate>-lab`, avoids both; add a suffix (`-2`, a date) when you rebuild.

Pass `--subscription` and `--location` explicitly too: otherwise azd falls back to its global defaults
(`azd config get defaults`), which can point at a subscription outside the lab tenant. `eastus2` is
tested; any region with gpt-5-mini (GlobalStandard) quota works.

### The Container App addresses

`azd env get-values` reports `POLICY_API_FQDN` / `UNDERWRITING_MCP_FQDN`. Despite the names they are full
URLs, scheme included — `https://ca-policyapi-<token>.<env-id>.<region>.azurecontainerapps.io` and
`https://ca-underwritingmcp-<token>.<env-id>.<region>.azurecontainerapps.io`, where `<env-id>` is the
Container Apps environment's generated name (e.g. `politestone-503df790`). These default
`*.azurecontainerapps.io` addresses — no custom domain, no DNS to configure — are what the agents' actions
point at: the host part (drop `https://`) is the `<policy-api-fqdn>` / `<mcp-fqdn>` in
`agent-authoring-guide.md`.

`azd up` deploys the entire project, but the workshop's agents use only the two weak apps. The demo web
app's member API (`/api/*`) returns **500** on this path — it needs the Entra app registration that
`infra/setup-env.sh` creates (`API_APP_ID`). Run that script only if you want the Foundry web demo.

The **static API key** you set here is the one that ends up in Policy Lookup Bot's HTTP action config.
That exposure is the point of Scenario E.

## Phase 2 — identities

### Why the personas live on the tenant's own domain

`AGENTS.md`, the artifact pack and the lab pages write every UPN as
`<alias>@halcourtmutual.onmicrosoft.com`, but a lab tenant keeps whatever domain Microsoft assigned it (a
Dev Program sandbox gets something like `0zwdt94t.onmicrosoft.com`), and an `*.onmicrosoft.com` domain
**cannot** be added to another tenant. So `01_provision_entra.ps1` uses the tenant's default verified
domain and announces the mapping before it creates anything.

`-DomainSuffix <domain>` picks another domain, but only one the tenant has verified — anything else stops
the script before it creates an account. What stays fixed is the **alias** (`ana.reyes`, `svc-claims`,
`it.helpdesk`, …): the later scripts find accounts by alias + estate on the tenant's domain.

### How the `it.helpdesk` shared mailbox gets created

Graph can't create shared mailboxes, but Exchange Online can, and `Connect-ExchangeOnline` accepts a
delegated **access token** — so `_auth.ps1`'s `Connect-LabExchange` reuses the same `az` sign-in the rest
of Phase 2 uses (no device code, no app-only Exchange app) and runs:

```powershell
New-Mailbox -Shared -Name "IT Helpdesk (<estate>)" -Alias it.helpdesk.<estate> -PrimarySmtpAddress it.helpdesk.<estate>@<domain>
```

Keep `-Alias`: without it Exchange derives an alias from the name and the account isn't
`it.helpdesk.<estate>@…`. Exchange creates the account **disabled for sign-in**, as it does for every
shared mailbox, and provisions it asynchronously (it can take a minute to appear). This mailbox is the
ambiguous owner of Policy Lookup Bot, so it must exist; Phase 6 turns its sign-in on so it can own that
agent. If the automatic step can't run (no `az` session, or the admin isn't an Exchange admin) the script
warns and prints the same command to run yourself after `Connect-ExchangeOnline -Device`.

## Phase 3 — environments, DLP, billing

### Why you don't choose the environment's country

The environment API no longer accepts one. It requires a **macro region** (`-MacroRegion`, default
`north-america`) and assigns the country itself: `location` alone is rejected (*MacroRegionRequired*), and
a specific `azureRegion` is ignored. The tenant this runbook was verified on got **Canada** for every
environment. That is fine as long as it is consistent — the script warns if an estate's environments land
in different regions, and the billing plan has to follow whatever the summary reports.

### Why the estates share one billing plan per region

A billing plan is region-locked and is just an Azure meter; each environment's usage is reported
separately. So estates in one tenant share a plan rather than each creating their own, and
`02b_provision_billing.ps1` looks for an existing plan in the environments' region before creating one.

`Maker-Sandbox` is a Developer environment: billing plans take production and sandbox environments only,
so it is neither linkable nor needed — its agents publish and run without a plan. Agents **publish**
without any plan at all; a plan is what lets attendees actually send them messages.

### Creating or linking a billing plan by hand

The scripted path is `02b_provision_billing.ps1`. Two manual equivalents, for when you'd rather click or
when a region has no plan yet. Do either only **after** the environments exist, so the plan's region
matches theirs.

**In PPAC:**

1. **Read the region from the Phase 3 summary** (the `Region` column — e.g. `canada`), or in PPAC
   (https://admin.powerplatform.microsoft.com) → **Manage → Environments**.
2. **Create the billing plan in that region.** PPAC → **Licensing → Billing Plans → + New billing plan →
   Azure subscription**. Name it `Halcourt-PAYG-<estate>` → pick the **Azure subscription** and **resource
   group** → set the **Meter** to **Copilot Studio** (Dataverse is auto-included) → **Next**. On **Select
   environments**, set the **Region** filter to the summary's region, then **check**
   `Halcourt-Prod-<estate>` and `Claims-Test-<estate>` → **Save**.
3. **Mind the region-lock.** A plan only lists environments in its own region: if an environment isn't in
   the picker, the plan's region doesn't match it (see errata).

**By API, reusing a plan the region already has.** With `az` signed in as the admin:

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

Re-run the GET to confirm both ids are listed, and check the plan has the **Copilot Studio** meter on (its
`payGoEntitlements` shows `MCSMessages` with `payAsYouGoState: true`). Note that the policy object's
`environmentIds` reads as null — the authoritative list is the `/environments` sub-resource the script
reads.

### The *Copilot Studio authors* tenant setting is optional

Microsoft documents it as how pay-as-you-go makers get into Copilot Studio, but on the verified tenant an
unlicensed persona opened Copilot Studio in a linked environment without it. It has no API. If you want
it: PPAC → **Manage → Tenant settings → Copilot Studio authors** → pick one tenant-wide security group,
e.g. `Halcourt-Copilot-Authors` (it exists on the verified tenant). It is one setting for the whole
tenant, so every estate adds its agent owners to that group rather than pointing the setting at its own.

## Phase 4 / 4b — SharePoint and OneDrive

### Why PnP needs its own app registration, and two identities on it

PnP.PowerShell 3.x ships no shared sign-in app, so the tenant needs one — registered once and shared by
every estate. `az` can register it, allow device codes on it and grant admin consent without a single
sign-in prompt. `az` cannot run the seed itself: SharePoint accepts tokens issued for the Azure CLI's app
but rejects them (401).

The app carries **two** sets of permissions because the kit uses it two ways:

- **Delegated** (`AllSites.FullControl`, Graph `Group.ReadWrite.All`, `User.ReadWrite.All`) — the
  interactive device-code/browser seed, and the admin-side OneDrive provisioning in Phase 4b.
- **Application**, plus a certificate (SharePoint `Sites.FullControl.All` and `User.ReadWrite.All`, Graph
  `Group.ReadWrite.All`) — the headless app-only runs: the Phase 4 seed (`03 -CertPath`) and the Phase 4b
  OneDrive *seed*. Graph `Group.ReadWrite.All` is there because the Phase 4 team sites are M365 groups
  created via Graph; without it the app-only site create 403s.

App-only can *seed* a OneDrive but cannot *provision* one — see below.

### Why the maker provisions their own OneDrive

The **Meeting Notes Summarizer** decoy grounds on Dev Kim's own OneDrive notes, so his OneDrive must exist
and hold his notes before that agent is built. A Dev Program sandbox does not auto-provision a user's
OneDrive reliably.

`03b_provision_onedrive.ps1` therefore signs in **as Dev** with the lab password and calls `GET /me/drive`,
which answers `ResourceNotFound` and can enqueue the personal site behind it. Personas are ordinary users,
so nothing in the CA baseline blocks the password grant. **It is not guaranteed** — `[verify]`,
best-effort: on the verified tenant this created Dev's site within a minute but had produced nothing for
another persona 47 minutes later, on identical licensing. First-access provisioning is asynchronous with
no SLA. So the script tries, waits, and if the site never appears it fails and tells you to provision that
one maker by hand and re-run, which then just seeds. Seeding is app-only with the PnP certificate either
way.

The maker does it because the **admin-side** enqueue can't be done headlessly (all verified 2026-09-22):
**app-only** is refused — *"Attempted to perform an unauthorized operation"* — even with every application
grant (the same token does other tenant-admin work fine, so it wants a *user context*, not a permission);
the **Azure CLI's** delegated token is **401 for every SharePoint tenant-admin call** even as Global Admin;
and a **freshly created SharePoint Administrator** signs in fine but is still refused, because SharePoint
doesn't honour a new role assignment for 15–60 min. The full trail is in the errata,
*Phase 4b · why OneDrive provisioning resists automation*.

Don't use Graph to check whether the OneDrive is ready: `GET /users/<upn>/drive` kept returning
`ResourceNotFound` for Dev **after** his OneDrive existed and had been written to. The script probes the
personal site with PnP instead.

## Phase 5 — Dataverse

### Why `svc-claims` needs a license

A security role can only be assigned to a Dataverse user record, and Dataverse creates one only for an
Entra account that is enabled **and licensed**
([requirements](https://learn.microsoft.com/power-platform/admin/create-users#requirements-for-successfully-adding-users-in-dataverse)).
The exceptions — admin roles, non-interactive accounts, app-pass capacity — don't fit a service account, so
an unlicensed `svc-claims` is refused (*userNotLicensed*) and there is nothing to hang the role on.

Without the role, Claims Copilot's shared connection can't read the claims data, and Scenario C (the
over-broad role) and Scenario D (the agent exercising svc-claims's authority instead of the caller's) have
nothing to show.

### Why E5 is enough

E5 — including the Dev Program sandbox's `DEVELOPERPACK_V2_E5` — carries a free Dataverse plan
(`DYN365_CDS_O365_P3`). Dataverse honors that plan only when a user is added **on demand** (the admin API
or PPAC), not by the background sync; `04_provision_dataverse.ps1`'s add is on demand. No Power Apps or
Dynamics 365 license is needed. `Claims-Test-<estate>` has no security group, so the license is the only
gate.

### Why the tables use `…number` business keys

A Dataverse table's primary key is always `<table>id`, so the canon's business keys live in `mm_customernumber`
and `mm_claimnumber`. The seed CSVs' `mm_customerid` / `mm_claimid` columns map onto them.

### Getting a seat back with non-interactive access mode

If you are short on seats, Microsoft's non-interactive route gives `svc-claims`'s seat back: license it,
run Phase 5, set its **Access Mode** to **Non-interactive** (PPAC → the environment → Users → svc-claims →
*Manage user in Dynamics 365* → Administration), then remove the license. Up to seven per environment.
**[verify]** that Claims Copilot's connection still works as a non-interactive account before relying on
it.

## Phase 6 — agents

### How the provisioning engine works

Verified through the 2026-09-22 greenfield rebuild; see the errata *Greenfield rebuild validation* for the
fresh-environment fixes.

- **Clone-first, committed-authoritative.** `pac copilot push` only *updates*, and needs a *synced* local
  workspace (matching `.mcs` state) — which a committed workspace (gitignored `.mcs`) never has, and which
  `init` alone doesn't reliably leave behind. So each provision **clones** the agent into a temp dir
  (pac's own existence view; the Dataverse `bots` table can disagree), drops the clone's server-state
  knowledge/tools/conn-refs, overlays the committed ones, and pushes. If clone finds nothing the agent is
  absent, so it `init`s the shell first — retried, because the solution import lags — then clones. The
  agent identity is preserved; nothing is deleted.
- **Publisher.** Each agent keeps its committed prefix, and the engine ensures a publisher with that
  prefix exists in the environment. It creates one on a fresh rebuild, because environment teardown gives
  new random CDS prefixes.
- **Owner-token Dataverse.** Bot lookup, chat-audience PATCH and connection binding run **as the owner**,
  not the admin: in the shared default environment the admin has no read on `bots` (it returns empty), and
  a connection reference can only be bound by the connection's owner (Sales Nudge is Lena's but binds
  Tom's connection; Claims Copilot is Priya's but binds svc-claims's).
- **Chat audience** is set on the bot record, then **publish with retry** — publishing right after create
  can be too soon.

### Why the planted mechanisms live in topics

All ten agents author from committed workspaces, no portal (verified 2026-09-22). Connector tools go in a
`TaskDialog`; the HTTP action, MCP invoke and flow invoke go in a **topic**, because a native HTTP/MCP/flow
action publishes as a topic node but not as a tool (errata, *Phase 6 · what authors cleanly vs needs the
portal*).

Most agents — the benign four **and** the connector/HTTP planted ones — are authored as committed
workspaces (`agent.mcs.yml` instructions + `knowledge/` + `actions/` + `connectionreferences.mcs.yml`,
scaffolded with `pac copilot init` then filled in; `capture:"authored"` in the manifest). The ones that
need a portal-only feature, a **Power Automate flow** (Expense Helper) or the **MCP server** (Underwriting)
are built once in the portal and captured into a committed workspace (`capture:"clone"`), then replayed:

```bash
pac copilot clone --bot <schema-name> --environment <env-org-url> --output-dir setup/agents   # then rename the folder to the manifest slug
```

An agent runs only if its workspace is committed under `setup/agents/<slug>/`; others report `SKIP`.

### Building one agent from the command line

The manual counterpart to the engine, and how a planted agent is first captured. Full per-agent detail is
in [`agent-authoring-guide.md`](../setup/agent-authoring-guide.md).

`pac` 2.12 builds and publishes an agent from a local workspace. Sign it in as the owner, with a profile
store of its own so your admin profile is untouched. Password sign-in works for the personas because the
CA baseline only requires MFA of admin roles. Call the real `pac`, not the repo's shim — the shim pins the
profile store to `.pac/`:

```bash
export XDG_DATA_HOME=$HOME/.halcourt-pac/marcus.webb     # one store per persona
~/.dotnet/tools/pac auth create --username marcus.webb.$E@$D --password '<lab password>' --environment <Prod org URL>
~/.dotnet/tools/pac copilot init --name "Benefits Buddy" --publisher-prefix <prefix> --project-dir agents/benefits-buddy
#   edit agents/benefits-buddy/agent.mcs.yml (instructions) and add knowledge/*.mcs.yml, actions/*.mcs.yml
~/.dotnet/tools/pac copilot push --project-dir agents/benefits-buddy
~/.dotnet/tools/pac copilot publish --bot <prefix>_BenefitsBuddy
```

- `<prefix>` is the environment's **CDS Default Publisher** prefix — the one the portal uses (`cr3f5` for
  Prod and Claims-Test on the verified tenant). `init` imports the agent straight away, owned by the
  persona.
- **`push` doesn't send `settings.mcs.yml`.** Set the chat audience on the agent record instead — PATCH
  `bots(<botid>)` with `authorizedsecuritygroupids` = the group's object id — then publish again.
- **`push` creates a connection reference but doesn't bind it.** PATCH `connectionreferences(<id>)` with
  `connectionid` = the owner's connection name, as the owner.
- A failed publish reports its errors in the agent record's `synchronizationstatus` →
  `lastFinishedPublishOperation`, not in `pac`'s output.

Built this way on the verified tenant (2026-09-19): **Team Wiki** (`Maker-Sandbox-mgray`, as Dev) and
**Benefits Buddy** (`Halcourt-Prod-mgray`, as Marcus).

### What to expect from the connections

- **OAuth connections can't be shared.** Sharing `DV-Claims-Shared` or `DV-CRM-Shared` with a group fails
  with *ConnectionSharingNotAllowed*, so the pack's `shared_with` values for them can't appear in a live
  export. The agent is what "shares" them: its tools run on the connection with the maker's credentials.
- **In the default environment the consent page asks the owner to confirm** ("Confirmation required", a
  checkbox, then **Allow access**). That is expected for a connection the owner just created.
- **Dev's OneDrive connection fails until his OneDrive exists** (Phase 4b).

## Phase 7 — the artifact pack

### Why the export runs anywhere now

It used to require the Windows build VM because it drove
`Microsoft.PowerApps.Administration.PowerShell`, whose `Add-PowerAppsAccount` needs `System.Windows.Forms`
and dies on Linux. It now reads the same data over REST with `az`'s sign-in, like Phases 3, 5 and teardown.

One prerequisite remains: the admin needs a security role in **every** Dataverse environment, because the
agent inventory reads each environment's `bot` table. Without a role the read fails with *"has not been
assigned any roles"* (403). Environments the admin created in Phase 3 already have it; a **Developer**
environment does not, because its owner is its only System Administrator.

### Why the committed pack is not a pure export

Three of its columns are hand-written canon that no API returns: agent `description`, the friendly
connector names (`SharePoint`, not `shared_sharepointonline`), and the rows for things that are not Power
Platform connections at all (`HTTP-PolicyAPI`, `MCP-Underwriting`, `PA-Expense-AutoApprove`).

The export therefore **preserves** the existing `description` text by display name rather than blanking it
— regenerating the pack will not destroy that prose — but the connector and conceptual-connection rows
still need a human. Read the diff as *drift to review*, not as a test that should come out empty.

`-Canonicalize` maps the live names back to the canon's (strips the estate id, restores
`@halcourtmutual.onmicrosoft.com`) so the export lands on the committed pack and `git diff` shows the
drift. Without it the script refuses to write into the committed pack, which is published with the site.

## Phase 8b — attendee accounts

### Why attendees get `Power Platform Administrator`, and what the exclusion costs

Lab 01-01 has attendees enumerate an environment's connections. Only the tenant-admin Power Platform
endpoints under `/scopes/admin/` return another person's connections, and only a Power Platform
Administrator reaches them. Both weaker options were tested on `0zwdt94t`, 2026-10-13, and both fail:

| Option | Result |
|---|---|
| `Global Reader` + unlicensed | Signs in fine, reads Entra fine, but **404 `CRMRequestFailed`** on `/scopes/admin/environments` where a tenant admin gets `200` |
| A per-environment role | The maker-facing connections API is **caller-scoped**. `marcus.webb`, who owns 1 of Halcourt-Prod's 2 connections, saw exactly 1; `priya.nair` and `dev.kim`, both environment members, saw 0 |

The second result is the decisive one, and it is easy to assume otherwise. No environment-level role makes
a user see another person's connections, because the API never returns them — this is not a permissions
level we failed to find, it is a scope the endpoint does not have.

The `404` is worth remembering on its own: the tenant-admin endpoints **hide themselves from an
unauthorized caller** rather than returning `403`. An attendee following Lab 01-01 sees "not found" and
reasonably concludes the estate is empty. It is an authorization result wearing a not-found costume.

**So the role is necessary, and it is MFA-gated.** Power Platform Administrator sits in
`CA-Require-MFA-Admins` (`00_conditional_access_baseline.ps1`), and an account holding it cannot sign in
with a handed-out password at all — `AADSTS50079`. The resolution is one group per delivery,
`Lab-Students-<estate>`, added to that policy's `excludeGroups`.

Three properties make the exclusion safe to automate:

- **Additive both ways.** The policy is read, one field changes, the whole `conditions` object goes back.
  Another estate's exclusion is never touched, and `-Destroy` drops only this estate's group id.
- **Verified after the write.** The script re-reads the policy and warns if the admin-role count moved.
  This policy is what keeps MFA on the tenant's real admins; a silent clobber would be the worst outcome
  here, so the write is never taken on trust.
- **No extra sign-in.** `00_conditional_access_baseline.ps1` connects separately because it asks for
  `Policy.ReadWrite.ConditionalAccess`. It turns out az's delegated `Directory.AccessAsUser.All` already
  covers Conditional Access for a Global Administrator — verified `GET` 200 and `PATCH` 204 — so Phase 8b
  stays non-interactive.

**The cost, stated plainly.** An attendee account is a tenant-wide Power Platform admin exempt from the
admin MFA policy. It can change or delete any environment in the tenant, including another facilitator's
estate, and it makes Lab 00-01's "a security reviewer observes; they do not change the estate" untrue of
the account itself. Give a delivery its own tenant where you can. This is only ever appropriate in an
isolated, disposable training tenant.

One cheaper option was not testable from the CLI and would be worth five minutes before the next delivery:
whether PPAC's **portal** shows an environment's connections to a `Global Reader`. If it does, the step
could be rewritten portal-first and the attendee account could go back to read-only.

### Why licence assignment is best effort

A Dev Program sandbox carries **25** E5 seats. The estate itself needs eight (Phase 2), and the optional
content pack's ~16 sample users hold most of the rest; on the build tenant `subscribedSkus` reported
`DEVELOPERPACK_V2_E5` at **25/25 consumed, 0 free**, so every attendee account came out unlicensed.

That is why `07_provision_lab_users.ps1` checks seat availability up front, attempts assignment per account,
never treats a failure as fatal, and prints who actually got one. Nothing an attendee does needs a seat:
Entra reads do not, the `/scopes/admin/` Power Platform calls do not (verified unlicensed), and opening an
agent in Copilot Studio is already gated on being its owner or co-author (Lab 01-01 step 6), which an
attendee never is. `FLOW_FREE` (10,000 seats, 1 consumed) is
available if some surface merely requires *a* licence to be present.

The accounts still get `usageLocation` stamped from the tenant's country, because a licence cannot be
assigned to an account without one — so freeing seats later and re-running is enough.

### Why the script purges, not just deletes

Deleting a user only **soft**-deletes it: it sits in `directory/deletedItems` for 30 days holding its UPN
and `mailNickname`. The next delivery's `student01.<estate>` would collide with the last one's. `-Destroy`
therefore deletes and then purges, the same lesson Phase 9 learned about sites and groups.

The same applies to `Lab-Students-<estate>`, and it matters more there: a soft-deleted group still holds
its `mailNickname`, so the next delivery could not recreate it, and the Conditional Access exclusion would
be left pointing at a group nobody can see. `-Destroy` removes the exclusion first, then deletes and purges
the group, in that order.

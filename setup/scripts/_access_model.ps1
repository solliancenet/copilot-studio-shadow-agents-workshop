# FACILITATOR-ONLY. The attendee ACCESS MODEL - dot-sourced by 07_provision_lab_users.ps1 (which enforces it)
# and 00b_preflight.ps1 (which checks it). One source, so the two can never disagree.
#
# One row per Dataverse privilege the lab role grants (always at Global depth), with the EXERCISE STEP that
# needs it. This table is the specification. $DvPrivilegeNames is derived from it, and 07 reconciles every
# estate environment to exactly this set on every run - adding what is missing and REMOVING what is not
# listed (07 -KeepExtraPrivileges reports instead). Extend it from an exercise's requirement, never from a
# failing probe: three modules in a row (03-02, 03-04, then Exercise 04 and the Copilot Studio steps of 01
# and 02) had their live path blocked because the role had been sized for 01-02 and grown reactively. A
# privilege nobody can tie to a step does not belong here.
#
# Every DATAVERSE privilege here is prvRead*. The directory roles are not all read-only: Power Platform
# Administrator (standing - the /scopes/admin/ connection reads need it) can self-elevate to System
# Administrator in any environment, edit tenant DLP and delete environments. The read-only stance is a rule
# the lab pages set ("look but don't change until a task says so"), not something these roles enforce.
#
# The model needs a LICENCE to take effect. An unlicensed account runs in Dataverse Administrative access
# mode, which filters a custom role's privileges; only System Administrator survives. Verified 2026-10-17:
# same model, licensed account opens the agent page, unlicensed accounts get "You don't have permission".
#
# Why it is a custom role PLUS the built-in `Bot Viewer`, not either alone (verified 2026-10-16):
#   - Opening an agent in Copilot Studio needs bot reads at GLOBAL depth, because the estate's agents belong
#     to the personas, not to the attendee. `Bot Viewer` grants them at BASIC depth (own records only), so
#     on its own it reads nothing and the page says "You need additional access".
#   - It ALSO needs reads `Bot Viewer` supplies - AIPlugin(Operation), Solution, Publisher,
#     EnvironmentVariableDefinition - at the depths Copilot Studio expects. Microsoft maintains that set as the
#     product changes; this role adds one only where Bot Viewer's depth (Basic) fails a step: Workflow and
#     connectionreference, which the attendee reads on other people's agents (see their rows below).
#   So: the lab role carries the Global-depth reads and the Copilot* set; `Bot Viewer` carries the rest.
#   Tested one combination at a time: role alone fails, `Bot Viewer` alone fails, together they work.

$DvRoleName   = 'Lab Reviewer (read-only)'
# Entra directory roles every attendee holds (07 -Roles defaults to these).
#   Power Platform Administrator - the /scopes/admin/ connection reads (01-01); tenant-wide, MFA-gated.
#   AI Reader - read-only; M365 admin center > Agents (Agent 365): All agents, Agent map, Tools, Settings,
#               for 01-01 KT01 s3, 02-01 KT01 s1, 04-06 KT01 s1, 05-05 KT01. Without it the Agents page is
#               ABSENT from the nav, which looks exactly like a tenant that lacks Agent 365 (it was
#               misreported as such until 2026-10-17). Agent 365 itself needs no service plan in the SKU
#               list: the tenant shows the 'Agent 365' service principal and the page renders for AI Reader
#               on DEVELOPERPACK_V2_E5.
#   Security Reader - read-only; Entra > Conditional Access policies (05-04 KT01) and the Defender portal's
#               Alerts, Incidents and AI agents (05-07). Without it CA says "You don't have access" and Defender
#               shows only Audit and Settings (verified 2026-10-18). It does NOT reach Purview, whose role
#               groups are separate.
#   Global Reader - read-only, tenant-wide. Chosen for Purview (05-06, 05-07): it is the one Entra role Purview
#               honours for Information Protection (labels, classifiers) and DSPM for AI, without the
#               interactive Security & Compliance sign-in a Purview role group would need. Broad: attendees can
#               read all tenant configuration - acceptable in an isolated training tenant, a decision made
#               2026-10-18.
$DirectoryRoles = @('Power Platform Administrator', 'AI Reader', 'Security Reader', 'Global Reader')
# PIM-ELIGIBLE roles: none. Exercise 05 is DEMONSTRATED (decided 2026-10-19): the facilitator applies each
# control to the shared estate once and restores it (09_ex05_demo_state.ps1); attendees retest. So no
# attendee needs a write role - not AI Administrator (05-05's Block), not Security Administrator (05-07's
# Defender setting, and it can edit Conditional Access), not Conditional Access Administrator, not
# Dataverse System Administrator. 07 keeps the PIM machinery for a future step that truly needs one.
$EligibleRoles = @()
# Eligibility an older kit granted; 07 withdraws it on its next run.
$RetiredEligibleRoles = @('AI Administrator', 'Security Administrator')

# Estate groups every attendee joins (plain names; 07 adds the estate suffix). Membership is what lets a
# lab account CHAT with the published agents: 06 restricts chat on each agent to one security group
# (accesscontrolpolicy 2), and Exercise 04 has attendees drive Benefits Buddy, Claims Copilot and Expense
# Helper with their own account (04-01, 04-02, 04-04). All-Employees also makes the attendee an ordinary
# employee on the HR-Benefits site - the same reach as the Jordan Blake persona, which is the point of
# Scenario B: the agent reaches Leadership/, the attendee cannot.
#   NOT Halcourt-Makers: it carries maker rights, so Underwriting Assistant and Sales Nudge stay out of chat.
$AudienceGroups = @('All-Employees')
# The Conditional Access policy attendees enrol MFA against (00_conditional_access_baseline.ps1 creates it).
$CaPolicyName = 'CA-Require-MFA-Admins'

$DvAccessModel = @(
  # PPAC: users, roles, connections ........................... Lab 00-02, 01-01, 02-03, 03-01, 03-02, 03-04
  @{ Privilege = 'prvReadUser';                   Needs = '00-02 KT01 s3 maker access; 03-01 Access panel; 03-04 KT01 s3 acting identity' }
  @{ Privilege = 'prvReadRole';                   Needs = '00-02 KT01 s3; 03-02 KT01 roles list; 03-04 KT01 s3' }
  @{ Privilege = 'prvReadOrganization';           Needs = '03-01 environment hub' }
  @{ Privilege = 'prvReadBusinessUnit';           Needs = '03-02: a role scoped to a business unit' }
  @{ Privilege = 'prvReadConnector';              Needs = '01-01 KT01 s3 and 02-03 connections' }
  @{ Privilege = 'prvReadTeam';                   Needs = '03-02 role editor: roles(...) read (named in its 403)' }
  @{ Privilege = 'prvReadPosition';               Needs = '03-02 KT01 s2, 04-04 KT01 s1: PPAC Settings > Users list - its systemusers query (named in its 403; without it the list shows "something went wrong")' }
  @{ Privilege = 'prvReadSettingDefinition';      Needs = 'PPAC Settings > Users: settingdefinitions read (named in its 403)' }
  @{ Privilege = 'prvReadWorkflow';               Needs = '03-01 KT01 s2, 04-04 KT02 s5: PPAC Resources > Flows lists another owner''s flow (Bot Viewer grants it at Basic only: the list said "No flows found")' }
  # PPAC role editor: the per-table privilege grid ............................. 03-02 KT01 s2, 03-04 KT01 s3
  @{ Privilege = 'prvReadAttribute';              Needs = '03-02 role editor: EntityDefinitions (named in its 403)' }
  @{ Privilege = 'prvReadEntity';                 Needs = '03-02 role editor: EntityDefinitions' }
  @{ Privilege = 'prvReadRelationship';           Needs = '03-02 role editor: EntityDefinitions (named in its 403)' }
  @{ Privilege = 'prvReadCustomization';          Needs = '03-02 role editor: managed properties' }
  @{ Privilege = 'prvReadRecordFilter';           Needs = '03-02 role editor: row-level security' }
  @{ Privilege = 'prvReadEntityRecordFilter';     Needs = '03-02 role editor: row-level security (named in its 403)' }
  # Copilot Studio: open an agent; read Knowledge, Topics, Tools, Connection Settings
  # ............ 01-01 KT01 s2-3, 01-02, 01-03, 02-01 KT01, 02-02, 02-03, 04-01 KT01, 04-03, 04-05, 04-06
  @{ Privilege = 'prvReadbot';                    Needs = 'agent list and agent page - GLOBAL depth, the agents belong to the personas' }
  @{ Privilege = 'prvReadbotcomponent';           Needs = 'Knowledge, Topics, Tools' }
  @{ Privilege = 'prvReadbotcomponentcollection'; Needs = 'agent page' }
  @{ Privilege = 'prvReadconnectionreference';    Needs = '02-02, 03-01, 03-04, 04-02: a connector tool''s Details / credentials setting (Bot Viewer grants it at Basic only: Claims Copilot''s tools said "error obtaining required dependencies")' }
  @{ Privilege = 'prvReadmsdynce_botcontent';     Needs = 'agent page' }
  @{ Privilege = 'prvReadAICopilot';              Needs = 'agent page' }
  @{ Privilege = 'prvReadCopilotExampleQuestion'; Needs = 'agent page' }
  @{ Privilege = 'prvReadCopilotGlossaryTerm';    Needs = 'agent page (named in its 403)' }
  @{ Privilege = 'prvReadCopilotSynonyms';        Needs = 'agent page (named in its 403)' }
)
$DvPrivilegeNames = @($DvAccessModel | ForEach-Object { $_.Privilege })

# Built-in roles assigned ALONGSIDE the lab role, by name. Never pruned - they are Microsoft's.
$DvCompanionRoles = @('Bot Viewer')

# Tenant capabilities the exercises assume, that no script can provision. The preflight checks each one
# and names the steps that lose their LIVE path without it; every such step has an artifact-pack fallback.
$TenantCapabilities = @(
  @{ Name = 'Purview sensitivity label Confidential-PII + SSN sensitive info type'; Protects = '05-06 and the Scenario B verdict'; Fallback = 'none - no phase creates them; AGENTS.md lists them as estate components' }
  @{ Name = 'Teams-capable seat per attendee (E5)';           Protects = '04-01, 04-02, 04-04 chat: the agents authenticate with Microsoft, Teams is the only working channel (the M365 Copilot option is greyed out), and Teams refuses an unlicensed account outright - verified 2026-10-17'; Fallback = 'the reveal blocks and the artifact pack' }
  @{ Name = 'Dataverse-capable licence per attendee';        Protects = 'the access model in the SHARED estate: the PPAC role editor (03-02 KT01 s2, 03-04 KT01 s3, 04-03 KT02 s2) and the Copilot Studio agent pages (01-01 KT02 s6, 01-02, 01-03, 02-01..03, 03-01, 03-02 KT02 s2, 03-04, 04-01..06, 05-01 KT02 s2, 05-03 KT01 s1, 05-04 KT06 s2). Unlicensed = Administrative mode, which filters the custom role'; Fallback = 'the role editor in 03-02 and 03-04: the attendee''s own slice, where System Administrator survives the filter; everything else: the artifact pack' }
)

# Privileges Dataverse stamps onto EVERY custom role at creation and refuses (HTTP 400) to remove. They are
# not drift and not this kit's doing; 07 reports them once and the preflight ignores them. Observed on all
# three estate environments 2026-10-17. If a fresh build shows another one on every environment, it belongs
# here - not in $DvAccessModel, because no exercise step asked for it.
$DvBaselinePrivileges = @(
  'prvCreateSharePointData', 'prvReadSharePointData', 'prvReadSharePointDocument', 'prvWriteSharePointData',
  'prvReadPluginAssembly', 'prvReadPluginType',
  'prvReadSdkMessage', 'prvReadSdkMessageProcessingStep', 'prvReadSdkMessageProcessingStepImage'
)

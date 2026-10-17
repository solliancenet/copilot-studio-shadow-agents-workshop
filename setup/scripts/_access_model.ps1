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
# Everything here is prvRead*. The reviewer stance - observe the shared estate, change nothing - holds.
#
# The model needs a LICENCE to take effect. An unlicensed account runs in Dataverse Administrative access
# mode, which filters a custom role's privileges; only System Administrator survives. Verified 2026-10-17:
# same model, licensed account opens the agent page, unlicensed accounts get "You don't have permission".
#
# Why it is a custom role PLUS the built-in `Bot Viewer`, not either alone (verified 2026-10-16):
#   - Opening an agent in Copilot Studio needs bot reads at GLOBAL depth, because the estate's agents belong
#     to the personas, not to the attendee. `Bot Viewer` grants them at BASIC depth (own records only), so
#     on its own it reads nothing and the page says "You need additional access".
#   - It ALSO needs reads `Bot Viewer` supplies and this role does not try to - connectionreference,
#     AIPlugin(Operation), Workflow, Solution, Publisher, EnvironmentVariableDefinition - at the depths
#     Copilot Studio expects. Microsoft maintains that set as the product changes; this role should not.
#   So: the lab role carries the Global-depth bot reads and the Copilot* set; `Bot Viewer` carries the rest.
#   Tested one combination at a time: role alone fails, `Bot Viewer` alone fails, together they work.

$DvRoleName   = 'Lab Reviewer (read-only)'
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
  @{ Name = 'M365 agent registry (Agent 365) service plan'; Protects = '01-01 KT01 s3, 02-01 KT01 s4, 04-06 KT01 s1'; Fallback = 'agents-export.csv, inline in each step' }
  @{ Name = 'Dataverse-capable licence per attendee';        Protects = 'the access model in the SHARED estate: 03-02 role editor, Copilot Studio agent pages (01-01 s2-3, 01-02, 02-01..03, 04-01/03/05/06). Unlicensed = Administrative mode, which filters the custom role'; Fallback = 'own slice (System Administrator survives filtering) or the artifact pack' }
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

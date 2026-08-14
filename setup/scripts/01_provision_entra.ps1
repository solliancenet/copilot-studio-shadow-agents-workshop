<#
FACILITATOR-ONLY. Phase 2 — Entra identities & personas for the Meridian Mutual demo estate.
Creates the personas, the service account, the shared mailbox, and the groups from AGENTS.md.

IMPORTANT ordering: create tom.dean ENABLED now. Only AFTER his shared connections exist (Phase 6),
run this script again with -DisableDepartedOwner to orphan him. That timing makes the orphan real.

Requires: Microsoft.Graph (Connect-MgGraph with User.ReadWrite.All, Group.ReadWrite.All).
Lines marked [verify] depend on tenant specifics.
#>
param(
  [string]$DomainSuffix = 'meridianmutual.com',
  [string]$InitialPassword = 'Lab-Only-Passw0rd!',   # rotate per delivery; lab-only
  [switch]$DisableDepartedOwner
)

$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.ReadWrite.All','Group.ReadWrite.All' | Out-Null

if ($DisableDepartedOwner) {
  Write-Host 'Disabling departed owner tom.dean (run this ONLY after his connections exist)...'
  Update-MgUser -UserId "tom.dean@$DomainSuffix" -AccountEnabled:$false
  Write-Host 'tom.dean disabled. Onboarding Guide + Sales Nudge connections must remain live.'
  return
}

$people = @(
  @{ First='Ana';    Last='Reyes'; Upn="ana.reyes@$DomainSuffix";    Note='Platform admin / CoE lead (attendee vantage)' }
  @{ First='Marcus'; Last='Webb';  Upn="marcus.webb@$DomainSuffix";  Note='HR maker' }
  @{ First='Priya';  Last='Nair';  Upn="priya.nair@$DomainSuffix";   Note='Claims/underwriting maker' }
  @{ First='Sam';    Last='Olsen'; Upn="sam.olsen@$DomainSuffix";    Note='Finance approver + maker' }
  @{ First='Lena';   Last='Ford';  Upn="lena.ford@$DomainSuffix";    Note='Sales manager' }
  @{ First='Dev';    Last='Kim';   Upn="dev.kim@$DomainSuffix";      Note='Developer (broad SharePoint)' }
  @{ First='Tom';    Last='Dean';  Upn="tom.dean@$DomainSuffix";     Note='Departed admin (disable in Phase 6.5)' }
  @{ First='Jordan'; Last='Blake'; Upn="jordan.blake@$DomainSuffix"; Note='Low-privilege employee (confused-deputy path)' }
  @{ First='Claims'; Last='Service'; Upn="svc-claims@$DomainSuffix"; Note='Service account for the shared Dataverse connection' }
)

foreach ($p in $people) {
  $pwProfile = @{ Password = $InitialPassword; ForceChangePasswordNextSignIn = $false }
  Write-Host "Creating $($p.Upn) - $($p.Note)"
  New-MgUser -AccountEnabled -DisplayName "$($p.First) $($p.Last)" `
    -UserPrincipalName $p.Upn -MailNickname ($p.Upn.Split('@')[0]) `
    -PasswordProfile $pwProfile | Out-Null
}

# it.helpdesk shared mailbox — [verify] created via Exchange Online (New-Mailbox -Shared) not Graph.
Write-Host '[verify] Create the it.helpdesk shared mailbox in Exchange Online: New-Mailbox -Shared -Name "IT Helpdesk" -PrimarySmtpAddress it.helpdesk@'$DomainSuffix

$groups = 'Meridian-Makers','HR-Team','Claims-Adjusters','All-Employees'
foreach ($g in $groups) {
  Write-Host "Creating group $g"
  New-MgGroup -DisplayName $g -MailEnabled:$false -SecurityEnabled:$true -MailNickname $g | Out-Null
}

Write-Host 'Phase 2 complete. Remember Phase 6.5: re-run with -DisableDepartedOwner after Tom''s connections exist.'

// Azure AI Foundry for the Claims Triage demo: an AIServices account, a Foundry
// project, and a chat model deployment. The agent itself (instructions, tools,
// File Search) is authored LATER via the Foundry portal/SDK — NOT here.

@description('Azure region for all resources.')
param location string

@description('Tags applied to every resource (includes azd-env-name).')
param tags object

@description('Stable per-environment suffix for globally-unique names.')
param resourceToken string

@description('Principal id of the app user-assigned identity, granted the Foundry User role.')
param appIdentityPrincipalId string = ''

@description('Resource id of the Application Insights component to wire as the project tracing connection. Empty skips the connection.')
param appInsightsId string = ''

@description('Application Insights connection string (ingestion key). Threaded as the ApiKey credential for the project connection.')
@secure()
param appInsightsConnectionString string = ''

@description('Chat model to deploy (Foundry / Azure OpenAI model name).')
param modelName string = 'gpt-4.1'

// Pin the model version explicitly rather than relying on a service default so
// the deployment is reproducible. Update as newer versions ship.
@description('Version of the chat model to deploy.')
param modelVersion string = '2025-04-14' // [verify] current GA version for gpt-4.1

@description('GlobalStandard throughput capacity (thousands of tokens/min) for the deployment.')
param modelCapacity int = 50

// AIServices account = the Azure AI Foundry resource. A custom subdomain is
// REQUIRED for Entra token-based auth (data-plane calls to the account/project).
// Type + API version verified against the live provider (2025-06-01). // [verify]
resource foundryAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: 'aif-${resourceToken}'
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // Custom subdomain — required for token auth.
    customSubDomainName: 'aif-${resourceToken}'
    // Enables Foundry projects as child resources under this account.
    allowProjectManagement: true
    // Demo posture: public network access is left ON so attendees can reach the
    // endpoint without private networking. Lock this down for anything real.
    publicNetworkAccess: 'Enabled'
  }
}

// Foundry project (child of the AIServices account). Type + API version verified
// against the live provider (2025-06-01). // [verify]
resource foundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: foundryAccount
  name: 'proj-${resourceToken}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'Claims Triage'
    description: 'Foundry project for the Halcourt Mutual Claims Triage demo agent.'
  }
}

// Chat model deployment on the account. GlobalStandard SKU with param capacity.
resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: foundryAccount
  name: modelName
  sku: {
    name: 'GlobalStandard'
    capacity: modelCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
      version: modelVersion
    }
  }
}

// "Foundry User" — the data-plane role that lets the app identity call the project's agents /
// Responses API. Assigned at the account scope so it covers the project's data plane.
var foundryUserRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '53ca6127-db72-4b80-b1b0-d745d6d5456d'
)

resource foundryUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(appIdentityPrincipalId)) {
  scope: foundryAccount
  name: guid(foundryAccount.id, appIdentityPrincipalId, foundryUserRoleId)
  properties: {
    principalId: appIdentityPrincipalId
    roleDefinitionId: foundryUserRoleId
    principalType: 'ServicePrincipal'
  }
}

// Project → App Insights connection. This is what makes agent runs trace into the
// Azure Monitor "AI Agents" view. Created out-of-band by CLI originally; now reproducible.
// authType ApiKey with the App Insights connection string is the confirmed-working shape
// (verified against the live connection via `az rest GET .../connections/appinsights`);
// App Insights ingestion keys already flow through resources.bicep outputs, so no new
// secret is introduced — it just lands in template/deployment state like the existing outputs.
// Type + api-version + property shape verified against the live provider (bicepschema +
// live GET). // [verify resolved]
resource appInsightsConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01' = if (!empty(appInsightsId)) {
  parent: foundryProject
  name: 'appinsights'
  properties: {
    category: 'AppInsights'
    authType: 'ApiKey'
    target: appInsightsId
    credentials: {
      key: appInsightsConnectionString
    }
    // The provider normalizes this to false for the AppInsights category, so set false to
    // match what the API stores (else every what-if / provision shows phantom drift).
    isSharedToAll: false
    metadata: {
      ApiType: 'Azure'
      ResourceId: appInsightsId
    }
  }
}

output AZURE_AI_FOUNDRY_ENDPOINT string = foundryAccount.properties.endpoint
output AZURE_AI_FOUNDRY_PROJECT string = foundryProject.name
output AZURE_AI_FOUNDRY_PROJECT_ENDPOINT string = '${foundryAccount.properties.endpoint}api/projects/${foundryProject.name}'
output AZURE_OPENAI_MODEL string = modelDeployment.name

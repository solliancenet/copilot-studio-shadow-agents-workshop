// Resource-group-scoped resources for the Meridian Mutual demo app:
// Log Analytics, Container Apps environment, ACR, a user-assigned identity with
// AcrPull, and the Container App itself.

@description('Azure region for all resources.')
param location string

@description('Tags applied to every resource (includes azd-env-name).')
param tags object

@description('Stable per-environment suffix for globally-unique names.')
param resourceToken string

@description('AppId of the Entra app registration fronting the member API. Wires the app\'s AzureAd auth (ClientId + Audience api://<appId>). Empty leaves /api/* unauthenticated.')
param apiAppId string = ''

@description('Entra tenant id the API validates tokens against.')
param tenantId string = ''

// azd matches this service to the `web` service in azure.yaml via this tag.
var serviceName = 'web'

// Placeholder image used only for the very first provision. `azd deploy` builds
// the real image from src/Dockerfile, pushes it to ACR, and updates the app.
var placeholderImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-${resourceToken}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Application Insights (workspace-based) — the sink for both the app's telemetry and the Foundry
// agent's OTel traces. Agent runs and their tool calls land in the Azure Monitor "AI Agents" view
// via this resource, so the denied write call is visible alongside the successful reads.
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${resourceToken}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource containerAppsEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-${resourceToken}'
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// ACR name must be alphanumeric and globally unique; strip to a safe token.
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: 'acr${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${resourceToken}'
  location: location
  tags: tags
}

// Built-in AcrPull role definition.
var acrPullRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, appIdentity.id, acrPullRoleId)
  properties: {
    principalId: appIdentity.properties.principalId
    roleDefinitionId: acrPullRoleId
    principalType: 'ServicePrincipal'
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-${serviceName}-${resourceToken}'
  location: location
  // azd finds the app to deploy to by this tag; must match azure.yaml service name.
  tags: union(tags, {
    'azd-service-name': serviceName
  })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppsEnv.id
    configuration: {
      // External ingress is intentional: an external Foundry agent must reach the
      // API over the public internet. TLS is terminated at the ingress; the
      // container listens on plain HTTP port 8080.
      ingress: {
        external: true
        targetPort: 8080
        transport: 'auto'
        allowInsecure: false
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: appIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: serviceName
          image: placeholderImage
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
          env: [
            // The app calls the Foundry Claims-Triage agent with its managed identity. No
            // secrets: only the project endpoint + agent name are configured here. The Foundry
            // account/project names are deterministic from resourceToken (see foundry.bicep),
            // so the endpoint is constructed directly and there is no module dependency cycle.
            {
              name: 'Foundry__ProjectEndpoint'
              value: 'https://aif-${resourceToken}.services.ai.azure.com/api/projects/proj-${resourceToken}'
            }
            {
              name: 'Foundry__AgentName'
              value: 'Claims-Triage'
            }
            // Selects the user-assigned identity for DefaultAzureCredential at runtime.
            {
              name: 'AZURE_CLIENT_ID'
              value: appIdentity.properties.clientId
            }
            // Entra JWT bearer for /api/*. When ClientId is set, Microsoft.Identity.Web validates
            // the caller's token against this app registration and enforces the Claims.Read /
            // Claims.Write app roles. Audience is the App ID URI (api://<appId>). Empty ClientId
            // (e.g. the very first provision before the app reg exists) leaves the API open.
            {
              name: 'AzureAd__Instance'
              value: 'https://login.microsoftonline.com/'
            }
            {
              name: 'AzureAd__TenantId'
              value: tenantId
            }
            {
              name: 'AzureAd__ClientId'
              value: apiAppId
            }
            {
              name: 'AzureAd__Audience'
              value: empty(apiAppId) ? '' : 'api://${apiAppId}'
            }
            // Application Insights — app telemetry + the target the Foundry agent traces to.
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsights.properties.ConnectionString
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
  dependsOn: [
    acrPullAssignment
  ]
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.properties.loginServer
output WEB_URI string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output APPLICATIONINSIGHTS_CONNECTION_STRING string = appInsights.properties.ConnectionString
output APPLICATIONINSIGHTS_NAME string = appInsights.name
output APPLICATIONINSIGHTS_ID string = appInsights.id

// Consumed by the foundry module to grant the app identity the Foundry User data-plane role.
output APP_IDENTITY_PRINCIPAL_ID string = appIdentity.properties.principalId

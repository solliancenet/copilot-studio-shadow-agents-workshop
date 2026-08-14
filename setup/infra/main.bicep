// FACILITATOR-ONLY lab infrastructure for the Meridian Mutual demo estate.
// Deploys two Container Apps that back workshop scenarios:
//   - Policy API   (Scenario E, C) : intentionally over-scoped, authed by a single static key.
//   - Underwriting MCP (Scenario E) : intentionally over-scoped, authed by a static bearer token.
// These are DELIBERATELY WEAK. Deploy only into an isolated lab subscription.

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Prefix for resource names.')
param namePrefix string = 'meridian-lab'

@description('Static API key that will be planted in the Policy Lookup Bot HTTP action (lab-only).')
@secure()
param policyApiKey string

@description('Static bearer token the Underwriting MCP server accepts (lab-only).')
@secure()
param mcpBearer string

@description('Container image for the Policy API. Build/push from infra/policy-api, or use a placeholder.')
param policyApiImage string = 'mcr.microsoft.com/k8se/quickstart:latest'

@description('Container image for the Underwriting MCP server. Build/push from infra/mcp-underwriting.')
param mcpImage string = 'mcr.microsoft.com/k8se/quickstart:latest'

var laName = '${namePrefix}-logs'
var envName = '${namePrefix}-cae'

resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: laName
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource cae 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: envName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logs.properties.customerId
        sharedKey: logs.listKeys().primarySharedKey
      }
    }
  }
}

resource policyApi 'Microsoft.App/containerApps@2024-03-01' = {
  name: '${namePrefix}-policy-api'
  location: location
  properties: {
    managedEnvironmentId: cae.id
    configuration: {
      ingress: { external: true, targetPort: 8080, transport: 'auto' }
      secrets: [ { name: 'policy-api-key', value: policyApiKey } ]
    }
    template: {
      containers: [
        {
          name: 'policy-api'
          image: policyApiImage
          resources: { cpu: json('0.5'), memory: '1Gi' }
          // The app reads POLICY_API_KEY and requires it on the intended endpoint,
          // but ALSO exposes /policy/all and /customer/{id} (the excess) — Scenario C/E.
          env: [ { name: 'POLICY_API_KEY', secretRef: 'policy-api-key' } ]
        }
      ]
      scale: { minReplicas: 1, maxReplicas: 1 }
    }
  }
}

resource mcp 'Microsoft.App/containerApps@2024-03-01' = {
  name: '${namePrefix}-underwriting-mcp'
  location: location
  properties: {
    managedEnvironmentId: cae.id
    configuration: {
      ingress: { external: true, targetPort: 8080, transport: 'auto' }
      secrets: [ { name: 'mcp-bearer', value: mcpBearer } ]
    }
    template: {
      containers: [
        {
          name: 'underwriting-mcp'
          image: mcpImage
          resources: { cpu: json('0.5'), memory: '1Gi' }
          // Accepts a single static bearer for ALL callers, and advertises get_quote,
          // get_risk_score AND run_query (arbitrary) — the over-wide tool schema, Scenario E.
          env: [ { name: 'MCP_BEARER', secretRef: 'mcp-bearer' } ]
        }
      ]
      scale: { minReplicas: 1, maxReplicas: 1 }
    }
  }
}

output policyApiFqdn string = policyApi.properties.configuration.ingress.fqdn
output underwritingMcpFqdn string = mcp.properties.configuration.ingress.fqdn

// Subscription-scoped entry point for `azd up`. Creates the resource group and
// delegates the resources to the resources module.
targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the azd environment; used to name and tag the resource group.')
param environmentName string

@minLength(1)
@description('Azure region for all resources.')
param location string

// Stable per-environment suffix for globally-unique names (e.g. ACR).
var resourceToken = uniqueString(subscription().id, environmentName, location)
var tags = {
  'azd-env-name': environmentName
}

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module resources 'resources.bicep' = {
  name: 'resources'
  scope: rg
  params: {
    location: location
    tags: tags
    resourceToken: resourceToken
  }
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = resources.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT
output WEB_URI string = resources.outputs.WEB_URI
output SERVICE_WEB_URI string = resources.outputs.WEB_URI

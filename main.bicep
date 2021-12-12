targetScope = 'subscription'

var enableLock = false
param tags object = {
  environment: 'development'
}
param prefix string = 'iac'

// Resource Group Parameters
param groupName string = '${prefix}-bicep'
param location string = 'centralus'

// Cluster Parameters
param aksVersion string = '1.20.7'
param adminPublicKey string
param adminGroupObjectIDs array = []

// Create Resource Group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: groupName
  location: location
  tags: tags
}

// Create a Managed User Identity for the Cluster
module clusterIdentity 'modules/user_identity.bicep' = {
  name: 'user_identity_cluster'
  scope: resourceGroup
  params: {
    name: '${groupName}-cluster-identity'
  }
}

// Create Log Analytics Workspace
module logAnalytics 'modules/azure_log_analytics.bicep' = {
  name: 'log_analytics'
  scope: resourceGroup
  params: {
    sku: 'PerGB2018'
    retentionInDays: 30
  }
  // This dependency is only added to attempt to solve a timing issue.
  // Identities sometimes list as completed but can't be used yet.
  dependsOn: [
    clusterIdentity
  ]
}

// Create Virtual Network
module vnet 'modules/azure_vnet.bicep' = {
  name: 'azure_vnet'
  scope: resourceGroup
  params: {
    principalId: clusterIdentity.outputs.principalId
    workspaceId: logAnalytics.outputs.Id
  }
  dependsOn: [
    clusterIdentity
    logAnalytics
  ]
}

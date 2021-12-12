targetScope = 'resourceGroup'

@description('User Managed Identity Name.')
param name string

@description('User Managed Identity Location.')
param location string = resourceGroup().location

@description('Tags.')
param tags object = {}

@description('Enable lock to prevent accidental deletion')
param enableDeleteLock bool = false

// Create User Identities
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: name
  location: location
  tags: tags
}

resource lock 'Microsoft.Authorization/locks@2016-09-01' = if (enableDeleteLock) {
  scope: managedIdentity

  name: '${managedIdentity.name}-lock'
  properties: {
    level: 'CanNotDelete'
  }
}

output resourceId string = managedIdentity.id
output principalId string = managedIdentity.properties.principalId

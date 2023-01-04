@description('Specify the Azure region to place the application definition.')
param location string = resourceGroup().location

@description('Specify the resource lock being used for the managed application')
@allowed([
  'ReadOnly'
  'CanNotDelete'
])
param lockLevel string = 'ReadOnly'

@description('Specify the User or Group Id.')
param groupId string

@description('Version to deploy. ie: 0.1.0')
param version string



// This is the naming information for the managed application
var appDescription = 'Elastic Search'
var name = 'ElasticSearch'
var displayName = 'Elastic Search'


// This is the Owner Role
var roleDefinitionId = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
var packageFileUri = 'https://github.com/danielscholl/aks-elastic/releases/download/v${version}/ama.zip'

var authorizations = [
  {
    principalId: groupId
    roleDefinitionId: roleDefinitionId
  }
]

resource name_resource 'Microsoft.Solutions/applicationDefinitions@2021-07-01' = {
  name: name
  location: location
  properties: {
    lockLevel: lockLevel
    authorizations: array(authorizations)
    description: appDescription
    displayName: displayName
    packageFileUri: packageFileUri
  }
}

output managedApplicationName string = name
output lockLevel string = lockLevel
output packageFileUri string = packageFileUri

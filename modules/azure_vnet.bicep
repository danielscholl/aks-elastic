targetScope = 'resourceGroup'

@description('Resource Name.')
param name string = '${resourceGroup().name}-vnet'

@description('Resource Location.')
param location string = resourceGroup().location

@description('Resource Tags (Optional).')
param tags object = {}

@description('Enable lock to prevent accidental deletion')
param enableDeleteLock bool = false

@description('Specify Identity to provide Network Contributor Role Access (Optional).')
param principalId string = 'null'

@description('Specify Log Workspace to Enable Diagnostics (Optional).')
param workspaceId string = 'null'

@description('Virtual Network Address CIDR')
param addressPrefix string = '10.50.0.0/16'

@description('Internal Load Balancer Address CIDR')
param ingressSubnet string = '10.50.1.0/24'

@description('Firewall Subnet 4 CIDR')
param egressSubnet string = '10.50.2.0/24'

@description('Azure PaaS Services Subnet 4 CIDR')
param serviceSubnet string = '10.50.3.0/24'

@description('Bastion Subnet CIDR')
param bastionSubnet string = '10.50.4.0/24'

@description('AKS Subnet Address CIDR')
param clusterSubnet string = '10.50.5.0/24'

@description('Pod Subnet Address CIDR')
param podSubnet string = '10.50.6.0/24'

@description('Firewall NextHop')
param egressSubnetNextHop string = '10.50.2.4'

// Define Variables
var networkContributorRole = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7'
var ingressSubnetName = 'IngressSubnet'
var egressSubnetName = 'AzureFirewallSubnet'
var bastionSubnetName = 'AzureBastionSubnet'
var serviceSubnetName = 'AzureServiceSubnet'
var clusterSubnetName = 'ClusterSubnet'
var podSubnetName = 'PodSubnet'

// Create a Route Table for Outbound Egress
resource routeTable 'Microsoft.Network/routeTables@2021-02-01' = {
  name: '${clusterSubnetName}-udr'
  location: location
  tags: tags
  properties: {
    routes: [
      {
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: egressSubnetNextHop
        }
        name: 'defaultRoute'
      }
    ]
    disableBgpRoutePropagation: true
  }
}

// Create a Network Security Group with Rules for the Bastion Subnet
resource bastionSubnetNsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${bastionSubnetName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowHttpsInBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'Internet'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowGatewayManagerInBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'GatewayManager'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowLoadBalancerInBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowBastionHostCommunicationInBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 130
          direction: 'Inbound'
        }
      }
      {
        name: 'DenyAllInBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowSshRdpOutBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRanges: [
            '22'
            '3389'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 100
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowAzureCloudCommunicationOutBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '443'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 110
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowBastionHostCommunicationOutBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
          destinationAddressPrefix: 'VirtualNetwork'
          access: 'Allow'
          priority: 120
          direction: 'Outbound'
        }
      }
      {
        name: 'AllowGetSessionInformationOutBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRanges: [
            '80'
            '443'
          ]
          access: 'Allow'
          priority: 130
          direction: 'Outbound'
        }
      }
      {
        name: 'DenyAllOutBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

// Hook up NSG Diagnostics
resource bastionSubnetDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (workspaceId != 'null') {
  name: 'diagnostics'
  scope: bastionSubnetNsg
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
  dependsOn: [
    bastionSubnetNsg
  ]
}

// Create a Network Security Group for the Service Subnet
resource serviceSubnetNsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: '${serviceSubnetName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSshInbound'
        properties: {
          priority: 100
          access: 'Allow'
          direction: 'Inbound'
          destinationPortRange: '22'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowHttpsInBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '443'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHttpInBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '80'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 120
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowAzureCloudCommunicationOutBound'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          sourceAddressPrefix: '*'
          destinationPortRange: '*'
          destinationAddressPrefix: 'AzureCloud'
          access: 'Allow'
          priority: 500
          direction: 'Outbound'
        }
      }
      {
        name: 'DenyAllOutBound'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Deny'
          priority: 1000
          direction: 'Outbound'
        }
      }
    ]
  }
}

// Hook up NSG Diagnostics
resource serviceSubnetDiagnostic 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (workspaceId != 'null') {
  name: 'service-diagnostics'
  scope: serviceSubnetNsg
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
  dependsOn: [
    serviceSubnetNsg
  ]
}

// Create a Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: ingressSubnetName
        properties: {
          addressPrefix: ingressSubnet
        }
      }
      {
        name: egressSubnetName
        properties: {
          addressPrefix: egressSubnet
        }
      }
      {
        // This Subnet is protected by a Network Security Group
        name: bastionSubnetName
        properties: {
          addressPrefix: bastionSubnet
          networkSecurityGroup: {
            id: bastionSubnetNsg.id
          }
        }
      }
      {
        // This Subnet is protected by a Network Security Group
        name: serviceSubnetName
        properties: {
          addressPrefix: serviceSubnet
          networkSecurityGroup: {
            id: serviceSubnetNsg.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: clusterSubnetName
        properties: {
          addressPrefix: clusterSubnet
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        // Pod Subnet should have traffic routed out of a Firewall.
        name: podSubnetName
        properties: {
          addressPrefix: podSubnet
          routeTable: {
            id: routeTable.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
  dependsOn: [
    routeTable
    serviceSubnetNsg
    bastionSubnetNsg
  ]
}

// Apply Resource Lock
resource lock 'Microsoft.Authorization/locks@2016-09-01' = if (enableDeleteLock) {
  scope: vnet

  name: '${vnet.name}-lock'
  properties: {
    level: 'CanNotDelete'
  }
}

// Hook up Vnet Diagnostics
resource vnetDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (workspaceId != 'null') {
  name: 'vnet-diagnostics'
  scope: vnet
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        category: 'VMProtectionAlerts'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

// Create a Network Contributor Role Assignment to the Provided Identity of the Module
resource clusterSubnetRoleAssignment 'Microsoft.Network/virtualNetworks/providers/roleAssignments@2021-04-01-preview' = if (principalId != 'null') {
  name: '${name}/Microsoft.Authorization/${guid(concat(resourceGroup().id), networkContributorRole)}'
  properties: {
    roleDefinitionId: networkContributorRole
    principalId: principalId
  }
  dependsOn: [
    vnet
  ]
}

output vnetId string = vnet.id
output ingressSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', name, ingressSubnetName)
output egressSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', name, egressSubnetName)
output bastionSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', name, bastionSubnetName)
output serviceSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', name, serviceSubnetName)
output clusterSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', name, clusterSubnetName)
output podSubnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', name, podSubnetName)

@description('Location of the Resource Group. It uses the resourceGroup\'s location when not provided.')
param location string =  resourceGroup().location


/////////////////////////////////
// Service Resources Configuration
/////////////////////////////////
var configuration = {
  name: 'instance'
  gitops: {
    url: 'https://github.com/danielscholl/aks-elastic'
    tag: 'v0.0.1'
    infra: './stamp/infra'
    apps: './stamp/apps'
  }
}

//---------Kubernetes Construction---------
module aksconst 'bicep/main.bicep' = {
  name: 'aksconstruction'
  params: {
    resourceName: configuration.name
    location : location

    // Enable Capability Monitoring
    omsagent: true
    retentionInDays: 30

    // Enable Capability Policy
    azurepolicy: 'audit'

    // Enable Upgrade
    upgradeChannel: 'node-image'

    // Enable Uptime SLA
    AksPaidSkuForSLA: true

    // Configure System Pool with CriticalAddonsOnly taint
    SystemPoolType: 'Standard'
    JustUseSystemPool: false

    // Scale Default User Pool to 0
    agentCount: 2
    agentCountMax: 3
    agentVMSize: 'Standard_DS2_v2'
    osDiskType: 'Managed'
    availabilityZones: [
      '1'
      '2'
      '3'
    ]

    // Enable Flux
    fluxGitOpsAddon: true
  }
}

module nodepool1 'bicep/aksagentpool.bicep' = {
  name: 'nodepool1'
  params: {
    AksName: aksconst.outputs.aksClusterName
    PoolName: 'espoolz1'
    agentCount: 2
    agentCountMax: 4
    availabilityZones: [
      '1'
    ]
    subnetId: ''
    nodeTaints: ['app=elasticsearch:NoSchedule']
    nodeLabels: {
      app: 'elasticsearch'
      costcenter: 'dev'
    }
  }
}
module nodepool2 'bicep/aksagentpool.bicep' = {
  name: 'nodepool2'
  params: {
    AksName: aksconst.outputs.aksClusterName
    PoolName: 'espoolz2'
    agentCount: 2
    agentCountMax: 4
    availabilityZones: [
      '2'
    ]
    subnetId: ''
    nodeTaints: ['app=elasticsearch:NoSchedule']
    nodeLabels: {
      app: 'elasticsearch'
      costcenter: 'dev'
    }
  }
}

module nodepool3 'bicep/aksagentpool.bicep' = {
  name: 'nodepool3'
  params: {
    AksName: aksconst.outputs.aksClusterName
    PoolName: 'espoolz3'
    agentCount: 2
    agentCountMax: 4
    availabilityZones: [
      '3'
    ]
    subnetId: ''
    nodeTaints: ['app=elasticsearch:NoSchedule']
    nodeLabels: {
      app: 'elasticsearch'
      costcenter: 'dev'
    }
  }
}

//--------------Flux Config---------------
module flux 'bicep/fluxConfig-InfraAndApps.bicep' = {
  name: 'flux-config'
  params: {
    aksName: aksconst.outputs.aksClusterName
    aksFluxAddOnReleaseNamespace: aksconst.outputs.fluxReleaseNamespace
    fluxConfigRepo: configuration.gitops.url
    fluxRepoInfraPath: configuration.gitops.infra
    fluxRepoAppsPath: configuration.gitops.apps
  }
  dependsOn: [
    nodepool1
    nodepool2
    nodepool3
  ]
}

output aksClusterName string = aksconst.outputs.aksClusterName

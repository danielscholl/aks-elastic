@description('Location of the Resource Group. It uses the resourceGroup\'s location when not provided.')
param location string =  resourceGroup().location


/////////////////////////////////
// Service Resources Configuration
/////////////////////////////////
var configuration = {
  name: 'instance'
  gitops: {
    name: 'sample-stamp'
    url: 'https://github.com/danielscholl/gitops-sample-stamp'
    tag: 'v0.0.1'
    path: './clusters/sample-stamp'
  }
}

//---------Kubernetes Construction---------
module aksconst 'aks-construction/bicep/main.bicep' = {
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

    // Configure System Pool with CriticalAddonsOnly taint
    SystemPoolType: 'Standard'
    JustUseSystemPool: false

    // Scale Default User Pool to 0
    agentCount: 0
    agentVMSize: 'Standard_DS2_v2'
    osDiskType: 'Managed'

    // Enable Flux
    fluxGitOpsAddon: true
  }
}

module nodepool1 'aks-construction/bicep/aksagentpool.bicep' = {
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
      purpose: 'elastic'
    }
  }
}
module nodepool2 'aks-construction/bicep/aksagentpool.bicep' = {
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
      purpose: 'elastic'
    }
  }
}

module nodepool3 'aks-construction/bicep/aksagentpool.bicep' = {
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
      purpose: 'elastic'
    }
  }
}

//--------------Flux Config---------------
module flux 'aks-construction/samples/flux/configpatterns/fluxConfig-InfraAndApps.bicep' = {
  name: 'flux'
  params: {
    aksName: aksconst.outputs.aksClusterName
    aksFluxAddOnReleaseNamespace: aksconst.outputs.fluxReleaseNamespace
    fluxConfigRepo: 'https://github.com/danielscholl/aks-elastic'
    fluxRepoInfraPath: './infrastructure'
    fluxRepoAppsPath: './apps/staging'
  }
}

output aksClusterName string = aksconst.outputs.aksClusterName

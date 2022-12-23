/*
  This is a flux GitOps Configuration for the Baseline Example
  https://github.com/mspnp/aks-baseline
*/

@description('The name of the AKS cluster.')
param aksName string

@description('The namespace for flux.')
param aksFluxAddOnReleaseNamespace string

resource aks 'Microsoft.ContainerService/managedClusters@2022-03-02-preview' existing = {
  name: aksName
}

@description('The Git Repository URL where your flux configuration is homed')
param fluxConfigRepo string

@description('The Git Repository Branch where your flux configuration is homed')
param fluxConfigRepoBranch string = ''

@description('The Git Repository Tag where your flux configuration is homed')
param fluxConfigRepoTag string = ''

@description('The name of the flux configuration to apply')
param fluxConfigName string = 'bootstrap'
var cleanFluxConfigName = toLower(fluxConfigName)

@secure()
@description('For private Repos, provide the username')
param fluxRepoUsername string = ''
var fluxRepoUsernameB64 = base64(fluxRepoUsername)

@secure()
@description('For private Repos, provide the password')
param fluxRepoPassword string = ''
var fluxRepoPasswordB64 = base64(fluxRepoPassword)

@description('The Git Repository path for manifests')
param fluxRepoPath string

resource fluxConfig 'Microsoft.KubernetesConfiguration/fluxConfigurations@2022-07-01' = {
  scope: aks
  name: cleanFluxConfigName
  properties: {
    scope: 'cluster'
    namespace: aksFluxAddOnReleaseNamespace
    sourceKind: 'GitRepository'
    gitRepository: {
      url: fluxConfigRepo
      timeoutInSeconds: 180
      syncIntervalInSeconds: 300
      repositoryRef: {
        branch: !empty(fluxConfigRepoBranch) ? fluxConfigRepoBranch : null
        tag: !empty(fluxConfigRepoTag) ? fluxConfigRepoTag : null
        semver: null
        commit: null
      }
      sshKnownHosts: ''
      httpsUser: null
      httpsCACert: null
      localAuthRef: null
    }
    configurationProtectedSettings: !empty(fluxRepoUsernameB64) && !empty(fluxRepoPasswordB64) ? {
      username: fluxRepoUsernameB64
      password: fluxRepoPasswordB64
    } : {}
    kustomizations: {
      config: {
        path: fluxRepoPath
        dependsOn: []
        timeoutInSeconds: 300
        syncIntervalInSeconds: 300
        retryIntervalInSeconds: 300
        prune: true
        force: false
      }
    }
  }
}

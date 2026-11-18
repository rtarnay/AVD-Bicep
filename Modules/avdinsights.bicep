@description('Azure region for the Log Analytics workspace.')
param location string = resourceGroup().location

@description('Name of the Azure Virtual Desktop host pool to monitor.')
param hostPoolName string

@description('Name of the Azure Virtual Desktop workspace to monitor.')
param avdWorkspaceName string

@description('Name of the dedicated Log Analytics workspace for Azure Virtual Desktop Insights.')
@minLength(4)
@maxLength(63)
param logAnalyticsWorkspaceName string

@description('Number of days to retain Log Analytics data. Longer retention increases workspace charges.')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

var hostPoolDiagnosticCategories = [
  'Management'
  'Feed'
  'Connection'
  'Error'
  'Checkpoint'
  'HostRegistration'
  'AgentHealthStatus'
]

var workspaceDiagnosticCategories = [
  'Management'
  'Feed'
  'Error'
  'Checkpoint'
]

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    retentionInDays: retentionInDays
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2025-10-10' existing = {
  name: hostPoolName
}

resource avdWorkspace 'Microsoft.DesktopVirtualization/workspaces@2025-10-10' existing = {
  name: avdWorkspaceName
}

resource hostPoolDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'avd-insights'
  scope: hostPool
  properties: {
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      for category in hostPoolDiagnosticCategories: {
        category: category
        enabled: true
      }
    ]
    workspaceId: logAnalyticsWorkspace.id
  }
}

resource workspaceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'avd-insights'
  scope: avdWorkspace
  properties: {
    logAnalyticsDestinationType: 'Dedicated'
    logs: [
      for category in workspaceDiagnosticCategories: {
        category: category
        enabled: true
      }
    ]
    workspaceId: logAnalyticsWorkspace.id
  }
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id

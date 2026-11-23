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
  'Connection'
  'Error'
  'Checkpoint'
  'HostRegistration'
  'AgentHealthStatus'
]

var workspaceDiagnosticCategories = [
  'Management'
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

var dataCollectionRuleName = 'avd-insights-${uniqueString(hostPool.id, logAnalyticsWorkspace.id)}'

resource avdInsightsDataCollectionRule 'Microsoft.Insights/dataCollectionRules@2024-03-11' = {
  name: dataCollectionRuleName
  location: location
  kind: 'Windows'
  properties: {
    dataSources: {
      performanceCounters: [
        {
          name: 'avdInsightsPerfCount30s'
          streams: [
            'Microsoft-Perf'
          ]
          samplingFrequencyInSeconds: 30
          counterSpecifiers: [
            '\\LogicalDisk(C:)\\Avg. Disk Queue Length'
            '\\LogicalDisk(C:)\\Current Disk Queue Length'
            '\\Memory\\Available Mbytes'
            '\\Memory\\Page Faults/sec'
            '\\Memory\\Pages/sec'
            '\\Memory\\% Committed Bytes In Use'
            '\\PhysicalDisk(*)\\Avg. Disk Queue Length'
            '\\PhysicalDisk(*)\\Avg. Disk sec/Read'
            '\\PhysicalDisk(*)\\Avg. Disk sec/Transfer'
            '\\PhysicalDisk(*)\\Avg. Disk sec/Write'
            '\\Processor Information(_Total)\\% Processor Time'
            '\\User Input Delay per Process(*)\\Max Input Delay'
            '\\User Input Delay per Session(*)\\Max Input Delay'
            '\\RemoteFX Network(*)\\Current TCP RTT'
            '\\RemoteFX Network(*)\\Current UDP Bandwidth'
          ]
        }
        {
          name: 'avdInsightsPerfCount60s'
          streams: [
            'Microsoft-Perf'
          ]
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            '\\LogicalDisk(C:)\\% Free Space'
            '\\LogicalDisk(C:)\\Avg. Disk sec/Transfer'
            '\\Terminal Services(*)\\Active Sessions'
            '\\Terminal Services(*)\\Inactive Sessions'
            '\\Terminal Services(*)\\Total Sessions'
          ]
        }
      ]
      windowsEventLogs: [
        {
          name: 'avdInsightsWindowsEvents'
          streams: [
            'Microsoft-Event'
          ]
          xPathQueries: [
            'Microsoft-Windows-TerminalServices-RemoteConnectionManager/Admin!*[System[(Level=2 or Level=3 or Level=4 or Level=0)]]'
            'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational!*[System[(Level=2 or Level=3 or Level=4 or Level=0)]]'
            'System!*'
            'Microsoft-FSLogix-Apps/Operational!*[System[(Level=2 or Level=3 or Level=4 or Level=0)]]'
            'Application!*[System[(Level=2 or Level=3)]]'
            'Microsoft-FSLogix-Apps/Admin!*[System[(Level=2 or Level=3 or Level=4 or Level=0)]]'
          ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: 'avdInsightsWorkspace'
          workspaceResourceId: logAnalyticsWorkspace.id
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-Perf'
        ]
        destinations: [
          'avdInsightsWorkspace'
        ]
      }
      {
        streams: [
          'Microsoft-Event'
        ]
        destinations: [
          'avdInsightsWorkspace'
        ]
      }
    ]
  }
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
output avdInsightsDataCollectionRuleId string = avdInsightsDataCollectionRule.id

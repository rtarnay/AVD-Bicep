//Host pool resource property configurations options


param location string = resourceGroup().location

@metadata({
  description: 'HostPool properties'
  friendlyName: 'HostPool Friendly Name'
  hostPoolType: 'Pooled,Personal'
  loadBalancerType: 'Persistent'
  personalDesktopAssignmentType: 'Direct,None'
  validationEnvironment: 'true,false'
  preferredAppGroupType: 'Desktop'
  publicNetworkAccess: 'Disabled'
  directUDP: 'Default'
  managedPrivateUDP: 'Default'
  publicUDP: 'Default'
  relayUDP: 'Default'
  startVMOnConnect: 'true,false'
})

param hostpoolproperties object = {
  friendlyName: hostPoolName
  description: 'Azure Virtual Desktop host pool'
  hostPoolType: hostpooltype
  loadBalancerType: 'Persistent'
  personalDesktopAssignmentType: 'Direct'
  validationEnvironment: false
  preferredAppGroupType: 'Desktop'
  publicNetworkAccess: 'Disabled'
  directUDP: 'Default'
  managedPrivateUDP: 'Default'
  publicUDP: 'Default'
  relayUDP: 'Default'
  startVMOnConnect: true
  registrationInfo: {
    expirationTime: dateTimeAdd('2026-11-20 00:00:00Z', 'P2D')
    registrationTokenOperation: 'Update'
  }
}
  

@description('Application group resource property configuration')
param applicationGroupProperties object = {
  applicationGroupType: 'Desktop'
  friendlyName: applicationGroupName
  description: 'Azure Virtual Desktop application group'
}

@description('Workspace resource property configuration')
param workspaceProperties object = {
  description: 'Azure Virtual Desktop workspace'
  friendlyName: workspaceName
  publicNetworkAccess: 'Enabled'
}


//AVD Host pool, application group and workspace parameters
@description('Host pool resource name')
param hostPoolName string

@allowed([
 'Pooled'
 'Personal'
])
@description('Host pool type can be Pooled or Personal')
param hostpooltype string
@description('Application groups resource name')
param applicationGroupName string
@description('Workspace resource name')
param workspaceName string

//Create Host Pool, Application Group and Workspace Resources
resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2025-10-10' = {
  location: location
  name: hostPoolName
  properties: hostpoolproperties
}

resource applicationGroups 'Microsoft.DesktopVirtualization/applicationGroups@2025-10-10' = {
  location: location
  name: applicationGroupName
  properties: union(applicationGroupProperties, {hostPoolArmPath: hostPool.id})
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2025-10-10' = {
  
  location: location
  name: workspaceName
  properties: union(workspaceProperties, {applicationGroupReferences: [applicationGroups.id]})
}

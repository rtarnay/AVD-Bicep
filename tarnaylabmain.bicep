
// targetScope = 'resourcegroup'  -  this is default value
// This bicep file deploys an AVD Pooled/Personal Desktop host pool. workspace and application group. It can optionally create a new virtual network and subnet for the AVD host pool. 
// If FSLogix is enabled It also deploys a storage account with a file share and private endpoint for the file share. The storage account is configured with Kerberos authentication methods, AES encryption, and a share delete retention policy. The file share is configured with an access tier of Premium, enabled protocols of SMB, and a share quota. The private endpoint is linked to a private DNS zone for the file share.

metadata deploymenttype = 'AVD Deployment - inculding host pool,networking,Azure file storage for FSLogix,Autoscale scaling plan'
metadata author = 'Robbie Tarnay'

targetScope = 'subscription'

@description('Location for all resources.')
param location string = 'australiaeast'

//Virtual network and subnet parameters
@description('Set this to true if creating a new network')
param newVirtualNetwork bool
@description('Virtual network resource name.')
param virtualNetworkName string
@description('Virtual network resource Address Space.')
param virtualNetworkAddressSpace string
@description('Virtual network resource Subnet name.')
param subnetName string
@description('Virtual network resource Subnet Address Prefix.')
param subnetAddressPrefix string


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

//Storage account and file share parameters for FLogix with Pooled host pools. 
//Also set the authentication method to AADKERB for Azure AD Kerberos or ADDS for Hybrid authentication or AD for Active Directory authentication.
@description('Set this to true if FSLogix is to be enabled')
/*Storage Account Parameters*/
param fslogixEnabled bool 
param filePrivateDnsZoneName string = 'privatelink.file.${environment().suffixes.storage}'
param filePrivateEndpointGroupName string = 'file'
param fileShareName  string = 'tarnaylabavdfileshare'
param fileShareQuota int = 100
param storageAccountName string = 'tarnaylabavd2'
@allowed([
 'AD'
 'AADKERB'
 'AADDS'
])
param authenticationMethod string = 'AADKERB'


param hostpoolproperties object = {
  friendlyName: hostPoolName
  description: 'Azure Virtual Desktop host pool'
  hostPoolType: hostpooltype
  loadBalancerType: 'Persistent'
  personalDesktopAssignmentType: 'Direct'
  validationEnvironment: false
  preferredAppGroupType: 'Desktop'
  publicNetworkAccess: 'Enabled'
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
  

//Create Resource Groups for deployment

param resourcegroups object = {
  resourceGroupName1: 'rg-avd2-controlplane'
  resourceGroupName2: 'rg-avd2-storage'
  resourceGroupName3: 'rg-avd2-networking'
   resourceGroupName4: 'rg-avd2-sessionhosts'
}

//Create resource groups
resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = [for resourceGroup in items(resourcegroups): {
  name: resourceGroup.value
  location: location
}]

resource controlplane 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: resourcegroups.resourceGroupName1
}
resource storage 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: resourcegroups.resourceGroupName2
}

resource network 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: resourcegroups.resourceGroupName3
}


//Service Principal Permissions for AVD Scaling Plan
@description('The Object ID (Principal ID) of the Azure Virtual Desktop Service Principal in your tenant.')
param avdServicePrincipalObjectId string

@description('The subscription ID where the AVD scaling plan and host pools reside.')
param subscriptionId string = subscription().id

// Built-in Role ID for 'Desktop Virtualization Power On Off Contributor'
// ID: 40c5ff49-9181-41f8-ae61-143b0e78555e
@description('Built-in Role Definition ID for Desktop Virtualization Power On Off Contributor')
param powerOnOffContributorRoleDefinitionId string = '40c5ff49-9181-41f8-ae61-143b0e78555e'


//AVD Modules for networking, hostpool, scaling plan and Azure File Storage

module networking 'Modules/Networking.bicep' = {
  name: 'networkingcomponent'
  scope:resourceGroup(network.name)
  params: {
    newVirtualNetwork: newVirtualNetwork
    subnetAddressPrefix: subnetAddressPrefix
    subnetName: subnetName
    virtualNetworkAddressSpace:virtualNetworkAddressSpace
    virtualNetworkName:virtualNetworkName
  }
  dependsOn: [
    rg
  ]
}

module hostPool 'Modules/hostpool.bicep' = {
  name: 'hostPoolComponent'
  scope: resourceGroup(controlplane.name)
  params: {
    location: location
    hostPoolName: hostPoolName
    hostpooltype: hostpooltype
    hostpoolproperties: hostpoolproperties
    applicationGroupName: applicationGroupName
    applicationGroupProperties: applicationGroupProperties
    workspaceName: workspaceName
    workspaceProperties: workspaceProperties
  }
  dependsOn: [
    rg
  ]
}

resource hostpoolpersonal 'Microsoft.DesktopVirtualization/hostPools@2025-10-10' existing = {
  name: hostPoolName
  scope: resourceGroup(controlplane.name)
}


//Scaling Plan params
param enableautoscaleplan bool 
@description('Time zone for the scaling plan, e.g., AUS Eastern Standard Time')
param timeZone string = 'AUS Eastern Standard Time'

module scalingPlan 'Modules/Scaling_Personal.bicep' = if (enableautoscaleplan) {
  name: 'scalingPlanComponent'
  scope: resourceGroup(controlplane.name)
  params: {
    location: location
    hostPoolId: hostpoolpersonal.id
    scalingPlanName: '${hostPoolName}-scalingplan'
    avdServicePrincipalObjectId: avdServicePrincipalObjectId
    powerOnOffContributorRoleDefinitionId: powerOnOffContributorRoleDefinitionId
    subscriptionId: subscriptionId
    timeZone: timeZone
  }
  dependsOn: [
    rg
    hostPool
  ]
}

//Retrieve Networking
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2026-01-01' existing = {
  name: virtualNetworkName
  scope: resourceGroup(network.name)

}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2026-01-01' existing = {
  parent: virtualNetwork
  name: subnetName
}

module storageAccount 'Modules/Storage.bicep' = if (fslogixEnabled) {
  name: 'storageAccountComponent'
  scope: resourceGroup(storage.name)
  params: {
    location: location
    storageAccountName: storageAccountName
    fileShareName: fileShareName
    fileShareQuota: fileShareQuota
    filePrivateDnsZoneName: filePrivateDnsZoneName
    virtualNetworkId: virtualNetwork.id
    subnetId: subnet.id
    filePrivateEndpointGroupName: filePrivateEndpointGroupName
    authenticationMethod: authenticationMethod
    
  }
  dependsOn: [
    rg
    networking
  ]
}

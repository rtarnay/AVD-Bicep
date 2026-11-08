using 'tarnaylabmain.bicep'

var environment = 'test'

/*Network Parameters*/
param newVirtualNetwork  = true
param virtualNetworkName = 'tarnaylab-vnet-avd2'
param virtualNetworkAddressSpace = '192.168.20.0/23'
param subnetName = 'tarnaylab-vnet-subnet1-avd2'
param subnetAddressPrefix = '192.168.21.0/24'

/*Host Pool Parameters*/
param hostPoolName  = 'avd-${environment}-personal-hostPool'
param applicationGroupName  = 'avd-${environment}-personal-desktop'
param workspaceName  = 'avd-${environment}-workspace'
param hostpooltype  = 'Personal'

//enable Storage Account for FSLogix
param fslogixEnabled = true

//Scaling Plan Details
param enableautoscaleplan = true
param avdServicePrincipalObjectId  = 'b827c2c6-050b-4533-ae45-13a656bd6e06'
param subscriptionId = 'add28662-fd96-4fb4-9a1f-2c47e0005245'




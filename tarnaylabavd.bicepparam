using 'tarnaylabmain.bicep'

var environment = 'test'

/*Network Parameters*/
param newVirtualNetwork  = true
param virtualNetworkName = 'tarnaylab-vnet-avd2'
param virtualNetworkAddressSpace = '192.168.20.0/23'
param subnetName = 'tarnaylab-vnet-subnet1-avd'
param subnetAddressPrefix = '192.168.20.0/24'
param privateEndpointSubnetName = 'tarnaylab-vnet-private-endpoints-avd'
param privateEndpointSubnetAddressPrefix = '192.168.21.0/24'

/*Host Pool Parameters*/
param hostPoolName  = 'avd-${environment}-personal-hostPool'
param applicationGroupName  = 'avd-${environment}-personal-desktop'
param workspaceName  = 'avd-${environment}-workspace'
param logAnalyticsWorkspaceName = 'avd-${environment}-law'
param hostpooltype  = 'Personal'

//enable Storage Account for FSLogix
param fslogixEnabled = true

//enable monitoring
param enablemonitoring = true

//Scaling Plan Details
param enableautoscaleplan = true



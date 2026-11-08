
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


//Create Networking Resources
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2026-01-01' = if(newVirtualNetwork) {
  name: virtualNetworkName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [virtualNetworkAddressSpace]
    }
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2026-01-01' = if(newVirtualNetwork) {
  parent: virtualNetwork
  name: subnetName
  properties: {
    addressPrefix: subnetAddressPrefix
    privateEndpointNetworkPolicies: 'Enabled'
    defaultOutboundAccess:true
  }
}

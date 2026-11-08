targetScope = 'subscription'
param location string = 'australiaeast'

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

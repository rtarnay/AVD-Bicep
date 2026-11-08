
param location string = resourceGroup().location

param artifactsLocation string 
param numberOfSessionHost int 
@secure()
param adminUsername string
@secure()
param adminPassword string
@secure()
param hostPoolRegistrationInfoToken string


var environment = 'test'

//Existing Resources 
resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2025-10-10' existing = {
  name: 'avd-${environment}-personal-hostPool'
 
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2026-01-01' existing = {  
  name: 'TARNAYLAB-VNET-AVD2/TARNAYLAB-VNET-SUBNET1-AVD2'
}



@description('Virtual machine resource object')
var virtualMachine = {
  name: 'azurevm'
  licenseType: 'Windows_Client'
  vmSize: 'Standard_D2ls_v5'
  osDisk: {
    createOption: 'FromImage'
    storageAccountType: 'Premium_LRS'
    deleteOption: 'Delete'
  }
  imageReference: {
    publisher: 'microsoftwindowsdesktop'
    offer: 'office-365'
    sku: 'win11-23h2-avd-m365'
    version: 'latest'
  }
}



resource networkInterface 'Microsoft.Network/networkInterfaces@2026-01-01' = [for i in range(0, numberOfSessionHost) : {
  location: location
  name: '${virtualMachine.name}-nic${i + 1}'
  properties: {
    enableAcceleratedNetworking: true
    ipConfigurations: [
      {
        name: 'ipConfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet.id
          }
         
        }
      }
    ]
  }
}]

resource vms 'Microsoft.Compute/virtualMachines@2026-04-01' = [for i in range(0, numberOfSessionHost) : {
  location: location
  name: '${virtualMachine.name}${i + 1}'
  properties: {
    licenseType: virtualMachine.licenseType
    hardwareProfile: {
      vmSize: virtualMachine.vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: virtualMachine.osDisk.createOption
        managedDisk: {
          storageAccountType: virtualMachine.osDisk.storageAccountType
        }
        deleteOption: virtualMachine.osDisk.deleteOption
      }
      imageReference: {
        publisher: virtualMachine.imageReference.publisher
        offer: virtualMachine.imageReference.offer
        sku: virtualMachine.imageReference.sku
        version: virtualMachine.imageReference.version
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface[i].id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    additionalCapabilities: {
      hibernationEnabled: false
    }
    osProfile: {
      computerName: '${virtualMachine.name}${i + 1}'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}]

resource entraIdJoin 'Microsoft.Compute/virtualMachines/extensions@2026-04-01' = [for i in range(0, numberOfSessionHost) :  {
  parent: vms[i]
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: false
  }
}]

resource dcs 'Microsoft.Compute/virtualMachines/extensions@2026-04-01' = [for i in range(0, numberOfSessionHost) : {
  parent: vms[i]
  name: 'MicrosoftPowershellDSC'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.83'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: artifactsLocation
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostPool.name
        aadJoin: true
      }
    }
    protectedSettings: {
      properties: {
        registrationInfoToken: hostPoolRegistrationInfoToken
      }
    }
  }
  dependsOn: [
    entraIdJoin
  ]
}]

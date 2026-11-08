param location string = 'AustraliaEast'

param storageAccountName string 
param fileShareName string 
param fileShareQuota int 
param filePrivateDnsZoneName string
param virtualNetworkId string 
param subnetId string 
param filePrivateEndpointGroupName string 
param authenticationMethod string 


resource storageAccount 'Microsoft.Storage/storageAccounts@2026-06-01' =  {
  name: toLower(storageAccountName)
  location: location
  sku: {
    name: 'Premium_LRS'
  }
  kind: 'FileStorage'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
      azureFilesIdentityBasedAuthentication: {
    directoryServiceOptions: authenticationMethod
    // AD also requires activeDirectoryProperties.
  }
    
  }
}


resource fileShareService 'Microsoft.Storage/storageAccounts/fileServices@2026-06-01' = {
  parent: storageAccount
  name: 'default'
  properties: {

    protocolSettings: {
      smb: {
        authenticationMethods: 'Kerberos'
        channelEncryption: 'AES-128-CCM;AES-128-GCM;AES-256-GCM'
        kerberosTicketEncryption: 'AES-256'
        versions: 'SMB3.0;SMB3.1.1'
       
      }
    
    }
    // Retain deleted file shares for 7 days to allow recovery; permanent delete is disabled for safety.
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2026-06-01' = {
  parent: fileShareService
  name: toLower(fileShareName)
  properties: {
    accessTier: 'Premium'
    enabledProtocols: 'SMB'
    shareQuota: fileShareQuota
  }

}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: filePrivateDnsZoneName
  location: 'global'
}

resource privateDnsZoneNameVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  name: 'link_to_${toLower(split(virtualNetworkId, '/')[8])}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2026-01-01' = {
  name: '${storageAccount.name}-file-pe'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: '${storageAccount.name}-file-pe'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            filePrivateEndpointGroupName
          ]
        }
      }
    ]
    subnet: {
      id: subnetId

    }
  }
}

resource PrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2026-01-01' = {
  parent: privateEndpoint
  name: filePrivateEndpointGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'dnsConfig'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}



output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
output fileShareName string = fileShare.name


param numberOfSessionHost int = 1
param subscriptionId string = 'add28662-fd96-4fb4-9a1f-2c47e0005245'
param kvResourceGroup string = 'RG-AVD2'
param kvName string = 'kv-avd-tarnaylab'
param artifactsLocation string = 'https://wvdportalstorageblob.blob.${environment().suffixes.storage}/galleryartifacts/Configuration_1.0.02774.414.zip'

resource kv 'Microsoft.KeyVault/vaults@2025-05-01' existing = {
  name: kvName
  scope: resourceGroup(subscriptionId, kvResourceGroup )
}


module sessionhost './sessionhost.bicep' = {
  name: 'deploysessionhost'
  params: {
    artifactsLocation: artifactsLocation
    hostPoolRegistrationInfoToken: kv.getSecret('registrationkey')
    numberOfSessionHost: numberOfSessionHost
    adminUsername: kv.getSecret('vmadminusername')
    adminPassword: kv.getSecret('vmadminpassword')
  }
}

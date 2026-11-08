
resource kv 'Microsoft.KeyVault/vaults@2026-05-15' = {

	name: 'kv-avd-tarnaylab'
	location: resourceGroup().location
	properties: {
		tenantId: tenant().tenantId
		sku: {
			family: 'A'
			name: 'standard'
		}
        enableRbacAuthorization:true
        enabledForTemplateDeployment:true
	}

}

// Create a secret outside of key vault definition
resource secret1 'Microsoft.KeyVault/vaults/secrets@2026-05-15' = {
  name: 'vmadminusername'
  parent: kv  // Pass key vault symbolic name as parent
  properties: {
    value: ''
  }
  
}


// Create a secret outside of key vault definition
resource secret2 'Microsoft.KeyVault/vaults/secrets@2026-05-15' = {
  name: 'vmadminpassword'
  parent: kv  // Pass key vault symbolic name as parent
  properties: {
    value: ''
  }
  
}

// Create a secret outside of key vault definition
resource secret3 'Microsoft.KeyVault/vaults/secrets@2026-05-15' = {
  name: 'registrationkey'
  parent: kv  // Pass key vault symbolic name as parent
  properties: {
    value: ''
  }
  
}

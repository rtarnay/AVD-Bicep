# Azure Files Storage Module — IaC Specification

## Purpose and scope

This specification describes the Azure Files storage module implemented in [`storage.bicep`](./storage.bicep). It is intended both to explain the current configuration and to provide a reusable source specification for recreating or adapting the Bicep module.

The module deploys an Azure Files share for AVD/FSLogix, secures it with a private endpoint, and configures private DNS for the supplied virtual network. It does not create an AVD host pool, session hosts, virtual network, or subnet.

## Inputs

| Parameter | Type | Current default | Description |
|---|---|---|---|
| `location` | `string` | `AustraliaEast` | Region for the storage account and private endpoint. |
| `storageAccountName` | `string` | Required | Storage account name; converted to lowercase. Must satisfy Azure Storage naming rules. |
| `fileShareName` | `string` | Required | Name of the Azure file share; converted to lowercase. |
| `fileShareQuota` | `int` | Required | File share quota in GiB. |
| `filePrivateDnsZoneName` | `string` | Required | Private DNS zone name for Azure Files, normally `privatelink.file.<storage DNS suffix>`. |
| `virtualNetworkId` | `string` | Required | Resource ID of the VNet to link to the private DNS zone. |
| `subnetId` | `string` | Required | Resource ID of the subnet hosting the private endpoint. |
| `filePrivateEndpointGroupName` | `string` | Required | Private Link subresource/group ID, normally `file`. Also used as the DNS zone group name. |
| `authenticationMethod` | `string` | Required | Azure Files identity-based authentication mode, such as `AADKERB`, `AADDS`, or `AD`. Active Directory modes may require additional directory configuration. |

The calling deployment currently supplies these values and conditionally deploys this module when FSLogix storage is enabled. Keep the module resource-group scoped so the caller can deploy it to the storage resource group.

## Resources and configuration

### Storage account

- Resource type: `Microsoft.Storage/storageAccounts`
- API version: `2026-06-01`
- Kind: `FileStorage`
- SKU: `Premium_LRS`
- Access tier: `Hot`
- Blob public access: disabled
- HTTPS-only traffic: enabled
- Minimum TLS: `TLS1_2`
- Network ACL default action: `Deny`; Azure services bypass is enabled
- Azure Files identity-based authentication uses the `authenticationMethod` input.

### Azure Files service

- Resource type: `Microsoft.Storage/storageAccounts/fileServices`
- API version: `2026-06-01`
- Child service name: `default`
- SMB authentication: `Kerberos`
- SMB channel encryption: `AES-128-CCM;AES-128-GCM;AES-256-GCM`
- Kerberos ticket encryption: `AES-256`
- SMB versions: `SMB3.0;SMB3.1.1`
- Soft-delete retention for file shares: enabled for 7 days.

### File share

- Resource type: `Microsoft.Storage/storageAccounts/fileServices/shares`
- API version: `2026-06-01`
- Share name: lowercase `fileShareName`
- Protocol: `SMB`
- Access tier: `Premium`
- Quota: `fileShareQuota`

### Private DNS

- Private DNS zone resource type: `Microsoft.Network/privateDnsZones`
- API version: `2024-06-01`
- Location: `global`
- Zone name: `filePrivateDnsZoneName`
- VNet link resource type: `Microsoft.Network/privateDnsZones/virtualNetworkLinks`
- API version: `2024-06-01`
- Link registration: disabled
- VNet: the resource ID supplied in `virtualNetworkId`

The VNet link name is generated as:

```bicep
'link_to_${toLower(split(virtualNetworkId, '/')[8])}'
```

This assumes `virtualNetworkId` is a standard VNet resource ID, for example:

```text
/subscriptions/<subscription-id>/resourceGroups/<resource-group>/providers/Microsoft.Network/virtualNetworks/<vnet-name>
```

Splitting that ID on `/` places the VNet name at index `8`; the name is lowercased and prefixed with `link_to_`. Pass the VNet resource ID, not a subnet ID, to this input.

### Private endpoint and DNS zone group

- Private endpoint resource type: `Microsoft.Network/privateEndpoints`
- API version: `2026-01-01`
- Endpoint name: `<lowercase-storage-account-name>-file-pe`
- Target: the storage account
- Group ID: `filePrivateEndpointGroupName`
- Subnet: `subnetId`
- Private DNS zone group resource type: `Microsoft.Network/privateEndpoints/privateDnsZoneGroups`
- API version: `2026-01-01`
- Zone group name: `filePrivateEndpointGroupName`
- DNS configuration references the created private DNS zone.

## Outputs

| Output | Value |
|---|---|
| `storageAccountName` | Deployed storage account name. |
| `storageAccountId` | Storage account resource ID. |
| `fileShareName` | Deployed file share name. |

## Reusable implementation instructions

Use this specification to recreate or update `storage.bicep` with the following requirements:

1. Define the inputs listed above, preserving the `location` default and requiring all other values unless the caller provides explicit defaults.
2. Deploy one Premium Azure Files storage account, its default file service, and one SMB file share with the settings described here.
3. Configure identity-based authentication from `authenticationMethod`; do not silently invent Active Directory properties that are not supplied by the caller.
4. Create the private DNS zone, a non-registering VNet link, a private endpoint in the provided subnet, and a private DNS zone group that associates the endpoint with that zone.
5. Derive the VNet link name from segment index `8` of the supplied standard VNet resource ID and lowercase it. Keep the assumption explicit; do not parse a subnet ID as though it were a VNet ID.
6. Preserve the API versions recorded above unless a newer stable, non-preview version is deliberately selected and validated for the resource type.
7. Preserve the three outputs and use Bicep parent/resource references for child resources.
8. Do not add host pool, session host, VNet, subnet, or FSLogix profile configuration; those belong to other deployment modules.
9. Keep security defaults restrictive: blob public access off, HTTPS required, TLS 1.2 minimum, and storage network ACL default action set to deny.
10. Validate the recreated module with `bicep build Modules/storage.bicep`.

## Caller example

The parent deployment passes the existing VNet and subnet IDs into this module and deploys it to the storage resource group. A representative module parameter block is:

```bicep
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
```

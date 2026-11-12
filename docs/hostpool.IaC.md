# Azure Virtual Desktop Host Pool Module — IaC Specification

## Purpose and scope

This specification describes the configuration in [`hostpool.bicep`](./hostpool.bicep). It is both a description of the current module and a reusable guide for recreating or adapting it.

The module deploys three related Azure Virtual Desktop resources: a host pool, an application group associated with that pool, and a workspace associated with that application group. It does not deploy session host virtual machines, networking, storage, scaling plans, or role assignments.

## Deployment scope and inputs

The module is deployed at resource-group scope. The parent deployment currently targets the control-plane resource group and supplies the values below.

| Parameter | Type | Default / allowed values | Purpose |
|---|---|---|---|
| `location` | `string` | `resourceGroup().location` | Azure region for all three resources. |
| `hostPoolName` | `string` | Required | Host pool resource name. |
| `hostpooltype` | `string` | `Pooled` or `Personal` | Host pool type. |
| `applicationGroupName` | `string` | Required | Application group resource name. |
| `workspaceName` | `string` | Required | Workspace resource name. |
| `hostpoolproperties` | `object` | See defaults below | Host pool configuration object. |
| `applicationGroupProperties` | `object` | See defaults below | Application group configuration object. |
| `workspaceProperties` | `object` | See defaults below | Workspace configuration object. |

### Host pool property defaults

The default `hostpoolproperties` object is:

| Property | Default |
|---|---|
| `friendlyName` | `hostPoolName` |
| `description` | `Azure Virtual Desktop host pool` |
| `hostPoolType` | `hostpooltype` |
| `loadBalancerType` | `Persistent` |
| `personalDesktopAssignmentType` | `Direct` |
| `validationEnvironment` | `false` |
| `preferredAppGroupType` | `Desktop` |
| `publicNetworkAccess` | `Disabled` |
| `directUDP` | `Default` |
| `managedPrivateUDP` | `Default` |
| `publicUDP` | `Default` |
| `relayUDP` | `Default` |
| `startVMOnConnect` | `true` |
| `registrationInfo.registrationTokenOperation` | `Update` |
| `registrationInfo.expirationTime` | `dateTimeAdd('2026-11-20 00:00:00Z', 'P2D')` (2026-11-22 UTC) |

The registration token expiration is currently a fixed date expression. For reusable deployments, make the expiry an input or calculate it from the deployment time in the parent template; do not retain an expired hard-coded date. The token operation is `Update`.

The current default combines `personalDesktopAssignmentType: 'Direct'` with an input that permits either `Pooled` or `Personal`. When recreating the module, ensure pool-specific properties are compatible with the selected host pool type; use the appropriate assignment setting for the chosen type rather than applying a personal-only property indiscriminately.

### Application group property defaults

| Property | Default |
|---|---|
| `applicationGroupType` | `Desktop` |
| `friendlyName` | `applicationGroupName` |
| `description` | `Azure Virtual Desktop application group` |

The module adds `hostPoolArmPath` from the created host pool resource ID. Because Bicep `union()` combines objects, that reference is included even when callers provide their own application-group properties.

### Workspace property defaults

| Property | Default |
|---|---|
| `description` | `Azure Virtual Desktop workspace` |
| `friendlyName` | `workspaceName` |
| `publicNetworkAccess` | `Enabled` |

The module adds `applicationGroupReferences` containing the created application group's resource ID. This reference is included when caller-supplied workspace properties are combined with `union()`.

## Resources and relationships

### Host pool

- Resource type: `Microsoft.DesktopVirtualization/hostPools`
- API version: `2025-10-10`
- Resource name: `hostPoolName`
- Location: `location`
- Properties: `hostpoolproperties`

### Application group

- Resource type: `Microsoft.DesktopVirtualization/applicationGroups`
- API version: `2025-10-10`
- Resource name: `applicationGroupName`
- Location: `location`
- Properties: `applicationGroupProperties` combined with `hostPoolArmPath: hostPool.id`
- Relationship: associated with the host pool created by this module.

### Workspace

- Resource type: `Microsoft.DesktopVirtualization/workspaces`
- API version: `2025-10-10`
- Resource name: `workspaceName`
- Location: `location`
- Properties: `workspaceProperties` combined with `applicationGroupReferences: [applicationGroups.id]`
- Relationship: registers the application group created by this module in the workspace.

Bicep symbolic references establish deployment dependencies: the application group depends on the host pool, and the workspace depends on the application group.

## Outputs

The current module declares no outputs. If the caller needs resource IDs, add explicit outputs for the host pool, application group, and workspace rather than reconstructing their IDs externally.

## Reusable implementation requirements

When using this specification to recreate or update `hostpool.bicep`:

1. Keep the module resource-group scoped and limited to the host pool, application group, and workspace.
2. Keep resource names, location, host pool type, and property objects as inputs.
3. Restrict `hostpooltype` to `Pooled` or `Personal`.
4. Ensure host-pool-type-specific properties are compatible with the selected type.
5. Associate the application group with the host pool using the host pool's resource ID.
6. Associate the workspace with the application group using its resource ID.
7. Preserve the current default network access settings unless explicitly changed: host pool `Disabled`, workspace `Enabled`.
8. Replace the fixed registration expiry with a deployment-appropriate value or parameter and ensure it is in the future when the host pool is deployed.
9. Use stable, non-preview API versions. The current module uses `2025-10-10` for all three resource types; verify availability before regenerating.
10. Keep caller-provided property objects extensible while always injecting the resource relationships. The current implementation does this with `union()`.
11. Consider adding outputs for resource IDs when needed by dependent modules.
12. Validate the recreated module with `bicep build Modules/hostpool.bicep`.

## Caller example

The parent deployment passes the host pool and resource names, and may override any property object:

```bicep
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
}
```

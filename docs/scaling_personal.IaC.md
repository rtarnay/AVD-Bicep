# Personal AVD Scaling Plan — IaC Specification

## Purpose and scope

This specification describes the personal-host-pool autoscale module in [`scaling_personal.bicep`](./scaling_personal.bicep). It is intended to explain the current configuration and provide a reusable specification for recreating or adapting the Bicep file.

The module deploys an Azure Virtual Desktop scaling plan for a personal host pool, associates the pool with the plan, creates a weekday personal schedule, and assigns the AVD service principal the Desktop Virtualization Power On Off Contributor role. It does not deploy the host pool, session hosts, workspace, application group, or networking.

## Inputs

| Parameter | Type | Default | Description |
|---|---|---|---|
| `scalingPlanName` | `string` | Required | Name and friendly name of the scaling plan. |
| `location` | `string` | `resourceGroup().location` | Azure region for the scaling plan; use a region compatible with the host pool. |
| `timeZone` | `string` | `AUS Eastern Standard Time` | Windows time zone used to interpret schedule times. |
| `hostPoolId` | `string` | Required | ARM resource ID of the personal host pool to associate. |
| `avdServicePrincipalObjectId` | `string` | Required | Tenant service principal object/principal ID used by AVD autoscale. |
| `subscriptionId` | `string` | `subscription().id` | Subscription ID included in the deterministic role assignment name. |
| `powerOnOffContributorRoleDefinitionId` | `string` | `40c5ff49-9181-41f8-ae61-143b0e78555e` | Built-in Desktop Virtualization Power On Off Contributor role definition ID. |

The consuming deployment currently invokes this module conditionally when autoscaling is enabled, deploys it to the host pool's control-plane resource group, and passes the host pool resource ID and AVD service principal object ID.

## Resources

### Role assignment

- Resource type: `Microsoft.Authorization/roleAssignments`
- API version: `2022-04-01`
- Role: Desktop Virtualization Power On Off Contributor, supplied by `powerOnOffContributorRoleDefinitionId`
- Principal: `avdServicePrincipalObjectId`, with principal type `ServicePrincipal`
- Role definition ID is built with `subscriptionResourceId`.
- Assignment name is deterministic: `guid(subscriptionId, avdServicePrincipalObjectId, powerOnOffContributorRoleDefinitionId)`.
- The assignment is deployed at the module's deployment scope. Deploy the module at the intended authorization scope and ensure the deployment identity is permitted to create role assignments there.

### Scaling plan

- Resource type: `Microsoft.DesktopVirtualization/scalingPlans`
- API version: `2025-10-10`
- Name and friendly name: `scalingPlanName`
- Host pool type: `Personal`
- Time zone: `timeZone`
- Description: weekday autoscale plan for a personal AVD host pool
- Exclusion tag: `MaintenanceWindow`
- Associates `hostPoolId` and enables scaling for that host pool.

### Personal weekday schedule

- Resource type: `Microsoft.DesktopVirtualization/scalingPlans/personalSchedules`
- API version: `2025-10-10`
- Child of the scaling plan
- Name: `AVD AutoScale - Weekly Personal AVD Desktop`
- Active days: Monday through Friday
- Unspecified weekend days retain the prior/off-peak settings; no Saturday or Sunday schedule is defined.

All times below are interpreted in the scaling plan's configured `timeZone`:

| Phase | Start | Start VM on connect | Assigned-user auto start | Disconnect action | Wait on disconnect | Logoff action | Wait on logoff |
|---|---:|---|---|---|---:|---|---:|
| Ramp-up | 08:00 | Enabled | `WithAssignedUser` | None | Not configured | Deallocate | 15 minutes |
| Peak | 09:00 | Enabled | Not configured | None | Not configured | Deallocate | 15 minutes |
| Ramp-down | 17:00 | Enabled | Not configured | Deallocate | 60 minutes | Deallocate | 15 minutes |
| Off-peak | 19:00 | Enabled | Not configured | Deallocate | 60 minutes | Deallocate | 15 minutes |

“Not configured” means the corresponding property is not present in the Bicep schedule, rather than an explicitly supplied value.

## Output

| Output | Value |
|---|---|
| `scalingPlanId` | ARM resource ID of the deployed scaling plan. |

## Reusable implementation requirements

When using this specification to recreate or update the Bicep module:

1. Keep the module resource-group scoped unless there is a specific requirement to deploy at another supported scope.
2. Preserve the input parameters and defaults above, and pass the actual personal host pool ARM ID.
3. Create the AVD service principal role assignment with the specified built-in role and principal type. Avoid hard-coding a tenant-specific principal object ID.
4. Create a `Personal` scaling plan and associate the supplied host pool with `scalingPlanEnabled: true`.
5. Create one personal schedule with the specified weekdays and phase settings. Preserve the order and configured start times of ramp-up, peak, ramp-down, and off-peak.
6. Interpret schedule times using the `timeZone` input; callers should supply the appropriate Windows time zone for their deployment.
7. Leave weekend days unspecified unless weekend autoscaling behavior is explicitly required.
8. Use stable, non-preview API versions. The current module uses `2022-04-01` for role assignments and `2025-10-10` for both scaling-plan resource types; verify availability before regenerating.
9. Keep the `scalingPlanId` output and reference resources through Bicep symbolic names/parent relationships.
10. Validate a recreated module with `bicep build Modules/scaling_personal.bicep`.

## Caller example

The parent deployment can invoke the module conditionally and pass its existing host pool:

```bicep
module scalingPlan 'Modules/scaling_personal.bicep' = if (enableautoscaleplan) {
  name: 'scalingPlanComponent'
  scope: resourceGroup(controlplane.name)
  params: {
    location: location
    hostPoolId: hostpoolpersonal.id
    scalingPlanName: '${hostPoolName}-scalingplan'
    avdServicePrincipalObjectId: avdServicePrincipalObjectId
    powerOnOffContributorRoleDefinitionId: powerOnOffContributorRoleDefinitionId
    subscriptionId: subscriptionId
    timeZone: timeZone
  }
}
```

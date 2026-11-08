metadata name = 'ScalingPlan Module for Personal Host Pools'
metadata description = 'Deploys an autoscale plan and weekday schedule for an Azure Virtual Desktop personal host pool.'
metadata version = '1.0.0'
metadata author = 'Robbie Tarnay'

@description('Name of the scaling plan.')
param scalingPlanName string

@description('Azure region for the scaling plan. Use the same region as the host pool.')
param location string = resourceGroup().location

@description('Windows time zone ID used to evaluate the schedule.')
param timeZone string = 'AUS Eastern Standard Time'

@description('Resource ID of the personal host pool to associate with this plan.')
param hostPoolId string

//Service Principal Permissions for AVD Scaling Plan
@description('The Object ID (Principal ID) of the Azure Virtual Desktop Service Principal in your tenant.')
param avdServicePrincipalObjectId string

@description('The subscription ID where the AVD scaling plan and host pools reside.')
param subscriptionId string = subscription().id

// Built-in Role ID for 'Desktop Virtualization Power On Off Contributor'
// ID: 40c5ff49-9181-41f8-ae61-143b0e78555e
@description('Built-in Role Definition ID for Desktop Virtualization Power On Off Contributor')
param powerOnOffContributorRoleDefinitionId string = '40c5ff49-9181-41f8-ae61-143b0e78555e'
//AVD PowerOnOffRoleAssignment
resource avdPowerOnOffRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscriptionId, avdServicePrincipalObjectId, powerOnOffContributorRoleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', powerOnOffContributorRoleDefinitionId)
    principalId: avdServicePrincipalObjectId
    principalType: 'ServicePrincipal'
  }
}


resource scalingPlan 'Microsoft.DesktopVirtualization/scalingPlans@2025-10-10' = {
  name: scalingPlanName
  location: location
  properties: {
    friendlyName: scalingPlanName
    description: 'Weekday autoscale plan for an Azure Virtual Desktop personal host pool.'
    hostPoolType: 'Personal'
    timeZone: timeZone
    exclusionTag: 'MaintenanceWindow'
    hostPoolReferences: [
      {
        hostPoolArmPath: hostPoolId
        scalingPlanEnabled: true
      }
    ]
  }
}

resource weekdaySchedule 'Microsoft.DesktopVirtualization/scalingPlans/personalSchedules@2025-10-10' = {
  parent: scalingPlan
  name: 'AVD AutoScale - Weekly Personal AVD Desktop'
  properties: {
    // Unscheduled weekend days retain the previous off-peak settings.
    daysOfWeek: [
      'Monday'
      'Tuesday'
      'Wednesday'
      'Thursday'
      'Friday'
    ]
    rampUpStartTime: {
      hour: 8
      minute: 0
    }
    rampUpAutoStartHosts: 'WithAssignedUser'
    rampUpStartVMOnConnect: 'Enable'
    rampUpActionOnDisconnect: 'None'
    rampUpMinutesToWaitOnLogoff: 15
    rampUpActionOnLogoff: 'Deallocate'
    peakStartTime: {
      hour: 9
      minute: 0
    }
    peakStartVMOnConnect: 'Enable'
    peakActionOnDisconnect: 'None'
    peakMinutesToWaitOnLogoff: 15
    peakActionOnLogoff: 'Deallocate'
    rampDownStartTime: {
      hour: 17
      minute: 0
    }
    rampDownStartVMOnConnect: 'Enable'
    rampDownMinutesToWaitOnDisconnect: 60
    rampDownActionOnDisconnect: 'Deallocate'
    rampDownMinutesToWaitOnLogoff: 15
    rampDownActionOnLogoff: 'Deallocate'
    offPeakStartTime: {
      hour: 19
      minute: 0
    }
    offPeakStartVMOnConnect: 'Enable'
    offPeakMinutesToWaitOnDisconnect: 60
    offPeakActionOnDisconnect: 'Deallocate'
    offPeakMinutesToWaitOnLogoff: 15
    offPeakActionOnLogoff: 'Deallocate'
  }
}

output scalingPlanId string = scalingPlan.id

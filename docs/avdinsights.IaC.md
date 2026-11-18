# Azure Virtual Desktop Insights — IaC

## What this deploys

The `modules/avdinsights.bicep` module creates a dedicated pay-as-you-go Log Analytics workspace and sends Azure Virtual Desktop control-plane diagnostics to it:

- Host pool: Management, Feed, Connection, Error, Checkpoint, HostRegistration, and AgentHealthStatus.
- Azure Virtual Desktop workspace: Management, Feed, Error, and Checkpoint.

The diagnostic settings use resource-specific Log Analytics tables (`Dedicated`). The workspace defaults to 30 days of retention, enables resource-context access, and leaves ingestion and query endpoints enabled so the Azure portal and Insights workbook can access it. Use private endpoints and disable public access only after configuring the corresponding network access path.

The Azure Virtual Desktop Insights workbook is a built-in Azure portal experience, so this module configures its data sources rather than deploying a separate workbook.

The subscription deployment in `tarnaylabmain.bicep` invokes the module after creating the host pool and workspace in the control-plane resource group. Set `logAnalyticsWorkspaceName` in the `.bicepparam` file; the name must be 4–63 characters.

## Session-host monitoring

This module configures AVD resource diagnostics only. For session-host performance counters and Windows event logs, configure a Data Collection Rule (DCR), associate every session-host VM with it, install Azure Monitor Agent, and ensure the VMs have the required managed identity and network access. The repository deploys session hosts separately, so those resources are not implicitly modified by this module. The Azure Virtual Desktop Insights configuration workbook can help configure and validate the session-host data settings.

## Cost and access

Log Analytics ingestion and retention incur charges. The workspace uses the `PerGB2018` pay-as-you-go SKU and a 30-day default retention; increase `retentionInDays` only when the retention requirement justifies the cost. Grant monitoring users the least-privilege Azure Virtual Desktop Reader and Log Analytics Reader roles at the narrowest appropriate scopes.

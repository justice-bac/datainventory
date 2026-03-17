# Azure Automation Account for scheduled VM start/stop
resource "azurerm_automation_account" "vm_scheduler" {
  name                = "sourcecontrol-automation"
  location            = azurerm_resource_group.sourcecontrol.location
  resource_group_name = azurerm_resource_group.sourcecontrol.name
  sku_name            = "Basic"

  identity {
    type = "SystemAssigned"
  }

  tags = {
    organization = "JUS"
    environment  = "Development"
  }
}

# Grant the automation account permission to start/stop VMs
resource "azurerm_role_assignment" "automation_vm_contributor" {
  scope                = azurerm_resource_group.sourcecontrol.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_automation_account.vm_scheduler.identity[0].principal_id
}

# Stop VM Runbook
resource "azurerm_automation_runbook" "stop_vm" {
  name                    = "Stop-VM"
  location                = azurerm_resource_group.sourcecontrol.location
  resource_group_name     = azurerm_resource_group.sourcecontrol.name
  automation_account_name = azurerm_automation_account.vm_scheduler.name
  log_verbose             = "false"
  log_progress            = "true"
  runbook_type            = "PowerShell"

  content = <<-POWERSHELL
    param(
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory=$true)]
        [string]$VMName
    )

    # Ensures you do not inherit an AzContext in your runbook
    Disable-AzContextAutosave -Scope Process | Out-Null

    # Connect using system-assigned managed identity
    Connect-AzAccount -Identity | Out-Null

    $powerState = (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status).Statuses | Where-Object { $_.Code -like "PowerState/*" }.DisplayStatus
    if ($powerState -eq "VM running") {
        Write-Output "Stopping VM: $VMName in resource group: $ResourceGroupName"
        Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force
        Write-Output "VM stopped successfully"
    }
    else {
        Write-Output "VM: $VMName in resource group: $ResourceGroupName is not running. Current state: $powerState"
    }

    
  POWERSHELL
}

# Start VM Runbook
resource "azurerm_automation_runbook" "start_vm" {
  name                    = "Start-VM"
  location                = azurerm_resource_group.sourcecontrol.location
  resource_group_name     = azurerm_resource_group.sourcecontrol.name
  automation_account_name = azurerm_automation_account.vm_scheduler.name
  log_verbose             = "false"
  log_progress            = "true"
  runbook_type            = "PowerShell"

  content = <<-POWERSHELL
    param(
        [Parameter(Mandatory=$true)]
        [string]$ResourceGroupName,
        
        [Parameter(Mandatory=$true)]
        [string]$VMName
    )

    # Ensures you do not inherit an AzContext in your runbook
    Disable-AzContextAutosave -Scope Process | Out-Null

    # Connect using system-assigned managed identity
    Connect-AzAccount -Identity | Out-Null

    $powerState = (Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Status).Statuses | Where-Object { $_.Code -like "PowerState/*" }.DisplayStatus
    if ($powerState -eq "VM deallocated") {
        Write-Output "Starting VM: $VMName in resource group: $ResourceGroupName"
        Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
        Write-Output "VM started successfully"
    }
    else {
        Write-Output "VM: $VMName in resource group: $ResourceGroupName is not deallocated. Current state: $powerState"
    }
  POWERSHELL
}

# Schedule: Stop VM at 7 PM EST (timezone is US Eastern)
resource "azurerm_automation_schedule" "stop_vm_schedule" {
  name                    = "stop-vm-7pm-est"
  resource_group_name     = azurerm_resource_group.sourcecontrol.name
  automation_account_name = azurerm_automation_account.vm_scheduler.name
  frequency               = "Day"
  interval                = 1
  timezone                = "America/New_York"
  start_time              = timeadd(formatdate("YYYY-MM-DD'T'19:00:00Z", timestamp()), "24h")
  description             = "Stop VM daily at 7 PM EST"
}

# Schedule: Start VM at 7 AM EST
resource "azurerm_automation_schedule" "start_vm_schedule" {
  name                    = "start-vm-7am-est"
  resource_group_name     = azurerm_resource_group.sourcecontrol.name
  automation_account_name = azurerm_automation_account.vm_scheduler.name
  frequency               = "Day"
  interval                = 1
  timezone                = "America/New_York"
  start_time              = timeadd(formatdate("YYYY-MM-DD'T'07:00:00Z", timestamp()), "24h")
  description             = "Start VM daily at 7 AM EST"
}

# Link the stop schedule to the stop runbook
resource "azurerm_automation_job_schedule" "stop_vm_job" {
  resource_group_name     = azurerm_resource_group.sourcecontrol.name
  automation_account_name = azurerm_automation_account.vm_scheduler.name
  schedule_name           = azurerm_automation_schedule.stop_vm_schedule.name
  runbook_name            = azurerm_automation_runbook.stop_vm.name

  parameters = {
    resourcegroupname = azurerm_resource_group.sourcecontrol.name
    vmname            = azurerm_linux_virtual_machine.sourcecontrol-vm.name
  }
}

# Link the start schedule to the start runbook
resource "azurerm_automation_job_schedule" "start_vm_job" {
  resource_group_name     = azurerm_resource_group.sourcecontrol.name
  automation_account_name = azurerm_automation_account.vm_scheduler.name
  schedule_name           = azurerm_automation_schedule.start_vm_schedule.name
  runbook_name            = azurerm_automation_runbook.start_vm.name

  parameters = {
    resourcegroupname = azurerm_resource_group.sourcecontrol.name
    vmname            = azurerm_linux_virtual_machine.sourcecontrol-vm.name
  }
}

output "automation_account_name" {
  value       = azurerm_automation_account.vm_scheduler.name
  description = "The name of the Azure Automation Account managing VM schedules"
}

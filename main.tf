# BEGINNING

////////////////////////
// Client/User Info
////////////////////////

data "azuread_client_config" "CURRENT" {}
data "azurerm_client_config" "CURRENT" {}
data "azurerm_subscription" "CURRENT" {}

////////////////////////
// External Resources
////////////////////////

data "azurerm_virtual_network" "MAIN" {
  name                = var.virtual_network.name
  resource_group_name = var.virtual_network.resource_group_name
}

data "azurerm_resource_group" "MAIN" {
  name = var.resource_group.name
}

////////////////////////
// Azure Key Vault
////////////////////////

resource "random_id" "VAULT" {
  count = var.key_vault_enabled ? 1 : 0

  byte_length = 3
}

resource "azurerm_key_vault" "MAIN" {
  count = var.key_vault_enabled ? 1 : 0

  name                        = length(var.key_vault_name) > 0 ? var.key_vault_name : join("", ["kv", one(random_id.VAULT[*].hex)])
  enabled_for_disk_encryption = var.key_vault_enabled_for_disk_encryption
  soft_delete_retention_days  = var.key_vault_soft_delete_retention_days
  purge_protection_enabled    = var.key_vault_purge_protection_enabled

  sku_name = var.key_vault_sku_name

  access_policy {
    tenant_id = data.azurerm_client_config.CURRENT.tenant_id
    object_id = data.azurerm_client_config.CURRENT.object_id

    key_permissions = [
      "Create", "Delete", "Update", "Get", "List", "Purge",
    ]

    secret_permissions = [
      "Get", "Set", "List", "Delete", "Purge",
    ]

    storage_permissions = [
      "Update", "Delete", "Get", "Set", "List", "Purge",
    ]
  }

  tenant_id           = data.azurerm_client_config.CURRENT.tenant_id
  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name
}

////////////////////////
// Azure Log Analytics Workspace
////////////////////////

resource "azurerm_log_analytics_workspace" "MAIN" {
  name              = var.log_analytics_workspace_name
  sku               = var.log_analytics_workspace_sku
  retention_in_days = var.log_analytics_workspace_retention_days
  daily_quota_gb    = var.log_analytics_workspace_daily_quota_gb

  location            = data.azurerm_virtual_network.MAIN.location
  resource_group_name = data.azurerm_virtual_network.MAIN.resource_group_name
}

////////////////////////
// AVD Subnet
////////////////////////

resource "azurerm_subnet" "MAIN" {
  name             = var.subnet_name
  
  address_prefixes = [cidrsubnet(
    element(data.azurerm_virtual_network.MAIN.address_space, var.subnet_prefixes.vnet_index), 
    var.subnet_prefixes.newbits,
    var.subnet_prefixes.netnum,
  )]

  virtual_network_name = data.azurerm_virtual_network.MAIN.name
  resource_group_name  = data.azurerm_virtual_network.MAIN.resource_group_name
}

resource "azurerm_application_security_group" "MAIN" {
  name = join("-", [azurerm_subnet.MAIN.name, "asg"])

  location            = data.azurerm_virtual_network.MAIN.location
  resource_group_name = data.azurerm_virtual_network.MAIN.resource_group_name
}

resource "azurerm_network_security_group" "MAIN" {
  name = join("-", [azurerm_subnet.MAIN.name, "nsg"])

  dynamic "security_rule" {
    for_each = var.nsg_rules

    content {
      name                       = security_rule.value["name"]
      priority                   = security_rule.value["priority"]
      direction                  = security_rule.value["direction"]
      access                     = security_rule.value["access"]
      protocol                   = security_rule.value["protocol"]
      source_port_range          = security_rule.value["source_port_range"]
      source_address_prefix      = security_rule.value["source_address_prefix"]
      destination_port_range     = security_rule.value["destination_port_range"]
      destination_address_prefix = security_rule.value["destination_address_prefix"]

      source_application_security_group_ids = flatten([
        try(length(security_rule.value["source_address_prefix"]) > 0, false) ? [] : [azurerm_application_security_group.MAIN.id],
      ])

      destination_application_security_group_ids = flatten([
        try(length(security_rule.value["destination_address_prefix"] > 0), false) ? [] : [azurerm_application_security_group.MAIN.id],
      ])
    }
  }

  location            = data.azurerm_virtual_network.MAIN.location
  resource_group_name = data.azurerm_virtual_network.MAIN.resource_group_name
}

resource "azurerm_subnet_network_security_group_association" "MAIN" {
  network_security_group_id = azurerm_network_security_group.MAIN.id
  subnet_id                 = azurerm_subnet.MAIN.id
}

////////////////////////
// Host Pool
////////////////////////

resource "azurerm_virtual_desktop_host_pool" "MAIN" {
  name                     = var.hostpool_name
  type                     = var.hostpool_type
  load_balancer_type       = var.hostpool_load_balancer_type
  validate_environment     = var.hostpool_validate_environment
  start_vm_on_connect      = var.hostpool_start_vm_on_connect
  maximum_sessions_allowed = var.hostpool_maximum_sessions_allowed

  // See https://learn.microsoft.com/nb-no/windows-server/remote/remote-desktop-services/clients/rdp-files
  custom_rdp_properties = var.hostpool_custom_rdp_properties


  scheduled_agent_updates {
    enabled  = var.hostpool_scheduled_agent_updates_enabled
    timezone = var.hostpool_scheduled_agent_updates_timezone

    dynamic "schedule" {
      for_each = var.hostpool_scheduled_agent_updates

      content {
        day_of_week = schedule.value["day_of_week"]
        hour_of_day = schedule.value["hour_of_day"]
      }
    }
  }

  tags                = var.tags
  resource_group_name = data.azurerm_resource_group.MAIN.name
  location            = data.azurerm_resource_group.MAIN.location
}

////////////////////////
// Host Pool | Token
////////////////////////

resource "time_rotating" "TOKEN" {
  rotation_hours = var.hostpool_registration_token_rotation_hours
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "MAIN" {
  hostpool_id     = azurerm_virtual_desktop_host_pool.MAIN.id
  expiration_date = time_rotating.TOKEN.rotation_rfc3339
}

////////////////////////
// Host Pool | Monitoring
////////////////////////

resource "azurerm_monitor_diagnostic_setting" "HOST_POOL" {
  name = join("-", [var.log_monitor_prefix, azurerm_virtual_desktop_host_pool.MAIN.name])

  target_resource_id         = azurerm_virtual_desktop_host_pool.MAIN.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.MAIN.id

  dynamic "enabled_log" {

    for_each = [
      "AgentHealthStatus",
      "Checkpoint",
      "Connection",
      "Error",
      "HostRegistration",
      "Management",
      "NetworkData",
      "SessionHostManagement",
    ]

    content {
      category = enabled_log.value

      retention_policy {
        enabled = false
      }
    }
  }
}

////////////////////////
// Session Host | Network
////////////////////////

resource "azurerm_network_interface" "MAIN" {
  count = var.host_count

  name = join("", [var.host_prefix, count.index])

  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.MAIN.id
  }

  resource_group_name = data.azurerm_virtual_network.MAIN.resource_group_name
  location            = data.azurerm_virtual_network.MAIN.location
}

resource "azurerm_network_interface_application_security_group_association" "MAIN" {
  for_each = {
    for nic in azurerm_network_interface.MAIN : nic.name => nic.id
  }

  network_interface_id          = each.value
  application_security_group_id = azurerm_application_security_group.MAIN.id
}

// Create unique id for each VM/NIC, since destroying doesn't unregister VMs from host-pool
resource "random_id" "VMID" {
  for_each = {
    for nic in azurerm_network_interface.MAIN : nic.name => nic.id
  }

  byte_length = 3

  keepers = {
    id = each.value
  }
}

////////////////////////
// Session Host | VM
////////////////////////

data "azurerm_shared_image" "MAIN" {
  count = var.host_gallery_image != null ? 1 : 0

  name                = var.host_gallery_image.name
  gallery_name        = var.host_gallery_image.gallery_name
  resource_group_name = var.host_gallery_image.resource_group_name
}

resource "random_password" "HOST" {
  count = length(var.host_admin_password) > 0 ? 0 : 1

  length           = 16
  special          = true
  min_special      = 2
  override_special = "*!@#?"

}

resource "azurerm_key_vault_secret" "HOST" {
  count = var.key_vault_enabled ? 1 : 0

  name         = "LocalAdminSecret"
  key_vault_id = one(azurerm_key_vault.MAIN[*].id)
  value        = length(var.host_admin_password) > 0 ? var.host_admin_password : one(random_password.HOST[*].result)
}

resource "azurerm_windows_virtual_machine" "MAIN" {
  for_each = {
    for nic in azurerm_network_interface.MAIN : nic.name => nic.id
  }

  name          = each.key
  computer_name = join("-", [each.key, random_id.VMID[each.key].hex])

  network_interface_ids = [
    each.value,
  ]

  license_type = var.host_license_type
  size         = var.host_size
  timezone     = var.host_timezone
  
  priority        = var.host_priority
  eviction_policy = var.host_eviction_policy
  
  admin_username  = var.host_admin_username
  admin_password  = length(var.host_admin_password) > 0 ? var.host_admin_password : one(random_password.HOST[*].result)

  identity {
    type = "SystemAssigned"
  }

  source_image_id = one(data.azurerm_shared_image.MAIN[*].id)

  dynamic "source_image_reference" {
    for_each = {
      for image in [var.host_source_image] : image.offer => image
      if var.host_gallery_image == null
    }

    content {
      publisher = source_image_reference.value["publisher"]
      offer     = source_image_reference.value["offer"]
      sku       = source_image_reference.value["sku"]
      version   = source_image_reference.value["version"]
    }
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  resource_group_name = data.azurerm_resource_group.MAIN.name
  location            = data.azurerm_resource_group.MAIN.location
}

////////////////////////
// Session Host | Extensions
////////////////////////

resource "azurerm_virtual_machine_extension" "AADLOGIN" {
  for_each = {
    for idx, vm in azurerm_windows_virtual_machine.MAIN : idx => vm.id
  }

  name                       = "AADLogin"
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "1.0" // az vm extension image list --name AADLoginForWindows --publisher Microsoft.Azure.ActiveDirectory --location <location> -o table
  auto_upgrade_minor_version = true
  virtual_machine_id         = each.value

  lifecycle {
    ignore_changes = []
  }
}

// RdAgent
resource "azurerm_virtual_machine_extension" "HOSTPOOL" {
  for_each = {
    for idx, vm in azurerm_windows_virtual_machine.MAIN : idx => vm.id
  }

  depends_on = [
    azurerm_virtual_machine_extension.AADLOGIN,
  ]

  name                       = "AddSessionHost"
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  auto_upgrade_minor_version = true
  type_handler_version       = var.host_extension_parameters.type_handler_version
  virtual_machine_id         = each.value

  settings = jsonencode({
    modulesUrl            = var.host_extension_parameters.modules_url_add_session_host
    configurationFunction = "Configuration.ps1\\AddSessionHost"

    properties = {
      HostPoolName = azurerm_virtual_desktop_host_pool.MAIN.name
      aadJoin      = true
    }
  })

  protected_settings = jsonencode({
    properties = {
      registrationInfoToken = azurerm_virtual_desktop_host_pool_registration_info.MAIN.token
    }
  })

  lifecycle {
    ignore_changes = [
      settings,
      protected_settings,
    ]
  }
}

// Required when using AAD instead of ADDS. Run last; forces reboot
resource "azurerm_virtual_machine_extension" "AADJPRIVATE" {
  for_each = {
    for idx, vm in azurerm_windows_virtual_machine.MAIN : idx => vm.id
  }

  depends_on = [
    azurerm_virtual_machine_extension.AADLOGIN,
    azurerm_virtual_machine_extension.HOSTPOOL,
  ]

  name                       = "AADJPRIVATE"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10" // az vm extension image list --name CustomScriptExtension --publisher Microsoft.Compute --location <location> -o table
  auto_upgrade_minor_version = true
  virtual_machine_id         = each.value

  settings = jsonencode({
    commandToExecute = join("", [
      "powershell.exe -Command \"New-Item -Path HKLM:\\SOFTWARE\\Microsoft\\RDInfraAgent\\AADJPrivate\"",
      ";shutdown -r -t 10",
      ";exit 0",
    ])
  })

  lifecycle {
    ignore_changes = [
      settings,
    ]
  }
}

////////////////////////
// Desktop Workspace
////////////////////////

resource "azurerm_virtual_desktop_workspace" "MAIN" {
  for_each = {
    for ws in var.workspaces : ws.name => ws
  }

  name          = each.value["name"]
  friendly_name = each.value["friendly_name"]
  description   = each.value["description"]

  resource_group_name = data.azurerm_resource_group.MAIN.name
  location            = data.azurerm_resource_group.MAIN.location
}


////////////////////////
// Desktop Workspace | Monitoring
////////////////////////

resource "azurerm_monitor_diagnostic_setting" "APP_WORKSPACE" {
  for_each = {
    for workspace in azurerm_virtual_desktop_workspace.MAIN : workspace.name => workspace.id
    if true
  }

  name                       = join("-", [var.log_monitor_prefix, each.key])
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.MAIN.id

  // See https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/resource-logs-categories#microsoftdesktopvirtualizationworkspaces
  dynamic "enabled_log" {

    for_each = [
      "Checkpoint",
      "Error",
      "Feed",
      "Management",
    ]

    content {
      category = enabled_log.value

      retention_policy {
        enabled = false
      }
    }
  }
}

////////////////////////
// Desktop Application Groups
////////////////////////

resource "azurerm_virtual_desktop_application_group" "MAIN" {
  for_each = {
    for group in var.application_groups : group.name => group
  }

  name                         = each.value["name"]
  type                         = each.value["type"]
  friendly_name                = each.value["friendly_name"]
  description                  = each.value["description"]
  default_desktop_display_name = each.value["default_desktop_display_name"]

  host_pool_id        = azurerm_virtual_desktop_host_pool.MAIN.id
  resource_group_name = data.azurerm_resource_group.MAIN.name
  location            = data.azurerm_resource_group.MAIN.location
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "MAIN" {
  for_each = {
    for group in var.application_groups : group.name => group
  }

  application_group_id = azurerm_virtual_desktop_application_group.MAIN[each.key].id
  workspace_id         = azurerm_virtual_desktop_workspace.MAIN[each.value["workspace_name"]].id
}

////////////////////////
// Desktop Application Group | Monitoring
////////////////////////

resource "azurerm_monitor_diagnostic_setting" "APP_GROUP" {
  for_each = {
    for group in azurerm_virtual_desktop_application_group.MAIN : group.name => group.id
    if true
  }

  name                       = join("-", [var.log_monitor_prefix, each.key])
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.MAIN.id

  // See https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/resource-logs-categories#microsoftdesktopvirtualizationapplicationgroups
  dynamic "enabled_log" {

    for_each = [
      "Checkpoint",
      "Error",
      "Management",
    ]

    content {
      category = enabled_log.value

      retention_policy {
        enabled = false
      }
    }
  }
}

////////////////////////
// Desktop Remote Apps
////////////////////////

resource "azurerm_virtual_desktop_application" "MAIN" {
  for_each = {
    for app in var.applications : join("-", [app.application_group_name, app.name]) => app
  }

  name                         = each.value["name"]
  friendly_name                = each.value["friendly_name"]
  description                  = each.value["description"]
  path                         = each.value["path"]
  command_line_argument_policy = each.value["command_line_argument_policy"]
  command_line_arguments       = each.value["command_line_arguments"]
  show_in_portal               = each.value["show_in_portal"]
  icon_path                    = each.value["icon_path"]
  icon_index                   = each.value["icon_index"]

  application_group_id = azurerm_virtual_desktop_application_group.MAIN[each.value["application_group_name"]].id
}

////////////////////////
// Azure AD Groups
////////////////////////

resource "azuread_group" "ADMIN" {
  display_name     = var.aad_group_admins.display_name
  security_enabled = true
  owners           = [data.azuread_client_config.CURRENT.object_id]

  lifecycle {
    ignore_changes = [owners]
  }
}

resource "azuread_group" "USER" {
  display_name     = var.aad_group_users.display_name
  security_enabled = true
  owners           = [data.azuread_client_config.CURRENT.object_id]

  lifecycle {
    ignore_changes = [owners]
  }
}

////////////////////////
// Azure AD Roles
////////////////////////

resource "azurerm_role_assignment" "ADMIN" {
  for_each = toset([
    "Desktop Virtualization User",
    "Virtual Machine Administrator Login",
  ])

  role_definition_name = each.value
  principal_id         = azuread_group.ADMIN.id
  scope                = data.azurerm_resource_group.MAIN.id
}

resource "azurerm_role_assignment" "USER" {
  for_each = toset([
    "Desktop Virtualization User",
    "Virtual Machine User Login",
  ])

  role_definition_name = each.value
  principal_id         = azuread_group.USER.id
  scope                = data.azurerm_resource_group.MAIN.id
}

/////////////////////////////////
// Autoscaler Role
//////////////////////////////////

data "azuread_service_principal" "AUTOSCALER" {
  display_name = "Windows Virtual Desktop"
}

resource "azurerm_role_definition" "AUTOSCALER" {
  name        = "avd-autoscaler-custom-role"
  description = "Custom Autoscaler Role (Azure Virtual Desktop)"
  scope       = data.azurerm_subscription.CURRENT.id

  permissions {
    actions = [
      "Microsoft.Insights/eventtypes/values/read",
      "Microsoft.Compute/virtualMachines/deallocate/action",
      "Microsoft.Compute/virtualMachines/restart/action",
      "Microsoft.Compute/virtualMachines/powerOff/action",
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.DesktopVirtualization/hostpools/read",
      "Microsoft.DesktopVirtualization/hostpools/write",
      "Microsoft.DesktopVirtualization/hostpools/sessionhosts/read",
      "Microsoft.DesktopVirtualization/hostpools/sessionhosts/write",
      "Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/delete",
      "Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/read",
      "Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/sendMessage/action",
      "Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/read"
    ]

    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.CURRENT.id,
  ]
}

resource "azurerm_role_assignment" "AUTOSCALER" {
  principal_id       = data.azuread_service_principal.AUTOSCALER.id
  role_definition_id = azurerm_role_definition.AUTOSCALER.role_definition_resource_id

  skip_service_principal_aad_check = true
  scope                            = data.azurerm_subscription.CURRENT.id
}

////////////////////////
// Autoscaler Plan
////////////////////////
/*
resource "azurerm_virtual_desktop_scaling_plan" "MAIN" {
  name          = var.autoscaler_plan_name
  friendly_name = var.autoscaler_plan_friendly_name
  description   = var.autoscaler_plan_description
  time_zone     = var.autoscaler_plan_timezone

  host_pool {
    hostpool_id          = azurerm_virtual_desktop_host_pool.MAIN.id
    scaling_plan_enabled = var.autoscaler_plan_enabled
  }

  dynamic "schedule" {
    for_each = var.autoscaler_plan_schedules

    content {
      name                                 = schedule.value["name"]
      days_of_week                         = schedule.value["days_of_week"]
      ramp_up_start_time                   = schedule.value["ramp_up_start_time"]
      ramp_up_load_balancing_algorithm     = schedule.value["ramp_up_load_balancing_algorithm"]
      ramp_up_minimum_hosts_percent        = schedule.value["ramp_up_minimum_hosts_percent"]
      ramp_up_capacity_threshold_percent   = schedule.value["ramp_up_capacity_threshold_percent"]
      peak_start_time                      = schedule.value["peak_start_time"]
      peak_load_balancing_algorithm        = schedule.value["peak_load_balancing_algorithm"]
      ramp_down_start_time                 = schedule.value["ramp_down_start_time"]
      ramp_down_load_balancing_algorithm   = schedule.value["ramp_down_load_balancing_algorithm"]
      ramp_down_minimum_hosts_percent      = schedule.value["ramp_down_minimum_hosts_percent"]
      ramp_down_force_logoff_users         = schedule.value["ramp_down_force_logoff_users"]
      ramp_down_wait_time_minutes          = schedule.value["ramp_down_wait_time_minutes"]
      ramp_down_notification_message       = schedule.value["ramp_down_notification_message"]
      ramp_down_capacity_threshold_percent = schedule.value["ramp_down_capacity_threshold_percent"]
      ramp_down_stop_hosts_when            = schedule.value["ramp_down_stop_hosts_when"]
      off_peak_start_time                  = schedule.value["off_peak_start_time"]
      off_peak_load_balancing_algorithm    = schedule.value["off_peak_load_balancing_algorithm"]
    }
  }

  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name
}

////////////////////////
// Autoscaler Monitoring
////////////////////////

resource "azurerm_monitor_diagnostic_setting" "AUTOSCALER" {
  name = join("-", [var.log_monitor_prefix, azurerm_virtual_desktop_scaling_plan.MAIN.name])

  depends_on = [
    azurerm_virtual_desktop_scaling_plan.MAIN,
  ]

  target_resource_id         = azurerm_virtual_desktop_scaling_plan.MAIN.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.MAIN.id

  enabled_log {
    category = "Autoscale"

    retention_policy {
      enabled = false
    }
  }
}
*/
# END
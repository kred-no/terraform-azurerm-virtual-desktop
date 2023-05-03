////////////////////////
// Data Sources
////////////////////////

data "azuread_client_config" "CURRENT" {}
data "azurerm_client_config" "CURRENT" {}
data "azurerm_subscription" "CURRENT" {}

data "azurerm_resource_group" "MAIN" {
  name = var.resource_group.name
}

data "azurerm_virtual_network" "MAIN" {
  name                = var.subnet.virtual_network_name
  resource_group_name = var.subnet.resource_group_name
}

data "azurerm_subnet" "MAIN" {
  name                 = var.subnet.name
  virtual_network_name = var.subnet.virtual_network_name
  resource_group_name  = var.subnet.resource_group_name
}

////////////////////////
// Azure Key Vault
////////////////////////

resource "random_string" "VAULT" {
  length  = 22
  special = false
  upper   = false

  keepers = {
    prefix = var.key_vault_prefix
  }
}

resource "azurerm_key_vault" "MAIN" {
  name                        = format("%s%s", random_string.VAULT.keepers.prefix, random_string.VAULT.result)
  enabled_for_disk_encryption = var.key_vault_enabled_for_disk_encryption
  soft_delete_retention_days  = var.key_vault_soft_delete_retention_days
  purge_protection_enabled    = var.key_vault_purge_protection_enabled

  sku_name = var.key_vault_sku_name

  access_policy {
    tenant_id = data.azurerm_client_config.CURRENT.tenant_id
    object_id = data.azurerm_client_config.CURRENT.object_id

    key_permissions     = ["Create", "Delete", "Update", "Get", "List", "Purge"]
    secret_permissions  = ["Get", "Set", "List", "Delete", "Purge"]
    storage_permissions = ["Update", "Delete", "Get", "Set", "List", "Purge"]
  }

  tags                = var.tags
  tenant_id           = data.azurerm_client_config.CURRENT.tenant_id
  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name
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
// Session Host | Network Interface
////////////////////////

// Create unique id for each Hostname, since destroying doesn't unregister VMs from host-pool
resource "random_string" "VM_UNIQUE_ID" {
  count = var.host_count

  length = 5

  keepers = {
    prefix = var.host_prefix
  }
}

resource "azurerm_network_interface" "MAIN" {
  count = var.host_count

  name = format(
    "%s%s-%s",
    random_string.VM_UNIQUE_ID[count.index].keepers.prefix,
    count.index,
    random_string.VM_UNIQUE_ID[count.index].result,
  )

  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = data.azurerm_subnet.MAIN.id
  }

  tags                = var.tags
  resource_group_name = data.azurerm_virtual_network.MAIN.resource_group_name
  location            = data.azurerm_virtual_network.MAIN.location

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_application_security_group" "MAIN" {
  name = format("%s-asg", data.azurerm_subnet.MAIN.name)

  tags                = var.tags
  location            = data.azurerm_virtual_network.MAIN.location
  resource_group_name = data.azurerm_virtual_network.MAIN.resource_group_name
}

resource "azurerm_network_interface_application_security_group_association" "MAIN" {
  count = var.host_count

  network_interface_id          = azurerm_network_interface.MAIN[count.index].id
  application_security_group_id = azurerm_application_security_group.MAIN.id
}

////////////////////////
// Session Host | Image & Credentials
////////////////////////

data "azurerm_shared_image" "MAIN" {
  count = alltrue([
    var.host_gallery_image != null,
    var.source_image_id == null,
  ]) ? 1 : 0

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
  name         = "LocalAdministratorPassword"
  key_vault_id = azurerm_key_vault.MAIN.id
  value        = length(var.host_admin_password) > 0 ? var.host_admin_password : one(random_password.HOST[*].result)
}

////////////////////////
// Session Host | VM
////////////////////////

resource "azurerm_windows_virtual_machine" "MAIN" {
  count = var.host_count

  depends_on = [
    azurerm_network_interface.MAIN,
  ]

  name = format(
    "%s%s-%s",
    random_string.VM_UNIQUE_ID[count.index].keepers.prefix,
    count.index,
    random_string.VM_UNIQUE_ID[count.index].result,
  )

  #computer_name = each.key //Registered in Azure AD

  license_type = var.host_license_type
  size         = var.host_size
  timezone     = var.host_timezone

  vtpm_enabled               = false
  encryption_at_host_enabled = false
  secure_boot_enabled        = false

  priority        = var.host_priority
  eviction_policy = var.host_eviction_policy

  admin_username = var.host_admin_username
  admin_password = length(var.host_admin_password) > 0 ? var.host_admin_password : one(random_password.HOST[*].result)

  network_interface_ids = [
    azurerm_network_interface.MAIN[count.index].id,
  ]

  identity {
    type = "SystemAssigned"
    #identity_ids = null
  }

  // Priority: Source Image Id > Gallery Image Reference > Source Image Reference
  source_image_id = try(var.source_image_id, one(data.azurerm_shared_image.MAIN[*].id))

  dynamic "source_image_reference" {
    for_each = {
      for image in [var.host_source_image] : image.offer => image
      if alltrue([
        var.host_gallery_image == null,
        var.source_image_id == null,
      ])
    }

    content {
      publisher = source_image_reference.value["publisher"]
      offer     = source_image_reference.value["offer"]
      sku       = source_image_reference.value["sku"]
      version   = source_image_reference.value["version"]
    }
  }

  os_disk {
    disk_size_gb         = var.host_disk_size_gb
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  tags                = var.tags
  resource_group_name = data.azurerm_resource_group.MAIN.name
  location            = data.azurerm_resource_group.MAIN.location

  lifecycle {
    ignore_changes = [
      admin_password,
      custom_data,
    ]
  }
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
  automatic_upgrade_enabled  = false
  virtual_machine_id         = each.value
  tags                       = var.tags

  lifecycle {
    ignore_changes = [
      settings,
      protected_settings,
      tags,
    ]
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
  automatic_upgrade_enabled  = false
  type_handler_version       = var.host_extension_parameters.type_handler_version
  virtual_machine_id         = each.value
  tags                       = var.tags

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
      tags,
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
  automatic_upgrade_enabled  = false
  virtual_machine_id         = each.value
  tags                       = var.tags

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
      protected_settings,
      tags,
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

  tags                = var.tags
  resource_group_name = data.azurerm_resource_group.MAIN.name
  location            = data.azurerm_resource_group.MAIN.location
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

  tags                = var.tags
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

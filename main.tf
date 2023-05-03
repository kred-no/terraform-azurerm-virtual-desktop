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

data "azurerm_shared_image" "MAIN" {
  count = alltrue([
    var.host_gallery_image != null,
    var.source_image_id == null,
  ]) ? 1 : 0

  name                = var.host_gallery_image.name
  gallery_name        = var.host_gallery_image.gallery_name
  resource_group_name = var.host_gallery_image.resource_group_name
}

////////////////////////
// Azure AD | Groups
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
// Azure AD | Roles
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
// Session Host | Network Interfaces
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
  for_each = {
    for idx,uid in random_string.VM_UNIQUE_ID: idx => uid
  }

  name = format("%s%s-%s", each.value["keepers"].prefix, each.key, each.value["result"])

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
  for_each = {
    for idx,nic in azurerm_network_interface.MAIN: idx => nic
  }

  network_interface_id          = each.value["id"]
  application_security_group_id = azurerm_application_security_group.MAIN.id
}

////////////////////////
// Session Host | Credentials
////////////////////////

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
// Session Host | Compute & Storage
////////////////////////

resource "azurerm_windows_virtual_machine" "MAIN" {
  for_each = {
    for idx, nic in azurerm_network_interface.MAIN : idx => nic
  }

  name          = format("%s%s", var.host_prefix, each.key)
  computer_name = each.value["name"] // Registered in Azure AD

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
    #azurerm_network_interface.MAIN[count.index].id,
    each.value["id"]
  ]

  identity {
    type = "SystemAssigned"
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
// TODO: Add local module here

module "SESSION_HOST_EXTENSIONS" {
  source = "./modules/extensions"
  
  for_each = {
    for vm in azurerm_vazurerm_windows_virtual_machine.MAIN: vm.name => vm
    if false
  }

  tags            = var.tags
  virtual_machine = each.value
  host_pool       = azurerm_virtual_desktop_host_pool.MAIN
}

////////////////////////
// Remote Desktop | Workspaces
////////////////////////

/*module "REMOTE_DESKTOP_WORKSPACE" {
  source = "./modules/workspace"
  
  for_each = var.workspaces

  tags = var.tags
}*/

////////////////////////
// Monitoring
////////////////////////

/*module "AZURE_MONITORING" {
  source = "./modules/moinitoring"
  
  for_each = []

  tags = var.tags
}*/

////////////////////////
// Session Host | AutoScaling
////////////////////////

/*module "REMOTE_DESKTOP_AUTOSCALER" {
  source = "./modules/autoscaler"
  
  for_each = []

  tags = var.tags
}*/

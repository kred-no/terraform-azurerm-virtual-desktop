////////////////////////
// Data Sources (Current Client)
////////////////////////

data "azuread_client_config" "CURRENT" {}
data "azurerm_client_config" "CURRENT" {}
data "azurerm_subscription" "CURRENT" {}

////////////////////////
// Data Sources
////////////////////////

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
// Azure AD Groups
////////////////////////

module "AZURE_AD_GROUPS" {
  source = "./modules/azure-ad"

  parameters = {
    group_admins = var.avd_group_admins
    group_users  = var.avd_group_users
  }

  // Resource References
  client_config  = data.azuread_client_config.CURRENT
  resource_group = data.azurerm_resource_group.MAIN
}

////////////////////////
// Azure Key Vault
////////////////////////

resource "random_string" "KEY_VAULT" {
  length  = 22
  special = false
  upper   = false

  keepers = {
    prefix = var.key_vault.prefix
  }
}

resource "azurerm_key_vault" "MAIN" {
  name     = format("%s%s", random_string.KEY_VAULT.keepers.prefix, random_string.KEY_VAULT.result)
  sku_name = var.key_vault.sku_name

  enabled_for_disk_encryption = var.key_vault.enabled_for_disk_encryption
  soft_delete_retention_days  = var.key_vault.soft_delete_retention_days
  purge_protection_enabled    = var.key_vault.purge_protection_enabled

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
// AVD Host Pool
////////////////////////

resource "azurerm_virtual_desktop_host_pool" "MAIN" {
  name                     = var.host_pool.name
  type                     = var.host_pool.pool_type
  load_balancer_type       = var.host_pool.load_balancer_type
  validate_environment     = var.host_pool.validate_environment
  start_vm_on_connect      = var.host_pool.start_vm_on_connect
  maximum_sessions_allowed = var.host_pool.maximum_sessions_allowed

  // See https://learn.microsoft.com/nb-no/windows-server/remote/remote-desktop-services/clients/rdp-files
  custom_rdp_properties = var.host_pool.custom_rdp_properties


  scheduled_agent_updates {
    enabled  = var.host_pool.scheduled_agent_updates_enabled
    timezone = var.host_pool.scheduled_agent_updates_timezone

    dynamic "schedule" {
      for_each = var.host_pool.scheduled_agent_updates

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
// Module | Workspaces
////////////////////////

module "REMOTE_DESKTOP_WORKSPACE" {
  source = "./modules/workspace"

  for_each = {
    for workspace in var.workspaces : workspace.name => workspace
  }

  parameters = each.value

  tags           = var.tags
  host_pool      = azurerm_virtual_desktop_host_pool.MAIN
  resource_group = data.azurerm_resource_group.MAIN
}

////////////////////////
// Module | AVD Session Hosts
////////////////////////

module "SESSION_HOSTS" {
  source = "./modules/session-hosts"

  parameters = var.session_hosts

  tags            = var.tags
  resource_group  = data.azurerm_resource_group.MAIN
  subnet          = data.azurerm_subnet.MAIN
  virtual_network = data.azurerm_virtual_network.MAIN
  key_vault       = azurerm_key_vault.MAIN
}

////////////////////////
// Module | AVD Session Host Extensions
////////////////////////

module "VM_EXTENSIONS" {
  source = "./modules/extensions"

  for_each = {
    for vm in module.SESSION_HOSTS.virtual_machines : vm.name => vm
  }

  parameters = var.session_host_extensions

  virtual_machine = each.value
  tags            = var.tags
  host_pool       = azurerm_virtual_desktop_host_pool.MAIN
}

////////////////////////
// Module | Monitoring
////////////////////////

/*module "AZURE_MONITORING" {
  source = "./modules/moinitoring"
  
  for_each = []

  tags = var.tags
}*/

////////////////////////
// SubModule | AutoScaling
////////////////////////

/*module "REMOTE_DESKTOP_AUTOSCALER" {
  source = "./modules/autoscaler"
  
  for_each = []

  tags = var.tags
}*/

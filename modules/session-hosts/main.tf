////////////////////////
// Data Sources
////////////////////////

data "azurerm_shared_image" "MAIN" {
  count = alltrue([
    var.parameters.shared_image != null,
    var.parameters.source_image_id == null,
  ]) ? 1 : 0

  name                = var.parameters.shared_image.name
  gallery_name        = var.parameters.shared_image.gallery_name
  resource_group_name = var.parameters.shared_image.resource_group_name
}

////////////////////////
// Helpers
////////////////////////

// Create unique id for each Hostname, since destroying doesn't unregister VMs from host-pool
resource "random_string" "HOSTNAME" {
  count = var.parameters.count

  length  = 10
  upper   = false
  special = false

  keepers = {
    prefix = var.parameters.prefix
  }
}

// Generate random password
resource "random_password" "LOCAL_ADMIN" {
  count = var.parameters.admin_password != null ? 0 : 1

  length           = 16
  special          = true
  min_special      = 2
  override_special = "*!@#?"
}

resource "azurerm_key_vault_secret" "ADMIN_USERNAME" {
  name         = "LocalAdminUsername"
  value        = var.parameters.admin_username
  key_vault_id = var.key_vault.id
}

resource "azurerm_key_vault_secret" "ADMIN_PASSWORD" {
  name         = "LocalAdminPassword"
  value        = var.parameters.admin_password != null ? var.parameters.admin_password : one(random_password.LOCAL_ADMIN[*].result)
  key_vault_id = var.key_vault.id
}

////////////////////////
// Network Interface
////////////////////////

resource "azurerm_application_security_group" "MAIN" {
  name = format("%s-asg", var.subnet.name)

  tags                = var.tags
  location            = var.virtual_network.location
  resource_group_name = var.virtual_network.resource_group_name
}

resource "azurerm_network_interface" "MAIN" {
  count = var.parameters.count

  name = format("%s%s", var.parameters.prefix, count.index)

  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.subnet.id
  }

  tags                = var.tags
  resource_group_name = var.virtual_network.resource_group_name
  location            = var.virtual_network.location

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_network_interface_application_security_group_association" "MAIN" {
  count = var.parameters.count

  network_interface_id          = azurerm_network_interface.MAIN[count.index].id
  application_security_group_id = azurerm_application_security_group.MAIN.id
}

////////////////////////
// Virtual Machine
////////////////////////

resource "azurerm_windows_virtual_machine" "MAIN" {
  count = var.parameters.count

  name          = format("%s%s", var.parameters.prefix, count.index)
  computer_name = random_string.HOSTNAME[count.index].result

  license_type = var.parameters.license_type
  size         = var.parameters.size
  timezone     = var.parameters.timezone

  vtpm_enabled               = false
  encryption_at_host_enabled = false
  secure_boot_enabled        = false

  priority        = var.parameters.priority
  eviction_policy = var.parameters.eviction_policy

  admin_username = var.parameters.admin_username
  admin_password = var.parameters.admin_password != null ? var.parameters.admin_password : one(random_password.LOCAL_ADMIN[*].result)

  network_interface_ids = [
    azurerm_network_interface.MAIN[count.index].id,
  ]

  identity {
    type = "SystemAssigned"
  }

  // Priority: Source Image Id > Gallery Image Reference > Source Image Reference
  source_image_id = try(coalesce(var.parameters.source_image_id, one(data.azurerm_shared_image.MAIN[*].id)), null)

  dynamic "source_image_reference" {
    for_each = {
      for image in [var.parameters.source_image] : image.offer => image
      if alltrue([
        var.parameters.source_image_id == null,
        one(data.azurerm_shared_image.MAIN[*].id) == null,
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
    disk_size_gb         = var.parameters.disk_size_gb
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  tags                = var.tags
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location

  lifecycle {
    ignore_changes = [
      admin_password,
      custom_data,
    ]
  }
}

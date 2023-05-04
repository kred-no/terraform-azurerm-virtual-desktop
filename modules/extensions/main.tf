////////////////////////
// Extra Extensions
////////////////////////

resource "azurerm_virtual_machine_extension" "EXTRA" {
  for_each = {
    for extension in var.parameters.extra_extensions : extension.name => extension
  }

  name      = each.value["name"]
  publisher = each.value["publisher"]
  type      = each.value["type"]

  type_handler_version       = each.value["type_handler_version"]
  auto_upgrade_minor_version = each.value["auto_upgrade_minor_version"]
  automatic_upgrade_enabled  = each.value["automatic_upgrade_enabled"]

  settings           = each.value["json_settings"]
  protected_settings = each.value["json_protected_settings"]

  virtual_machine_id = var.virtual_machine.id
  tags               = var.tags

  lifecycle {
    ignore_changes = [settings, protected_settings, tags]
  }
}

////////////////////////
// Extension | Azure AD Login
////////////////////////
// az vm extension image list --name AADLoginForWindows --publisher Microsoft.Azure.ActiveDirectory --location <location> -o table

resource "azurerm_virtual_machine_extension" "AZURE_AD_LOGIN" {
  count = var.parameters.aad_login_for_windows.enabled ? 1 : 0

  name      = "AADLogin"
  publisher = "Microsoft.Azure.ActiveDirectory"
  type      = "AADLoginForWindows"

  type_handler_version       = var.parameters.aad_login_for_windows.type_handler_version
  auto_upgrade_minor_version = var.parameters.aad_login_for_windows.auto_upgrade_minor_version
  automatic_upgrade_enabled  = var.parameters.aad_login_for_windows.automatic_upgrade_enabled

  settings = var.parameters.aad_login_for_windows.intune_registration ? jsonencode({
    mdmId = "0000000a-0000-0000-c000-000000000000"
  }) : null

  virtual_machine_id = var.virtual_machine.id
  tags               = var.tags

  lifecycle {
    ignore_changes = [settings, protected_settings, tags]
  }
}

////////////////////////
// Extension | Host Pool Registration
////////////////////////

resource "time_rotating" "HOSTPOOL_TOKEN" {
  rotation_hours = 8
}

resource "azurerm_virtual_desktop_host_pool_registration_info" "MAIN" {
  hostpool_id     = var.host_pool.id
  expiration_date = time_rotating.HOSTPOOL_TOKEN.rotation_rfc3339

  lifecycle {
    ignore_changes = [expiration_date]
  }
}

resource "azurerm_virtual_machine_extension" "JOIN_HOSTPOOL" {
  count      = var.parameters.join_hostpool.enabled ? 1 : 0
  depends_on = [azurerm_virtual_machine_extension.AZURE_AD_LOGIN]

  name      = "AddSessionHost"
  publisher = "Microsoft.Powershell"
  type      = "DSC"

  type_handler_version       = var.parameters.join_hostpool.type_handler_version
  auto_upgrade_minor_version = var.parameters.join_hostpool.auto_upgrade_minor_version
  automatic_upgrade_enabled  = var.parameters.join_hostpool.automatic_upgrade_enabled

  settings = jsonencode({
    modulesUrl            = var.parameters.join_hostpool.modules_url
    configurationFunction = var.parameters.join_hostpool.modules_function

    properties = {
      HostPoolName = var.host_pool.name
      aadJoin      = true
    }
  })

  protected_settings = jsonencode({
    properties = {
      registrationInfoToken = azurerm_virtual_desktop_host_pool_registration_info.MAIN.token
    }
  })

  virtual_machine_id = var.virtual_machine.id
  tags               = var.tags

  lifecycle {
    ignore_changes = [settings, protected_settings, tags]
  }
}

////////////////////////
// Extension | Azure AD Fix
////////////////////////
// Required when using AAD instead of ADDS. Run last; forces reboot
// az vm extension image list --name CustomScriptExtension --publisher Microsoft.Compute --location <location> -o table

resource "azurerm_virtual_machine_extension" "AADJPRIVATE" {
  count = var.parameters.aadjprivate_registry_update.enabled ? 1 : 0

  depends_on = [
    azurerm_virtual_machine_extension.JOIN_HOSTPOOL,
    azurerm_virtual_machine_extension.EXTRA,
  ]

  name      = "AADJPRIVATE"
  publisher = "Microsoft.Compute"
  type      = "CustomScriptExtension"

  type_handler_version       = var.parameters.aadjprivate_registry_update.type_handler_version
  auto_upgrade_minor_version = var.parameters.aadjprivate_registry_update.auto_upgrade_minor_version
  automatic_upgrade_enabled  = var.parameters.aadjprivate_registry_update.automatic_upgrade_enabled

  settings = jsonencode({
    commandToExecute = join("", [
      "powershell.exe -Command \"New-Item -Path HKLM:\\SOFTWARE\\Microsoft\\RDInfraAgent\\AADJPrivate\"",
      ";shutdown -r -t 15",
      ";exit 0",
    ])
  })

  virtual_machine_id = var.virtual_machine.id
  tags               = var.tags

  lifecycle {
    ignore_changes = [settings, protected_settings, tags]
  }
}

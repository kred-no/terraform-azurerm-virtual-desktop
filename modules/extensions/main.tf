////////////////////////
// Variables
////////////////////////

variable "tags" {}
variable "virtual_machine" {}
variable "host_pool" {}

////////////////////////
// Extension | Azure AD Registration
////////////////////////
// az vm extension image list --name AADLoginForWindows --publisher Microsoft.Azure.ActiveDirectory --location <location> -o table

resource "azurerm_virtual_machine_extension" "AZURE_AD_REGISTER" {
  count = 1

  name                       = "AADLogin"
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADLoginForWindows"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = false

  virtual_machine_id         = var.virtual_machine.id
  tags                       = var.tags

  lifecycle {
    ignore_changes = [
      settings,
      protected_settings,
      tags,
    ]
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
}

resource "azurerm_virtual_machine_extension" "HOSTPOOL" {
  count = 1
  
  depends_on = [
    azurerm_virtual_machine_extension.AZURE_AD_REGISTER,
  ]

  name                       = "AddSessionHost"
  publisher                  = "Microsoft.Powershell"
  type                       = "DSC"
  type_handler_version       = "2.73"

  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = false
  
  virtual_machine_id         = var.virtual_machine.id
  tags                       = var.tags

  settings = jsonencode({
    modulesUrl            = "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_06-15-2022.zip"
    configurationFunction = "Configuration.ps1\\AddSessionHost"

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

  lifecycle {
    ignore_changes = [
      settings,
      protected_settings,
      tags,
    ]
  }
}

////////////////////////
// Extension | Azure AD Fix
////////////////////////
// Required when using AAD instead of ADDS. Run last; forces reboot
// az vm extension image list --name CustomScriptExtension --publisher Microsoft.Compute --location <location> -o table

resource "azurerm_virtual_machine_extension" "AADJPRIVATE" {
  count = 1

  depends_on = [
    azurerm_virtual_machine_extension.AZURE_AD_REGISTER,
    azurerm_virtual_machine_extension.HOSTPOOL_TOKEN,
  ]

  name                       = "AADJPRIVATE"
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"

  auto_upgrade_minor_version = true
  automatic_upgrade_enabled  = false
  virtual_machine_id         = var.virtual_machine.id
  tags                       = var.tags

  settings = jsonencode({
    commandToExecute = join("", [
      "powershell.exe -Command \"New-Item -Path HKLM:\\SOFTWARE\\Microsoft\\RDInfraAgent\\AADJPrivate\"",
      ";shutdown -r -t 15",
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

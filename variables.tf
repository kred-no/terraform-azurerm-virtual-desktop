////////////////////////
// Misc
////////////////////////

variable "virtual_network" {
  description = "Used for creating data-source."

  type = object({
    name                = string
    resource_group_name = string
  })
}

variable "resource_group" {
  description = "Used for creating data-source."

  type = object({
    name = string
  })
}

variable "tags" {
  type    = map(string)
  default = {}
}

////////////////////////
// Azure Key Vault
////////////////////////

variable "key_vault_enabled" {
  type    = bool
  default = true
}

variable "key_vault_name" {
  type    = string
  default = ""
}

variable "key_vault_sku_name" {
  type    = string
  default = "standard"
}

variable "key_vault_enabled_for_disk_encryption" {
  type    = bool
  default = true
}

variable "key_vault_soft_delete_retention_days" {
  type    = number
  default = 7
}

variable "key_vault_purge_protection_enabled" {
  type    = bool
  default = false
}

////////////////////////
// Azure Log Analytics
////////////////////////

variable "log_analytics_workspace_name" {
  type    = string
  default = "avd-analytics"
}

variable "log_analytics_workspace_sku" {
  type    = string
  default = "PerGB2018"
}

variable "log_analytics_workspace_retention_days" {
  type    = number
  default = 30
}

variable "log_analytics_workspace_daily_quota_gb" {
  type    = number
  default = null
}

variable "log_monitor_prefix" {
  type    = string
  default = "monitor"
}

////////////////////////
// AVD | Subnet
////////////////////////

variable "subnet_name" {
  type    = string
  default = "DefaultHostPool"
}

variable "subnet_prefixes" {
  description = "Create subnet within provided external virtual network."
  
  type = object({
    vnet_index = optional(number, 0)
    newbits    = optional(number, 8)
    netnum     = optional(number, 0)
  })

  default = {}
}

variable "nsg_rules" {
  type = list(object({
    priority = number
    name     = string

    direction                  = optional(string, "Inbound")
    access                     = optional(string, "Allow")
    protocol                   = optional(string, "Tcp")
    source_port_range          = optional(string)
    source_address_prefix      = optional(string)
    destination_port_range     = optional(string)
    destination_address_prefix = optional(string)
  }))

  default = [{
    priority               = 500
    name                   = "allow-3389-inbound-tcp"
    source_port_range      = "*"
    source_address_prefix  = "*"
    destination_port_range = "3389"
  }]
}

////////////////////////
// AVD | Host Pool
////////////////////////

variable "hostpool_name" {
  type    = string
  default = "default-hostpool"
}

variable "hostpool_friendly_name" {
  type    = string
  default = null
}

variable "hostpool_description" {
  type    = string
  default = null
}

variable "hostpool_type" {
  type    = string
  default = "Pooled"
}

variable "hostpool_load_balancer_type" {
  type    = string
  default = "BreadthFirst"
}

variable "hostpool_validate_environment" {
  type    = bool
  default = false
}

variable "hostpool_start_vm_on_connect" {
  type    = bool
  default = true
}

variable "hostpool_maximum_sessions_allowed" {
  type    = number
  default = 5
}

variable "hostpool_custom_rdp_properties" {
  type    = string
  default = "targetisaadjoined:i:1;enablerdsaadauth:i:1;redirectlocation:i:1;videoplaybackmode:i:1;audiocapturemode:i:1;audiomode:i:0;"
}

variable "hostpool_scheduled_agent_updates_enabled" {
  type    = bool
  default = false
}

variable "hostpool_scheduled_agent_updates_timezone" {
  type    = string
  default = "W. Europe Standard Time"
}

variable "hostpool_scheduled_agent_updates" {
  type = list(object({
    day_of_week = string
    hour_of_day = number
  }))

  default = []
}

variable "hostpool_registration_token_rotation_hours" {
  type    = number
  default = 8
}

////////////////////////
// AVD | Session Host
////////////////////////

variable "host_prefix" {
  type    = string
  default = "sh"
}

variable "host_count" {
  type    = number
  default = 1
}

variable "host_license_type" {
  type    = string
  default = "None"
}

variable "host_size" {
  type    = string
  default = "Standard_DS2_v2"
}

variable "host_priority" {
  type    = string
  default = "Regular"
}

variable "host_eviction_policy" {
  type    = string
  default = null
}

variable "host_admin_username" {
  type    = string
  default = "Superman"
}

variable "host_admin_password" {
  type = string
  #default = "Cl@rkK3nt"
  default = ""
}

variable "host_gallery_image" {
  type = object({
    name                = string
    gallery_name        = string
    resource_group_name = string
  })

  default = null
}

variable "host_source_image" {
  type = object({
    publisher = optional(string)
    offer     = optional(string)
    sku       = optional(string)
    version   = optional(string, "latest")
  })

  default = {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "office-365"
    sku       = "win11-22h2-avd-m365"
  }
}

variable "host_extension_parameters" {
  type = object({
    modules_url_add_session_host = optional(string, "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_06-15-2022.zip")
    type_handler_version         = optional(string, "2.73")
  })

  default = {}
}

variable "host_timezone" {
  description = "See https://jackstromberg.com/2017/01/list-of-time-zones-consumed-by-azure/"
  
  type    = string
  default = "W. Europe Standard Time"
}

////////////////////////
// AVD | Workspaces
////////////////////////

variable "workspaces" {
  type = list(object({
    name          = string
    friendly_name = optional(string)
    description   = optional(string)
  }))

  default = [{
    name = "DefaultWorkspace"
  }]
}

////////////////////////
// AVD | Workspace Application Groups
////////////////////////

variable "application_groups" {
  type = list(object({
    name                         = string
    workspace_name               = string
    type                         = optional(string, "Desktop")
    friendly_name                = optional(string)
    description                  = optional(string)
    default_desktop_display_name = optional(string)
  }))

  default = [{
    workspace_name = "DefaultWorkspace"
    type           = "Desktop"
    name           = "RemoteDesktop"
    }, {
    workspace_name = "DefaultWorkspace"
    type           = "RemoteApp"
    name           = "RemoteApps"
  }]
}

////////////////////////
// AVD | Workspace RemoteApp Applications
////////////////////////

variable "applications" {
  type = list(object({
    name                         = string
    application_group_name       = string
    path                         = string
    friendly_name                = optional(string)
    description                  = optional(string)
    icon_path                    = optional(string)
    icon_index                   = optional(number)
    show_in_portal               = optional(bool)
    command_line_argument_policy = optional(string, "DoNotAllow")
    command_line_arguments       = optional(string)
  }))

  default = [{
    application_group_name = "RemoteApps"
    name                   = "notepad"
    friendly_name          = "Notepad"
    description            = "Notepad on Azure Virtual Desktop"
    path                   = "C:\\Program Files\\WindowsApps\\Microsoft.WindowsNotepad_11.2112.32.0_x64__8wekyb3d8bbwe\\Notepad\\Notepad.exe"
    icon_path              = "C:\\Program Files\\WindowsApps\\Microsoft.WindowsNotepad_11.2112.32.0_x64__8wekyb3d8bbwe\\Notepad\\Notepad.exe"
    icon_index             = 0
  }]
}

////////////////////////
// AVD | Autoscaler
////////////////////////

variable "autoscaler_plan_name" {
  type    = string
  default = "default-scaling-plan"
}

variable "autoscaler_plan_friendly_name" {
  type    = string
  default = "Default Scaling Plan"
}

variable "autoscaler_plan_description" {
  type    = string
  default = "Default Scaling Plan for Azure Virtual Desktop"
}

variable "autoscaler_plan_timezone" {
  type    = string
  default = "W. Europe Standard Time"
}

variable "autoscaler_plan_enabled" {
  type    = bool
  default = false
}

variable "autoscaler_plan_schedules" {
  type = list(object({
    name                                 = string
    days_of_week                         = optional(list(string), ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"])
    peak_start_time                      = optional(string, "06:30")
    peak_load_balancing_algorithm        = optional(string, "BreadthFirst")
    off_peak_start_time                  = optional(string, "16:30")
    off_peak_load_balancing_algorithm    = optional(string, "DepthFirst")
    ramp_up_start_time                   = optional(string, "07:30")
    ramp_up_load_balancing_algorithm     = optional(string, "BreadthFirst")
    ramp_up_minimum_hosts_percent        = optional(number, 40)
    ramp_up_capacity_threshold_percent   = optional(number, 20)
    ramp_down_start_time                 = optional(string, "15:30")
    ramp_down_load_balancing_algorithm   = optional(string, "DepthFirst")
    ramp_down_minimum_hosts_percent      = optional(number, 5)
    ramp_down_force_logoff_users         = optional(bool, false)
    ramp_down_wait_time_minutes          = optional(number, 10)
    ramp_down_notification_message       = optional(string, "Please log off in the next 10 minutes")
    ramp_down_capacity_threshold_percent = optional(number, 5)
    ramp_down_stop_hosts_when            = optional(string, "ZeroSessions")
  }))

  default = [{
    name = "standard-schedule"
  }]
}

////////////////////////
// AVD | Azure AD
////////////////////////

variable "aad_group_users" {
  type = object({
    name         = string
    display_name = string
  })

  default = {
    name         = "AVD Users"
    display_name = "Azure Virtual Desktop Users"
  }
}

variable "aad_group_admins" {
  type = object({
    name         = string
    display_name = string
  })

  default = {
    name         = "AVD Administrators"
    display_name = "Azure Virtual Desktop Administrators"
  }
}

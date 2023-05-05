////////////////////////
// Misc
////////////////////////

variable "tags" {
  type    = map(string)
  default = {}
}

variable "resource_group" {
  description = "Used for creating data-source."

  type = object({
    name = string
  })
}

variable "subnet" {
  description = "Used for creating data-source."

  type = object({
    name                 = string
    resource_group_name  = string
    virtual_network_name = string
  })
}

////////////////////////
// Azure AD Groups
////////////////////////

variable "avd_group_users" {
  type = object({
    display_name = string
    description  = optional(string)
  })

  default = {
    display_name = "Azure Virtual Desktop Users"
  }
}

variable "avd_group_admins" {
  type = object({
    display_name = string
    description  = optional(string)
  })

  default = {
    display_name = "Azure Virtual Desktop Administrators"
  }
}

////////////////////////
// Azure Key Vault
////////////////////////

variable "key_vault" {
  type = object({
    prefix                      = optional(string, "kv")
    sku_name                    = optional(string, "standard")
    enabled_for_disk_encryption = optional(bool, true)
    soft_delete_retention_days  = optional(number, 7)
    purge_protection_enabled    = optional(bool, false)
  })

  default = {}
}

////////////////////////
// AVD Host Pool
////////////////////////

variable "host_pool" {
  type = object({
    name                              = optional(string, "default-pool")
    friendly_name                     = optional(string)
    description                       = optional(string)
    pool_type                         = optional(string, "Pooled")
    load_balancer_type                = optional(string, "BreadthFirst")
    validate_environment              = optional(bool, false)
    start_vm_on_connect               = optional(bool, true)
    maximum_sessions_allowed          = optional(number, 10)
    custom_rdp_properties             = optional(string, "targetisaadjoined:i:1;enablerdsaadauth:i:1;redirectlocation:i:1;videoplaybackmode:i:1;audiocapturemode:i:1;audiomode:i:0;")
    scheduled_agent_updates_enabled   = optional(bool, false)
    scheduled_agent_updates_timezone  = optional(string, "W. Europe Standard Time")
    registration_token_rotation_hours = optional(number, 8)

    scheduled_agent_updates = optional(list(object({
      day_of_week = string
      hour_of_day = number
    })), [])
  })

  default = {
    scheduled_agent_updates_enabled = true

    scheduled_agent_updates = [{
      day_of_week = "Saturday"
      hour_of_day = 2
    }]
  }
}

////////////////////////
// AVD Host Pool | Scaling Plan
////////////////////////

variable "scaling_plan" {
  type = object({
    name          = string
    friendly_name = optional(string)
    description   = optional(string)
    time_zone     = optional(string, "W. Europe Standard Time")
    enabled       = optional(bool, true)

    schedules = optional(list(object({
      name                                 = string
      days_of_week                         = list(string)
      ramp_up_start_time                   = optional(string, "05:00")
      peak_start_time                      = optional(string, "09:00")
      ramp_down_start_time                 = optional(string, "15:00")
      off_peak_start_time                  = optional(string, "22:00")
      ramp_up_load_balancing_algorithm     = optional(string, "BreadthFirst")
      peak_load_balancing_algorithm        = optional(string, "BreadthFirst")
      ramp_down_load_balancing_algorithm   = optional(string, "DepthFirst")
      off_peak_load_balancing_algorithm    = optional(string, "DepthFirst")
      ramp_up_minimum_hosts_percent        = optional(number, 10)
      ramp_up_capacity_threshold_percent   = optional(number, 75)
      ramp_down_minimum_hosts_percent      = optional(number, 0)
      ramp_down_capacity_threshold_percent = optional(number, 100)
      ramp_down_wait_time_minutes          = optional(number, 180)
      ramp_down_force_logoff_users         = optional(bool, true)
      ramp_down_notification_message       = optional(string, "Scale down in progress; you will automatically logged out in ~180 minutes.")
      ramp_down_stop_hosts_when            = optional(string, "ZeroActiveSessions")
    })), [])
  })

  default = {
    name = "default-scaling-plan"

    schedules = [{
      name         = "Weekdays"
      days_of_week = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    }]
  }
}

////////////////////////
// AVD Workspaces
////////////////////////

variable "workspaces" {
  type = list(object({
    name          = string
    friendly_name = optional(string)
    description   = optional(string)

    application_groups = optional(list(object({
      name                         = string
      type                         = optional(string, "Desktop")
      friendly_name                = optional(string)
      description                  = optional(string)
      default_desktop_display_name = optional(string)
    })), [])

    applications = optional(list(object({
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
    })), [])
  }))

  default = []
}

////////////////////////
// AVD Session Hosts
////////////////////////

variable "session_hosts" {
  type = object({
    prefix          = optional(string, "sh")
    count           = optional(number, 1)
    size            = optional(string, "Standard_DS2_v2")
    license_type    = optional(string, "None")
    priority        = optional(string, "Regular")
    eviction_policy = optional(string)
    admin_username  = optional(string, "Superman")
    admin_password  = optional(string)
    disk_size_gb    = optional(number)
    timezone        = optional(string, "W. Europe Standard Time")
    source_image_id = optional(string)

    source_image = optional(object({
      publisher = optional(string, "MicrosoftWindowsDesktop")
      offer     = optional(string, "office-365")
      sku       = optional(string, "win11-22h2-avd-m365")
      version   = optional(string, "latest")
    }), {})

    shared_image = optional(object({
      name                = string
      gallery_name        = string
      resource_group_name = string
    }))
  })

  default = {}
}


////////////////////////
// AVD Session Host | Extensions
////////////////////////

variable "session_host_extensions" {
  type = object({
    aad_login_for_windows = optional(object({
      enabled                    = optional(bool, true)
      type_handler_version       = optional(string, "2.0")
      auto_upgrade_minor_version = optional(bool, true)
      automatic_upgrade_enabled  = optional(bool, false)
      intune_registration        = optional(bool, true)
    }), {})

    // This function includes a 6+ minute 'sleep' due to 'Intune' registration
    join_hostpool = optional(object({
      enabled                    = optional(bool, true)
      type_handler_version       = optional(string, "2.83")
      auto_upgrade_minor_version = optional(bool, true)
      automatic_upgrade_enabled  = optional(bool, false)
      modules_url                = optional(string, "https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_04-24-2023.zip") # Working: Configuration_06-15-2022.zip
      modules_function           = optional(string, "Configuration.ps1\\AddSessionHost")                                                                // See https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/scripts/Configuration.ps1
    }), {})

    aadjprivate_registry_update = optional(object({
      enabled                    = optional(bool, true)
      type_handler_version       = optional(string, "1.10")
      auto_upgrade_minor_version = optional(bool, true)
      automatic_upgrade_enabled  = optional(bool, false)
    }), {})

    extra_extensions = optional(list(object({
      name                       = string
      publisher                  = string
      type                       = string
      type_handler_version       = string
      auto_upgrade_minor_version = optional(bool, true)
      automatic_upgrade_enabled  = optional(bool, false)
      json_settings              = optional(string)
      json_protected_settings    = optional(string)
    })), [])
  })

  default = {
    extra_extensions = [{
      name                 = "BGInfo"
      publisher            = "Microsoft.Compute"
      type                 = "BGInfo"
      type_handler_version = "2.2"
    }]
  }
}

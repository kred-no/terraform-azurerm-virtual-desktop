terraform {
  required_version = ">= 1.4.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }

    azuread = {
      source = "hashicorp/azuread"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }

  subscription_id = var.azure.subscription_id // ARM_SUBSCRIPTION_ID
  tenant_id       = var.azure.tenant_id       // ARM_TENANT_ID
}

provider "azuread" {
  tenant_id = var.azure.tenant_id // ARM_TENANT_ID
}

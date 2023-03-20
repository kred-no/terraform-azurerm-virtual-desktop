terraform {
  required_version = ">= 1.4.0"

  required_providers {
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1"
    }

    random = {
      source  = "hashicorp/random"
      version = ">= 3.4.3"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.48.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 2.36.0"
    }
  }
}

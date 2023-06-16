terraform {
  required_providers {
    az = {
        source = "hashicorp/azurerm"
        version = "latest"
    }
  }
}

provider "az" {
  subscription_id = var.az_subscription_id
  skip_provider_registration = true
}


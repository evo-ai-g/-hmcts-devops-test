# versions.tf
#
# Declares which Terraform CLI version and which provider plugins this
# configuration requires. Terraform reads this first, downloads the
# providers, and refuses to run if the installed Terraform is older
# than required_version specifies.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}
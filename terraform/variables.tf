# variables.tf
#
# Every input the configuration accepts. Variables are the interface
# another team consumes: naming them well and describing them clearly
# is what makes this a reusable capability rather than a one-off script.
#
# Anything environment-specific lives here as a variable. Anything
# that is a fact about the code (like "managed by Terraform") is
# hardcoded in main.tf instead — a variable would invite someone to
# change something that isn't a choice.

# ---------------------------------------------------------------
# Location and naming
# ---------------------------------------------------------------

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "uksouth"
}

variable "resource_group_name" {
  description = "Name of the resource group that holds the stack."
  type        = string
  default     = "rg-hmcts-dev-test"
}

variable "project_name" {
  description = "Short project identifier, used as a prefix for resource names."
  type        = string
  default     = "hmcts-dev-test"
}

# ---------------------------------------------------------------
# Tagging
# ---------------------------------------------------------------
# Applied to every resource via local.common_tags in main.tf.
# See docs/adr/0006-azure-tagging-strategy.md for the reasoning
# behind this specific set.

variable "environment" {
  description = "Deployment environment. Distinguishes dev/staging/prod."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  description = "Team or individual accountable for these resources."
  type        = string
  default     = "platform-team"
}

variable "cost_centre" {
  description = "Cost centre for billing attribution."
  type        = string
  default     = "engineering"
}

variable "data_classification" {
  description = "UK government data classification. One of: official, secret, top-secret."
  type        = string
  default     = "official"

  validation {
    condition     = contains(["official", "secret", "top-secret"], var.data_classification)
    error_message = "data_classification must follow the UK government scheme: official, secret, or top-secret."
  }
}

# ---------------------------------------------------------------
# PostgreSQL
# ---------------------------------------------------------------

variable "postgres_server_name" {
  description = "Name of the PostgreSQL Flexible Server. Must be globally unique."
  type        = string
  default     = "psql-hmcts-dev-test"
}

variable "postgres_admin_username" {
  description = "Administrator username for the PostgreSQL server."
  type        = string
  default     = "psqladmin"
}

variable "postgres_admin_password" {
  description = "Administrator password. Supplied at apply time via TF_VAR_postgres_admin_password or a tfvars file. Never committed."
  type        = string
  sensitive   = true
}

variable "postgres_version" {
  description = "Major version of PostgreSQL."
  type        = string
  default     = "16"
}

variable "postgres_sku_name" {
  description = "SKU for the Flexible Server. B_Standard_B1ms is the smallest burstable tier, appropriate for dev."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgres_storage_mb" {
  description = "Storage size in MB."
  type        = number
  default     = 32768
}

variable "database_name" {
  description = "Name of the database created inside the PostgreSQL server."
  type        = string
  default     = "devtest"
}

# ---------------------------------------------------------------
# Container Apps
# ---------------------------------------------------------------

variable "container_app_name" {
  description = "Name of the Container App running the application."
  type        = string
  default     = "ca-hmcts-dev-test"
}

variable "container_image" {
  description = "Container image to deploy. Should be the immutable SHA-tagged image from CI, not a moving tag."
  type        = string
  default     = "hmcts-devops-test:main-latest"
}

variable "container_cpu" {
  description = "CPU cores allocated to each replica."
  type        = number
  default     = 0.5
}

variable "container_memory" {
  description = "Memory allocated to each replica. Must be compatible with container_cpu per Container Apps rules."
  type        = string
  default     = "1Gi"
}

variable "container_min_replicas" {
  description = "Minimum number of replicas. Set to 0 to allow scale-to-zero (dev); 1 or more for availability (prod)."
  type        = number
  default     = 0
}

variable "container_max_replicas" {
  description = "Maximum number of replicas for autoscaling."
  type        = number
  default     = 3
}

# ---------------------------------------------------------------
# Key Vault
# ---------------------------------------------------------------

variable "key_vault_name" {
  description = "Name of the Key Vault. Must be globally unique across Azure."
  type        = string
  default     = "kv-hmcts-dev-test"
}

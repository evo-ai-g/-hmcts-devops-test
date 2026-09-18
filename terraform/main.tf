# main.tf
#
# The resources themselves. Every resource gets the common tags from
# local.common_tags. Every environment-specific value comes from a
# variable in variables.tf. Nothing here is hardcoded that shouldn't be.

# ---------------------------------------------------------------
# Locals
# ---------------------------------------------------------------
# Computed values used across multiple resources. Defining the tag
# map once means adding a tag is a one-line change, not six.

locals {
  common_tags = {
    environment         = var.environment
    project             = var.project_name
    owner               = var.owner
    cost-centre         = var.cost_centre
    data-classification = var.data_classification
    # Hardcoded, not a variable: it is a fact about how the resource
    # was created, not a choice. See ADR 0006.
    managed-by = "terraform"
  }
}

# ---------------------------------------------------------------
# Resource group
# ---------------------------------------------------------------
# The container for every other resource. Deleting this deletes the
# whole stack — which is the point of grouping.

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# ---------------------------------------------------------------
# Log Analytics workspace
# ---------------------------------------------------------------
# Required by the Container Apps Environment. Container stdout and
# stderr are streamed here for centralised logging and querying.

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.common_tags
}

# ---------------------------------------------------------------
# Container Apps Environment
# ---------------------------------------------------------------
# The shared runtime that Container Apps run inside. Provides the
# network, the log pipeline, and shared configuration. Roughly the
# equivalent of a Kubernetes namespace, without the cluster to manage.

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${var.project_name}-${var.environment}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  tags                       = local.common_tags
}

# ---------------------------------------------------------------
# PostgreSQL Flexible Server
# ---------------------------------------------------------------
# Azure's managed Postgres. The app connects to this exactly as it
# connects to the Compose Postgres locally — same JDBC URL, different
# host. See ADR 0001 for why we're on JDBC rather than JPA.

resource "azurerm_postgresql_flexible_server" "postgres" {
  name                = var.postgres_server_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  version    = var.postgres_version
  sku_name   = var.postgres_sku_name
  storage_mb = var.postgres_storage_mb

  administrator_login    = var.postgres_admin_username
  administrator_password = var.postgres_admin_password

  # Allow Azure services (including our Container App) to connect.
  # In production this would be replaced by VNet integration, but
  # for a design-only exercise the firewall rule is the standard
  # minimal connectivity path.
  public_network_access_enabled = true

  tags = local.common_tags
}

# Allow Azure-internal traffic (service endpoints, the container
# platform) to reach the server. 0.0.0.0 within Azure means "any
# service inside Azure", not "the internet".
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.postgres.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# The database inside the server. A server can hold many databases;
# this creates the one the app expects (`DB_NAME` from .env).
resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.postgres.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# ---------------------------------------------------------------
# Key Vault
# ---------------------------------------------------------------
# Managed secret storage. The DB password lives here, not in the
# Container App's config. The Container App reads it at runtime via
# a system-assigned managed identity — the password never appears
# in the app's environment variables or in Terraform state at the
# Container App level.

resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Standard tier is enough for secrets (no HSM-backed keys needed).
  sku_name = "standard"

  # Azure AD is the identity provider; access is granted via RBAC.
  tenant_id = data.azurerm_client_config.current.tenant_id

  # Purge protection means a deleted vault cannot be permanently
  # removed until the retention period expires. Guards against
  # accidental or malicious destruction of secrets.
  purge_protection_enabled = false # false for dev; true for prod

  tags = local.common_tags
}

# The Postgres password, stored as a secret. This is the source of
# truth for the app's DB_PASSWORD at runtime.
resource "azurerm_key_vault_secret" "postgres_admin_password" {
  name         = "postgres-admin-password"
  value        = var.postgres_admin_password
  key_vault_id = azurerm_key_vault.main.id

  tags = local.common_tags
}

# ---------------------------------------------------------------
# Container App
# ---------------------------------------------------------------
# The running application. References the environment, the image,
# the DB coordinates, and the Key Vault secret. HTTPS ingress is
# managed by Azure — TLS certificate provisioned and rotated for us.

resource "azurerm_container_app" "app" {
  name                         = var.container_app_name
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  # System-assigned managed identity. Azure creates a service
  # principal for the app; we grant it read access to Key Vault
  # secrets below. No credentials to manage or rotate.
  identity {
    type = "SystemAssigned"
  }

  template {
    min_replicas = var.container_min_replicas
    max_replicas = var.container_max_replicas

    container {
      name   = "app"
      image  = var.container_image
      cpu    = var.container_cpu
      memory = var.container_memory

      # The app's own config: DB_HOST/DB_PORT/DB_NAME/DB_USER_NAME
      # come from variables here. DB_PASSWORD comes from the secret
      # block below, not from a plain env var.
      env {
        name  = "DB_HOST"
        value = azurerm_postgresql_flexible_server.postgres.fqdn
      }
      env {
        name  = "DB_PORT"
        value = "5432"
      }
      env {
        name  = "DB_NAME"
        value = var.database_name
      }
      env {
        name  = "DB_USER_NAME"
        value = var.postgres_admin_username
      }
      env {
        name        = "DB_PASSWORD"
        secret_name = "postgres-admin-password"
      }
      env {
        name  = "SERVER_PORT"
        value = "4000"
      }
    }
  }

  # Secret definition. Rather than storing the password directly in
  # the Container App, we reference the Key Vault secret. The
  # identity block above grants read access.
  secret {
    name                = "postgres-admin-password"
    key_vault_secret_id = azurerm_key_vault_secret.postgres_admin_password.versionless_id
    identity            = "System"
  }

  ingress {
    external_enabled = true
    target_port      = 4000
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = local.common_tags
}

# Grant the Container App's managed identity read access to Key
# Vault secrets. This is the modern RBAC approach; the older
# access-policy model is being phased out.
resource "azurerm_role_assignment" "app_kv_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_container_app.app.identity[0].principal_id
}

# ---------------------------------------------------------------
# Data sources
# ---------------------------------------------------------------
# Read-only lookups. The current Azure client's tenant ID is needed
# to configure Key Vault's identity provider.

data "azurerm_client_config" "current" {}
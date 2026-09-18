# outputs.tf
#
# What this configuration produces for its consumers. Outputs are the
# return values of the module — the interface another team uses to
# wire this stack into theirs.
#
# Every output has a description. Sensitive values are marked
# `sensitive = true` so they don't appear in CLI output. Note that
# `sensitive` is a display concern, not a storage one — the state
# file still contains the values and must be encrypted at rest.

output "resource_group_name" {
  description = "Name of the resource group holding the stack."
  value       = azurerm_resource_group.main.name
}

output "container_app_url" {
  description = "Public HTTPS URL of the Container App."
  value       = "https://${azurerm_container_app.app.latest_revision_fqdn}"
}

output "postgres_fqdn" {
  description = "Fully qualified domain name of the PostgreSQL server. This is the value the app uses as DB_HOST."
  value       = azurerm_postgresql_flexible_server.postgres.fqdn
}

output "postgres_database_name" {
  description = "Name of the database inside the PostgreSQL server."
  value       = azurerm_postgresql_flexible_server_database.main.name
}

output "postgres_admin_username" {
  description = "Administrator username for the PostgreSQL server."
  value       = var.postgres_admin_username
}

output "key_vault_uri" {
  description = "URI of the Key Vault. Consumers reference secrets as <uri>/secrets/<name>."
  value       = azurerm_key_vault.main.vault_uri
}

output "key_vault_secret_name" {
  description = "Name of the Key Vault secret holding the PostgreSQL admin password."
  value       = azurerm_key_vault_secret.postgres_admin_password.name
}

# Marked sensitive. The value appears in state but not in CLI output,
# CI logs, or plan files rendered to a terminal. Storage encryption
# is a separate concern handled by the backend (see backend.tf).
output "postgres_admin_password" {
  description = "PostgreSQL admin password. Read from Key Vault at runtime by the Container App; exposed here for operator use."
  value       = var.postgres_admin_password
  sensitive   = true
}

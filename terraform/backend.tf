# backend.tf
#
# Remote state configuration.
#
# Commented out by default. A remote backend requires an Azure Storage
# account that must already exist before Terraform runs — and this
# repository is design-only (no Azure account). The block below is
# what you would uncomment for a real deployment.
#
# WHY REMOTE STATE AT ALL
#
# Terraform's state file is the source of truth for what it manages.
# Local state (terraform.tfstate on your machine) has three fatal
# problems the moment more than one person or machine touches the
# configuration:
#
#   1. Not shareable. If your teammate runs apply, their state file
#      diverges from yours. Next apply by either of you can destroy
#      resources the other one created, because each thinks it knows
#      what exists.
#
#   2. No locking. Two concurrent applies race each other. Both read
#      the same state, both decide to create the same resource, both
#      write back, and one clobbers the other. Result: orphaned
#      resources in Azure that Terraform no longer tracks.
#
#   3. Not encrypted, not backed up. The state file contains secrets
#      in plaintext — the PostgreSQL admin password, for example,
#      appears verbatim in terraform.tfstate. On a laptop this is a
#      file in a home directory. In a remote backend it can be
#      encrypted at rest and access-controlled.
#
# Every one of those is a reason no real deployment uses local state.

# terraform {
#   backend "azurerm" {
#     resource_group_name  = "rg-tfstate"
#     storage_account_name = "sttfstatehmcts"
#     container_name       = "tfstate"
#
#     # STATE ISOLATION PER ENVIRONMENT
#     #
#     # The `key` is the blob path within the container. One key per
#     # environment means each environment's state file is fully
#     # isolated — a dev apply cannot read, write, or destroy prod
#     # resources, because it can't even see prod's state.
#     #
#     # The convention below is <project>/<environment>.tfstate. An
#     # equally valid convention is <environment>/<project>.tfstate.
#     # The convention matters less than picking one and being
#     # consistent across every project in the organisation.
#     key = "hmcts-dev-test/dev.tfstate"
#
#     # For staging and prod, the CI pipeline would apply with a
#     # different -backend-config or a different tfvars file pointing
#     # at key = "hmcts-dev-test/staging.tfstate", etc.
#
#     # Use Azure AD rather than storage account keys. This means the
#     # caller must have the "Storage Blob Data Contributor" role on
#     # the container, and there is no long-lived key to rotate or
#     # leak. See ADR 0007.
#     use_azuread_auth = true
#   }
# }
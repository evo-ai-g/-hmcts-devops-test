# 0007 — Terraform state management strategy

## Status

Accepted

## Context

Terraform's state file records what the configuration manages. It must
be shared between operators, locked during apply, and encrypted at rest
because it contains secret values in plaintext — including the
PostgreSQL admin password in this configuration.

Four strategies for isolating environments were considered:

1. **Local state.** Single operator only. Not shareable, no locking,
   no encryption. Rejected outright.
2. **Terraform workspaces.** Parallel state per workspace in one
   backend. Shares config, backend, and IAM. The "isolation" is a
   naming convention, not a security boundary. Microsoft's guidance
   is to use workspaces for ephemeral developer sandboxes, not for
   environment separation.
3. **Separate blob key per environment, one container.** Isolated by
   path within a single storage account. Depends on IAM being correct
   to prevent cross-environment access.
4. **Separate storage account per environment.** Strongest isolation.
   Compromise of dev credentials cannot reach prod state. Requires
   three storage accounts, three sets of RBAC, three CI secret scopes.

## Decision

Use **option 3**: a single Azure Storage account and container, with
one blob key per environment following the convention
`<project>/<environment>.tfstate`. The backend block is commented out
in `backend.tf` because this repository is design-only.

Authentication to the backend uses **Azure AD** (`use_azuread_auth = true`),
not storage account access keys. The caller must hold the "Storage Blob
Data Contributor" role on the container.

## Consequences

- Dev, staging, and prod each get an isolated state file. An apply in
  dev cannot read, write, or destroy prod resources — provided IAM is
  configured correctly.
- The isolation guarantee depends on RBAC. It is not a technical
  boundary — nothing stops a dev identity from attempting to read the
  prod key. Mitigated by scoping role assignments carefully; stronger
  isolation (option 4) is available if the security posture requires it.
- No storage account access keys exist. Nothing to rotate, nothing to
  leak. This is the primary reason for choosing Azure AD over shared
  keys.
- Migrating from local to remote state is a one-time operation:
  `terraform init -migrate-state`.
- Adding a new environment (e.g. `uat`) is a new tfvars file, not new
  infrastructure. The storage account, container, and IAM already
  exist.

## Alternatives not taken

- **Terraform workspaces.** Rejected because they share a single
  backend and IAM context. The appearance of isolation without the
  guarantee is worse than no isolation, because it can lead to
  false confidence when reviewing access controls.
- **Separate storage account per environment.** Rejected for this
  project's scale. It is the right answer for regulated workloads
  where the cost of an access-control failure is high. It remains
  the documented upgrade path if requirements change.
---
name: terraform-init
description: Initialize a Terraform working directory — download providers, configure backends, install modules. Use when setting up a new Terraform project, cloning an existing one, or changing backend/provider configuration.
---

# Terraform Init

Initialize a Terraform working directory to prepare it for plan and apply operations.

## When to Use

- Starting a new Terraform project after writing `.tf` files
- Cloning an existing Terraform repository for the first time
- After adding or changing provider version constraints in `required_providers`
- After adding or changing `module` blocks with new sources
- After modifying the `backend` configuration block
- When provider lock file (`.terraform.lock.hcl`) is missing or stale

## Workflow

1. **Check prerequisites**: Ensure `terraform` is installed (`terraform version`)
2. **Navigate to config directory**: `cd` to the directory containing `.tf` files
3. **Run init**: Execute `terraform init` with appropriate flags
4. **Verify**: Confirm providers installed and backend configured

## Basic Commands

```bash
# Standard init
terraform init

# Non-interactive (CI/CD)
terraform init -input=false

# Upgrade all providers and modules
terraform init -upgrade

# Reconfigure backend (no state migration)
terraform init -reconfigure

# Migrate state to new backend
terraform init -migrate-state
```

## Backend Configuration at Runtime

Pass sensitive or environment-specific backend settings at init time:

```bash
terraform init \
  -backend-config="bucket=my-state-bucket" \
  -backend-config="key=prod/terraform.tfstate" \
  -backend-config="region=us-east-1"

# Or from a file
terraform init -backend-config=backend.hcl
```

## CI/CD Pattern

```bash
export TF_IN_AUTOMATION=true
export TF_INPUT=0
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"

mkdir -p "$TF_PLUGIN_CACHE_DIR"
terraform init -lockfile=readonly
```

## Key Flags Reference

| Flag | Purpose |
|------|---------|
| `-input=false` | Disable prompts |
| `-upgrade` | Update providers/modules |
| `-reconfigure` | Reset backend config |
| `-migrate-state` | Move state to new backend |
| `-backend-config=K=V` | Runtime backend settings |
| `-lockfile=readonly` | Fail if lock file stale |
| `-plugin-dir=PATH` | Local provider mirror |
| `-get=false` | Skip module download |

## Edge Cases

- **First init with remote backend**: Terraform creates the state file in the remote backend; the backend storage (S3 bucket, GCS bucket) must already exist
- **Backend change without `-migrate-state`**: Terraform errors — you must choose `-reconfigure` (fresh start) or `-migrate-state` (copy state)
- **Lock file conflicts**: When teammates update providers, pull their `.terraform.lock.hcl` changes and re-run `terraform init`
- **Air-gapped environments**: Pre-download providers and use `-plugin-dir` to point to the local mirror
- **Monorepos**: Each Terraform root module needs its own `terraform init` — there is no workspace-level init

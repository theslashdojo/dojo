---
name: terraform-state
description: Inspect and manipulate Terraform state — list, show, move, remove, import, and pull/push resources. Use when refactoring resource names, removing resources from management, importing existing infrastructure, or debugging state issues.
---

# Terraform State

Manage the mapping between Terraform configuration and real-world infrastructure.

## When to Use

- **Inspecting**: View which resources Terraform manages (`state list`, `state show`)
- **Refactoring**: Rename resources without destroy/recreate (`state mv`)
- **Un-managing**: Stop managing a resource without destroying it (`state rm`)
- **Importing**: Bring existing infrastructure under Terraform management (`import`)
- **Debugging**: Pull remote state for inspection (`state pull`)
- **Recovery**: Push repaired state to remote backend (`state push`)
- **Provider migration**: Switch provider source addresses (`state replace-provider`)

## Core Commands

```bash
# List all tracked resources
terraform state list

# Show details for a specific resource
terraform state show aws_instance.web

# Rename a resource (refactoring)
terraform state mv aws_instance.web aws_instance.app_server

# Move resource into a module
terraform state mv aws_instance.web module.compute.aws_instance.web

# Remove resource from state (keeps real infra)
terraform state rm aws_instance.legacy

# Import existing infrastructure
terraform import aws_instance.web i-0abcdef1234567890

# Pull remote state to stdout
terraform state pull

# Push local state to remote
terraform state push terraform.tfstate

# Replace provider in state
terraform state replace-provider hashicorp/aws registry.terraform.io/hashicorp/aws
```

## Workflow: Refactoring with state mv

```bash
# 1. Rename the resource in your .tf file
# 2. Run state mv to update state mapping
terraform state mv aws_instance.old_name aws_instance.new_name

# 3. Verify: plan should show no changes
terraform plan
# => No changes. Infrastructure is up-to-date.
```

Without `state mv`, renaming a resource block causes Terraform to destroy the old and create a new one.

## Workflow: Importing Existing Resources

```bash
# 1. Write the resource block in your .tf file
# 2. Import the real resource into state
terraform import aws_s3_bucket.data my-existing-bucket-name

# 3. Run plan to verify config matches reality
terraform plan
# => Fix any diffs, then re-plan until clean
```

## Safety

- All state-modifying commands create automatic backups (`terraform.tfstate.backup`)
- Backups cannot be disabled — they are always created
- Never edit `terraform.tfstate` manually
- For teams, always use remote backends with locking
- State files contain sensitive data — encrypt at rest, restrict access

## Edge Cases

- **Locked state**: If another process holds the lock, use `-lock-timeout=60s` to wait. Use `terraform force-unlock <LOCK_ID>` only as a last resort
- **State version mismatch**: Occurs when state was written by a newer Terraform version. Upgrade your Terraform binary to match
- **Moved resources between modules**: `terraform state mv` supports cross-module moves: `terraform state mv aws_instance.web module.compute.aws_instance.web`
- **Count/for_each changes**: When changing from single resource to count, use `terraform state mv 'aws_instance.web' 'aws_instance.web[0]'`

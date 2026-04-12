---
name: terraform-plan
description: Preview Terraform infrastructure changes by computing the diff between configuration and real-world state. Use when you need to see what terraform apply will do before executing it.
---

# Terraform Plan

Compute an execution plan showing what Terraform will create, modify, or destroy.

## When to Use

- Before any `terraform apply` to review changes
- To detect infrastructure drift (`-refresh-only`)
- To preview resource destruction (`-destroy`)
- In CI/CD pipelines to gate deployments (`-detailed-exitcode`)
- When debugging by targeting specific resources (`-target`)

## Workflow

1. Ensure working directory is initialized (`terraform init`)
2. Run `terraform plan` to preview changes
3. Review the plan output carefully
4. Save the plan with `-out=tfplan` for production workflows
5. Apply the saved plan: `terraform apply tfplan`

## Core Commands

```bash
# Basic plan
terraform plan

# Save plan for later apply (recommended for production)
terraform plan -out=tfplan

# Plan with variables
terraform plan -var='env=prod' -var-file=prod.tfvars

# Plan destruction
terraform plan -destroy

# Detect drift without changing infra
terraform plan -refresh-only

# Target specific resource
terraform plan -target=aws_instance.web

# Force resource replacement
terraform plan -replace=aws_instance.web

# CI/CD: get exit code 2 when changes exist
terraform plan -detailed-exitcode -out=tfplan
```

## Reading Plan Output

```
+ create       — new resource
- destroy      — remove existing resource
~ update       — in-place modification
-/+ replace    — destroy and recreate
<= read        — data source lookup
```

Summary line: `Plan: 3 to add, 1 to change, 0 to destroy.`

## CI/CD Pattern

```bash
terraform plan -detailed-exitcode -out=tfplan -input=false
EXIT_CODE=$?

case $EXIT_CODE in
  0) echo "No changes" ;;
  1) echo "Error" ; exit 1 ;;
  2) echo "Changes detected" ;;
esac
```

## Edge Cases

- **Plan file is binary and contains secrets**: Treat saved plans as sensitive artifacts; do not commit to git
- **Targeting skips validation of non-targeted resources**: Use only for recovery, not regular workflow
- **`-refresh=false` may produce stale plans**: Only use when you know state is current
- **Concurrent plans**: State locking prevents conflicts; use `-lock-timeout` in CI to handle contention
- **Large state performance**: Reduce `-parallelism` or use `-target` to plan subsets

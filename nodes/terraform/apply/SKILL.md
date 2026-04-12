---
name: terraform-apply
description: Execute a Terraform plan to create, update, or destroy real infrastructure. Use when you need to apply planned changes to cloud resources, provision new infrastructure, or tear down environments.
---

# Terraform Apply

Execute infrastructure changes computed by `terraform plan`.

## When to Use

- After reviewing a `terraform plan` to deploy changes
- To provision new infrastructure from scratch
- To update existing infrastructure after config changes
- To destroy all managed resources (`-destroy`)
- In CI/CD pipelines for automated deployments

## Workflow

### Production (recommended)

```bash
# 1. Initialize
terraform init -input=false

# 2. Plan and save
terraform plan -out=tfplan -input=false

# 3. Review plan output (human or automated check)

# 4. Apply saved plan (no confirmation needed)
terraform apply -input=false tfplan

# 5. Verify
terraform output -json
```

### Development (quick iteration)

```bash
terraform apply -auto-approve
```

## Core Commands

```bash
# Apply with confirmation prompt
terraform apply

# Apply saved plan (skip confirmation)
terraform apply tfplan

# Auto-approve (CI/CD)
terraform apply -auto-approve

# Apply with variables
terraform apply -var='env=prod' -var-file=prod.tfvars

# Target specific resource
terraform apply -target=aws_instance.web

# Force resource replacement
terraform apply -replace=aws_instance.web

# Destroy all resources
terraform apply -destroy

# JSON output for machine consumption
terraform apply -auto-approve -json
```

## CI/CD Pattern

```bash
export TF_IN_AUTOMATION=true
export TF_INPUT=0

terraform init -input=false -lockfile=readonly
terraform plan -out=tfplan -input=false
terraform apply -input=false tfplan
terraform output -json > outputs.json
rm -f tfplan
```

## Edge Cases

- **Partial failure**: If apply fails midway, state is partially updated. Re-run `terraform apply` safely — Terraform only applies remaining changes
- **State lock contention**: Use `-lock-timeout=60s` in CI environments where multiple pipelines may overlap
- **Stale saved plans**: Terraform rejects plan files if state or config changed since the plan was generated — re-plan
- **Sensitive outputs**: Apply prints output values to stdout; mark sensitive outputs with `sensitive = true`
- **Resource timeouts**: Some cloud resources take minutes to create; increase `-parallelism` or use provider-level timeouts

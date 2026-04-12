#!/usr/bin/env bash
# terraform-init.sh — Initialize a Terraform working directory
# Handles backend configuration, provider installation, module download, and state migration.
set -euo pipefail

WORKING_DIR="${TF_WORKING_DIR:-.}"
UPGRADE="${TF_UPGRADE:-false}"
MIGRATE="${TF_MIGRATE_STATE:-false}"
BACKEND_CONFIG="${TF_BACKEND_CONFIG:-}"

cd "$WORKING_DIR"

echo "=== Terraform Init ==="
echo "Working directory: $(pwd)"

# Build init arguments
INIT_ARGS=("-input=false")

if [[ "$UPGRADE" == "true" ]]; then
  INIT_ARGS+=("-upgrade")
  echo "Mode: upgrade providers and modules"
fi

if [[ "$MIGRATE" == "true" ]]; then
  INIT_ARGS+=("-migrate-state" "-force-copy")
  echo "Mode: migrate state to new backend"
fi

# Handle backend config: can be a file path or comma-separated KEY=VALUE pairs
if [[ -n "$BACKEND_CONFIG" ]]; then
  IFS=',' read -ra CONFIGS <<< "$BACKEND_CONFIG"
  for config in "${CONFIGS[@]}"; do
    config="$(echo "$config" | xargs)"  # trim whitespace
    INIT_ARGS+=("-backend-config=$config")
  done
  echo "Backend config: $BACKEND_CONFIG"
fi

echo ""
terraform init "${INIT_ARGS[@]}"

echo ""
echo "=== Init Complete ==="

# Show installed providers
echo ""
echo "Installed providers:"
terraform providers 2>/dev/null || true

# Show backend info
echo ""
echo "Backend type:"
if [[ -f .terraform/terraform.tfstate ]]; then
  grep -o '"type":"[^"]*"' .terraform/terraform.tfstate 2>/dev/null | head -1 || echo "local"
else
  echo "local (default)"
fi

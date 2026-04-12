#!/usr/bin/env bash
# terraform-apply.sh — Apply Terraform changes from a saved plan or with auto-approve.
set -euo pipefail

WORKING_DIR="${TF_WORKING_DIR:-.}"
PLAN_FILE="${TF_PLAN_FILE:-}"
VAR_FILE="${TF_VAR_FILE:-}"
TARGETS="${TF_TARGETS:-}"
AUTO_APPROVE="${TF_AUTO_APPROVE:-true}"
PARALLELISM="${TF_PARALLELISM:-10}"

cd "$WORKING_DIR"

echo "=== Terraform Apply ==="
echo "Working directory: $(pwd)"

APPLY_ARGS=("-input=false" "-parallelism=$PARALLELISM")

if [[ -n "$PLAN_FILE" ]]; then
  # Saved plan mode
  if [[ ! -f "$PLAN_FILE" ]]; then
    echo "ERROR: Plan file not found: $PLAN_FILE"
    exit 1
  fi
  echo "Mode: saved plan ($PLAN_FILE)"
  # Saved plans don't accept -auto-approve, -var, -target flags
  APPLY_ARGS+=("$PLAN_FILE")
else
  # Automatic plan mode
  echo "Mode: automatic plan"

  if [[ "$AUTO_APPROVE" == "true" ]]; then
    APPLY_ARGS+=("-auto-approve")
  fi

  # Variable file
  if [[ -n "$VAR_FILE" ]]; then
    if [[ ! -f "$VAR_FILE" ]]; then
      echo "ERROR: Variable file not found: $VAR_FILE"
      exit 1
    fi
    APPLY_ARGS+=("-var-file=$VAR_FILE")
    echo "Variable file: $VAR_FILE"
  fi

  # Targets (comma-separated)
  if [[ -n "$TARGETS" ]]; then
    IFS=',' read -ra TARGET_LIST <<< "$TARGETS"
    for target in "${TARGET_LIST[@]}"; do
      target="$(echo "$target" | xargs)"
      APPLY_ARGS+=("-target=$target")
    done
    echo "Targets: $TARGETS"
  fi
fi

echo ""
terraform apply "${APPLY_ARGS[@]}"

echo ""
echo "=== Apply Complete ==="

# Show outputs
echo ""
echo "Outputs:"
terraform output 2>/dev/null || echo "(no outputs defined)"

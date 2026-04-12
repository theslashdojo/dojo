#!/usr/bin/env bash
# terraform-plan.sh — Run terraform plan with configurable mode, variables, targets, and saved output.
set -euo pipefail

WORKING_DIR="${TF_WORKING_DIR:-.}"
PLAN_FILE="${TF_PLAN_FILE:-tfplan}"
VAR_FILE="${TF_VAR_FILE:-}"
TARGETS="${TF_TARGETS:-}"
MODE="${TF_PLAN_MODE:-normal}"

cd "$WORKING_DIR"

echo "=== Terraform Plan ==="
echo "Working directory: $(pwd)"
echo "Mode: $MODE"
echo "Plan file: $PLAN_FILE"

PLAN_ARGS=("-input=false" "-out=$PLAN_FILE")

# Planning mode
case "$MODE" in
  destroy)
    PLAN_ARGS+=("-destroy")
    echo "Planning destruction of all resources"
    ;;
  refresh-only)
    PLAN_ARGS+=("-refresh-only")
    echo "Refresh-only: updating state without changing infrastructure"
    ;;
  normal)
    echo "Normal mode: converging to configuration"
    ;;
  *)
    echo "ERROR: Unknown mode '$MODE'. Use: normal, destroy, refresh-only"
    exit 1
    ;;
esac

# Variable file
if [[ -n "$VAR_FILE" ]]; then
  if [[ ! -f "$VAR_FILE" ]]; then
    echo "ERROR: Variable file not found: $VAR_FILE"
    exit 1
  fi
  PLAN_ARGS+=("-var-file=$VAR_FILE")
  echo "Variable file: $VAR_FILE"
fi

# Targets (comma-separated)
if [[ -n "$TARGETS" ]]; then
  IFS=',' read -ra TARGET_LIST <<< "$TARGETS"
  for target in "${TARGET_LIST[@]}"; do
    target="$(echo "$target" | xargs)"
    PLAN_ARGS+=("-target=$target")
  done
  echo "Targets: $TARGETS"
fi

echo ""
terraform plan "${PLAN_ARGS[@]}"
EXIT_CODE=$?

echo ""
echo "=== Plan Complete ==="
echo "Saved plan to: $PLAN_FILE"
echo ""
echo "To apply this plan:"
echo "  terraform apply $PLAN_FILE"

exit $EXIT_CODE

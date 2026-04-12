#!/usr/bin/env bash
# manage-state.sh — Terraform state management operations: list, show, mv, rm, pull, push, import.
set -euo pipefail

WORKING_DIR="${TF_WORKING_DIR:-.}"
ACTION="${TF_STATE_ACTION:-list}"
RESOURCE="${TF_STATE_RESOURCE:-}"
DESTINATION="${TF_STATE_DESTINATION:-}"
IMPORT_ID="${TF_IMPORT_ID:-}"

cd "$WORKING_DIR"

echo "=== Terraform State: $ACTION ==="
echo "Working directory: $(pwd)"

case "$ACTION" in
  list)
    echo "Listing all managed resources:"
    echo ""
    terraform state list
    ;;

  show)
    if [[ -z "$RESOURCE" ]]; then
      echo "ERROR: TF_STATE_RESOURCE is required for 'show'"
      exit 1
    fi
    echo "Showing resource: $RESOURCE"
    echo ""
    terraform state show "$RESOURCE"
    ;;

  mv)
    if [[ -z "$RESOURCE" || -z "$DESTINATION" ]]; then
      echo "ERROR: TF_STATE_RESOURCE and TF_STATE_DESTINATION are required for 'mv'"
      exit 1
    fi
    echo "Moving: $RESOURCE -> $DESTINATION"
    echo ""
    terraform state mv "$RESOURCE" "$DESTINATION"
    echo "Move completed successfully."
    ;;

  rm)
    if [[ -z "$RESOURCE" ]]; then
      echo "ERROR: TF_STATE_RESOURCE is required for 'rm'"
      exit 1
    fi
    echo "Removing from state (not destroying real resource): $RESOURCE"
    echo ""
    terraform state rm "$RESOURCE"
    echo "Resource removed from state. The real infrastructure is untouched."
    ;;

  pull)
    echo "Pulling remote state to stdout:"
    echo ""
    terraform state pull
    ;;

  push)
    if [[ -z "$RESOURCE" ]]; then
      echo "ERROR: TF_STATE_RESOURCE must be set to the path of the state file for 'push'"
      exit 1
    fi
    echo "Pushing local state file to remote backend: $RESOURCE"
    echo ""
    terraform state push "$RESOURCE"
    echo "State pushed successfully."
    ;;

  import)
    if [[ -z "$RESOURCE" || -z "$IMPORT_ID" ]]; then
      echo "ERROR: TF_STATE_RESOURCE (address) and TF_IMPORT_ID (real-world ID) are required for 'import'"
      exit 1
    fi
    echo "Importing: $IMPORT_ID -> $RESOURCE"
    echo ""
    terraform import "$RESOURCE" "$IMPORT_ID"
    echo "Import completed. Run 'terraform plan' to verify."
    ;;

  replace-provider)
    if [[ -z "$RESOURCE" || -z "$DESTINATION" ]]; then
      echo "ERROR: TF_STATE_RESOURCE (old provider) and TF_STATE_DESTINATION (new provider) are required"
      exit 1
    fi
    echo "Replacing provider: $RESOURCE -> $DESTINATION"
    echo ""
    terraform state replace-provider -auto-approve "$RESOURCE" "$DESTINATION"
    echo "Provider replaced successfully."
    ;;

  *)
    echo "ERROR: Unknown action '$ACTION'"
    echo "Valid actions: list, show, mv, rm, pull, push, import, replace-provider"
    exit 1
    ;;
esac

echo ""
echo "=== Done ==="

#!/usr/bin/env bash
# Manage Compute Engine VM instances — create, list, start, stop, delete, describe, ssh
# Usage: ACTION=create INSTANCE_NAME=my-vm ./manage-instance.sh
set -euo pipefail

ACTION="${ACTION:?ACTION is required (create|list|start|stop|delete|describe|ssh)}"
INSTANCE_NAME="${INSTANCE_NAME:-}"
ZONE="${CLOUDSDK_COMPUTE_ZONE:-us-central1-a}"
PROJECT="${GOOGLE_CLOUD_PROJECT:?GOOGLE_CLOUD_PROJECT is required}"
MACHINE_TYPE="${MACHINE_TYPE:-e2-medium}"
IMAGE_FAMILY="${IMAGE_FAMILY:-debian-12}"
IMAGE_PROJECT="${IMAGE_PROJECT:-debian-cloud}"
DISK_SIZE="${DISK_SIZE:-50GB}"
DISK_TYPE="${DISK_TYPE:-pd-balanced}"
TAGS="${TAGS:-}"
STARTUP_SCRIPT="${STARTUP_SCRIPT:-}"

# Verify gcloud is available
if ! command -v gcloud &>/dev/null; then
  echo "ERROR: gcloud CLI is not installed. Install from https://cloud.google.com/sdk/docs/install" >&2
  exit 1
fi

case "$ACTION" in
  create)
    if [[ -z "$INSTANCE_NAME" ]]; then
      echo "ERROR: INSTANCE_NAME is required for create" >&2
      exit 1
    fi
    CMD=(gcloud compute instances create "$INSTANCE_NAME"
      --project="$PROJECT"
      --zone="$ZONE"
      --machine-type="$MACHINE_TYPE"
      --image-family="$IMAGE_FAMILY"
      --image-project="$IMAGE_PROJECT"
      --boot-disk-size="$DISK_SIZE"
      --boot-disk-type="$DISK_TYPE"
      --format=json
    )
    if [[ -n "$TAGS" ]]; then
      CMD+=(--tags="$TAGS")
    fi
    if [[ -n "$STARTUP_SCRIPT" && -f "$STARTUP_SCRIPT" ]]; then
      CMD+=(--metadata-from-file="startup-script=$STARTUP_SCRIPT")
    fi
    echo "Creating instance $INSTANCE_NAME in $ZONE..."
    "${CMD[@]}"
    ;;

  list)
    echo "Listing instances in project $PROJECT..."
    gcloud compute instances list \
      --project="$PROJECT" \
      --format="table(name, zone.basename(), machineType.basename(), status, networkInterfaces[0].accessConfigs[0].natIP:label=EXTERNAL_IP)"
    ;;

  start)
    if [[ -z "$INSTANCE_NAME" ]]; then
      echo "ERROR: INSTANCE_NAME is required for start" >&2
      exit 1
    fi
    echo "Starting instance $INSTANCE_NAME in $ZONE..."
    gcloud compute instances start "$INSTANCE_NAME" \
      --project="$PROJECT" \
      --zone="$ZONE" \
      --format=json
    ;;

  stop)
    if [[ -z "$INSTANCE_NAME" ]]; then
      echo "ERROR: INSTANCE_NAME is required for stop" >&2
      exit 1
    fi
    echo "Stopping instance $INSTANCE_NAME in $ZONE..."
    gcloud compute instances stop "$INSTANCE_NAME" \
      --project="$PROJECT" \
      --zone="$ZONE" \
      --format=json
    ;;

  delete)
    if [[ -z "$INSTANCE_NAME" ]]; then
      echo "ERROR: INSTANCE_NAME is required for delete" >&2
      exit 1
    fi
    echo "Deleting instance $INSTANCE_NAME in $ZONE..."
    gcloud compute instances delete "$INSTANCE_NAME" \
      --project="$PROJECT" \
      --zone="$ZONE" \
      --quiet \
      --format=json
    ;;

  describe)
    if [[ -z "$INSTANCE_NAME" ]]; then
      echo "ERROR: INSTANCE_NAME is required for describe" >&2
      exit 1
    fi
    gcloud compute instances describe "$INSTANCE_NAME" \
      --project="$PROJECT" \
      --zone="$ZONE" \
      --format=json
    ;;

  ssh)
    if [[ -z "$INSTANCE_NAME" ]]; then
      echo "ERROR: INSTANCE_NAME is required for ssh" >&2
      exit 1
    fi
    SSH_COMMAND="${SSH_COMMAND:-}"
    if [[ -n "$SSH_COMMAND" ]]; then
      gcloud compute ssh "$INSTANCE_NAME" \
        --project="$PROJECT" \
        --zone="$ZONE" \
        --command="$SSH_COMMAND"
    else
      gcloud compute ssh "$INSTANCE_NAME" \
        --project="$PROJECT" \
        --zone="$ZONE"
    fi
    ;;

  *)
    echo "ERROR: Unknown action '$ACTION'. Use: create, list, start, stop, delete, describe, ssh" >&2
    exit 1
    ;;
esac

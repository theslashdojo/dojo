#!/usr/bin/env bash
# Deploy and manage Cloud Functions (v2) — deploy, list, describe, logs, delete, call
# Usage: ACTION=deploy FUNCTION_NAME=hello ENTRY_POINT=hello ./deploy-function.sh
set -euo pipefail

ACTION="${ACTION:?ACTION is required (deploy|list|describe|logs|delete|call)}"
FUNCTION_NAME="${FUNCTION_NAME:-}"
PROJECT="${GOOGLE_CLOUD_PROJECT:?GOOGLE_CLOUD_PROJECT is required}"
REGION="${CLOUDSDK_COMPUTE_REGION:-us-central1}"
RUNTIME="${RUNTIME:-python312}"
ENTRY_POINT="${ENTRY_POINT:-}"
SOURCE="${SOURCE:-.}"
TRIGGER_TYPE="${TRIGGER_TYPE:-http}"
TRIGGER_BUCKET="${TRIGGER_BUCKET:-}"
TRIGGER_TOPIC="${TRIGGER_TOPIC:-}"
MEMORY="${MEMORY:-256Mi}"
TIMEOUT="${TIMEOUT:-60s}"
MIN_INSTANCES="${MIN_INSTANCES:-0}"
MAX_INSTANCES="${MAX_INSTANCES:-100}"
ALLOW_UNAUTHENTICATED="${ALLOW_UNAUTHENTICATED:-false}"
ENV_VARS="${ENV_VARS:-}"
SECRETS="${SECRETS:-}"

# Verify gcloud is available
if ! command -v gcloud &>/dev/null; then
  echo "ERROR: gcloud CLI is not installed." >&2
  exit 1
fi

case "$ACTION" in
  deploy)
    if [[ -z "$FUNCTION_NAME" ]]; then
      echo "ERROR: FUNCTION_NAME is required for deploy" >&2
      exit 1
    fi
    if [[ -z "$ENTRY_POINT" ]]; then
      ENTRY_POINT="$FUNCTION_NAME"
    fi

    CMD=(gcloud functions deploy "$FUNCTION_NAME"
      --gen2
      --project="$PROJECT"
      --region="$REGION"
      --runtime="$RUNTIME"
      --source="$SOURCE"
      --entry-point="$ENTRY_POINT"
      --memory="$MEMORY"
      --timeout="$TIMEOUT"
      --min-instances="$MIN_INSTANCES"
      --max-instances="$MAX_INSTANCES"
      --format=json
    )

    # Set trigger type
    case "$TRIGGER_TYPE" in
      http)
        CMD+=(--trigger-http)
        if [[ "$ALLOW_UNAUTHENTICATED" == "true" ]]; then
          CMD+=(--allow-unauthenticated)
        fi
        ;;
      gcs)
        if [[ -z "$TRIGGER_BUCKET" ]]; then
          echo "ERROR: TRIGGER_BUCKET is required for gcs trigger" >&2
          exit 1
        fi
        CMD+=(
          --trigger-event-filters="type=google.cloud.storage.object.v1.finalized"
          --trigger-event-filters="bucket=$TRIGGER_BUCKET"
        )
        ;;
      pubsub)
        if [[ -z "$TRIGGER_TOPIC" ]]; then
          echo "ERROR: TRIGGER_TOPIC is required for pubsub trigger" >&2
          exit 1
        fi
        CMD+=(--trigger-topic="$TRIGGER_TOPIC")
        ;;
      *)
        echo "ERROR: Unknown TRIGGER_TYPE '$TRIGGER_TYPE'. Use: http, gcs, pubsub" >&2
        exit 1
        ;;
    esac

    # Add environment variables
    if [[ -n "$ENV_VARS" ]]; then
      CMD+=(--set-env-vars="$ENV_VARS")
    fi

    # Add secrets
    if [[ -n "$SECRETS" ]]; then
      CMD+=(--set-secrets="$SECRETS")
    fi

    echo "Deploying function $FUNCTION_NAME ($RUNTIME) in $REGION..."
    "${CMD[@]}"
    ;;

  list)
    echo "Listing Cloud Functions in $REGION..."
    gcloud functions list \
      --gen2 \
      --project="$PROJECT" \
      --region="$REGION" \
      --format="table(name.basename(), state, runtime, updateTime)"
    ;;

  describe)
    if [[ -z "$FUNCTION_NAME" ]]; then
      echo "ERROR: FUNCTION_NAME is required for describe" >&2
      exit 1
    fi
    gcloud functions describe "$FUNCTION_NAME" \
      --gen2 \
      --project="$PROJECT" \
      --region="$REGION" \
      --format=json
    ;;

  logs)
    if [[ -z "$FUNCTION_NAME" ]]; then
      echo "ERROR: FUNCTION_NAME is required for logs" >&2
      exit 1
    fi
    LIMIT="${LIMIT:-50}"
    echo "Reading logs for $FUNCTION_NAME (last $LIMIT entries)..."
    gcloud functions logs read "$FUNCTION_NAME" \
      --gen2 \
      --project="$PROJECT" \
      --region="$REGION" \
      --limit="$LIMIT"
    ;;

  delete)
    if [[ -z "$FUNCTION_NAME" ]]; then
      echo "ERROR: FUNCTION_NAME is required for delete" >&2
      exit 1
    fi
    echo "Deleting function $FUNCTION_NAME in $REGION..."
    gcloud functions delete "$FUNCTION_NAME" \
      --gen2 \
      --project="$PROJECT" \
      --region="$REGION" \
      --quiet
    echo "Function deleted."
    ;;

  call)
    if [[ -z "$FUNCTION_NAME" ]]; then
      echo "ERROR: FUNCTION_NAME is required for call" >&2
      exit 1
    fi
    DATA="${DATA:-{}}"
    echo "Calling function $FUNCTION_NAME..."
    gcloud functions call "$FUNCTION_NAME" \
      --gen2 \
      --project="$PROJECT" \
      --region="$REGION" \
      --data="$DATA"
    ;;

  *)
    echo "ERROR: Unknown action '$ACTION'. Use: deploy, list, describe, logs, delete, call" >&2
    exit 1
    ;;
esac

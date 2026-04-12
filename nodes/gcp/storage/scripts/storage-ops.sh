#!/usr/bin/env bash
# Cloud Storage operations — create buckets, upload/download objects, signed URLs, lifecycle
# Usage: ACTION=create-bucket BUCKET=my-bucket ./storage-ops.sh
set -euo pipefail

ACTION="${ACTION:?ACTION is required (create-bucket|upload|download|list|delete|sync|sign-url|set-lifecycle)}"
BUCKET="${BUCKET:-}"
SOURCE="${SOURCE:-}"
DESTINATION="${DESTINATION:-}"
PROJECT="${GOOGLE_CLOUD_PROJECT:?GOOGLE_CLOUD_PROJECT is required}"
LOCATION="${LOCATION:-us-central1}"
STORAGE_CLASS="${STORAGE_CLASS:-STANDARD}"
SIGN_DURATION="${SIGN_DURATION:-1h}"
KEY_FILE="${GOOGLE_APPLICATION_CREDENTIALS:-}"
LIFECYCLE_FILE="${LIFECYCLE_FILE:-}"

# Verify gcloud is available
if ! command -v gcloud &>/dev/null; then
  echo "ERROR: gcloud CLI is not installed. Install from https://cloud.google.com/sdk/docs/install" >&2
  exit 1
fi

# Helper: ensure bucket has gs:// prefix
gs_uri() {
  local name="$1"
  if [[ "$name" == gs://* ]]; then
    echo "$name"
  else
    echo "gs://$name"
  fi
}

case "$ACTION" in
  create-bucket)
    if [[ -z "$BUCKET" ]]; then
      echo "ERROR: BUCKET is required for create-bucket" >&2
      exit 1
    fi
    BUCKET_URI=$(gs_uri "$BUCKET")
    echo "Creating bucket $BUCKET_URI in $LOCATION ($STORAGE_CLASS)..."
    gcloud storage buckets create "$BUCKET_URI" \
      --project="$PROJECT" \
      --location="$LOCATION" \
      --default-storage-class="$STORAGE_CLASS" \
      --uniform-bucket-level-access \
      --format=json
    ;;

  upload)
    if [[ -z "$SOURCE" || -z "$DESTINATION" ]]; then
      echo "ERROR: SOURCE and DESTINATION are required for upload" >&2
      echo "  SOURCE: local file/directory path" >&2
      echo "  DESTINATION: gs://bucket/path" >&2
      exit 1
    fi
    DEST_URI=$(gs_uri "$DESTINATION")
    if [[ -d "$SOURCE" ]]; then
      echo "Uploading directory $SOURCE to $DEST_URI..."
      gcloud storage cp -r "$SOURCE" "$DEST_URI"
    else
      echo "Uploading $SOURCE to $DEST_URI..."
      gcloud storage cp "$SOURCE" "$DEST_URI"
    fi
    echo "Upload complete."
    ;;

  download)
    if [[ -z "$SOURCE" || -z "$DESTINATION" ]]; then
      echo "ERROR: SOURCE and DESTINATION are required for download" >&2
      echo "  SOURCE: gs://bucket/path" >&2
      echo "  DESTINATION: local file/directory path" >&2
      exit 1
    fi
    SOURCE_URI=$(gs_uri "$SOURCE")
    echo "Downloading $SOURCE_URI to $DESTINATION..."
    gcloud storage cp "$SOURCE_URI" "$DESTINATION"
    echo "Download complete."
    ;;

  list)
    if [[ -z "$BUCKET" ]]; then
      echo "Listing all buckets in project $PROJECT..."
      gcloud storage buckets list --project="$PROJECT" --format="table(name, location, default_storage_class)"
    else
      BUCKET_URI=$(gs_uri "$BUCKET")
      PREFIX="${PREFIX:-}"
      echo "Listing objects in $BUCKET_URI${PREFIX:+/$PREFIX}..."
      gcloud storage ls -l "$BUCKET_URI${PREFIX:+/$PREFIX}"
    fi
    ;;

  delete)
    if [[ -z "$SOURCE" ]]; then
      echo "ERROR: SOURCE is required for delete (gs://bucket/path)" >&2
      exit 1
    fi
    SOURCE_URI=$(gs_uri "$SOURCE")
    echo "Deleting $SOURCE_URI..."
    gcloud storage rm "$SOURCE_URI" --recursive 2>/dev/null || gcloud storage rm "$SOURCE_URI"
    echo "Delete complete."
    ;;

  sync)
    if [[ -z "$SOURCE" || -z "$DESTINATION" ]]; then
      echo "ERROR: SOURCE and DESTINATION are required for sync" >&2
      exit 1
    fi
    # Ensure at least one side is a gs:// URI
    if [[ "$SOURCE" == gs://* || "$DESTINATION" == gs://* ]]; then
      echo "Syncing $SOURCE -> $DESTINATION..."
      gcloud storage rsync -r "$SOURCE" "$DESTINATION"
      echo "Sync complete."
    else
      echo "ERROR: At least one of SOURCE or DESTINATION must be a gs:// URI" >&2
      exit 1
    fi
    ;;

  sign-url)
    if [[ -z "$SOURCE" ]]; then
      echo "ERROR: SOURCE is required for sign-url (gs://bucket/object)" >&2
      exit 1
    fi
    if [[ -z "$KEY_FILE" ]]; then
      echo "ERROR: GOOGLE_APPLICATION_CREDENTIALS must point to a service account key file for signing" >&2
      exit 1
    fi
    SOURCE_URI=$(gs_uri "$SOURCE")
    echo "Generating signed URL for $SOURCE_URI (valid for $SIGN_DURATION)..."
    gcloud storage sign-url "$SOURCE_URI" \
      --private-key-file="$KEY_FILE" \
      --duration="$SIGN_DURATION"
    ;;

  set-lifecycle)
    if [[ -z "$BUCKET" ]]; then
      echo "ERROR: BUCKET is required for set-lifecycle" >&2
      exit 1
    fi
    if [[ -z "$LIFECYCLE_FILE" || ! -f "$LIFECYCLE_FILE" ]]; then
      echo "ERROR: LIFECYCLE_FILE must point to a valid lifecycle JSON file" >&2
      exit 1
    fi
    BUCKET_URI=$(gs_uri "$BUCKET")
    echo "Setting lifecycle rules on $BUCKET_URI from $LIFECYCLE_FILE..."
    gcloud storage buckets update "$BUCKET_URI" --lifecycle-file="$LIFECYCLE_FILE"
    echo "Lifecycle rules applied."
    ;;

  *)
    echo "ERROR: Unknown action '$ACTION'. Use: create-bucket, upload, download, list, delete, sync, sign-url, set-lifecycle" >&2
    exit 1
    ;;
esac

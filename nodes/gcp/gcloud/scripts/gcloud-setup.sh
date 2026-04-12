#!/usr/bin/env bash
# Install and configure the gcloud CLI — auth, project, region, zone, and API enablement
# Usage: ACTION=config-set GOOGLE_CLOUD_PROJECT=my-project ./gcloud-setup.sh
set -euo pipefail

ACTION="${ACTION:?ACTION is required (install|auth-login|auth-activate-sa|config-set|config-list|enable-api)}"
PROJECT="${GOOGLE_CLOUD_PROJECT:-}"
REGION="${CLOUDSDK_COMPUTE_REGION:-us-central1}"
ZONE="${CLOUDSDK_COMPUTE_ZONE:-us-central1-a}"
KEY_FILE="${GOOGLE_APPLICATION_CREDENTIALS:-}"
API="${API:-}"

case "$ACTION" in
  install)
    if command -v gcloud &>/dev/null; then
      echo "gcloud is already installed:"
      gcloud version
      echo ""
      echo "Updating components..."
      gcloud components update --quiet 2>/dev/null || echo "Note: Component updates may require running as the SDK owner"
    else
      echo "Installing Google Cloud SDK..."
      if [[ "$(uname)" == "Darwin" ]]; then
        if command -v brew &>/dev/null; then
          brew install --cask google-cloud-sdk
        else
          curl https://sdk.cloud.google.com | bash
          echo ""
          echo "Restart your shell or run: exec -l \$SHELL"
        fi
      elif [[ -f /etc/debian_version ]]; then
        apt-get update -qq
        apt-get install -y -qq apt-transport-https ca-certificates gnupg curl
        curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
        echo "deb https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list
        apt-get update -qq && apt-get install -y -qq google-cloud-cli
      else
        curl https://sdk.cloud.google.com | bash
        echo ""
        echo "Restart your shell or run: exec -l \$SHELL"
      fi
      echo ""
      echo "Installation complete. Verify with: gcloud version"
    fi
    ;;

  auth-login)
    echo "Starting interactive login (opens browser)..."
    gcloud auth login
    echo ""
    echo "Setting Application Default Credentials..."
    gcloud auth application-default login
    echo ""
    echo "Active account:"
    gcloud auth list --filter="status:ACTIVE" --format="value(account)"
    ;;

  auth-activate-sa)
    if [[ -z "$KEY_FILE" ]]; then
      echo "ERROR: GOOGLE_APPLICATION_CREDENTIALS must point to a service account key file" >&2
      exit 1
    fi
    if [[ ! -f "$KEY_FILE" ]]; then
      echo "ERROR: Key file not found: $KEY_FILE" >&2
      exit 1
    fi
    echo "Activating service account from $KEY_FILE..."
    gcloud auth activate-service-account --key-file="$KEY_FILE"
    echo ""
    echo "Active account:"
    gcloud auth list --filter="status:ACTIVE" --format="value(account)"
    ;;

  config-set)
    if [[ -z "$PROJECT" ]]; then
      echo "ERROR: GOOGLE_CLOUD_PROJECT is required for config-set" >&2
      exit 1
    fi
    echo "Configuring gcloud defaults..."
    gcloud config set project "$PROJECT"
    gcloud config set compute/region "$REGION"
    gcloud config set compute/zone "$ZONE"
    echo ""
    echo "Configuration set:"
    gcloud config list --format="table(core.project, compute.region, compute.zone, core.account)"
    ;;

  config-list)
    echo "Current gcloud configuration:"
    echo ""
    gcloud config list
    echo ""
    echo "Available configurations:"
    gcloud config configurations list
    echo ""
    echo "Authenticated accounts:"
    gcloud auth list
    ;;

  enable-api)
    if [[ -z "$API" ]]; then
      echo "ERROR: API is required (e.g., API=compute.googleapis.com)" >&2
      echo ""
      echo "Common APIs:"
      echo "  compute.googleapis.com         - Compute Engine"
      echo "  storage.googleapis.com         - Cloud Storage"
      echo "  cloudfunctions.googleapis.com  - Cloud Functions"
      echo "  cloudbuild.googleapis.com      - Cloud Build"
      echo "  run.googleapis.com             - Cloud Run"
      echo "  container.googleapis.com       - GKE"
      echo "  iam.googleapis.com             - IAM"
      echo "  secretmanager.googleapis.com   - Secret Manager"
      exit 1
    fi
    if [[ -z "$PROJECT" ]]; then
      echo "ERROR: GOOGLE_CLOUD_PROJECT is required for enable-api" >&2
      exit 1
    fi
    echo "Enabling $API in project $PROJECT..."
    gcloud services enable "$API" --project="$PROJECT"
    echo "API $API enabled."
    ;;

  *)
    echo "ERROR: Unknown action '$ACTION'. Use: install, auth-login, auth-activate-sa, config-set, config-list, enable-api" >&2
    exit 1
    ;;
esac

---
name: gcloud
description: >
  Install, configure, and use the gcloud CLI to manage Google Cloud Platform resources.
  Use when setting up GCP authentication, switching projects, enabling APIs, or running
  any GCP infrastructure command from the terminal.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: gcp-cli
---

# gcloud CLI

Install, authenticate, and use the Google Cloud CLI for all GCP operations.

## When to Use

- Installing the Google Cloud SDK for the first time
- Authenticating gcloud for interactive or CI/CD use
- Setting default project, region, and zone
- Switching between multiple GCP projects/configurations
- Enabling GCP service APIs
- Running any GCP management command from the terminal
- Getting access tokens for REST API calls

## Prerequisites

- Internet access for installation and authentication
- A Google Cloud account with at least one project
- A web browser for interactive login (or a service account key for headless auth)

## Workflow

### 1. Install

```bash
# macOS (Homebrew)
brew install --cask google-cloud-sdk

# macOS / Linux (official installer)
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Debian / Ubuntu
apt-get install apt-transport-https ca-certificates gnupg curl
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list
apt-get update && apt-get install google-cloud-cli

# Verify
gcloud version
```

### 2. Authenticate

```bash
# Interactive login (opens browser)
gcloud auth login

# Set Application Default Credentials (for client libraries)
gcloud auth application-default login

# Service account (non-interactive / CI/CD)
gcloud auth activate-service-account --key-file=sa-key.json

# List accounts
gcloud auth list

# Get access token for curl/REST
TOKEN=$(gcloud auth print-access-token)
curl -H "Authorization: Bearer $TOKEN" https://compute.googleapis.com/...
```

### 3. Configure Defaults

```bash
# Set project
gcloud config set project my-project-id

# Set region and zone
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a

# View current config
gcloud config list

# Enable APIs
gcloud services enable compute.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable storage.googleapis.com
```

### 4. Named Configurations

```bash
# Create a config for production
gcloud config configurations create prod
gcloud config set project prod-project-id
gcloud config set compute/region us-east1

# Create a config for development
gcloud config configurations create dev
gcloud config set project dev-project-id
gcloud config set compute/region us-central1

# Switch between configs
gcloud config configurations activate prod
gcloud config configurations list
```

### 5. Output and Filtering

```bash
# JSON output
gcloud compute instances list --format=json

# Table with specific columns
gcloud compute instances list \
  --format="table(name, zone, status, networkInterfaces[0].accessConfigs[0].natIP)"

# Extract a single value (for scripting)
IP=$(gcloud compute instances describe my-vm \
  --zone=us-central1-a \
  --format="value(networkInterfaces[0].accessConfigs[0].natIP)")

# Filter results
gcloud compute instances list --filter="status=RUNNING AND zone:us-central1-*"
```

## Key Patterns

### Non-Interactive Scripting

```bash
#!/usr/bin/env bash
set -euo pipefail

export CLOUDSDK_CORE_DISABLE_PROMPTS=1

# Authenticate with service account
gcloud auth activate-service-account --key-file="$GOOGLE_APPLICATION_CREDENTIALS"
gcloud config set project "$GOOGLE_CLOUD_PROJECT"

# Run commands
gcloud compute instances list --format=json
```

### Service Account Impersonation (No Key File)

```bash
# Act as a service account without downloading keys
gcloud compute instances list \
  --impersonate-service-account=my-sa@project.iam.gserviceaccount.com

# Set impersonation for all commands in this session
gcloud config set auth/impersonate_service_account my-sa@project.iam.gserviceaccount.com
```

### Dynamic Values in Scripts

```bash
# Get the first running instance name
INSTANCE=$(gcloud compute instances list \
  --filter="status=RUNNING" --limit=1 --format="value(name)")

# Get its zone
ZONE=$(gcloud compute instances list \
  --filter="name=$INSTANCE" --format="value(zone)")

# SSH into it
gcloud compute ssh "$INSTANCE" --zone="$ZONE"
```

## Command Groups Reference

| Group | Service | Common Commands |
|-------|---------|----------------|
| `compute` | Compute Engine | `instances list/create/delete`, `ssh`, `firewall-rules` |
| `storage` | Cloud Storage | `cp`, `ls`, `rm`, `buckets create` |
| `functions` | Cloud Functions | `deploy`, `logs read`, `delete` |
| `iam` | IAM | `service-accounts create`, `roles list` |
| `run` | Cloud Run | `deploy`, `services list` |
| `container` | GKE | `clusters create`, `get-credentials` |
| `sql` | Cloud SQL | `instances create`, `connect` |
| `secrets` | Secret Manager | `create`, `versions add` |
| `projects` | Projects | `list`, `create`, `describe` |
| `services` | APIs | `enable`, `list --enabled` |
| `logging` | Cloud Logging | `read` |

## Edge Cases

- **Multiple accounts**: `gcloud auth list` shows all, active is marked with `*`. Switch with `gcloud config set account EMAIL`.
- **Proxy**: Set `HTTPS_PROXY` env var. gcloud respects standard proxy environment variables.
- **Component updates**: `gcloud components update` updates all installed components. `gcloud components install COMPONENT` adds new ones.
- **Credential precedence**: Environment `GOOGLE_APPLICATION_CREDENTIALS` > `gcloud auth application-default` > metadata server (on GCE/GKE).
- **Quiet mode**: `--quiet` suppresses all interactive prompts. Essential for CI/CD pipelines.

## Troubleshooting

- **Command not found**: Ensure `google-cloud-sdk/bin` is in PATH. Re-run the installer or `source ~/google-cloud-sdk/path.bash.inc`.
- **Auth errors**: Run `gcloud auth login` again. Check `gcloud auth list` for active account.
- **Wrong project**: Verify with `gcloud config get project`. Override with `--project=ID`.
- **API not enabled**: Run `gcloud services enable SERVICE.googleapis.com` before using a service.
- **Old SDK version**: Run `gcloud components update` to get the latest.

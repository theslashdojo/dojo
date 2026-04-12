---
name: functions
description: >
  Deploy event-driven serverless functions on Google Cloud Functions — HTTP triggers,
  Cloud Storage events, Pub/Sub messages, and Eventarc. Use when deploying webhooks,
  processing events, or running serverless code on GCP.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: gcp-functions
---

# Cloud Functions

Deploy serverless, event-driven functions on Google Cloud Platform.

## When to Use

- Deploying an HTTP endpoint or webhook handler
- Processing file uploads in Cloud Storage
- Handling Pub/Sub messages
- Running scheduled tasks (Cloud Scheduler + Pub/Sub)
- Responding to Firestore/Firebase changes
- Building lightweight APIs without managing servers

## Prerequisites

- gcloud CLI installed and authenticated
- Active GCP project
- Cloud Functions API enabled (`gcloud services enable cloudfunctions.googleapis.com`)
- Cloud Build API enabled (`gcloud services enable cloudbuild.googleapis.com`)
- IAM role: `roles/cloudfunctions.developer`

## Workflow

### 1. Write the Function

**Python (HTTP):**

```python
# main.py
import functions_framework
from flask import jsonify

@functions_framework.http
def hello(request):
    """HTTP Cloud Function."""
    name = request.args.get("name", "World")
    return jsonify({"message": f"Hello, {name}!", "status": "ok"})
```

```txt
# requirements.txt
functions-framework==3.*
```

**Node.js (HTTP):**

```javascript
// index.js
const functions = require('@google-cloud/functions-framework');

functions.http('hello', (req, res) => {
  const name = req.query.name || 'World';
  res.json({ message: `Hello, ${name}!`, status: 'ok' });
});
```

```json
{
  "dependencies": {
    "@google-cloud/functions-framework": "^3.0.0"
  }
}
```

**Python (Cloud Event / GCS trigger):**

```python
# main.py
import functions_framework
from cloudevents.http import CloudEvent

@functions_framework.cloud_event
def process_upload(cloud_event: CloudEvent):
    """Triggered when a file is uploaded to Cloud Storage."""
    data = cloud_event.data
    bucket = data["bucket"]
    name = data["name"]
    content_type = data.get("contentType", "unknown")
    size = data.get("size", "unknown")
    print(f"New file: gs://{bucket}/{name} ({content_type}, {size} bytes)")
```

### 2. Test Locally

```bash
# Python
pip install functions-framework
functions-framework --target=hello --port=8080 --debug

# Node.js
npx @google-cloud/functions-framework --target=hello --port=8080

# Test
curl http://localhost:8080?name=Agent
```

### 3. Deploy

```bash
# HTTP function (v2 / 2nd gen — recommended)
gcloud functions deploy hello \
  --gen2 \
  --runtime=python312 \
  --region=us-central1 \
  --source=. \
  --entry-point=hello \
  --trigger-http \
  --allow-unauthenticated \
  --memory=256Mi \
  --timeout=60s

# GCS event function
gcloud functions deploy process-upload \
  --gen2 \
  --runtime=python312 \
  --region=us-central1 \
  --source=. \
  --entry-point=process_upload \
  --trigger-event-filters="type=google.cloud.storage.object.v1.finalized" \
  --trigger-event-filters="bucket=my-uploads-bucket"

# Pub/Sub function
gcloud functions deploy process-message \
  --gen2 \
  --runtime=python312 \
  --region=us-central1 \
  --source=. \
  --entry-point=process_message \
  --trigger-topic=my-topic

# With environment variables
gcloud functions deploy my-func \
  --gen2 \
  --runtime=python312 \
  --region=us-central1 \
  --source=. \
  --entry-point=handler \
  --trigger-http \
  --set-env-vars="DB_HOST=10.0.0.5,DB_NAME=mydb"

# With Secret Manager secrets
gcloud functions deploy my-func \
  --gen2 \
  --runtime=python312 \
  --region=us-central1 \
  --source=. \
  --entry-point=handler \
  --trigger-http \
  --set-secrets="API_KEY=projects/my-project/secrets/api-key:latest"
```

### 4. Manage Functions

```bash
# List functions
gcloud functions list --gen2 --region=us-central1

# View logs
gcloud functions logs read hello --gen2 --region=us-central1 --limit=50

# Describe
gcloud functions describe hello --gen2 --region=us-central1

# Call directly
gcloud functions call hello --gen2 --region=us-central1 --data='{"name":"test"}'

# Delete
gcloud functions delete hello --gen2 --region=us-central1 --quiet
```

## Key Patterns

### Authenticated HTTP Function

```bash
# Deploy without --allow-unauthenticated
gcloud functions deploy secure-api \
  --gen2 --runtime=python312 --region=us-central1 \
  --source=. --entry-point=handler --trigger-http

# Call with auth token
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  https://REGION-PROJECT.cloudfunctions.net/secure-api
```

### Scheduled Function

```bash
# Deploy a Pub/Sub function
gcloud functions deploy daily-cleanup \
  --gen2 --runtime=python312 --region=us-central1 \
  --source=. --entry-point=cleanup --trigger-topic=daily-trigger

# Create a Cloud Scheduler job
gcloud scheduler jobs create pubsub daily-cleanup-trigger \
  --schedule="0 2 * * *" \
  --topic=daily-trigger \
  --message-body="{}"
```

### Minimum Instances (Avoid Cold Starts)

```bash
gcloud functions deploy latency-sensitive \
  --gen2 --runtime=python312 --region=us-central1 \
  --source=. --entry-point=handler --trigger-http \
  --min-instances=1 --max-instances=10
```

## Configuration Reference

| Flag | Default | Range | Notes |
|------|---------|-------|-------|
| `--memory` | 256Mi | 128Mi–32Gi | v2 supports up to 32 GiB |
| `--timeout` | 60s | 1s–3600s | v2 supports up to 60 min |
| `--min-instances` | 0 | 0–1000 | Keep warm to avoid cold starts |
| `--max-instances` | 100 | 1–1000 | Limit scaling |
| `--concurrency` | 1 | 1–1000 | v2 only; requests per instance |

## Runtimes

| Runtime | Flag | Status |
|---------|------|--------|
| Python 3.12 | `python312` | Recommended |
| Python 3.11 | `python311` | Supported |
| Node.js 20 | `nodejs20` | Recommended |
| Node.js 18 | `nodejs18` | Supported |
| Go 1.22 | `go122` | Supported |
| Java 21 | `java21` | Supported |

## Edge Cases

- **Cold starts**: First request after idle takes 500ms–5s. Use `--min-instances=1` for latency-sensitive functions.
- **Timeout**: Default is 60s. Background processing beyond response requires Cloud Tasks or Pub/Sub.
- **Deployment source**: `--source=.` uploads the current directory. `.gcloudignore` controls what's excluded.
- **Dependencies**: Python reads `requirements.txt`, Node.js reads `package.json`. Dependencies are installed during build.
- **Concurrency**: v1 processes one request per instance. v2 supports concurrency — set `--concurrency` for better utilization.

## Troubleshooting

- **Build fails**: Check `requirements.txt` or `package.json` for version conflicts. View build logs with `gcloud builds list`.
- **Permission denied on deploy**: Need `roles/cloudfunctions.developer` and `roles/cloudbuild.builds.builder`.
- **Function not reachable**: Check `--allow-unauthenticated` or call with Bearer token from `gcloud auth print-identity-token`.
- **Out of memory**: Increase `--memory`. Check for memory leaks in warm instances.
- **Event not triggering**: Verify event filter matches. Check Eventarc triggers with `gcloud eventarc triggers list`.

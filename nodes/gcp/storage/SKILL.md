---
name: storage
description: >
  Upload, download, and manage objects in Google Cloud Storage — buckets, lifecycle,
  signed URLs, and access control. Use when storing files, serving static assets,
  backing up data, or transferring objects on GCP.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: gcp-storage
---

# Cloud Storage

Manage object storage on Google Cloud Storage (GCS) — buckets, objects, lifecycle rules, and access control.

## When to Use

- Creating storage buckets for application data
- Uploading or downloading files to/from GCS
- Syncing directories between local and cloud
- Generating signed URLs for temporary file access
- Setting lifecycle policies for automatic cleanup
- Serving static websites from a bucket
- Backing up databases or application state

## Prerequisites

- gcloud CLI installed and authenticated (`gcloud auth login`)
- Active GCP project (`gcloud config set project PROJECT_ID`)
- IAM role: `roles/storage.admin` or scoped roles (`objectViewer`, `objectCreator`)

## Workflow

### 1. Create a Bucket

```bash
# Regional bucket (cheapest, single region)
gcloud storage buckets create gs://my-app-data-prod \
  --location=us-central1 \
  --default-storage-class=standard \
  --uniform-bucket-level-access

# Multi-region bucket (highest availability)
gcloud storage buckets create gs://my-app-static \
  --location=us \
  --default-storage-class=standard
```

Bucket names are globally unique across all GCP projects. Use a naming convention like `{project}-{purpose}-{env}`.

### 2. Upload Files

```bash
# Single file
gcloud storage cp ./report.pdf gs://my-bucket/reports/2026/report.pdf

# Directory (recursive)
gcloud storage cp -r ./build/ gs://my-bucket/static/

# With specific content type
gcloud storage cp ./index.html gs://my-bucket/ --content-type="text/html"

# Sync (only uploads changed files)
gcloud storage rsync -r ./dist/ gs://my-bucket/app/
```

### 3. Download Files

```bash
# Single file
gcloud storage cp gs://my-bucket/data/export.csv ./export.csv

# Directory
gcloud storage cp -r gs://my-bucket/backups/latest/ ./restore/
```

### 4. List and Manage Objects

```bash
# List objects
gcloud storage ls gs://my-bucket/
gcloud storage ls -l gs://my-bucket/reports/  # with sizes and dates

# Delete
gcloud storage rm gs://my-bucket/temp/scratch.txt
gcloud storage rm -r gs://my-bucket/old-data/  # recursive

# Move/rename
gcloud storage mv gs://my-bucket/old.txt gs://my-bucket/new.txt
```

### 5. Signed URLs

```bash
# Generate signed URL (requires service account key)
gcloud storage sign-url gs://my-bucket/private/file.pdf \
  --private-key-file=sa-key.json \
  --duration=1h
```

```python
from google.cloud import storage
import datetime

client = storage.Client()
bucket = client.bucket("my-bucket")
blob = bucket.blob("private/file.pdf")

url = blob.generate_signed_url(
    version="v4",
    expiration=datetime.timedelta(hours=1),
    method="GET",
)
print(url)
```

### 6. Lifecycle Rules

```bash
cat > lifecycle.json << 'RULES'
{
  "rule": [
    {
      "action": {"type": "Delete"},
      "condition": {"age": 90}
    },
    {
      "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
      "condition": {"age": 30, "matchesStorageClass": ["STANDARD"]}
    },
    {
      "action": {"type": "Delete"},
      "condition": {"isLive": false, "numNewerVersions": 3}
    }
  ]
}
RULES

gcloud storage buckets update gs://my-bucket --lifecycle-file=lifecycle.json
```

### 7. Access Control

```bash
# Make bucket publicly readable
gcloud storage buckets add-iam-policy-binding gs://my-bucket \
  --member=allUsers \
  --role=roles/storage.objectViewer

# Grant a service account write access
gcloud storage buckets add-iam-policy-binding gs://my-bucket \
  --member="serviceAccount:my-sa@project.iam.gserviceaccount.com" \
  --role=roles/storage.objectCreator
```

## Key Patterns

### Python Upload/Download

```python
from google.cloud import storage

def upload_blob(bucket_name: str, source: str, destination: str) -> str:
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(destination)
    blob.upload_from_filename(source)
    return f"gs://{bucket_name}/{destination}"

def download_blob(bucket_name: str, source: str, destination: str) -> None:
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(source)
    blob.download_to_filename(destination)
```

### Static Website Hosting

```bash
# Create bucket with website config
gcloud storage buckets create gs://www.example.com \
  --location=us \
  --uniform-bucket-level-access

# Upload site files
gcloud storage cp -r ./site/ gs://www.example.com/

# Set main page and 404 page
gcloud storage buckets update gs://www.example.com \
  --web-main-page-suffix=index.html \
  --web-error-page=404.html

# Make publicly readable
gcloud storage buckets add-iam-policy-binding gs://www.example.com \
  --member=allUsers \
  --role=roles/storage.objectViewer
```

## Edge Cases

- **Bucket names are global**: If `gs://data` is taken by any GCP user, you can't use it. Prefix with project ID.
- **Eventual consistency**: Listing objects after creation may have brief delays. Object read-after-write is strongly consistent.
- **Object immutability**: Objects are immutable — "updating" an object writes a new version. Enable versioning to keep old versions.
- **Max object size**: 5 TiB per object. Uploads > 5 MiB auto-use resumable uploads.
- **gsutil vs gcloud storage**: `gcloud storage` is the modern replacement for `gsutil`. Both work; prefer `gcloud storage`.

## Troubleshooting

- **403 Forbidden**: Check IAM roles on the bucket. Verify uniform access is enabled if expecting IAM-only auth.
- **404 Not Found on bucket create**: Bucket name already taken globally. Choose a different name.
- **Slow uploads**: Use `gcloud storage cp --parallel-composite-upload-threshold=150M` for large files.
- **CORS errors**: Set CORS config with `gcloud storage buckets update gs://bucket --cors-file=cors.json`.

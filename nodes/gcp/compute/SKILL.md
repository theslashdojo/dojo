---
name: compute
description: >
  Create, configure, and manage Google Compute Engine VMs — instances, machine types,
  disks, SSH access, and firewall rules. Use when provisioning servers, running workloads,
  or managing VM infrastructure on GCP.
license: MIT
metadata:
  author: dojo-community
  version: "1.0"
  scope: gcp-compute
---

# Compute Engine

Provision and manage virtual machines on Google Cloud Platform's Compute Engine.

## When to Use

- Creating a VM instance for development, staging, or production
- SSHing into a GCP instance or transferring files
- Starting, stopping, or resizing VM instances
- Attaching persistent disks or creating snapshots
- Configuring firewall rules for network access
- Provisioning GPU instances for ML workloads

## Prerequisites

- gcloud CLI installed and authenticated (`gcloud auth login`)
- Active GCP project (`gcloud config set project PROJECT_ID`)
- Compute Engine API enabled (`gcloud services enable compute.googleapis.com`)
- IAM role: `roles/compute.instanceAdmin.v1` or `roles/compute.admin`

## Workflow

### 1. Choose a Machine Type

Select based on workload requirements:

| Family | When to Use | Example |
|--------|-------------|---------|
| E2 | General purpose, cost-sensitive | `e2-medium` (2 vCPU, 4 GB) |
| N2 | Balanced production workloads | `n2-standard-4` (4 vCPU, 16 GB) |
| C3 | CPU-intensive (compilation, encoding) | `c3-highcpu-8` (8 vCPU, 16 GB) |
| M3 | Memory-intensive (databases, caches) | `m3-megamem-64` (64 vCPU, 896 GB) |
| A2/A3 | GPU workloads (ML training, inference) | `a2-highgpu-1g` (1 A100 GPU) |

```bash
# List machine types available in a zone
gcloud compute machine-types list --zones=us-central1-a --format="table(name, guestCpus, memoryMb)"
```

### 2. Create an Instance

```bash
# Basic Linux instance
gcloud compute instances create my-vm \
  --zone=us-central1-a \
  --machine-type=e2-medium \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --boot-disk-size=50GB \
  --boot-disk-type=pd-balanced

# Instance with startup script
gcloud compute instances create web-server \
  --zone=us-central1-a \
  --machine-type=e2-standard-2 \
  --image-family=ubuntu-2404-lts-amd64 \
  --image-project=ubuntu-os-cloud \
  --metadata-from-file=startup-script=startup.sh \
  --tags=http-server,https-server \
  --scopes=cloud-platform

# Spot instance (up to 91% cheaper)
gcloud compute instances create batch-worker \
  --zone=us-central1-a \
  --machine-type=n2-standard-4 \
  --provisioning-model=SPOT \
  --instance-termination-action=STOP \
  --image-family=debian-12 \
  --image-project=debian-cloud
```

### 3. Connect via SSH

```bash
# SSH (auto-generates keys)
gcloud compute ssh my-vm --zone=us-central1-a

# Run a remote command
gcloud compute ssh my-vm --zone=us-central1-a --command="df -h"

# Copy files to/from instance
gcloud compute scp ./deploy.tar.gz my-vm:~/ --zone=us-central1-a
gcloud compute scp my-vm:~/results.csv ./ --zone=us-central1-a
```

### 4. Manage Instance Lifecycle

```bash
# List all instances
gcloud compute instances list

# Stop (still billed for disks)
gcloud compute instances stop my-vm --zone=us-central1-a

# Start
gcloud compute instances start my-vm --zone=us-central1-a

# Delete
gcloud compute instances delete my-vm --zone=us-central1-a --quiet
```

### 5. Manage Disks

```bash
# Create a persistent SSD
gcloud compute disks create data-disk \
  --zone=us-central1-a \
  --size=200GB \
  --type=pd-ssd

# Attach to a running instance
gcloud compute instances attach-disk my-vm \
  --disk=data-disk \
  --zone=us-central1-a

# Inside the VM: format and mount
sudo mkfs.ext4 -F /dev/sdb
sudo mkdir -p /mnt/data
sudo mount /dev/sdb /mnt/data
echo '/dev/sdb /mnt/data ext4 defaults 0 2' | sudo tee -a /etc/fstab

# Snapshot a disk
gcloud compute disks snapshot data-disk \
  --zone=us-central1-a \
  --snapshot-names=data-snap-$(date +%Y%m%d)
```

### 6. Configure Firewall Rules

```bash
# Allow HTTP
gcloud compute firewall-rules create allow-http \
  --direction=INGRESS --action=ALLOW \
  --rules=tcp:80 --target-tags=http-server

# Allow app port from specific IP range
gcloud compute firewall-rules create allow-app \
  --direction=INGRESS --action=ALLOW \
  --rules=tcp:8080 --source-ranges=10.0.0.0/8
```

## Key Patterns

### Python Client Library

```python
from google.cloud import compute_v1

client = compute_v1.InstancesClient()

# List instances
instances = client.list(project="my-project", zone="us-central1-a")
for instance in instances:
    print(f"{instance.name}: {instance.status}")

# Stop an instance
op = client.stop(project="my-project", zone="us-central1-a", instance="my-vm")
op.result()
```

## Edge Cases

- **Quota limits**: Each project has per-region CPU and IP quotas. Check with `gcloud compute regions describe REGION`.
- **Spot termination**: Spot VMs can be preempted with 30s notice. Design for interruption.
- **Disk auto-delete**: Boot disks auto-delete when the VM is deleted by default. Set `--no-boot-disk-auto-delete` to keep them.
- **Metadata server**: VMs can get project/instance metadata at `http://metadata.google.internal/computeMetadata/v1/`.
- **Serial console**: Debug boot issues with `gcloud compute instances get-serial-port-output VM --zone=ZONE`.

## Troubleshooting

- **QUOTA_EXCEEDED**: Request quota increase in the Console or use a different region.
- **ZONE_RESOURCE_POOL_EXHAUSTED**: Choose a different zone — capacity is finite per zone.
- **Permission denied**: Verify IAM role (`roles/compute.instanceAdmin.v1`) on the project.
- **SSH fails**: Check firewall rules allow TCP:22, verify OS Login config, try `--troubleshoot` flag.

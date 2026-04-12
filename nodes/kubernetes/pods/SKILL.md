---
name: pods
description: Create, inspect, debug, and manage Kubernetes Pods. Use when an agent needs to work with individual Pods — view logs, exec into containers, check status, or diagnose failures like CrashLoopBackOff and OOMKilled.
---

# Pods

Pods are the smallest deployable unit in Kubernetes. A Pod runs one or more containers sharing network and storage.

## Prerequisites

- kubectl configured with cluster access
- Target namespace identified (`$KUBE_NAMESPACE` or `-n <namespace>`)

## Core Workflow

### 1. Check Pod Status

```bash
kubectl get pods -n <namespace> -o wide
kubectl get pods -l app=<name> --show-labels
```

### 2. Inspect a Pod

```bash
kubectl describe pod <name> -n <namespace>
# Focus on: Events section, Container Statuses, Conditions
```

### 3. Read Logs

```bash
kubectl logs <pod> --tail=100
kubectl logs <pod> -c <container>     # specific container
kubectl logs <pod> --previous          # from crashed container
kubectl logs <pod> -f                  # follow/stream
```

### 4. Interactive Debug

```bash
kubectl exec -it <pod> -- /bin/sh
kubectl port-forward pod/<pod> 8080:8080
kubectl cp <pod>:/path/to/file ./local-file
```

## Pod Spec Essentials

Every Pod spec should include:
- **Image tag** — never use `:latest` in production
- **Resource requests/limits** — prevent noisy-neighbor and OOMKill
- **Probes** — livenessProbe (restart on failure), readinessProbe (traffic gating)
- **Labels** — for Service selector matching

## Debugging Decision Tree

1. **Pending** → `kubectl describe pod` → check Events for FailedScheduling
2. **ImagePullBackOff** → verify image name/tag, check registry credentials
3. **CrashLoopBackOff** → `kubectl logs --previous` → check exit code in describe
4. **Running but not Ready** → check readinessProbe configuration
5. **OOMKilled** → increase `resources.limits.memory`

## Multi-Container Patterns

- **Init containers** — run to completion before app starts (migrations, config gen)
- **Sidecars** — run alongside app (log shippers, proxies, metrics exporters)
- **Ephemeral debug containers** — `kubectl debug pod/<name> -it --image=busybox`

## Edge Cases

- Pods are rarely created directly — use Deployments for managed lifecycle
- `kubectl delete pod` with no `--grace-period` waits for graceful shutdown (default 30s)
- `--force --grace-period=0` for stuck terminating pods (last resort)
- `kubectl top pod` requires metrics-server

---
name: deployments
description: Create, scale, update, and rollback Kubernetes Deployments. Use when an agent needs to deploy applications, perform rolling updates, scale replicas, or rollback failed releases.
---

# Deployments

Deployments manage the lifecycle of stateless applications — controlling replicas, rolling updates, and rollbacks through ReplicaSets.

## Prerequisites

- kubectl configured with cluster access
- Container image available in a registry the cluster can pull from
- Target namespace identified

## Core Workflow

### 1. Deploy an Application

```bash
# From manifest
kubectl apply -f deployment.yaml

# Imperatively
kubectl create deployment my-app --image=myregistry/app:v1.0.0 --replicas=3
```

### 2. Verify Rollout

```bash
kubectl rollout status deployment/my-app
kubectl get deployment my-app -o wide
kubectl get pods -l app=my-app
```

### 3. Update (Rolling)

```bash
# Update image (triggers rolling update)
kubectl set image deployment/my-app app=myregistry/app:v1.1.0

# Watch rollout
kubectl rollout status deployment/my-app
```

### 4. Rollback

```bash
kubectl rollout history deployment/my-app
kubectl rollout undo deployment/my-app               # previous version
kubectl rollout undo deployment/my-app --to-revision=3  # specific version
```

### 5. Scale

```bash
kubectl scale deployment my-app --replicas=5
```

## Update Strategies

| Strategy | Behavior | Use When |
|----------|----------|----------|
| `RollingUpdate` | Gradual replacement | Default for most apps |
| `Recreate` | Kill all, then create | App can't run two versions |

For RollingUpdate, key settings:
- `maxSurge: 1, maxUnavailable: 0` — zero-downtime, slowest
- `maxSurge: 25%, maxUnavailable: 25%` — balanced speed/availability

## Deployment → ReplicaSet → Pod

Deployments don't manage Pods directly. Each unique Pod template creates a ReplicaSet. Rolling updates scale the new ReplicaSet up while scaling the old one down. Old ReplicaSets (scaled to 0) enable instant rollback.

## Edge Cases

- **Stalled rollout**: Pod fails readinessProbe → rollout hangs → `kubectl rollout undo`
- **Rolling restart** (no image change): `kubectl rollout restart deployment/my-app`
- **Canary**: `kubectl rollout pause` → partial rollout → verify → `kubectl rollout resume`
- **revisionHistoryLimit**: Controls how many old ReplicaSets are kept (default 10)
- **minReadySeconds**: Delay before counting new Pods as available

## Troubleshooting Deployments

```bash
kubectl describe deployment my-app     # Conditions and Events
kubectl get replicasets -l app=my-app  # Check RS scaling
kubectl rollout history deployment/my-app
```

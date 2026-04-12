#!/bin/bash
set -euo pipefail

# Rollout Status — show deployment status, replica counts, and history
# Usage: rollout-status.sh <deployment-name> [namespace]

NAME=${1:?Usage: rollout-status.sh <deployment-name> [namespace]}
NS=${2:-${KUBE_NAMESPACE:-default}}

echo "=== Deployment Status ==="
kubectl get deployment "$NAME" -n "$NS" -o wide

echo ""
echo "=== Rollout Status ==="
kubectl rollout status deployment/"$NAME" -n "$NS" 2>&1 || true

echo ""
echo "=== Rollout History ==="
kubectl rollout history deployment/"$NAME" -n "$NS"

echo ""
echo "=== ReplicaSets ==="
kubectl get replicasets -n "$NS" -l app="$NAME" -o wide 2>/dev/null || \
  echo "No ReplicaSets found with label app=$NAME"

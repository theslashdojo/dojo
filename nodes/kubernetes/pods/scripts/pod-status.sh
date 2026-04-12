#!/bin/bash
set -euo pipefail

# Pod Status — list all pods in a namespace with status, restarts, and age
# Usage: pod-status.sh [namespace]

NS=${KUBE_NAMESPACE:-default}

echo "Pods in namespace: $NS"
kubectl get pods -n "$NS" -o wide

echo ""
echo "Pod events (last 10 minutes):"
kubectl get events -n "$NS" --sort-by=.metadata.creationTimestamp \
  --field-selector type!=Normal 2>/dev/null | tail -20 || echo "No warning events"

#!/bin/bash
set -euo pipefail

# Debug Pod — describe a pod, show recent logs, and display events
# Usage: pod-debug.sh <pod-name> [namespace]

POD=${1:?Usage: pod-debug.sh <pod-name> [namespace]}
NS=${2:-${KUBE_NAMESPACE:-default}}

echo "=== Pod Description ==="
kubectl describe pod "$POD" -n "$NS"

echo ""
echo "=== Recent Logs (last 50 lines) ==="
kubectl logs "$POD" -n "$NS" --tail=50 2>/dev/null || echo "No logs available"

echo ""
echo "=== Previous Container Logs ==="
kubectl logs "$POD" -n "$NS" --previous --tail=30 2>/dev/null || echo "No previous logs"

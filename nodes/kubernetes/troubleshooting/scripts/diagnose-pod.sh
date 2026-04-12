#!/bin/bash
set -euo pipefail

# Diagnose Pod — comprehensive diagnostics for a failing Pod
# Usage: diagnose-pod.sh <pod-name> [namespace]

POD=${1:?Usage: diagnose-pod.sh <pod-name> [namespace]}
NS=${2:-${KUBE_NAMESPACE:-default}}

echo "========================================"
echo "Diagnosing Pod: $POD in namespace: $NS"
echo "========================================"

echo ""
echo "=== Pod Status ==="
kubectl get pod "$POD" -n "$NS" -o wide 2>/dev/null || { echo "Pod not found"; exit 1; }

STATUS=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.status.phase}')
echo "Phase: $STATUS"

echo ""
echo "=== Container Statuses ==="
kubectl get pod "$POD" -n "$NS" \
  -o jsonpath='{range .status.containerStatuses[*]}{.name}: ready={.ready}, restarts={.restartCount}, state={.state}{"\n"}{end}' \
  2>/dev/null || echo "No container statuses"

echo ""
echo "=== Events (last 10) ==="
kubectl describe pod "$POD" -n "$NS" 2>/dev/null | grep -A 50 '^Events:' | head -15

echo ""
echo "=== Current Logs (last 30 lines) ==="
kubectl logs "$POD" -n "$NS" --tail=30 2>/dev/null || echo "No current logs"

echo ""
echo "=== Previous Container Logs (last 20 lines) ==="
kubectl logs "$POD" -n "$NS" --previous --tail=20 2>/dev/null || echo "No previous logs"

echo ""
echo "=== Resource Usage ==="
kubectl top pod "$POD" -n "$NS" 2>/dev/null || echo "metrics-server not available"

echo ""
echo "=== Node Status ==="
NODE=$(kubectl get pod "$POD" -n "$NS" -o jsonpath='{.spec.nodeName}' 2>/dev/null)
if [ -n "$NODE" ]; then
  echo "Scheduled on: $NODE"
  kubectl top node "$NODE" 2>/dev/null || echo "Node metrics not available"
else
  echo "Pod not yet scheduled to a node"
fi

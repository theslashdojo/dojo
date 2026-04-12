#!/bin/bash
set -euo pipefail

# Diagnose Service — debug a Service that is not routing traffic
# Usage: diagnose-service.sh <service-name> [namespace]

SVC=${1:?Usage: diagnose-service.sh <service-name> [namespace]}
NS=${2:-${KUBE_NAMESPACE:-default}}

echo "========================================"
echo "Diagnosing Service: $SVC in namespace: $NS"
echo "========================================"

echo ""
echo "=== Service ==="
kubectl get svc "$SVC" -n "$NS" -o wide 2>/dev/null || { echo "Service not found"; exit 1; }

echo ""
echo "=== Selector ==="
SELECTOR=$(kubectl get svc "$SVC" -n "$NS" -o jsonpath='{.spec.selector}' 2>/dev/null)
echo "$SELECTOR"

echo ""
echo "=== Endpoints ==="
kubectl get endpoints "$SVC" -n "$NS" 2>/dev/null || echo "No endpoints found"

ENDPOINT_ADDRS=$(kubectl get endpoints "$SVC" -n "$NS" -o jsonpath='{.subsets[*].addresses}' 2>/dev/null)
if [ -z "$ENDPOINT_ADDRS" ]; then
  echo ""
  echo "WARNING: No endpoints! Pods may not match the Service selector or are not Ready."
  echo ""
  echo "All Pods in namespace with labels:"
  kubectl get pods -n "$NS" --show-labels 2>/dev/null || echo "Could not list pods"
fi

echo ""
echo "=== Service Events ==="
kubectl describe svc "$SVC" -n "$NS" 2>/dev/null | grep -A 20 '^Events:' || echo "No events"

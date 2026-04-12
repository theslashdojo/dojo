#!/bin/bash
set -euo pipefail

# Cluster Status — show connection info, node health, and resource summary
# Usage: cluster-status.sh [namespace]

NS=${KUBE_NAMESPACE:-default}

echo "========================================"
echo "Kubernetes Cluster Status"
echo "========================================"

echo ""
echo "=== Current Context ==="
kubectl config current-context 2>/dev/null || echo "No context set"

echo ""
echo "=== Cluster Info ==="
kubectl cluster-info 2>/dev/null | head -5 || echo "Cannot reach cluster"

echo ""
echo "=== Nodes ==="
kubectl get nodes -o wide 2>/dev/null || echo "Cannot list nodes"

echo ""
echo "=== Node Resource Usage ==="
kubectl top nodes 2>/dev/null || echo "metrics-server not available"

echo ""
echo "=== Namespaces ==="
kubectl get namespaces 2>/dev/null || echo "Cannot list namespaces"

echo ""
echo "=== Resources in namespace: $NS ==="
echo "--- Deployments ---"
kubectl get deployments -n "$NS" 2>/dev/null || echo "none"
echo ""
echo "--- Pods ---"
kubectl get pods -n "$NS" -o wide 2>/dev/null || echo "none"
echo ""
echo "--- Services ---"
kubectl get services -n "$NS" 2>/dev/null || echo "none"

echo ""
echo "=== Recent Warning Events (cluster-wide, last 10) ==="
kubectl get events --all-namespaces --field-selector type=Warning \
  --sort-by=.metadata.creationTimestamp 2>/dev/null | tail -10 || echo "none"

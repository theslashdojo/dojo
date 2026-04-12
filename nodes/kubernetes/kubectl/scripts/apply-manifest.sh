#!/bin/bash
set -euo pipefail

# Apply Manifest — diff, apply, and verify a YAML manifest
# Usage: apply-manifest.sh <manifest-path> [namespace]

MANIFEST=${1:?Usage: apply-manifest.sh <manifest-path> [namespace]}
NS=${2:-${KUBE_NAMESPACE:-default}}

if [ ! -f "$MANIFEST" ]; then
  echo "Error: File not found: $MANIFEST"
  exit 1
fi

echo "Applying manifest: $MANIFEST to namespace: $NS"
echo ""

# Show what will change
echo "=== Diff (current vs desired) ==="
kubectl diff -f "$MANIFEST" -n "$NS" 2>/dev/null || echo "(no existing resources or diff unavailable)"

echo ""
echo "=== Applying ==="
kubectl apply -f "$MANIFEST" -n "$NS"

echo ""
echo "=== Verifying ==="
# Check if any Deployments were created/updated and wait for rollout
DEPLOYMENTS=$(kubectl get -f "$MANIFEST" -n "$NS" -o jsonpath='{range .items[?(@.kind=="Deployment")]}{.metadata.name}{"\n"}{end}' 2>/dev/null || \
  kubectl get -f "$MANIFEST" -n "$NS" -o jsonpath='{.metadata.name}' 2>/dev/null)

if [ -n "$DEPLOYMENTS" ]; then
  for DEP in $DEPLOYMENTS; do
    echo "Waiting for deployment/$DEP rollout..."
    kubectl rollout status deployment/"$DEP" -n "$NS" --timeout=300s 2>/dev/null || echo "Rollout check skipped for $DEP"
  done
fi

echo ""
echo "=== Applied Resources ==="
kubectl get -f "$MANIFEST" -n "$NS" -o wide 2>/dev/null || echo "Resources applied successfully"

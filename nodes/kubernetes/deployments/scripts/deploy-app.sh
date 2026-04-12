#!/bin/bash
set -euo pipefail

# Deploy Application — create or update a Deployment and wait for rollout
# Usage: deploy-app.sh <name> <image> [replicas]

NAME=${1:?Usage: deploy-app.sh <name> <image> [replicas]}
IMAGE=${2:?Usage: deploy-app.sh <name> <image> [replicas]}
REPLICAS=${3:-3}
NS=${KUBE_NAMESPACE:-default}

echo "Deploying $NAME with image $IMAGE ($REPLICAS replicas) to namespace $NS"

kubectl create deployment "$NAME" \
  --image="$IMAGE" \
  --replicas="$REPLICAS" \
  -n "$NS" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Waiting for rollout..."
kubectl rollout status deployment/"$NAME" -n "$NS" --timeout=300s

echo ""
echo "Deployment complete:"
kubectl get deployment "$NAME" -n "$NS" -o wide

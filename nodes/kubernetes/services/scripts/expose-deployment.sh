#!/bin/bash
set -euo pipefail

# Expose Deployment — create a Service for a Deployment
# Usage: expose-deployment.sh <deployment> <port> <target-port> [type]

NAME=${1:?Usage: expose-deployment.sh <deployment> <port> <target-port> [type]}
PORT=${2:?Usage: expose-deployment.sh <deployment> <port> <target-port> [type]}
TARGET_PORT=${3:?Usage: expose-deployment.sh <deployment> <port> <target-port> [type]}
TYPE=${4:-ClusterIP}
NS=${KUBE_NAMESPACE:-default}

echo "Exposing deployment $NAME as $TYPE service (port $PORT -> $TARGET_PORT)"
kubectl expose deployment "$NAME" \
  --port="$PORT" \
  --target-port="$TARGET_PORT" \
  --type="$TYPE" \
  -n "$NS"

echo ""
kubectl get svc "$NAME" -n "$NS" -o wide

echo ""
echo "Endpoints:"
kubectl get endpoints "$NAME" -n "$NS"

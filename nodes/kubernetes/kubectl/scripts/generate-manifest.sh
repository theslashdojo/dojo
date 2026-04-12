#!/bin/bash
set -euo pipefail

# Generate Manifest — create Kubernetes YAML manifests using kubectl dry-run
# Usage: generate-manifest.sh <type> <name> [options...]
#   type: deployment, service, configmap, secret, job, cronjob
#   For deployment: generate-manifest.sh deployment my-app --image=nginx:1.25 --replicas=3
#   For service:    generate-manifest.sh service my-app --port=80 --target-port=8080 --type=ClusterIP
#   For configmap:  generate-manifest.sh configmap my-config --from-literal=KEY=value
#   For secret:     generate-manifest.sh secret my-secret --from-literal=password=s3cret

TYPE=${1:?Usage: generate-manifest.sh <type> <name> [options...]}
NAME=${2:?Usage: generate-manifest.sh <type> <name> [options...]}
shift 2

case "$TYPE" in
  deployment)
    IMAGE=""
    REPLICAS="1"
    EXTRA_ARGS=()
    for arg in "$@"; do
      case "$arg" in
        --image=*) IMAGE="${arg#--image=}" ;;
        --replicas=*) REPLICAS="${arg#--replicas=}" ;;
        *) EXTRA_ARGS+=("$arg") ;;
      esac
    done
    IMAGE=${IMAGE:?deployment requires --image=<image>}
    echo "# Generated Deployment: $NAME"
    kubectl create deployment "$NAME" \
      --image="$IMAGE" \
      --replicas="$REPLICAS" \
      --dry-run=client -o yaml "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"
    ;;

  service)
    PORT=""
    TARGET_PORT=""
    SVC_TYPE="ClusterIP"
    for arg in "$@"; do
      case "$arg" in
        --port=*) PORT="${arg#--port=}" ;;
        --target-port=*) TARGET_PORT="${arg#--target-port=}" ;;
        --type=*) SVC_TYPE="${arg#--type=}" ;;
      esac
    done
    PORT=${PORT:?service requires --port=<port>}
    TARGET_PORT=${TARGET_PORT:-$PORT}
    echo "# Generated Service: $NAME"
    cat <<EOF
apiVersion: v1
kind: Service
metadata:
  name: $NAME
spec:
  type: $SVC_TYPE
  selector:
    app: $NAME
  ports:
    - port: $PORT
      targetPort: $TARGET_PORT
      protocol: TCP
EOF
    ;;

  configmap)
    echo "# Generated ConfigMap: $NAME"
    kubectl create configmap "$NAME" "$@" --dry-run=client -o yaml
    ;;

  secret)
    echo "# Generated Secret: $NAME"
    kubectl create secret generic "$NAME" "$@" --dry-run=client -o yaml
    ;;

  job)
    IMAGE=""
    for arg in "$@"; do
      case "$arg" in
        --image=*) IMAGE="${arg#--image=}" ;;
      esac
    done
    IMAGE=${IMAGE:?job requires --image=<image>}
    echo "# Generated Job: $NAME"
    kubectl create job "$NAME" --image="$IMAGE" --dry-run=client -o yaml
    ;;

  *)
    echo "Error: Unknown type '$TYPE'. Supported: deployment, service, configmap, secret, job"
    exit 1
    ;;
esac

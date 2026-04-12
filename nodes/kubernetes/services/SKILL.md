---
name: services
description: Expose Kubernetes workloads with Services — ClusterIP, NodePort, LoadBalancer, and headless. Use when an agent needs to make Pods reachable over the network, set up service discovery, or expose applications externally.
---

# Services

Services provide stable networking for ephemeral Pods. They give a fixed DNS name and virtual IP that persists across Pod restarts and scaling.

## Prerequisites

- kubectl configured with cluster access
- Running Pods with labels matching the Service selector
- For LoadBalancer: cloud provider integration (EKS, GKE, AKS)

## Core Workflow

### 1. Expose a Deployment

```bash
# ClusterIP (internal)
kubectl expose deployment my-app --port=80 --target-port=8080

# LoadBalancer (external)
kubectl expose deployment my-app --port=80 --target-port=8080 --type=LoadBalancer
```

### 2. Verify

```bash
kubectl get svc my-app -o wide
kubectl get endpoints my-app
```

### 3. Test Connectivity

```bash
# From within the cluster
kubectl run curl-test --rm -it --image=curlimages/curl -- curl http://my-app.default.svc.cluster.local

# From local machine
kubectl port-forward svc/my-app 8080:80
```

## Service Types

| Type | Scope | Use Case |
|------|-------|----------|
| ClusterIP | Cluster-internal | Microservice communication |
| NodePort | Node IP:30000-32767 | Development, direct access |
| LoadBalancer | Cloud LB + external IP | Production external traffic |
| ExternalName | DNS CNAME | Map to external services |
| Headless | DNS only (no proxy) | StatefulSets, direct Pod access |

## DNS Resolution

Services get automatic DNS entries via CoreDNS:
- Same namespace: `my-service`
- Cross-namespace: `my-service.other-namespace`
- Fully qualified: `my-service.namespace.svc.cluster.local`

## Debugging Services

1. **No endpoints**: `kubectl get endpoints my-svc` — if empty, selector doesn't match Pod labels
2. **Labels mismatch**: Compare `kubectl get svc my-svc -o yaml | grep -A5 selector` with `kubectl get pods --show-labels`
3. **Pods not Ready**: Failing readinessProbe removes Pods from endpoints
4. **Wrong targetPort**: Verify it matches the container's listening port

## Edge Cases

- Multi-port services require each port to have a `name`
- ExternalName creates a DNS CNAME — no proxying, no port mapping
- Headless services (`clusterIP: None`) return individual Pod IPs
- `sessionAffinity: ClientIP` for sticky sessions
- Cloud LB annotations vary by provider (AWS, GCP, Azure)

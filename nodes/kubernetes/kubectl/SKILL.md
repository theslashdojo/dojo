---
name: kubectl
description: Use kubectl to interact with Kubernetes clusters — apply manifests, inspect resources, debug workloads, and manage cluster contexts. Use when an agent needs to run kubectl commands or generate Kubernetes manifests.
---

# kubectl

kubectl is the CLI for Kubernetes. Use it for all cluster interactions: deploying, inspecting, debugging, and managing resources.

## Prerequisites

- `kubectl` installed and on PATH
- Valid kubeconfig at `~/.kube/config` or `$KUBECONFIG`
- Active cluster context (`kubectl config current-context`)

## Core Workflow

### 1. Verify Connection

```bash
kubectl cluster-info
kubectl config current-context
kubectl get nodes
```

### 2. Apply Manifests

```bash
# Preview changes
kubectl diff -f manifest.yaml

# Apply
kubectl apply -f manifest.yaml

# Verify
kubectl rollout status deployment/<name>
```

### 3. Inspect Resources

```bash
kubectl get <resource> -n <namespace> -o wide
kubectl describe <resource> <name> -n <namespace>
kubectl get events --sort-by=.metadata.creationTimestamp
```

### 4. Debug

```bash
kubectl logs <pod> --tail=100
kubectl logs <pod> --previous
kubectl exec -it <pod> -- /bin/sh
kubectl port-forward pod/<pod> 8080:8080
```

## Common Patterns

### Generate manifests without creating

```bash
kubectl create deployment web --image=nginx --replicas=3 --dry-run=client -o yaml > deploy.yaml
kubectl expose deployment web --port=80 --target-port=8080 --dry-run=client -o yaml > svc.yaml
```

### Extract data with JSONPath

```bash
kubectl get pod my-pod -o jsonpath='{.status.phase}'
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.allocatable.cpu}{"\n"}{end}'
```

### Bulk operations by label

```bash
kubectl get all -l app=my-app
kubectl delete pods -l app=my-app
kubectl logs -l app=my-app --all-containers --tail=10
```

### Quick debug pod

```bash
kubectl run debug --rm -it --image=nicolaka/netshoot -- /bin/bash
kubectl run curl-test --rm -it --image=curlimages/curl -- curl http://my-service
```

## Context Switching

```bash
kubectl config get-contexts
kubectl config use-context production
kubectl config set-context --current --namespace=my-app
```

## Edge Cases

- **Multiple containers**: Use `-c <container>` for logs and exec
- **CrashLoopBackOff**: Use `--previous` flag to get logs from crashed container
- **Metrics unavailable**: `kubectl top` requires metrics-server to be installed
- **RBAC denied**: Check ServiceAccount permissions with `kubectl auth can-i <verb> <resource>`
- **Context confusion**: Always verify with `kubectl config current-context` before destructive operations

## Output Modes

| Flag | Use Case |
|------|----------|
| `-o wide` | Node name, IP, extra columns |
| `-o json` | Machine parsing with jq |
| `-o yaml` | Full resource definition |
| `-o jsonpath='{...}'` | Extract specific fields |
| `-o name` | Just resource names |
| `--sort-by=.field` | Sort output |
| `-w` / `--watch` | Live updates |

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `KUBECONFIG` | `~/.kube/config` | Kubeconfig file path |
| `KUBE_EDITOR` | `$EDITOR` | Editor for `kubectl edit` |
| `KUBECTL_EXTERNAL_DIFF` | `diff` | Diff tool for `kubectl diff` |

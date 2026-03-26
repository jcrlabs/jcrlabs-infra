# Architecture — jcrlabs Infrastructure

## Overview

Homelab Kubernetes cluster gestionado como IaC. Todo el estado vive en Git; cero `kubectl apply` manual post-bootstrap.

```
                        ┌─────────────────────────────────┐
                        │         GitHub (jcrlabs-infra)  │
                        │  argocd/ · k8s/ · monitoring/   │
                        └────────────┬────────────────────┘
                                     │ GitOps (pull)
                        ┌────────────▼────────────────────┐
                        │            ArgoCD               │
                        │   ApplicationSet auto-discover  │
                        └──┬──────────────────────────────┘
                           │ syncs
          ┌────────────────┼────────────────────┐
          │                │                    │
    ┌─────▼──────┐  ┌──────▼──────┐  ┌─────────▼────────┐
    │  prod ns   │  │  test ns    │  │   infra ns       │
    │ home       │  │ home-test   │  │ monitoring       │
    │ inventory  │  │ inv-test    │  │ cert-manager     │
    │ blog       │  │ blog-test   │  │ metallb-system   │
    │ dashboard  │  │ dash-test   │  │ sealed-secrets   │
    │ chat       │  │ chat-test   │  │ argocd           │
    │ fincontrol │  │ fin-test    │  └──────────────────┘
    └────────────┘  └─────────────┘
```

## Nodes

| Hostname | IP | Role |
|----------|-----|------|
| k8s-master | 192.168.1.10 | control-plane |
| k8s-worker-01 | 192.168.1.11 | worker |
| k8s-worker-02 | 192.168.1.12 | worker |

## Networking

- **CNI**: Calico (pod CIDR `10.244.0.0/16`)
- **LoadBalancer**: MetalLB L2 — pool `192.168.1.200-192.168.1.220`
- **Ingress**: ingress-nginx con IP de MetalLB
- **TLS**: cert-manager + Let's Encrypt DNS-01 (Cloudflare)
  - `*.jcrlabs.net` → prod (letsencrypt-prod)
  - `*-test.jcrlabs.net` → staging (letsencrypt-staging)

## GitOps Flow

1. Developer pushes manifests a `k8s/apps/{project}/`
2. ArgoCD ApplicationSet `portfolio-apps-prod` lo detecta vía git generator
3. ArgoCD sincroniza automáticamente (prune + selfHeal)
4. Para test: push a `k8s/apps-test/{project}/` → namespace `{project}-test`

## Secrets Management

Todos los secrets son **Sealed Secrets**. Flujo:

```bash
# 1. Crear secret en claro
kubectl create secret generic my-secret \
  --from-literal=key=value \
  --dry-run=client -o yaml > /tmp/secret.yaml

# 2. Cifrar con kubeseal
kubeseal --controller-namespace sealed-secrets \
  --format yaml < /tmp/secret.yaml > k8s/sealed-secrets/my-sealed-secret.yaml

# 3. Commit + push → ArgoCD lo aplica
```

## Observabilidad

| Componente | Namespace | URL |
|-----------|-----------|-----|
| Grafana | monitoring | grafana.jcrlabs.net |
| Prometheus | monitoring | (interno) |
| Alertmanager | monitoring | (interno) |
| Loki | monitoring | (interno) |

### Dashboards

- **Cluster Overview**: nodos, pods, CPU/RAM por nodo
- **Per-Service**: HTTP rate, latencia p99, CPU/RAM por pod
- **Alerts**: alertas activas en tiempo real

## Stack de versiones

| Componente | Versión |
|-----------|--------|
| Kubernetes | 1.30 |
| Calico CNI | v3.28 |
| MetalLB | v0.14.5 |
| ArgoCD | v2.11 |
| cert-manager | v1.14.5 |
| Sealed Secrets | v0.26.2 |
| kube-prometheus-stack | latest stable |
| Loki | latest stable |

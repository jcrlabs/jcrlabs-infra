# Architecture — jcrlabs Infrastructure

## Stack real

| Capa | Tecnología |
|------|------------|
| Cluster | k3d (k3s en Docker) v1.31.5 |
| Nodos | 3 control-plane + 3 workers |
| Ingress | ingress-nginx (LoadBalancer via k3d) |
| TLS externo | Cloudflare (edge termination) |
| TLS interno | cert-manager + letsencrypt-cloudflare |
| Wildcard cert | `wildcard-jcrlabs-tls` (cert-manager ns) |
| GitOps | ArgoCD + ApplicationSets |
| Secrets | Sealed Secrets |
| Observabilidad | kube-prometheus-stack + Loki + Promtail |

## Topología de red

```
Internet
    │
    ▼
Cloudflare (DNS + TLS edge termination)
    │  Cloudflare Tunnel
    ▼
Host (Docker)
    │
    ▼
ingress-nginx  ←  LoadBalancer k3d  (172.18.0.2–7:80/443)
    │
    ├── home.jcrlabs.net        → ns: home
    ├── inventory.jcrlabs.net   → ns: inventory
    ├── blog.jcrlabs.net        → ns: blog
    ├── dashboard.jcrlabs.net   → ns: dashboard
    ├── chat.jcrlabs.net        → ns: chat
    ├── fincontrol.jcrlabs.net  → ns: fincontrol
    ├── grafana.jcrlabs.net     → ns: monitoring
    └── argocd.jcrlabs.net      → ns: argocd
```

## Nodos k3d

| Nombre | IP Docker | Rol |
|--------|-----------|-----|
| k3d-jcrlabs-server-0 | 172.18.0.2 | control-plane, etcd, master |
| k3d-jcrlabs-server-1 | 172.18.0.3 | control-plane, etcd, master |
| k3d-jcrlabs-server-2 | 172.18.0.4 | control-plane, etcd, master |
| k3d-jcrlabs-agent-0  | 172.18.0.5 | worker |
| k3d-jcrlabs-agent-1  | 172.18.0.6 | worker |
| k3d-jcrlabs-agent-2  | 172.18.0.7 | worker |

## GitOps Flow

```
git push → main (jcrlabs-infra)
     │
     │  ArgoCD poll / webhook
     ▼
ApplicationSet portfolio-apps-prod
     │  detecta k8s/apps/*/
     ▼
K8s namespace = nombre del directorio
     │  prune + selfHeal automático
     ▼
Pods corriendo
```

## cert-manager (ya instalado)

- **ClusterIssuer**: `letsencrypt-cloudflare` (DNS-01, Cloudflare API)
- **Certificate**: `wildcard-jcrlabs` → secret `wildcard-jcrlabs-tls` en ns `cert-manager`
- Para nuevos proyectos: usar annotation `cert-manager.io/cluster-issuer: letsencrypt-cloudflare`
  en el Ingress; cert-manager crea el secret en el namespace del proyecto automáticamente.

## Secrets (Sealed Secrets)

```bash
# Generar sealed secret
kubectl create secret generic my-secret \
  --from-literal=key=value \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace sealed-secrets --format yaml \
  > k8s/sealed-secrets/my-sealed-secret.yaml

# Commit + push → ArgoCD lo aplica
```

## Namespaces de sistema

| Namespace | Componente |
|-----------|------------|
| `cert-manager` | cert-manager (ya instalado) |
| `ingress-nginx` | ingress-nginx (ya instalado) |
| `argocd` | ArgoCD |
| `monitoring` | kube-prometheus-stack + Loki |
| `sealed-secrets` | Sealed Secrets controller |

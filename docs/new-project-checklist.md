# Checklist — Añadir Nuevo Proyecto

## 1. Namespaces

```yaml
# k8s/namespaces/{name}.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: {name}
  labels:
    app.kubernetes.io/managed-by: argocd
    env: production
    project: {name}
---
# k8s/namespaces/{name}-test.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: {name}-test
  labels:
    app.kubernetes.io/managed-by: argocd
    env: test
    project: {name}
```

## 2. Manifests K8s — `k8s/apps/{name}/`

```
k8s/apps/{name}/
├── deployment.yaml
├── service.yaml
├── ingress.yaml
├── hpa.yaml
└── servicemonitor.yaml
```

### ingress.yaml
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {name}
  namespace: {name}
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-cloudflare
spec:
  ingressClassName: nginx
  rules:
    - host: {name}.jcrlabs.net
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {name}
                port:
                  number: 80
  tls:
    - hosts:
        - {name}.jcrlabs.net
      secretName: {name}-tls
```

### servicemonitor.yaml
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {name}
  namespace: {name}
  labels:
    release: kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app: {name}
  endpoints:
    - port: http
      path: /api/health
      interval: 30s
```

## 3. Manifests de test — `k8s/apps-test/{name}/`

Copia de `k8s/apps/{name}/` con:
- `namespace: {name}-test`
- `host: {name}-test.jcrlabs.net`
- `secretName: {name}-test-tls`

## 4. AppProject ArgoCD

Edita `argocd/projects/portfolio.yaml` y añade:
```yaml
    - namespace: {name}
      server: https://kubernetes.default.svc
    - namespace: {name}-test
      server: https://kubernetes.default.svc
```

## 5. ArgoCD auto-detecta

Tras el commit+push, el ApplicationSet lo descubre automáticamente.
```bash
argocd app list | grep {name}
```

## 6. Dashboard Grafana

Crea `monitoring/dashboards/{name}.json`.

## 7. Actualizar docs

`docs/architecture.md` — añadir fila en la tabla de dominios.

## Checklist rápida

- [ ] `k8s/namespaces/{name}.yaml`
- [ ] `k8s/namespaces/{name}-test.yaml`
- [ ] `k8s/apps/{name}/deployment.yaml`
- [ ] `k8s/apps/{name}/service.yaml`
- [ ] `k8s/apps/{name}/ingress.yaml`  ← issuer: `letsencrypt-cloudflare`
- [ ] `k8s/apps/{name}/hpa.yaml`
- [ ] `k8s/apps/{name}/servicemonitor.yaml`
- [ ] `k8s/apps-test/{name}/` (adaptado para test)
- [ ] `argocd/projects/portfolio.yaml` actualizado
- [ ] `monitoring/dashboards/{name}.json`
- [ ] `docs/architecture.md` actualizado

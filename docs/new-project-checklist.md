# Checklist — Añadir Nuevo Proyecto

Sigue estos pasos para integrar un nuevo proyecto en el cluster.

## 1. Namespaces

Crea los dos manifests en `k8s/namespaces/`:

```bash
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

## 2. Manifests K8s (producción)

Crea el directorio `k8s/apps/{name}/` con la estructura mínima:

```
k8s/apps/{name}/
├── deployment.yaml
├── service.yaml
├── ingress.yaml          # host: {name}.jcrlabs.net
├── hpa.yaml              # min: 1, max: 4
└── servicemonitor.yaml   # para Prometheus
```

### ingress.yaml mínimo
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {name}
  namespace: {name}
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
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

### servicemonitor.yaml mínimo
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

## 3. Manifests K8s (test)

Crea `k8s/apps-test/{name}/` con los mismos manifests pero:
- `namespace: {name}-test`
- `host: {name}-test.jcrlabs.net`
- `cert-manager.io/cluster-issuer: letsencrypt-staging`

## 4. Añadir a AppProject ArgoCD

Edita `argocd/projects/portfolio.yaml` y añade los namespaces:

```yaml
    - namespace: {name}
      server: https://kubernetes.default.svc
    - namespace: {name}-test
      server: https://kubernetes.default.svc
```

## 5. ArgoCD auto-detecta

Una vez hecho el commit+push, ArgoCD detecta el nuevo directorio automáticamente vía ApplicationSet y sincroniza.

```bash
# Verificar que aparece
argocd app list | grep {name}
```

## 6. Dashboard Grafana

Crea `monitoring/dashboards/{name}.json` con:
- HTTP request rate por endpoint
- Latencia p99
- CPU y memoria del pod
- Errores 4xx/5xx

## 7. Actualizar docs

Actualiza `docs/architecture.md`:
- Añadir fila en la tabla de dominios
- Actualizar diagrama si es necesario

## Checklist rápida

- [ ] `k8s/namespaces/{name}.yaml`
- [ ] `k8s/namespaces/{name}-test.yaml`
- [ ] `k8s/apps/{name}/deployment.yaml`
- [ ] `k8s/apps/{name}/service.yaml`
- [ ] `k8s/apps/{name}/ingress.yaml`
- [ ] `k8s/apps/{name}/hpa.yaml`
- [ ] `k8s/apps/{name}/servicemonitor.yaml`
- [ ] `k8s/apps-test/{name}/` (copia adaptada para test)
- [ ] `argocd/projects/portfolio.yaml` actualizado
- [ ] `monitoring/dashboards/{name}.json`
- [ ] `docs/architecture.md` actualizado

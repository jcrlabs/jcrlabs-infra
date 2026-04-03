# Secrets para blog namespace

Crear con kubeseal antes de desplegar blog-back:

## blog-back-secrets (prod)

```bash
kubectl create secret generic blog-back-secrets \
  --namespace blog \
  --from-literal=MONGODB_URI="mongodb://blog-mongodb.blog.svc.cluster.local:27017/blog" \
  --from-literal=JWT_SECRET="<genera-con-openssl-rand-hex-32>" \
  --from-literal=JWT_REFRESH_SECRET="<genera-con-openssl-rand-hex-32>" \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace sealed-secrets \
    --scope namespace-wide --format yaml \
  > k8s/blog/blog-back-secrets.yaml
```

Luego añadir `blog-back-secrets.yaml` al argocd/applications/blog-back-prod.yaml:
```yaml
helm:
  parameters:
    - name: secretName
      value: blog-back-secrets
```

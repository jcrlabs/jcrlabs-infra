# Secrets para blog-test namespace

## blog-back-secrets (test)

```bash
kubectl create secret generic blog-back-secrets \
  --namespace blog-test \
  --from-literal=MONGODB_URI="mongodb://blog-mongodb.blog-test.svc.cluster.local:27017/blog" \
  --from-literal=JWT_SECRET="<genera-con-openssl-rand-hex-32>" \
  --from-literal=JWT_REFRESH_SECRET="<genera-con-openssl-rand-hex-32>" \
  --dry-run=client -o yaml | \
  kubeseal --controller-namespace sealed-secrets \
    --scope namespace-wide --format yaml \
  > k8s/blog-test/blog-back-secrets.yaml
```

Luego en argocd/applications/blog-back-test.yaml:
```yaml
helm:
  parameters:
    - name: secretName
      value: blog-back-secrets
```

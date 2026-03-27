# CLAUDE.md — jcrlabs-infra

Repositorio de infraestructura: manifests de Kubernetes, Helm values, ArgoCD ApplicationSets y Ansible playbooks.

## CI local

Ejecutar **antes de cada commit** para evitar que lleguen errores a GitHub Actions:

```bash
yamllint -d relaxed k8s/ argocd/
```

Verificar que no hay Secrets en texto plano (solo SealedSecrets):

```bash
grep -rl --include='*.yaml' 'kind: Secret' k8s/ 2>/dev/null | \
  xargs grep -L 'SealedSecret' && echo "ERROR: secrets en texto plano" || echo "OK"
```

## Git

- Ramas: `feature/`, `bugfix/`, `hotfix/`, `release/` — sin prefijos adicionales
- Commits: convencional (`feat:`, `fix:`, `chore:`, etc.) — sin mencionar herramientas externas ni agentes en el mensaje
- PRs: título y descripción propios del cambio — sin mencionar herramientas externas ni agentes
- Comentarios y documentación: redactar en primera persona del equipo — sin atribuir autoría a herramientas

## Estructura

```
argocd/
├── applicationsets/   # ApplicationSets prod + test (git directory generator)
├── applications/      # Applications individuales (e.g. portfolio-gateway/landing)
├── projects/          # AppProjects
└── kustomization.yaml
k8s/
├── namespaces/        # Namespace manifests por proyecto
├── cert-manager/
└── sealed-secrets/
monitoring/            # kube-prometheus-stack, loki, promtail values
ansible/               # playbooks de bootstrap del cluster
```

## Convenciones

- Todos los recursos k8s gestionados por ArgoCD llevan `app.kubernetes.io/managed-by: argocd`
- Secrets siempre como SealedSecret — nunca Secret en texto plano
- Los ApplicationSets usan `CreateNamespace=true` + `ServerSideApply=true`

#!/bin/bash
# Sella el GHCR pull secret con un PAT nuevo de GitHub.
# Ejecutar DESPUÉS de generar un nuevo PAT en: GitHub → Settings → Developer settings → PATs
#
# Uso: GHCR_PAT=ghp_xxx ./scripts/seal-ghcr-secret.sh

set -euo pipefail

: "${GHCR_PAT:?Falta GHCR_PAT. Uso: GHCR_PAT=ghp_xxx $0}"

SEALED_SECRETS_CONTROLLER="sealed-secrets-controller"
SEALED_SECRETS_NS="sealed-secrets"
INFRA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GITHUB_USER="jonathancaamano"

echo "▶ Sellando ghcr-pull-secret para todos los namespaces de producción..."

for NS in portfolio portfolio-test blog blog-test inventory inventory-test dashboard dashboard-test chat chat-test fincontrol fincontrol-test home home-test; do
  kubectl create secret docker-registry ghcr-pull-secret \
    --docker-server=ghcr.io \
    --docker-username="$GITHUB_USER" \
    --docker-password="$GHCR_PAT" \
    --namespace="$NS" \
    --dry-run=client -o yaml \
  | kubeseal \
    --controller-name=$SEALED_SECRETS_CONTROLLER \
    --controller-namespace=$SEALED_SECRETS_NS \
    --format=yaml \
    > "$INFRA_DIR/k8s/sealed-secrets/ghcr-pull-secret-${NS}.yaml"

  echo "  ✅ ghcr-pull-secret para namespace: $NS"
done

echo ""
echo "Commitea y ArgoCD aplicará los secrets:"
echo "  git add k8s/sealed-secrets/ghcr-pull-secret-*.yaml"
echo "  git commit -m 'feat: renew ghcr pull secrets'"

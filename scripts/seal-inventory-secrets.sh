#!/bin/bash
# Crea y sella los secrets de inventory-back con los valores recuperados del backup.
# Ejecutar DESPUÉS de que sealed-secrets esté instalado y el controller esté listo.
#
# Uso: ./scripts/seal-inventory-secrets.sh

set -euo pipefail

SEALED_SECRETS_CONTROLLER="sealed-secrets-controller"
SEALED_SECRETS_NS="sealed-secrets"
INFRA_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "▶ Sellando secrets de inventory-back (namespace: inventory)..."

kubectl create secret generic inventory-back-secrets \
  --from-literal=DB_USER=inventory \
  --from-literal=DB_PASSWORD="jcrlabsDB_1." \
  --from-literal=JWT_SECRET="02799900869c3c268ef1bba895b390d9b46e7970120b71c7f3838ef2cd5d0079" \
  --from-literal=MINIO_ACCESS_KEY="minIOusername_1" \
  --from-literal=MINIO_SECRET_KEY="secret_MINIO_1" \
  --namespace=inventory \
  --dry-run=client -o yaml \
| kubeseal \
  --controller-name=$SEALED_SECRETS_CONTROLLER \
  --controller-namespace=$SEALED_SECRETS_NS \
  --format=yaml \
  > "$INFRA_DIR/k8s/sealed-secrets/inventory-back-secrets.yaml"

echo "▶ Sellando secrets de inventory-back (namespace: inventory-test)..."

kubectl create secret generic inventory-back-secrets \
  --from-literal=DB_USER=inventory \
  --from-literal=DB_PASSWORD="jcrlabsDB_1." \
  --from-literal=JWT_SECRET="02799900869c3c268ef1bba895b390d9b46e7970120b71c7f3838ef2cd5d0079" \
  --from-literal=MINIO_ACCESS_KEY="minIOusername_1" \
  --from-literal=MINIO_SECRET_KEY="secret_MINIO_1" \
  --namespace=inventory-test \
  --dry-run=client -o yaml \
| kubeseal \
  --controller-name=$SEALED_SECRETS_CONTROLLER \
  --controller-namespace=$SEALED_SECRETS_NS \
  --format=yaml \
  > "$INFRA_DIR/k8s/sealed-secrets/inventory-back-secrets-test.yaml"

echo "✅ SealedSecrets creados en k8s/sealed-secrets/"
echo ""
echo "Commitea los ficheros y ArgoCD los aplicará automáticamente:"
echo "  git add k8s/sealed-secrets/inventory-back-secrets*.yaml"
echo "  git commit -m 'feat: add sealed secrets for inventory-back'"

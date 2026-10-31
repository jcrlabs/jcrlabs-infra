#!/bin/bash
# Genera y sella los secrets de barber-back (solo prod) y el pull secret de GHCR.
#
# - DB_PASSWORD y JWT_PRIVATE_KEY se generan aleatoriamente la primera vez.
# - Si el secret ya existe en el cluster, se REUTILIZAN (cambiarlos rompería Postgres y las sesiones).
# - OAuth y admins se leen de variables de entorno; si no se pasan, se conservan los actuales.
#
# Uso:
#   ADMIN_EMAILS=yo@dominio.com \
#   GOOGLE_CLIENT_ID=... GOOGLE_CLIENT_SECRET=... \
#   GITHUB_CLIENT_ID=... GITHUB_CLIENT_SECRET=... \
#   TELEGRAM_BOT_TOKEN=... TELEGRAM_CHAT_ID=... \
#   ./scripts/seal-barber-secrets.sh
#
# Avisos de reservas: si no hay NTFY_URL se genera un topic privado aleatorio en ntfy.sh
# (suscríbete a él desde la app ntfy del móvil para recibir cada cita con botón de llamar).
#
# Pull secret de GHCR: usa GHCR_PAT si se define; si no, copia el de GHCR_SOURCE_NS (por defecto: inventory).

set -euo pipefail

SEALED_SECRETS_CONTROLLER="sealed-secrets-controller"
SEALED_SECRETS_NS="sealed-secrets"
INFRA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$INFRA_DIR/k8s/sealed-secrets"
GITHUB_USER="jonathancaamano"
GHCR_SOURCE_NS="${GHCR_SOURCE_NS:-inventory}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

seal() {
  kubeseal --controller-name="$SEALED_SECRETS_CONTROLLER" --controller-namespace="$SEALED_SECRETS_NS" --format=yaml
}

# Lee una clave del secret existente (vacío si no existe).
current() {
  kubectl get secret barber-back-secrets -n "$1" -o "jsonpath={.data.$2}" 2>/dev/null | base64 -d 2>/dev/null || true
}

for NS in barber; do
  SUFFIX=""
  echo "▶ barber-back-secrets ($NS)"

  DB_PASSWORD="$(current "$NS" DB_PASSWORD)"
  [ -n "$DB_PASSWORD" ] || DB_PASSWORD="$(openssl rand -base64 32 | tr -d '/+=' | cut -c1-32)"

  JWT_PRIVATE_KEY="$(current "$NS" JWT_PRIVATE_KEY)"
  if [ -z "$JWT_PRIVATE_KEY" ]; then
    openssl genrsa -out "$TMP/jwt-$NS.pem" 2048 2>/dev/null
    JWT_PRIVATE_KEY="$(base64 -w0 < "$TMP/jwt-$NS.pem")"
  fi

  pick() { local v="${!1:-}"; [ -n "$v" ] && echo "$v" || current "$NS" "$1"; }

  NTFY="$(pick NTFY_URL)"
  [ -n "$NTFY" ] || NTFY="https://ntfy.sh/edgarbarber${SUFFIX}-$(openssl rand -hex 12)"
  echo "  avisos ntfy: $NTFY"

  kubectl create secret generic barber-back-secrets \
    --namespace="$NS" \
    --from-literal=DB_USER=barber \
    --from-literal=DB_PASSWORD="$DB_PASSWORD" \
    --from-literal=JWT_PRIVATE_KEY="$JWT_PRIVATE_KEY" \
    --from-literal=ADMIN_EMAILS="$(pick ADMIN_EMAILS)" \
    --from-literal=GOOGLE_CLIENT_ID="$(pick GOOGLE_CLIENT_ID)" \
    --from-literal=GOOGLE_CLIENT_SECRET="$(pick GOOGLE_CLIENT_SECRET)" \
    --from-literal=GITHUB_CLIENT_ID="$(pick GITHUB_CLIENT_ID)" \
    --from-literal=GITHUB_CLIENT_SECRET="$(pick GITHUB_CLIENT_SECRET)" \
    --from-literal=NTFY_URL="$NTFY" \
    --from-literal=NTFY_TOKEN="$(pick NTFY_TOKEN)" \
    --from-literal=TELEGRAM_BOT_TOKEN="$(pick TELEGRAM_BOT_TOKEN)" \
    --from-literal=TELEGRAM_CHAT_ID="$(pick TELEGRAM_CHAT_ID)" \
    --dry-run=client -o yaml | seal > "$OUT/barber-back-secrets$SUFFIX.yaml"

  echo "▶ ghcr-pull-secret ($NS)"
  if [ -n "${GHCR_PAT:-}" ]; then
    kubectl create secret docker-registry ghcr-pull-secret --namespace="$NS" \
      --docker-server=ghcr.io --docker-username="$GITHUB_USER" --docker-password="$GHCR_PAT" \
      --dry-run=client -o yaml | seal > "$OUT/ghcr-pull-secret-$NS.yaml"
  else
    kubectl get secret ghcr-pull-secret -n "$GHCR_SOURCE_NS" -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d > "$TMP/dockerconfig.json"
    kubectl create secret generic ghcr-pull-secret --namespace="$NS" \
      --type=kubernetes.io/dockerconfigjson --from-file=.dockerconfigjson="$TMP/dockerconfig.json" \
      --dry-run=client -o yaml | seal > "$OUT/ghcr-pull-secret-$NS.yaml"
  fi
done

echo "✅ SealedSecrets generados en k8s/sealed-secrets/ (barber)"

#!/usr/bin/env bash
# Lance l'app sur un device avec le service token Cloudflare Access lu depuis
# collega_app/.env.local (jamais committé). Usage :
#   tool/run_device.sh                    # device par défaut, mode debug
#   tool/run_device.sh --release -d <id>  # options passées telles quelles à flutter run
set -euo pipefail
cd "$(dirname "$0")/.."
ENV_FILE=".env.local"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ $ENV_FILE introuvable — créer le fichier avec CF_ACCESS_CLIENT_ID / CF_ACCESS_CLIENT_SECRET" >&2
  exit 1
fi
set -a; # shellcheck disable=SC1090
source "$ENV_FILE"; set +a
: "${CF_ACCESS_CLIENT_ID:?manquant dans $ENV_FILE}"
: "${CF_ACCESS_CLIENT_SECRET:?manquant dans $ENV_FILE}"
exec flutter run \
  --dart-define="CF_ACCESS_CLIENT_ID=${CF_ACCESS_CLIENT_ID}" \
  --dart-define="CF_ACCESS_CLIENT_SECRET=${CF_ACCESS_CLIENT_SECRET}" \
  "$@"

#!/usr/bin/env bash
# Construit l'IPA de publication (TestFlight) avec le service token Cloudflare
# Access lu depuis collega_app/.env.local (jamais committé), puis l'envoie à
# App Store Connect si une clé API est configurée. Usage :
#   tool/build_ipa.sh
# Envoi automatique : ASC_KEY_ID / ASC_ISSUER_ID dans .env.local et la clé
# ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8 ; sinon, via Xcode.
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

# Numéro de build : minutes écoulées depuis 2026-01-01T00:00Z (1767225600).
# Toujours croissant, et tient dans un int32 pendant des siècles.
BUILD_NUMBER=$(( ($(date -u +%s) - 1767225600) / 60 ))
echo "▶ Build n° $BUILD_NUMBER"

flutter build ipa --release \
  --build-number="$BUILD_NUMBER" \
  --export-options-plist=ios/ExportOptions.plist \
  --dart-define="CF_ACCESS_CLIENT_ID=${CF_ACCESS_CLIENT_ID}" \
  --dart-define="CF_ACCESS_CLIENT_SECRET=${CF_ACCESS_CLIENT_SECRET}"

shopt -s nullglob
IPAS=(build/ios/ipa/*.ipa)
shopt -u nullglob
if [[ ${#IPAS[@]} -eq 0 ]]; then
  echo "❌ aucune IPA dans build/ios/ipa (export échoué ?)" >&2
  exit 1
fi

ASC_KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID:-}.p8"
if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" && -f "$ASC_KEY_FILE" ]]; then
  echo "▶ Envoi à App Store Connect : ${IPAS[0]}"
  xcrun altool --upload-app --type ios -f "${IPAS[0]}" \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  echo "✅ Envoyée — la build apparaît dans TestFlight après traitement (quelques minutes)."
else
  echo "ℹ️  Pas de clé App Store Connect (ASC_KEY_ID / ASC_ISSUER_ID dans $ENV_FILE + $ASC_KEY_FILE)."
  echo "   Envoi manuel : dans l'Organizer Xcode qui s'ouvre, choisir l'archive puis"
  echo "   « Distribute App » → « App Store Connect » → « Upload »."
  open build/ios/archive/Runner.xcarchive
fi

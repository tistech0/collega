#!/usr/bin/env bash
# Construit l'IPA de publication (TestFlight) avec le service token Cloudflare
# Access lu depuis collega_app/.env.local (jamais committé), puis l'envoie à
# App Store Connect si une clé API est configurée. Usage :
#   tool/build_ipa.sh               # construit, signe et envoie
#   tool/build_ipa.sh --no-upload   # construit et signe seulement (clé API)
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

ASC_KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID:-}.p8"
DEFINES=(
  --dart-define="CF_ACCESS_CLIENT_ID=${CF_ACCESS_CLIENT_ID}"
  --dart-define="CF_ACCESS_CLIENT_SECRET=${CF_ACCESS_CLIENT_SECRET}"
)

if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" && -f "$ASC_KEY_FILE" ]]; then
  # Signature par la clé API (aucun compte Apple requis dans Xcode) : Flutter
  # prépare la configuration, xcodebuild archive, exporte et envoie.
  AUTH=(-allowProvisioningUpdates
    -authenticationKeyPath "$ASC_KEY_FILE"
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID")
  flutter build ios --release --config-only --build-number="$BUILD_NUMBER" "${DEFINES[@]}"
  rm -rf build/ios/archive build/ios/ipa
  xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
    -destination 'generic/platform=iOS' -archivePath build/ios/archive/Runner.xcarchive \
    "${AUTH[@]}" -quiet archive
  xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive \
    -exportOptionsPlist ios/ExportOptions.plist -exportPath build/ios/ipa "${AUTH[@]}" -quiet
  IPA=$(ls build/ios/ipa/*.ipa)
  if [[ "${1:-}" == "--no-upload" ]]; then
    echo "✅ IPA prête (non envoyée) : $IPA"
    exit 0
  fi
  echo "▶ Envoi à App Store Connect : $IPA"
  xcrun altool --upload-app --type ios -f "$IPA" --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  echo "✅ Build $BUILD_NUMBER envoyée : elle apparaît dans TestFlight après traitement (5 à 30 min)."
else
  # Sans clé API : signature par le compte connecté dans Xcode, envoi via l'Organizer.
  flutter build ipa --release --build-number="$BUILD_NUMBER" \
    --export-options-plist=ios/ExportOptions.plist "${DEFINES[@]}"
  echo "ℹ️  Pas de clé App Store Connect (ASC_KEY_ID / ASC_ISSUER_ID dans $ENV_FILE + $ASC_KEY_FILE)."
  echo "   Envoi manuel : dans l'Organizer Xcode qui s'ouvre, choisir l'archive puis"
  echo "   « Distribute App » → « App Store Connect » → « Upload »."
  open build/ios/archive/Runner.xcarchive
fi

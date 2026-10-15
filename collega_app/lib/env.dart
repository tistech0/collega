// URL backend — jamais de secrets dans ce fichier
// En dev : pointe vers le Docker Compose local via Caddy
// En prod : pointer vers le domaine homelab configuré dans Caddyfile

const String backendBaseUrl = 'https://collega.matthislesur.com';

const String revenueCatApiKey = 'REPLACE_WITH_REVENUECAT_APPLE_API_KEY';

// RevenueCat n'est configuré qu'avec une vraie clé iOS (`appl_…`). Sinon (beta
// TestFlight sans abonnement) il reste inerte : aucun appel au SDK natif.
final bool kRevenueCatEnabled = revenueCatApiKey.startsWith('appl_');

// Service token Cloudflare Access (policy "collega-mobile token access").
// Injecté au build, jamais committé :
//   flutter run --dart-define=CF_ACCESS_CLIENT_ID=... --dart-define=CF_ACCESS_CLIENT_SECRET=...
// Vide → aucun header envoyé (OK sur le LAN, KO via le tunnel Cloudflare).
const String cfAccessClientId = String.fromEnvironment('CF_ACCESS_CLIENT_ID');
const String cfAccessClientSecret = String.fromEnvironment('CF_ACCESS_CLIENT_SECRET');

// Outils de test (réinitialiser la session du jour…) : seulement dans les builds
// de validation (`--dart-define=COLLEGA_TEST_TOOLS=true`), jamais publiés.
const bool kTestTools = bool.fromEnvironment('COLLEGA_TEST_TOOLS');

// Version affichée dans le Profil (à tenir égale à `version:` du pubspec).
const String kAppVersion = '1.0.0';

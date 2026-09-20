// URL backend — jamais de secrets dans ce fichier
// En dev : pointe vers le Docker Compose local via Caddy
// En prod : pointer vers le domaine homelab configuré dans Caddyfile

const String backendBaseUrl = 'https://collegatest.matthislesur.com';

const String revenueCatApiKey = '0f4aaa288ed5cc241dee937ffacd8bdd6605680e9a4a87c4e9ae5ae30f6dbe3c';

// Service token Cloudflare Access (policy "collega-mobile token access").
// Injecté au build, jamais committé :
//   flutter run --dart-define=CF_ACCESS_CLIENT_ID=... --dart-define=CF_ACCESS_CLIENT_SECRET=...
// Vide → aucun header envoyé (OK sur le LAN, KO via le tunnel Cloudflare).
const String cfAccessClientId = String.fromEnvironment('CF_ACCESS_CLIENT_ID');
const String cfAccessClientSecret = String.fromEnvironment('CF_ACCESS_CLIENT_SECRET');

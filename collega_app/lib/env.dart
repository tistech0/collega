// URL backend — jamais de secrets dans ce fichier
// En dev : pointe vers le Docker Compose local via Caddy
// En prod : pointer vers le domaine homelab configuré dans Caddyfile

const String backendBaseUrl = 'https://api.collega.local';

const String revenueCatApiKey = 'REPLACE_WITH_REVENUECAT_APPLE_API_KEY';

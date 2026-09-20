/// Headers Cloudflare Access (policy "Service Auth") à joindre à chaque
/// requête vers le backend quand l'app passe par le tunnel Cloudflare.
///
/// Sans ces headers, Cloudflare Access répond 302 vers sa page de login sur
/// toutes les routes (l'app ne reçoit jamais de JSON). Sur le LAN (DNS local
/// → NPM direct) Access n'intervient pas : la map vide est inoffensive.
Map<String, String> cloudflareAccessHeaders({
  required String clientId,
  required String clientSecret,
}) {
  if (clientId.isEmpty || clientSecret.isEmpty) return const {};
  return {
    'CF-Access-Client-Id': clientId,
    'CF-Access-Client-Secret': clientSecret,
  };
}

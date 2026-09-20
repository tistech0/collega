import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/network/cloudflare_access.dart';

void main() {
  group('cloudflareAccessHeaders', () {
    test('retourne les deux headers CF-Access quand id et secret sont fournis', () {
      final headers = cloudflareAccessHeaders(clientId: 'abc.access', clientSecret: 's3cr3t');
      expect(headers, {
        'CF-Access-Client-Id': 'abc.access',
        'CF-Access-Client-Secret': 's3cr3t',
      });
    });

    test('retourne une map vide si le token est absent (chemin LAN sans Access)', () {
      expect(cloudflareAccessHeaders(clientId: '', clientSecret: ''), isEmpty);
      expect(cloudflareAccessHeaders(clientId: 'abc', clientSecret: ''), isEmpty);
      expect(cloudflareAccessHeaders(clientId: '', clientSecret: 'x'), isEmpty);
    });
  });
}

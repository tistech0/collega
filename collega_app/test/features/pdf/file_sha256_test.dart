import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/pdf/pdf_providers.dart';

void main() {
  test('empreinte SHA-256 du fichier, calculée dans un isolate (même valeur que le serveur)', () async {
    final tmp = Directory.systemTemp.createTempSync('sha');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final f = File('${tmp.path}/c.pdf')..writeAsStringSync('%PDF-1.7 abc');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // hashlib.sha256(b"%PDF-1.7 abc").hexdigest()
    expect(await container.read(fileSha256Provider)(f), 'baad13769b56aaeb5b072762fefe73bc572a131353d594ec2db2b382bfabadfa');
  });
}

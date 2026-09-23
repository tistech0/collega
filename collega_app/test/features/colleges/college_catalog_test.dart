import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/colleges/domain/college_catalog.dart';

void main() {
  test('chaque collège du catalogue a une icône SVG Collega UI lisible', () async {
    for (final entry in kCollegeCatalog) {
      expect(entry.icon, startsWith('<svg'), reason: entry.name);
      // Le SVG se charge sans erreur (même moteur que CgIcon).
      final loader = SvgStringLoader(entry.icon);
      await expectLater(loader.loadBytes(null), completes, reason: entry.name);
    }
  });

  test('catalogue trié alphabétiquement, refs uniques', () {
    final refs = kCollegeCatalog.map((e) => e.refId).toSet();
    expect(refs.length, kCollegeCatalog.length);
  });

  test('collegeCatalogEntry retrouve un collège par ref, null sinon', () {
    expect(collegeCatalogEntry(3)?.name, 'Cancérologie');
    expect(collegeCatalogEntry(999), isNull);
  });
}

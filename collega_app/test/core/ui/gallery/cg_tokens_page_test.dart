import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/brand/cg_logo.dart';
import 'package:collega_app/core/ui/brand/cg_wordmark.dart';
import 'package:collega_app/core/ui/gallery/cg_tokens_page.dart';

import '../../../support/cg_golden.dart';

void main() {
  testWidgets('la page Tokens montre palette, typographie, espaces, rayons, mouvement', (tester) async {
    tester.view.physicalSize = const Size(393, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(cgTestApp(const CgTokensPage()));
    for (final section in ['Palette', 'Typographie', 'Espaces', 'Rayons', 'Mouvement']) {
      expect(find.text(section), findsOneWidget);
    }
    expect(find.text('accent'), findsOneWidget);
    expect(find.textContaining('#0E5E63'), findsWidgets);
    expect(find.byType(CgWordmark), findsOneWidget);
    expect(find.byType(CgLogo), findsOneWidget);
  });

  group('goldens', () {
    cgGoldenMatrix('tokens_page', () => const CgTokensPage(), height: 3400);
  });
}

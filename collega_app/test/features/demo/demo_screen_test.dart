import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/router/app_router.dart';
import 'package:collega_app/core/theme/app_theme.dart';

Widget _appWithRouter() {
  return ProviderScope(
    child: ShadApp.router(
      theme: buildShadTheme(),
      routerConfig: appRouter,
    ),
  );
}

void main() {
  group('DemoScreen', () {
    testWidgets('affiche le bouton "Essayer la démo"', (tester) async {
      await tester.pumpWidget(_appWithRouter());
      await tester.pumpAndSettle();
      expect(find.text('Essayer la démo'), findsOneWidget);
    });

    testWidgets('affiche le bouton "Accéder directement"', (tester) async {
      await tester.pumpWidget(_appWithRouter());
      await tester.pumpAndSettle();
      expect(find.text('Accéder directement'), findsOneWidget);
    });

    testWidgets('affiche le nom du collège fictif', (tester) async {
      await tester.pumpWidget(_appWithRouter());
      await tester.pumpAndSettle();
      expect(find.text('Cardiologie Exemple'), findsWidgets);
    });
  });
}

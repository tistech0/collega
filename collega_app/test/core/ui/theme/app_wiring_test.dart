import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/app.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';

/// Story 8.1 — l'app fournit CgTheme, s'appelle Collega et n'a plus d'ondulation Material.
void main() {
  testWidgets('App : CgTheme au-dessus des routes, Material neutralisé, titre Collega', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Navigator).first);
    expect(context.findAncestorWidgetOfExactType<CgTheme>(), isNotNull);
    expect(Theme.of(context).splashFactory, NoSplash.splashFactory);
    expect(Theme.of(context).cupertinoOverrideTheme?.primaryColor, const Color(0xFF0E5E63));

    // Titre de l'app (sélecteur d'apps) : plus jamais « AppMédecine ».
    expect(tester.widget<Title>(find.byType(Title).first).title, 'Collega');
  });
}

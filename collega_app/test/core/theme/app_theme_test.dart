import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';

void main() {
  testWidgets(
      'le rail de ShadProgress est gris clair (pas secondary vert) avec le thème app',
      (tester) async {
    // Repro iPhone 2026-09-21 : shadcn_ui peint le rail avec colorScheme.secondary
    // (vert foncé chez nous) → une barre à 0 % paraissait pleine, et les
    // ShadProgress indéterminés ressemblaient à une longue barre verte.
    await tester.pumpWidget(ShadApp(
      theme: buildShadTheme(),
      home: const Scaffold(body: ShadProgress(value: 0)),
    ));
    await tester.pump();
    // Drain pending 0ms timers from ShadApp's flutter_animate internals
    await tester.pump(Duration.zero);

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.backgroundColor, isNot(AppColors.secondary));
    expect(indicator.backgroundColor, AppColors.progressTrack);
    expect(indicator.color, AppColors.primary);
  });
}

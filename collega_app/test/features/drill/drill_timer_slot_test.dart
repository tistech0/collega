import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/drill/presentation/drill_timer_slot.dart';

import '../../support/cg_golden.dart';

/// Story 8.4 — chronomètre activable/désactivable pendant le drill (demande utilisateur).
void main() {
  Widget slot({
    int seconds = 3,
    bool enabled = true,
    bool paused = false,
    bool running = true,
    Object cardKey = 'c1',
    VoidCallback? onToggle,
    VoidCallback? onTogglePause,
    VoidCallback? onExpired,
  }) =>
      cgTestApp(Center(
        child: DrillTimerSlot(
          enabled: enabled,
          paused: paused,
          running: running,
          durationSeconds: seconds,
          cardKey: cardKey,
          onToggle: onToggle ?? () {},
          onTogglePause: onTogglePause ?? () {},
          onExpired: onExpired ?? () {},
        ),
      ));

  testWidgets('désactivé : icône « Activer le chronomètre », tap → onToggle', (tester) async {
    final handle = tester.ensureSemantics();
    var toggles = 0;
    await tester.pumpWidget(slot(enabled: false, onToggle: () => toggles++));
    expect(find.bySemanticsLabel('Activer le chronomètre'), findsOneWidget);
    await tester.tap(find.byType(DrillTimerSlot));
    expect(toggles, 1);
    expect(tester.getSize(find.byType(DrillTimerSlot)), const Size(44, 44));
    handle.dispose();
  });

  testWidgets('activé : compte à rebours, expire une seule fois', (tester) async {
    var expired = 0;
    await tester.pumpWidget(slot(onExpired: () => expired++));
    expect(find.text('3'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1, milliseconds: 100));
    expect(find.text('2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(expired, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(expired, 1);
  });

  testWidgets('en pause : n’expire pas ; appui long → onTogglePause', (tester) async {
    var expired = 0;
    var pauses = 0;
    await tester.pumpWidget(slot(paused: true, onExpired: () => expired++, onTogglePause: () => pauses++));
    await tester.pump(const Duration(seconds: 5));
    expect(expired, 0);
    await tester.longPress(find.byType(DrillTimerSlot));
    expect(pauses, 1);
  });

  testWidgets('réponse ouverte (running false) : le temps s’arrête', (tester) async {
    var expired = 0;
    await tester.pumpWidget(slot(running: false, onExpired: () => expired++));
    await tester.pump(const Duration(seconds: 5));
    expect(expired, 0);
  });

  testWidgets('fiche suivante (cardKey) : le compte repart de la durée complète', (tester) async {
    await tester.pumpWidget(slot(cardKey: 'c1'));
    await tester.pump(const Duration(seconds: 2, milliseconds: 100));
    expect(find.text('1'), findsOneWidget);
    await tester.pumpWidget(slot(cardKey: 'c2'));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('activé : VoiceOver lit l’état et le temps restant', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(slot());
    expect(find.bySemanticsLabel(RegExp(r'^Chronomètre activé, 3 secondes')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('durée modifiée en cours (réglages chargés après) : le compte suit la nouvelle durée', (tester) async {
    var expired = 0;
    await tester.pumpWidget(slot(seconds: 30, onExpired: () => expired++));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(slot(seconds: 2, onExpired: () => expired++));
    await tester.pump(const Duration(seconds: 3));
    expect(expired, 1);
  });
}

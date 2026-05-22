import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/drill/widgets/timer_ring.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('TimerRing (Story 7.4)', () {
    testWidgets('appelle onExpired après durationSeconds', (tester) async {
      var expired = false;
      await tester.pumpWidget(_wrap(TimerRing(
        durationSeconds: 2,
        cardId: 'card-1',
        isPaused: false,
        onExpired: () => expired = true,
      )));
      expect(expired, isFalse);
      // Avance le ticker de 2.5s pour dépasser la durée
      await tester.pump(const Duration(milliseconds: 2500));
      expect(expired, isTrue);

      // Évite les pending timers / tickers leaks à la fin du test
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    });

    testWidgets('isPaused=true à l\'init → pas d\'expiration spontanée',
        (tester) async {
      var expired = false;
      await tester.pumpWidget(_wrap(TimerRing(
        durationSeconds: 1,
        cardId: 'card-1',
        isPaused: true,
        onExpired: () => expired = true,
      )));
      await tester.pump(const Duration(seconds: 3));
      expect(expired, isFalse);
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    });

    testWidgets('pause après démarrage → bloque la décompte', (tester) async {
      var expired = false;
      var paused = false;

      Widget build() => _wrap(TimerRing(
            durationSeconds: 2,
            cardId: 'card-1',
            isPaused: paused,
            onExpired: () => expired = true,
          ));

      await tester.pumpWidget(build());
      await tester.pump(const Duration(milliseconds: 500));
      paused = true;
      await tester.pumpWidget(build());
      // Laisse passer largement plus que la durée initiale → ne doit pas expirer
      await tester.pump(const Duration(seconds: 5));
      expect(expired, isFalse);

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    });

    testWidgets('changement de cardId → reset du timer', (tester) async {
      var expired = false;
      var cardId = 'card-1';

      Widget build() => _wrap(TimerRing(
            durationSeconds: 2,
            cardId: cardId,
            isPaused: false,
            onExpired: () => expired = true,
          ));

      await tester.pumpWidget(build());
      // ~1.5s du timer écoulés
      await tester.pump(const Duration(milliseconds: 1500));
      expect(expired, isFalse);

      // Change la cardId → reset complet
      cardId = 'card-2';
      await tester.pumpWidget(build());

      // 1s de plus : avec reset, on n'est qu'à 1s du nouveau timer (< 2s)
      await tester.pump(const Duration(seconds: 1));
      expect(expired, isFalse);

      // Encore 1.5s pour dépasser la nouvelle durée (total : 2.5s depuis reset)
      await tester.pump(const Duration(milliseconds: 1500));
      expect(expired, isTrue);

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    });

    testWidgets('affiche le compte à rebours en secondes', (tester) async {
      await tester.pumpWidget(_wrap(TimerRing(
        durationSeconds: 3,
        cardId: 'card-1',
        isPaused: true, // pause pour figer l'affichage à 3s
        onExpired: () {},
      )));
      // Au démarrage en pause, on doit voir "3s"
      expect(find.text('3s'), findsOneWidget);
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    });
  });
}

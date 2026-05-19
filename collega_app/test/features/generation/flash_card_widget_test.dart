import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';
import 'package:collega_app/features/generation/widgets/flash_card_widget.dart';

FlashCardModel _makeCard({
  String rang = 'A',
  String cardType = 'classic',
  double ocrScore = 0.9,
  bool lowConfidence = false,
}) =>
    FlashCardModel(
      id: 'test-id',
      itemId: 'item-id',
      collegeId: 'college-id',
      cardType: cardType,
      rang: rang,
      recto: 'Question test',
      verso: 'Réponse test',
      ocrConfidenceScore: ocrScore,
      lowConfidence: lowConfidence,
    );

Widget _wrap(Widget child) => ShadApp(
      theme: buildShadTheme(),
      home: Scaffold(body: child),
    );

void main() {
  group('FlashCardWidget', () {
    testWidgets('recto affiche question + badge rang A', (tester) async {
      await tester.pumpWidget(_wrap(
        FlashCardWidget(card: _makeCard(rang: 'A'), isFlipped: false),
      ));
      await tester.pump(Duration.zero);

      expect(find.text('Question test'), findsOneWidget);
      expect(find.text('Rang A'), findsOneWidget);
    });

    testWidgets('recto affiche badge rang B', (tester) async {
      await tester.pumpWidget(_wrap(
        FlashCardWidget(card: _makeCard(rang: 'B'), isFlipped: false),
      ));
      await tester.pump(Duration.zero);

      expect(find.text('Rang B'), findsOneWidget);
    });

    testWidgets('recto affiche badge rang C', (tester) async {
      await tester.pumpWidget(_wrap(
        FlashCardWidget(card: _makeCard(rang: 'C'), isFlipped: false),
      ));
      await tester.pump(Duration.zero);

      expect(find.text('Rang C'), findsOneWidget);
    });

    // OcrConfidenceBadge piloté par ocrConfidenceScore (seuil >= 0.7 → absent)
    testWidgets('OcrConfidenceBadge absent si ocrConfidenceScore >= 0.7', (tester) async {
      await tester.pumpWidget(_wrap(
        FlashCardWidget(
            card: _makeCard(ocrScore: 0.9),
            isFlipped: false),
      ));
      await tester.pump(Duration.zero);

      expect(find.text('À vérifier'), findsNothing);
      expect(find.text('Source peu lisible'), findsNothing);
    });

    // OcrConfidenceBadge piloté par ocrConfidenceScore (score < 0.5 → "Source peu lisible")
    testWidgets('OcrConfidenceBadge visible si ocrConfidenceScore < 0.5', (tester) async {
      await tester.pumpWidget(_wrap(
        FlashCardWidget(
            card: _makeCard(ocrScore: 0.4),
            isFlipped: false),
      ));
      await tester.pump(Duration.zero);

      expect(find.text('Source peu lisible'), findsOneWidget);
    });

    testWidgets('tap appelle onFlip', (tester) async {
      var flipped = false;
      await tester.pumpWidget(_wrap(
        FlashCardWidget(
          card: _makeCard(),
          isFlipped: false,
          onFlip: () {
            flipped = true;
          },
        ),
      ));
      await tester.pump(Duration.zero);

      await tester.tap(find.byType(FlashCardWidget));
      await tester.pump(Duration.zero);

      expect(flipped, isTrue);
    });

    // Recto visible avant flip, verso absent (DrillEvaluationBar invisible géré côté parent)
    testWidgets('recto visible avant flip — verso absent', (tester) async {
      await tester.pumpWidget(_wrap(
        FlashCardWidget(card: _makeCard(), isFlipped: false),
      ));
      await tester.pump(Duration.zero);

      expect(find.text('Question test'), findsOneWidget);
      expect(find.text('Réponse test'), findsNothing);
    });

    testWidgets('variant definition — même comportement flip', (tester) async {
      await tester.pumpWidget(_wrap(
        FlashCardWidget(
          card: _makeCard(cardType: 'definition', rang: 'B'),
          isFlipped: false,
        ),
      ));
      await tester.pump(Duration.zero);

      expect(find.text('Question test'), findsOneWidget);
      expect(find.text('Rang B'), findsOneWidget);
    });

    // ─── Story 7.1 — R2 + R4 ───────────────────────────────────────────────

    testWidgets('AC1: tap sans onFlip ne déclenche pas le flip visuel',
        (tester) async {
      // R4 — si onFlip est null (def card recto), _handleTap doit early-return
      // sans démarrer l'animation locale.
      await tester.pumpWidget(_wrap(
        FlashCardWidget(
          card: _makeCard(cardType: 'definition'),
          isFlipped: false,
          // onFlip omis volontairement → null
        ),
      ));
      await tester.pump(Duration.zero);

      // Recto visible avant tap
      expect(find.text('Question test'), findsOneWidget);
      expect(find.text('Réponse test'), findsNothing);

      await tester.tap(find.byType(FlashCardWidget));
      await tester.pump(const Duration(milliseconds: 400)); // > 300ms anim

      // Recto toujours visible — pas de flip déclenché
      expect(find.text('Question test'), findsOneWidget);
      expect(find.text('Réponse test'), findsNothing);
    });

    testWidgets('AC2: tap re-flip d\'une carte déjà retournée appelle onFlip',
        (tester) async {
      // R2 — sur une carte verso, un tap doit re-déclencher onFlip
      // (le parent toggle isFlipped → didUpdateWidget reverse l'anim).
      var flipCount = 0;
      await tester.pumpWidget(_wrap(
        FlashCardWidget(
          card: _makeCard(),
          isFlipped: true, // carte déjà retournée
          onFlip: () => flipCount++,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FlashCardWidget));
      await tester.pump(const Duration(milliseconds: 400));

      expect(flipCount, 1);
    });

    testWidgets('AC2: tap après exitResult ne déclenche pas onFlip',
        (tester) async {
      // R2 — une fois l'évaluation cliquée (exitResult != null), la carte
      // glisse hors écran et les taps ne doivent plus déclencher de flip.
      var flipCount = 0;
      await tester.pumpWidget(_wrap(
        FlashCardWidget(
          card: _makeCard(),
          isFlipped: true,
          exitResult: DrillEvaluationResult.maitrise,
          onFlip: () => flipCount++,
        ),
      ));
      await tester.pump(Duration.zero);

      await tester.tap(find.byType(FlashCardWidget), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));

      expect(flipCount, 0);
    });
  });
}

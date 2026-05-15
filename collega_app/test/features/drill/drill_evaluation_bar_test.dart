import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';
import 'package:collega_app/features/drill/widgets/drill_evaluation_bar.dart';

Widget _wrap(Widget child) => ShadApp(
      theme: buildShadTheme(),
      home: Scaffold(body: child),
    );

void main() {
  group('DrillEvaluationBar', () {
    testWidgets('3 boutons présents avec textes corrects', (tester) async {
      await tester.pumpWidget(_wrap(
        DrillEvaluationBar(isVisible: true, onEvaluate: (_) {}),
      ));
      // Drain pending 0ms timers from ShadApp's flutter_animate internals
      await tester.pump(Duration.zero);

      expect(find.text('À revoir'), findsOneWidget);
      expect(find.text('Bien'), findsOneWidget);
      expect(find.text('Maîtrisé'), findsOneWidget);
    });

    testWidgets('tap Maîtrisé → callback maitrise', (tester) async {
      DrillEvaluationResult? result;
      await tester.pumpWidget(_wrap(
        DrillEvaluationBar(
          isVisible: true,
          onEvaluate: (r) {
            result = r;
          },
        ),
      ));
      await tester.pump(Duration.zero);

      await tester.tap(find.text('Maîtrisé'));
      await tester.pump(Duration.zero);

      expect(result, DrillEvaluationResult.maitrise);
    });

    testWidgets('tap À revoir → callback aRevoir', (tester) async {
      DrillEvaluationResult? result;
      await tester.pumpWidget(_wrap(
        DrillEvaluationBar(
          isVisible: true,
          onEvaluate: (r) {
            result = r;
          },
        ),
      ));
      await tester.pump(Duration.zero);

      await tester.tap(find.text('À revoir'));
      await tester.pump(Duration.zero);

      expect(result, DrillEvaluationResult.aRevoir);
    });

    testWidgets('tap Bien → callback bien', (tester) async {
      DrillEvaluationResult? result;
      await tester.pumpWidget(_wrap(
        DrillEvaluationBar(
          isVisible: true,
          onEvaluate: (r) {
            result = r;
          },
        ),
      ));
      await tester.pump(Duration.zero);

      await tester.tap(find.text('Bien'));
      await tester.pump(Duration.zero);

      expect(result, DrillEvaluationResult.bien);
    });

    testWidgets('isVisible false → boutons non interactifs (IgnorePointer)',
        (tester) async {
      var called = false;
      await tester.pumpWidget(_wrap(
        DrillEvaluationBar(
          isVisible: false,
          onEvaluate: (_) {
            called = true;
          },
        ),
      ));
      await tester.pump(Duration.zero);

      await tester.tap(find.text('Maîtrisé'), warnIfMissed: false);
      await tester.pump(Duration.zero);

      expect(called, isFalse);
    });
  });
}

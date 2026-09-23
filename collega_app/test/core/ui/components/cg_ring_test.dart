import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/components/cg_ring.dart';
import 'package:collega_app/core/ui/gallery/cg_ring_gallery.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

import '../../../support/cg_golden.dart';

const c = CgColors.light;

/// Le peintre de l'anneau (valeur affichée à l'instant, couleurs, épaisseur).
CgRingPainter _painter(WidgetTester tester) => tester
    .widget<CustomPaint>(find.descendant(of: find.byType(CgRing), matching: find.byType(CustomPaint)))
    .painter! as CgRingPainter;

Widget _ring(double value, {bool reduced = false, bool animate = true, CgRingSize size = CgRingSize.s}) =>
    cgTestApp(Center(child: CgRing(value: value, animate: animate, size: size)), disableAnimations: reduced);

void main() {
  group('géométrie et couleurs', () {
    for (final (size, diameter, stroke, style) in [
      (CgRingSize.s, 56.0, 5.0, CgType.label),
      (CgRingSize.m, 84.0, 7.0, CgType.head),
      (CgRingSize.l, 200.0, 14.0, CgType.display),
    ]) {
      testWidgets('$size : ${diameter.toInt()} pt, trait ${stroke.toInt()}, texte ${style.fontSize}', (tester) async {
        await tester.pumpWidget(_ring(0.42, size: size, animate: false));
        expect(tester.getSize(find.byType(CgRing)), Size(diameter, diameter));
        final p = _painter(tester);
        expect(p.strokeWidth, stroke);
        expect(p.track, c.unseen);
        expect(p.arc, c.accent);
        final text = tester.widget<Text>(find.text('42 %'));
        expect(text.style?.fontSize, style.fontSize);
        expect(text.style?.fontFeatures, contains(const FontFeature.tabularFigures()));
      });
    }

    testWidgets('centerLabel remplace le pourcentage', (tester) async {
      await tester.pumpWidget(cgTestApp(const Center(child: CgRing(value: 0.5, centerLabel: '12/24', animate: false))));
      expect(find.text('12/24'), findsOneWidget);
      expect(find.text('50 %'), findsNothing);
    });

    testWidgets('valeur hors bornes ramenée à 0..1', (tester) async {
      await tester.pumpWidget(_ring(1.4, animate: false));
      expect(_painter(tester).progress, 1);
      expect(find.text('100 %'), findsOneWidget);
    });
  });

  group('animation', () {
    testWidgets('remplissage 0 → valeur en 900 ms, une fois à l\'apparition', (tester) async {
      await tester.pumpWidget(_ring(0.6));
      expect(_painter(tester).progress, 0);
      await tester.pump(CgMotion.ringFill ~/ 2);
      final mid = _painter(tester).progress;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(0.6));
      await tester.pump(CgMotion.ringFill ~/ 2);
      expect(_painter(tester).progress, closeTo(0.6, 1e-9));

      // Un rebuild à valeur égale ne relance pas le remplissage.
      await tester.pumpWidget(_ring(0.6));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_painter(tester).progress, closeTo(0.6, 1e-9));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('nouvelle valeur : anime de l\'ancienne à la nouvelle (pas depuis 0)', (tester) async {
      await tester.pumpWidget(_ring(0.4));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_ring(0.8));
      await tester.pump(const Duration(milliseconds: 16));
      final early = _painter(tester).progress;
      expect(early, greaterThanOrEqualTo(0.4));
      expect(early, lessThan(0.8));
      await tester.pumpAndSettle();
      expect(_painter(tester).progress, closeTo(0.8, 1e-9));
      expect(find.text('80 %'), findsOneWidget);
    });

    testWidgets('mouvement réduit : valeur directe, aucune animation', (tester) async {
      await tester.pumpWidget(_ring(0.42, reduced: true));
      expect(_painter(tester).progress, 0.42);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(_ring(0.7, reduced: true));
      expect(_painter(tester).progress, 0.7);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('animate: false : valeur directe', (tester) async {
      await tester.pumpWidget(_ring(0.42, animate: false));
      expect(_painter(tester).progress, 0.42);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('accessibilité', () {
    testWidgets('Semantics : value « 42 % » et libellé', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(cgTestApp(const Center(
        child: CgRing(value: 0.42, semanticLabel: 'Cancérologie maîtrisée', animate: false),
      )));
      expect(
        tester.getSemantics(find.byType(CgRing)),
        matchesSemantics(label: 'Cancérologie maîtrisée', value: '42 %'),
      );
      handle.dispose();
    });

    testWidgets('Dynamic Type 1,6 : la valeur tient dans l\'anneau s', (tester) async {
      await tester.pumpWidget(cgTestApp(
        const Center(child: CgRing(value: 1, animate: false)),
        textScale: 1.6,
      ));
      expect(tester.takeException(), isNull);
      final ring = tester.getRect(find.byType(CgRing));
      final label = tester.getRect(find.text('100 %'));
      expect(ring.contains(label.topLeft) && ring.contains(label.bottomRight), isTrue);
    });
  });

  group('goldens', () {
    cgGoldenMatrix('cg_ring', () => const CgRingGallery(), height: 480);
  });
}

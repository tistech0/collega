import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/components/cg_verdict_bar.dart';
import 'package:collega_app/core/ui/gallery/cg_verdict_bar_gallery.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';

import '../../../support/cg_golden.dart';

const c = CgColors.light;

Finder _button(CgVerdict v) => find.byKey(CgVerdictBar.buttonKey(v));

BoxDecoration _decoration(WidgetTester tester, CgVerdict v) => tester
    .widget<DecoratedBox>(find.descendant(of: _button(v), matching: find.byType(DecoratedBox)).first)
    .decoration as BoxDecoration;

Color? _textColor(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style?.color;

/// Enregistre les appels `HapticFeedback.vibrate` (canal plateforme).
List<String> _recordHaptics() {
  final calls = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments as String);
    return null;
  });
  addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return calls;
}

Widget _bar({ValueChanged<CgVerdict>? onVerdict, bool enabled = true}) => cgTestApp(Center(
      child: Padding(
        padding: const EdgeInsets.all(CgSpace.gutter),
        child: CgVerdictBar(onVerdict: onVerdict ?? (_) {}, enabled: enabled),
      ),
    ));

void main() {
  group('anatomie', () {
    testWidgets('trois boutons égaux de 54 pt, libellés et couleurs des tokens', (tester) async {
      await tester.pumpWidget(_bar());
      for (final v in CgVerdict.values) {
        expect(tester.getSize(_button(v)).height, CgSpace.buttonHeight, reason: v.name);
      }
      final w = tester.getSize(_button(CgVerdict.review)).width;
      expect(tester.getSize(_button(CgVerdict.good)).width, w);
      expect(tester.getSize(_button(CgVerdict.mastered)).width, w);
      // Ordre visuel = ordre des gestes : à revoir (gauche), bien, maîtrisé (droite).
      expect(tester.getCenter(_button(CgVerdict.review)).dx, lessThan(tester.getCenter(_button(CgVerdict.good)).dx));
      expect(tester.getCenter(_button(CgVerdict.good)).dx, lessThan(tester.getCenter(_button(CgVerdict.mastered)).dx));

      expect(_decoration(tester, CgVerdict.review).color, c.surface);
      expect((_decoration(tester, CgVerdict.review).border as Border).top.color, c.line);
      expect(_textColor(tester, 'À revoir'), c.reviewInk);
      expect(_decoration(tester, CgVerdict.good).color, c.surface);
      expect(_textColor(tester, 'Bien'), c.ink);
      expect(_decoration(tester, CgVerdict.mastered).color, c.accent);
      expect(_textColor(tester, 'Maîtrisé'), c.accentInk);
    });
  });

  group('comportement', () {
    testWidgets('chaque bouton émet son verdict avec une haptique distincte', (tester) async {
      final calls = _recordHaptics();
      final verdicts = <CgVerdict>[];
      await tester.pumpWidget(_bar(onVerdict: verdicts.add));
      await tester.tap(_button(CgVerdict.review));
      await tester.tap(_button(CgVerdict.good));
      await tester.tap(_button(CgVerdict.mastered));
      expect(verdicts, [CgVerdict.review, CgVerdict.good, CgVerdict.mastered]);
      expect(calls, [
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
    });

    testWidgets('pressé : échelle 0,97 puis retour', (tester) async {
      await tester.pumpWidget(_bar());
      final gesture = await tester.startGesture(tester.getCenter(_button(CgVerdict.good)));
      await tester.pumpAndSettle();
      final scale = find.descendant(of: _button(CgVerdict.good), matching: find.byType(AnimatedScale));
      expect(tester.widget<AnimatedScale>(scale).scale, 0.97);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(scale).scale, 1);
    });

    testWidgets('désactivée : aucun verdict, aucune haptique', (tester) async {
      final calls = _recordHaptics();
      final verdicts = <CgVerdict>[];
      await tester.pumpWidget(_bar(onVerdict: verdicts.add, enabled: false));
      for (final v in CgVerdict.values) {
        await tester.tap(_button(v), warnIfMissed: false);
      }
      expect(verdicts, isEmpty);
      expect(calls, isEmpty);
    });
  });

  group('Dynamic Type', () {
    testWidgets('1,6 : toujours sur une ligne, sans débordement', (tester) async {
      tester.view.physicalSize = const Size(375, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(cgTestApp(
        const Padding(
          padding: EdgeInsets.all(CgSpace.gutter),
          child: Align(alignment: Alignment.topCenter, child: CgVerdictBar(onVerdict: _noop)),
        ),
        textScale: 1.6,
      ));
      expect(tester.takeException(), isNull);
      final y = tester.getCenter(_button(CgVerdict.review)).dy;
      expect(tester.getCenter(_button(CgVerdict.good)).dy, y);
      expect(tester.getCenter(_button(CgVerdict.mastered)).dy, y);
    });

    testWidgets('au-delà de 1,6 : trois boutons empilés pleine largeur', (tester) async {
      tester.view.physicalSize = const Size(375, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(cgTestApp(
        const Padding(
          padding: EdgeInsets.all(CgSpace.gutter),
          child: Align(alignment: Alignment.topCenter, child: CgVerdictBar(onVerdict: _noop)),
        ),
        textScale: 2,
      ));
      expect(tester.takeException(), isNull);
      final review = tester.getRect(_button(CgVerdict.review));
      final good = tester.getRect(_button(CgVerdict.good));
      final mastered = tester.getRect(_button(CgVerdict.mastered));
      expect(review.bottom, lessThanOrEqualTo(good.top));
      expect(good.bottom, lessThanOrEqualTo(mastered.top));
      expect(review.width, 375 - 2 * CgSpace.gutter);
    });
  });

  testWidgets('Semantics : trois boutons standard, libellés français', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_bar());
    for (final (v, label) in [
      (CgVerdict.review, 'À revoir'),
      (CgVerdict.good, 'Bien'),
      (CgVerdict.mastered, 'Maîtrisé'),
    ]) {
      expect(
        tester.getSemantics(_button(v)),
        matchesSemantics(label: label, isButton: true, hasEnabledState: true, isEnabled: true, hasTapAction: true),
      );
    }
    handle.dispose();
  });

  group('goldens', () {
    cgGoldenMatrix('cg_verdict_bar', () => const CgVerdictBarGallery(), height: 700);
  });
}

void _noop(CgVerdict _) {}

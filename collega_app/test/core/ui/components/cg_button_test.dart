import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/components/cg_button.dart';
import 'package:collega_app/core/ui/gallery/cg_button_gallery.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';

import '../../../support/cg_golden.dart';

const c = CgColors.light;

Color? _fill(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: find.byType(CgButton), matching: find.byType(DecoratedBox)).first,
  );
  return (box.decoration as BoxDecoration).color;
}

Color? _textColor(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style?.color;

void main() {
  group('variantes', () {
    for (final (variant, fill, text) in [
      (CgButtonVariant.primary, c.accent, c.accentInk),
      (CgButtonVariant.secondary, c.surface, c.ink),
      (CgButtonVariant.inverse, c.accentInk, c.accent),
    ]) {
      testWidgets('$variant : fond et texte des tokens', (tester) async {
        await tester.pumpWidget(cgTestApp(Center(
          child: CgButton(label: 'Commencer', onPressed: () {}, variant: variant),
        )));
        expect(_fill(tester), fill);
        expect(_textColor(tester, 'Commencer'), text);
      });
    }

    testWidgets('quiet : texte accent, sans fond', (tester) async {
      await tester.pumpWidget(cgTestApp(Center(
        child: CgButton(label: 'Personnaliser', onPressed: () {}, variant: CgButtonVariant.quiet),
      )));
      expect(_fill(tester), isNull);
      expect(_textColor(tester, 'Personnaliser'), c.accent);
    });

    testWidgets('destructive : texte danger', (tester) async {
      await tester.pumpWidget(cgTestApp(Center(
        child: CgButton(label: 'Supprimer', onPressed: () {}, variant: CgButtonVariant.destructive),
      )));
      expect(_textColor(tester, 'Supprimer'), c.danger);
    });
  });

  group('tailles', () {
    testWidgets('regular 54 pt pleine largeur, compact 44 pt', (tester) async {
      await tester.pumpWidget(cgTestApp(Column(children: [
        CgButton(key: const Key('r'), label: 'A', onPressed: () {}),
        CgButton(key: const Key('c'), label: 'B', onPressed: () {}, size: CgButtonSize.compact, expand: false),
      ])));
      expect(tester.getSize(find.byKey(const Key('r'))).height, CgSpace.buttonHeight);
      expect(tester.getSize(find.byKey(const Key('r'))).width, 800);
      expect(tester.getSize(find.byKey(const Key('c'))).height, CgSpace.buttonHeightCompact);
      expect(tester.getSize(find.byKey(const Key('c'))).width, lessThan(800));
    });
  });

  group('états', () {
    testWidgets('tap appelle onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(cgTestApp(Center(child: CgButton(label: 'Go', onPressed: () => taps++))));
      await tester.tap(find.byType(CgButton));
      expect(taps, 1);
    });

    testWidgets('pressé : échelle 0,97', (tester) async {
      await tester.pumpWidget(cgTestApp(Center(child: CgButton(label: 'Go', onPressed: () {}))));
      final gesture = await tester.startGesture(tester.getCenter(find.byType(CgButton)));
      await tester.pumpAndSettle();
      final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
      expect(scale.scale, 0.97);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    });

    testWidgets('désactivé : texte ink3, fond soft, non tapable', (tester) async {
      await tester.pumpWidget(cgTestApp(const Center(child: CgButton(label: 'Enregistrer', onPressed: null))));
      expect(_textColor(tester, 'Enregistrer'), c.ink3);
      expect(_fill(tester), c.soft);
    });

    testWidgets('chargement : indicateur à la place du libellé, largeur figée, non tapable', (tester) async {
      var taps = 0;
      await tester.pumpWidget(cgTestApp(Center(
        child: CgButton(label: 'Se connecter', onPressed: () => taps++, expand: false),
      )));
      final width = tester.getSize(find.byType(CgButton)).width;
      await tester.pumpWidget(cgTestApp(Center(
        child: CgButton(label: 'Se connecter', onPressed: () => taps++, expand: false, loading: true),
      )));
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(tester.getSize(find.byType(CgButton)).width, width);
      await tester.tap(find.byType(CgButton), warnIfMissed: false);
      expect(taps, 0);
    });
  });

  testWidgets('Semantics : bouton, libellé = verbe, activé/désactivé', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(cgTestApp(Column(children: [
      CgButton(label: 'Commencer', onPressed: () {}),
      const CgButton(label: 'Enregistrer', onPressed: null),
    ])));
    expect(
      tester.getSemantics(find.byType(CgButton).first),
      matchesSemantics(label: 'Commencer', isButton: true, hasEnabledState: true, isEnabled: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.byType(CgButton).last),
      matchesSemantics(label: 'Enregistrer', isButton: true, hasEnabledState: true, isEnabled: false),
    );
    handle.dispose();
  });

  group('goldens', () {
    cgGoldenMatrix('cg_button', () => const CgButtonGallery(), height: 900);
  });
}

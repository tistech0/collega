import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/components/cg_card_type_tag.dart';
import 'package:collega_app/core/ui/gallery/cg_card_type_tag_gallery.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/contrast.dart';

import '../../../support/cg_golden.dart';

const c = CgColors.light;

BoxDecoration _decoration(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: find.byType(CgCardTypeTag), matching: find.byType(DecoratedBox)).first,
  );
  return box.decoration as BoxDecoration;
}

void main() {
  group('étiquette', () {
    for (final text in ['Cas clinique', 'Définition']) {
      testWidgets('$text : contour ink3, texte ink2, rayon du badge', (tester) async {
        await tester.pumpWidget(cgTestApp(Center(child: CgCardTypeTag(text))));
        expect(find.text(text), findsOneWidget);
        final d = _decoration(tester);
        expect(d.color, isNull, reason: 'contourée : le badge de rang, lui, est plein');
        expect((d.border! as Border).top.color, c.ink3);
        expect(d.borderRadius, CgRadius.badgeAll);
        expect(tester.widget<Text>(find.text(text)).style?.color, c.ink2);
      });
    }

    testWidgets('sans libellé (classique) : rien d’affiché', (tester) async {
      await tester.pumpWidget(cgTestApp(const Center(child: CgCardTypeTag(null))));
      expect(find.byType(Text), findsNothing);
      expect(tester.getSize(find.byType(CgCardTypeTag)), Size.zero);
    });

    testWidgets('sur le recto (accent) : texte accentInk', (tester) async {
      await tester.pumpWidget(cgTestApp(const Center(child: CgCardTypeTag('Définition', onAccent: true))));
      expect(tester.widget<Text>(find.text('Définition')).style?.color, c.accentInk);
    });

    testWidgets('hauteur 22 pt à 1,0 ; grandit avec le Dynamic Type sans déborder', (tester) async {
      await tester.pumpWidget(cgTestApp(const Center(child: CgCardTypeTag('Cas clinique'))));
      expect(tester.getSize(find.byType(CgCardTypeTag)).height, 22);
      await tester.pumpWidget(cgTestApp(const Center(child: CgCardTypeTag('Cas clinique')), textScale: 1.6));
      expect(tester.getSize(find.byType(CgCardTypeTag)).height, greaterThan(22));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Semantics : « Fiche cas clinique » lu comme un seul élément', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(cgTestApp(const Column(children: [
        CgCardTypeTag('Cas clinique'),
        CgCardTypeTag('Définition'),
      ])));
      final tags = find.byType(CgCardTypeTag);
      expect(tester.getSemantics(tags.at(0)), matchesSemantics(label: 'Fiche cas clinique'));
      expect(tester.getSemantics(tags.at(1)), matchesSemantics(label: 'Fiche définition'));
      handle.dispose();
    });
  });

  test('contrastes des couleurs de l’étiquette (texte ≥ 4,5:1, contour ≥ 3:1)', () {
    for (final bg in [c.ground, c.surface]) {
      final (border, ink) = CgCardTypeTag.colorsFor(c, onAccent: false);
      expect(contrastRatio(ink, bg), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(border, bg), greaterThanOrEqualTo(3));
    }
    final (border, ink) = CgCardTypeTag.colorsFor(c, onAccent: true);
    expect(contrastRatio(ink, c.accent), greaterThanOrEqualTo(4.5));
    expect(contrastRatio(Color.alphaBlend(border, c.accent), c.accent), greaterThanOrEqualTo(3));
  });

  group('goldens', () {
    cgGoldenMatrix('cg_card_type_tag', () => const CgCardTypeTagGallery(), height: 420);
  });
}

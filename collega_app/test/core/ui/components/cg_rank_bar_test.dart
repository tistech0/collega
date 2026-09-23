import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/components/cg_rank_bar.dart';
import 'package:collega_app/core/ui/gallery/cg_rank_bar_gallery.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

import '../../../support/cg_golden.dart';

const c = CgColors.light;

/// Barre posée dans une largeur connue (341 = 104 + 40 + 17 + 180 : 1 pt par fiche).
Widget _bar({
  int mastered = 104,
  int good = 40,
  int review = 17,
  int unseen = 180,
  CgRankBarSize size = CgRankBarSize.row,
  bool legend = false,
  double width = 341,
  double textScale = 1,
}) =>
    cgTestApp(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: CgRankBar(mastered: mastered, good: good, review: review, unseen: unseen, size: size, legend: legend),
        ),
      ),
      textScale: textScale,
    );

Color _color(WidgetTester tester, Key key) => tester.widget<ColoredBox>(find.byKey(key)).color;

void main() {
  group('segments', () {
    testWidgets('proportions sur le total (non vues incluses)', (tester) async {
      await tester.pumpWidget(_bar());
      expect(tester.getSize(find.byKey(CgRankBar.masteredKey)).width, closeTo(104, 1e-6));
      expect(tester.getSize(find.byKey(CgRankBar.goodKey)).width, closeTo(40, 1e-6));
      expect(tester.getSize(find.byKey(CgRankBar.reviewKey)).width, closeTo(17, 1e-6));
      // Le reste (180 non vues) est le rail, visible sur toute la largeur.
      expect(tester.getSize(find.byKey(CgRankBar.railKey)).width, 341);
    });

    testWidgets('segments dans l\'ordre maîtrisé → bien → à revoir, depuis la gauche', (tester) async {
      await tester.pumpWidget(_bar());
      final m = tester.getRect(find.byKey(CgRankBar.masteredKey));
      final g = tester.getRect(find.byKey(CgRankBar.goodKey));
      final r = tester.getRect(find.byKey(CgRankBar.reviewKey));
      expect(m.left, 0);
      expect(g.left, closeTo(m.right, 1e-6));
      expect(r.left, closeTo(g.right, 1e-6));
    });

    testWidgets('couleurs des tokens : mastered, good, review, rail unseen', (tester) async {
      await tester.pumpWidget(_bar());
      expect(_color(tester, CgRankBar.masteredKey), c.mastered);
      expect(_color(tester, CgRankBar.goodKey), c.good);
      expect(_color(tester, CgRankBar.reviewKey), c.review);
      expect(_color(tester, CgRankBar.railKey), c.unseen);
    });

    testWidgets('un compte nul ne dessine pas de segment', (tester) async {
      await tester.pumpWidget(_bar(good: 0, review: 0, unseen: 237));
      expect(find.byKey(CgRankBar.goodKey), findsNothing);
      expect(find.byKey(CgRankBar.reviewKey), findsNothing);
      expect(tester.getSize(find.byKey(CgRankBar.masteredKey)).width, closeTo(104, 1e-6));
    });

    testWidgets('total 0 : rail seul, sans division par zéro', (tester) async {
      await tester.pumpWidget(_bar(mastered: 0, good: 0, review: 0, unseen: 0));
      expect(tester.takeException(), isNull);
      expect(find.byKey(CgRankBar.masteredKey), findsNothing);
      expect(find.byKey(CgRankBar.goodKey), findsNothing);
      expect(find.byKey(CgRankBar.reviewKey), findsNothing);
      expect(tester.getSize(find.byKey(CgRankBar.railKey)), const Size(341, 6));
    });

    testWidgets('tout maîtrisé : un seul segment plein', (tester) async {
      await tester.pumpWidget(_bar(mastered: 10, good: 0, review: 0, unseen: 0));
      expect(tester.getSize(find.byKey(CgRankBar.masteredKey)).width, closeTo(341, 1e-6));
    });
  });

  group('tailles', () {
    for (final (size, height, radius) in [
      (CgRankBarSize.row, 6.0, 3.0),
      (CgRankBarSize.header, 10.0, 5.0),
      (CgRankBarSize.hero, 22.0, 8.0),
    ]) {
      testWidgets('$size : hauteur ${height.toInt()}, rayon ${radius.toInt()}', (tester) async {
        await tester.pumpWidget(_bar(size: size));
        expect(tester.getSize(find.byKey(CgRankBar.railKey)).height, height);
        final clip = tester.widget<ClipRRect>(find.descendant(of: find.byType(CgRankBar), matching: find.byType(ClipRRect)));
        expect(clip.borderRadius, BorderRadius.all(Radius.circular(radius)));
      });
    }
  });

  group('légende', () {
    testWidgets('absente par défaut', (tester) async {
      await tester.pumpWidget(_bar());
      expect(find.text('104 maîtrisées'), findsNothing);
    });

    testWidgets('les mots, jamais la couleur seule ; texte label ink2', (tester) async {
      await tester.pumpWidget(_bar(legend: true));
      for (final label in ['104 maîtrisées', '40 bien', '17 à revoir', '180 non vues']) {
        final text = tester.widget<Text>(find.text(label));
        expect(text.style?.fontSize, CgType.label.fontSize);
        expect(text.style?.color, c.ink2);
      }
    });

    testWidgets('accord au singulier', (tester) async {
      await tester.pumpWidget(_bar(mastered: 1, good: 1, review: 1, unseen: 1, legend: true));
      expect(find.text('1 maîtrisée'), findsOneWidget);
      expect(find.text('1 bien'), findsOneWidget);
      expect(find.text('1 à revoir'), findsOneWidget);
      expect(find.text('1 non vue'), findsOneWidget);
    });

    testWidgets('pastilles 10 pt aux couleurs des segments', (tester) async {
      await tester.pumpWidget(_bar(legend: true));
      final dots = tester
          .widgetList<DecoratedBox>(find.descendant(of: find.byType(CgRankBar), matching: find.byType(DecoratedBox)))
          .map((d) => (d.decoration as BoxDecoration).color)
          .toList();
      expect(dots, [c.mastered, c.good, c.review, c.unseen]);
      final dot = find.descendant(of: find.byType(CgRankBar), matching: find.byType(DecoratedBox)).first;
      expect(tester.getSize(dot), const Size(10, 10));
    });

    testWidgets('Dynamic Type 1,6 : la légende passe à la ligne sans déborder', (tester) async {
      await tester.pumpWidget(_bar(legend: true, width: 240, textScale: 1.6));
      expect(tester.takeException(), isNull);
      final first = tester.getTopLeft(find.text('104 maîtrisées')).dy;
      final last = tester.getTopLeft(find.text('180 non vues')).dy;
      expect(last, greaterThan(first));
    });
  });

  testWidgets('Semantics : un seul nœud récapitulatif', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_bar(legend: true));
    expect(
      tester.getSemantics(find.byType(CgRankBar)),
      matchesSemantics(label: '104 maîtrisées, 40 bien, 17 à revoir, 180 non vues'),
    );
    // La légende n'est pas relue une seconde fois.
    expect(find.bySemanticsLabel('104 maîtrisées'), findsNothing);
    handle.dispose();
  });

  group('goldens', () {
    cgGoldenMatrix('cg_rank_bar', () => const CgRankBarGallery(), height: 600);
  });
}

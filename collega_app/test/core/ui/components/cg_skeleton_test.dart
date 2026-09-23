import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/components/cg_skeleton.dart';
import 'package:collega_app/core/ui/gallery/cg_skeleton_gallery.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';

import '../../../support/cg_golden.dart';

const c = CgColors.light;

/// Opacité de la (première) pulsation sous [of].
double _opacity(WidgetTester tester, Finder of) => tester
    .widget<FadeTransition>(find.descendant(of: of, matching: find.byType(FadeTransition)).first)
    .opacity
    .value;

BoxDecoration _decoration(WidgetTester tester, Finder of) => tester
    .widget<DecoratedBox>(find.descendant(of: of, matching: find.byType(DecoratedBox)).first)
    .decoration as BoxDecoration;

Widget _app(Widget child, {bool reduced = false, double textScale = 1}) => cgTestApp(
      Align(alignment: Alignment.topLeft, child: SizedBox(width: 300, child: child)),
      disableAnimations: reduced,
      textScale: textScale,
    );

void main() {
  group('formes', () {
    testWidgets('line : 14 pt de haut, pleine largeur, fond soft', (tester) async {
      await tester.pumpWidget(_app(CgSkeleton.line(), reduced: true));
      expect(tester.getSize(find.byType(CgSkeleton)), const Size(300, 14));
      expect(_decoration(tester, find.byType(CgSkeleton)).color, c.soft);
    });

    testWidgets('block : hauteur demandée, rayon l par défaut', (tester) async {
      await tester.pumpWidget(_app(Align(alignment: Alignment.topLeft, child: CgSkeleton.block(width: 120, height: 80)), reduced: true));
      expect(tester.getSize(find.byType(CgSkeleton)), const Size(120, 80));
      expect(_decoration(tester, find.byType(CgSkeleton)).borderRadius, CgRadius.lAll);
    });

    testWidgets('largeur imposée respectée même sous un parent qui étire', (tester) async {
      await tester.pumpWidget(_app(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [CgSkeleton.line(width: 180)]),
        reduced: true,
      ));
      final bone = find.descendant(of: find.byType(CgSkeleton), matching: find.byType(DecoratedBox));
      expect(tester.getSize(bone), const Size(180, 14));
      expect(tester.getTopLeft(bone).dx, 0);
    });

    testWidgets('ring : disque de 56 pt', (tester) async {
      await tester.pumpWidget(_app(Align(alignment: Alignment.topLeft, child: CgSkeleton.ring()), reduced: true));
      expect(tester.getSize(find.byType(CgSkeleton)), const Size(56, 56));
      expect(_decoration(tester, find.byType(CgSkeleton)).shape, BoxShape.circle);
    });

    testWidgets('liste : 5 lignes par défaut (pastille 36 + 2 lignes)', (tester) async {
      await tester.pumpWidget(_app(const CgSkeletonList(), reduced: true));
      final boxes = tester
          .widgetList<DecoratedBox>(find.descendant(of: find.byType(CgSkeletonList), matching: find.byType(DecoratedBox)))
          .toList();
      expect(boxes, hasLength(5 * 3));
      final leading = find.descendant(of: find.byType(CgSkeletonList), matching: find.byType(DecoratedBox)).first;
      expect(tester.getSize(leading), const Size(36, 36));
    });

    testWidgets('liste : nombre de lignes paramétrable', (tester) async {
      await tester.pumpWidget(_app(const CgSkeletonList(rows: 2), reduced: true));
      expect(
        find.descendant(of: find.byType(CgSkeletonList), matching: find.byType(DecoratedBox)),
        findsNWidgets(2 * 3),
      );
    });
  });

  group('pulsation', () {
    testWidgets('1 → 0,55 → 1 en 1,2 s, en boucle', (tester) async {
      await tester.pumpWidget(_app(CgSkeleton.line()));
      await tester.pump();
      expect(_opacity(tester, find.byType(CgSkeleton)), closeTo(1, 0.01));
      await tester.pump(CgMotion.skeletonPulse ~/ 2);
      expect(_opacity(tester, find.byType(CgSkeleton)), closeTo(0.55, 0.01));
      await tester.pump(CgMotion.skeletonPulse ~/ 2);
      expect(_opacity(tester, find.byType(CgSkeleton)), closeTo(1, 0.01));
      // Toujours en cours au cycle suivant (boucle).
      await tester.pump(CgMotion.skeletonPulse ~/ 2);
      expect(_opacity(tester, find.byType(CgSkeleton)), closeTo(0.55, 0.01));
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets('mouvement réduit : statique (opacité 1), aucune animation', (tester) async {
      await tester.pumpWidget(_app(const CgSkeletonList(), reduced: true));
      await tester.pump(CgMotion.skeletonPulse ~/ 2);
      expect(_opacity(tester, find.byType(CgSkeletonList)), 1);
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpAndSettle(); // se termine : rien ne boucle
    });

    testWidgets('mouvement réduit activé en cours de route : la pulsation s\'arrête', (tester) async {
      await tester.pumpWidget(_app(CgSkeleton.line()));
      await tester.pump(CgMotion.skeletonPulse ~/ 3);
      await tester.pumpWidget(_app(CgSkeleton.line(), reduced: true));
      await tester.pump();
      expect(_opacity(tester, find.byType(CgSkeleton)), 1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('accessibilité', () {
    testWidgets('CgSkeletonList : un seul nœud « Chargement »', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const CgSkeletonList(), reduced: true));
      expect(find.bySemanticsLabel('Chargement'), findsOneWidget);
      expect(tester.getSemantics(find.byType(CgSkeletonList)), matchesSemantics(label: 'Chargement'));
      handle.dispose();
    });

    testWidgets('CgSkeleton seul : exclu de l\'arbre sémantique', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(CgSkeleton.line(), reduced: true));
      expect(tester.getSemantics(find.byType(CgSkeleton)), isNot(matchesSemantics(label: 'Chargement')));
      handle.dispose();
    });

    testWidgets('Dynamic Type 1,6 : les lignes de la liste grandissent comme le texte', (tester) async {
      await tester.pumpWidget(_app(const CgSkeletonList(rows: 1), reduced: true));
      final normal = tester.getSize(find.byType(CgSkeletonList)).height;
      await tester.pumpWidget(_app(const CgSkeletonList(rows: 1), reduced: true, textScale: 1.6));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(CgSkeletonList)).height, greaterThan(normal));
    });
  });

  group('goldens', () {
    cgGoldenMatrix('cg_skeleton', () => const CgSkeletonGallery(), height: 640);
  });
}

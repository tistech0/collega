import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/components/cg_badge.dart';
import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/gallery/cg_badge_gallery.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';

import '../../../support/cg_golden.dart';

const c = CgColors.light;

BoxDecoration _decoration(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: find.byType(CgBadge), matching: find.byType(DecoratedBox)).first,
  );
  return box.decoration as BoxDecoration;
}

Color? _textColor(WidgetTester tester, String text) => tester.widget<Text>(find.text(text)).style?.color;

void main() {
  group('rang', () {
    for (final (rank, fill, text) in [
      ('A', c.accentSoft, c.accent),
      ('B', c.rankBSoft, c.rankB),
      ('C', c.soft, c.rankC),
    ]) {
      testWidgets('rang $rank : fond et texte des tokens', (tester) async {
        await tester.pumpWidget(cgTestApp(Center(child: CgBadge.rank(rank))));
        expect(_decoration(tester).color, fill);
        expect(_decoration(tester).borderRadius, CgRadius.badgeAll);
        expect(_textColor(tester, 'Rang $rank'), text);
        expect(tester.widget<Text>(find.text('Rang $rank')).style?.fontWeight, FontWeight.w600);
      });
    }

    testWidgets('hauteur 22 pt à 1,0 ; grandit avec le Dynamic Type sans déborder', (tester) async {
      await tester.pumpWidget(cgTestApp(Center(child: CgBadge.rank('A'))));
      expect(tester.getSize(find.byType(CgBadge)).height, 22);
      await tester.pumpWidget(cgTestApp(Center(child: CgBadge.rank('A')), textScale: 1.6));
      expect(tester.getSize(find.byType(CgBadge)).height, greaterThan(22));
      expect(tester.takeException(), isNull);
    });

    testWidgets('lettre seule possible (listes compactes)', (tester) async {
      await tester.pumpWidget(cgTestApp(Center(child: CgBadge.rank('B', short: true))));
      expect(find.text('B'), findsOneWidget);
      expect(_textColor(tester, 'B'), c.rankB);
    });
  });

  group('ocr', () {
    testWidgets('icône warning + « À vérifier », texte warningInk, fond soft', (tester) async {
      await tester.pumpWidget(cgTestApp(Center(child: CgBadge.ocr())));
      expect(find.text('À vérifier'), findsOneWidget);
      expect(_textColor(tester, 'À vérifier'), c.warningInk);
      expect(_decoration(tester).color, c.soft);
      final icon = tester.widget<CgIcon>(find.byType(CgIcon));
      expect(icon.svg, CgIcons.warning);
      expect(icon.color, c.warningInk);
    });

    testWidgets('tapable : cible ≥ 44 pt, onTap appelé', (tester) async {
      var taps = 0;
      await tester.pumpWidget(cgTestApp(Center(child: CgBadge.ocr(onTap: () => taps++))));
      final size = tester.getSize(find.byType(CgBadge));
      expect(size.height, greaterThanOrEqualTo(CgSpace.tapTarget));
      expect(size.width, greaterThanOrEqualTo(CgSpace.tapTarget));
      await tester.tap(find.byType(CgBadge));
      expect(taps, 1);
    });

    testWidgets('non tapable : 22 pt, pas de cible élargie', (tester) async {
      await tester.pumpWidget(cgTestApp(Center(child: CgBadge.ocr())));
      expect(tester.getSize(find.byType(CgBadge)).height, 22);
    });
  });

  testWidgets('beta : « Beta » sur accentSoft, texte accent', (tester) async {
    await tester.pumpWidget(cgTestApp(Center(child: CgBadge.beta())));
    expect(_decoration(tester).color, c.accentSoft);
    expect(_textColor(tester, 'Beta'), c.accent);
  });

  testWidgets('count : nombre sur soft, texte ink2', (tester) async {
    await tester.pumpWidget(cgTestApp(Center(child: CgBadge.count(12))));
    expect(find.text('12'), findsOneWidget);
    expect(_decoration(tester).color, c.soft);
    expect(_textColor(tester, '12'), c.ink2);
  });

  group('Semantics (français)', () {
    testWidgets('rang, ocr, beta, count', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(cgTestApp(Column(children: [
        CgBadge.rank('A', short: true),
        CgBadge.ocr(),
        CgBadge.ocr(onTap: () {}),
        CgBadge.beta(),
        CgBadge.count(3, semanticLabel: '3 fiches'),
        CgBadge.count(7),
      ])));
      final badges = find.byType(CgBadge);
      expect(tester.getSemantics(badges.at(0)), matchesSemantics(label: 'Rang A'));
      expect(tester.getSemantics(badges.at(1)), matchesSemantics(label: 'Source à vérifier'));
      expect(
        tester.getSemantics(badges.at(2)),
        matchesSemantics(label: 'Source à vérifier', isButton: true, hasTapAction: true),
      );
      expect(tester.getSemantics(badges.at(3)), matchesSemantics(label: 'Beta'));
      expect(tester.getSemantics(badges.at(4)), matchesSemantics(label: '3 fiches'));
      expect(tester.getSemantics(badges.at(5)), matchesSemantics(label: '7'));
      handle.dispose();
    });
  });

  group('goldens', () {
    cgGoldenMatrix('cg_badge', () => const CgBadgeGallery(), height: 520);
  });
}

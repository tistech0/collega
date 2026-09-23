import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/components/cg_header.dart';
import 'package:collega_app/core/ui/components/cg_tab_bar.dart';
import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/gallery/cg_header_gallery.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

import '../../../support/cg_golden.dart';

const c = CgColors.light;
const _screen = Size(393, 852);

TextStyle? _style(WidgetTester tester, String text) => tester.widget<Text>(find.text(text)).style;

/// Écran iPhone : taille 393 × 852, safe areas (encoche 59, indicateur 34).
Future<void> _pumpScreen(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
  bool disableAnimations = false,
  EdgeInsets padding = const EdgeInsets.only(top: 59, bottom: 34),
}) async {
  tester.view.physicalSize = _screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(cgTestApp(
    Builder(builder: (context) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(padding: padding, viewPadding: padding),
        child: child,
      );
    }),
    textScale: textScale,
    disableAnimations: disableAnimations,
  ));
}

List<Widget> _rows(int n) => [
      for (var i = 0; i < n; i++) SizedBox(key: Key('row$i'), height: 64, child: Text('Ligne $i')),
    ];

double _inlineTitleOpacity(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byKey(const ValueKey('cg-page-inline-title'))).opacity;

void main() {
  testWidgets('CgPage peint son fond : l’écran dessous ne transparaît pas pendant un glissement (8.15)',
      (tester) async {
    await _pumpScreen(tester, CgPage(title: 'Titre', children: _rows(2)));
    final root = find.descendant(of: find.byType(CgPage), matching: find.byType(ColoredBox)).first;
    expect(tester.widget<ColoredBox>(root).color, c.ground);
    expect(tester.getSize(root), _screen);
  });

  group('CgHeader.large', () {
    testWidgets('titre titleL ink, sous-titre bodyS ink2, trailing 44 × 44', (tester) async {
      await tester.pumpWidget(cgTestApp(const Align(
        alignment: Alignment.topCenter,
        child: CgHeader.large(
          title: 'Aujourd’hui',
          subtitle: 'Lundi 21 septembre',
          trailing: CgIcon(CgIcons.search, semanticLabel: 'Rechercher'),
        ),
      )));
      final title = _style(tester, 'Aujourd’hui')!;
      expect(title.fontSize, CgType.titleL.fontSize);
      expect(title.fontWeight, CgType.titleL.fontWeight);
      expect(title.color, c.ink);
      final sub = _style(tester, 'Lundi 21 septembre')!;
      expect(sub.fontSize, CgType.bodyS.fontSize);
      expect(sub.color, c.ink2);
      final slot = find.byKey(const ValueKey('cg-header-trailing'));
      expect(tester.getSize(slot), const Size.square(CgSpace.tapTarget));
      expect(tester.getTopLeft(find.text('Lundi 21 septembre')).dy, greaterThan(tester.getTopLeft(find.text('Aujourd’hui')).dy));
    });

    testWidgets('Dynamic Type 2× : titre plafonné à 1,3×, sous-titre non plafonné', (tester) async {
      await tester.pumpWidget(cgTestApp(
        const CgHeader.large(title: 'Progression', subtitle: 'Cette semaine'),
        textScale: 2,
      ));
      expect(MediaQuery.textScalerOf(tester.element(find.text('Progression'))).scale(10), closeTo(13, 0.001));
      expect(MediaQuery.textScalerOf(tester.element(find.text('Cette semaine'))).scale(10), closeTo(20, 0.001));
    });

    testWidgets('Semantics : le titre est un en-tête', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(cgTestApp(const CgHeader.large(title: 'Bibliothèque')));
      expect(tester.getSemantics(find.text('Bibliothèque')), matchesSemantics(label: 'Bibliothèque', isHeader: true));
      handle.dispose();
    });
  });

  group('CgHeader.inline', () {
    testWidgets('barre 44 pt, titre head centré, « ‹ Bibliothèque » accent', (tester) async {
      await tester.pumpWidget(cgTestApp(Align(
        alignment: Alignment.topCenter,
        child: CgHeader.inline(title: 'Cancérologie', backLabel: 'Bibliothèque', onBack: () {}),
      )));
      expect(tester.getSize(find.byType(CgHeader)).height, CgSpace.tapTarget);
      final title = _style(tester, 'Cancérologie')!;
      expect(title.fontSize, CgType.head.fontSize);
      expect(title.fontWeight, CgType.head.fontWeight);
      expect(tester.getCenter(find.text('Cancérologie')).dx, closeTo(400, 0.5));
      expect(_style(tester, 'Bibliothèque')!.color, c.accent);
      final chevron = tester.widget<CgIcon>(find.byType(CgIcon));
      expect(chevron.svg, CgIcons.chevronLeft);
      expect(chevron.color, c.accent);
    });

    testWidgets('retour : tap appelle onBack, cible ≥ 44, Semantics bouton « Retour, Bibliothèque »', (tester) async {
      final handle = tester.ensureSemantics();
      var backs = 0;
      await tester.pumpWidget(cgTestApp(Align(
        alignment: Alignment.topCenter,
        child: CgHeader.inline(title: 'Cancérologie', backLabel: 'Bibliothèque', onBack: () => backs++),
      )));
      final back = find.byKey(const ValueKey('cg-header-back'));
      expect(tester.getSize(back).height, greaterThanOrEqualTo(CgSpace.tapTarget));
      expect(tester.getSize(back).width, greaterThanOrEqualTo(CgSpace.tapTarget));
      await tester.tap(back);
      expect(backs, 1);
      expect(
        tester.getSemantics(back),
        matchesSemantics(label: 'Retour, Bibliothèque', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('sans onBack : retour = Navigator.maybePop', (tester) async {
      await tester.pumpWidget(cgTestApp(Navigator(
        onGenerateRoute: (_) => PageRouteBuilder<void>(pageBuilder: (context, _, __) {
          return Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(PageRouteBuilder<void>(
                pageBuilder: (_, __, ___) => const Align(
                  alignment: Alignment.topCenter,
                  child: CgHeader.inline(title: 'Cancérologie', backLabel: 'Bibliothèque'),
                ),
              )),
              child: const Text('ouvrir'),
            ),
          );
        }),
      )));
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('Cancérologie'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cg-header-back')));
      await tester.pumpAndSettle();
      expect(find.text('Cancérologie'), findsNothing);
    });

    testWidgets('Dynamic Type 2× : la barre ne déborde pas (texte plafonné)', (tester) async {
      await tester.pumpWidget(cgTestApp(
        Align(
          alignment: Alignment.topCenter,
          child: CgHeader.inline(title: 'Cancérologie', backLabel: 'Bibliothèque', onBack: () {}),
        ),
        textScale: 2,
      ));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.text('Cancérologie')).height, lessThanOrEqualTo(CgSpace.tapTarget));
    });
  });

  group('CgPage', () {
    testWidgets('large title en haut, barre inline masquée ; au défilement elle apparaît', (tester) async {
      await _pumpScreen(tester, CgPage(title: 'Bibliothèque', children: _rows(30)));
      expect(_inlineTitleOpacity(tester), 0);
      final largeTop = tester.getTopLeft(find.text('Bibliothèque').first).dy;
      expect(largeTop, greaterThanOrEqualTo(59 + CgSpace.tapTarget));

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(_inlineTitleOpacity(tester), 1);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(_inlineTitleOpacity(tester), 0);
    });

    testWidgets('barre réduite : fond ground flouté, sous la safe area haute', (tester) async {
      await _pumpScreen(tester, CgPage(title: 'Bibliothèque', children: _rows(30)));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);
      final bar = find.byKey(const ValueKey('cg-page-bar'));
      expect(tester.getTopLeft(bar).dy, 0);
      expect(tester.getSize(bar).height, 59 + CgSpace.tapTarget);
      final titleCenter = tester.getCenter(find.descendant(of: bar, matching: find.text('Bibliothèque')));
      expect(titleCenter.dx, closeTo(_screen.width / 2, 0.5));
      expect(titleCenter.dy, greaterThan(59));
    });

    testWidgets('titre inline masqué : ignoré par VoiceOver (pas de doublon du large title)', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpScreen(tester, CgPage(title: 'Bibliothèque', children: _rows(3)));
      expect(find.bySemanticsLabel('Bibliothèque'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('mouvement réduit : bascule sans animation', (tester) async {
      await _pumpScreen(tester, CgPage(title: 'Bibliothèque', children: _rows(30)), disableAnimations: true);
      final op = tester.widget<AnimatedOpacity>(find.byKey(const ValueKey('cg-page-inline-title')));
      expect(op.duration, Duration.zero);
    });

    testWidgets('« ‹ backLabel » au-dessus du large title, tapable', (tester) async {
      var backs = 0;
      await _pumpScreen(
        tester,
        CgPage(title: 'Cancérologie', subtitle: 'CNEC · 177 fiches', backLabel: 'Bibliothèque', onBack: () => backs++, children: _rows(3)),
      );
      final back = find.byKey(const ValueKey('cg-header-back'));
      expect(tester.getBottomLeft(back).dy, lessThanOrEqualTo(tester.getTopLeft(find.text('Cancérologie').first).dy));
      expect(tester.getTopLeft(back).dy, greaterThanOrEqualTo(59));
      await tester.tap(back);
      expect(backs, 1);
    });

    testWidgets('bottomAction ancré au-dessus de la safe area ; le dernier élément n’est jamais masqué', (tester) async {
      await _pumpScreen(
        tester,
        CgPage(
          title: 'Cancérologie',
          bottomAction: const SizedBox(key: Key('cta'), height: CgSpace.buttonHeight),
          children: _rows(30),
        ),
      );
      final cta = find.byKey(const Key('cta'));
      expect(tester.getBottomLeft(cta).dy, lessThanOrEqualTo(_screen.height - 34));
      await tester.fling(find.byType(CustomScrollView), const Offset(0, -6000), 3000);
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(find.byKey(const Key('row29'))).dy, lessThanOrEqualTo(tester.getTopLeft(cta).dy));
    });

    testWidgets('trailing monté une seule fois (GlobalKey sûre), avant et après défilement', (tester) async {
      final key = GlobalKey();
      await _pumpScreen(tester, CgPage(
        title: 'Bibliothèque',
        trailing: SizedBox(key: key, width: 44, height: 44),
        children: _rows(30),
      ));
      expect(find.byKey(key), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(key), findsOneWidget);
    });

    testWidgets('clavier ouvert : bottomAction au-dessus du clavier', (tester) async {
      tester.view.physicalSize = _screen;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const keyboard = 336.0;
      await tester.pumpWidget(cgTestApp(Builder(builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(top: 59),
              viewInsets: const EdgeInsets.only(bottom: keyboard),
            ),
            child: CgPage(
              title: 'Planning',
              bottomAction: const SizedBox(key: Key('cta'), height: CgSpace.buttonHeight),
              children: _rows(5),
            ),
          ))));
      expect(tester.getBottomLeft(find.byKey(const Key('cta'))).dy, lessThanOrEqualTo(_screen.height - keyboard));
    });

    testWidgets('reserveTabBar : bottomAction au-dessus de la tab bar', (tester) async {
      await _pumpScreen(
        tester,
        CgPage(
          title: 'Aujourd’hui',
          reserveTabBar: true,
          bottomAction: const SizedBox(key: Key('cta'), height: CgSpace.buttonHeight),
          children: _rows(30),
        ),
      );
      final reserved = CgTabBar.reservedHeight(tester.element(find.byType(CgPage)));
      expect(tester.getBottomLeft(find.byKey(const Key('cta'))).dy, lessThanOrEqualTo(_screen.height - reserved));
    });

    testWidgets('reserveTabBar sans action : la fin de liste remonte au-dessus de la tab bar', (tester) async {
      await _pumpScreen(tester, CgPage(title: 'Bibliothèque', reserveTabBar: true, children: _rows(30)));
      await tester.fling(find.byType(CustomScrollView), const Offset(0, -6000), 3000);
      await tester.pumpAndSettle();
      final reserved = CgTabBar.reservedHeight(tester.element(find.byType(CgPage)));
      expect(tester.getBottomLeft(find.byKey(const Key('row29'))).dy, lessThanOrEqualTo(_screen.height - reserved));
    });

    testWidgets('onRefresh : CupertinoSliverRefreshControl ; sinon absent', (tester) async {
      await _pumpScreen(tester, CgPage(title: 'Aujourd’hui', onRefresh: () async {}, children: _rows(3)));
      expect(find.byType(CupertinoSliverRefreshControl, skipOffstage: false), findsOneWidget);
      await _pumpScreen(tester, CgPage(title: 'Aujourd’hui', children: _rows(3)));
      expect(find.byType(CupertinoSliverRefreshControl, skipOffstage: false), findsNothing);
    });

    testWidgets('controller fourni : utilisé par la liste (remonter en haut)', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await _pumpScreen(tester, CgPage(title: 'Bibliothèque', controller: controller, children: _rows(30)));
      controller.jumpTo(400);
      await tester.pump();
      expect(_inlineTitleOpacity(tester), 1);
    });

    testWidgets('Dynamic Type 1,6 : aucun débordement', (tester) async {
      await _pumpScreen(
        tester,
        CgPage(title: 'Chirurgie générale, viscérale et digestive', subtitle: 'CFCVD · 94 fiches', backLabel: 'Bibliothèque', children: _rows(5)),
        textScale: 1.6,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('goldens', () {
    cgGoldenMatrix('cg_header', () => const CgHeaderGallery(), height: 700);
    cgGoldenMatrix('cg_page', () => const CgPageGallery(), height: 844);
  });
}

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/components/cg_button.dart';
import 'package:collega_app/core/ui/components/cg_illustrations.dart';
import 'package:collega_app/core/ui/components/cg_state.dart';
import 'package:collega_app/core/ui/gallery/cg_state_gallery.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

import '../../../support/cg_golden.dart';

const c = CgColors.light;

CgButton _button(WidgetTester tester) => tester.widget<CgButton>(find.byType(CgButton));

FadeTransition _illustrationFade(WidgetTester tester) => tester.widget<FadeTransition>(
      find.ancestor(of: find.byType(CgIllustrationArt), matching: find.byType(FadeTransition)).first,
    );

void main() {
  group('variantes', () {
    testWidgets('empty : illustration sheets, action primary compacte', (tester) async {
      var taps = 0;
      await tester.pumpWidget(cgTestApp(CgState.empty(
        title: 'Importe ton premier collège',
        message: 'Tes fiches apparaîtront ici.',
        actionLabel: 'Importer',
        onAction: () => taps++,
      )));
      await tester.pumpAndSettle();
      expect(tester.widget<CgIllustrationArt>(find.byType(CgIllustrationArt)).illustration, CgIllustration.sheets);
      expect(_button(tester).variant, CgButtonVariant.primary);
      expect(_button(tester).size, CgButtonSize.compact);
      expect(_button(tester).expand, isFalse);
      await tester.tap(find.text('Importer'));
      expect(taps, 1);
    });

    testWidgets('error : illustration broken, action secondary', (tester) async {
      await tester.pumpWidget(cgTestApp(CgState.error(
        title: 'Tes fiches sont là',
        message: 'Impossible de joindre le serveur.',
        actionLabel: 'Réessayer',
        onAction: () {},
      )));
      await tester.pumpAndSettle();
      expect(tester.widget<CgIllustrationArt>(find.byType(CgIllustrationArt)).illustration, CgIllustration.broken);
      expect(_button(tester).variant, CgButtonVariant.secondary);
      expect(_button(tester).size, CgButtonSize.compact);
    });

    testWidgets('offline : illustration offline, action secondary', (tester) async {
      await tester.pumpWidget(cgTestApp(CgState.offline(
        title: 'Hors connexion',
        message: 'La recherche a besoin d\'une connexion. Tes collèges restent disponibles.',
        actionLabel: 'Réessayer',
        onAction: () {},
      )));
      await tester.pumpAndSettle();
      expect(tester.widget<CgIllustrationArt>(find.byType(CgIllustrationArt)).illustration, CgIllustration.offline);
      expect(_button(tester).variant, CgButtonVariant.secondary);
    });

    testWidgets('illustration surchargeable ; sans actionLabel, pas de bouton', (tester) async {
      await tester.pumpWidget(cgTestApp(const CgState.empty(
        title: 'Aucun résultat',
        message: 'Essaie un autre mot.',
        illustration: CgIllustration.search,
      )));
      await tester.pumpAndSettle();
      expect(tester.widget<CgIllustrationArt>(find.byType(CgIllustrationArt)).illustration, CgIllustration.search);
      expect(find.byType(CgButton), findsNothing);
    });
  });

  group('tokens', () {
    testWidgets('titre title/ink, message bodyS/ink2 centré, illustration 96 pt accent', (tester) async {
      await tester.pumpWidget(cgTestApp(const CgState.empty(title: 'Titre', message: 'Message')));
      await tester.pumpAndSettle();
      final title = tester.widget<Text>(find.text('Titre'));
      expect(title.style?.fontSize, CgType.title.fontSize);
      expect(title.style?.color, c.ink);
      final message = tester.widget<Text>(find.text('Message'));
      expect(message.style?.fontSize, CgType.bodyS.fontSize);
      expect(message.style?.color, c.ink2);
      expect(message.textAlign, TextAlign.center);
      expect(tester.getSize(find.byType(CgIllustrationArt)), const Size(96, 96));
      final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(svg.colorFilter, ColorFilter.mode(c.accent, BlendMode.srcIn));
    });

    testWidgets('les 5 illustrations sont des SVG distincts', (tester) async {
      final svgs = {for (final i in CgIllustration.values) CgIllustrations.svgOf(i)};
      expect(svgs.length, CgIllustration.values.length);
      for (final svg in svgs) {
        expect(svg, startsWith('<svg'));
      }
    });
  });

  group('mouvement', () {
    testWidgets('apparition : fondu + montée 8 pt en CgMotion.slow, une fois', (tester) async {
      await tester.pumpWidget(cgTestApp(const CgState.empty(title: 'Titre', message: 'Message')));
      expect(_illustrationFade(tester).opacity.value, 0);
      final start = tester.getTopLeft(find.byType(CgIllustrationArt)).dy;
      await tester.pump(CgMotion.slow);
      expect(_illustrationFade(tester).opacity.value, 1);
      final end = tester.getTopLeft(find.byType(CgIllustrationArt)).dy;
      expect(start - end, closeTo(8, 0.01));

      // Une reconstruction ne rejoue pas l'animation.
      await tester.pumpWidget(cgTestApp(const CgState.empty(title: 'Titre 2', message: 'Message')));
      expect(_illustrationFade(tester).opacity.value, 1);
    });

    testWidgets('mouvement réduit : illustration posée d\'emblée', (tester) async {
      await tester.pumpWidget(cgTestApp(
        const CgState.empty(title: 'Titre', message: 'Message'),
        disableAnimations: true,
      ));
      expect(_illustrationFade(tester).opacity.value, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  testWidgets('Semantics : titre en en-tête, illustration décorative', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(cgTestApp(CgState.error(
      title: 'Tes fiches sont là',
      message: 'Impossible de joindre le serveur.',
      actionLabel: 'Réessayer',
      onAction: () {},
    )));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text('Tes fiches sont là')),
      matchesSemantics(label: 'Tes fiches sont là', isHeader: true),
    );
    expect(find.bySemanticsLabel('Réessayer'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Dynamic Type 1,6 : aucun débordement sur 375 pt', (tester) async {
    tester.view.physicalSize = const Size(375, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(cgTestApp(
      Center(
        child: CgState.offline(
          title: 'Hors connexion',
          message: 'La recherche a besoin d\'une connexion. Tes collèges restent disponibles.',
          actionLabel: 'Réessayer',
          onAction: () {},
        ),
      ),
      textScale: 1.6,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('goldens', () {
    cgGoldenMatrix('cg_state', () => const CgStateGallery(), height: 1550);
  });
}

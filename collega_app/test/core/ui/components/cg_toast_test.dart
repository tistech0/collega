import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/components/cg_tab_bar.dart';
import 'package:collega_app/core/ui/components/cg_toast.dart';
import 'package:collega_app/core/ui/gallery/cg_toast_gallery.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

import '../../../support/cg_golden.dart';

const c = CgColors.light;
const _msg = 'Elle reviendra dans quelques questions';

/// Monte un écran vide et renvoie un contexte d'appel.
Future<BuildContext> _host(WidgetTester tester, {bool reduced = false, double textScale = 1}) async {
  late BuildContext ctx;
  await tester.pumpWidget(cgTestApp(
    Builder(builder: (context) {
      ctx = context;
      return const SizedBox.expand();
    }),
    disableAnimations: reduced,
    textScale: textScale,
  ));
  return ctx;
}

/// Laisse passer la durée d'affichage puis le fondu de sortie.
Future<void> _runOut(WidgetTester tester) async {
  await tester.pump(CgMotion.toast);
  await tester.pump(CgMotion.base);
  await tester.pump(CgMotion.base);
}

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(find.ancestor(of: find.byType(CgToastCapsule), matching: find.byType(FadeTransition)).first)
    .opacity
    .value;

void main() {
  group('capsule', () {
    testWidgets('fond ink, texte ground bodyS, une ligne avec ellipse', (tester) async {
      await tester.pumpWidget(cgTestApp(const Center(child: CgToastCapsule(message: _msg))));
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(CgToastCapsule), matching: find.byType(DecoratedBox)),
      );
      expect((box.decoration as BoxDecoration).color, c.ink);
      final text = tester.widget<Text>(find.text(_msg));
      expect(text.style?.color, c.ground);
      expect(text.style?.fontSize, CgType.bodyS.fontSize);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('Dynamic Type 1,6 : message long tronqué sans débordement', (tester) async {
      await tester.pumpWidget(cgTestApp(
        const Center(child: CgToastCapsule(message: '$_msg, puis encore une fois, et une autre')),
        textScale: 1.6,
      ));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(CgToastCapsule)).width, lessThanOrEqualTo(800));
    });
    testWidgets('plusieurs lignes : passe à la ligne, bloc arrondi r-l', (tester) async {
      const long = 'Pas assez de contenu : items 215, 216, 217, 218, 219, 220, 221, 222 et 3 autres';
      await tester.pumpWidget(cgTestApp(const Center(child: CgToastCapsule(message: long, maxLines: 3))));
      final text = tester.widget<Text>(find.text(long));
      expect(text.maxLines, 3);
      expect(text.softWrap, isTrue);
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(CgToastCapsule), matching: find.byType(DecoratedBox)),
      );
      expect((box.decoration as BoxDecoration).borderRadius, CgRadius.lAll);
      expect(tester.takeException(), isNull);
    });
  });

  group('showCgToast', () {
    testWidgets('durée et lignes choisies par l’appelant', (tester) async {
      final ctx = await _host(tester);
      showCgToast(ctx, _msg, maxLines: 3, duration: const Duration(seconds: 5));
      await tester.pump();
      expect(tester.widget<Text>(find.text(_msg)).maxLines, 3);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text(_msg), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(CgMotion.base);
      await tester.pump(CgMotion.base);
      expect(find.byType(CgToastCapsule), findsNothing);
    });

    testWidgets('apparition en fondu + montée de 8 pt', (tester) async {
      final ctx = await _host(tester);
      showCgToast(ctx, _msg);
      await tester.pump();
      expect(find.text(_msg), findsOneWidget);
      expect(_opacity(tester), closeTo(0, 0.01));
      final start = tester.getTopLeft(find.byType(CgToastCapsule)).dy;
      await tester.pump(CgMotion.base);
      expect(_opacity(tester), 1);
      final end = tester.getTopLeft(find.byType(CgToastCapsule)).dy;
      expect(start - end, closeTo(8, 0.01));
      await _runOut(tester);
    });

    testWidgets('disparaît après 2 s', (tester) async {
      final ctx = await _host(tester);
      showCgToast(ctx, _msg);
      await tester.pump();
      await tester.pump(CgMotion.toast - const Duration(milliseconds: 100));
      expect(find.text(_msg), findsOneWidget);
      await _runOut(tester);
      expect(find.byType(CgToastCapsule), findsNothing);
    });

    testWidgets('un seul à la fois : le suivant remplace, avec sa propre durée', (tester) async {
      final ctx = await _host(tester);
      showCgToast(ctx, _msg);
      await tester.pump(const Duration(milliseconds: 1500));
      showCgToast(ctx, 'Fiche signalée');
      await tester.pump();
      expect(find.text(_msg), findsNothing);
      expect(find.text('Fiche signalée'), findsOneWidget);
      expect(find.byType(CgToastCapsule), findsOneWidget);
      // L'échéance du premier (2 s après lui) n'emporte pas le second.
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Fiche signalée'), findsOneWidget);
      await _runOut(tester);
      expect(find.byType(CgToastCapsule), findsNothing);
    });

    testWidgets('annonce VoiceOver du message', (tester) async {
      final announced = <String>[];
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility,
        (message) async {
          final map = message as Map<dynamic, dynamic>;
          if (map['type'] == 'announce') announced.add((map['data'] as Map<dynamic, dynamic>)['message'] as String);
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, null));
      final ctx = await _host(tester);
      showCgToast(ctx, _msg);
      await tester.pump();
      expect(announced, [_msg]);
      await _runOut(tester);
    });

    testWidgets('au-dessus de la tab bar et de la safe area', (tester) async {
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);
      final ctx = await _host(tester);
      showCgToast(ctx, _msg, aboveTabBar: true);
      await tester.pump();
      await tester.pump(CgMotion.base);
      final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final safe = 34 / tester.view.devicePixelRatio;
      final bottom = tester.getBottomLeft(find.byType(CgToastCapsule)).dy;
      expect(bottom, lessThanOrEqualTo(screen - safe - cgToastTabBarReserve));
      expect(cgToastTabBarReserve, CgSpace.tabBarHeight + CgSpace.tabBarBottom);
      await _runOut(tester);
    });

    testWidgets('aboveTabBar: false : posé plus bas, au-dessus de la safe area', (tester) async {
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.reset);
      final ctx = await _host(tester);
      showCgToast(ctx, _msg, aboveTabBar: false);
      await tester.pump();
      await tester.pump(CgMotion.base);
      final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final safe = 34 / tester.view.devicePixelRatio;
      final bottom = tester.getBottomLeft(find.byType(CgToastCapsule)).dy;
      expect(bottom, lessThanOrEqualTo(screen - safe));
      expect(bottom, greaterThan(screen - safe - cgToastTabBarReserve));
      await _runOut(tester);
    });

    testWidgets('par défaut : au-dessus de la tab bar seulement si l’écran en a une (CgTabBarScope)', (tester) async {
      late BuildContext inShell;
      late BuildContext inDrill;
      await tester.pumpWidget(cgTestApp(Column(children: [
        Expanded(child: CgTabBarScope(child: Builder(builder: (c) { inShell = c; return const SizedBox.expand(); }))),
        Expanded(child: Builder(builder: (c) { inDrill = c; return const SizedBox.expand(); })),
      ])));
      final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;

      showCgToast(inDrill, _msg);
      await tester.pump();
      await tester.pump(CgMotion.base);
      final drillBottom = tester.getBottomLeft(find.byType(CgToastCapsule)).dy;
      expect(drillBottom, greaterThan(screen - cgToastTabBarReserve), reason: 'pas de tab bar dans le drill');

      showCgToast(inShell, _msg);
      await tester.pump();
      await tester.pump(CgMotion.base);
      final shellBottom = tester.getBottomLeft(find.byType(CgToastCapsule)).dy;
      expect(shellBottom, lessThanOrEqualTo(screen - cgToastTabBarReserve));
      await _runOut(tester);
    });

    testWidgets('deux toasts dans la même frame : une seule capsule', (tester) async {
      final ctx = await _host(tester);
      showCgToast(ctx, 'Premier');
      showCgToast(ctx, 'Second');
      await tester.pump();
      expect(find.byType(CgToastCapsule), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      await _runOut(tester);
    });

    testWidgets('ne bloque pas les taps dessous', (tester) async {
      var taps = 0;
      late BuildContext ctx;
      await tester.pumpWidget(cgTestApp(Builder(builder: (context) {
        ctx = context;
        return GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++, child: const SizedBox.expand());
      })));
      showCgToast(ctx, _msg);
      await tester.pump(CgMotion.base);
      await tester.tap(find.byType(CgToastCapsule), warnIfMissed: false);
      expect(taps, 1);
      await _runOut(tester);
    });

    testWidgets('mouvement réduit : fondu seul, sans montée', (tester) async {
      final ctx = await _host(tester, reduced: true);
      showCgToast(ctx, _msg);
      await tester.pump();
      final start = tester.getTopLeft(find.byType(CgToastCapsule)).dy;
      expect(_opacity(tester), closeTo(0, 0.01));
      await tester.pump(CgMotion.fast);
      expect(_opacity(tester), 1);
      expect(tester.getTopLeft(find.byType(CgToastCapsule)).dy, start);
      await _runOut(tester);
      expect(find.byType(CgToastCapsule), findsNothing);
    });
  });

  group('goldens', () {
    cgGoldenMatrix('cg_toast', () => const CgToastGallery(), height: 360);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Story 8.1 — valeurs figées par la section « Direction de design » du spec v2.
void main() {
  group('couleurs (spec § Ce que la direction fixe pour les tokens)', () {
    const c = CgColors.light;
    test('fonds et encres', () {
      expect(c.ground, const Color(0xFFECEAE3));
      expect(c.surface, const Color(0xFFF7F6F2));
      expect(c.soft, const Color(0xFFE2E0D8));
      expect(c.ink, const Color(0xFF17201F));
      expect(c.ink2, const Color(0xFF5B6664));
      expect(c.line, const Color(0xFFD9D6CC));
    });
    test('accent sarcelle unique', () {
      expect(c.accent, const Color(0xFF0E5E63));
      expect(c.accentSoft, const Color(0xFFD5E6E4));
      expect(c.accentInk, const Color(0xFFF2F5F3));
      expect(c.rankA, c.accent);
      expect(c.mastered, c.accent);
    });
    test('états de progression et danger', () {
      expect(c.good, const Color(0xFF6FA8A2));
      expect(c.review, const Color(0xFFD9822B));
      expect(c.reviewInk, const Color(0xFF9A5A16));
      expect(c.unseen, const Color(0xFFD9D6CC));
      expect(c.danger, const Color(0xFFB8352B));
      expect(c.warning, c.review);
    });
    test('aucun blanc ni noir purs en fond', () {
      expect(c.ground, isNot(const Color(0xFFFFFFFF)));
      expect(c.ground, isNot(const Color(0xFF000000)));
    });
  });

  group('espace — grille 8 pt', () {
    test('gouttière écran 20, ligne 16, rythme 8/16/32/48', () {
      expect(CgSpace.gutter, 20);
      expect(CgSpace.rowInset, 16);
      expect(CgSpace.related, 8);
      expect(CgSpace.row, 16);
      expect(CgSpace.section, 32);
      expect(CgSpace.beforeLargeTitle, 48);
    });
    test('cibles tactiles ≥ 44 pt, boutons 54/44, tab bar 64', () {
      expect(CgSpace.tapTarget, greaterThanOrEqualTo(44));
      expect(CgSpace.buttonHeight, 54);
      expect(CgSpace.buttonHeightCompact, 44);
      expect(CgSpace.tabBarHeight, 64);
      expect(CgSpace.tabBarInset, 24);
    });
  });

  group('rayons — deux valeurs + bouton', () {
    test('r-s 10, r-l 20, bouton 14, badge 6', () {
      expect(CgRadius.s, 10);
      expect(CgRadius.l, 20);
      expect(CgRadius.button, 14);
      expect(CgRadius.badge, 6);
    });
  });

  group('mouvement', () {
    test('trois durées : 150 / 250 / 400 ms', () {
      expect(CgMotion.fast, const Duration(milliseconds: 150));
      expect(CgMotion.base, const Duration(milliseconds: 250));
      expect(CgMotion.slow, const Duration(milliseconds: 400));
    });

    testWidgets('Réduire les animations → durée 0', (tester) async {
      late Duration d;
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(builder: (context) {
          d = CgMotion.resolve(context, CgMotion.base);
          return const SizedBox();
        }),
      ));
      expect(d, Duration.zero);
    });

    testWidgets('animations actives → durée inchangée', (tester) async {
      late Duration d;
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(),
        child: Builder(builder: (context) {
          d = CgMotion.resolve(context, CgMotion.slow);
          return const SizedBox();
        }),
      ));
      expect(d, CgMotion.slow);
    });
  });

  group('typographie — Instrument Sans, une seule famille', () {
    test('échelle du spec', () {
      expect(CgType.display.fontSize, 40);
      expect(CgType.display.fontWeight, FontWeight.w700);
      expect(CgType.titleL.fontSize, 34);
      expect(CgType.title.fontSize, 22);
      expect(CgType.title.fontWeight, FontWeight.w600);
      expect(CgType.head.fontSize, 17);
      expect(CgType.head.fontWeight, FontWeight.w600);
      expect(CgType.body.fontSize, 17);
      expect(CgType.body.height, 1.45);
      expect(CgType.bodyS.fontSize, 15);
      expect(CgType.meta.fontSize, 14);
      expect(CgType.label.fontSize, 13);
      expect(CgType.label.fontWeight, FontWeight.w500);
    });

    test('tous les styles utilisent Instrument Sans', () {
      for (final s in CgType.all.values) {
        expect(s.fontFamily, CgType.family);
      }
      expect(CgType.family, 'InstrumentSans');
    });

    test('chiffres tabulaires sur les styles numériques', () {
      for (final s in [CgType.display, CgType.numeral, CgType.score, CgType.label]) {
        expect(s.fontFeatures, contains(const FontFeature.tabularFigures()));
      }
    });

    testWidgets('Dynamic Type : display et title-l plafonnés à 1,3×', (tester) async {
      late TextScaler capped;
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: CgTextScaleCap(
          child: Builder(builder: (context) {
            capped = MediaQuery.textScalerOf(context);
            return const SizedBox();
          }),
        ),
      ));
      expect(capped.scale(10), closeTo(13, 0.001));
    });

    testWidgets('Dynamic Type sous le plafond : inchangé', (tester) async {
      late TextScaler scaler;
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.1)),
        child: CgTextScaleCap(
          child: Builder(builder: (context) {
            scaler = MediaQuery.textScalerOf(context);
            return const SizedBox();
          }),
        ),
      ));
      expect(scaler.scale(10), closeTo(11, 0.001));
    });
  });
}

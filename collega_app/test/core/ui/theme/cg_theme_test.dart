import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Story 8.1 — thème Collega UI et neutralisation de Material.
void main() {
  group('CgTheme', () {
    testWidgets('fournit la palette du thème ancêtre', (tester) async {
      late CgColors colors;
      await tester.pumpWidget(CgTheme(
        data: CgThemeData.light,
        child: Builder(builder: (context) {
          colors = CgTheme.of(context).colors;
          return const SizedBox();
        }),
      ));
      expect(colors, same(CgColors.light));
    });

    testWidgets('replie sur le thème clair sans ancêtre', (tester) async {
      late CgThemeData data;
      await tester.pumpWidget(Builder(builder: (context) {
        data = CgTheme.of(context);
        return const SizedBox();
      }));
      expect(data.colors, same(CgColors.light));
    });
  });

  group('neutralizeMaterial — MaterialApp reste un conteneur technique', () {
    final base = ThemeData.light(useMaterial3: true);
    final t = neutralizeMaterial(base);

    test('aucune ondulation ni surbrillance Material', () {
      expect(t.splashFactory, NoSplash.splashFactory);
      expect(t.highlightColor, Colors.transparent);
      expect(t.splashColor, Colors.transparent);
      expect(t.hoverColor, Colors.transparent);
    });

    test('transitions de page iOS (retour par balayage) partout', () {
      expect(
        t.pageTransitionsTheme.builders[TargetPlatform.iOS],
        isA<CupertinoPageTransitionsBuilder>(),
      );
      expect(
        t.pageTransitionsTheme.builders[TargetPlatform.android],
        isA<CupertinoPageTransitionsBuilder>(),
      );
    });

    test('plateforme iOS forcée (sélection de texte, défilement, retours)', () {
      expect(t.platform, TargetPlatform.iOS);
    });
  });

  group('buildCgMaterialTheme — pour les écrans Collega UI', () {
    final t = buildCgMaterialTheme(CgThemeData.light);
    const c = CgColors.light;

    test('fond, surfaces et accent viennent des tokens', () {
      expect(t.scaffoldBackgroundColor, c.ground);
      expect(t.colorScheme.primary, c.accent);
      expect(t.colorScheme.onPrimary, c.accentInk);
      expect(t.colorScheme.surface, c.surface);
      expect(t.colorScheme.onSurface, c.ink);
      expect(t.colorScheme.error, c.danger);
    });

    test('police Instrument Sans', () {
      expect(t.textTheme.bodyMedium?.fontFamily, CgType.family);
    });

    test('reste neutralisé', () {
      expect(t.splashFactory, NoSplash.splashFactory);
    });
  });

  test('Cupertino n’est thémé qu’à la couleur d’accent', () {
    final ct = buildCgCupertinoTheme(CgThemeData.light);
    expect(ct.primaryColor, CgColors.light.accent);
    expect(ct.brightness, Brightness.light);
  });
}

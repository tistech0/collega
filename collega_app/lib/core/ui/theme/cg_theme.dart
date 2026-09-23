import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Données du thème Collega UI. Un seul thème en v2 ; un thème sombre serait
/// un second `CgThemeData`, sans toucher aux composants.
@immutable
class CgThemeData {
  const CgThemeData({required this.colors});

  final CgColors colors;

  static const light = CgThemeData(colors: CgColors.light);
}

/// Fournit [CgThemeData] au sous-arbre. Sans ancêtre, `of` replie sur le thème clair.
class CgTheme extends InheritedWidget {
  const CgTheme({super.key, required this.data, required super.child});

  final CgThemeData data;

  static CgThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CgTheme>()?.data ?? CgThemeData.light;

  @override
  bool updateShouldNotify(CgTheme oldWidget) => data != oldWidget.data;
}

const _cupertinoTransitions = PageTransitionsTheme(builders: {
  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  TargetPlatform.android: CupertinoPageTransitionsBuilder(),
  TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
});

/// Retire de Material tout ce qui se voit ou se ressent : ondulation,
/// surbrillance, transitions Android. `MaterialApp` reste un conteneur
/// technique (routing, overlays) ; les couleurs existantes sont conservées.
ThemeData neutralizeMaterial(ThemeData base) => base.copyWith(
      platform: TargetPlatform.iOS,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      pageTransitionsTheme: _cupertinoTransitions,
    );

/// Thème Material entièrement dérivé des tokens, pour les écrans Collega UI.
ThemeData buildCgMaterialTheme(CgThemeData data) {
  final c = data.colors;
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: CgType.family,
    scaffoldBackgroundColor: c.ground,
    canvasColor: c.ground,
    dividerColor: c.line,
    colorScheme: ColorScheme.light(
      primary: c.accent,
      onPrimary: c.accentInk,
      secondary: c.accent,
      onSecondary: c.accentInk,
      surface: c.surface,
      onSurface: c.ink,
      error: c.danger,
      onError: c.accentInk,
      outline: c.line,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accentSoft,
      selectionHandleColor: c.accent,
    ),
  );
  return neutralizeMaterial(base);
}

/// Cupertino n'est thémé qu'à la couleur d'accent : ses widgets restent natifs.
CupertinoThemeData buildCgCupertinoTheme(CgThemeData data) => CupertinoThemeData(
      brightness: Brightness.light,
      primaryColor: data.colors.accent,
    );

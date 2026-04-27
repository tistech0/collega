import 'package:flutter/material.dart';

// Stub — palette complète configurée en Story 2.1 (shadcn_ui theme)
// Les tokens de design définis ici seront surchargés par shadcn_ui en Story 2.1

class AppColors {
  static const primary = Color(0xFF1B6B3A);
  static const primaryContainer = Color(0xFFB7F2C8);
  static const secondary = Color(0xFF3D6B5E);
  static const surface = Color(0xFFF8FAF9);
  static const onSurface = Color(0xFF1A1C1A);
  static const error = Color(0xFFBA1A1A);
  static const warning = Color(0xFFF0A500);
}

class AppSpacing {
  static const screenMargin = 16.0;
  static const cardPadding = 16.0;
  static const sectionSpacing = 24.0;
  static const cardRadius = 12.0;
  static const buttonRadius = 8.0;
  static const baseUnit = 8.0;
}

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    useMaterial3: true,
  );
}

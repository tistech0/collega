import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AppColors {
  static const primary = Color(0xFF1B6B3A);
  static const primaryContainer = Color(0xFFB7F2C8);
  static const secondary = Color(0xFF3D6B5E);
  static const surface = Color(0xFFF8FAF9);
  static const onSurface = Color(0xFF1A1C1A);
  static const error = Color(0xFFBA1A1A);
  static const warning = Color(0xFFF0A500);

  /// Rail (fond) des barres de progression. shadcn_ui utilise sinon
  /// `colorScheme.secondary` — vert foncé chez nous, ce qui rend une barre
  /// vide visuellement pleine.
  static const progressTrack = Color(0xFFE2EAE4);
}

class AppSpacing {
  static const screenMargin = 16.0;
  static const cardPadding = 16.0;
  static const sectionSpacing = 24.0;
  static const cardRadius = 12.0;
  static const buttonRadius = 8.0;
  static const baseUnit = 8.0;
}

class AppTypography {
  static TextStyle displayMedium() =>
      GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700);
  static TextStyle titleLarge() =>
      GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600);
  static TextStyle titleMedium() =>
      GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600);
  static TextStyle bodyLarge() =>
      GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400);
  static TextStyle bodyMedium() =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400);
  static TextStyle labelMedium() =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500);
}

ShadThemeData buildShadTheme() {
  return ShadThemeData(
    brightness: Brightness.light,
    colorScheme: const ShadColorScheme(
      background: Color(0xFFF8FAF9),
      foreground: Color(0xFF1A1C1A),
      card: Color(0xFFFFFFFF),
      cardForeground: Color(0xFF1A1C1A),
      popover: Color(0xFFFFFFFF),
      popoverForeground: Color(0xFF1A1C1A),
      primary: Color(0xFF1B6B3A),
      primaryForeground: Color(0xFFFFFFFF),
      secondary: Color(0xFF3D6B5E),
      secondaryForeground: Color(0xFFFFFFFF),
      muted: Color(0xFFF1F5F2),
      mutedForeground: Color(0xFF6B7C6E),
      accent: Color(0xFFB7F2C8),
      accentForeground: Color(0xFF1B6B3A),
      destructive: Color(0xFFBA1A1A),
      destructiveForeground: Color(0xFFFFFFFF),
      border: Color(0xFFE2EAE4),
      input: Color(0xFFE2EAE4),
      ring: Color(0xFF1B6B3A),
      selection: Color(0xFFB7F2C8),
    ),
    progressTheme: const ShadProgressTheme(
      color: AppColors.primary,
      backgroundColor: AppColors.progressTrack,
    ),
    textTheme: ShadTextTheme.fromGoogleFont(GoogleFonts.inter).copyWith(
      h2: AppTypography.displayMedium(),
      h3: AppTypography.titleLarge(),
      large: AppTypography.titleMedium(),
      p: AppTypography.bodyLarge(),
      small: AppTypography.bodyMedium(),
      muted: AppTypography.labelMedium(),
    ),
  );
}

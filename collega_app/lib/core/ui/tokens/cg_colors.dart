import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

/// Palette Collega UI (spec v2 § Direction de design « Feuille × Bloc »).
///
/// Un seul thème, mais nommé par rôle : un thème sombre serait un second
/// `const CgColors(...)`, pas une réécriture. Aucun écran ni composant ne
/// référence une couleur brute — tout passe par ces rôles.
///
/// Écarts au spec, imposés par ses propres seuils de contraste (test
/// `contrast_test.dart`) : `ink3` #9A9E97 → #60645E (texte tertiaire ≥ 4,5:1 sur
/// ground, surface et soft, story 8.15 ; `ink2` #5B6664 → #454D4C pour rester distinct),
/// `rankB` #4C6A6E → #4C696D, `rankC` #8B8A80 → #64635B (texte de badge
/// ≥ 4,5:1), et le texte posé sur `review` est `ink` (le blanc ne fait que 2,9:1).
@immutable
class CgColors {
  const CgColors({
    required this.ground,
    required this.surface,
    required this.soft,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.accent,
    required this.accentSoft,
    required this.accentInk,
    required this.rankA,
    required this.rankB,
    required this.rankBSoft,
    required this.rankC,
    required this.mastered,
    required this.good,
    required this.review,
    required this.reviewInk,
    required this.onReview,
    required this.unseen,
    required this.danger,
    required this.warning,
    required this.warningInk,
    required this.scrim,
  });

  /// Fond d'écran (pierre, teinté — jamais #FFF ni #000).
  final Color ground;

  /// Cartes, sheets, tab bar : un cran au-dessus de [ground].
  final Color surface;

  /// Rails, skeletons, champs de recherche, état pressé.
  final Color soft;

  /// Texte principal / secondaire / désactivé.
  final Color ink;
  final Color ink2;
  final Color ink3;

  /// Filets et contours.
  final Color line;

  /// La couleur de marque : CTA primaire, sélection, anneau plein. Jamais décorative.
  final Color accent;
  final Color accentSoft;

  /// Texte et icônes posés sur [accent].
  final Color accentInk;

  final Color rankA;
  final Color rankB;

  /// Fond du badge de rang B.
  final Color rankBSoft;

  /// Texte du badge de rang C (fond : [soft]).
  final Color rankC;

  final Color mastered;
  final Color good;

  /// « À revoir » en surface (segment, pastille). En texte : [reviewInk].
  final Color review;
  final Color reviewInk;

  /// Texte posé sur [review].
  final Color onReview;

  final Color unseen;

  /// Réservé au destructif et aux erreurs bloquantes.
  final Color danger;

  /// Badge OCR « À vérifier » (surface) ; texte : [warningInk].
  final Color warning;
  final Color warningInk;

  /// Voile derrière une sheet (ink à 40 %).
  final Color scrim;

  static const light = CgColors(
    ground: Color(0xFFECEAE3),
    surface: Color(0xFFF7F6F2),
    soft: Color(0xFFE2E0D8),
    ink: Color(0xFF17201F),
    ink2: Color(0xFF454D4C),
    ink3: Color(0xFF60645E),
    line: Color(0xFFD9D6CC),
    accent: Color(0xFF0E5E63),
    accentSoft: Color(0xFFD5E6E4),
    accentInk: Color(0xFFF2F5F3),
    rankA: Color(0xFF0E5E63),
    rankB: Color(0xFF4C696D),
    rankBSoft: Color(0xFFDDE3E3),
    rankC: Color(0xFF64635B),
    mastered: Color(0xFF0E5E63),
    good: Color(0xFF6FA8A2),
    review: Color(0xFFD9822B),
    reviewInk: Color(0xFF9A5A16),
    onReview: Color(0xFF17201F),
    unseen: Color(0xFFD9D6CC),
    danger: Color(0xFFB8352B),
    warning: Color(0xFFD9822B),
    warningInk: Color(0xFF9A5A16),
    scrim: Color(0x6617201F),
  );
}

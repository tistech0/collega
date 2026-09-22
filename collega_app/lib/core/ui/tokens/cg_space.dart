/// Espaces Collega UI — grille 8 pt (spec v2 § Espace, formes, mouvement).
abstract final class CgSpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s12 = 48;

  /// Marge latérale d'écran (HIG).
  static const double gutter = 20;

  /// Gouttière interne d'une ligne.
  static const double rowInset = 16;

  /// Rythme vertical : éléments liés / lignes / sections / avant un large title.
  static const double related = 8;
  static const double row = 16;
  static const double section = 32;
  static const double beforeLargeTitle = 48;

  static const double tapTarget = 44;
  static const double buttonHeight = 54;
  static const double buttonHeightCompact = 44;

  /// Tab bar flottante : hauteur, écart aux bords, distance au bas de l'écran.
  static const double tabBarHeight = 64;
  static const double tabBarInset = 24;
  static const double tabBarBottom = 22;

  /// Colonne de contenu au plus large (Pro Max : rien ne s'étire).
  static const double maxContentWidth = 430;
}

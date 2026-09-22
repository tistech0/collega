import 'package:flutter/painting.dart';

/// Rayons Collega UI : deux valeurs (+ bouton et badge figés par la direction).
abstract final class CgRadius {
  /// Champs, segmented, icônes de ligne.
  static const double s = 10;

  /// Cartes de drill, sheets, groupes insetGrouped.
  static const double l = 20;

  static const double button = 14;
  static const double badge = 6;

  static const BorderRadius sAll = BorderRadius.all(Radius.circular(s));
  static const BorderRadius lAll = BorderRadius.all(Radius.circular(l));
  static const BorderRadius buttonAll = BorderRadius.all(Radius.circular(button));
  static const BorderRadius badgeAll = BorderRadius.all(Radius.circular(badge));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

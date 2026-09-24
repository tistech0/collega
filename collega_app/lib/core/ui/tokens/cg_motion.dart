import 'package:flutter/widgets.dart';

/// Mouvement Collega UI : trois durées, une courbe de sortie, une élastique.
///
/// Tout composant passe ses durées par [resolve] : « Réduire les animations »
/// (iOS) les ramène à zéro (le composant choisit alors un fondu ou la valeur finale).
abstract final class CgMotion {
  /// Retours visuels (pression, pastille d'onglet).
  static const fast = Duration(milliseconds: 150);

  /// Verdict, transitions de liste.
  static const base = Duration(milliseconds: 250);

  /// Flip, fermeture d'anneau courte.
  static const slow = Duration(milliseconds: 400);

  /// Durées nommées de la maquette (drill, anneaux, compteur de fin de session).
  static const sheetRise = Duration(milliseconds: 380);
  static const questionLift = Duration(milliseconds: 350);
  static const ringFill = Duration(milliseconds: 900);
  static const skeletonPulse = Duration(milliseconds: 1200);
  static const toast = Duration(seconds: 2);

  /// Toast à lire en entier (liste d'items, plusieurs lignes) : le temps de lire les numéros.
  static const toastLong = Duration(seconds: 6);

  /// ease-out de la maquette : cubic-bezier(.2,.7,.2,1).
  static const Curve out = Cubic(0.2, 0.7, 0.2, 1);

  /// Retour de carte sous le seuil de swipe.
  static const Curve elastic = Curves.easeOutBack;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration resolve(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

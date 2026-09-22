import 'package:flutter/services.dart';

/// Retours haptiques Collega UI (spec v2 § Mouvement et haptique).
///
/// iOS respecte de lui-même le réglage système ; l'haptique n'est jamais le
/// seul signal d'un événement. Flutter n'expose pas le retour « succès »
/// d'UINotificationFeedbackGenerator : il est rendu par un impact lourd.
abstract final class CgHaptics {
  /// Changement d'onglet, de segment.
  static Future<void> selection() => HapticFeedback.selectionClick();

  /// Retournement d'une fiche.
  static Future<void> flip() => HapticFeedback.lightImpact();

  static Future<void> review() => HapticFeedback.mediumImpact();
  static Future<void> good() => HapticFeedback.lightImpact();
  static Future<void> mastered() => HapticFeedback.heavyImpact();

  /// Fin de session, import terminé.
  static Future<void> success() => HapticFeedback.heavyImpact();

  /// Erreur (une fois).
  static Future<void> error() => HapticFeedback.vibrate();
}

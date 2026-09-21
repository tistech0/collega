import 'dart:math' as math;

import 'package:flutter/foundation.dart';

@immutable
class DrillStats {
  const DrillStats({
    this.maitrise = 0,
    this.bien = 0,
    this.aRevoir = 0,
    this.notSeen = 0,
  });

  /// Compte les niveaux de drill (`maitrise` / `bien` / `a_revoir` / `new`) ;
  /// toute autre valeur est ignorée.
  factory DrillStats.fromDrillLevels(Iterable<String> levels) {
    int maitrise = 0, bien = 0, aRevoir = 0, notSeen = 0;
    for (final level in levels) {
      switch (level) {
        case 'maitrise':
          maitrise++;
        case 'bien':
          bien++;
        case 'a_revoir':
          aRevoir++;
        case 'new':
          notSeen++;
        default:
          break;
      }
    }
    return DrillStats(
      maitrise: maitrise,
      bien: bien,
      aRevoir: aRevoir,
      notSeen: notSeen,
    );
  }

  final int maitrise;
  final int bien;
  final int aRevoir;
  final int notSeen;

  int get total => maitrise + bien + aRevoir + notSeen;

  int get masteryPercent =>
      total == 0 ? 0 : ((maitrise / total) * 100).round();

  /// Fiches ayant reçu une évaluation (hors `new`).
  int get drilled => maitrise + bien + aRevoir;

  /// Recale le « non vu » sur le total connu du serveur.
  ///
  /// Les fiches ne sont cachées en local qu'à l'ouverture d'un item : le
  /// `notSeen` local ne couvre donc que les items déjà ouverts. Le total
  /// serveur (`card_count_*`) est la seule référence fiable.
  DrillStats withTotal(int serverTotal) => DrillStats(
        maitrise: maitrise,
        bien: bien,
        aRevoir: aRevoir,
        notSeen: math.max(0, serverTotal - drilled),
      );

  @override
  bool operator ==(Object other) =>
      other is DrillStats &&
      other.maitrise == maitrise &&
      other.bien == bien &&
      other.aRevoir == aRevoir &&
      other.notSeen == notSeen;

  @override
  int get hashCode => Object.hash(maitrise, bien, aRevoir, notSeen);

  @override
  String toString() =>
      'DrillStats(maitrise: $maitrise, bien: $bien, aRevoir: $aRevoir, notSeen: $notSeen)';
}

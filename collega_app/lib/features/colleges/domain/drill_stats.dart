import 'package:flutter/foundation.dart';

@immutable
class DrillStats {
  const DrillStats({
    this.maitrise = 0,
    this.bien = 0,
    this.aRevoir = 0,
    this.notSeen = 0,
  });

  final int maitrise;
  final int bien;
  final int aRevoir;
  final int notSeen;

  int get total => maitrise + bien + aRevoir + notSeen;

  int get masteryPercent =>
      total == 0 ? 0 : ((maitrise / total) * 100).round();
}

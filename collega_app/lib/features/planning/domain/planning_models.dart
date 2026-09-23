import 'dart:math' as math;

import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/features/today/domain/daily_session_builder.dart';
import 'package:flutter/foundation.dart';

@immutable
class PlanningConfig {
  const PlanningConfig({
    required this.id,
    required this.collegeIds,
    this.itemIds,
    required this.startDate,
    required this.endDate,
    required this.dailyMinutes,
    required this.createdAt,
  });

  final String id;
  final List<String> collegeIds;
  final List<String>? itemIds;
  final DateTime startDate;
  final DateTime endDate;
  final int dailyMinutes;
  final DateTime createdAt;

  /// Même convention que la session du jour : 1 fiche ≈ 50 s (story 8.3).
  int get cardsPerDay => math.max(1, sessionBudget(dailyMinutes: dailyMinutes));

  /// Même planning, fin au jour [endDay] (jours epoch : jamais ± 24 h, qui
  /// déraperait au changement d'heure).
  PlanningConfig withEndDay(int endDay) => PlanningConfig(
        id: id,
        collegeIds: collegeIds,
        itemIds: itemIds,
        startDate: startDate,
        endDate: dateOfEpochDay(endDay),
        dailyMinutes: dailyMinutes,
        createdAt: createdAt,
      );
}

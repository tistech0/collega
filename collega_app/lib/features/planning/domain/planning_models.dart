import 'dart:math' as math;

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
}

@immutable
class PlannedSession {
  const PlannedSession({
    required this.id,
    required this.planningConfigId,
    required this.sessionDate,
    required this.collegeId,
    required this.maxCards,
    required this.status,
  });

  final String id;
  final String planningConfigId;
  final DateTime sessionDate;
  final String collegeId;
  final int maxCards;
  final String status; // 'pending' | 'completed' | 'postponed'

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
}

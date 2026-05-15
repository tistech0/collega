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

  int get cardsPerDay => (dailyMinutes * 5).clamp(5, 100);
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

import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/planning/domain/planning_models.dart';

class PlanningRepository {
  const PlanningRepository({required this.db});

  final AppDatabase db;

  // ── Config ──────────────────────────────────────────────────────────────────

  Future<PlanningConfig?> getActiveConfig() async {
    final rows = await db.select(db.planningConfigs).get();
    if (rows.isEmpty) return null;
    return _configFromRow(rows.last);
  }

  Future<void> saveConfig(PlanningConfig config) async {
    await db.into(db.planningConfigs).insertOnConflictUpdate(
      PlanningConfigsCompanion.insert(
        id: config.id,
        collegeIds: jsonEncode(config.collegeIds),
        itemIds: Value(
            config.itemIds == null ? null : jsonEncode(config.itemIds)),
        startDateEpochDay: _toEpochDay(config.startDate),
        endDateEpochDay: _toEpochDay(config.endDate),
        dailyMinutes: config.dailyMinutes,
        createdAtMs: config.createdAt.millisecondsSinceEpoch,
      ),
    );
  }

  // ── Sessions ────────────────────────────────────────────────────────────────

  Future<PlannedSession?> getTodaySession() async {
    final today = _toEpochDay(DateTime.now());
    final rows = await (db.select(db.planningSessions)
          ..where((t) => t.sessionDateEpochDay.equals(today))
          ..where((t) => t.status.equals('pending')))
        .get();
    if (rows.isEmpty) return null;
    return _sessionFromRow(rows.first);
  }

  Future<void> saveSessions(List<PlannedSession> sessions) async {
    await db.batch((batch) {
      for (final s in sessions) {
        batch.insert(
          db.planningSessions,
          PlanningSessionsCompanion.insert(
            id: s.id,
            planningConfigId: s.planningConfigId,
            sessionDateEpochDay: _toEpochDay(s.sessionDate),
            collegeId: s.collegeId,
            maxCards: s.maxCards,
            status: Value(s.status),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> markSessionCompleted(String sessionId) async {
    await (db.update(db.planningSessions)
          ..where((t) => t.id.equals(sessionId)))
        .write(const PlanningSessionsCompanion(
      status: Value('completed'),
    ));
  }

  Future<void> postponeSession(String sessionId) async {
    final row = await (db.select(db.planningSessions)
          ..where((t) => t.id.equals(sessionId)))
        .getSingleOrNull();
    if (row == null) return;

    await (db.update(db.planningSessions)
          ..where((t) => t.id.equals(sessionId)))
        .write(const PlanningSessionsCompanion(
      status: Value('postponed'),
    ));

    var nextDay = row.sessionDateEpochDay + 1;
    while (true) {
      final existing = await (db.select(db.planningSessions)
            ..where((t) => t.sessionDateEpochDay.equals(nextDay))
            ..where((t) => t.status.equals('pending')))
          .get();
      if (existing.isEmpty) break;
      nextDay++;
    }
    // Unique par session d'origine ET jour de destination : deux sessions du même
    // jour décalées ne se percutent plus (story 8.3).
    final newId = '${row.id}-postponed-$nextDay';
    await db.into(db.planningSessions).insertOnConflictUpdate(
      PlanningSessionsCompanion.insert(
        id: newId,
        planningConfigId: row.planningConfigId,
        sessionDateEpochDay: nextDay,
        collegeId: row.collegeId,
        maxCards: row.maxCards,
        status: const Value('pending'),
      ),
    );
  }

  Future<void> deleteAllPendingSessions() async {
    await (db.delete(db.planningSessions)
          ..where((t) => t.status.equals('pending')))
        .go();
  }

  Future<void> deleteAllConfigs() async {
    await db.delete(db.planningConfigs).go();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static int _toEpochDay(DateTime dt) =>
      DateTime.utc(dt.year, dt.month, dt.day).millisecondsSinceEpoch ~/
      86400000;

  static DateTime _fromEpochDay(int day) =>
      DateTime.fromMillisecondsSinceEpoch(day * 86400000, isUtc: true);

  PlanningConfig _configFromRow(PlanningConfigRow row) {
    final collegeIds =
        (jsonDecode(row.collegeIds) as List).cast<String>();
    final itemIds = row.itemIds == null
        ? null
        : (jsonDecode(row.itemIds!) as List).cast<String>();
    return PlanningConfig(
      id: row.id,
      collegeIds: collegeIds,
      itemIds: itemIds,
      startDate: _fromEpochDay(row.startDateEpochDay),
      endDate: _fromEpochDay(row.endDateEpochDay),
      dailyMinutes: row.dailyMinutes,
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(row.createdAtMs, isUtc: true),
    );
  }

  PlannedSession _sessionFromRow(PlanningSessionRow row) {
    return PlannedSession(
      id: row.id,
      planningConfigId: row.planningConfigId,
      sessionDate: _fromEpochDay(row.sessionDateEpochDay),
      collegeId: row.collegeId,
      maxCards: row.maxCards,
      status: row.status,
    );
  }
}

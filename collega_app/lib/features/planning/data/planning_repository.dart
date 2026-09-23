import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/utils/epoch_day.dart';
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

  /// Remplace le planning actif (un seul à la fois) et ses jours décalés.
  Future<void> replace(PlanningConfig config) async {
    await db.transaction(() async {
      await clear();
      await saveConfig(config);
    });
  }

  Future<void> clear() async {
    await db.transaction(() async {
      await db.delete(db.planningSessions).go();
      await db.delete(db.planningConfigs).go();
    });
  }

  // ── Jours décalés ───────────────────────────────────────────────────────────
  // Depuis la 8.3 la session du jour est calculée à part : `planning_sessions`
  // ne garde que les jours décalés (« Décaler aujourd'hui », story 8.9).

  static const _postponed = 'postponed';

  Future<Set<int>> postponedDays(String configId) async {
    final rows = await (db.select(db.planningSessions)
          ..where((t) => t.planningConfigId.equals(configId) & t.status.equals(_postponed)))
        .get();
    return rows.map((r) => r.sessionDateEpochDay).toSet();
  }

  Future<void> addPostponed(String configId, int day) async {
    await db.into(db.planningSessions).insertOnConflictUpdate(PlanningSessionsCompanion.insert(
          id: '$configId-postponed-$day',
          planningConfigId: configId,
          sessionDateEpochDay: day,
          collegeId: '',
          maxCards: 0,
          status: const Value(_postponed),
        ));
  }

  /// Décale [day] et prolonge la période d'un jour, en une seule transaction.
  Future<void> postpone(PlanningConfig config, int day) => db.transaction(() async {
        await addPostponed(config.id, day);
        await saveConfig(config.withEndDay(epochDayOf(config.endDate) + 1));
      });

  /// Annule le décalage de [day] et rend le jour ajouté à la période.
  Future<void> unpostpone(PlanningConfig config, int day) => db.transaction(() async {
        await removePostponed(config.id, day);
        await saveConfig(config.withEndDay(epochDayOf(config.endDate) - 1));
      });

  Future<void> removePostponed(String configId, int day) async {
    await (db.delete(db.planningSessions)..where((t) => t.id.equals('$configId-postponed-$day'))).go();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static int _toEpochDay(DateTime dt) => epochDayOf(dt);

  /// Minuit local du jour (les écrans affichent et comparent des dates locales).
  static DateTime _fromEpochDay(int day) => dateOfEpochDay(day);

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
}

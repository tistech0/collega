import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/planning/data/planning_repository.dart';
import 'package:collega_app/features/planning/domain/planning_models.dart';

AppDatabase _makeDb() => AppDatabase.forTesting(NativeDatabase.memory());

PlanningConfig _cfg() => PlanningConfig(
      id: 'cfg1',
      collegeIds: ['c1'],
      startDate: DateTime.utc(2026, 1, 1),
      endDate: DateTime.utc(2026, 1, 7),
      dailyMinutes: 30,
      createdAt: DateTime.utc(2026, 1, 1),
    );

PlannedSession _session({
  String id = 's1',
  required String configId,
  required DateTime date,
  String status = 'pending',
}) =>
    PlannedSession(
      id: id,
      planningConfigId: configId,
      sessionDate: date,
      collegeId: 'c1',
      maxCards: 100,
      status: status,
    );

void main() {
  group('PlanningRepository', () {
    test('getActiveConfig() retourne null si aucune config', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final repo = PlanningRepository(db: db);

      final result = await repo.getActiveConfig();
      expect(result, isNull);
    });

    test('saveConfig + getActiveConfig retourne la config', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final repo = PlanningRepository(db: db);
      final cfg = _cfg();

      await repo.saveConfig(cfg);
      final result = await repo.getActiveConfig();

      expect(result, isNotNull);
      expect(result!.id, cfg.id);
      expect(result.collegeIds, ['c1']);
      expect(result.dailyMinutes, 30);
    });

    test('getTodaySession() retourne null si aucune session', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final repo = PlanningRepository(db: db);

      final result = await repo.getTodaySession();
      expect(result, isNull);
    });

    test('saveSessions + getTodaySession retourne la session du jour', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final repo = PlanningRepository(db: db);

      final today = DateTime.now().toUtc();
      final todayDate = DateTime.utc(today.year, today.month, today.day);
      final session = _session(configId: 'cfg1', date: todayDate);

      await repo.saveSessions([session]);
      final result = await repo.getTodaySession();

      expect(result, isNotNull);
      expect(result!.id, 's1');
      expect(result.isPending, isTrue);
    });

    test('markSessionCompleted passe le statut à completed', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final repo = PlanningRepository(db: db);

      final today = DateTime.now().toUtc();
      final todayDate = DateTime.utc(today.year, today.month, today.day);
      await repo.saveSessions([_session(configId: 'cfg1', date: todayDate)]);

      await repo.markSessionCompleted('s1');

      final result = await repo.getTodaySession();
      expect(result, isNull); // completed → plus de session pending aujourd'hui
    });

    test('postponeSession crée une session au lendemain', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final repo = PlanningRepository(db: db);

      final today = DateTime.now().toUtc();
      final todayDate = DateTime.utc(today.year, today.month, today.day);
      final tomorrowDate = todayDate.add(const Duration(days: 1));
      await repo.saveSessions([_session(configId: 'cfg1', date: todayDate)]);

      await repo.postponeSession('s1');

      // Session d'aujourd'hui marquée postponed
      final todaySession = await repo.getTodaySession();
      expect(todaySession, isNull);

      // Session de demain créée
      final allSessions =
          await db.select(db.planningSessions).get();
      final tomorrow = allSessions.where((s) =>
          s.status == 'pending' &&
          s.sessionDateEpochDay ==
              tomorrowDate.millisecondsSinceEpoch ~/ 86400000);
      expect(tomorrow, isNotEmpty);
    });
  
    test('décaler deux sessions du même jour : pas de collision d’identifiant (story 8.3)', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final repo = PlanningRepository(db: db);
      final today = DateTime.now().toUtc();
      final todayDate = DateTime.utc(today.year, today.month, today.day);
      await repo.saveSessions([
        _session(configId: 'cfg1', date: todayDate),
        _session(id: 's2', configId: 'cfg1', date: todayDate),
      ]);
      await repo.postponeSession('s1');
      await repo.postponeSession('s2');
      final pending = (await db.select(db.planningSessions).get()).where((s) => s.status == 'pending');
      expect(pending, hasLength(2));
    });
});
}

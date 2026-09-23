import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/features/planning/data/planning_repository.dart';
import 'package:collega_app/features/planning/domain/planning_models.dart';

PlanningConfig _config({String id = 'cfg', int days = 30}) => PlanningConfig(
      id: id,
      collegeIds: const ['c1', 'c2'],
      startDate: DateTime(2026, 9, 21),
      endDate: DateTime(2026, 9, 21).add(Duration(days: days - 1)),
      dailyMinutes: 30,
      createdAt: DateTime.utc(2026, 9, 21),
    );

void main() {
  late AppDatabase db;
  late PlanningRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = PlanningRepository(db: db);
  });
  tearDown(() => db.close());

  test('sans planning : null', () async {
    expect(await repo.getActiveConfig(), isNull);
  });

  test('saveConfig + getActiveConfig : dates locales conservées au jour près', () async {
    await repo.saveConfig(_config());
    final c = await repo.getActiveConfig();
    expect(c!.collegeIds, ['c1', 'c2']);
    expect(epochDayOf(c.startDate), epochDayOf(DateTime(2026, 9, 21)));
    expect(epochDayOf(c.endDate), epochDayOf(DateTime(2026, 10, 20)));
    expect(c.dailyMinutes, 30);
  });

  test('replace : un seul planning actif, les jours décalés de l’ancien disparaissent', () async {
    await repo.replace(_config(id: 'old'));
    await repo.addPostponed('old', 20000);
    await repo.replace(_config(id: 'new'));
    expect((await repo.getActiveConfig())!.id, 'new');
    expect(await repo.postponedDays('new'), isEmpty);
    expect(await db.select(db.planningSessions).get(), isEmpty);
  });

  test('jours décalés : ajout idempotent, retrait', () async {
    await repo.replace(_config());
    await repo.addPostponed('cfg', 20000);
    await repo.addPostponed('cfg', 20000);
    await repo.addPostponed('cfg', 20003);
    expect(await repo.postponedDays('cfg'), {20000, 20003});
    await repo.removePostponed('cfg', 20000);
    expect(await repo.postponedDays('cfg'), {20003});
  });

  test('clear : plus de planning ni de jours décalés', () async {
    await repo.replace(_config());
    await repo.addPostponed('cfg', 20000);
    await repo.clear();
    expect(await repo.getActiveConfig(), isNull);
    expect(await db.select(db.planningSessions).get(), isEmpty);
  });
}

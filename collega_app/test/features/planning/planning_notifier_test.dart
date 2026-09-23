import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/features/planning/planning_providers.dart';
import 'package:collega_app/features/today/data/daily_session_repository.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  var clock = DateTime(2026, 9, 23, 10);
  final today = DateTime(2026, 9, 23, 10);

  setUp(() {
    clock = today;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      planningClockProvider.overrideWithValue(() => clock),
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  PlanningNotifier notifier() => container.read(planningProvider.notifier);

  Future<void> planFrom21to20Oct() => notifier().plan(
        collegeIds: const ['c1'],
        startDate: DateTime(2026, 9, 21),
        endDate: DateTime(2026, 10, 20),
        dailyMinutes: 30,
      );

  test('plan : le planning devient actif', () async {
    await planFrom21to20Oct();
    final s = await container.read(planningProvider.future);
    expect(s.config!.collegeIds, ['c1']);
    expect(s.config!.dailyMinutes, 30);
    expect(s.postponedToday, isFalse);
  });

  test('décaler aujourd’hui : prolonge d’un jour, marque le jour ; annuler rétablit', () async {
    await planFrom21to20Oct();
    await notifier().postponeToday();
    var s = await container.read(planningProvider.future);
    expect(s.postponedToday, isTrue);
    expect(s.postponedDays, {epochDayOf(today)});
    expect(epochDayOf(s.config!.endDate), epochDayOf(DateTime(2026, 10, 21)));

    // Deux fois de suite : sans effet (pas deux jours ajoutés).
    await notifier().postponeToday();
    s = await container.read(planningProvider.future);
    expect(epochDayOf(s.config!.endDate), epochDayOf(DateTime(2026, 10, 21)));

    await notifier().cancelPostpone();
    s = await container.read(planningProvider.future);
    expect(s.postponedToday, isFalse);
    expect(epochDayOf(s.config!.endDate), epochDayOf(DateTime(2026, 10, 20)));
  });

  group('revue 8.9', () {
    Future<void> plan(DateTime start, DateTime end) => notifier().plan(
          collegeIds: const ['c1'], startDate: start, endDate: end, dailyMinutes: 30);
    Future<int> endDay() async => epochDayOf((await container.read(planningProvider.future)).config!.endDate);

    test('changement d’heure (25 oct.) : décaler prolonge bien d’un jour, annuler rétablit', () async {
      clock = DateTime(2026, 10, 23, 10);
      await plan(DateTime(2026, 9, 21), DateTime(2026, 10, 25));
      await notifier().postponeToday();
      expect(await endDay(), epochDayOf(DateTime(2026, 10, 26)));
      await notifier().cancelPostpone();
      expect(await endDay(), epochDayOf(DateTime(2026, 10, 25)));
    });

    test('changement d’heure (28 mars) : annuler ne retire qu’un jour', () async {
      clock = DateTime(2027, 3, 20, 10);
      await plan(DateTime(2027, 3, 1), DateTime(2027, 3, 28));
      await notifier().postponeToday();
      expect(await endDay(), epochDayOf(DateTime(2027, 3, 29)));
      await notifier().cancelPostpone();
      expect(await endDay(), epochDayOf(DateTime(2027, 3, 28)));
    });

    test('après minuit sans rechargement : « annuler » ne raccourcit pas, « décaler » vise le nouveau jour', () async {
      await plan(DateTime(2026, 9, 21), DateTime(2026, 10, 20));
      await notifier().postponeToday(); // mercredi
      clock = DateTime(2026, 9, 24, 8); // jeudi, état gardé en mémoire
      await notifier().cancelPostpone();
      expect(await endDay(), epochDayOf(DateTime(2026, 10, 21)), reason: 'mercredi reste décalé');
      await notifier().postponeToday();
      final s = await container.read(planningProvider.future);
      expect(s.postponedDays, {epochDayOf(today), epochDayOf(clock)});
      expect(epochDayOf(s.config!.endDate), epochDayOf(DateTime(2026, 10, 22)));
      expect(s.today, epochDayOf(clock), reason: 'l’état suit le nouveau jour');
    });

    test('refreshIfNewDay : recharge seulement si le jour a changé', () async {
      await plan(DateTime(2026, 9, 21), DateTime(2026, 10, 20));
      final before = await container.read(planningProvider.future);
      notifier().refreshIfNewDay();
      expect(identical(await container.read(planningProvider.future), before), isTrue);
      clock = DateTime(2026, 9, 24, 8);
      notifier().refreshIfNewDay();
      expect((await container.read(planningProvider.future)).today, epochDayOf(clock));
    });

    test('rien à décaler : session du jour commencée ou faite, ou hors période', () async {
      await plan(DateTime(2026, 9, 21), DateTime(2026, 10, 20));
      final daily = DailySessionRepository(db);
      await db.into(db.dailySessions).insert(DailySessionsCompanion.insert(
            day: Value(epochDayOf(today)), queueJson: '["a"]', startedAtMs: Value(today.millisecondsSinceEpoch)));
      await notifier().postponeToday();
      expect((await container.read(planningProvider.future)).postponedToday, isFalse);
      await daily.complete(epochDayOf(today));
      await notifier().postponeToday();
      expect((await container.read(planningProvider.future)).postponedToday, isFalse);

      await plan(DateTime(2026, 10, 1), DateTime(2026, 10, 20)); // commence plus tard
      await db.delete(db.dailySessions).go();
      await notifier().postponeToday();
      expect((await container.read(planningProvider.future)).postponedToday, isFalse);
    });
  });

  test('clear : plus de planning', () async {
    await planFrom21to20Oct();
    await notifier().clear();
    expect((await container.read(planningProvider.future)).config, isNull);
  });

  test('aperçu : fiches, jours, fiches par jour et faisabilité', () {
    final ok = PlanningPreview.of(cards: 341, startDate: DateTime(2026, 9, 21), endDate: DateTime(2026, 10, 20), dailyMinutes: 30);
    expect(ok.days, 30);
    expect(ok.perDay, 12);
    expect(ok.feasible, isTrue);

    final tight = PlanningPreview.of(cards: 341, startDate: DateTime(2026, 9, 21), endDate: DateTime(2026, 9, 30), dailyMinutes: 15);
    expect(tight.days, 10);
    expect(tight.perDay, 35);
    expect(tight.feasible, isFalse);
    expect(tight.minutesNeeded, 30);
  });
}

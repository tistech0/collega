import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/features/colleges/data/college_cards_sync.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/drill/data/drill_repository.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';
import 'package:collega_app/features/drill/drill_providers.dart';
import 'package:collega_app/features/today/data/daily_session_repository.dart';

FlashCardModel _card(String id, String college) => FlashCardModel(
      id: id, itemId: 'i-$id', collegeId: college, cardType: 'classique', rang: 'A',
      recto: 'Q $id', verso: 'R $id', ocrConfidenceScore: 0.9, lowConfidence: false,
    );

/// Story 8.3 — « Commencer » lance le drill sur la session du jour figée (multi-collèges).
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  final today = epochDayOf(DateTime.now());

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      drillRepositoryProvider.overrideWithValue(DrillRepository(dio: Dio(), db: db)),
    ]);
    await syncCollegeCards(db, 'c1', [_card('a', 'c1'), _card('b', 'c1')]);
    await syncCollegeCards(db, 'c2', [_card('x', 'c2')]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('charge les fiches de la session, dans son ordre, tous collèges confondus', () async {
    final session = await DailySessionRepository(db).getOrBuild(day: today, budget: 10);
    final state = await container.read(drillSessionProvider(DrillSessionParams.daily(today)).future);
    expect(state.queue.map((i) => state.cards[i].id).toList(), session.cardIds);
    expect(state.cards.map((c) => c.collegeId).toSet(), {'c1', 'c2'});
    expect(state.currentQueuePos, 0);
  });

  test('reprise : repart à la position enregistrée, réinsertions comprises', () async {
    final repo = DailySessionRepository(db);
    final session = await repo.getOrBuild(day: today, budget: 10);
    final queue = [...session.cardIds, session.cardIds.first];
    await repo.saveProgress(day: today, queue: queue, position: 2);

    final state = await container.read(drillSessionProvider(DrillSessionParams.daily(today)).future);
    expect(state.queue, hasLength(queue.length));
    expect(state.currentQueuePos, 2);
    expect(state.evaluatedCount, 2);
    expect(state.cards, hasLength(3), reason: 'fiches distinctes');
    expect(state.currentCard!.id, queue[2]);
  });

  test('session vide ou absente : drill terminé d’emblée (pas d’écran blanc)', () async {
    final state = await container.read(drillSessionProvider(DrillSessionParams.daily(today + 1)).future);
    expect(state.isComplete, isTrue);
  });

  test('params daily : égalité par jour (clé de provider stable)', () {
    expect(DrillSessionParams.daily(today), DrillSessionParams.daily(today));
    expect(DrillSessionParams.daily(today), isNot(DrillSessionParams.daily(today + 1)));
  });

  group('persistance (revue 8.3 : le drill du jour doit enregistrer)', () {
    test('chaque verdict est journalisé sur le jour de la session, la position (index de file) est enregistrée', () async {
      final repo = DailySessionRepository(db);
      final session = await repo.getOrBuild(day: today, budget: 10);
      final params = DrillSessionParams.daily(today);
      await container.read(drillSessionProvider(params).future);
      final notifier = container.read(drillSessionProvider(params).notifier);

      await notifier.evaluate(DrillEvaluationResult.maitrise);
      notifier.advanceToNext();
      await pumpEventQueue();

      final saved = await repo.find(today);
      expect(saved!.position, 1);
      expect(saved.isStarted, isTrue);
      expect(await repo.verdictCounts(today), {'maitrise': 1});
      expect(saved.cardIds, session.cardIds);
    });

    test('« à revoir » : la réinsertion est enregistrée dans la file', () async {
      final repo = DailySessionRepository(db);
      await repo.getOrBuild(day: today, budget: 10);
      final params = DrillSessionParams.daily(today);
      await container.read(drillSessionProvider(params).future);
      final notifier = container.read(drillSessionProvider(params).notifier);

      await notifier.evaluate(DrillEvaluationResult.aRevoir);
      notifier.advanceToNext();
      await pumpEventQueue();
      expect((await repo.find(today))!.cardIds, hasLength(4));
    });

    test('dernière fiche : session close automatiquement, planning du jour marqué fait', () async {
      await db.into(db.planningSessions).insert(PlanningSessionsCompanion.insert(
            id: 'p1', planningConfigId: 'cfg', sessionDateEpochDay: today, collegeId: 'c1', maxCards: 3,
          ));
      final repo = DailySessionRepository(db);
      await repo.getOrBuild(day: today, budget: 10);
      final params = DrillSessionParams.daily(today);
      await container.read(drillSessionProvider(params).future);
      final notifier = container.read(drillSessionProvider(params).notifier);
      for (var i = 0; i < 3; i++) {
        await notifier.evaluate(DrillEvaluationResult.bien);
        notifier.advanceToNext();
      }
      await pumpEventQueue();
      expect((await repo.find(today))!.isCompleted, isTrue);
      final planned = await (db.select(db.planningSessions)..where((t) => t.id.equals('p1'))).getSingle();
      expect(planned.status, 'completed');
    });

    test('reprise : une fiche déjà réinsérée ne l’est pas une seconde fois', () async {
      final repo = DailySessionRepository(db);
      final s = await repo.getOrBuild(day: today, budget: 10);
      final first = s.cardIds.first;
      await repo.saveProgress(day: today, queue: [first, s.cardIds[1], first, s.cardIds[2]], position: 2);
      final params = DrillSessionParams.daily(today);
      final state = await container.read(drillSessionProvider(params).future);
      expect(state.currentCard!.id, first);
      final requeued = await container.read(drillSessionProvider(params).notifier).evaluate(DrillEvaluationResult.aRevoir);
      expect(requeued, isFalse);
    });
  });
}

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/features/colleges/data/college_cards_sync.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/today/data/daily_session_repository.dart';
import 'package:collega_app/features/today/domain/daily_session_builder.dart';

FlashCardModel _server(String id, {String college = 'c1', String rang = 'A', String recto = 'Q'}) => FlashCardModel(
      id: id, itemId: 'i-$id', collegeId: college, cardType: 'classique', rang: rang,
      recto: recto, verso: 'R', ocrConfidenceScore: 0.9, lowConfidence: false,
    );

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 9, 22, 20);
  final today = epochDayOf(now);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('syncCollegeCards — toutes les fiches, sans écraser l’état de révision local', () {
    test('insère, met à jour le contenu, conserve drillLevel / nextReviewAt / reviewCount / pouce', () async {
      await syncCollegeCards(db, 'c1', [_server('a'), _server('b')]);
      await (db.update(db.flashCards)..where((t) => t.id.equals('a'))).write(const FlashCardsCompanion(
        drillLevel: Value('maitrise'), nextReviewAt: Value(123), reviewCount: Value(4), userFeedback: Value('positive'),
      ));

      await syncCollegeCards(db, 'c1', [_server('a', recto: 'Q modifiée'), _server('b')]);

      final a = await (db.select(db.flashCards)..where((t) => t.id.equals('a'))).getSingle();
      expect(a.recto, 'Q modifiée');
      expect(a.drillLevel, 'maitrise');
      expect(a.nextReviewAt, 123);
      expect(a.reviewCount, 4);
      expect(a.userFeedback, 'positive', reason: 'le serveur renvoie null si le pouce n’a pas encore été synchronisé');
    });

    test('liste vide : rien n’est effacé (réponse anormale ≠ collège sans fiches) — revue 8.3', () async {
      await syncCollegeCards(db, 'c1', [_server('a'), _server('b')]);
      await syncCollegeCards(db, 'c1', const []);
      expect(await db.select(db.flashCards).get(), hasLength(2));
    });

    test('supprime les fiches du collège que le serveur n’a plus (fiche supprimée, régénérée)', () async {
      await syncCollegeCards(db, 'c1', [_server('a'), _server('b')]);
      await syncCollegeCards(db, 'c2', [_server('z', college: 'c2')]);
      await syncCollegeCards(db, 'c1', [_server('a')]);
      final ids = (await db.select(db.flashCards).get()).map((c) => c.id).toSet();
      expect(ids, {'a', 'z'});
    });
  });

  group('DailySessionRepository', () {
    late DailySessionRepository repo;
    setUp(() => repo = DailySessionRepository(db, clock: () => now));

    Future<void> seed(int n, {String college = 'c1'}) =>
        syncCollegeCards(db, college, [for (var i = 0; i < n; i++) _server('$college-$i', college: college)]);

    test('FIGÉE dès qu’elle est commencée : les fiches synchronisées ensuite n’y entrent pas', () async {
      await seed(30);
      final first = await repo.getOrBuild(day: today, budget: 24);
      expect(first.cardIds, hasLength(24));
      await repo.saveProgress(day: today, queue: first.cardIds, position: 1);
      await seed(30, college: 'c2');
      final again = await repo.getOrBuild(day: today, budget: 24);
      expect(again.cardIds, first.cardIds);
    });

    test('pas encore commencée : recalculée avec les fiches arrivées depuis (revue 8.3)', () async {
      final empty = await repo.getOrBuild(day: today, budget: 24);
      expect(empty.cardIds, isEmpty);
      expect(await repo.find(today), isNull, reason: 'une session vide n’est jamais figée');
      await seed(3);
      final filled = await repo.getOrBuild(day: today, budget: 24);
      expect(filled.cardIds, hasLength(3));
    });

    test('personnalisée puis non commencée : recalculée avec SES réglages', () async {
      await seed(10);
      await seed(10, college: 'c2');
      await repo.rebuild(day: today, budget: 4, collegeIds: {'c2'});
      await seed(10, college: 'c3');
      final again = await repo.getOrBuild(day: today, budget: 24);
      expect(again.cardIds, hasLength(4));
      expect(again.cardIds.every((id) => id.startsWith('c2-')), isTrue);
      expect(again.settings?.collegeIds, {'c2'});
      expect(again.settings?.budget, 4);
    });

    test('personnaliser reconstruit tant que la session n’est pas commencée', () async {
      await seed(10);
      await seed(10, college: 'c2');
      await repo.getOrBuild(day: today, budget: 24);
      final custom = await repo.rebuild(day: today, budget: 5, collegeIds: {'c2'});
      expect(custom.cardIds, hasLength(5));
      expect(custom.cardIds.every((id) => id.startsWith('c2-')), isTrue);
    });

    test('personnaliser refusé une fois la session commencée', () async {
      await seed(10);
      final s = await repo.getOrBuild(day: today, budget: 5);
      await repo.saveProgress(day: today, queue: s.cardIds, position: 1);
      expect(() => repo.rebuild(day: today, budget: 3), throwsStateError);
    });

    test('progression, reprise et clôture', () async {
      await seed(3);
      final s = await repo.getOrBuild(day: today, budget: 3);
      await repo.saveProgress(day: today, queue: [...s.cardIds, s.cardIds.first], position: 2);
      final resumed = await repo.find(today);
      expect(resumed!.position, 2);
      expect(resumed.cardIds, hasLength(4), reason: 'la file garde la réinsertion « à revoir »');
      expect(resumed.isStarted, isTrue);
      expect(resumed.isCompleted, isFalse);

      await repo.complete(today);
      expect((await repo.find(today))!.isCompleted, isTrue);
    });

    test('journal des verdicts et jours faits de la semaine', () async {
      await repo.recordVerdict(day: today, cardId: 'x', collegeId: 'c1', rang: 'A', drillLevel: 'maitrise');
      await repo.recordVerdict(day: today, cardId: 'y', collegeId: 'c1', rang: 'B', drillLevel: 'a_revoir');
      // Verdict d'une session commencée la veille et finie après minuit : compté sur la veille.
      await repo.recordVerdict(day: today - 1, cardId: 'z', collegeId: 'c1', rang: 'A', drillLevel: 'bien');
      final counts = await repo.verdictCounts(today);
      expect(counts, {'maitrise': 1, 'a_revoir': 1});

      await seed(1);
      await repo.getOrBuild(day: today, budget: 1);
      await repo.complete(today);
      expect(await repo.completedDays(from: today - 6, to: today), {today});
    });

    test('resetDay (outil de test) : la session du jour et son bilan repartent de zéro', () async {
      await seed(2);
      await repo.getOrBuild(day: today, budget: 2);
      await repo.recordVerdict(day: today, cardId: 'x', collegeId: 'c1', rang: 'A', drillLevel: 'maitrise');
      await repo.recordVerdict(
          day: today, cardId: 'y', collegeId: 'c1', rang: 'A', drillLevel: 'bien', daily: false);
      await repo.complete(today);
      await repo.resetDay(today);
      expect(await repo.find(today), isNull);
      expect(await repo.verdictCounts(today), isEmpty);
      expect(await repo.completedDays(from: today, to: today), isEmpty);
      expect((await repo.weekCounts(from: today, to: today))[today], 1, reason: 'les autres révisions restent');
    });

    test('journal hors session du jour (8.8) : compté dans la semaine, pas dans le bilan du jour', () async {
      await repo.recordVerdict(day: today, cardId: 'x', collegeId: 'c1', rang: 'A', drillLevel: 'maitrise');
      await repo.recordVerdict(
          day: today, cardId: 'y', collegeId: 'c1', rang: 'A', drillLevel: 'bien', daily: false);
      await repo.recordVerdict(
          day: today - 2, cardId: 'z', collegeId: 'c1', rang: 'B', drillLevel: 'a_revoir', daily: false);
      expect(await repo.verdictCounts(today), {'maitrise': 1});
      expect(await repo.lastVerdicts(today), {'x': 'maitrise'});
      expect(await repo.weekCounts(from: today - 6, to: today), {today: 2, today - 2: 1});
      // La même fiche revue une 2e fois le même jour compte une fois.
      await repo.recordVerdict(
          day: today, cardId: 'y', collegeId: 'c1', rang: 'A', drillLevel: 'maitrise', daily: false);
      expect((await repo.weekCounts(from: today, to: today))[today], 2);
    });


    test('aperçu : compte sans enregistrer', () async {
      await seed(10);
      await seed(5, college: 'c2');
      expect(await repo.preview(budget: 24), 15);
      expect(await repo.preview(budget: 24, collegeIds: {'c2'}), 5);
      expect(await repo.preview(budget: 3), 3);
      expect(await repo.find(today), isNull);
    });

    test('session vide si aucune fiche locale', () async {
      final s = await repo.getOrBuild(day: today, budget: 24);
      expect(s.cardIds, isEmpty);
    });

    test('statut « non vues » transmis au moteur (plus de compteur ≠ contenu)', () async {
      await seed(3);
      await (db.update(db.flashCards)..where((t) => t.id.equals('c1-0'))).write(
        const FlashCardsCompanion(drillLevel: Value('a_revoir')),
      );
      final s = await repo.rebuild(day: today, budget: 10, status: SessionStatusFilter.unseen);
      expect(s.cardIds, ['c1-1', 'c1-2']);
    });
  });

  test('epochDayOf : jour civil local, identique au planning', () {
    expect(epochDayOf(DateTime(1970, 1, 2, 23, 59)), 1);
    expect(epochDayOf(DateTime(2026, 9, 22, 0, 1)), epochDayOf(DateTime(2026, 9, 22, 23, 59)));
  });
  group('jours « rien à réviser » (série de l’Accueil)', () {
    test('session du jour vide : le jour est noté calme', () async {
      final repo = DailySessionRepository(db, clock: () => now);
      await repo.getOrBuild(day: today, budget: 24);
      expect(await repo.quietDays(from: today, to: today), {today});
    });

    test('Personnaliser sans aucune fiche : ce n’est pas un jour calme', () async {
      await syncCollegeCards(db, 'c1', [_server('a')]);
      final repo = DailySessionRepository(db, clock: () => now);
      await repo.rebuild(day: today, budget: 24, rangs: {'C'});
      expect(await repo.quietDays(from: today, to: today), isEmpty);
    });

    test('session avec des fiches : pas de jour calme', () async {
      await syncCollegeCards(db, 'c1', [_server('a')]);
      final repo = DailySessionRepository(db, clock: () => now);
      await repo.getOrBuild(day: today, budget: 24);
      expect(await repo.quietDays(from: today, to: today), isEmpty);
    });

    test('resetDay (outil de test) oublie aussi le jour calme', () async {
      final repo = DailySessionRepository(db, clock: () => now);
      await repo.getOrBuild(day: today, budget: 24);
      await repo.resetDay(today);
      expect(await repo.quietDays(from: today, to: today), isEmpty);
    });
  });
}

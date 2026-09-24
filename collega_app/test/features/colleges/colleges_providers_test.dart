import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/data/colleges_repository.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/planning/data/planning_repository.dart';

class _FakeCollegesRepository extends CollegesRepository {
  _FakeCollegesRepository({List<UserCollegeStatus>? result, this.offline = false})
      : _result = result ?? [],
        super(dio: Dio());

  final List<UserCollegeStatus> _result;
  bool offline;
  bool serverError = false;

  @override
  Future<List<UserCollegeStatus>> getUserColleges() async {
    if (offline) {
      throw DioException(
        requestOptions: RequestOptions(path: '/v1/colleges'),
        type: DioExceptionType.connectionError,
      );
    }
    if (serverError) {
      throw DioException(
        requestOptions: RequestOptions(path: '/v1/colleges'),
        type: DioExceptionType.badResponse,
      );
    }
    return _result;
  }
}

ProviderContainer _makeContainer(_FakeCollegesRepository repo, {AppDatabase? db}) {
  final database = db ?? AppDatabase.forTesting(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      collegesRepositoryProvider.overrideWithValue(repo),
      databaseProvider.overrideWithValue(database),
    ],
  );
  if (db == null) addTearDown(database.close);
  return container;
}

void main() {
  group('CollegesNotifier', () {
    test('état initial sans imports → 39 entrées, toutes non-importées', () async {
      final container = _makeContainer(_FakeCollegesRepository());
      addTearDown(container.dispose);

      final entries = await container.read(collegesProvider.future);
      expect(entries.length, 39);
      expect(entries.every((e) => !e.isImported), isTrue);
    });

    test('avec 1 college importé → cette entrée est marquée importée', () async {
      final imported = UserCollegeStatus(
        refId: 26,
        collegeId: 'college-uuid-26',
        status: 'generation_complete',
        cardCountA: 5,
        cardCountB: 3,
        cardCountC: 2,
      );
      final container = _makeContainer(_FakeCollegesRepository(result: [imported]));
      addTearDown(container.dispose);

      final entries = await container.read(collegesProvider.future);
      expect(entries.length, 39);

      final neurologie = entries.firstWhere((e) => e.catalog.refId == 26);
      expect(neurologie.isImported, isTrue);
      expect(neurologie.userStatus!.cardCountA, 5);
      expect(neurologie.userStatus!.totalCards, 10);
    });

    test('catalogue respecte l\'ordre et contient les 39 colleges prédéfinis', () async {
      final container = _makeContainer(_FakeCollegesRepository());
      addTearDown(container.dispose);

      final entries = await container.read(collegesProvider.future);
      expect(entries.map((e) => e.catalog.refId).toList(), List.generate(39, (i) => i + 1));
      expect(entries.first.catalog.name, kCollegeCatalog.first.name);
    });
  });

  group('hors-ligne (story 8.3) — la liste vient du cache local', () {
    const imported = UserCollegeStatus(
      refId: 3, collegeId: 'c-3', status: 'generation_complete', cardCountA: 5, cardCountB: 3, cardCountC: 2,
    );

    test('après un succès, un échec réseau renvoie les collèges connus', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = _FakeCollegesRepository(result: [imported]);
      final online = _makeContainer(repo, db: db);
      await online.read(collegesProvider.future);
      online.dispose();

      repo.offline = true;
      final offline = _makeContainer(repo, db: db);
      addTearDown(offline.dispose);
      final entries = await offline.read(collegesProvider.future);
      final cancero = entries.firstWhere((e) => e.catalog.refId == 3);
      expect(cancero.isGenerationComplete, isTrue);
      expect(cancero.userStatus!.totalCards, 10);
      expect(offline.read(collegesProvider.notifier).isOffline, isTrue,
          reason: 'la Bibliothèque affiche « Hors connexion »');
    });

    test('erreur serveur (500) : cache servi mais pas « hors connexion »', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = _FakeCollegesRepository(result: [imported]);
      final online = _makeContainer(repo, db: db);
      await online.read(collegesProvider.future);
      online.dispose();
      repo.serverError = true;
      final c = _makeContainer(repo, db: db);
      addTearDown(c.dispose);
      final entries = await c.read(collegesProvider.future);
      expect(entries.firstWhere((e) => e.catalog.refId == 3).isImported, isTrue);
      expect(c.read(collegesProvider.notifier).isOffline, isFalse);
    });

    test('liste fraîche du serveur → pas hors-ligne', () async {
      final container = _makeContainer(_FakeCollegesRepository(result: [imported]));
      addTearDown(container.dispose);
      await container.read(collegesProvider.future);
      expect(container.read(collegesProvider.notifier).isOffline, isFalse);
    });

    test('sans cache, l’échec réseau remonte (l’écran affiche son état d’erreur)', () async {
      final container = _makeContainer(_FakeCollegesRepository(offline: true));
      addTearDown(container.dispose);
      await expectLater(container.read(collegesProvider.future), throwsA(isA<DioException>()));
    });

    test('un nouveau succès remplace le cache (collège supprimé côté serveur)', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final first = _makeContainer(_FakeCollegesRepository(result: [imported]), db: db);
      await first.read(collegesProvider.future);
      first.dispose();
      final second = _makeContainer(_FakeCollegesRepository(result: const []), db: db);
      await second.read(collegesProvider.future);
      second.dispose();
      expect(await db.select(db.userColleges).get(), isEmpty);
    });
  });
  group('purge des collèges disparus du serveur (revue finale chantier 4, I1)', () {
    const alive = UserCollegeStatus(
      refId: 3, collegeId: 'c-3', status: 'generation_complete', cardCountA: 1, cardCountB: 0, cardCountC: 0,
    );

    Future<void> seed(AppDatabase db) async {
      for (final college in ['c-3', 'c-dead']) {
        await db.into(db.items).insert(ItemsCompanion.insert(
              id: 'item-$college', collegeId: college, itemNumber: 1, rang: 'A',
            ));
        await db.into(db.flashCards).insert(FlashCardsCompanion.insert(
              id: 'card-$college', itemId: 'item-$college', collegeId: college,
              cardType: 'classique', rang: 'A', recto: 'Q', verso: 'R',
            ));
        await db.into(db.collegeImports).insert(CollegeImportsCompanion.insert(
              id: college, refId: 3, jobId: 'job-$college', status: 'generation_complete',
              updatedAt: DateTime.utc(2026, 9, 1),
            ));
      }
      // « Décaler aujourd'hui » : seule écriture de planningSessions en prod
      // (collegeId vide) — pas une donnée de collège, jamais purgée.
      await PlanningRepository(db: db).addPostponed('cfg', 100);
      // Session du jour commencée qui mélange les deux collèges, session vivante
      // seule, et session terminée (historique de la semaine) avec une fiche morte.
      await db.into(db.dailySessions).insert(DailySessionsCompanion.insert(
            day: const Value(100), queueJson: jsonEncode(['card-c-3', 'card-c-dead']),
            startedAtMs: const Value(1),
          ));
      await db.into(db.dailySessions).insert(DailySessionsCompanion.insert(
            day: const Value(99), queueJson: jsonEncode(['card-c-3']),
          ));
      await db.into(db.dailySessions).insert(DailySessionsCompanion.insert(
            day: const Value(98), queueJson: jsonEncode(['card-c-dead']),
            startedAtMs: const Value(1), completedAtMs: const Value(2),
          ));
      await db.into(db.reviewLog).insert(ReviewLogCompanion.insert(
            cardId: 'card-c-dead', collegeId: 'c-dead', rang: 'A', drillLevel: 'bien', reviewedAtMs: 1, day: 98,
          ));
    }

    test('succès réseau : les lignes locales des collèges absents sont supprimées', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await seed(db);

      final container = _makeContainer(_FakeCollegesRepository(result: [alive]), db: db);
      addTearDown(container.dispose);
      await container.read(collegesProvider.future);

      expect((await db.select(db.flashCards).get()).map((r) => r.id), ['card-c-3']);
      expect((await db.select(db.items).get()).map((r) => r.id), ['item-c-3']);
      expect(await PlanningRepository(db: db).postponedDays('cfg'), {100},
          reason: 'un jour décalé survit à un chargement réussi');
      expect((await db.select(db.collegeImports).get()).map((r) => r.id), ['c-3']);
      // Session non terminée qui citait une fiche morte : oubliée (recalculée) ;
      // les autres restent (la session terminée compte dans la semaine).
      expect((await db.select(db.dailySessions).get()).map((r) => r.day).toSet(), {99, 98});
      // Journal des révisions : historique réel, gardé (Progression).
      expect(await db.select(db.reviewLog).get(), hasLength(1));
    });

    test('liste vide du serveur (vidage de la prod) : tout le contenu local part', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await seed(db);

      final container = _makeContainer(_FakeCollegesRepository(result: const []), db: db);
      addTearDown(container.dispose);
      await container.read(collegesProvider.future);

      expect(await db.select(db.flashCards).get(), isEmpty);
      expect(await db.select(db.items).get(), isEmpty);
      expect((await db.select(db.dailySessions).get()).map((r) => r.day).toSet(), {98});
      expect(await PlanningRepository(db: db).postponedDays('cfg'), {100});
    });

    test('file de session du jour illisible : ignorée, la purge aboutit', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await seed(db);
      await db.into(db.dailySessions).insert(DailySessionsCompanion.insert(
            day: const Value(101), queueJson: 'pas du json',
          ));
      await db.into(db.dailySessions).insert(DailySessionsCompanion.insert(
            day: const Value(102), queueJson: jsonEncode({'pas': 'une liste'}),
          ));

      final container = _makeContainer(_FakeCollegesRepository(result: [alive]), db: db);
      addTearDown(container.dispose);
      await container.read(collegesProvider.future);

      expect((await db.select(db.flashCards).get()).map((r) => r.id), ['card-c-3']);
      expect((await db.select(db.dailySessions).get()).map((r) => r.day).toSet(), {98, 99, 101, 102});
    });

    for (final failure in ['offline', 'serverError']) {
      test('échec du chargement ($failure) : rien n’est supprimé', () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await seed(db);
        // Cache des collèges présent : l'échec est servi depuis le cache, sans purge.
        await db.into(db.userColleges).insert(UserCollegesCompanion.insert(
              refId: const Value(3), collegeId: 'c-3', status: 'generation_complete',
              cardCountA: 1, cardCountB: 0, cardCountC: 0,
            ));
        final repo = _FakeCollegesRepository(result: [alive]);
        if (failure == 'offline') repo.offline = true;
        if (failure == 'serverError') repo.serverError = true;

        final container = _makeContainer(repo, db: db);
        addTearDown(container.dispose);
        await container.read(collegesProvider.future);

        expect(await db.select(db.flashCards).get(), hasLength(2));
        expect(await db.select(db.items).get(), hasLength(2));
        expect(await db.select(db.planningSessions).get(), hasLength(1));
        expect(await db.select(db.collegeImports).get(), hasLength(2));
        expect(await db.select(db.dailySessions).get(), hasLength(3));
      });
    }
  });
}

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/data/colleges_repository.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';

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
}

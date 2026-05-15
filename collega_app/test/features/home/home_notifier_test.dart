import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/data/colleges_repository.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/home/domain/home_session_config.dart';
import 'package:collega_app/features/home/home_providers.dart';

AppDatabase _makeDb() => AppDatabase.forTesting(NativeDatabase.memory());

CollegeListEntry _entry({
  required int refId,
  String? collegeId,
  String? status,
}) {
  final catalog = kCollegeCatalog.firstWhere((e) => e.refId == refId);
  return CollegeListEntry(
    catalog: catalog,
    userStatus: collegeId == null
        ? null
        : UserCollegeStatus(
            refId: refId,
            collegeId: collegeId,
            status: status ?? 'generation_complete',
            cardCountA: 0,
            cardCountB: 0,
            cardCountC: 0,
          ),
  );
}

class _FakeCollegesRepository extends CollegesRepository {
  _FakeCollegesRepository(this._result) : super(dio: Dio());
  final List<UserCollegeStatus> _result;

  @override
  Future<List<UserCollegeStatus>> getUserColleges() async => _result;
}

ProviderContainer _makeContainer(
  List<CollegeListEntry> colleges, {
  AppDatabase? db,
}) {
  final database = db ?? _makeDb();
  final importedStatuses =
      colleges.where((e) => e.userStatus != null).map((e) => e.userStatus!).toList();
  return ProviderContainer(
    overrides: [
      collegesRepositoryProvider.overrideWithValue(
        _FakeCollegesRepository(importedStatuses),
      ),
      databaseProvider.overrideWithValue(database),
    ],
  );
}

void main() {
  group('HomeNotifier', () {
    test('HomeEmpty si aucun collège importé', () async {
      final container = _makeContainer([
        _entry(refId: 1),
        _entry(refId: 2),
      ]);
      addTearDown(container.dispose);

      final state = await container.read(homeProvider.future);
      expect(state, isA<HomeEmpty>());
    });

    test('HomeOcrInProgress si collège importé mais pas generation_complete', () async {
      final container = _makeContainer([
        _entry(refId: 1, collegeId: 'c1', status: 'processing'),
      ]);
      addTearDown(container.dispose);

      final state = await container.read(homeProvider.future);
      expect(state, isA<HomeOcrInProgress>());
      expect((state as HomeOcrInProgress).collegeName, isNotEmpty);
    });

    test('HomeReady avec 2 colleges récents si 2+ en generation_complete', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final container = _makeContainer(
        [
          _entry(refId: 1, collegeId: 'c1'),
          _entry(refId: 2, collegeId: 'c2'),
          _entry(refId: 3, collegeId: 'c3'),
        ],
        db: db,
      );
      addTearDown(container.dispose);

      final state = await container.read(homeProvider.future);
      expect(state, isA<HomeReady>());
      final ready = state as HomeReady;
      expect(ready.recentColleges.length, 2);
      expect(ready.recentColleges[0].userStatus!.collegeId, 'c1');
      expect(ready.recentColleges[1].userStatus!.collegeId, 'c2');
    });

    test('HomeReady avec 1 college récent si 1 en generation_complete', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final container = _makeContainer(
        [_entry(refId: 1, collegeId: 'c1')],
        db: db,
      );
      addTearDown(container.dispose);

      final state = await container.read(homeProvider.future);
      expect(state, isA<HomeReady>());
      final ready = state as HomeReady;
      expect(ready.recentColleges.length, 1);
    });
  });

  group('HomeSessionConfigNotifier', () {
    test('applyDefault ne remplace pas la config si déjà customisée', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(homeSessionConfigProvider.notifier);
      const initial = HomeSessionConfig(collegeId: 'c1', collegeName: 'Cardio');
      notifier.setConfig(initial);

      const other = HomeSessionConfig(collegeId: 'c2', collegeName: 'Dermato');
      notifier.applyDefault(other);

      expect(container.read(homeSessionConfigProvider)!.collegeId, 'c1');
    });

    test('setConfig remplace toujours la config existante', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(homeSessionConfigProvider.notifier);
      notifier.setConfig(const HomeSessionConfig(collegeId: 'c1', collegeName: 'Cardio'));
      notifier.setConfig(const HomeSessionConfig(collegeId: 'c2', collegeName: 'Dermato'));

      expect(container.read(homeSessionConfigProvider)!.collegeId, 'c2');
    });

    test('état initial est null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(homeSessionConfigProvider), isNull);
    });
  });
}

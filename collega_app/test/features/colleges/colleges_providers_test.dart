import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/data/colleges_repository.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';

class _FakeCollegesRepository extends CollegesRepository {
  _FakeCollegesRepository({List<UserCollegeStatus>? result})
      : _result = result ?? [],
        super(dio: Dio());

  final List<UserCollegeStatus> _result;

  @override
  Future<List<UserCollegeStatus>> getUserColleges() async => _result;
}

ProviderContainer _makeContainer(_FakeCollegesRepository repo) {
  return ProviderContainer(
    overrides: [collegesRepositoryProvider.overrideWithValue(repo)],
  );
}

void main() {
  group('CollegesNotifier', () {
    test('état initial sans imports → 40 entrées, toutes non-importées', () async {
      final container = _makeContainer(_FakeCollegesRepository());
      addTearDown(container.dispose);

      final entries = await container.read(collegesProvider.future);
      expect(entries.length, 40);
      expect(entries.every((e) => !e.isImported), isTrue);
    });

    test('avec 1 college importé → cette entrée est marquée importée', () async {
      final imported = UserCollegeStatus(
        refId: 15,
        collegeId: 'college-uuid-15',
        status: 'generation_complete',
        cardCountA: 5,
        cardCountB: 3,
        cardCountC: 2,
      );
      final container = _makeContainer(_FakeCollegesRepository(result: [imported]));
      addTearDown(container.dispose);

      final entries = await container.read(collegesProvider.future);
      expect(entries.length, 40);

      final neurologie = entries.firstWhere((e) => e.catalog.refId == 15);
      expect(neurologie.isImported, isTrue);
      expect(neurologie.userStatus!.cardCountA, 5);
      expect(neurologie.userStatus!.totalCards, 10);
    });

    test('catalogue respecte l\'ordre et contient les 40 colleges prédéfinis', () async {
      final container = _makeContainer(_FakeCollegesRepository());
      addTearDown(container.dispose);

      final entries = await container.read(collegesProvider.future);
      expect(entries.map((e) => e.catalog.refId).toList(), List.generate(40, (i) => i + 1));
      expect(entries.first.catalog.name, kCollegeCatalog.first.name);
    });
  });
}

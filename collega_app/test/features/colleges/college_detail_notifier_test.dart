import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/features/colleges/colleges_detail_providers.dart';
import 'package:collega_app/features/colleges/data/college_detail_repository.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';

class _FakeCollegeDetailRepository extends CollegeDetailRepository {
  _FakeCollegeDetailRepository({
    this.itemsResult,
    this.throwOnGetItems,
    this.driftItems,
  }) : super(dio: Dio(), db: AppDatabase.forTesting(NativeDatabase.memory()));

  final List<ItemModel>? itemsResult;
  final Exception? throwOnGetItems;
  final List<ItemModel>? driftItems;

  @override
  Future<List<ItemModel>> getItems(String collegeId) async {
    if (throwOnGetItems != null) throw throwOnGetItems!;
    return itemsResult ?? [];
  }

  @override
  Future<List<ItemModel>> getItemsFromDrift(String collegeId) async {
    return driftItems ?? [];
  }

  @override
  Future<void> syncItemsToDrift(
      String collegeId, List<ItemModel> items) async {}
}

AppDatabase _makeInMemoryDb() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

ProviderContainer _makeContainer(_FakeCollegeDetailRepository repo) {
  return ProviderContainer(
    overrides: [
      collegeDetailRepositoryProvider.overrideWithValue(repo),
      secureStorageProvider.overrideWithValue(const FlutterSecureStorage()),
      databaseProvider.overrideWithValue(_makeInMemoryDb()),
    ],
  );
}

const _testItem = ItemModel(
  id: 'item-1',
  collegeId: 'college-1',
  itemNumber: 232,
  rang: 'A',
  chapterTitle: 'Insuffisance Cardiaque',
  ocrConfidenceScore: 0.9,
  lowConfidence: false,
  cardCountA: 3,
  cardCountB: 2,
  cardCountC: 0,
);

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  group('CollegeDetailNotifier', () {
    test('getItems succès → state passe à CollegeDetailLoaded avec items corrects',
        () async {
      final repo = _FakeCollegeDetailRepository(itemsResult: [_testItem]);
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final result = await container
          .read(collegeDetailProvider('college-1').future);

      expect(result, isA<CollegeDetailLoaded>());
      final loaded = result as CollegeDetailLoaded;
      expect(loaded.items.length, 1);
      expect(loaded.items.first.itemNumber, 232);
      expect(loaded.items.first.rang, 'A');
    });

    test('filterByRang("A") → state.selectedRang == "A"', () async {
      final repo = _FakeCollegeDetailRepository(itemsResult: [_testItem]);
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(collegeDetailProvider('college-1').future);
      container
          .read(collegeDetailProvider('college-1').notifier)
          .filterByRang('A');

      final state =
          container.read(collegeDetailProvider('college-1')).valueOrNull;
      expect(state, isA<CollegeDetailLoaded>());
      final loaded = state as CollegeDetailLoaded;
      expect(loaded.selectedRang, 'A');
    });

    test('DioException → fallback Drift → state loaded depuis Drift', () async {
      final driftItem = const ItemModel(
        id: 'item-drift-1',
        collegeId: 'college-1',
        itemNumber: 100,
        rang: 'B',
        chapterTitle: 'Pneumologie',
        ocrConfidenceScore: 0.8,
        lowConfidence: false,
        cardCountA: 0,
        cardCountB: 5,
        cardCountC: 0,
      );
      final repo = _FakeCollegeDetailRepository(
        throwOnGetItems: DioException(
          requestOptions: RequestOptions(path: '/v1/colleges/college-1/items'),
        ),
        driftItems: [driftItem],
      );
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final result = await container
          .read(collegeDetailProvider('college-1').future);

      expect(result, isA<CollegeDetailLoaded>());
      final loaded = result as CollegeDetailLoaded;
      expect(loaded.items.length, 1);
      expect(loaded.items.first.id, 'item-drift-1');
    });
  });
}

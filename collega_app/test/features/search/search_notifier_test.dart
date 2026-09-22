import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/search/data/search_repository.dart';
import 'package:collega_app/features/search/domain/search_result.dart';
import 'package:collega_app/features/search/search_providers.dart';

class _FakeSearchRepository extends SearchRepository {
  _FakeSearchRepository({
    this.results = const [],
    this.throwOffline = false,
  }) : super(Dio());

  final List<SearchResult> results;
  final bool throwOffline;

  @override
  Future<List<SearchResult>> search(String query) async {
    if (throwOffline) {
      throw DioException(
        requestOptions: RequestOptions(path: '/v1/search'),
        type: DioExceptionType.connectionError,
      );
    }
    return results;
  }
}

ProviderContainer _makeContainer(SearchRepository repo) {
  return ProviderContainer(
    overrides: [
      searchRepositoryProvider.overrideWithValue(repo),
    ],
  );
}

void main() {
  group('SearchNotifier', () {
    test("onQueryChanged('') reset l'état", () async {
      final container = _makeContainer(_FakeSearchRepository());
      addTearDown(container.dispose);

      final notifier = container.read(searchNotifierProvider.notifier);
      notifier.onQueryChanged('');

      final state = container.read(searchNotifierProvider);
      expect(state.query, '');
      expect(state.isLoading, isFalse);
      expect(state.results, isEmpty);
    });

    test("onQueryChanged('BNP') → requête enregistrée, pas de chargement pendant le debounce", () {
      final container = _makeContainer(_FakeSearchRepository());
      addTearDown(container.dispose);

      container.read(searchNotifierProvider.notifier).onQueryChanged('BNP');
      final state = container.read(searchNotifierProvider);
      // isLoading ne passe à true qu'au lancement de la requête (après 400 ms),
      // pour garder les résultats précédents affichés pendant la frappe.
      expect(state.isLoading, isFalse);
      expect(state.query, 'BNP');
    });

    test('après repo retournant résultats → results non vide', () async {
      final result = SearchResult(
        itemId: 'id-1',
        itemNumber: 232,
        rang: 'A',
        chapterTitle: 'IC',
        collegeId: 'c',
        collegeRefId: 1,
        excerpt: '<mark>BNP</mark>',
      );
      final container = _makeContainer(
        _FakeSearchRepository(results: [result]),
      );
      addTearDown(container.dispose);

      container.read(searchNotifierProvider.notifier).onQueryChanged('BNP');
      // Attendre le debounce (400ms) + l'appel réseau
      await Future.delayed(const Duration(milliseconds: 600));

      final state = container.read(searchNotifierProvider);
      expect(state.results, isNotEmpty);
      expect(state.results.first.itemId, 'id-1');
      expect(state.isLoading, isFalse);
    });

    test('après DioException connectionError → isOffline=true', () async {
      final container = _makeContainer(
        _FakeSearchRepository(throwOffline: true),
      );
      addTearDown(container.dispose);

      container.read(searchNotifierProvider.notifier).onQueryChanged('BNP');
      await Future.delayed(const Duration(milliseconds: 600));

      final state = container.read(searchNotifierProvider);
      expect(state.isOffline, isTrue);
      expect(state.isLoading, isFalse);
    });
  });
}

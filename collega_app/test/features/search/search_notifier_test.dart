import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/search/data/search_repository.dart';
import 'package:collega_app/features/search/domain/search_result.dart';
import 'package:collega_app/features/search/search_providers.dart';

const _result = SearchResult(
  itemId: 'id-1', itemNumber: 232, rang: 'A', chapterTitle: 'IC',
  collegeId: 'c', collegeRefId: 1, excerpt: '<mark>BNP</mark> élevé.',
);

class _FakeSearchRepository extends SearchRepository {
  _FakeSearchRepository() : super(Dio());

  List<SearchResult> results = const [_result];
  Object? error;
  final queries = <String>[];

  @override
  Future<List<SearchResult>> search(String query) async {
    queries.add(query);
    if (error != null) throw error!;
    return results;
  }
}

class _MemoryRecents implements SearchRecentsStore {
  List<String> saved = [];
  bool failWrites = false;
  @override
  Future<List<String>> read() async => saved;
  @override
  Future<void> write(List<String> recents) async {
    await Future<void>.delayed(Duration.zero);
    if (failWrites) throw StateError('trousseau');
    saved = List.of(recents);
  }
  @override
  Future<void> clearAll() async => saved = [];
}

DioException _dio(DioExceptionType type) =>
    DioException(requestOptions: RequestOptions(path: '/v1/search'), type: type);

void main() {
  late _FakeSearchRepository repo;
  late _MemoryRecents recents;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeSearchRepository();
    recents = _MemoryRecents();
    container = ProviderContainer(overrides: [
      searchRepositoryProvider.overrideWithValue(repo),
      searchRecentsStoreProvider.overrideWithValue(recents),
    ]);
  });
  tearDown(() => container.dispose());

  SearchNotifier notifier() => container.read(searchNotifierProvider.notifier);
  SearchState state() => container.read(searchNotifierProvider);
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 380));

  group('SearchNotifier', () {
    test('vide : état initial', () {
      notifier().onQueryChanged('');
      expect(state().query, '');
      expect(state().results, isEmpty);
    });

    test('1 caractère : aucune requête (résultats dès 2)', () async {
      notifier().onQueryChanged('B');
      await settle();
      expect(repo.queries, isEmpty);
      expect(state().isTooShort, isTrue);
    });

    test('300 ms de délai puis résultats ; frappe rapide = une seule requête', () async {
      notifier().onQueryChanged('BN');
      notifier().onQueryChanged('BNP');
      expect(repo.queries, isEmpty, reason: 'rien avant la fin du délai');
      expect(state().isPending, isTrue);
      expect(state().isEmpty, isFalse, reason: 'jamais « aucun résultat » pendant le délai (revue 8.10)');
      await settle();
      expect(repo.queries, ['BNP']);
      expect(state().results.single.itemId, 'id-1');
    });

    test('réseau injoignable → hors-ligne ; erreur serveur → erreur (pas hors-ligne)', () async {
      repo.error = _dio(DioExceptionType.connectionError);
      notifier().onQueryChanged('BNP');
      await settle();
      expect(state().isOffline, isTrue);
      expect(state().hasError, isFalse);

      repo.error = _dio(DioExceptionType.badResponse);
      notifier().onQueryChanged('BNPx');
      await settle();
      expect(state().isOffline, isFalse);
      expect(state().hasError, isTrue);
    });

    test('après hors-ligne, retaper : pas d’« aucun résultat » avant la réponse', () async {
      repo.error = _dio(DioExceptionType.connectionError);
      notifier().onQueryChanged('BNP');
      await settle();
      repo.error = null;
      notifier().onQueryChanged('BNPx');
      expect(state().isEmpty, isFalse);
      expect(state().isOffline, isFalse);
    });

    test('« Rechercher » au clavier : requête immédiate', () async {
      await notifier().submit('BNP');
      expect(repo.queries, ['BNP']);
      expect(state().results, isNotEmpty);
    });

    test('retry relance la dernière recherche', () async {
      repo.error = _dio(DioExceptionType.connectionError);
      notifier().onQueryChanged('BNP');
      await settle();
      repo.error = null;
      await notifier().retry();
      expect(state().results, isNotEmpty);
      expect(repo.queries, ['BNP', 'BNP']);
    });

    test('réponse périmée ignorée (la requête a changé entre-temps)', () async {
      notifier().onQueryChanged('BNP');
      await settle();
      repo.results = const [];
      notifier().onQueryChanged('xyz');
      await settle();
      expect(state().query, 'xyz');
      expect(state().results, isEmpty);
      expect(state().isEmpty, isTrue);
    });
  });

  group('récentes', () {
    test('ajout en tête, sans doublon (casse ignorée), 5 au plus, persistées', () async {
      final r = container.read(searchRecentsProvider.notifier);
      await container.read(searchRecentsProvider.future);
      for (final q in ['bnp', 'gardasil', 'dyspnée', 'alcool', 'amoxicilline', 'BNP', 'fièvre']) {
        await r.add(q);
      }
      final list = await container.read(searchRecentsProvider.future);
      expect(list, ['fièvre', 'BNP', 'amoxicilline', 'alcool', 'dyspnée']);
      expect(recents.saved, list);
    });

    test('écriture du trousseau en échec : pas d’erreur non gérée, liste tenue à jour', () async {
      recents.failWrites = true;
      final r = container.read(searchRecentsProvider.notifier);
      await container.read(searchRecentsProvider.future);
      await r.add('BNP');
      await r.clear();
      expect(await container.read(searchRecentsProvider.future), isEmpty);
    });

    test('deux ajouts simultanés : aucun perdu', () async {
      final r = container.read(searchRecentsProvider.notifier);
      await container.read(searchRecentsProvider.future);
      await Future.wait([r.add('BNP'), r.add('Gardasil')]);
      expect((await container.read(searchRecentsProvider.future)).toSet(), {'BNP', 'Gardasil'});
    });

    test('moins de 2 caractères : pas enregistré ; effacer vide la liste', () async {
      final r = container.read(searchRecentsProvider.notifier);
      await container.read(searchRecentsProvider.future);
      await r.add(' b ');
      await r.add('BNP');
      expect(await container.read(searchRecentsProvider.future), ['BNP']);
      await r.clear();
      expect(await container.read(searchRecentsProvider.future), isEmpty);
      expect(recents.saved, isEmpty);
    });
  });
}

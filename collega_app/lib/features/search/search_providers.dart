import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/network/network_errors.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/search/data/search_repository.dart';
import 'package:collega_app/features/search/domain/search_result.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(apiClientProvider).dio);
});

/// Résultats dès 2 caractères, 300 ms après la dernière frappe (spec v2 § Recherche).
const kSearchMinChars = 2;
const kSearchDebounce = Duration(milliseconds: 300);

class SearchState {
  const SearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.isPending = false,
    this.isOffline = false,
    this.hasError = false,
  });

  final String query;
  final List<SearchResult> results;
  final bool isLoading;

  /// Tapée, pas encore envoyée (délai de 300 ms) : ni résultat ni « aucun résultat ».
  final bool isPending;
  final bool isOffline;
  final bool hasError;

  bool get hasResults => results.isNotEmpty;
  bool get hasQuery => query.trim().isNotEmpty;

  /// Moins de 2 caractères : pas encore de recherche.
  bool get isTooShort => query.trim().length < kSearchMinChars;

  /// Recherche faite, sans résultat.
  bool get isEmpty => !isTooShort && !isLoading && !isPending && results.isEmpty && !isOffline && !hasError;
}

class SearchNotifier extends Notifier<SearchState> {
  Timer? _debounce;

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  void onQueryChanged(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < kSearchMinChars) {
      state = SearchState(query: trimmed);
      return;
    }
    // Résultats précédents gardés pendant la frappe (le chargement ne commence
    // qu'à la requête).
    state = SearchState(query: trimmed, results: state.results, isPending: true);
    _debounce = Timer(kSearchDebounce, () => _doSearch(trimmed));
  }

  /// « Rechercher » au clavier : sans attendre le délai.
  Future<void> submit(String query) async {
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.length < kSearchMinChars) return;
    await _doSearch(trimmed);
  }

  /// Relance la dernière recherche (après une erreur ou le retour du réseau).
  Future<void> retry() async {
    _debounce?.cancel();
    if (state.isTooShort) return;
    await _doSearch(state.query);
  }

  Future<void> _doSearch(String query) async {
    state = SearchState(query: query, results: state.results, isLoading: true);
    try {
      final results = await ref.read(searchRepositoryProvider).search(query);
      if (state.query == query) state = SearchState(query: query, results: results);
    } catch (e) {
      final offline = isNetworkUnreachable(e);
      if (!offline) AppLogger.error('Search error', tag: 'SearchNotifier', error: e);
      if (state.query == query) {
        state = SearchState(query: query, isOffline: offline, hasError: !offline);
      }
    }
  }
}

final searchNotifierProvider = NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);

// ─── Recherches récentes ──────────────────────────────────────────────────────

/// Stockage des recherches récentes (sur l'iPhone, jamais envoyées au serveur).
abstract interface class SearchRecentsStore {
  Future<List<String>> read();
  Future<void> write(List<String> recents);

  /// Changement de compte : les recherches de l'autre compte disparaissent.
  Future<void> clearAll();
}

class SecureSearchRecentsStore implements SearchRecentsStore {
  const SecureSearchRecentsStore(this._storage);

  final FlutterSecureStorage _storage;
  static const storageKey = 'search_recent_v1';

  @override
  Future<List<String>> read() async {
    try {
      final raw = await _storage.read(key: storageKey);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> write(List<String> recents) => _storage.write(key: storageKey, value: jsonEncode(recents));

  @override
  Future<void> clearAll() => _storage.delete(key: storageKey);
}

final searchRecentsStoreProvider = Provider<SearchRecentsStore>(
  (ref) => SecureSearchRecentsStore(ref.watch(secureStorageProvider)),
);

const kSearchRecentsMax = 5;

class SearchRecentsNotifier extends AsyncNotifier<List<String>> {
  /// Les modifications s'enchaînent (deux ajouts simultanés ne s'écrasent pas).
  Future<void> _queue = Future.value();

  @override
  Future<List<String>> build() => ref.read(searchRecentsStoreProvider).read();

  /// En tête, sans doublon (casse ignorée), 5 au plus.
  Future<void> add(String query) {
    final q = query.trim();
    if (q.length < kSearchMinChars) return Future.value();
    return _update((current) =>
        [q, ...current.where((r) => r.toLowerCase() != q.toLowerCase())].take(kSearchRecentsMax).toList());
  }

  Future<void> clear() => _update((_) => const []);

  Future<void> _update(List<String> Function(List<String>) change) {
    return _queue = _queue.then((_) async {
      final next = change(state.valueOrNull ?? await future);
      state = AsyncValue.data(next);
      try {
        await ref.read(searchRecentsStoreProvider).write(next);
      } catch (e) {
        // Trousseau indisponible : la liste reste juste en mémoire.
        AppLogger.warning('recherches récentes non enregistrées : $e', tag: 'SearchRecents');
      }
    });
  }
}

final searchRecentsProvider =
    AsyncNotifierProvider<SearchRecentsNotifier, List<String>>(SearchRecentsNotifier.new);

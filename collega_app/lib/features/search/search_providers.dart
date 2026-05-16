import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/search/data/search_repository.dart';
import 'package:collega_app/features/search/domain/search_result.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(apiClientProvider).dio);
});

class SearchState {
  const SearchState({
    this.query = '',
    this.results = const [],
    this.isLoading = false,
    this.isOffline = false,
    this.error,
  });

  final String query;
  final List<SearchResult> results;
  final bool isLoading;
  final bool isOffline;
  final String? error;

  bool get hasResults => results.isNotEmpty;
  bool get hasQuery => query.trim().isNotEmpty;
  bool get isEmpty =>
      query.trim().isNotEmpty &&
      !isLoading &&
      results.isEmpty &&
      !isOffline &&
      error == null;
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
    if (trimmed.isEmpty) {
      state = const SearchState();
      return;
    }
    // Résultats précédents conservés pendant le debounce (isLoading activé seulement à la requête)
    state = SearchState(query: trimmed, results: state.results);
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _doSearch(trimmed);
    });
  }

  Future<void> _doSearch(String query) async {
    state = SearchState(query: query, isLoading: true);
    try {
      final repo = ref.read(searchRepositoryProvider);
      final results = await repo.search(query);
      if (state.query == query) {
        state = SearchState(query: query, results: results);
      }
    } on DioException catch (e) {
      if (!_isOfflineError(e)) {
        AppLogger.error('Search error', tag: 'SearchNotifier', error: e);
      }
      if (state.query == query) {
        state = SearchState(
          query: query,
          isOffline: _isOfflineError(e),
          error: _isOfflineError(e) ? null : 'Erreur de recherche',
        );
      }
    } catch (e) {
      AppLogger.error('Search unexpected error', tag: 'SearchNotifier', error: e);
      if (state.query == query) {
        state = SearchState(query: query, error: 'Erreur de recherche');
      }
    }
  }

  bool _isOfflineError(DioException e) =>
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.receiveTimeout ||
      e.type == DioExceptionType.sendTimeout;
}

final searchNotifierProvider =
    NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);

import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/colleges/data/college_cards_sync.dart';
import 'package:collega_app/features/colleges/data/college_detail_repository.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/domain/drill_stats.dart';

final collegeDetailRepositoryProvider = Provider<CollegeDetailRepository>(
  (ref) => CollegeDetailRepository(
    dio: ref.read(apiClientProvider).dio,
    db: ref.read(databaseProvider),
  ),
);

/// Stats de drill par item, vivantes (watch Drift) — même pattern que
/// `collegeDrillStatsProvider` côté liste. Calculées hors du notifier de
/// détail pour que le détail suive les drills sans invalidation manuelle.
final collegeDrillStatsByItemProvider =
    StreamProvider.family<Map<String, DrillStats>, String>((ref, collegeId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.flashCards)
        ..where((t) => t.collegeId.equals(collegeId)))
      .watch()
      .map((cards) {
    final levelsByItem = <String, List<String>>{};
    for (final c in cards) {
      levelsByItem.putIfAbsent(c.itemId, () => []).add(c.drillLevel);
    }
    return levelsByItem.map(
      (itemId, levels) => MapEntry(itemId, DrillStats.fromDrillLevels(levels)),
    );
  });
});

/// Récupère toutes les fiches d'un collège (`GET /v1/colleges/{id}/cards`).
typedef CollegeCardsFetcher = Future<List<FlashCardModel>> Function(String collegeId);

final collegeCardsFetcherProvider = Provider<CollegeCardsFetcher>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  return (collegeId) => fetchCollegeCards(dio, collegeId);
});

/// Une réponse sans liste `data` est une erreur, jamais « aucune fiche » : la
/// synchronisation effacerait sinon toutes les fiches locales du collège.
Future<List<FlashCardModel>> fetchCollegeCards(Dio dio, String collegeId) async {
  final response = await dio.get<Map<String, dynamic>>('/v1/colleges/$collegeId/cards');
  final list = response.data?['data'];
  if (list is! List) {
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Réponse inattendue pour les fiches du collège $collegeId',
    );
  }
  return list.map((e) => FlashCardModel.fromJson(e as Map<String, dynamic>)).toList();
}

/// Incrémentée quand le contenu d'un collège change côté serveur (fin d'import
/// ou de réimport) : le détail, qui l'observe, se recharge.
final collegeDataVersionProvider = StateProvider.family<int, String>((ref, collegeId) => 0);

final collegeDetailProvider = AsyncNotifierProvider.family<
    CollegeDetailNotifier, CollegeDetailState, String>(
  CollegeDetailNotifier.new,
);

class CollegeDetailNotifier
    extends FamilyAsyncNotifier<CollegeDetailState, String> {
  @override
  Future<CollegeDetailState> build(String arg) async {
    final collegeId = arg;
    ref.watch(collegeDataVersionProvider(collegeId));
    final repo = ref.read(collegeDetailRepositoryProvider);
    List<ItemModel> items;
    try {
      // Les fiches aussi : le drill du collège lit Drift, qui doit refléter le
      // serveur (réimport, fiches arrivées depuis) — revue 8.7.
      final cards = ref.read(collegeCardsFetcherProvider)(collegeId).then<List<FlashCardModel>?>(
        (c) => c,
        onError: (Object e) {
          AppLogger.error('fiches du collège $collegeId', tag: 'CollegeDetailNotifier', error: e);
          return null;
        },
      );
      items = await repo.getItems(collegeId);
      if (items.isEmpty) return const CollegeDetailEmpty();
      final db = ref.read(databaseProvider);
      try {
        await syncItemsToDrift(db, collegeId, items);
        final fetched = await cards;
        if (fetched != null) await syncCollegeCards(db, collegeId, fetched);
      } catch (e) {
        AppLogger.error('synchro du collège $collegeId', tag: 'CollegeDetailNotifier', error: e);
      }
    } on DioException {
      items = await repo.getItemsFromDrift(collegeId);
      // Rien en cache : c'est le réseau qui manque, pas les fiches — l'écran
      // affiche l'état hors-ligne, jamais « aucune fiche ».
      if (items.isEmpty) rethrow;
    }
    return CollegeDetailLoaded(items: items);
  }

  void filterByRang(String? rang) {
    final current = state.valueOrNull;
    if (current is! CollegeDetailLoaded) return;
    state = AsyncValue.data(
      CollegeDetailLoaded(
        items: current.items,
        selectedRang: rang,
      ),
    );
  }
}

/// Numéro, titre et rang d'un item lus dans Drift (story 8.11) : le détail
/// d'item n'a pas à recharger tout le collège (réseau + synchro) pour un titre.
final itemInfoProvider = FutureProvider.autoDispose.family<ItemModel?, String>((ref, itemId) async {
  final db = ref.watch(databaseProvider);
  final row = await (db.select(db.items)..where((t) => t.id.equals(itemId))).getSingleOrNull();
  if (row == null) return null;
  return ItemModel(
    id: row.id,
    collegeId: row.collegeId,
    itemNumber: row.itemNumber,
    rang: row.rang,
    chapterTitle: row.chapterTitle,
    ocrConfidenceScore: row.ocrConfidenceScore,
    lowConfidence: row.lowConfidence,
    cardCountA: 0,
    cardCountB: 0,
    cardCountC: 0,
  );
});

final itemDetailProvider = AsyncNotifierProvider.family<
    ItemDetailNotifier, List<FlashCardModel>, String>(
  ItemDetailNotifier.new,
);

class ItemDetailNotifier
    extends FamilyAsyncNotifier<List<FlashCardModel>, String> {
  @override
  Future<List<FlashCardModel>> build(String arg) async {
    final compositeKey = arg;
    final parts = compositeKey.split(':');
    if (parts.length < 2) throw ArgumentError('Invalid compositeKey: $compositeKey');
    final collegeId = parts[0];
    final itemId = parts[1];
    final repo = ref.read(collegeDetailRepositoryProvider);
    try {
      final cards = await repo.getCards(collegeId, itemId);
      unawaited(repo.syncCardsToDrift(cards).catchError((Object e) {
        AppLogger.error('syncCardsToDrift failed', tag: 'ItemDetailNotifier', error: e);
      }));
      return cards;
    } on DioException {
      final cached = await repo.getCardsFromDrift(itemId);
      // Rien en cache : c'est le réseau qui manque — l'écran le dit (hors-ligne),
      // jamais « aucune fiche » (revue 8.11).
      if (cached.isEmpty) rethrow;
      return cached;
    }
  }

  Future<void> submitPositiveFeedback(String cardId) async {
    final repo = ref.read(collegeDetailRepositoryProvider);
    try {
      await repo.submitFeedback(cardId, 'positive');
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(
        current.map((c) => c.id == cardId ? c.copyWith(userFeedback: 'positive') : c).toList(),
      );
    } on DioException catch (e) {
      AppLogger.error('submitPositiveFeedback failed', tag: 'ItemDetailNotifier', error: e);
      rethrow;
    }
  }

  // P6: feedback négatif — enregistré en DB quand le pouce bas est tapé
  Future<void> submitNegativeFeedback(String cardId) async {
    final repo = ref.read(collegeDetailRepositoryProvider);
    try {
      await repo.submitFeedback(cardId, 'negative');
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(
        current.map((c) => c.id == cardId ? c.copyWith(userFeedback: 'negative') : c).toList(),
      );
    } on DioException catch (e) {
      AppLogger.error('submitNegativeFeedback failed', tag: 'ItemDetailNotifier', error: e);
      rethrow;
    }
  }

  Future<void> deleteCard(String cardId) async {
    final repo = ref.read(collegeDetailRepositoryProvider);
    // P14: try/catch cohérent avec les autres méthodes du notifier
    try {
      await repo.deleteCard(cardId);
      final current = state.valueOrNull ?? [];
      state = AsyncValue.data(current.where((c) => c.id != cardId).toList());
      // P8 : seul le collège courant (arg = compositeKey "collegeId:itemId") se
      // recharge, et seulement s'il est affiché (pas d'invalidate : en debug il
      // construirait un détail jamais lu).
      ref.read(collegeDataVersionProvider(arg.split(':')[0]).notifier).state++;
    } on DioException catch (e) {
      AppLogger.error('deleteCard failed', tag: 'ItemDetailNotifier', error: e);
      rethrow;
    }
  }

  Future<FlashCardModel> regenerateCard(String cardId, {String? userNote}) async {
    final repo = ref.read(collegeDetailRepositoryProvider);
    final newCard = await repo.regenerateCard(cardId, userNote: userNote);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.map((c) => c.id == cardId ? newCard : c).toList(),
    );
    return newCard;
  }
}

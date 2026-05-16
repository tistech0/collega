import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/colleges/data/college_detail_repository.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/domain/drill_stats.dart';

final collegeDetailRepositoryProvider = Provider<CollegeDetailRepository>(
  (ref) => CollegeDetailRepository(
    dio: ref.read(apiClientProvider).dio,
    db: ref.read(databaseProvider),
  ),
);

final collegeDetailProvider = AsyncNotifierProvider.family<
    CollegeDetailNotifier, CollegeDetailState, String>(
  CollegeDetailNotifier.new,
);

class CollegeDetailNotifier
    extends FamilyAsyncNotifier<CollegeDetailState, String> {
  @override
  Future<CollegeDetailState> build(String collegeId) async {
    final repo = ref.read(collegeDetailRepositoryProvider);
    List<ItemModel> items;
    try {
      items = await repo.getItems(collegeId);
      if (items.isEmpty) return const CollegeDetailEmpty();
      unawaited(repo.syncItemsToDrift(collegeId, items).catchError((Object e) {
        AppLogger.error('syncItemsToDrift failed', tag: 'CollegeDetailNotifier', error: e);
      }));
    } on DioException {
      items = await repo.getItemsFromDrift(collegeId);
      if (items.isEmpty) return const CollegeDetailEmpty();
    }
    Map<String, DrillStats> drillByItem;
    try {
      drillByItem = await repo.getDrillStatsByItem(collegeId);
    } catch (e) {
      AppLogger.error('getDrillStatsByItem failed', tag: 'CollegeDetailNotifier', error: e);
      return CollegeDetailLoaded(items: items);
    }
    items = items.map((item) {
      final drill = drillByItem[item.id];
      if (drill == null) return item;
      return ItemModel(
        id: item.id,
        collegeId: item.collegeId,
        itemNumber: item.itemNumber,
        rang: item.rang,
        chapterTitle: item.chapterTitle,
        ocrConfidenceScore: item.ocrConfidenceScore,
        lowConfidence: item.lowConfidence,
        cardCountA: item.cardCountA,
        cardCountB: item.cardCountB,
        cardCountC: item.cardCountC,
        drillMaitrise: drill.maitrise,
        drillBien: drill.bien,
        drillARevoir: drill.aRevoir,
        drillNotSeen: drill.notSeen,
      );
    }).toList();
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

final itemDetailProvider = AsyncNotifierProvider.family<
    ItemDetailNotifier, List<FlashCardModel>, String>(
  ItemDetailNotifier.new,
);

class ItemDetailNotifier
    extends FamilyAsyncNotifier<List<FlashCardModel>, String> {
  @override
  Future<List<FlashCardModel>> build(String compositeKey) async {
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
      return repo.getCardsFromDrift(itemId);
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
      // P8: invalider uniquement le collège courant (arg = compositeKey "collegeId:itemId")
      ref.invalidate(collegeDetailProvider(arg.split(':')[0]));
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

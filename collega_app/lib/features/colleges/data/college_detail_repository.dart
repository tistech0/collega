import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/colleges/data/college_cards_sync.dart' as sync_items;
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';

class CollegeDetailRepository {
  const CollegeDetailRepository({required this.dio, required this.db});

  final Dio dio;
  final AppDatabase db;

  Future<List<ItemModel>> getItems(String collegeId) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/v1/colleges/$collegeId/items',
      );
      final list = (response.data?['data'] as List<dynamic>?) ?? [];
      return list
          .map((e) => ItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      AppLogger.error('getItems failed', tag: 'CollegeDetailRepository', error: e);
      rethrow;
    }
  }

  Future<List<ItemModel>> getItemsFromDrift(String collegeId) async {
    final rows = await (db.select(db.items)
          ..where((t) => t.collegeId.equals(collegeId))
          ..orderBy([(t) => OrderingTerm.asc(t.itemNumber)]))
        .get();
    if (rows.isEmpty) return [];

    final itemIds = rows.map((r) => r.id).toList();
    final cardRows = await (db.select(db.flashCards)
          ..where((t) => t.itemId.isIn(itemIds)))
        .get();

    final counts = <String, Map<String, int>>{};
    for (final c in cardRows) {
      counts.putIfAbsent(c.itemId, () => {});
      counts[c.itemId]![c.rang] = (counts[c.itemId]![c.rang] ?? 0) + 1;
    }

    return rows
        .map(
          (r) => ItemModel(
            id: r.id,
            collegeId: r.collegeId,
            itemNumber: r.itemNumber,
            rang: r.rang,
            chapterTitle: r.chapterTitle,
            ocrConfidenceScore: r.ocrConfidenceScore,
            lowConfidence: r.lowConfidence,
            cardCountA: counts[r.id]?['A'] ?? 0,
            cardCountB: counts[r.id]?['B'] ?? 0,
            cardCountC: counts[r.id]?['C'] ?? 0,
            startPage: r.startPage,
            endPage: r.endPage,
          ),
        )
        .toList();
  }

  Future<List<FlashCardModel>> getCards(
      String collegeId, String itemId) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/v1/colleges/$collegeId/items/$itemId/cards',
      );
      final list = (response.data?['data'] as List<dynamic>?) ?? [];
      return list
          .map((e) => FlashCardModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      AppLogger.error('getCards failed', tag: 'CollegeDetailRepository', error: e);
      rethrow;
    }
  }

  Future<List<FlashCardModel>> getCardsFromDrift(String itemId) async {
    final rows = await (db.select(db.flashCards)
          ..where((t) => t.itemId.equals(itemId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.rang),
            (t) => OrderingTerm.asc(t.cardType),
          ]))
        .get();
    return rows
        .map(
          (r) => FlashCardModel(
            id: r.id,
            itemId: r.itemId,
            collegeId: r.collegeId,
            cardType: r.cardType,
            rang: r.rang,
            recto: r.recto,
            verso: r.verso,
            ocrConfidenceScore: r.ocrConfidenceScore,
            lowConfidence: r.lowConfidence,
            userFeedback: r.userFeedback,
          ),
        )
        .toList();
  }

  Future<void> syncItemsToDrift(String collegeId, List<ItemModel> items) =>
      sync_items.syncItemsToDrift(db, collegeId, items);

  Future<void> syncCardsToDrift(List<FlashCardModel> cards) async {
    await db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        db.flashCards,
        cards.map(
          (c) => FlashCardsCompanion.insert(
            id: c.id,
            itemId: c.itemId,
            collegeId: c.collegeId,
            cardType: c.cardType,
            rang: c.rang,
            recto: c.recto,
            verso: c.verso,
            ocrConfidenceScore: Value(c.ocrConfidenceScore),
            lowConfidence: Value(c.lowConfidence),
            userFeedback: Value(c.userFeedback),
          ),
        ),
      );
    });
  }

  Future<void> submitFeedback(String cardId, String feedback) async {
    try {
      await dio.post<void>(
        '/v1/flash-cards/$cardId/feedback',
        data: {'feedback': feedback},
      );
      await (db.update(db.flashCards)..where((t) => t.id.equals(cardId)))
          .write(FlashCardsCompanion(userFeedback: Value(feedback)));
    } on DioException catch (e) {
      AppLogger.error('submitFeedback failed', tag: 'CollegeDetailRepository', error: e);
      rethrow;
    }
  }

  Future<void> deleteCard(String cardId) async {
    try {
      await dio.delete<void>('/v1/flash-cards/$cardId');
      await (db.delete(db.flashCards)..where((t) => t.id.equals(cardId))).go();
    } on DioException catch (e) {
      AppLogger.error('deleteCard failed', tag: 'CollegeDetailRepository', error: e);
      rethrow;
    }
  }

  Future<FlashCardModel> regenerateCard(String cardId, {String? userNote}) async {
    try {
      final response = await dio.post<Map<String, dynamic>>(
        '/v1/flash-cards/$cardId/regenerate',
        data: {'user_note': userNote},
      );
      final newCard = FlashCardModel.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
      await syncCardsToDrift([newCard]);
      return newCard;
    } on DioException catch (e) {
      AppLogger.error('regenerateCard failed', tag: 'CollegeDetailRepository', error: e);
      rethrow;
    }
  }
}

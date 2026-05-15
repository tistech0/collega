import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';

class DrillRepository {
  const DrillRepository({required this.dio, required this.db});

  final Dio dio;
  final AppDatabase db;

  Future<List<FlashCardModel>> getCardsForDrill({
    required String collegeId,
    String? itemId,
    List<String>? rangs,
    bool onlyARevoir = false,
    int maxCards = 0,
  }) async {
    final query = db.select(db.flashCards)
      ..where((t) => t.collegeId.equals(collegeId));
    if (itemId != null) {
      query.where((t) => t.itemId.equals(itemId));
    }
    if (rangs != null && rangs.isNotEmpty) {
      query.where((t) => t.rang.isIn(rangs));
    }
    if (onlyARevoir) {
      query.where((t) => t.drillLevel.equals('a_revoir'));
    }
    final rows = await query.get();
    final models = rows.map(rowToModel).toList();

    // Tri en Dart : a_revoir → new → bien → maitrise, puis A→B→C
    const levelOrder = {'a_revoir': 0, 'new': 1, 'bien': 2, 'maitrise': 3};
    const rangOrder = {'A': 0, 'B': 1, 'C': 2};
    final drillLevels = {for (final r in rows) r.id: r.drillLevel};
    models.sort((a, b) {
      final lA = levelOrder[drillLevels[a.id] ?? 'new'] ?? 1;
      final lB = levelOrder[drillLevels[b.id] ?? 'new'] ?? 1;
      if (lA != lB) return lA.compareTo(lB);
      return (rangOrder[a.rang] ?? 3).compareTo(rangOrder[b.rang] ?? 3);
    });
    if (maxCards > 0 && models.length > maxCards) {
      return models.sublist(0, maxCards);
    }
    return models;
  }

  Future<void> updateCardDrillLevel(
      String cardId, DrillEvaluationResult result) async {
    final existing = await (db.select(db.flashCards)
          ..where((t) => t.id.equals(cardId)))
        .getSingleOrNull();
    final currentCount = existing?.reviewCount ?? 0;

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final level = switch (result) {
      DrillEvaluationResult.aRevoir => 'a_revoir',
      DrillEvaluationResult.bien => 'bien',
      DrillEvaluationResult.maitrise => 'maitrise',
    };
    final nextReview = switch (result) {
      DrillEvaluationResult.aRevoir => nowMs,
      DrillEvaluationResult.bien => nowMs + 86400000,
      DrillEvaluationResult.maitrise => nowMs + 7 * 86400000,
    };
    await (db.update(db.flashCards)..where((t) => t.id.equals(cardId))).write(
      FlashCardsCompanion(
        drillLevel: Value(level),
        nextReviewAt: Value(nextReview),
        reviewCount: Value(currentCount + 1),
      ),
    );
  }

  Future<SemanticFeedback> evaluateSemantic(
      String cardId, String userAnswer) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/v1/flash-cards/$cardId/evaluate-semantic',
      data: {'user_answer': userAnswer},
    );
    final raw = response.data;
    if (raw == null) throw Exception('empty evaluateSemantic response');
    final data = raw['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('malformed evaluateSemantic response');
    return SemanticFeedback(
      result: data['result'] as String? ?? 'incorrect',
      feedback: data['feedback'] as String? ?? '',
    );
  }

  FlashCardModel rowToModel(FlashCard row) => FlashCardModel(
        id: row.id,
        itemId: row.itemId,
        collegeId: row.collegeId,
        cardType: row.cardType,
        rang: row.rang,
        recto: row.recto,
        verso: row.verso,
        ocrConfidenceScore: row.ocrConfidenceScore,
        lowConfidence: row.lowConfidence,
        userFeedback: row.userFeedback,
        drillLevel: row.drillLevel,
      );
}

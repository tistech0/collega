import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';

@immutable
class DrillSessionParams {
  const DrillSessionParams({
    required this.collegeId,
    this.itemId,
    this.itemName,
    this.rangs,
    this.onlyARevoir = false,
    this.maxCards = 0,
    this.fromSearch = false,
    this.dailySessionDay,
  });

  /// Session du jour (story 8.3) : fiches de la file figée en Drift pour ce jour,
  /// tous collèges confondus, reprise à la position enregistrée.
  const DrillSessionParams.daily(int day)
      : collegeId = '',
        itemId = null,
        itemName = null,
        rangs = null,
        onlyARevoir = false,
        maxCards = 0,
        fromSearch = false,
        dailySessionDay = day;

  final String collegeId;
  final String? itemId;
  final String? itemName;
  final List<String>? rangs;
  final bool onlyARevoir;
  final int maxCards;
  final bool fromSearch;
  final int? dailySessionDay;

  bool get isDailySession => dailySessionDay != null;

  @override
  bool operator ==(Object other) =>
      other is DrillSessionParams &&
      other.collegeId == collegeId &&
      other.itemId == itemId &&
      other.itemName == itemName &&
      const ListEquality<String>().equals(other.rangs, rangs) &&
      other.onlyARevoir == onlyARevoir &&
      other.maxCards == maxCards &&
      other.fromSearch == fromSearch &&
      other.dailySessionDay == dailySessionDay;

  @override
  int get hashCode => Object.hash(
      collegeId, itemId, itemName, Object.hashAll(rangs ?? []), onlyARevoir, maxCards, fromSearch,
      dailySessionDay);
}

@immutable
class SemanticFeedback {
  const SemanticFeedback({required this.result, required this.feedback});

  final String result; // 'correct' | 'partial' | 'incorrect'
  final String feedback;
}

@immutable
class DrillSessionState {
  const DrillSessionState({
    required this.cards,
    required this.queue,
    this.currentQueuePos = 0,
    this.evaluatedCount = 0,
    this.evaluations = const {},
    this.isFlipped = false,
    this.exitResult,
    this.semanticFeedback,
    this.isComplete = false,
    this.timerExpired = false,
    this.requeued = false,
  });

  final List<FlashCardModel> cards;
  final List<int> queue;
  final int currentQueuePos;
  final int evaluatedCount;
  final Map<String, DrillEvaluationResult> evaluations;
  final bool isFlipped;
  final DrillEvaluationResult? exitResult;
  final SemanticFeedback? semanticFeedback;
  final bool isComplete;
  final bool timerExpired;

  /// La dernière évaluation a réinséré la carte plus loin dans la file
  /// (1er « à revoir ») — l'écran affiche un rappel. Reset par advanceToNext.
  final bool requeued;

  int get totalInitial => cards.length;

  FlashCardModel? get currentCard =>
      queue.isEmpty || currentQueuePos >= queue.length
          ? null
          : cards[queue[currentQueuePos]];

  DrillSessionState copyWith({
    List<FlashCardModel>? cards,
    List<int>? queue,
    int? currentQueuePos,
    int? evaluatedCount,
    Map<String, DrillEvaluationResult>? evaluations,
    bool? isFlipped,
    Object? exitResult = _absent,
    Object? semanticFeedback = _absent,
    bool? isComplete,
    bool? timerExpired,
    bool? requeued,
  }) {
    return DrillSessionState(
      cards: cards ?? this.cards,
      queue: queue ?? this.queue,
      currentQueuePos: currentQueuePos ?? this.currentQueuePos,
      evaluatedCount: evaluatedCount ?? this.evaluatedCount,
      evaluations: evaluations ?? this.evaluations,
      isFlipped: isFlipped ?? this.isFlipped,
      exitResult: identical(exitResult, _absent)
          ? this.exitResult
          : exitResult as DrillEvaluationResult?,
      semanticFeedback: identical(semanticFeedback, _absent)
          ? this.semanticFeedback
          : semanticFeedback as SemanticFeedback?,
      isComplete: isComplete ?? this.isComplete,
      timerExpired: timerExpired ?? this.timerExpired,
      requeued: requeued ?? this.requeued,
    );
  }

  static const _absent = Object();
}

@immutable
class DrillSessionSummary {
  const DrillSessionSummary({
    required this.maitrisCount,
    required this.bienCount,
    required this.aRevoirCount,
  });

  final int maitrisCount;
  final int bienCount;
  final int aRevoirCount;

  int get total => maitrisCount + bienCount + aRevoirCount;
  double get masteryRatio => total == 0 ? 0 : maitrisCount / total;

  factory DrillSessionSummary.fromEvaluations(
      Map<String, DrillEvaluationResult> evaluations) {
    return DrillSessionSummary(
      maitrisCount: evaluations.values
          .where((v) => v == DrillEvaluationResult.maitrise)
          .length,
      bienCount: evaluations.values
          .where((v) => v == DrillEvaluationResult.bien)
          .length,
      aRevoirCount: evaluations.values
          .where((v) => v == DrillEvaluationResult.aRevoir)
          .length,
    );
  }
}

import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/drill/data/drill_repository.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';

final drillRepositoryProvider = Provider<DrillRepository>(
  (ref) => DrillRepository(
    dio: ref.read(apiClientProvider).dio,
    db: ref.read(databaseProvider),
  ),
);

final drillSessionProvider = AsyncNotifierProvider.family<
    DrillSessionNotifier, DrillSessionState, DrillSessionParams>(
  DrillSessionNotifier.new,
);

class DrillSessionNotifier
    extends FamilyAsyncNotifier<DrillSessionState, DrillSessionParams> {
  @override
  Future<DrillSessionState> build(DrillSessionParams arg) async {
    final repo = ref.read(drillRepositoryProvider);
    final cards = await repo.getCardsForDrill(
      collegeId: arg.collegeId,
      itemId: arg.itemId,
      rangs: arg.rangs,
      onlyARevoir: arg.onlyARevoir,
      maxCards: arg.maxCards,
    );
    if (cards.isEmpty) {
      return const DrillSessionState(cards: [], queue: [], isComplete: true);
    }
    final queue = List.generate(cards.length, (i) => i);
    return DrillSessionState(cards: cards, queue: queue);
  }

  void flip() {
    final s = state.value;
    if (s == null) return;
    if (s.exitResult != null) return;
    state = AsyncValue.data(s.copyWith(isFlipped: !s.isFlipped));
  }

  /// Force le passage au verso suite à l'expiration du chronomètre (Story 7.4).
  ///
  /// - Idempotent : un second appel ne change pas l'état.
  /// - Ignoré si la carte est déjà retournée manuellement (`isFlipped == true`).
  /// - Aucun appel backend (pas d'`evaluateSemantic` ni d'`updateCardDrillLevel`)
  ///   — l'utilisatrice évalue manuellement après lecture du verso.
  void handleTimerExpiry() {
    final s = state.value;
    if (s == null) return;
    if (s.exitResult != null) return;
    if (s.isFlipped) return;
    if (s.timerExpired) return;
    state = AsyncValue.data(s.copyWith(
      isFlipped: true,
      timerExpired: true,
    ));
  }

  void setSemanticFeedback(SemanticFeedback feedback) {
    final s = state.value;
    if (s == null) return;
    state = AsyncValue.data(s.copyWith(semanticFeedback: feedback));
  }

  Future<void> evaluate(DrillEvaluationResult result) async {
    final s = state.value;
    if (s == null || s.currentCard == null) return;
    if (s.exitResult != null) return;

    final card = s.currentCard!;
    final repo = ref.read(drillRepositoryProvider);

    unawaited(
      repo.updateCardDrillLevel(card.id, result).catchError(
        (Object e) =>
            AppLogger.error('updateCardDrillLevel failed', error: e),
      ),
    );

    final newQueue = List<int>.from(s.queue);
    if (result == DrillEvaluationResult.aRevoir) {
      final insertPos = (s.currentQueuePos + 3).clamp(
        s.currentQueuePos + 1,
        newQueue.length,
      );
      newQueue.insert(insertPos, newQueue[s.currentQueuePos]);
    }

    final newEvals =
        Map<String, DrillEvaluationResult>.from(s.evaluations)
          ..[card.id] = result;

    state = AsyncValue.data(s.copyWith(
      queue: newQueue,
      evaluations: newEvals,
      evaluatedCount: s.evaluations.containsKey(card.id)
          ? s.evaluatedCount
          : s.evaluatedCount + 1,
      exitResult: result,
    ));
  }

  void advanceToNext() {
    final s = state.value;
    if (s == null || s.isComplete) return;
    final nextPos = s.currentQueuePos + 1;
    final isComplete = nextPos >= s.queue.length;
    state = AsyncValue.data(s.copyWith(
      currentQueuePos: nextPos,
      isFlipped: false,
      exitResult: null,
      semanticFeedback: null,
      isComplete: isComplete,
      timerExpired: false,
    ));
  }

  void restartWithErrors() {
    final s = state.value;
    if (s == null) return;
    final errorCardIds = s.evaluations.entries
        .where((e) => e.value == DrillEvaluationResult.aRevoir)
        .map((e) => e.key)
        .toSet();
    final errorIndices = s.cards
        .asMap()
        .entries
        .where((e) => errorCardIds.contains(e.value.id))
        .map((e) => e.key)
        .toList();
    if (errorIndices.isEmpty) return;
    state = AsyncValue.data(DrillSessionState(
      cards: s.cards,
      queue: errorIndices,
      evaluatedCount: 0,
      evaluations: const {},
      isFlipped: false,
      isComplete: false,
    ));
  }
}

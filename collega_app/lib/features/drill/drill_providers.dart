import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/drill/data/drill_repository.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';
import 'package:collega_app/features/today/data/daily_session_repository.dart';

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
    if (arg.isDailySession) return _buildDaily(repo, arg.dailySessionDay!);
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

  /// Session du jour : file figée (réinsertions comprises) reprise à sa position.
  Future<DrillSessionState> _buildDaily(DrillRepository repo, int day) async {
    final session = await DailySessionRepository(ref.read(databaseProvider)).find(day);
    if (session == null || session.cardIds.isEmpty) {
      return const DrillSessionState(cards: [], queue: [], isComplete: true);
    }
    final unique = <String>[];
    for (final id in session.cardIds) {
      if (!unique.contains(id)) unique.add(id);
    }
    final cards = await repo.getCardsByIds(unique);
    final indexOf = {for (var i = 0; i < cards.length; i++) cards[i].id: i};
    // Une fiche supprimée depuis (régénération) sort simplement de la file.
    final queue = [for (final id in session.cardIds) if (indexOf[id] != null) indexOf[id]!];
    final position = session.position.clamp(0, queue.length);
    // Une fiche présente deux fois dans la file a déjà été réinsérée : la règle
    // « une seule réinsertion » tient aussi après une reprise.
    final seen = <String>{};
    final requeued = <String, DrillEvaluationResult>{
      for (final id in session.cardIds)
        if (!seen.add(id)) id: DrillEvaluationResult.aRevoir,
    };
    return DrillSessionState(
      cards: cards,
      queue: queue,
      currentQueuePos: position,
      evaluatedCount: position,
      evaluations: requeued,
      isComplete: queue.isEmpty || position >= queue.length,
    );
  }

  // — Session du jour : persistance (story 8.3) —

  DailySessionRepository get _daily => DailySessionRepository(ref.read(databaseProvider));

  static const _levelOf = {
    DrillEvaluationResult.aRevoir: 'a_revoir',
    DrillEvaluationResult.bien: 'bien',
    DrillEvaluationResult.maitrise: 'maitrise',
  };

  /// File et position enregistrées à chaque fiche ; clôture automatique à la
  /// dernière (plus de bouton « Session terminée »).
  Future<void> _persistDaily(DrillSessionState s) async {
    final day = arg.dailySessionDay!;
    try {
      await _daily.saveProgress(
        day: day,
        queue: [for (final i in s.queue) s.cards[i].id],
        position: s.currentQueuePos,
      );
      // Aujourd'hui se recalcule au retour du drill (TodayScreen), pas d'ici.
      if (s.isComplete) await _daily.complete(day);
    } catch (e) {
      AppLogger.error('session du jour : enregistrement impossible', tag: 'Drill', error: e);
    }
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

  /// Retour d'évaluation d'une définition. Ignoré s'il arrive après le passage
  /// à une autre fiche (réponse serveur lente, chrono expiré entre-temps).
  void setSemanticFeedback(SemanticFeedback feedback, {String? cardId}) {
    final s = state.value;
    if (s == null || s.exitResult != null) return;
    if (cardId != null && s.currentCard?.id != cardId) return;
    state = AsyncValue.data(s.copyWith(semanticFeedback: feedback));
  }


  /// Retourne `true` si la carte a été réinsérée plus loin dans la file.
  Future<bool> evaluate(DrillEvaluationResult result) async {
    final s = state.value;
    if (s == null || s.currentCard == null) return false;
    if (s.exitResult != null) return false;

    final card = s.currentCard!;
    final repo = ref.read(drillRepositoryProvider);

    unawaited(
      repo.updateCardDrillLevel(card.id, result).catchError(
        (Object e) =>
            AppLogger.error('updateCardDrillLevel failed', error: e),
      ),
    );

    // Un 1er « à revoir » réinsère la carte 3 positions plus loin ; un 2e
    // « à revoir » sur la même carte ne la réinsère plus (comptée en erreur,
    // la session peut se terminer — reprise via restartWithErrors).
    final alreadyFailed =
        s.evaluations[card.id] == DrillEvaluationResult.aRevoir;
    final requeue = result == DrillEvaluationResult.aRevoir && !alreadyFailed;
    final newQueue = List<int>.from(s.queue);
    if (requeue) {
      final insertPos = (s.currentQueuePos + 3).clamp(
        s.currentQueuePos + 1,
        newQueue.length,
      );
      newQueue.insert(insertPos, newQueue[s.currentQueuePos]);
    }

    final newEvals =
        Map<String, DrillEvaluationResult>.from(s.evaluations)
          ..[card.id] = result;

    if (arg.isDailySession) {
      unawaited(_daily
          .recordVerdict(
            day: arg.dailySessionDay!,
            cardId: card.id,
            collegeId: card.collegeId,
            rang: card.rang,
            drillLevel: _levelOf[result]!,
          )
          .catchError((Object e) => AppLogger.error('recordVerdict failed', error: e)));
    }

    state = AsyncValue.data(s.copyWith(
      queue: newQueue,
      evaluations: newEvals,
      evaluatedCount: s.evaluations.containsKey(card.id)
          ? s.evaluatedCount
          : s.evaluatedCount + 1,
      exitResult: result,
      requeued: requeue,
    ));
    return requeue;
  }

  void advanceToNext() {
    final s = state.value;
    if (s == null || s.isComplete) return;
    final nextPos = s.currentQueuePos + 1;
    final isComplete = nextPos >= s.queue.length;
    final next = s.copyWith(
      currentQueuePos: nextPos,
      isFlipped: false,
      exitResult: null,
      semanticFeedback: null,
      isComplete: isComplete,
      timerExpired: false,
      requeued: false,
    );
    state = AsyncValue.data(next);
    // « Refaire les à revoir » après la fin : entraînement hors session du jour,
    // la file enregistrée (et la reprise) ne sont pas écrasées.
    if (arg.isDailySession && !_replayingErrors) unawaited(_persistDaily(next));
  }

  /// Vrai après « Refaire les à revoir » : plus rien n'est écrit dans la session du jour.
  bool _replayingErrors = false;

  void restartWithErrors() {
    final s = state.value;
    if (s == null) return;
    _replayingErrors = true;
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

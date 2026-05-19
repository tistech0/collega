import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/drill/data/drill_repository.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';
import 'package:collega_app/features/drill/drill_providers.dart';

class _FakeDrillRepository extends DrillRepository {
  _FakeDrillRepository(this._cards)
      : super(
          dio: Dio(),
          db: AppDatabase.forTesting(NativeDatabase.memory()),
        );

  final List<FlashCardModel> _cards;
  final List<String> updatedIds = [];

  @override
  Future<List<FlashCardModel>> getCardsForDrill({
    required String collegeId,
    String? itemId,
    List<String>? rangs,
    bool onlyARevoir = false,
    int maxCards = 0,
  }) async {
    if (onlyARevoir) {
      return _cards.where((c) => c.id.startsWith('a_revoir')).toList();
    }
    return List.from(_cards);
  }

  @override
  Future<void> updateCardDrillLevel(
      String cardId, DrillEvaluationResult result) async {
    updatedIds.add(cardId);
  }
}

const _params = DrillSessionParams(collegeId: 'c1', itemId: 'i1');

List<FlashCardModel> _makeCards(int count) => List.generate(
      count,
      (i) => FlashCardModel(
        id: 'card-$i',
        itemId: 'i1',
        collegeId: 'c1',
        cardType: 'classique',
        rang: 'A',
        recto: 'Q$i',
        verso: 'R$i',
        ocrConfidenceScore: 1.0,
        lowConfidence: false,
      ),
    );

ProviderContainer _makeContainer(List<FlashCardModel> cards) {
  return ProviderContainer(
    overrides: [
      drillRepositoryProvider
          .overrideWithValue(_FakeDrillRepository(cards)),
    ],
  );
}

void main() {
  group('DrillSessionNotifier', () {
    test('chargement initial — queue ordonnée 0..n-1', () async {
      final cards = _makeCards(3);
      final container = _makeContainer(cards);
      addTearDown(container.dispose);

      final session =
          await container.read(drillSessionProvider(_params).future);
      expect(session.queue, [0, 1, 2]);
      expect(session.cards.length, 3);
      expect(session.isComplete, false);
    });

    test('evaluate(aRevoir) — carte réinsérée 3 positions plus loin', () async {
      final cards = _makeCards(5);
      final container = _makeContainer(cards);
      addTearDown(container.dispose);

      await container.read(drillSessionProvider(_params).future);
      final notifier =
          container.read(drillSessionProvider(_params).notifier);

      await notifier.evaluate(DrillEvaluationResult.aRevoir);

      final s = container.read(drillSessionProvider(_params)).value!;
      expect(s.queue.length, 6); // 1 carte réinsérée
      expect(s.queue[3], 0); // réinsérée en position currentPos+3 = 3
      expect(s.evaluatedCount, 1);
    });

    test('evaluate(bien) — evaluatedCount + 1, queue non allongée', () async {
      final cards = _makeCards(3);
      final container = _makeContainer(cards);
      addTearDown(container.dispose);

      await container.read(drillSessionProvider(_params).future);
      final notifier =
          container.read(drillSessionProvider(_params).notifier);

      await notifier.evaluate(DrillEvaluationResult.bien);

      final s = container.read(drillSessionProvider(_params)).value!;
      expect(s.queue.length, 3); // inchangé
      expect(s.evaluatedCount, 1);
      expect(s.evaluations['card-0'], DrillEvaluationResult.bien);
    });

    test('evaluate(maitrise) — evaluatedCount + 1', () async {
      final cards = _makeCards(3);
      final container = _makeContainer(cards);
      addTearDown(container.dispose);

      await container.read(drillSessionProvider(_params).future);
      final notifier =
          container.read(drillSessionProvider(_params).notifier);

      await notifier.evaluate(DrillEvaluationResult.maitrise);

      final s = container.read(drillSessionProvider(_params)).value!;
      expect(s.evaluatedCount, 1);
      expect(s.evaluations['card-0'], DrillEvaluationResult.maitrise);
    });

    test('advanceToNext() — currentQueuePos avance, isFlipped reset', () async {
      final cards = _makeCards(3);
      final container = _makeContainer(cards);
      addTearDown(container.dispose);

      await container.read(drillSessionProvider(_params).future);
      final notifier =
          container.read(drillSessionProvider(_params).notifier);

      notifier.flip();
      await notifier.evaluate(DrillEvaluationResult.bien);
      notifier.advanceToNext();

      final s = container.read(drillSessionProvider(_params)).value!;
      expect(s.currentQueuePos, 1);
      expect(s.isFlipped, false);
      expect(s.exitResult, isNull);
    });

    test('session complète — isComplete == true', () async {
      final cards = _makeCards(1);
      final container = _makeContainer(cards);
      addTearDown(container.dispose);

      await container.read(drillSessionProvider(_params).future);
      final notifier =
          container.read(drillSessionProvider(_params).notifier);

      await notifier.evaluate(DrillEvaluationResult.maitrise);
      notifier.advanceToNext();

      final s = container.read(drillSessionProvider(_params)).value!;
      expect(s.isComplete, true);
    });

    // ─── Story 7.1 — R2 (flip toggle) ────────────────────────────────────

    test('flip() — toggle bidirectionnel tant que pas d\'évaluation',
        () async {
      final cards = _makeCards(1);
      final container = _makeContainer(cards);
      addTearDown(container.dispose);

      await container.read(drillSessionProvider(_params).future);
      final notifier =
          container.read(drillSessionProvider(_params).notifier);

      notifier.flip();
      expect(container.read(drillSessionProvider(_params)).value!.isFlipped,
          true);

      notifier.flip(); // re-flip vers recto
      expect(container.read(drillSessionProvider(_params)).value!.isFlipped,
          false);

      notifier.flip();
      expect(container.read(drillSessionProvider(_params)).value!.isFlipped,
          true);
    });

    test('flip() — désactivé après évaluation (exitResult != null)',
        () async {
      final cards = _makeCards(1);
      final container = _makeContainer(cards);
      addTearDown(container.dispose);

      await container.read(drillSessionProvider(_params).future);
      final notifier =
          container.read(drillSessionProvider(_params).notifier);

      notifier.flip();
      await notifier.evaluate(DrillEvaluationResult.maitrise);

      // Après evaluate, isFlipped reste true (préservé) et exitResult != null.
      expect(
        container.read(drillSessionProvider(_params)).value!.isFlipped,
        true,
        reason: 'isFlipped doit être préservé après evaluate()',
      );
      expect(
        container.read(drillSessionProvider(_params)).value!.exitResult,
        DrillEvaluationResult.maitrise,
      );

      notifier.flip();

      // flip() doit être un no-op : isFlipped reste true, exitResult reste set.
      expect(
        container.read(drillSessionProvider(_params)).value!.isFlipped,
        true,
        reason: 'flip() doit être no-op tant que exitResult != null',
      );
      expect(
        container.read(drillSessionProvider(_params)).value!.exitResult,
        DrillEvaluationResult.maitrise,
      );
    });

    test('restartWithErrors() — queue = indices des cartes à revoir', () async {
      final cards = _makeCards(3);
      final container = _makeContainer(cards);
      addTearDown(container.dispose);

      await container.read(drillSessionProvider(_params).future);
      final notifier =
          container.read(drillSessionProvider(_params).notifier);

      // Évaluer card-0 comme à revoir, card-1 comme bien, card-2 comme maîtrisé
      await notifier.evaluate(DrillEvaluationResult.aRevoir);
      notifier.advanceToNext();
      await notifier.evaluate(DrillEvaluationResult.bien);
      notifier.advanceToNext();
      await notifier.evaluate(DrillEvaluationResult.maitrise);
      notifier.advanceToNext();

      notifier.restartWithErrors();

      final s = container.read(drillSessionProvider(_params)).value!;
      expect(s.isComplete, false);
      expect(s.queue.length, 1);
      expect(s.cards[s.queue[0]].id, 'card-0');
      expect(s.evaluatedCount, 0);
    });
  });
}

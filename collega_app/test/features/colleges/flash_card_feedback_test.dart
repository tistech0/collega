import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/features/colleges/colleges_detail_providers.dart';
import 'package:collega_app/features/colleges/data/college_detail_repository.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';

const _card1 = FlashCardModel(
  id: 'card-1',
  itemId: 'item-1',
  collegeId: 'college-1',
  cardType: 'classique',
  rang: 'A',
  recto: 'Question initiale ?',
  verso: 'Réponse initiale',
  ocrConfidenceScore: 0.9,
  lowConfidence: false,
);

const _card2 = FlashCardModel(
  id: 'card-2',
  itemId: 'item-1',
  collegeId: 'college-1',
  cardType: 'definition',
  rang: 'B',
  recto: 'Terme',
  verso: 'Définition',
  ocrConfidenceScore: 0.8,
  lowConfidence: false,
);

class _FakeCollegeDetailRepository extends CollegeDetailRepository {
  _FakeCollegeDetailRepository({
    List<FlashCardModel>? cards,
    this.regeneratedCard,
  })  : cards = cards ?? const [_card1, _card2],
        super(dio: Dio(), db: AppDatabase.forTesting(NativeDatabase.memory()));

  final List<FlashCardModel> cards;
  final FlashCardModel? regeneratedCard;

  @override
  Future<List<FlashCardModel>> getCards(String collegeId, String itemId) async {
    return cards;
  }

  @override
  Future<List<FlashCardModel>> getCardsFromDrift(String itemId) async {
    return cards;
  }

  @override
  Future<void> syncCardsToDrift(List<FlashCardModel> cards) async {}

  @override
  Future<void> submitFeedback(String cardId, String feedback) async {}

  @override
  Future<void> deleteCard(String cardId) async {}

  @override
  Future<FlashCardModel> regenerateCard(String cardId, {String? userNote}) async {
    return regeneratedCard ?? _card1.copyWith(recto: 'Question régénérée ?');
  }
}

ProviderContainer _makeContainer(_FakeCollegeDetailRepository repo) {
  return ProviderContainer(
    overrides: [
      collegeDetailRepositoryProvider.overrideWithValue(repo),
      secureStorageProvider.overrideWithValue(const FlutterSecureStorage()),
      databaseProvider.overrideWithValue(AppDatabase.forTesting(NativeDatabase.memory())),
    ],
  );
}

void main() {
  group('FlashCardModel.fromJson', () {
    test('parse user_feedback correctement', () {
      final json = {
        'id': 'card-1',
        'item_id': 'item-1',
        'college_id': 'college-1',
        'card_type': 'classique',
        'rang': 'A',
        'recto': 'Question ?',
        'verso': 'Réponse',
        'ocr_confidence_score': 0.9,
        'low_confidence': false,
        'user_feedback': 'positive',
      };
      final model = FlashCardModel.fromJson(json);
      expect(model.userFeedback, 'positive');
    });

    test('user_feedback est null si absent', () {
      final json = {
        'id': 'card-1',
        'item_id': 'item-1',
        'college_id': 'college-1',
        'card_type': 'classique',
        'rang': 'A',
        'recto': 'Question ?',
        'verso': 'Réponse',
        'ocr_confidence_score': 0.9,
        'low_confidence': false,
      };
      final model = FlashCardModel.fromJson(json);
      expect(model.userFeedback, isNull);
    });

    test('copyWith met à jour userFeedback', () {
      const original = FlashCardModel(
        id: 'card-1',
        itemId: 'item-1',
        collegeId: 'college-1',
        cardType: 'classique',
        rang: 'A',
        recto: 'Question ?',
        verso: 'Réponse',
        ocrConfidenceScore: 0.9,
        lowConfidence: false,
      );
      final updated = original.copyWith(userFeedback: 'positive');
      expect(updated.userFeedback, 'positive');
      expect(updated.id, original.id);
    });
  });

  group('ItemDetailNotifier.submitPositiveFeedback', () {
    test('appelle submitFeedback et met à jour state', () async {
      final repo = _FakeCollegeDetailRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      final notifier = container.read(itemDetailProvider('college-1:item-1').notifier);
      await container.read(itemDetailProvider('college-1:item-1').future);

      await notifier.submitPositiveFeedback('card-1');

      final cards = container.read(itemDetailProvider('college-1:item-1')).valueOrNull!;
      final updated = cards.firstWhere((c) => c.id == 'card-1');
      expect(updated.userFeedback, 'positive');
      // L'autre card n'est pas modifiée
      final unchanged = cards.firstWhere((c) => c.id == 'card-2');
      expect(unchanged.userFeedback, isNull);
    });
  });

  group('ItemDetailNotifier.deleteCard', () {
    test('retire la card de la liste', () async {
      final repo = _FakeCollegeDetailRepository();
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(itemDetailProvider('college-1:item-1').future);
      final notifier = container.read(itemDetailProvider('college-1:item-1').notifier);

      await notifier.deleteCard('card-1');

      final cards = container.read(itemDetailProvider('college-1:item-1')).valueOrNull!;
      expect(cards.any((c) => c.id == 'card-1'), isFalse);
      expect(cards.any((c) => c.id == 'card-2'), isTrue);
    });
  });

  group('ItemDetailNotifier.regenerateCard', () {
    test('remplace la card par la nouvelle', () async {
      final newCard = _card1.copyWith(recto: 'Question régénérée ?', verso: 'Nouvelle réponse');
      final repo = _FakeCollegeDetailRepository(regeneratedCard: newCard);
      final container = _makeContainer(repo);
      addTearDown(container.dispose);

      await container.read(itemDetailProvider('college-1:item-1').future);
      final notifier = container.read(itemDetailProvider('college-1:item-1').notifier);

      final result = await notifier.regenerateCard('card-1', userNote: 'Feedback');

      expect(result.recto, 'Question régénérée ?');
      final cards = container.read(itemDetailProvider('college-1:item-1')).valueOrNull!;
      final replaced = cards.firstWhere((c) => c.id == 'card-1');
      expect(replaced.recto, 'Question régénérée ?');
    });
  });
}

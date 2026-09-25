import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/colleges/domain/college_detail_models.dart';

FlashCardModel _card(String id, String type, String rang) => FlashCardModel(
      id: id, itemId: 'i1', collegeId: 'c3', cardType: type, rang: rang,
      recto: 'Q $id', verso: 'R $id', ocrConfidenceScore: 1, lowConfidence: false,
    );

void main() {
  test('liste des fiches : classique, cas clinique, définition ; puis rang de la fiche ; sinon ordre reçu', () {
    final sorted = sortCardsForList([
      _card('d-a', 'definition', 'A'),
      _card('cc-b', 'cas_clinique', 'B'),
      _card('cl-b', 'classique', 'B'),
      _card('cc-a', 'cas_clinique', 'A'),
      _card('cl-a1', 'classique', 'A'),
      _card('cl-a2', 'classique', 'A'),
    ]);
    expect(sorted.map((c) => c.id), ['cl-a1', 'cl-a2', 'cl-b', 'cc-a', 'cc-b', 'd-a']);
  });

  test('type inconnu (ancien serveur) : rangé avec les classiques', () {
    final sorted = sortCardsForList([_card('d', 'definition', 'A'), _card('q', 'qa', 'A')]);
    expect(sorted.map((c) => c.id), ['q', 'd']);
  });
}

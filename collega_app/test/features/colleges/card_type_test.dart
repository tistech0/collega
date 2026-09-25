import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/colleges/domain/card_type.dart';

void main() {
  test('card_type → type ; inconnu ou absent : classique', () {
    expect(CardType.parse('classique'), CardType.classique);
    expect(CardType.parse('cas_clinique'), CardType.casClinique);
    expect(CardType.parse('definition'), CardType.definition);
    expect(CardType.parse('qa'), CardType.classique);
    expect(CardType.parse(null), CardType.classique);
  });

  test('libellés : rien pour la classique', () {
    expect(CardType.classique.label, isNull);
    expect(CardType.casClinique.label, 'Cas clinique');
    expect(CardType.definition.label, 'Définition');
  });
}

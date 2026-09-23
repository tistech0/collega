import 'package:collega_app/features/colleges/domain/item_title.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('itemDisplayTitle (story 8.0)', () {
    test('renvoie le titre quand il existe', () {
      expect(itemDisplayTitle(310, 'Tumeurs du testicule'), 'Tumeurs du testicule');
    });

    test('replie sur « Item N » si le titre est nul', () {
      expect(itemDisplayTitle(310, null), 'Item 310');
    });

    test('traite une chaîne vide ou blanche comme nulle', () {
      expect(itemDisplayTitle(310, ''), 'Item 310');
      expect(itemDisplayTitle(310, '   '), 'Item 310');
    });

    test('nettoie les espaces autour du titre', () {
      expect(itemDisplayTitle(75, '  Addiction au tabac '), 'Addiction au tabac');
    });
  });

  group('itemFullLabel', () {
    test('numéro et titre', () {
      expect(itemFullLabel(310, 'Tumeurs du testicule'), 'Item 310 · Tumeurs du testicule');
    });

    test('numéro seul, sans séparateur pendant, si pas de titre', () {
      expect(itemFullLabel(310, ''), 'Item 310');
      expect(itemFullLabel(310, null), 'Item 310');
    });
  });

  group('hasItemTitle', () {
    test('faux pour nul, vide ou blanc', () {
      expect(hasItemTitle(null), isFalse);
      expect(hasItemTitle(''), isFalse);
      expect(hasItemTitle('  '), isFalse);
      expect(hasItemTitle('Pneumothorax'), isTrue);
    });
  });
}

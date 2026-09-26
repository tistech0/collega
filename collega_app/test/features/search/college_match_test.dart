// collega_app/test/features/search/college_match_test.dart
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/search/domain/college_match.dart';

final _all = [for (final c in kCollegeCatalog) CollegeListEntry(catalog: c)];

List<String> _names(String q) => matchColleges(q, _all).map((e) => e.catalog.name).toList();

void main() {
  group('foldForSearch', () {
    test('minuscules, sans accents, ligatures', () {
      expect(foldForSearch('Gynécologie-Obstétrique'), 'gynecologie obstetrique');
      expect(foldForSearch('Cœur ÆTHER'), 'coeur aether');
    });

    test('apostrophes, tirets et espaces multiples → un espace', () {
      expect(foldForSearch("  Médecine d'urgence "), 'medecine d urgence');
      expect(foldForSearch('Médecine d’urgence'), 'medecine d urgence');
      expect(foldForSearch('Médecine intensive – Réanimation'), 'medecine intensive reanimation');
    });
  });

  group('matchColleges', () {
    test('préfixe du nom', () {
      expect(_names('neuro'), ['Neurochirurgie', 'Neurologie']);
    });

    test('sans accents ni casse', () {
      expect(_names('GYNECO'), ['Gynécologie-Obstétrique']);
      expect(_names('gyneco obstetrique'), ['Gynécologie-Obstétrique']);
      expect(_names('MEDECINE d urgence'), ["Médecine d'urgence"]);
    });

    test('par éditeur', () {
      expect(_names('cngof'), ['Gynécologie-Obstétrique']);
    });

    test('les noms qui commencent par le terme d’abord, puis ceux qui le contiennent', () {
      final names = _names('chirurgie');
      expect(names.take(2), ['Chirurgie générale, viscérale et digestive', 'Chirurgie maxillo-faciale et stomatologie']);
      expect(names.skip(2), containsAll(['Médecine et chirurgie vasculaire', 'Neurochirurgie', 'ORL et chirurgie cervico-faciale']));
    });

    test('un nom court en majuscules', () {
      expect(_names('orl'), ['ORL et chirurgie cervico-faciale']);
    });

    test('vide, espaces ou rien de trouvé → liste vide', () {
      expect(_names(''), isEmpty);
      expect(_names('   '), isEmpty);
      expect(_names('xyz'), isEmpty);
    });

    test('garde le statut de l’entrée', () {
      const status = UserCollegeStatus(
        refId: 26, collegeId: 'c26', status: 'generation_complete', cardCountA: 1, cardCountB: 0, cardCountC: 0,
      );
      final entries = [
        for (final c in kCollegeCatalog) CollegeListEntry(catalog: c, userStatus: c.refId == 26 ? status : null),
      ];
      final neuro = matchColleges('neurologie', entries).single;
      expect(neuro.userStatus, same(status));
    });
  });
}

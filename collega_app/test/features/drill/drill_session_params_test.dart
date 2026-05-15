import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/drill/domain/drill_session_state.dart';

void main() {
  group('DrillSessionParams — non-régression itemId nullable', () {
    test('avec itemId non-null → compile et fonctionne comme Story 4.2', () {
      const params = DrillSessionParams(
        collegeId: 'c1',
        itemId: 'i1',
        itemName: 'Myocardite',
      );
      expect(params.collegeId, 'c1');
      expect(params.itemId, 'i1');
      expect(params.onlyARevoir, false);
    });

    test('avec itemId null → compile sans erreur', () {
      const params = DrillSessionParams(
        collegeId: 'c1',
        itemId: null,
        itemName: 'Cardiologie',
      );
      expect(params.collegeId, 'c1');
      expect(params.itemId, isNull);
    });

    test('sans itemId (omis) → itemId est null', () {
      const params = DrillSessionParams(collegeId: 'c1');
      expect(params.itemId, isNull);
    });

    test('égalité — deux params identiques sont égaux', () {
      const a = DrillSessionParams(collegeId: 'c1', itemId: 'i1');
      const b = DrillSessionParams(collegeId: 'c1', itemId: 'i1');
      expect(a, equals(b));
    });

    test('égalité — itemId null vs non-null → pas égaux', () {
      const a = DrillSessionParams(collegeId: 'c1', itemId: null);
      const b = DrillSessionParams(collegeId: 'c1', itemId: 'i1');
      expect(a, isNot(equals(b)));
    });

    test('hashCode — params identiques ont le même hashCode', () {
      const a = DrillSessionParams(collegeId: 'c1', itemId: 'i1');
      const b = DrillSessionParams(collegeId: 'c1', itemId: 'i1');
      expect(a.hashCode, equals(b.hashCode));
    });

    test('onlyARevoir dérivé de la config', () {
      const p = DrillSessionParams(
        collegeId: 'c1',
        onlyARevoir: true,
      );
      expect(p.onlyARevoir, true);
    });

    test('maxCards défaut = 0 (toutes les fiches)', () {
      const p = DrillSessionParams(collegeId: 'c1');
      expect(p.maxCards, 0);
    });

    test('maxCards inclus dans égalité', () {
      const a = DrillSessionParams(collegeId: 'c1', maxCards: 50);
      const b = DrillSessionParams(collegeId: 'c1', maxCards: 100);
      expect(a, isNot(equals(b)));
    });

    test('maxCards identique → params égaux', () {
      const a = DrillSessionParams(collegeId: 'c1', maxCards: 50);
      const b = DrillSessionParams(collegeId: 'c1', maxCards: 50);
      expect(a, equals(b));
    });
  });
}

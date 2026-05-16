import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/colleges/domain/drill_stats.dart';

void main() {
  group('DrillStats', () {
    test('masteryPercent est 0 si total == 0', () {
      const stats = DrillStats();
      expect(stats.masteryPercent, 0);
      expect(stats.total, 0);
    });

    test('masteryPercent est 50 si maitrise=5, total=10', () {
      const stats = DrillStats(maitrise: 5, bien: 3, aRevoir: 2);
      expect(stats.total, 10);
      expect(stats.masteryPercent, 50);
    });

    test('masteryPercent est 100 si tout maîtrisé', () {
      const stats = DrillStats(maitrise: 10);
      expect(stats.masteryPercent, 100);
    });

    test('masteryPercent arrondi à l\'entier le plus proche', () {
      const stats = DrillStats(maitrise: 1, bien: 0, aRevoir: 0, notSeen: 2);
      expect(stats.total, 3);
      expect(stats.masteryPercent, 33);
    });

    test('total = somme des 4 catégories', () {
      const stats = DrillStats(maitrise: 1, bien: 2, aRevoir: 3, notSeen: 4);
      expect(stats.total, 10);
    });
  });
}

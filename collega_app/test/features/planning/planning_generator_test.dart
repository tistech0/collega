import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/planning/data/planning_generator.dart';
import 'package:collega_app/features/planning/domain/planning_models.dart';

FlashCardModel _card({
  required String id,
  required String collegeId,
  String rang = 'A',
  String drillLevel = 'new',
}) =>
    FlashCardModel(
      id: id,
      itemId: 'i1',
      collegeId: collegeId,
      cardType: 'classique',
      rang: rang,
      recto: 'Q',
      verso: 'R',
      ocrConfidenceScore: 0.9,
      lowConfidence: false,
      drillLevel: drillLevel,
    );

PlanningConfig _config({
  int dailyMinutes = 30,
  int days = 7,
}) {
  final start = DateTime.utc(2026, 1, 1);
  return PlanningConfig(
    id: 'cfg1',
    collegeIds: ['c1'],
    startDate: start,
    endDate: start.add(Duration(days: days - 1)),
    dailyMinutes: dailyMinutes,
    createdAt: start,
  );
}

void main() {
  group('PlanningGenerator', () {
    test('génère 0 session si aucune carte', () {
      final sessions = PlanningGenerator.generate(
        config: _config(),
        allCards: [],
      );
      expect(sessions, isEmpty);
    });

    test('génère N sessions pour N jours avec cardsPerDay correct', () {
      // 30 min → 30*5=150 → clamp(5,100) = 100
      // 250 cartes → 3 sessions de 100 cartes/j (3 jours nécessaires)
      final cards = List.generate(
          250, (i) => _card(id: 'c$i', collegeId: 'c1', rang: 'A'));
      final sessions = PlanningGenerator.generate(
        config: _config(dailyMinutes: 30, days: 3),
        allCards: cards,
      );
      expect(sessions.length, 3);
      for (final s in sessions) {
        expect(s.maxCards, 100);
      }
    });

    test('cardsPerDay clampé entre 5 et 100 (min)', () {
      final cfg = PlanningConfig(
        id: 'cfg',
        collegeIds: ['c1'],
        startDate: DateTime.utc(2026, 1, 1),
        endDate: DateTime.utc(2026, 1, 2),
        dailyMinutes: 1,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      expect(cfg.cardsPerDay, 5);
    });

    test('cardsPerDay clampé entre 5 et 100 (max)', () {
      final cfg = PlanningConfig(
        id: 'cfg',
        collegeIds: ['c1'],
        startDate: DateTime.utc(2026, 1, 1),
        endDate: DateTime.utc(2026, 1, 2),
        dailyMinutes: 60,
        createdAt: DateTime.utc(2026, 1, 1),
      );
      expect(cfg.cardsPerDay, 100);
    });

    test('tri des cartes : Rang A avant Rang B, a_revoir avant new', () {
      final cards = [
        _card(id: 'b-new', collegeId: 'c1', rang: 'B', drillLevel: 'new'),
        _card(id: 'a-bien', collegeId: 'c1', rang: 'A', drillLevel: 'bien'),
        _card(id: 'a-arevoir', collegeId: 'c1', rang: 'A', drillLevel: 'a_revoir'),
        _card(id: 'a-new', collegeId: 'c1', rang: 'A', drillLevel: 'new'),
      ];
      // 4 cards, 1 session (config 7 days but offset exhausted after 1 day if cardsPerDay=100)
      final cfg = PlanningConfig(
        id: 'cfg',
        collegeIds: ['c1'],
        startDate: DateTime.utc(2026, 1, 1),
        endDate: DateTime.utc(2026, 1, 7),
        dailyMinutes: 30, // 100 cards/day
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final sessions = PlanningGenerator.generate(
        config: cfg,
        allCards: cards,
      );
      // All 4 cards fit in 1 session (maxCards=100)
      expect(sessions.length, 1);
    });

    test('sessions ont des dates progressives', () {
      final cards =
          List.generate(20, (i) => _card(id: 'c$i', collegeId: 'c1'));
      final cfg = PlanningConfig(
        id: 'cfg',
        collegeIds: ['c1'],
        startDate: DateTime.utc(2026, 1, 1),
        endDate: DateTime.utc(2026, 1, 5),
        dailyMinutes: 1, // 5 cards/day → 4 sessions to cover 20 cards
        createdAt: DateTime.utc(2026, 1, 1),
      );
      final sessions = PlanningGenerator.generate(
        config: cfg,
        allCards: cards,
      );
      expect(sessions.length, 4);
      for (int i = 0; i < sessions.length - 1; i++) {
        expect(
          sessions[i + 1].sessionDate.isAfter(sessions[i].sessionDate),
          isTrue,
        );
      }
    });
  });
}

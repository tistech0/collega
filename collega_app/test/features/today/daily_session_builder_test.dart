import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/today/domain/daily_session_builder.dart';

final _now = DateTime(2026, 9, 22, 20);
int _ms(DateTime d) => d.millisecondsSinceEpoch;

SessionCard _card(String id, {String college = 'c1', String rang = 'A', String level = 'new', DateTime? next}) =>
    SessionCard(id: id, collegeId: college, rang: rang, drillLevel: level, nextReviewAtMs: next == null ? null : _ms(next));

void main() {
  group('buildDailySession — ordre (spec : à revoir d’abord, puis nouvelles A → B → C)', () {
    test('à revoir d’abord (plus ancienne échéance d’abord), puis dues, puis nouvelles', () {
      final cards = [
        _card('new-a', rang: 'A'),
        _card('rev-late', level: 'a_revoir', next: _now.subtract(const Duration(hours: 1))),
        _card('bien-due', level: 'bien', next: _now.subtract(const Duration(days: 1))),
        _card('rev-old', level: 'a_revoir', next: _now.subtract(const Duration(days: 3))),
      ];
      final ids = buildDailySession(cards, budget: 10, now: _now).map((c) => c.id).toList();
      expect(ids, ['rev-old', 'rev-late', 'bien-due', 'new-a']);
    });

    test('nouvelles par rang A → B → C', () {
      final cards = [_card('c', rang: 'C'), _card('b', rang: 'B'), _card('a', rang: 'A')];
      expect(buildDailySession(cards, budget: 10, now: _now).map((c) => c.id), ['a', 'b', 'c']);
    });

    test('dans un même rang, les collèges alternent (session mixte)', () {
      final cards = [
        _card('c1-1', college: 'c1'), _card('c1-2', college: 'c1'), _card('c1-3', college: 'c1'),
        _card('c2-1', college: 'c2'),
      ];
      expect(
        buildDailySession(cards, budget: 10, now: _now).map((c) => c.id),
        ['c1-1', 'c2-1', 'c1-2', 'c1-3'],
      );
    });

    test('bien / maîtrisé pas encore dus : exclus', () {
      final cards = [
        _card('bien-later', level: 'bien', next: _now.add(const Duration(days: 1))),
        _card('maitrise-later', level: 'maitrise', next: _now.add(const Duration(days: 7))),
        _card('new'),
      ];
      expect(buildDailySession(cards, budget: 10, now: _now).map((c) => c.id), ['new']);
    });

    test('tronqué au budget', () {
      final cards = [for (var i = 0; i < 40; i++) _card('n$i')];
      expect(buildDailySession(cards, budget: 24, now: _now), hasLength(24));
    });

    test('filtre collèges (planning / personnaliser)', () {
      final cards = [_card('x', college: 'c1'), _card('y', college: 'c2')];
      expect(
        buildDailySession(cards, budget: 10, now: _now, collegeIds: {'c2'}).map((c) => c.id),
        ['y'],
      );
    });

    test('filtres personnaliser : rangs et statut', () {
      final cards = [
        _card('a-new', rang: 'A'),
        _card('b-new', rang: 'B'),
        _card('a-rev', rang: 'A', level: 'a_revoir', next: _now),
      ];
      expect(buildDailySession(cards, budget: 10, now: _now, rangs: {'A'}).map((c) => c.id), ['a-rev', 'a-new']);
      expect(buildDailySession(cards, budget: 10, now: _now, status: SessionStatusFilter.toReview).map((c) => c.id), ['a-rev']);
      expect(buildDailySession(cards, budget: 10, now: _now, status: SessionStatusFilter.unseen).map((c) => c.id), ['a-new', 'b-new']);
    });

    test('aucune fiche : session vide', () {
      expect(buildDailySession(const [], budget: 24, now: _now), isEmpty);
    });
  });

  group('budget et durée — 1 fiche ≈ 50 s (maquette : 24 fiches · 20 min)', () {
    test('planning : minutes/jour → fiches', () {
      expect(sessionBudget(dailyMinutes: 20), 24);
      expect(sessionBudget(dailyMinutes: 30), 36);
    });

    test('sans planning : préférence, sinon 24', () {
      expect(sessionBudget(preferredMaxCards: 15), 15);
      expect(sessionBudget(), 24);
      expect(sessionBudget(preferredMaxCards: 0), 24);
    });

    test('le planning prime sur la préférence', () {
      expect(sessionBudget(dailyMinutes: 20, preferredMaxCards: 5), 24);
    });

    test('durée estimée arrondie à la minute supérieure, au moins 1', () {
      expect(estimatedMinutes(24), 20);
      expect(estimatedMinutes(1), 1);
      expect(estimatedMinutes(0), 0);
    });
  });
}

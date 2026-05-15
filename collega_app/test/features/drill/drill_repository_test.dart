import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/drill/data/drill_repository.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';

AppDatabase _makeDb() => AppDatabase.forTesting(NativeDatabase.memory());

Future<void> _insertCard(
  AppDatabase db, {
  required String id,
  required String itemId,
  String rang = 'A',
  String drillLevel = 'new',
}) async {
  await db.into(db.flashCards).insert(FlashCardsCompanion.insert(
        id: id,
        itemId: itemId,
        collegeId: 'c1',
        cardType: 'classique',
        rang: rang,
        recto: 'Q',
        verso: 'R',
      ));
  if (drillLevel != 'new') {
    await (db.update(db.flashCards)..where((t) => t.id.equals(id))).write(
      FlashCardsCompanion(drillLevel: Value(drillLevel)),
    );
  }
}

void main() {
  group('DrillRepository', () {
    test('getCardsForDrill — retourne les fiches sans réseau', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final repo = DrillRepository(dio: Dio(), db: db);

      await _insertCard(db, id: 'c1', itemId: 'i1');
      await _insertCard(db, id: 'c2', itemId: 'i1');
      await _insertCard(db, id: 'other', itemId: 'i2');

      final cards = await repo.getCardsForDrill(collegeId: 'c1', itemId: 'i1');
      expect(cards.length, 2);
      expect(cards.map((c) => c.id), containsAll(['c1', 'c2']));
    });

    test('updateCardDrillLevel(bien) → drillLevel=bien, nextReviewAt≈now+1j',
        () async {
      final db = _makeDb();
      addTearDown(db.close);
      final repo = DrillRepository(dio: Dio(), db: db);

      await _insertCard(db, id: 'card', itemId: 'i1');
      final beforeMs = DateTime.now().toUtc().millisecondsSinceEpoch;

      await repo.updateCardDrillLevel('card', DrillEvaluationResult.bien);

      final row = await (db.select(db.flashCards)
            ..where((t) => t.id.equals('card')))
          .getSingle();
      expect(row.drillLevel, 'bien');
      expect(row.nextReviewAt, isNotNull);
      final diff = row.nextReviewAt! - beforeMs;
      expect(diff, greaterThanOrEqualTo(86400000 - 1000));
      expect(diff, lessThanOrEqualTo(86400000 + 5000));
    });

    test('updateCardDrillLevel(maitrise) → nextReviewAt≈now+7j', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final repo = DrillRepository(dio: Dio(), db: db);

      await _insertCard(db, id: 'card', itemId: 'i1');
      final beforeMs = DateTime.now().toUtc().millisecondsSinceEpoch;

      await repo.updateCardDrillLevel('card', DrillEvaluationResult.maitrise);

      final row = await (db.select(db.flashCards)
            ..where((t) => t.id.equals('card')))
          .getSingle();
      expect(row.drillLevel, 'maitrise');
      final diff = row.nextReviewAt! - beforeMs;
      expect(diff, greaterThanOrEqualTo(7 * 86400000 - 1000));
      expect(diff, lessThanOrEqualTo(7 * 86400000 + 5000));
    });

    test('updateCardDrillLevel incrémente reviewCount (fix D7)', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final repo = DrillRepository(dio: Dio(), db: db);

      await _insertCard(db, id: 'card', itemId: 'i1');

      // Premier review
      await repo.updateCardDrillLevel('card', DrillEvaluationResult.bien);
      final row1 = await (db.select(db.flashCards)
            ..where((t) => t.id.equals('card')))
          .getSingle();
      expect(row1.reviewCount, 1);

      // Deuxième review
      await repo.updateCardDrillLevel('card', DrillEvaluationResult.maitrise);
      final row2 = await (db.select(db.flashCards)
            ..where((t) => t.id.equals('card')))
          .getSingle();
      expect(row2.reviewCount, 2);
    });
  });
}

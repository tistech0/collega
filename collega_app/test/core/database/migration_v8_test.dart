import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';

void main() {
  test('migration v7 → v8 : review_log gagne `daily`, les lignes existantes restent au bilan du jour', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
      raw.execute('CREATE TABLE review_log ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, card_id TEXT NOT NULL, college_id TEXT NOT NULL, '
          'rang TEXT NOT NULL, drill_level TEXT NOT NULL, reviewed_at_ms INTEGER NOT NULL, day INTEGER NOT NULL)');
      raw.execute("INSERT INTO review_log (card_id, college_id, rang, drill_level, reviewed_at_ms, day) "
          "VALUES ('k1', 'c1', 'A', 'bien', 0, 20000)");
      // Tables présentes sur toute base réelle ≥ v7 (la migration v10 les modifie).
      raw.execute('CREATE TABLE items (id TEXT NOT NULL PRIMARY KEY, college_id TEXT NOT NULL, '
          'item_number INTEGER NOT NULL, rang TEXT NOT NULL, chapter_title TEXT NULL, '
          'ocr_confidence_score REAL NOT NULL DEFAULT 0.0, low_confidence INTEGER NOT NULL DEFAULT 0)');
      raw.execute('CREATE TABLE user_colleges (ref_id INTEGER NOT NULL PRIMARY KEY, college_id TEXT NOT NULL, '
          'status TEXT NOT NULL, card_count_a INTEGER NOT NULL, card_count_b INTEGER NOT NULL, '
          'card_count_c INTEGER NOT NULL)');
      raw.execute('PRAGMA user_version = 7');
    }));
    addTearDown(db.close);

    final rows = await db.select(db.reviewLog).get();
    expect(rows.single.daily, isTrue);
    await db.into(db.reviewLog).insert(ReviewLogCompanion.insert(
          cardId: 'k2', collegeId: 'c1', rang: 'A', drillLevel: 'maitrise', reviewedAtMs: 1, day: 20000,
        ));
    expect((await db.select(db.reviewLog).get()).length, 2);
  });
}

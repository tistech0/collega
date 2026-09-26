import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';

void main() {
  test('migration v9 → v10 : items gagnent leurs pages, user_colleges la version du PDF', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
      raw.execute('CREATE TABLE items (id TEXT NOT NULL PRIMARY KEY, college_id TEXT NOT NULL, '
          'item_number INTEGER NOT NULL, rang TEXT NOT NULL, chapter_title TEXT NULL, '
          'ocr_confidence_score REAL NOT NULL DEFAULT 0.0, low_confidence INTEGER NOT NULL DEFAULT 0)');
      raw.execute("INSERT INTO items (id, college_id, item_number, rang) VALUES ('i1', 'c1', 340, 'A')");
      raw.execute('CREATE TABLE user_colleges (ref_id INTEGER NOT NULL PRIMARY KEY, college_id TEXT NOT NULL, '
          'status TEXT NOT NULL, card_count_a INTEGER NOT NULL, card_count_b INTEGER NOT NULL, '
          'card_count_c INTEGER NOT NULL)');
      raw.execute("INSERT INTO user_colleges VALUES (26, 'c1', 'generation_complete', 1, 0, 0)");
      raw.execute('PRAGMA user_version = 9');
    }));
    addTearDown(db.close);

    final item = await db.select(db.items).getSingle();
    expect(item.startPage, isNull);
    expect(item.endPage, isNull);
    final college = await db.select(db.userColleges).getSingle();
    expect(college.pdfVersion, isNull);
    expect(college.pdfSize, isNull);
  });
}

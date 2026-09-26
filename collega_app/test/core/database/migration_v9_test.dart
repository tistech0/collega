import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';

void main() {
  test('migration v8 → v9 : quiet_days créée, les sessions existantes intactes', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
      raw.execute('CREATE TABLE daily_sessions ('
          'day INTEGER NOT NULL PRIMARY KEY, queue_json TEXT NOT NULL, position INTEGER NOT NULL DEFAULT 0, '
          'settings_json TEXT NULL, started_at_ms INTEGER NULL, completed_at_ms INTEGER NULL)');
      raw.execute("INSERT INTO daily_sessions (day, queue_json, completed_at_ms) VALUES (20000, '[]', 1)");
      raw.execute('PRAGMA user_version = 8');
    }));
    addTearDown(db.close);

    expect((await db.select(db.dailySessions).get()).single.day, 20000);
    await db.into(db.quietDays).insert(QuietDaysCompanion.insert(day: const Value(20001)));
    expect((await db.select(db.quietDays).get()).single.day, 20001);
  });

  test('deleteEverything vide aussi les jours calmes (changement de compte)', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.quietDays).insert(QuietDaysCompanion.insert(day: const Value(20001)));
    await db.deleteEverything();
    expect(await db.select(db.quietDays).get(), isEmpty);
  });
}

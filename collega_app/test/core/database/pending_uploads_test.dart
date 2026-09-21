import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';

void main() {
  test('pending_uploads : insert/read/delete et deleteEverything', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.into(db.pendingUploads).insert(PendingUploadsCompanion.insert(
          uploadId: 'u1',
          refId: 3,
          filePath: '/tmp/x.pdf',
          sizeBytes: 100,
          partSize: 25,
          partsTotal: 4,
          createdAt: DateTime.utc(2026, 9, 21),
        ));
    final rows = await db.select(db.pendingUploads).get();
    expect(rows.single.partsTotal, 4);

    await db.deleteEverything();
    expect(await db.select(db.pendingUploads).get(), isEmpty);
  });
}

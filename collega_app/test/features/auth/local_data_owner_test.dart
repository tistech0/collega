import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/auth/data/local_data_owner.dart';
import 'package:collega_app/features/search/search_providers.dart';

/// Revue 8.3 — la progression n'existe qu'en local : on ne l'efface que si un
/// AUTRE compte se connecte sur l'appareil (jamais pour le même étudiant).
void main() {
  late AppDatabase db;
  const storage = FlutterSecureStorage();

  Future<void> seed() => db.into(db.userColleges).insert(UserCollegesCompanion.insert(
        refId: const Value(3), collegeId: 'c3', status: 'generation_complete', cardCountA: 1, cardCountB: 0, cardCountC: 0,
      ));

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  test('premier propriétaire (installation existante) : rien n’est effacé', () async {
    await seed();
    await LocalDataOwner(storage: storage, db: db).claim('u1');
    expect(await db.select(db.userColleges).get(), hasLength(1));
  });

  test('même compte qui se reconnecte : progression conservée', () async {
    final owner = LocalDataOwner(storage: storage, db: db);
    await owner.claim('u1');
    await seed();
    await owner.claim('u1');
    expect(await db.select(db.userColleges).get(), hasLength(1));
  });

  test('autre compte : les données locales du précédent sont effacées', () async {
    final owner = LocalDataOwner(storage: storage, db: db);
    await owner.claim('u1');
    await seed();
    await owner.claim('u2');
    expect(await db.select(db.userColleges).get(), isEmpty);
    expect(await storage.read(key: LocalDataOwner.storageKey), 'u2');
  });

  test('autre compte : ses recherches récentes ne sont plus proposées (revue 8.10)', () async {
    final owner = LocalDataOwner(storage: storage, db: db);
    await owner.claim('u1');
    await storage.write(key: SecureSearchRecentsStore.storageKey, value: '["BNP"]');
    await owner.claim('u1');
    expect(await storage.read(key: SecureSearchRecentsStore.storageKey), '["BNP"]');
    await owner.claim('u2');
    expect(await storage.read(key: SecureSearchRecentsStore.storageKey), isNull);
  });
}

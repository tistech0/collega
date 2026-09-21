import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/colleges/colleges_detail_providers.dart';
import 'package:collega_app/features/colleges/domain/drill_stats.dart';

FlashCardsCompanion _card(String id, String itemId,
        {String collegeId = 'college-1', String drillLevel = 'new'}) =>
    FlashCardsCompanion.insert(
      id: id,
      itemId: itemId,
      collegeId: collegeId,
      cardType: 'qcm',
      rang: 'A',
      recto: 'r',
      verso: 'v',
      drillLevel: Value(drillLevel),
    );

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('collegeDrillStatsByItemProvider', () {
    test('agrège les fiches locales par item pour le collège demandé',
        () async {
      await db.batch((b) => b.insertAll(db.flashCards, [
            _card('c1', 'item-1', drillLevel: 'maitrise'),
            _card('c2', 'item-1', drillLevel: 'bien'),
            _card('c3', 'item-1'),
            _card('c4', 'item-2', drillLevel: 'a_revoir'),
            _card('c5', 'item-9', collegeId: 'other'),
          ]));

      final stats = await container
          .read(collegeDrillStatsByItemProvider('college-1').future);

      expect(stats.keys, unorderedEquals(['item-1', 'item-2']));
      expect(stats['item-1'],
          const DrillStats(maitrise: 1, bien: 1, aRevoir: 0, notSeen: 1));
      expect(stats['item-2'], const DrillStats(aRevoir: 1));
    });

    test('émet une nouvelle valeur quand un drillLevel change (bug S1 : détail figé)',
        () async {
      await db.into(db.flashCards).insert(_card('c1', 'item-1'));
      final sub = container.listen(
        collegeDrillStatsByItemProvider('college-1'),
        (_, __) {},
      );
      await container.read(collegeDrillStatsByItemProvider('college-1').future);
      expect(sub.read().value!['item-1']!.maitrise, 0);

      await (db.update(db.flashCards)..where((t) => t.id.equals('c1')))
          .write(const FlashCardsCompanion(drillLevel: Value('maitrise')));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sub.read().value!['item-1']!.maitrise, 1);
      sub.close();
    });
  });
}

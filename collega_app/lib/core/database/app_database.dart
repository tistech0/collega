import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/college_import_table.dart';
import 'tables/flash_cards_table.dart';
import 'tables/items_table.dart';
import 'tables/planning_configs_table.dart';
import 'tables/planning_sessions_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [CollegeImports, Items, FlashCards, PlanningConfigs, PlanningSessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            // P3: collegeImports était absent de la migration v1→v2
            await m.createTable(collegeImports);
            await m.createTable(items);
            await m.createTable(flashCards);
          }
          // P2: uniquement si la table existe déjà sans userFeedback (from=2)
          // Si from<2, m.createTable(flashCards) a déjà créé la colonne (schéma actuel)
          if (from >= 2 && from < 3) {
            await m.addColumn(flashCards, flashCards.userFeedback);
          }
          if (from < 4) {
            await m.addColumn(flashCards, flashCards.drillLevel);
            await m.addColumn(flashCards, flashCards.nextReviewAt);
            await m.addColumn(flashCards, flashCards.reviewCount);
          }
          if (from < 5) {
            await m.createTable(planningConfigs);
            await m.createTable(planningSessions);
          }
        },
      );

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'collega.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() async => db.close());
  return db;
});

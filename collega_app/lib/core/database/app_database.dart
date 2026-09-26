import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/college_import_table.dart';
import 'tables/daily_sessions_table.dart';
import 'tables/flash_cards_table.dart';
import 'tables/items_table.dart';
import 'tables/pending_uploads_table.dart';
import 'tables/planning_configs_table.dart';
import 'tables/planning_sessions_table.dart';
import 'tables/quiet_days_table.dart';
import 'tables/review_log_table.dart';
import 'tables/user_colleges_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  CollegeImports, Items, FlashCards, PlanningConfigs, PlanningSessions, PendingUploads,
  DailySessions, ReviewLog, UserColleges, QuietDays,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 10;

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
          // Même garde : depuis v1, createTable(flashCards) a déjà ces colonnes.
          if (from >= 2 && from < 4) {
            await m.addColumn(flashCards, flashCards.drillLevel);
            await m.addColumn(flashCards, flashCards.nextReviewAt);
            await m.addColumn(flashCards, flashCards.reviewCount);
          }
          if (from < 5) {
            await m.createTable(planningConfigs);
            await m.createTable(planningSessions);
          }
          if (from < 6) {
            // Story 7.11 : reprise d'upload par morceaux
            await m.createTable(pendingUploads);
          }
          if (from < 7) {
            // Story 8.3 : session du jour figée + journal des verdicts
            await m.createTable(dailySessions);
            await m.createTable(reviewLog);
            await m.createTable(userColleges);
          }
          if (from >= 7 && from < 8) {
            // Story 8.8 : toutes les révisions sont journalisées (semaine de
            // Progression) ; les lignes existantes venaient de la session du jour.
            await m.addColumn(reviewLog, reviewLog.daily);
          }
          if (from < 9) {
            // Partie D : jours « rien à réviser » (série de l'Accueil).
            await m.createTable(quietDays);
          }
          // Partie B : pages des items et version du PDF. `items` existe depuis la
          // v2 et `user_colleges` depuis la v7 : avant, createTable a déjà les colonnes.
          if (from >= 2 && from < 10) {
            await m.addColumn(items, items.startPage);
            await m.addColumn(items, items.endPage);
          }
          if (from >= 7 && from < 10) {
            await m.addColumn(userColleges, userColleges.pdfVersion);
            await m.addColumn(userColleges, userColleges.pdfSize);
          }
        },
      );

  Future<void> deleteEverything() async {
    await transaction(() async {
      await delete(collegeImports).go();
      await delete(items).go();
      await delete(flashCards).go();
      await delete(planningConfigs).go();
      await delete(planningSessions).go();
      await delete(pendingUploads).go();
      await delete(dailySessions).go();
      await delete(reviewLog).go();
      await delete(userColleges).go();
      await delete(quietDays).go();
    });
  }

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

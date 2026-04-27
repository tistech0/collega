import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Tables Drift ajoutées progressivement dans les stories suivantes
// Story 1.1 : base de données initialisée, sans tables (génération de code en Story 2.1+)
// Story 2.1+ : ajout de @DriftDatabase(tables: [...]) et build_runner

class AppDatabase {
  static AppDatabase? _instance;

  AppDatabase._();

  static AppDatabase get instance => _instance ??= AppDatabase._();

  static LazyDatabase openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'collega.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

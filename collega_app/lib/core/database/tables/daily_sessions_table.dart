import 'package:drift/drift.dart';

/// Session du jour figée (story 8.3) : une ligne par jour local.
@DataClassName('DailySessionRow')
class DailySessions extends Table {
  /// Jour local (`epochDayOf`).
  IntColumn get day => integer()();

  /// File des ids de fiches (JSON), réinsertions « à revoir » comprises.
  TextColumn get queueJson => text()();

  /// Nombre de fiches jugées.
  IntColumn get position => integer().withDefault(const Constant(0))();

  /// Réglages « Personnaliser » (JSON), null = session calculée par défaut.
  TextColumn get settingsJson => text().nullable()();

  IntColumn get startedAtMs => integer().nullable()();
  IntColumn get completedAtMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {day};
}

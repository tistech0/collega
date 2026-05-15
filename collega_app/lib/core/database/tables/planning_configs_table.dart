import 'package:drift/drift.dart';

@DataClassName('PlanningConfigRow')
class PlanningConfigs extends Table {
  TextColumn get id => text()();
  TextColumn get collegeIds => text()();         // JSON: ["uuid1","uuid2"]
  TextColumn get itemIds => text().nullable()(); // JSON ou null = tous les items
  IntColumn get startDateEpochDay => integer()();
  IntColumn get endDateEpochDay => integer()();
  IntColumn get dailyMinutes => integer()();
  IntColumn get createdAtMs => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

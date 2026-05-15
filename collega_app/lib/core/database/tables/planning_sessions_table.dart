import 'package:drift/drift.dart';

@DataClassName('PlanningSessionRow')
class PlanningSessions extends Table {
  TextColumn get id => text()();
  TextColumn get planningConfigId => text()();
  IntColumn get sessionDateEpochDay => integer()();
  TextColumn get collegeId => text()();
  IntColumn get maxCards => integer()();
  TextColumn get status =>
      text().withDefault(const Constant('pending'))();
  // 'pending' | 'completed' | 'postponed'

  @override
  Set<Column> get primaryKey => {id};
}

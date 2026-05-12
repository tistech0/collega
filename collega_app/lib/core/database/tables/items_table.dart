import 'package:drift/drift.dart';

class Items extends Table {
  TextColumn get id => text()();
  TextColumn get collegeId => text()();
  IntColumn get itemNumber => integer()();
  TextColumn get rang => text()();
  TextColumn get chapterTitle => text().nullable()();
  RealColumn get ocrConfidenceScore =>
      real().withDefault(const Constant(0.0))();
  BoolColumn get lowConfidence =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

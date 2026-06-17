import 'package:drift/drift.dart';

class CollegeImports extends Table {
  TextColumn get id => text()(); // UUID backend du College
  IntColumn get refId => integer()(); // ref 1-39 du catalogue
  TextColumn get jobId => text()(); // UUID du GenerationJob
  TextColumn get status => text()(); // pending/processing/ocr_complete/generation_complete/failed
  IntColumn get ocrProgress => integer().withDefault(const Constant(0))();
  IntColumn get totalPages => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

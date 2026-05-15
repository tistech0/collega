import 'package:drift/drift.dart';

class FlashCards extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();
  TextColumn get collegeId => text()();
  TextColumn get cardType => text()();
  TextColumn get rang => text()();
  TextColumn get recto => text()();
  TextColumn get verso => text()();
  RealColumn get ocrConfidenceScore =>
      real().withDefault(const Constant(0.0))();
  BoolColumn get lowConfidence =>
      boolean().withDefault(const Constant(false))();
  TextColumn get userFeedback => text().nullable()();
  TextColumn get drillLevel =>
      text().withDefault(const Constant('new'))();
  IntColumn get nextReviewAt => integer().nullable()();
  IntColumn get reviewCount =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

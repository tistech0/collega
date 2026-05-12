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

  @override
  Set<Column> get primaryKey => {id};
}

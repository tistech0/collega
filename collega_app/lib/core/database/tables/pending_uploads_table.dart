import 'package:drift/drift.dart';

/// Upload par morceaux en cours (Story 7.11) — permet la reprise après relance de l'app.
/// Une seule ligne à la fois (un import par utilisateur).
class PendingUploads extends Table {
  TextColumn get uploadId => text()(); // UUID backend de l'upload
  IntColumn get refId => integer()();
  TextColumn get filePath => text()(); // copie du PDF dans le répertoire de l'app
  IntColumn get sizeBytes => integer()();
  IntColumn get partSize => integer()();
  IntColumn get partsTotal => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {uploadId};
}

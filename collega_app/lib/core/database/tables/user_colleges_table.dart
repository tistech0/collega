import 'package:drift/drift.dart';

/// Derniers collèges connus de l'utilisateur (story 8.3) : Aujourd'hui et la
/// Bibliothèque restent utilisables hors-ligne.
@DataClassName('UserCollegeRow')
class UserColleges extends Table {
  IntColumn get refId => integer()();
  TextColumn get collegeId => text()();
  TextColumn get status => text()();
  IntColumn get cardCountA => integer()();
  IntColumn get cardCountB => integer()();
  IntColumn get cardCountC => integer()();

  /// PDF en service côté serveur (id du dernier job publié) et sa taille (partie B).
  TextColumn get pdfVersion => text().nullable()();
  IntColumn get pdfSize => integer().nullable()();

  @override
  Set<Column> get primaryKey => {refId};
}

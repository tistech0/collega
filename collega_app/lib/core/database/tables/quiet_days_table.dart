import 'package:drift/drift.dart';

/// Jours « rien à réviser » (partie D) : la session du jour vide n'est pas
/// enregistrée, ce jour est noté ici pour ne pas casser la série.
@DataClassName('QuietDayRow')
class QuietDays extends Table {
  /// Jour local (`epochDayOf`).
  IntColumn get day => integer()();

  @override
  Set<Column> get primaryKey => {day};
}

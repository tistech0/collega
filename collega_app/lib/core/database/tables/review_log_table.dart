import 'package:drift/drift.dart';

/// Journal des verdicts (story 8.3) : semaine de Progression, bilan de la session du jour.
@DataClassName('ReviewLogRow')
class ReviewLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get cardId => text()();
  TextColumn get collegeId => text()();
  TextColumn get rang => text()();

  /// Même vocabulaire que `flash_cards.drillLevel` : `a_revoir` | `bien` | `maitrise`.
  TextColumn get drillLevel => text()();
  IntColumn get reviewedAtMs => integer()();

  /// Jour local de la révision (`epochDayOf`), pour les regroupements par jour.
  IntColumn get day => integer()();

  /// Verdict de la session du jour (son bilan) ; `false` : autre révision
  /// (collège, item, recherche, refaire les erreurs), comptée dans la semaine
  /// de Progression seulement (story 8.8).
  BoolColumn get daily => boolean().withDefault(const Constant(true))();
}

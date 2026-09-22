import 'package:drift/drift.dart';

/// Journal des verdicts (story 8.3) : semaine, progression par rang, récap de session.
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
}

import 'package:drift/drift.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';

/// Remplace les fiches locales d'un collège par la liste du serveur (story 8.3),
/// sans toucher à l'état de révision local (`drillLevel`, `nextReviewAt`,
/// `reviewCount`) ni au pouce déjà posé quand le serveur n'en renvoie pas.
/// Les fiches que le serveur n'a plus (supprimées, régénérées) disparaissent.
///
/// Une liste vide ne supprime rien : un collège prêt a toujours des fiches, une
/// liste vide trahit une réponse anormale (et effacerait toute la progression).
Future<void> syncCollegeCards(AppDatabase db, String collegeId, List<FlashCardModel> cards) async {
  if (cards.isEmpty) return;
  await db.transaction(() async {
    await db.batch((batch) {
      for (final c in cards) {
        final content = FlashCardsCompanion(
          itemId: Value(c.itemId),
          collegeId: Value(c.collegeId),
          cardType: Value(c.cardType),
          rang: Value(c.rang),
          recto: Value(c.recto),
          verso: Value(c.verso),
          ocrConfidenceScore: Value(c.ocrConfidenceScore),
          lowConfidence: Value(c.lowConfidence),
          // Pouce : le serveur fait foi s'il en a un, sinon on garde le local.
          userFeedback: c.userFeedback == null ? const Value.absent() : Value(c.userFeedback),
        );
        batch.insert(
          db.flashCards,
          content.copyWith(id: Value(c.id)),
          onConflict: DoUpdate((_) => content),
        );
      }
    });
    final keep = cards.map((c) => c.id).toList();
    await (db.delete(db.flashCards)
          ..where((t) => t.collegeId.equals(collegeId) & t.id.isNotIn(keep)))
        .go();
  });
}

/// Items (titres, rangs) d'un collège, sans toucher aux autres collèges (story 8.5).
Future<void> syncItemsToDrift(AppDatabase db, String collegeId, List<ItemModel> items) async {
  await db.batch((batch) {
    batch.insertAllOnConflictUpdate(
      db.items,
      [
        for (final item in items)
          ItemsCompanion.insert(
            id: item.id,
            collegeId: collegeId,
            itemNumber: item.itemNumber,
            rang: item.rang,
            chapterTitle: Value(item.chapterTitle),
            ocrConfidenceScore: Value(item.ocrConfidenceScore),
            lowConfidence: Value(item.lowConfidence),
          ),
      ],
    );
  });
}

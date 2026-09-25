import 'dart:convert';

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

/// Oublie le contenu local des collèges que le serveur n'a plus (revue finale du
/// chantier 4 : après un vidage de la prod, « Aujourd'hui » mêlait des fiches
/// mortes — 404 à l'évaluation). À n'appeler qu'après un chargement RÉUSSI de la
/// liste des collèges : [keep] = leurs ids ; une liste vide purge tout.
///
/// Supprimés : fiches, items, imports suivis ; les sessions du jour non terminées
/// qui citent une fiche supprimée (recalculées à la prochaine lecture). Gardés :
/// les sessions terminées (semaine « faite »), le journal des révisions (historique
/// réel de la Progression, jamais renvoyé au serveur) et `planningSessions`, qui ne
/// contient que les jours décalés (`addPostponed`, collegeId vide) — pas une donnée
/// de collège.
Future<void> pruneStaleColleges(AppDatabase db, Set<String> keep) async {
  final ids = keep.toList();
  await db.transaction(() async {
    final deadCards = await (db.selectOnly(db.flashCards)
          ..addColumns([db.flashCards.id])
          ..where(db.flashCards.collegeId.isNotIn(ids)))
        .map((row) => row.read(db.flashCards.id)!)
        .get();
    await (db.delete(db.flashCards)..where((t) => t.collegeId.isNotIn(ids))).go();
    await (db.delete(db.items)..where((t) => t.collegeId.isNotIn(ids))).go();
    await (db.delete(db.collegeImports)..where((t) => t.id.isNotIn(ids))).go();

    if (deadCards.isEmpty) return;
    final dead = deadCards.toSet();
    final open = await (db.select(db.dailySessions)..where((t) => t.completedAtMs.isNull())).get();
    final stale = [
      for (final s in open)
        if (_queueIds(s.queueJson).any(dead.contains)) s.day,
    ];
    if (stale.isNotEmpty) {
      await (db.delete(db.dailySessions)..where((t) => t.day.isIn(stale))).go();
    }
  });
}

/// Ids d'une file de session du jour ; file illisible → aucun id (jamais d'exception
/// dans la transaction de purge).
Iterable<Object?> _queueIds(String queueJson) {
  try {
    final decoded = jsonDecode(queueJson);
    return decoded is List ? decoded : const [];
  } on FormatException {
    return const [];
  }
}

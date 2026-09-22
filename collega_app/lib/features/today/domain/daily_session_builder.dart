/// Moteur de la session du jour (story 8.3, spec v2 § L'expérience définissante).
///
/// Une seule session mixte : les fiches « à revoir » de tous les collèges d'abord,
/// puis celles dont la révision est due, puis les nouvelles par rang A → B → C,
/// jusqu'au budget du jour. Fonction pure : testée sans base ni réseau.
library;

/// 1 fiche ≈ 50 s (maquette : « 24 fiches · 20 min »). Seule convention de durée de l'app.
const kSecondsPerCard = 50;

/// Budget par défaut sans planning ni préférence (≈ 20 min).
const kDefaultSessionCards = 24;

enum SessionStatusFilter { all, toReview, unseen }

/// Ce dont le moteur a besoin d'une fiche (lu depuis Drift).
class SessionCard {
  const SessionCard({
    required this.id,
    required this.collegeId,
    required this.rang,
    required this.drillLevel,
    this.nextReviewAtMs,
  });

  final String id;
  final String collegeId;
  final String rang;

  /// `new` | `a_revoir` | `bien` | `maitrise`.
  final String drillLevel;
  final int? nextReviewAtMs;
}

const _rankOrder = {'A': 0, 'B': 1, 'C': 2};

/// Construit la liste ordonnée des fiches de la session du jour.
List<SessionCard> buildDailySession(
  List<SessionCard> cards, {
  required int budget,
  required DateTime now,
  Set<String>? collegeIds,
  Set<String>? rangs,
  SessionStatusFilter status = SessionStatusFilter.all,
}) {
  final nowMs = now.millisecondsSinceEpoch;
  final pool = cards.where((c) =>
      (collegeIds == null || collegeIds.contains(c.collegeId)) &&
      (rangs == null || rangs.isEmpty || rangs.contains(c.rang)));

  int byDue(SessionCard a, SessionCard b) =>
      (a.nextReviewAtMs ?? 0).compareTo(b.nextReviewAtMs ?? 0);

  final toReview = pool.where((c) => c.drillLevel == 'a_revoir').toList()..sort(byDue);
  final due = pool
      .where((c) =>
          (c.drillLevel == 'bien' || c.drillLevel == 'maitrise') &&
          c.nextReviewAtMs != null &&
          c.nextReviewAtMs! <= nowMs)
      .toList()
    ..sort(byDue);
  final fresh = _interleaveByRank(pool.where((c) => c.drillLevel == 'new').toList());

  final ordered = switch (status) {
    SessionStatusFilter.all => [...toReview, ...due, ...fresh],
    SessionStatusFilter.toReview => toReview,
    SessionStatusFilter.unseen => fresh,
  };
  return ordered.take(budget < 0 ? 0 : budget).toList();
}

/// Nouvelles fiches par rang A → B → C ; dans un rang, les collèges alternent
/// (ordre de première apparition) pour que la session soit vraiment mixte.
List<SessionCard> _interleaveByRank(List<SessionCard> fresh) {
  final result = <SessionCard>[];
  final ranks = fresh.map((c) => c.rang).toSet().toList()
    ..sort((a, b) => (_rankOrder[a] ?? 9).compareTo(_rankOrder[b] ?? 9));
  for (final rank in ranks) {
    final byCollege = <String, List<SessionCard>>{};
    for (final c in fresh.where((c) => c.rang == rank)) {
      byCollege.putIfAbsent(c.collegeId, () => []).add(c);
    }
    final queues = byCollege.values.toList();
    for (var i = 0; queues.any((q) => i < q.length); i++) {
      for (final q in queues) {
        if (i < q.length) result.add(q[i]);
      }
    }
  }
  return result;
}

/// Nombre de fiches du jour : planning (minutes/jour), sinon préférence, sinon 24.
int sessionBudget({int? dailyMinutes, int? preferredMaxCards}) {
  if (dailyMinutes != null && dailyMinutes > 0) {
    return (dailyMinutes * 60 / kSecondsPerCard).round();
  }
  if (preferredMaxCards != null && preferredMaxCards > 0) return preferredMaxCards;
  return kDefaultSessionCards;
}

/// Durée estimée en minutes (arrondie au-dessus).
int estimatedMinutes(int cardCount) =>
    cardCount <= 0 ? 0 : (cardCount * kSecondsPerCard / 60).ceil();

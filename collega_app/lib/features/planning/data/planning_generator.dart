import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/planning/domain/planning_models.dart';

class PlanningGenerator {
  /// Génère les sessions planifiées pour une config donnée.
  /// Règle priorité : Rang A (tous items) → Rang B → Rang C
  /// Au sein d'un rang : a_revoir → new → bien → maitrise
  static List<PlannedSession> generate({
    required PlanningConfig config,
    required List<FlashCardModel> allCards,
  }) {
    var cards = config.itemIds == null
        ? allCards
        : allCards
            .where((c) => config.itemIds!.contains(c.itemId))
            .toList();

    const levelOrder = {'a_revoir': 0, 'new': 1, 'bien': 2, 'maitrise': 3};
    const rangOrder = {'A': 0, 'B': 1, 'C': 2};
    cards = List.from(cards)
      ..sort((a, b) {
        final rA = rangOrder[a.rang] ?? 3;
        final rB = rangOrder[b.rang] ?? 3;
        if (rA != rB) return rA.compareTo(rB);
        final lA = levelOrder[a.drillLevel] ?? 1;
        final lB = levelOrder[b.drillLevel] ?? 1;
        return lA.compareTo(lB);
      });

    if (cards.isEmpty) return [];

    final cardsPerDay = config.cardsPerDay;
    final days = config.endDate.difference(config.startDate).inDays + 1;
    final sessionCollegeId =
        _pickDominantCollege(cards, config.collegeIds);

    final sessions = <PlannedSession>[];
    int offset = 0;
    for (int dayIdx = 0; dayIdx < days; dayIdx++) {
      if (offset >= cards.length) break;
      final sessionDate = config.startDate.add(Duration(days: dayIdx));
      final sessionId = '${config.id}-day-$dayIdx';
      sessions.add(PlannedSession(
        id: sessionId,
        planningConfigId: config.id,
        sessionDate: sessionDate,
        collegeId: sessionCollegeId,
        maxCards: cardsPerDay,
        status: 'pending',
      ));
      offset += cardsPerDay;
    }
    return sessions;
  }

  static String _pickDominantCollege(
      List<FlashCardModel> cards, List<String> collegeIds) {
    if (collegeIds.length == 1) return collegeIds.first;
    final counts = <String, int>{};
    for (final c in cards) {
      if (c.drillLevel == 'a_revoir' || c.drillLevel == 'new') {
        counts[c.collegeId] = (counts[c.collegeId] ?? 0) + 1;
      }
    }
    return counts.entries
        .where((e) => collegeIds.contains(e.key))
        .fold(
          MapEntry(collegeIds.first, 0),
          (best, e) => e.value > best.value ? e : best,
        )
        .key;
  }
}

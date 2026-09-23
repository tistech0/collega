import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/drill_stats.dart';
import 'package:collega_app/features/planning/planning_providers.dart';
import 'package:collega_app/features/today/data/daily_session_repository.dart';

/// Horloge de Progression (injectée en test).
final progressClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

sealed class ProgressState {
  const ProgressState();
}

/// Aucun collège prêt : « Ta première session remplira cette page ».
class ProgressEmpty extends ProgressState {
  const ProgressEmpty();
}

@immutable
class ProgressCollege {
  const ProgressCollege({
    required this.refId,
    required this.collegeId,
    required this.name,
    required this.icon,
    required this.stats,
  });

  final int refId;
  final String collegeId;
  final String name;
  final String icon;
  final DrillStats stats;
}

@immutable
class ProgressDay {
  const ProgressDay({required this.date, required this.count, required this.isToday});

  final DateTime date;
  final int count;
  final bool isToday;
}

class ProgressReady extends ProgressState {
  const ProgressReady({
    required this.overall,
    required this.colleges,
    required this.byRang,
    required this.week,
    required this.planning,
  });

  final DrillStats overall;
  final List<ProgressCollege> colleges;

  /// Rangs qui ont des fiches, dans l'ordre A → B → C.
  final Map<String, DrillStats> byRang;

  /// Lundi → dimanche de la semaine courante.
  final List<ProgressDay> week;
  final PlanningState planning;

  int get weekTotal => week.fold(0, (sum, d) => sum + d.count);
}

DrillStats _sum(Iterable<DrillStats> all) => all.fold(
      const DrillStats(),
      (a, b) => DrillStats(
        maitrise: a.maitrise + b.maitrise,
        bien: a.bien + b.bien,
        aRevoir: a.aRevoir + b.aRevoir,
        notSeen: a.notSeen + b.notSeen,
      ),
    );

/// Onglet Progression (story 8.8) : tout, par collège, par rang, la semaine et
/// le planning. Vivant : se recalcule après chaque verdict ou synchro de fiches
/// (Drift), hors-ligne compris — mises à jour regroupées, et seulement tant que
/// l'onglet est affiché (autoDispose).
final progressProvider = StreamProvider.autoDispose<ProgressState>((ref) async* {
  final entries = await ref.watch(collegesProvider.future);
  final planning = await ref.watch(planningProvider.future);
  final now = ref.watch(progressClockProvider);
  final db = ref.watch(databaseProvider);

  final ready = entries.where((e) => e.isGenerationComplete).toList();
  if (ready.isEmpty) {
    yield const ProgressEmpty();
    return;
  }
  final ids = [for (final e in ready) e.userStatus!.collegeId];

  Future<ProgressReady> compute() async {
    final cards = await (db.select(db.flashCards)..where((t) => t.collegeId.isIn(ids))).get();
    final byCollege = <String, List<String>>{};
    final byRangLevels = <String, List<String>>{};
    for (final c in cards) {
      byCollege.putIfAbsent(c.collegeId, () => []).add(c.drillLevel);
      byRangLevels.putIfAbsent(c.rang, () => []).add(c.drillLevel);
    }
    // Non vues recalées sur le total serveur (fiches pas encore synchronisées).
    final colleges = [
      for (final e in ready)
        ProgressCollege(
          refId: e.catalog.refId,
          collegeId: e.userStatus!.collegeId,
          name: e.catalog.name,
          icon: e.catalog.icon,
          stats: DrillStats.fromDrillLevels(byCollege[e.userStatus!.collegeId] ?? const [])
              .withTotal(e.userStatus!.totalCards),
        ),
    ];
    final serverByRang = {
      'A': ready.fold(0, (s, e) => s + e.userStatus!.cardCountA),
      'B': ready.fold(0, (s, e) => s + e.userStatus!.cardCountB),
      'C': ready.fold(0, (s, e) => s + e.userStatus!.cardCountC),
    };
    final byRang = <String, DrillStats>{};
    for (final rang in const ['A', 'B', 'C']) {
      final local = DrillStats.fromDrillLevels(byRangLevels[rang] ?? const []);
      final stats = local.withTotal(serverByRang[rang]! > local.total ? serverByRang[rang]! : local.total);
      if (stats.total > 0) byRang[rang] = stats;
    }

    final date = now();
    final todayDay = epochDayOf(date);
    final monday = DateTime(date.year, date.month, date.day).subtract(Duration(days: date.weekday - DateTime.monday));
    final mondayDay = epochDayOf(monday);
    final counts = await DailySessionRepository(db).weekCounts(from: mondayDay, to: mondayDay + 6);

    return ProgressReady(
      overall: _sum(colleges.map((c) => c.stats)),
      colleges: colleges,
      byRang: byRang,
      week: [
        for (var i = 0; i < 7; i++)
          ProgressDay(
            date: DateTime(monday.year, monday.month, monday.day + i),
            count: counts[mondayDay + i] ?? 0,
            isToday: mondayDay + i == todayDay,
          ),
      ],
      planning: planning,
    );
  }

  // Abonné AVANT le premier calcul (une mise à jour pendant celui-ci n'est pas
  // perdue) ; une rafale (verdict = 2 écritures, synchro = N) → un seul calcul.
  final ticks = StreamController<void>();
  Timer? debounce;
  final sub = db.tableUpdates(TableUpdateQuery.onAllTables([db.flashCards, db.reviewLog])).listen((_) {
    debounce?.cancel();
    debounce = Timer(_debounce, () {
      if (!ticks.isClosed) ticks.add(null);
    });
  });
  ref.onDispose(() {
    debounce?.cancel();
    sub.cancel();
    ticks.close();
  });

  yield await compute();
  await for (final _ in ticks.stream) {
    yield await compute();
  }
});

const _debounce = Duration(milliseconds: 150);

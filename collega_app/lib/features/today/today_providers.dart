import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/data/college_cards_sync.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/domain/drill_stats.dart';
import 'package:collega_app/features/planning/planning_providers.dart';
import 'package:collega_app/features/profile/profile_providers.dart';
import 'package:collega_app/features/today/data/daily_session_repository.dart';
import 'package:collega_app/features/today/domain/daily_session_builder.dart';

// ─── État ─────────────────────────────────────────────────────────────────────

sealed class TodayState {
  const TodayState();
}

/// Aucun collège importé : « Importe ton premier collège ».
class TodayNoCollege extends TodayState {
  const TodayNoCollege();
}

/// Un import est en cours et aucun collège n'est encore prêt.
class TodayPreparing extends TodayState {
  const TodayPreparing({required this.collegeName});
  final String collegeName;
}

/// Part d'un collège dans la session du jour (« Cancérologie · 16 · rang A »).
class TodayMix {
  const TodayMix({required this.collegeName, required this.count, required this.rangs});
  final String collegeName;
  final int count;

  /// Rangs présents, triés (A, B, C).
  final List<String> rangs;
}

/// Pastille de la semaine.
class TodayWeekDay {
  const TodayWeekDay({required this.date, required this.done, required this.isToday});
  final DateTime date;
  final bool done;
  final bool isToday;
}

/// Ligne « Mes collèges ».
class TodayCollege {
  const TodayCollege({required this.refId, required this.collegeId, required this.name, required this.stats});
  final int refId;
  final String collegeId;
  final String name;
  final DrillStats stats;
}

class TodayReady extends TodayState {
  const TodayReady({
    required this.date,
    required this.session,
    required this.cardCount,
    required this.toReview,
    required this.mix,
    required this.week,
    required this.colleges,
    required this.verdicts,
    required this.budget,
    required this.sessionCollegeIds,
    this.planningDay,
    this.planningDays,
  });

  final DateTime date;
  final DailySession session;

  /// Fiches distinctes de la session.
  final int cardCount;

  /// Dont « à revoir ».
  final int toReview;
  final List<TodayMix> mix;
  final List<TodayWeekDay> week;
  final List<TodayCollege> colleges;

  /// Verdicts du jour (`maitrise` / `bien` / `a_revoir`), pour « Session faite ».
  final Map<String, int> verdicts;

  /// Budget du jour (planning, préférence ou 24) : base de « Personnaliser ».
  final int budget;

  /// Collèges de la session (réglages personnalisés, sinon planning, sinon tous
  /// les collèges prêts) : cochés à l'ouverture de « Personnaliser ».
  final Set<String> sessionCollegeIds;

  /// « jour 3 sur 30 » si un planning couvre aujourd'hui.
  final int? planningDay;
  final int? planningDays;

  int get minutes => estimatedMinutes(cardCount);
}

// ─── Dépendances ──────────────────────────────────────────────────────────────

/// Récupère toutes les fiches d'un collège (`GET /v1/colleges/{id}/cards`).
typedef CollegeCardsFetcher = Future<List<FlashCardModel>> Function(String collegeId);

final collegeCardsFetcherProvider = Provider<CollegeCardsFetcher>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  return (collegeId) => fetchCollegeCards(dio, collegeId);
});

/// Une réponse sans liste `data` est une erreur, jamais « aucune fiche » : la
/// synchronisation effacerait sinon toutes les fiches locales du collège.
Future<List<FlashCardModel>> fetchCollegeCards(Dio dio, String collegeId) async {
  final response = await dio.get<Map<String, dynamic>>('/v1/colleges/$collegeId/cards');
  final list = response.data?['data'];
  if (list is! List) {
    throw DioException(
      requestOptions: response.requestOptions,
      response: response,
      type: DioExceptionType.badResponse,
      message: 'Réponse inattendue pour les fiches du collège $collegeId',
    );
  }
  return list.map((e) => FlashCardModel.fromJson(e as Map<String, dynamic>)).toList();
}

final dailySessionRepositoryProvider = Provider<DailySessionRepository>(
  (ref) => DailySessionRepository(ref.read(databaseProvider)),
);

// ─── Notifier ─────────────────────────────────────────────────────────────────

const _inProgress = {'pending', 'processing', 'ocr_complete'};

class TodayNotifier extends AsyncNotifier<TodayState> {
  /// Collèges synchronisés pendant cette exécution de l'app (une fois suffit ;
  /// le tirer-pour-rafraîchir force une nouvelle synchronisation).
  final _synced = <String>{};

  @override
  Future<TodayState> build() async {
    final entries = await ref.watch(collegesProvider.future);
    final ready = entries.where((e) => e.isGenerationComplete && e.userStatus != null).toList();
    if (ready.isEmpty) {
      // Seuls les imports réellement en cours ; un import échoué invite à réimporter.
      final preparing = entries.where((e) => _inProgress.contains(e.userStatus?.status)).toList();
      return preparing.isEmpty
          ? const TodayNoCollege()
          : TodayPreparing(collegeName: preparing.first.catalog.name);
    }

    await _syncCards(ready.map((e) => e.userStatus!.collegeId));

    final now = DateTime.now();
    final day = epochDayOf(now);
    final planning = (await ref.watch(planningProvider.future)).config;
    final prefs = await ref.watch(revisionPrefsProvider.future);
    final readyIds = ready.map((e) => e.userStatus!.collegeId).toSet();
    final planned = planning?.collegeIds.toSet().intersection(readyIds);
    final repo = ref.read(dailySessionRepositoryProvider);
    final budget = sessionBudget(dailyMinutes: planning?.dailyMinutes, preferredMaxCards: prefs.defaultMaxCards);
    final defaultCollegeIds = planned == null || planned.isEmpty ? readyIds : planned;
    final session = await repo.getOrBuild(day: day, budget: budget, collegeIds: defaultCollegeIds);

    final db = ref.read(databaseProvider);
    final nameOf = {for (final e in ready) e.userStatus!.collegeId: e.catalog.name};
    final ids = session.cardIds.toSet();
    final sessionRows = ids.isEmpty
        ? const <FlashCard>[]
        : await (db.select(db.flashCards)..where((t) => t.id.isIn(ids))).get();

    final byCollege = <String, List<FlashCard>>{};
    for (final r in sessionRows) {
      byCollege.putIfAbsent(r.collegeId, () => []).add(r);
    }
    final mix = [
      for (final entry in byCollege.entries)
        TodayMix(
          collegeName: nameOf[entry.key] ?? 'Collège',
          count: entry.value.length,
          rangs: entry.value.map((r) => r.rang).toSet().toList()..sort(),
        ),
    ]..sort((a, b) => b.count.compareTo(a.count));

    final colleges = <TodayCollege>[];
    for (final e in ready) {
      final status = e.userStatus!;
      final levels = await (db.selectOnly(db.flashCards)
            ..addColumns([db.flashCards.drillLevel])
            ..where(db.flashCards.collegeId.equals(status.collegeId)))
          .map((row) => row.read(db.flashCards.drillLevel)!)
          .get();
      colleges.add(TodayCollege(
        refId: e.catalog.refId,
        collegeId: status.collegeId,
        name: e.catalog.name,
        stats: DrillStats.fromDrillLevels(levels).withTotal(status.totalCards),
      ));
    }

    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - DateTime.monday));
    final mondayDay = epochDayOf(monday);
    final done = await repo.completedDays(from: mondayDay, to: mondayDay + 6);

    int? planningDay;
    int? planningDays;
    if (planning != null) {
      final start = epochDayOf(planning.startDate);
      final end = epochDayOf(planning.endDate);
      if (day >= start && day <= end) {
        planningDay = day - start + 1;
        planningDays = end - start + 1;
      }
    }

    return TodayReady(
      date: now,
      session: session,
      // Fiches réellement présentes : un réimport régénère les fiches (nouveaux
      // ids) et une session commencée peut garder des ids disparus.
      cardCount: sessionRows.length,
      toReview: sessionRows.where((r) => r.drillLevel == 'a_revoir').length,
      mix: mix,
      week: [
        for (var i = 0; i < 7; i++)
          TodayWeekDay(
            date: monday.add(Duration(days: i)),
            done: done.contains(mondayDay + i),
            isToday: mondayDay + i == day,
          ),
      ],
      colleges: colleges,
      verdicts: await repo.verdictCounts(session.day),
      budget: session.settings?.budget ?? budget,
      sessionCollegeIds: session.settings?.collegeIds ?? defaultCollegeIds,
      planningDay: planningDay,
      planningDays: planningDays,
    );
  }

  /// Synchronise toutes les fiches des collèges prêts. Hors-ligne : on garde le local.
  Future<void> _syncCards(Iterable<String> collegeIds) async {
    final fetch = ref.read(collegeCardsFetcherProvider);
    final db = ref.read(databaseProvider);
    await Future.wait([
      for (final id in collegeIds.where((id) => !_synced.contains(id)))
        fetch(id).then((cards) async {
          await syncCollegeCards(db, id, cards);
          _synced.add(id);
        }).catchError((Object e) {
          if (e is! DioException) AppLogger.error('sync fiches $id', tag: 'Today', error: e);
        }),
    ]);
  }

  /// Tirer pour rafraîchir : resynchronise collèges et fiches.
  Future<void> refresh() async {
    _synced.clear();
    ref.invalidate(collegesProvider);
    ref.invalidateSelf();
    await future;
  }

  /// « Personnaliser la session » (tant qu'elle n'est pas commencée).
  Future<void> customize({
    Set<String>? collegeIds,
    Set<String>? rangs,
    SessionStatusFilter status = SessionStatusFilter.all,
    int? maxCards,
  }) async {
    final current = state.valueOrNull;
    final readyIds = current is TodayReady ? current.colleges.map((c) => c.collegeId).toSet() : null;
    await ref.read(dailySessionRepositoryProvider).rebuild(
          day: epochDayOf(DateTime.now()),
          budget: maxCards ?? (current is TodayReady ? current.budget : kDefaultSessionCards),
          collegeIds: collegeIds ?? readyIds,
          rangs: rangs,
          status: status,
        );
    ref.invalidateSelf();
    await future;
  }
}

final todayProvider = AsyncNotifierProvider<TodayNotifier, TodayState>(TodayNotifier.new);

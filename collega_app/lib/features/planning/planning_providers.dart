import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/features/planning/data/planning_repository.dart';
import 'package:collega_app/features/planning/domain/planning_models.dart';
import 'package:collega_app/features/today/data/daily_session_repository.dart';
import 'package:collega_app/features/today/domain/daily_session_builder.dart';

export 'domain/planning_models.dart';

final planningRepositoryProvider = Provider<PlanningRepository>(
  (ref) => PlanningRepository(db: ref.read(databaseProvider)),
);

/// Horloge du planning (injectée en test).
final planningClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

// ─── PlanningState ────────────────────────────────────────────────────────────

@immutable
class PlanningState {
  const PlanningState({this.config, this.postponedDays = const {}, required this.today});

  final PlanningConfig? config;

  /// Jours décalés (« Décaler aujourd'hui »), en jours epoch.
  final Set<int> postponedDays;

  /// Jour courant (epoch) au moment du calcul.
  final int today;

  bool get hasPlanningConfig => config != null;
  bool get postponedToday => postponedDays.contains(today);
}

// ─── PlanningNotifier ─────────────────────────────────────────────────────────

/// Le planning fixe la période, les collèges et le temps par jour ; la session
/// du jour en découle (story 8.3). « Décaler aujourd'hui » prolonge la période
/// d'un jour, sans pénalité (story 8.9).
class PlanningNotifier extends AsyncNotifier<PlanningState> {
  PlanningRepository get _repo => ref.read(planningRepositoryProvider);
  int get _today => epochDayOf(ref.read(planningClockProvider)());

  @override
  Future<PlanningState> build() async {
    final config = await _repo.getActiveConfig();
    final postponed = config == null ? const <int>{} : await _repo.postponedDays(config.id);
    return PlanningState(config: config, postponedDays: postponed, today: _today);
  }

  Future<void> plan({
    required List<String> collegeIds,
    required DateTime startDate,
    required DateTime endDate,
    required int dailyMinutes,
  }) async {
    await _repo.replace(PlanningConfig(
      id: ref.read(planningClockProvider)().microsecondsSinceEpoch.toString(),
      collegeIds: collegeIds,
      startDate: dateOfEpochDay(epochDayOf(startDate)),
      endDate: dateOfEpochDay(epochDayOf(endDate)),
      dailyMinutes: dailyMinutes,
      createdAt: DateTime.now().toUtc(),
    ));
    await _reload();
  }

  /// Décale aujourd'hui (jour relu à l'horloge, pas celui du dernier calcul) :
  /// seulement dans la période, et tant que la session du jour n'est ni
  /// commencée ni faite.
  Future<void> postponeToday() async {
    final config = (await future).config;
    final today = _today;
    if (config == null) return;
    if (today < epochDayOf(config.startDate) || today > epochDayOf(config.endDate)) return;
    if ((await _repo.postponedDays(config.id)).contains(today)) return;
    final session = await DailySessionRepository(ref.read(databaseProvider)).find(today);
    if (session != null && (session.isStarted || session.isCompleted)) return;
    await _repo.postpone(config, today);
    await _reload();
  }

  Future<void> cancelPostpone() async {
    final config = (await future).config;
    final today = _today;
    if (config == null || !(await _repo.postponedDays(config.id)).contains(today)) return;
    await _repo.unpostpone(config, today);
    await _reload();
  }

  /// Retour au premier plan après minuit : l'état (jour courant, « décalé »)
  /// est recalculé pour le nouveau jour.
  void refreshIfNewDay() {
    final s = state.valueOrNull;
    if (s != null && s.today != _today) ref.invalidateSelf();
  }

  Future<void> clear() async {
    await _repo.clear();
    await _reload();
  }

  Future<void> _reload() async {
    ref.invalidateSelf();
    await future;
  }
}

final planningProvider = AsyncNotifierProvider<PlanningNotifier, PlanningState>(PlanningNotifier.new);

// ─── Aperçu ───────────────────────────────────────────────────────────────────

/// Aperçu vivant du planning (spec v2 § Parcours 5) : « 341 fiches · 30 jours ·
/// ~12 par jour », faisable ou non dans le temps choisi.
@immutable
class PlanningPreview {
  const PlanningPreview({required this.cards, required this.days, required this.dailyMinutes});

  factory PlanningPreview.of({
    required int cards,
    required DateTime startDate,
    required DateTime endDate,
    required int dailyMinutes,
  }) =>
      PlanningPreview(
        cards: cards,
        days: math.max(0, epochDayOf(endDate) - epochDayOf(startDate) + 1),
        dailyMinutes: dailyMinutes,
      );

  final int cards;
  final int days;
  final int dailyMinutes;

  int get perDay => days == 0 ? cards : (cards / days).ceil();

  /// Fiches que le temps choisi permet chaque jour (1 fiche ≈ 50 s).
  int get budget => sessionBudget(dailyMinutes: dailyMinutes);

  bool get feasible => days > 0 && perDay <= budget;

  /// Temps quotidien qu'il faudrait pour tenir la période.
  int get minutesNeeded => estimatedMinutes(perDay);
}

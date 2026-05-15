import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/planning/data/planning_generator.dart';
import 'package:collega_app/features/planning/data/planning_repository.dart';
import 'package:collega_app/features/planning/domain/planning_models.dart';

export 'domain/planning_models.dart';

final planningRepositoryProvider = Provider<PlanningRepository>(
  (ref) => PlanningRepository(db: ref.read(databaseProvider)),
);

// ─── PlanningState ────────────────────────────────────────────────────────────

class PlanningState {
  const PlanningState({
    this.config,
    this.todaySession,
  });

  final PlanningConfig? config;
  final PlannedSession? todaySession;

  bool get hasPlanningConfig => config != null;
}

// ─── PlanningNotifier ─────────────────────────────────────────────────────────

class PlanningNotifier extends AsyncNotifier<PlanningState> {
  @override
  Future<PlanningState> build() async {
    final repo = ref.read(planningRepositoryProvider);
    final config = await repo.getActiveConfig();
    final todaySession =
        config != null ? await repo.getTodaySession() : null;
    return PlanningState(config: config, todaySession: todaySession);
  }

  Future<void> generatePlanning({
    required List<String> collegeIds,
    List<String>? itemIds,
    required DateTime startDate,
    required DateTime endDate,
    required int dailyMinutes,
  }) async {
    state = const AsyncValue.loading();
    final repo = ref.read(planningRepositoryProvider);
    final db = ref.read(databaseProvider);

    await repo.deleteAllPendingSessions();
    await repo.deleteAllConfigs();

    final query = db.select(db.flashCards)
      ..where((t) => t.collegeId.isIn(collegeIds));
    if (itemIds != null && itemIds.isNotEmpty) {
      query.where((t) => t.itemId.isIn(itemIds));
    }
    final allRows = await query.get();

    final allCards = allRows
        .map((r) => FlashCardModel(
              id: r.id,
              itemId: r.itemId,
              collegeId: r.collegeId,
              cardType: r.cardType,
              rang: r.rang,
              recto: r.recto,
              verso: r.verso,
              ocrConfidenceScore: r.ocrConfidenceScore,
              lowConfidence: r.lowConfidence,
              userFeedback: r.userFeedback,
              drillLevel: r.drillLevel,
            ))
        .toList();

    final configId = DateTime.now().millisecondsSinceEpoch.toString();
    final config = PlanningConfig(
      id: configId,
      collegeIds: collegeIds,
      itemIds: itemIds,
      startDate: startDate,
      endDate: endDate,
      dailyMinutes: dailyMinutes,
      createdAt: DateTime.now().toUtc(),
    );

    await repo.saveConfig(config);

    final sessions = PlanningGenerator.generate(
      config: config,
      allCards: allCards,
    );
    await repo.saveSessions(sessions);

    final todaySession = await repo.getTodaySession();
    state = AsyncValue.data(
      PlanningState(config: config, todaySession: todaySession),
    );
  }

  Future<void> markTodayCompleted() async {
    final s = state.value;
    if (s?.todaySession == null) return;
    final repo = ref.read(planningRepositoryProvider);
    await repo.markSessionCompleted(s!.todaySession!.id);
    state = AsyncValue.data(
      PlanningState(config: s.config, todaySession: null),
    );
  }

  Future<void> postponeToday() async {
    final s = state.value;
    if (s?.todaySession == null) return;
    final repo = ref.read(planningRepositoryProvider);
    await repo.postponeSession(s!.todaySession!.id);
    state = AsyncValue.data(
      PlanningState(config: s.config, todaySession: null),
    );
  }
}

final planningProvider =
    AsyncNotifierProvider<PlanningNotifier, PlanningState>(
  PlanningNotifier.new,
);

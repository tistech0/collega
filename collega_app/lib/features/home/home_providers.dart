import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/home/domain/home_session_config.dart';
import 'package:collega_app/features/planning/planning_providers.dart';
import 'package:collega_app/features/profile/profile_providers.dart';

// ─── HomeState ────────────────────────────────────────────────────────────────

sealed class HomeState {
  const HomeState();
}

class HomeEmpty extends HomeState {
  const HomeEmpty();
}

class HomeOcrInProgress extends HomeState {
  const HomeOcrInProgress({required this.collegeName});
  final String collegeName;
}

class HomeReady extends HomeState {
  const HomeReady({
    required this.sessionConfig,
    required this.recentColleges,
    required this.totalCards,
    this.todaySession,
    this.hasPlanningConfig = false,
  });

  final HomeSessionConfig sessionConfig;
  final List<CollegeListEntry> recentColleges;
  final int totalCards;
  final PlannedSession? todaySession;
  final bool hasPlanningConfig;

  String get estimatedDuration {
    final mins = (totalCards / 5).ceil();
    return '$mins min';
  }
}

// ─── HomeSessionConfigNotifier ────────────────────────────────────────────────

class HomeSessionConfigNotifier extends Notifier<HomeSessionConfig?> {
  @override
  HomeSessionConfig? build() => null;

  void setConfig(HomeSessionConfig config) => state = config;

  void applyDefault(HomeSessionConfig config) {
    state ??= config;
  }

  void reset() => state = null;
}

final homeSessionConfigProvider =
    NotifierProvider<HomeSessionConfigNotifier, HomeSessionConfig?>(
  HomeSessionConfigNotifier.new,
);

// ─── HomeNotifier ─────────────────────────────────────────────────────────────

class HomeNotifier extends AsyncNotifier<HomeState> {
  @override
  Future<HomeState> build() async {
    final colleges = await ref.watch(collegesProvider.future);

    final generationComplete =
        colleges.where((e) => e.isGenerationComplete).toList();
    final inProgress =
        colleges.where((e) => e.isImported && !e.isGenerationComplete).toList();

    if (generationComplete.isEmpty && inProgress.isEmpty) {
      return const HomeEmpty();
    }

    if (generationComplete.isEmpty) {
      return HomeOcrInProgress(collegeName: inProgress.first.catalog.name);
    }

    final defaultCollege = generationComplete.first;
    final defaultCollegeId = defaultCollege.userStatus?.collegeId;
    if (defaultCollegeId == null) return const HomeEmpty();

    final revisionPrefs = await ref.read(revisionPrefsProvider.future);
    ref.read(homeSessionConfigProvider.notifier).applyDefault(
          HomeSessionConfig(
            collegeId: defaultCollegeId,
            collegeName: defaultCollege.catalog.name,
            rangs: revisionPrefs.defaultRangs,
            maxCards: revisionPrefs.defaultMaxCards,
          ),
        );

    final sessionConfig = ref.read(homeSessionConfigProvider);
    if (sessionConfig == null) return const HomeEmpty();
    final totalCards = await _countCards(sessionConfig);

    final planningState = await ref.watch(planningProvider.future);
    return HomeReady(
      sessionConfig: sessionConfig,
      recentColleges: generationComplete.take(2).toList(),
      totalCards: totalCards,
      todaySession: planningState.todaySession,
      hasPlanningConfig: planningState.hasPlanningConfig,
    );
  }

  Future<int> _countCards(HomeSessionConfig config) async {
    final db = ref.read(databaseProvider);
    final query = db.select(db.flashCards)
      ..where((t) => t.collegeId.equals(config.collegeId));
    if (config.rangs != null && config.rangs!.isNotEmpty) {
      query.where((t) => t.rang.isIn(config.rangs!));
    }
    if (config.statusFilter == 'a_revoir') {
      query.where((t) => t.drillLevel.equals('a_revoir'));
    } else if (config.statusFilter == 'non_vues') {
      query.where((t) => t.drillLevel.equals('new'));
    }
    final rows = await query.get();
    final count =
        config.maxCards == 0 ? rows.length : rows.length.clamp(0, config.maxCards);
    return count;
  }
}

final homeProvider =
    AsyncNotifierProvider<HomeNotifier, HomeState>(HomeNotifier.new);

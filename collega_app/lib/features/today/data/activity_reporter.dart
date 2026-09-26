import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/planning/planning_providers.dart';
import 'package:collega_app/features/today/data/daily_session_repository.dart';
import 'package:collega_app/features/today/domain/streak.dart';

/// Résumé d'un jour envoyé au backend pour la console de pilotage de la beta.
/// Uniquement des compteurs, jamais le contenu des fiches.
class ActivitySummary {
  const ActivitySummary({
    required this.day,
    required this.cardsReviewed,
    required this.sessionCompleted,
    required this.streak,
  });

  final int day;
  final int cardsReviewed;
  final bool sessionCompleted;
  final int streak;

  Map<String, Object> toJson() => {
        'cards_reviewed': cardsReviewed,
        'session_completed': sessionCompleted,
        'streak': streak,
      };
}

/// Envoie `PUT /v1/activity/{date}` : remplacement idempotent côté serveur, donc
/// renvoyer un jour déjà envoyé ne compte rien en double. Hors ligne : échec
/// silencieux (log, pas d'exception, pas d'erreur visible pour l'utilisatrice) —
/// le jour repart au prochain lancement (`reportRecent`).
class ActivityReporter {
  ActivityReporter({
    required Dio dio,
    required DailySessionRepository repo,
    required Future<Set<int>> Function() postponedDays,
    this.debounce = const Duration(seconds: 30),
  })  : _dio = dio,
        _repo = repo,
        _postponedDays = postponedDays;

  final Dio _dio;
  final DailySessionRepository _repo;
  final Future<Set<int>> Function() _postponedDays;
  final Duration debounce;
  final _timers = <int, Timer>{};

  /// Même mesure que l'écran Progression (`weekCounts`) : fiches distinctes
  /// révisées ce jour-là, série calculée comme sur l'Accueil (`today_providers`).
  Future<ActivitySummary> summarize(int day) async {
    final cards = (await _repo.weekCounts(from: day, to: day))[day] ?? 0;
    final completed = await _repo.completedDays(from: 0, to: day);
    final streak = streakLength(
      today: day,
      completed: completed,
      excused: {...await _repo.quietDays(from: 0, to: day), ...await _postponedDays()},
    );
    return ActivitySummary(
      day: day,
      cardsReviewed: cards,
      sessionCompleted: completed.contains(day),
      streak: streak,
    );
  }

  Future<void> report(int day) async {
    try {
      final summary = await summarize(day);
      await _dio.put<void>('/v1/activity/${_isoDate(day)}', data: summary.toJson());
    } catch (e) {
      AppLogger.error('activité : envoi impossible', tag: 'Activity', error: e);
    }
  }

  /// Anti-rebond : un seul envoi par jour après [debounce] sans nouvel appel.
  void schedule(int day) {
    _timers.remove(day)?.cancel();
    _timers[day] = Timer(debounce, () {
      _timers.remove(day);
      unawaited(report(day));
    });
  }

  /// Au lancement / connexion : renvoie les [days] derniers jours (aujourd'hui
  /// compris) qui ont de l'activité locale (fiches révisées ou session terminée).
  Future<void> reportRecent({required int today, int days = 7}) async {
    final from = today - days + 1;
    final counts = await _repo.weekCounts(from: from, to: today);
    final completed = await _repo.completedDays(from: from, to: today);
    final activeDays = {...counts.keys, ...completed}.toList()..sort();
    for (final day in activeDays) {
      await report(day);
    }
  }

  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }

  static String _isoDate(int day) {
    final d = dateOfEpochDay(day);
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

final activityReporterProvider = Provider<ActivityReporter>((ref) {
  final reporter = ActivityReporter(
    dio: ref.read(apiClientProvider).dio,
    repo: DailySessionRepository(ref.read(databaseProvider)),
    postponedDays: () async => (await ref.read(planningProvider.future)).postponedDays,
  );
  ref.onDispose(reporter.dispose);
  return reporter;
});

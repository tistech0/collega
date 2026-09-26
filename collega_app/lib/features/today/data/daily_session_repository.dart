import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/today/domain/daily_session_builder.dart';

/// Réglages « Personnaliser » enregistrés avec la session.
class DailySessionSettings {
  const DailySessionSettings({required this.budget, this.collegeIds, this.rangs, this.status = SessionStatusFilter.all});

  final int budget;
  final Set<String>? collegeIds;
  final Set<String>? rangs;
  final SessionStatusFilter status;

  Map<String, Object?> toJson() => {
        'budget': budget,
        'collegeIds': collegeIds?.toList(),
        'rangs': rangs?.toList(),
        'status': status.name,
      };

  static DailySessionSettings fromJson(Map<String, dynamic> json) => DailySessionSettings(
        budget: json['budget'] as int,
        collegeIds: (json['collegeIds'] as List?)?.cast<String>().toSet(),
        rangs: (json['rangs'] as List?)?.cast<String>().toSet(),
        status: SessionStatusFilter.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => SessionStatusFilter.all,
        ),
      );
}

/// Session du jour lue depuis Drift.
class DailySession {
  const DailySession({
    required this.day,
    required this.cardIds,
    required this.position,
    this.startedAt,
    this.completedAt,
    this.settings,
  });

  final int day;

  /// File complète (réinsertions « à revoir » comprises).
  final List<String> cardIds;

  /// Index dans la file de la prochaine fiche à présenter (fiches déjà passées,
  /// réinsertions comprises) — c'est la position de reprise du drill.
  final int position;

  /// Réglages « Personnaliser », null = session calculée par défaut.
  final DailySessionSettings? settings;
  final DateTime? startedAt;
  final DateTime? completedAt;

  bool get isStarted => position > 0 || startedAt != null;
  bool get isCompleted => completedAt != null;

  /// Fiches distinctes de la session (sans les réinsertions).
  int get uniqueCount => cardIds.toSet().length;

  static DailySession fromRow(DailySessionRow r) => DailySession(
        day: r.day,
        cardIds: (jsonDecode(r.queueJson) as List).cast<String>(),
        position: r.position,
        startedAt: r.startedAtMs == null ? null : DateTime.fromMillisecondsSinceEpoch(r.startedAtMs!),
        completedAt: r.completedAtMs == null ? null : DateTime.fromMillisecondsSinceEpoch(r.completedAtMs!),
        settings: r.settingsJson == null
            ? null
            : DailySessionSettings.fromJson(jsonDecode(r.settingsJson!) as Map<String, dynamic>),
      );
}

/// Persistance de la session du jour et du journal des verdicts (story 8.3).
///
/// La session est **figée dès qu'elle est commencée** : les fiches synchronisées
/// ensuite n'en changent pas le contenu. Avant, elle est recalculée à chaque
/// lecture (avec ses réglages « Personnaliser » s'il y en a), pour profiter des
/// fiches arrivées entre-temps ; une session vide n'est jamais enregistrée.
class DailySessionRepository {
  DailySessionRepository(this.db, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _clock;

  Future<DailySession?> find(int day) async {
    final row = await (db.select(db.dailySessions)..where((t) => t.day.equals(day))).getSingleOrNull();
    return row == null ? null : DailySession.fromRow(row);
  }

  /// Session du jour : figée si commencée, sinon (re)calculée depuis les fiches locales.
  Future<DailySession> getOrBuild({required int day, required int budget, Set<String>? collegeIds}) async {
    final existing = await find(day);
    if (existing != null && (existing.isStarted || existing.isCompleted)) return existing;
    final custom = existing?.settings;
    if (custom != null) {
      return _build(
        day: day,
        budget: custom.budget,
        collegeIds: custom.collegeIds,
        rangs: custom.rangs,
        status: custom.status,
        custom: true,
      );
    }
    return _build(day: day, budget: budget, collegeIds: collegeIds);
  }

  /// « Personnaliser » : reconstruit la session tant qu'elle n'est pas commencée.
  Future<DailySession> rebuild({
    required int day,
    required int budget,
    Set<String>? collegeIds,
    Set<String>? rangs,
    SessionStatusFilter status = SessionStatusFilter.all,
  }) async {
    final existing = await find(day);
    if (existing != null && existing.isStarted) {
      throw StateError('La session du jour est commencée : elle ne se personnalise plus.');
    }
    return _build(day: day, budget: budget, collegeIds: collegeIds, rangs: rangs, status: status, custom: true);
  }

  /// Aperçu vivant de « Personnaliser » : nombre de fiches, sans rien enregistrer.
  Future<int> preview({
    required int budget,
    Set<String>? collegeIds,
    Set<String>? rangs,
    SessionStatusFilter status = SessionStatusFilter.all,
  }) async {
    final rows = await db.select(db.flashCards).get();
    return buildDailySession(
      [
        for (final r in rows)
          SessionCard(id: r.id, collegeId: r.collegeId, rang: r.rang, drillLevel: r.drillLevel, nextReviewAtMs: r.nextReviewAt),
      ],
      budget: budget,
      now: _clock(),
      collegeIds: collegeIds,
      rangs: rangs,
      status: status,
    ).length;
  }

  Future<DailySession> _build({
    required int day,
    required int budget,
    Set<String>? collegeIds,
    Set<String>? rangs,
    SessionStatusFilter status = SessionStatusFilter.all,
    bool custom = false,
  }) async {
    final rows = await db.select(db.flashCards).get();
    final plan = buildDailySession(
      [
        for (final r in rows)
          SessionCard(id: r.id, collegeId: r.collegeId, rang: r.rang, drillLevel: r.drillLevel, nextReviewAtMs: r.nextReviewAt),
      ],
      budget: budget,
      now: _clock(),
      collegeIds: collegeIds,
      rangs: rangs,
      status: status,
    );
    final settings = custom
        ? jsonEncode(DailySessionSettings(budget: budget, collegeIds: collegeIds, rangs: rangs, status: status).toJson())
        : null;
    if (plan.isEmpty) {
      // Rien à réviser : ne rien figer, la prochaine synchro pourra la remplir.
      await (db.delete(db.dailySessions)..where((t) => t.day.equals(day))).go();
      // Jour calme (série de l'Accueil) : pas un choix de « Personnaliser ».
      if (!custom) {
        await db.into(db.quietDays).insertOnConflictUpdate(QuietDaysCompanion.insert(day: Value(day)));
      }
      return DailySession(
        day: day,
        cardIds: const [],
        position: 0,
        settings: settings == null ? null : DailySessionSettings.fromJson(jsonDecode(settings) as Map<String, dynamic>),
      );
    }
    await db.into(db.dailySessions).insertOnConflictUpdate(DailySessionsCompanion.insert(
          day: Value(day),
          queueJson: jsonEncode(plan.map((c) => c.id).toList()),
          position: const Value(0),
          settingsJson: Value(settings),
          startedAtMs: const Value(null),
          completedAtMs: const Value(null),
        ));
    return (await find(day))!;
  }

  /// Enregistre l'avancement (file courante + fiches jugées). Marque le début.
  Future<void> saveProgress({required int day, required List<String> queue, required int position}) async {
    final existing = await find(day);
    await (db.update(db.dailySessions)..where((t) => t.day.equals(day))).write(DailySessionsCompanion(
      queueJson: Value(jsonEncode(queue)),
      position: Value(position),
      startedAtMs: existing?.startedAt == null
          ? Value(_clock().millisecondsSinceEpoch)
          : const Value.absent(),
    ));
  }

  /// Clôt la session du jour (le planning avance seul : jour suivant).
  Future<void> complete(int day) async {
    final at = _clock().millisecondsSinceEpoch;
    await (db.update(db.dailySessions)..where((t) => t.day.equals(day))).write(DailySessionsCompanion(
      completedAtMs: Value(at),
    ));
  }

  /// Journalise un verdict (`a_revoir` | `bien` | `maitrise`) sur le jour de la
  /// session (une session commencée à 23 h 50 reste comptée sur son jour).
  /// [daily] : verdict de la session du jour (son bilan) ; sinon il ne compte
  /// que dans la semaine de Progression.
  Future<void> recordVerdict({
    required int day,
    required String cardId,
    required String collegeId,
    required String rang,
    required String drillLevel,
    bool daily = true,
  }) async {
    final at = _clock();
    await db.into(db.reviewLog).insert(ReviewLogCompanion.insert(
          cardId: cardId,
          collegeId: collegeId,
          rang: rang,
          drillLevel: drillLevel,
          reviewedAtMs: at.millisecondsSinceEpoch,
          day: day,
          daily: Value(daily),
        ));
  }

  /// Dernier verdict du jour par fiche (reprise : le bilan compte aussi ce qui a
  /// été jugé avant l'interruption).
  Future<Map<String, String>> lastVerdicts(int day) async {
    final rows = await (db.select(db.reviewLog)
          ..where((t) => t.day.equals(day) & t.daily.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    return {for (final r in rows) r.cardId: r.drillLevel};
  }

  /// Verdicts de la session d'un jour, par niveau.
  Future<Map<String, int>> verdictCounts(int day) async {
    final rows = await (db.select(db.reviewLog)..where((t) => t.day.equals(day) & t.daily.equals(true))).get();
    final counts = <String, int>{};
    for (final r in rows) {
      counts[r.drillLevel] = (counts[r.drillLevel] ?? 0) + 1;
    }
    return counts;
  }

  /// Fiches distinctes révisées par jour (toutes révisions confondues : une
  /// fiche revue deux fois le même jour compte une fois), jours inclus ; les
  /// jours sans révision sont absents.
  Future<Map<int, int>> weekCounts({required int from, required int to}) async {
    final count = db.reviewLog.cardId.count(distinct: true);
    final rows = await (db.selectOnly(db.reviewLog)
          ..addColumns([db.reviewLog.day, count])
          ..where(db.reviewLog.day.isBetweenValues(from, to))
          ..groupBy([db.reviewLog.day]))
        .get();
    return {for (final r in rows) r.read(db.reviewLog.day)!: r.read(count)!};
  }

  /// Outil de test (build `COLLEGA_TEST_TOOLS`) : oublie la session du jour et
  /// son bilan, comme si elle n'avait pas encore été faite.
  Future<void> resetDay(int day) => db.transaction(() async {
        await (db.delete(db.dailySessions)..where((t) => t.day.equals(day))).go();
        await (db.delete(db.reviewLog)..where((t) => t.day.equals(day) & t.daily.equals(true))).go();
        await (db.delete(db.quietDays)..where((t) => t.day.equals(day))).go();
      });

  /// Jours (inclus) dont la session du jour a été terminée.
  Future<Set<int>> completedDays({required int from, required int to}) async {
    final rows = await (db.select(db.dailySessions)
          ..where((t) => t.day.isBetweenValues(from, to) & t.completedAtMs.isNotNull()))
        .get();
    return rows.map((r) => r.day).toSet();
  }

  /// Jours « rien à réviser » entre [from] et [to] inclus (série de l'Accueil).
  Future<Set<int>> quietDays({required int from, required int to}) async {
    final rows = await (db.select(db.quietDays)..where((t) => t.day.isBetweenValues(from, to))).get();
    return rows.map((r) => r.day).toSet();
  }
}

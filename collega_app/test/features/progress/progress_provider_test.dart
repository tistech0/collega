import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/data/college_cards_sync.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/planning/planning_providers.dart';
import 'package:collega_app/features/progress/progress_providers.dart';
import 'package:collega_app/features/today/data/daily_session_repository.dart';

FlashCardModel _card(String id, String college, String rang) => FlashCardModel(
      id: id, itemId: 'i-$id', collegeId: college, cardType: 'qa', rang: rang,
      recto: 'Q', verso: 'R', ocrConfidenceScore: 0.9, lowConfidence: false,
    );

class _Colleges extends CollegesNotifier {
  _Colleges(this.statuses);
  final List<UserCollegeStatus> statuses;
  @override
  Future<List<CollegeListEntry>> build() async {
    final byRef = {for (final s in statuses) s.refId: s};
    return [for (final c in kCollegeCatalog) CollegeListEntry(catalog: c, userStatus: byRef[c.refId])];
  }
}

void main() {
  late AppDatabase db;
  // Mercredi 23 septembre 2026.
  final now = DateTime(2026, 9, 23, 18);
  final today = epochDayOf(now);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer container(List<UserCollegeStatus> statuses) {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      collegesProvider.overrideWith(() => _Colleges(statuses)),
      progressClockProvider.overrideWithValue(() => now),
      planningClockProvider.overrideWithValue(() => now),
    ]);
    addTearDown(c.dispose);
    // autoDispose : un écouteur garde le fournisseur vivant, comme l'onglet affiché.
    c.listen(progressProvider, (_, __) {});
    return c;
  }

  Future<void> level(String id, String drillLevel) =>
      (db.update(db.flashCards)..where((t) => t.id.equals(id))).write(FlashCardsCompanion(drillLevel: Value(drillLevel)));

  test('aucun collège prêt : vide', () async {
    final c = container(const [
      UserCollegeStatus(refId: 3, collegeId: 'c3', status: 'processing', cardCountA: 0, cardCountB: 0, cardCountC: 0),
    ]);
    expect(await c.read(progressProvider.future), isA<ProgressEmpty>());
  });

  test('totaux, collèges, rangs (non vues recalées sur le total serveur), semaine', () async {
    // Cancéro : 4 fiches locales (A,A,B,C) sur 10 au serveur (6 A, 3 B, 1 C) ; Pneumo : rien de local, 5 A.
    await syncCollegeCards(db, 'c3', [_card('a1', 'c3', 'A'), _card('a2', 'c3', 'A'), _card('b1', 'c3', 'B'), _card('k1', 'c3', 'C')]);
    await level('a1', 'maitrise');
    await level('a2', 'bien');
    await level('b1', 'a_revoir');
    final daily = DailySessionRepository(db);
    // Lundi 2 révisions, mercredi 1 (hors session du jour), dimanche dernier (hors semaine) 1.
    await daily.recordVerdict(day: today - 2, cardId: 'a1', collegeId: 'c3', rang: 'A', drillLevel: 'maitrise');
    await daily.recordVerdict(day: today - 2, cardId: 'a2', collegeId: 'c3', rang: 'A', drillLevel: 'bien');
    await daily.recordVerdict(day: today, cardId: 'b1', collegeId: 'c3', rang: 'B', drillLevel: 'a_revoir', daily: false);
    await daily.recordVerdict(day: today - 3, cardId: 'k1', collegeId: 'c3', rang: 'C', drillLevel: 'bien');

    final c = container(const [
      UserCollegeStatus(refId: 3, collegeId: 'c3', status: 'generation_complete', cardCountA: 6, cardCountB: 3, cardCountC: 1),
      UserCollegeStatus(refId: 34, collegeId: 'c34', status: 'generation_complete', cardCountA: 5, cardCountB: 0, cardCountC: 0),
    ]);
    final p = await c.read(progressProvider.future) as ProgressReady;

    expect([p.overall.maitrise, p.overall.bien, p.overall.aRevoir, p.overall.notSeen], [1, 1, 1, 12]);
    expect(p.colleges.map((e) => e.name), ['Cancérologie', 'Pneumologie']);
    expect(p.colleges.first.stats.total, 10);
    expect(p.colleges.last.stats.notSeen, 5);
    expect(p.byRang.keys, ['A', 'B', 'C']);
    expect([p.byRang['A']!.maitrise, p.byRang['A']!.bien, p.byRang['A']!.notSeen], [1, 1, 9]);
    expect([p.byRang['B']!.aRevoir, p.byRang['B']!.notSeen], [1, 2]);

    expect(p.week.map((d) => d.count), [2, 0, 1, 0, 0, 0, 0]);
    expect(p.week[2].isToday, isTrue);
    expect(p.weekTotal, 3);
  });

  test('vivant : un nouveau verdict met la semaine à jour', () async {
    await syncCollegeCards(db, 'c3', [_card('a1', 'c3', 'A')]);
    final c = container(const [
      UserCollegeStatus(refId: 3, collegeId: 'c3', status: 'generation_complete', cardCountA: 1, cardCountB: 0, cardCountC: 0),
    ]);
    final values = <ProgressState>[];
    c.listen(progressProvider, (_, next) {
      if (next.hasValue) values.add(next.value!);
    }, fireImmediately: true);
    await c.read(progressProvider.future);
    await DailySessionRepository(db).recordVerdict(day: today, cardId: 'a1', collegeId: 'c3', rang: 'A', drillLevel: 'bien');
    await pumpEventQueue();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect((values.last as ProgressReady).weekTotal, 1);
  });
}

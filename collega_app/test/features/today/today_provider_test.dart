import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/planning/planning_providers.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';
import 'package:collega_app/features/profile/profile_providers.dart';
import 'package:collega_app/features/today/data/daily_session_repository.dart';
import 'package:collega_app/features/today/today_providers.dart';

FlashCardModel _card(String id, String college, {String rang = 'A'}) => FlashCardModel(
      id: id, itemId: 'i-$id', collegeId: college, cardType: 'classique', rang: rang,
      recto: 'Q', verso: 'R', ocrConfidenceScore: 0.9, lowConfidence: false,
    );

UserCollegeStatus _status(int refId, String id, {String status = 'generation_complete', int a = 0}) =>
    UserCollegeStatus(refId: refId, collegeId: id, status: status, cardCountA: a, cardCountB: 0, cardCountC: 0);

class _Colleges extends CollegesNotifier {
  _Colleges(this.statuses, {this.error});
  final List<UserCollegeStatus> statuses;
  final Object? error;
  @override
  Future<List<CollegeListEntry>> build() async {
    if (error != null) throw error!;
    final byRef = {for (final s in statuses) s.refId: s};
    return [for (final c in kCollegeCatalog) CollegeListEntry(catalog: c, userStatus: byRef[c.refId])];
  }
}

class _JsonAdapter implements HttpClientAdapter {
  _JsonAdapter(this.body);
  final String body;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(body, 200, headers: {Headers.contentTypeHeader: ['application/json']});
  @override
  void close({bool force = false}) {}
}

class _Prefs extends RevisionPrefsNotifier {
  _Prefs(this.prefs);
  final RevisionPrefs prefs;
  @override
  Future<RevisionPrefs> build() async => prefs;
}

void main() {
  late AppDatabase db;
  final now = DateTime.now();
  final today = epochDayOf(now);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer container({
    List<UserCollegeStatus> statuses = const [],
    Object? collegesError,
    Map<String, List<FlashCardModel>> server = const {},
    Map<String, List<ItemModel>> items = const {},
    bool itemsFail = false,
    bool offline = false,
    RevisionPrefs prefs = const RevisionPrefs(),
  }) {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      collegesProvider.overrideWith(() => _Colleges(statuses, error: collegesError)),
      revisionPrefsProvider.overrideWith(() => _Prefs(prefs)),
      collegeItemsFetcherProvider.overrideWithValue((id) async {
        if (offline || itemsFail) {
          throw DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError);
        }
        return items[id] ?? const [];
      }),
      collegeCardsFetcherProvider.overrideWithValue((id) async {
        if (offline) {
          throw DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError);
        }
        return server[id] ?? const [];
      }),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('fetcher : réponse sans « data » = erreur (jamais une liste vide qui effacerait tout)', () async {
    final dio = Dio()..httpClientAdapter = _JsonAdapter('{"detail": "x"}');
    await expectLater(fetchCollegeCards(dio, 'c3'), throwsA(isA<DioException>()));
    final ok = Dio()..httpClientAdapter = _JsonAdapter('{"data": [], "total": 0}');
    expect(await fetchCollegeCards(ok, 'c3'), isEmpty);
  });

  test('import échoué seul : pas « en préparation » éternel → invitation à importer', () async {
    final state = await container(statuses: [_status(3, 'c3', status: 'failed')]).read(todayProvider.future);
    expect(state, isA<TodayNoCollege>());
  });

  test('aucun collège importé → TodayNoCollege', () async {
    final state = await container().read(todayProvider.future);
    expect(state, isA<TodayNoCollege>());
  });

  test('import en cours sans collège prêt → TodayPreparing', () async {
    final state = await container(statuses: [_status(3, 'c3', status: 'processing')]).read(todayProvider.future);
    expect(state, isA<TodayPreparing>());
    expect((state as TodayPreparing).collegeName, 'Cancérologie');
  });

  test('collèges prêts : synchronise toutes leurs fiches puis construit la session mixte', () async {
    final c = container(
      statuses: [_status(3, 'c3', a: 2), _status(34, 'c34', a: 1)],
      server: {
        'c3': [_card('a', 'c3'), _card('b', 'c3')],
        'c34': [_card('x', 'c34')],
      },
    );
    final state = await c.read(todayProvider.future) as TodayReady;
    expect(state.cardCount, 3);
    expect(state.minutes, 3);
    expect(state.mix.map((m) => m.collegeName).toSet(), {'Cancérologie', 'Pneumologie'});
    expect(state.mix.firstWhere((m) => m.collegeName == 'Cancérologie').count, 2);
    expect(state.colleges, hasLength(2));
    expect((await db.select(db.flashCards).get()), hasLength(3));
  });

  test('synchro : les items (titres) sont aussi enregistrés localement (fin de session, 8.5)', () async {
    final c = container(
      statuses: [_status(3, 'c3', a: 1)],
      server: {'c3': [_card('a', 'c3')]},
      items: {'c3': [const ItemModel(id: 'i-a', collegeId: 'c3', itemNumber: 310, rang: 'A',
          chapterTitle: 'Tumeurs du testicule', ocrConfidenceScore: 0.9, lowConfidence: false,
          cardCountA: 1, cardCountB: 0, cardCountC: 0)]},
    );
    await c.read(todayProvider.future);
    final rows = await db.select(db.items).get();
    expect(rows.single.chapterTitle, 'Tumeurs du testicule');
  });

  test('échec du seul appel items : les fiches sont quand même enregistrées (revue 8.5)', () async {
    final c = container(statuses: [_status(3, 'c3', a: 2)], server: {'c3': [_card('a', 'c3'), _card('b', 'c3')]}, itemsFail: true);
    final state = await c.read(todayProvider.future) as TodayReady;
    expect(state.cardCount, 2);
  });

  test('budget de demain : celui du jour sans personnalisation (revue 8.5)', () async {
    final c = container(
      statuses: [_status(3, 'c3', a: 30)],
      server: {'c3': [for (var i = 0; i < 30; i++) _card('n$i', 'c3')]},
    );
    await c.read(todayProvider.future);
    await c.read(todayProvider.notifier).customize(maxCards: 12);
    final state = await c.read(todayProvider.future) as TodayReady;
    expect(state.budget, 12);
    expect(state.tomorrowBudget, 24);
  });

  test('hors-ligne : la session se construit depuis les fiches locales', () async {
    final seed = container(statuses: [_status(3, 'c3', a: 2)], server: {'c3': [_card('a', 'c3'), _card('b', 'c3')]});
    await seed.read(todayProvider.future);
    seed.dispose();
    await (db.delete(db.dailySessions)).go();

    final offline = container(statuses: [_status(3, 'c3', a: 2)], offline: true);
    final state = await offline.read(todayProvider.future) as TodayReady;
    expect(state.cardCount, 2);
  });

  test('budget : préférence de nombre de fiches (sans planning)', () async {
    final c = container(
      statuses: [_status(3, 'c3', a: 30)],
      server: {'c3': [for (var i = 0; i < 30; i++) _card('n$i', 'c3')]},
      prefs: const RevisionPrefs(defaultMaxCards: 10),
    );
    final state = await c.read(todayProvider.future) as TodayReady;
    expect(state.cardCount, 10);
  });

  test('semaine : 7 jours du lundi au dimanche, aujourd’hui marqué, jour fait rempli', () async {
    final c = container(statuses: [_status(3, 'c3', a: 1)], server: {'c3': [_card('a', 'c3')]});
    await c.read(todayProvider.future);
    await DailySessionRepository(db).complete(today);
    c.invalidate(todayProvider);
    final state = await c.read(todayProvider.future) as TodayReady;
    expect(state.week, hasLength(7));
    expect(state.week.first.date.weekday, DateTime.monday);
    final todayDot = state.week.singleWhere((d) => d.isToday);
    expect(todayDot.done, isTrue);
    expect(state.session.isCompleted, isTrue);
  });

  test('personnaliser : reconstruit la session et recharge l’état', () async {
    final c = container(
      statuses: [_status(3, 'c3', a: 2), _status(34, 'c34', a: 1)],
      server: {'c3': [_card('a', 'c3'), _card('b', 'c3')], 'c34': [_card('x', 'c34')]},
    );
    await c.read(todayProvider.future);
    await c.read(todayProvider.notifier).customize(collegeIds: {'c34'});
    final state = await c.read(todayProvider.future) as TodayReady;
    expect(state.cardCount, 1);
    expect(state.mix.single.collegeName, 'Pneumologie');
    expect(state.budget, 24, reason: 'le budget du jour ne fond pas en filtrant');
  });

  test('aucun collège joignable et aucun cache → erreur (état d’erreur de l’écran)', () async {
    final c = container(collegesError: DioException(requestOptions: RequestOptions()));
    await expectLater(c.read(todayProvider.future), throwsA(isA<DioException>()));
  });

  test('planning : jour N sur M et budget en minutes', () async {
    final c = container(
      statuses: [_status(3, 'c3', a: 40)],
      server: {'c3': [for (var i = 0; i < 40; i++) _card('n$i', 'c3')]},
    );
    await c.read(planningRepositoryProvider).saveConfig(PlanningConfig(
          id: 'cfg',
          collegeIds: const ['c3'],
          startDate: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 2)),
          endDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 27)),
          dailyMinutes: 20,
          createdAt: now,
        ));
    final state = await c.read(todayProvider.future) as TodayReady;
    expect(state.planningDay, 3);
    expect(state.planningDays, 30);
    expect(state.cardCount, 24);
  });
}

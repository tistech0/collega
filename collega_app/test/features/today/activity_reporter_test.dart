import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/colleges/data/college_cards_sync.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/today/data/activity_reporter.dart';
import 'package:collega_app/features/today/data/daily_session_repository.dart';

/// Adapter Dio scripté qui enregistre les requêtes (pattern repris de
/// `test/core/network/api_client_test.dart`).
class _Recorder implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool fail = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? body, Future<void>? cancel) async {
    requests.add(options);
    if (fail) throw DioException.connectionError(requestOptions: options, reason: 'hors ligne');
    return ResponseBody.fromString(
      jsonEncode({'data': options.data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

FlashCardModel _server(String id, {String college = 'c1', String rang = 'A'}) => FlashCardModel(
      id: id,
      itemId: 'i-$id',
      collegeId: college,
      cardType: 'classique',
      rang: rang,
      recto: 'Q',
      verso: 'R',
      ocrConfidenceScore: 0.9,
      lowConfidence: false,
    );

void main() {
  late AppDatabase db;
  late DailySessionRepository repo;
  late _Recorder http;
  late ActivityReporter reporter;
  const day = 20722; // 2026-09-26 en jours epoch

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DailySessionRepository(db);
    http = _Recorder();
    reporter = ActivityReporter(
      dio: Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = http,
      repo: repo,
      postponedDays: () async => <int>{},
      debounce: const Duration(milliseconds: 50),
    );
  });
  tearDown(() async {
    reporter.dispose();
    await db.close();
  });

  Future<void> verdict(int d, String card) =>
      repo.recordVerdict(day: d, cardId: card, collegeId: 'c1', rang: 'A', drillLevel: 'bien', daily: true);

  test('summarize : fiches distinctes, séance terminée, série', () async {
    // Séance de la veille : une fiche locale pour que getOrBuild construise
    // une vraie session, puis clôturée (recordVerdict seul n'écrit pas de session).
    await syncCollegeCards(db, 'c1', [_server('a')]);
    await repo.getOrBuild(day: day - 1, budget: 5);
    await verdict(day - 1, 'a');
    await repo.complete(day - 1);

    await verdict(day, 'a');
    await verdict(day, 'a');
    await verdict(day, 'b');

    final s = await reporter.summarize(day);
    expect(s.cardsReviewed, 2);
    expect(s.sessionCompleted, isFalse);
    expect(s.streak, 1);
  });

  test('report : PUT /v1/activity/<date> avec les compteurs', () async {
    await verdict(day, 'a');
    await reporter.report(day);
    expect(http.requests, hasLength(1));
    expect(http.requests.single.method, 'PUT');
    expect(http.requests.single.path, '/v1/activity/2026-09-26');
    expect(http.requests.single.data, {'cards_reviewed': 1, 'session_completed': false, 'streak': 0});
  });

  test('hors ligne : aucune exception', () async {
    http.fail = true;
    await reporter.report(day);
    expect(http.requests, hasLength(1));
  });

  test('schedule : un seul envoi après l\'anti-rebond', () async {
    reporter.schedule(day);
    reporter.schedule(day);
    // Rien avant l'anti-rebond (50 ms) : vérifié tôt (30 ms), marge large sous CI.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(http.requests, isEmpty);
    // Puis on attend la requête par sondage plutôt qu'un délai fixe après le
    // debounce (40 ms de marge) : sous charge CI, le Timer peut se déclencher
    // en retard et rendre le test flaky. On sonde jusqu'à 2 s.
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (http.requests.isEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(http.requests, hasLength(1));
  });

  test('reportRecent : seulement les jours avec de l\'activité, sur 7 jours', () async {
    await verdict(day - 2, 'a');
    await verdict(day - 9, 'b');
    await reporter.reportRecent(today: day);
    expect(http.requests.map((r) => r.path), ['/v1/activity/2026-09-24']);
  });
}

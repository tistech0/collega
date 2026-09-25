import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/drill/data/drill_repository.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';

AppDatabase _makeDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// Adapter Dio qui rejoue une séquence pré-définie de réponses ou d'exceptions
/// (Story 7.2 AC #6 — vérifier le retry sur receiveTimeout/5xx).
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.script);

  final List<Object> script;
  int callCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final idx = callCount;
    callCount += 1;
    if (idx >= script.length) {
      throw StateError('ScriptedAdapter ran out of responses at call $idx');
    }
    final item = script[idx];
    if (item is DioExceptionType) {
      throw DioException(
        type: item,
        requestOptions: options,
        message: 'fake-$item',
      );
    }
    if (item is int) {
      // status code (utilisé pour les 5xx → Dio renvoie une DioException)
      final body = utf8.encode(jsonEncode({'error': 'server', 'status': item}));
      return ResponseBody.fromBytes(body, item);
    }
    if (item is Map<String, dynamic>) {
      final body = utf8.encode(jsonEncode(item));
      return ResponseBody.fromBytes(
        body,
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    throw StateError('Unknown scripted item type: ${item.runtimeType}');
  }

  @override
  void close({bool force = false}) {}
}

Dio _makeScriptedDio(_ScriptedAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://test',
    // Validation : status >= 500 doit lever DioException (sinon Dio renvoie une réponse OK)
    validateStatus: (status) => status != null && status < 500,
  ));
  dio.httpClientAdapter = adapter;
  return dio;
}

Future<void> _insertCard(
  AppDatabase db, {
  required String id,
  required String itemId,
  String rang = 'A',
  String drillLevel = 'new',
}) async {
  await db.into(db.flashCards).insert(FlashCardsCompanion.insert(
        id: id,
        itemId: itemId,
        collegeId: 'c1',
        cardType: 'classique',
        rang: rang,
        recto: 'Q',
        verso: 'R',
      ));
  if (drillLevel != 'new') {
    await (db.update(db.flashCards)..where((t) => t.id.equals(id))).write(
      FlashCardsCompanion(drillLevel: Value(drillLevel)),
    );
  }
}

void main() {
  group('DrillRepository', () {
    test('getCardsForDrill — retourne les fiches sans réseau', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final repo = DrillRepository(dio: Dio(), db: db);

      await _insertCard(db, id: 'c1', itemId: 'i1');
      await _insertCard(db, id: 'c2', itemId: 'i1');
      await _insertCard(db, id: 'other', itemId: 'i2');

      final cards = await repo.getCardsForDrill(collegeId: 'c1', itemId: 'i1');
      expect(cards.length, 2);
      expect(cards.map((c) => c.id), containsAll(['c1', 'c2']));
    });

    test('getCardsForDrill(rangs: B) — seulement les fiches B, même dans un item de rang A (chantier 4)', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final repo = DrillRepository(dio: Dio(), db: db);

      // Item i1 (rang A côté item) : fiches A et B ; item i2 : fiche B.
      await _insertCard(db, id: 'a1', itemId: 'i1');
      await _insertCard(db, id: 'b1', itemId: 'i1', rang: 'B');
      await _insertCard(db, id: 'b2', itemId: 'i2', rang: 'B');
      await _insertCard(db, id: 'a2', itemId: 'i2');

      final cards = await repo.getCardsForDrill(collegeId: 'c1', rangs: ['B']);
      expect(cards.map((c) => c.id), unorderedEquals(['b1', 'b2']));
    });

    test('updateCardDrillLevel(bien) → drillLevel=bien, nextReviewAt≈now+1j',
        () async {
      final db = _makeDb();
      addTearDown(db.close);
      final repo = DrillRepository(dio: Dio(), db: db);

      await _insertCard(db, id: 'card', itemId: 'i1');
      final beforeMs = DateTime.now().toUtc().millisecondsSinceEpoch;

      await repo.updateCardDrillLevel('card', DrillEvaluationResult.bien);

      final row = await (db.select(db.flashCards)
            ..where((t) => t.id.equals('card')))
          .getSingle();
      expect(row.drillLevel, 'bien');
      expect(row.nextReviewAt, isNotNull);
      final diff = row.nextReviewAt! - beforeMs;
      expect(diff, greaterThanOrEqualTo(86400000 - 1000));
      expect(diff, lessThanOrEqualTo(86400000 + 5000));
    });

    test('updateCardDrillLevel(maitrise) → nextReviewAt≈now+7j', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final repo = DrillRepository(dio: Dio(), db: db);

      await _insertCard(db, id: 'card', itemId: 'i1');
      final beforeMs = DateTime.now().toUtc().millisecondsSinceEpoch;

      await repo.updateCardDrillLevel('card', DrillEvaluationResult.maitrise);

      final row = await (db.select(db.flashCards)
            ..where((t) => t.id.equals('card')))
          .getSingle();
      expect(row.drillLevel, 'maitrise');
      final diff = row.nextReviewAt! - beforeMs;
      expect(diff, greaterThanOrEqualTo(7 * 86400000 - 1000));
      expect(diff, lessThanOrEqualTo(7 * 86400000 + 5000));
    });

    test('updateCardDrillLevel incrémente reviewCount (fix D7)', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final repo = DrillRepository(dio: Dio(), db: db);

      await _insertCard(db, id: 'card', itemId: 'i1');

      // Premier review
      await repo.updateCardDrillLevel('card', DrillEvaluationResult.bien);
      final row1 = await (db.select(db.flashCards)
            ..where((t) => t.id.equals('card')))
          .getSingle();
      expect(row1.reviewCount, 1);

      // Deuxième review
      await repo.updateCardDrillLevel('card', DrillEvaluationResult.maitrise);
      final row2 = await (db.select(db.flashCards)
            ..where((t) => t.id.equals('card')))
          .getSingle();
      expect(row2.reviewCount, 2);
    });
  });

  group('DrillRepository.evaluateSemantic (Story 7.2 AC #6)', () {
    Map<String, dynamic> okBody() => {
          'data': {'result': 'correct', 'feedback': 'Bonne réponse'},
        };

    test('succès au 1er essai → 1 appel HTTP', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final adapter = _ScriptedAdapter([okBody()]);
      final repo = DrillRepository(dio: _makeScriptedDio(adapter), db: db);

      final feedback = await repo.evaluateSemantic('card-1', 'ma réponse');

      expect(adapter.callCount, 1);
      expect(feedback.result, 'correct');
      expect(feedback.feedback, 'Bonne réponse');
    });

    test('timeout au 1er essai puis succès → 2 appels HTTP', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final adapter = _ScriptedAdapter([
        DioExceptionType.receiveTimeout,
        okBody(),
      ]);
      final repo = DrillRepository(dio: _makeScriptedDio(adapter), db: db);

      final feedback = await repo.evaluateSemantic('card-1', 'ma réponse');

      expect(adapter.callCount, 2);
      expect(feedback.result, 'correct');
    });

    test('timeout sur les 2 essais → DioException relancée', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final adapter = _ScriptedAdapter([
        DioExceptionType.receiveTimeout,
        DioExceptionType.receiveTimeout,
      ]);
      final repo = DrillRepository(dio: _makeScriptedDio(adapter), db: db);

      await expectLater(
        repo.evaluateSemantic('card-1', 'ma réponse'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.callCount, 2, reason: 'maxAttempts = 2 (1 try + 1 retry)');
    });

    test('connectionTimeout → retry comme receiveTimeout', () async {
      final db = _makeDb();
      addTearDown(db.close);
      final adapter = _ScriptedAdapter([
        DioExceptionType.connectionTimeout,
        okBody(),
      ]);
      final repo = DrillRepository(dio: _makeScriptedDio(adapter), db: db);

      await repo.evaluateSemantic('card-1', 'ma réponse');
      expect(adapter.callCount, 2);
    });

    test('500 → retry puis succès', () async {
      final db = _makeDb();
      addTearDown(db.close);
      // Dio considère un 500 comme erreur car validateStatus < 500 = ok
      final adapter = _ScriptedAdapter([500, okBody()]);
      final repo = DrillRepository(dio: _makeScriptedDio(adapter), db: db);

      await repo.evaluateSemantic('card-1', 'ma réponse');
      expect(adapter.callCount, 2);
    });

    test('422 → PAS de retry, rethrow immédiat', () async {
      final db = _makeDb();
      addTearDown(db.close);
      // 422 = erreur cliente, ne doit pas être retentée
      final dio = Dio(BaseOptions(
        baseUrl: 'http://test',
        // Tout sauf < 422 doit lever → 422 lève
        validateStatus: (status) => status != null && status < 422,
      ));
      final adapter = _ScriptedAdapter([422]);
      dio.httpClientAdapter = adapter;
      final repo = DrillRepository(dio: dio, db: db);

      await expectLater(
        repo.evaluateSemantic('card-1', 'ma réponse'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.callCount, 1, reason: 'pas de retry sur 4xx');
    });
  });
}

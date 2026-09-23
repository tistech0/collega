import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/auth/data/auth_repository.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';

/// Fake storage qui trace les `delete()` pour vérifier qu'`AuthRepository.deleteAccount`
/// ne vide PLUS le storage en interne (Story 7.3 T5 — wipe délégué au Notifier).
class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage({Map<String, String>? initial}) : _store = {...?initial};

  final Map<String, String> _store;
  final List<String> deletedKeys = [];
  final List<String> writtenKeys = [];

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store[key];

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    deletedKeys.add(key);
    _store.remove(key);
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    writtenKeys.add(key);
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }
}

/// Adapter Dio qui rejoue une séquence pré-définie de réponses / exceptions
/// (pattern réutilisé depuis `drill_repository_test.dart`, Story 7.2).
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
      final body = utf8.encode(jsonEncode({'detail': {'message': 'server error'}}));
      // Content-Type explicite : sans ça, Dio ne parse pas le body en JSON et
      // `_extractError` ne peut pas lire `detail.message` → fallback générique.
      return ResponseBody.fromBytes(
        body,
        item,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
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

Dio _makeScriptedDio(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://test',
    validateStatus: (status) => status != null && status < 500,
  ));
  dio.httpClientAdapter = adapter;
  return dio;
}

/// Adapter Dio qui renvoie une réponse brute non-JSON (HTML, vide, etc.) avec
/// un Content-Type configurable — pour tester que `auth_repository.deleteAccount`
/// supporte un 2xx dont le body ne se cast pas en `Map<String, dynamic>`.
class _ScriptedRawAdapter implements HttpClientAdapter {
  _ScriptedRawAdapter({
    required this.statusCode,
    required this.body,
    required this.contentType,
  });

  final int statusCode;
  final String body;
  final String contentType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      utf8.encode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('AuthRepository.login — erreur typée (story 8.12)', () {
    Future<LoginError?> errorFor(HttpClientAdapter adapter) async {
      // Validation des statuts par défaut, comme le client de l'app (4xx = exception).
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;
      final repo = AuthRepository(dio: dio, storage: _FakeSecureStorage());
      return (await repo.login('a@b.fr', 'x')).loginError;
    }

    test('401 → identifiants incorrects', () async {
      expect(await errorFor(_ScriptedRawAdapter(statusCode: 401, body: '{"detail":{"code":"INVALID_CREDENTIALS"}}',
          contentType: 'application/json')), LoginError.invalidCredentials);
    });

    test('429 → trop d’essais', () async {
      expect(await errorFor(_ScriptedRawAdapter(statusCode: 429, body: '{}', contentType: 'application/json')),
          LoginError.tooManyAttempts);
    });

    test('réseau injoignable → réseau', () async {
      expect(await errorFor(_ScriptedAdapter([DioExceptionType.connectionError])), LoginError.network);
    });

    test('422 (email mal formé) → email invalide', () async {
      expect(await errorFor(_ScriptedRawAdapter(statusCode: 422, body: '{}', contentType: 'application/json')),
          LoginError.invalidEmail);
    });

    test('500 → autre', () async {
      expect(await errorFor(_ScriptedRawAdapter(statusCode: 500, body: '{}', contentType: 'application/json')),
          LoginError.other);
    });
  });

  group('AuthRepository /me (story 8.14)', () {
    Map<String, dynamic> me({int? reminder}) => {
          'data': {
            'id': 'u', 'email': 'a@b.fr', 'is_beta': true, 'is_subscribed': false,
            'first_name': 'Léa', 'year_group': null, 'faculty': null,
            'monthly_reloads': 1, 'monthly_reloads_max': 3,
            'monthly_reloads_reset_at': '2026-10-01T00:00:00+00:00',
            'reminder_hour_utc': reminder,
          },
        };

    test('refreshFromMe : renouvellement du quota et heure du rappel, mémorisés pour un démarrage hors-ligne', () async {
      final storage = _FakeSecureStorage(initial: {'access_token': 't', 'user_id': 'u', 'user_email': 'a@b.fr'});
      final repo = AuthRepository(dio: _makeScriptedDio(_ScriptedAdapter([me(reminder: 6)])), storage: storage);

      final user = (await repo.refreshFromMe()).user!;
      expect(user.monthlyResetAt, DateTime.utc(2026, 10, 1));
      expect(user.reminderHourUtc, 6);

      final stored = (await repo.loadStoredUser()).user!;
      expect(stored.monthlyResetAt, DateTime.utc(2026, 10, 1));
      expect(stored.reminderHourUtc, 6);
    });

    test('saveReminderHour(null) : rappel éteint au prochain démarrage', () async {
      final storage = _FakeSecureStorage(initial: {
        'access_token': 't', 'user_id': 'u', 'user_email': 'a@b.fr', 'reminder_hour_utc': '6',
      });
      final repo = AuthRepository(dio: Dio(), storage: storage);
      await repo.saveReminderHour(null);
      expect((await repo.loadStoredUser()).user!.reminderHourUtc, isNull);
    });

    test('logout oublie le rappel et la date de renouvellement', () async {
      final storage = _FakeSecureStorage();
      await AuthRepository(dio: Dio(), storage: storage).logout();
      expect(storage.deletedKeys, containsAll(['reminder_hour_utc', 'monthly_reset_at']));
    });
  });

  group('AuthRepository.deleteAccount (Story 7.3 — safe delete)', () {
    test('pas de token → errorMessage explicite, pas de wipe', () async {
      final storage = _FakeSecureStorage();
      final repo = AuthRepository(dio: Dio(), storage: storage);

      final result = await repo.deleteAccount();

      expect(result.errorMessage, contains('Session expirée'));
      expect(storage.deletedKeys, isEmpty);
    });

    test('200 → AuthState sans errorMessage, storage intact', () async {
      final storage = _FakeSecureStorage(initial: {'access_token': 'tok'});
      final adapter = _ScriptedAdapter([
        {'data': {'message': 'Account deleted'}},
      ]);
      final repo = AuthRepository(dio: _makeScriptedDio(adapter), storage: storage);

      final result = await repo.deleteAccount();

      expect(result.errorMessage, isNull);
      // Le wipe est désormais externe (AuthNotifier) — le repo ne doit RIEN
      // supprimer du storage lui-même.
      expect(storage.deletedKeys, isEmpty);
      expect(adapter.callCount, 1);
    });

    test('timeout Dio → errorMessage, storage intact', () async {
      final storage = _FakeSecureStorage(initial: {'access_token': 'tok'});
      final adapter = _ScriptedAdapter([DioExceptionType.receiveTimeout]);
      final repo = AuthRepository(dio: _makeScriptedDio(adapter), storage: storage);

      final result = await repo.deleteAccount();

      expect(result.errorMessage, isNotNull);
      expect(storage.deletedKeys, isEmpty);
    });

    test('500 → errorMessage extrait du detail.message, storage intact', () async {
      final storage = _FakeSecureStorage(initial: {'access_token': 'tok'});
      final adapter = _ScriptedAdapter([500]);
      final repo = AuthRepository(dio: _makeScriptedDio(adapter), storage: storage);

      final result = await repo.deleteAccount();

      // _extractError doit lire `detail.message` du body JSON (cf. fixture
      // _ScriptedAdapter : `{'detail': {'message': 'server error'}}`).
      // Si la branche extraction casse, le fallback `'Erreur réseau, veuillez
      // réessayer'` masquerait le bug — l'assertion exacte verrouille le cas.
      expect(result.errorMessage, 'server error');
      expect(storage.deletedKeys, isEmpty);
    });

    test('200 avec body non-JSON → succès sans throw, storage intact', () async {
      // Scénario : proxy/CDN renvoie un 200 avec body HTML/vide. Le cast
      // implicite `Response.data as Map<String, dynamic>?` aurait throw côté
      // repo avant le patch ; désormais le repo utilise `<dynamic>` et ne lit
      // pas le body. La séquence delete doit retourner succès — sinon le wipe
      // local serait bloqué alors que le compte est déjà supprimé serveur.
      final storage = _FakeSecureStorage(initial: {'access_token': 'tok'});
      final adapter = _ScriptedRawAdapter(
        statusCode: 200,
        body: '<html>OK</html>',
        contentType: 'text/html',
      );
      final repo = AuthRepository(dio: _makeScriptedDio(adapter), storage: storage);

      final result = await repo.deleteAccount();

      expect(result.errorMessage, isNull);
      expect(storage.deletedKeys, isEmpty);
    });

    test('connectionError → errorMessage, storage intact', () async {
      final storage = _FakeSecureStorage(initial: {'access_token': 'tok'});
      final adapter = _ScriptedAdapter([DioExceptionType.connectionError]);
      final repo = AuthRepository(dio: _makeScriptedDio(adapter), storage: storage);

      final result = await repo.deleteAccount();

      expect(result.errorMessage, isNotNull);
      expect(storage.deletedKeys, isEmpty);
    });
  });
}

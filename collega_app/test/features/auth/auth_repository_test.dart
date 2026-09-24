import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/network/api_client.dart';
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

  /// Requêtes reçues (path, headers, body) — pour vérifier ce que le repo
  /// envoie réellement (Story task 5 — appel `/v1/auth/logout`).
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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

/// Dio « nu » (validateStatus par défaut : 4xx/5xx lèvent) — comme le groupe
/// `login — erreur typée`, pour tester les statuts d'erreur de `logout()`.
Dio _plainDio(HttpClientAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;

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

    // Chantier 5 § 4 : corps uniformes {"detail": {"code", "message", ...}} pour 422 et 429.
    test('422 VALIDATION_ERROR (corps uniforme) → email invalide', () async {
      const body = '{"detail":{"code":"VALIDATION_ERROR","message":"Requête invalide",'
          '"errors":[{"loc":["body","email"],"msg":"value is not a valid email address","type":"value_error"}]}}';
      expect(await errorFor(_ScriptedRawAdapter(statusCode: 422, body: body, contentType: 'application/json')),
          LoginError.invalidEmail);
    });

    test('429 RATE_LIMITED (corps uniforme) → trop d’essais', () async {
      const body = '{"detail":{"code":"RATE_LIMITED","message":"Trop de requêtes, réessayez plus tard"}}';
      expect(await errorFor(_ScriptedRawAdapter(statusCode: 429, body: body, contentType: 'application/json')),
          LoginError.tooManyAttempts);
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

    test('refreshFromMe d’un autre compte (réponse tardive) : rien n’est écrit', () async {
      final storage = _FakeSecureStorage(initial: {'access_token': 't', 'user_id': 'autre', 'user_email': 'b@b.fr'});
      final repo = AuthRepository(dio: _makeScriptedDio(_ScriptedAdapter([me(reminder: 6)])), storage: storage);

      final result = await repo.refreshFromMe();
      expect(result.user, isNull);
      expect(storage.writtenKeys, isEmpty);
    });

    test('refreshFromMe après déconnexion : rien n’est réécrit', () async {
      final storage = _FakeSecureStorage();
      final repo = AuthRepository(dio: _makeScriptedDio(_ScriptedAdapter([me(reminder: 6)])), storage: storage);
      expect((await repo.refreshFromMe()).user, isNull);
      expect(storage.writtenKeys, isEmpty);
    });

    test('connexion : rappel et renouvellement du compte connecté (jamais ceux du précédent)', () async {
      final storage = _FakeSecureStorage(initial: {'reminder_hour_utc': '9', 'reminder_local_hour': '11'});
      final repo = AuthRepository(
        dio: _makeScriptedDio(_ScriptedAdapter([
          {'data': {'access_token': 'a', 'refresh_token': 'r', 'is_beta': true, 'is_subscribed': false}},
          me(reminder: null),
        ])),
        storage: storage,
      );
      final user = (await repo.login('a@b.fr', 'x')).user!;
      expect(user.reminderHourUtc, isNull);
      expect(user.monthlyResetAt, DateTime.utc(2026, 10, 1));
      final stored = (await repo.loadStoredUser()).user!;
      expect(stored.reminderHourUtc, isNull);
      expect(stored.reminderLocalHour, isNull);
    });

    test('saveReminderHour : heure locale choisie gardée (changement d’heure)', () async {
      final storage = _FakeSecureStorage(initial: {'access_token': 't', 'user_id': 'u', 'user_email': 'a@b.fr'});
      final repo = AuthRepository(dio: Dio(), storage: storage);
      await repo.saveReminderHour(6, localHour: 8);
      final stored = (await repo.loadStoredUser()).user!;
      expect(stored.reminderHourUtc, 6);
      expect(stored.reminderLocalHour, 8);
    });

    test('saveReminderHour(null) : rappel éteint au prochain démarrage', () async {
      final storage = _FakeSecureStorage(initial: {
        'access_token': 't', 'user_id': 'u', 'user_email': 'a@b.fr', 'reminder_hour_utc': '6',
        'reminder_local_hour': '8',
      });
      final repo = AuthRepository(dio: Dio(), storage: storage);
      await repo.saveReminderHour(null);
      final stored = (await repo.loadStoredUser()).user!;
      expect(stored.reminderHourUtc, isNull);
      expect(stored.reminderLocalHour, isNull);
    });

    test('logout oublie le rappel et la date de renouvellement', () async {
      final storage = _FakeSecureStorage();
      await AuthRepository(dio: Dio(), storage: storage).logout();
      expect(storage.deletedKeys, containsAll(['reminder_hour_utc', 'reminder_local_hour', 'monthly_reset_at']));
    });
  });

  group('AuthRepository.logout — appel serveur best-effort (chantier 2 sécurité, task 5)', () {
    test('pas d’access_token → aucun appel réseau, storage vidé quand même', () async {
      final storage = _FakeSecureStorage();
      final adapter = _ScriptedAdapter([204]);
      final repo = AuthRepository(dio: _plainDio(adapter), storage: storage);

      await repo.logout();

      expect(adapter.callCount, 0);
      expect(storage.deletedKeys, containsAll(['access_token', 'refresh_token', 'user_id']));
    });

    test('API OK (204) → POST /v1/auth/logout avec le refresh_token stocké, puis storage vidé', () async {
      final storage = _FakeSecureStorage(initial: {
        'access_token': 'acc-1',
        'refresh_token': 'ref-1',
        'user_id': 'u',
        'user_email': 'a@b.fr',
      });
      final adapter = _ScriptedAdapter([204]);
      final repo = AuthRepository(dio: _plainDio(adapter), storage: storage);

      await repo.logout();

      expect(adapter.callCount, 1);
      final sent = adapter.requests.single;
      expect(sent.path, '/v1/auth/logout');
      expect(sent.headers['Authorization'], 'Bearer acc-1');
      expect(sent.data, {'refresh_token': 'ref-1'});
      expect(
        storage.deletedKeys,
        containsAll(['access_token', 'refresh_token', 'user_id', 'user_email']),
      );
    });

    test('API en erreur (500) → appel tenté, storage vidé quand même', () async {
      final storage = _FakeSecureStorage(initial: {'access_token': 'acc-1', 'refresh_token': 'ref-1'});
      final adapter = _ScriptedAdapter([500]);
      final repo = AuthRepository(dio: _plainDio(adapter), storage: storage);

      await repo.logout();

      expect(adapter.callCount, 1);
      expect(storage.deletedKeys, containsAll(['access_token', 'refresh_token']));
    });

    test('401 (access token déjà expiré côté serveur) → ignoré, storage vidé quand même', () async {
      final storage = _FakeSecureStorage(initial: {'access_token': 'acc-1', 'refresh_token': 'ref-1'});
      final adapter = _ScriptedAdapter([401]);
      final repo = AuthRepository(dio: _plainDio(adapter), storage: storage);

      await repo.logout();

      expect(storage.deletedKeys, containsAll(['access_token', 'refresh_token']));
    });

    test('timeout réseau → storage vidé quand même', () async {
      final storage = _FakeSecureStorage(initial: {'access_token': 'acc-1', 'refresh_token': 'ref-1'});
      final adapter = _ScriptedAdapter([DioExceptionType.sendTimeout]);
      final repo = AuthRepository(dio: _plainDio(adapter), storage: storage);

      await repo.logout();

      expect(storage.deletedKeys, containsAll(['access_token', 'refresh_token']));
    });
  });

  group('AuthRepository.logout — rotation défensive avant logout (fix round 1)', () {
    test(
      'rotation R1→R2 pré-logout : /logout reçoit R2 (jamais figé sur R1), '
      'jamais via le dio intercepté 401→refresh→retry',
      () async {
        final storage = _FakeSecureStorage(initial: {
          'access_token': 'stale-access',
          'refresh_token': 'R1',
          'user_id': 'u',
          'user_email': 'a@b.fr',
        });

        // ApiClient.rawDio (= _refreshDio) : 1) le refresh défensif (R1→R2),
        // 2) le POST /v1/auth/logout lui-même.
        final rawAdapter = _ScriptedAdapter([
          {
            'data': {'access_token': 'new-access', 'refresh_token': 'R2'},
          },
          204,
        ]);
        // ApiClient.dio (intercepté 401→refresh→retry) : ne doit JAMAIS être
        // sollicité par logout() — script vide, tout appel ici fait échouer
        // le test (StateError).
        final interceptedAdapter = _ScriptedAdapter([]);

        final apiClient = ApiClient(
          storage,
          dio: _plainDio(interceptedAdapter),
          refreshDio: _plainDio(rawAdapter),
        );

        final repo = AuthRepository(
          dio: apiClient.dio,
          storage: storage,
          logoutDio: apiClient.rawDio,
          ensureFreshAccessToken: apiClient.ensureFreshAccessToken,
        );

        await repo.logout();

        expect(interceptedAdapter.callCount, 0);
        expect(rawAdapter.callCount, 2);
        expect(rawAdapter.requests[0].path, '/v1/auth/refresh');
        final logoutSent = rawAdapter.requests[1];
        expect(logoutSent.path, '/v1/auth/logout');
        expect(logoutSent.headers['Authorization'], 'Bearer new-access');
        // Le corps envoyé porte le refresh_token POST-rotation (R2) — jamais
        // l'ancien R1 lu avant la rotation défensive.
        expect(logoutSent.data, {'refresh_token': 'R2'});
        expect(await storage.read(key: 'access_token'), isNull);
        expect(await storage.read(key: 'refresh_token'), isNull);
      },
    );

    test('rafraîchissement défensif en échec → logout suit avec les jetons existants (best-effort)', () async {
      final storage = _FakeSecureStorage(initial: {'access_token': 'acc-1', 'refresh_token': 'ref-1'});
      final rawAdapter = _ScriptedAdapter([DioExceptionType.connectionError, 204]);
      final interceptedAdapter = _ScriptedAdapter([]);

      final apiClient = ApiClient(
        storage,
        dio: _plainDio(interceptedAdapter),
        refreshDio: _plainDio(rawAdapter),
      );
      final repo = AuthRepository(
        dio: apiClient.dio,
        storage: storage,
        logoutDio: apiClient.rawDio,
        ensureFreshAccessToken: apiClient.ensureFreshAccessToken,
      );

      await repo.logout();

      expect(rawAdapter.callCount, 2);
      final logoutSent = rawAdapter.requests[1];
      expect(logoutSent.headers['Authorization'], 'Bearer acc-1');
      expect(logoutSent.data, {'refresh_token': 'ref-1'});
      expect(await storage.read(key: 'access_token'), isNull);
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

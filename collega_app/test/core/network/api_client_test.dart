import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/network/api_client.dart';

/// Fake storage minimal (pattern repris de `auth_repository_test.dart`).
class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage({Map<String, String>? initial}) : _store = {...?initial};

  final Map<String, String> _store;
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
    _store.remove(key);
  }
}

/// Adapter Dio qui rejoue une séquence pré-définie de réponses / exceptions
/// (pattern repris de `auth_repository_test.dart` / `drill_repository_test.dart`).
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
      throw DioException(type: item, requestOptions: options, message: 'fake-$item');
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

Dio _scriptedDio(HttpClientAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = adapter;

/// JWT factice (signature non vérifiée côté app) expirant dans [expiresIn].
String _jwt(Duration expiresIn) {
  String part(Map<String, Object> m) => base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(expiresIn).millisecondsSinceEpoch ~/ 1000;
  return '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': 'u', 'type': 'access', 'exp': exp})}.c2ln';
}

void main() {
  group('ApiClient._tryRefresh (via ensureFreshAccessToken) — rotation (chantier 2 § 8 task 5)', () {
    test('refresh réussi → access_token ET refresh_token (nouveau) stockés', () async {
      final storage = _FakeSecureStorage(initial: {'refresh_token': 'old-refresh'});
      final adapter = _ScriptedAdapter([
        {
          'data': {'access_token': 'new-access', 'refresh_token': 'new-refresh'},
        },
      ]);
      final client = ApiClient(storage, refreshDio: _scriptedDio(adapter));

      final ok = await client.ensureFreshAccessToken();

      expect(ok, isTrue);
      expect(await storage.read(key: 'access_token'), 'new-access');
      expect(await storage.read(key: 'refresh_token'), 'new-refresh');
    });

    test('réponse sans refresh_token → access_token stocké, refresh_token existant inchangé', () async {
      final storage = _FakeSecureStorage(initial: {'refresh_token': 'old-refresh'});
      final adapter = _ScriptedAdapter([
        {
          'data': {'access_token': 'new-access'},
        },
      ]);
      final client = ApiClient(storage, refreshDio: _scriptedDio(adapter));

      final ok = await client.ensureFreshAccessToken();

      expect(ok, isTrue);
      expect(await storage.read(key: 'access_token'), 'new-access');
      expect(await storage.read(key: 'refresh_token'), 'old-refresh');
    });

    test('réponse avec refresh_token vide → ignoré, refresh_token existant inchangé', () async {
      final storage = _FakeSecureStorage(initial: {'refresh_token': 'old-refresh'});
      final adapter = _ScriptedAdapter([
        {
          'data': {'access_token': 'new-access', 'refresh_token': ''},
        },
      ]);
      final client = ApiClient(storage, refreshDio: _scriptedDio(adapter));

      await client.ensureFreshAccessToken();

      expect(await storage.read(key: 'refresh_token'), 'old-refresh');
    });

    test('aucun refresh_token stocké → aucun appel, retourne false', () async {
      final storage = _FakeSecureStorage();
      final adapter = _ScriptedAdapter([DioExceptionType.connectionError]);
      final client = ApiClient(storage, refreshDio: _scriptedDio(adapter));

      final ok = await client.ensureFreshAccessToken();

      expect(ok, isFalse);
      expect(adapter.callCount, 0);
    });

    test('appel réseau en échec → retourne false, storage inchangé', () async {
      final storage = _FakeSecureStorage(initial: {'refresh_token': 'old-refresh'});
      final adapter = _ScriptedAdapter([DioExceptionType.connectionError]);
      final client = ApiClient(storage, refreshDio: _scriptedDio(adapter));

      final ok = await client.ensureFreshAccessToken();

      expect(ok, isFalse);
      expect(await storage.read(key: 'access_token'), isNull);
      expect(await storage.read(key: 'refresh_token'), 'old-refresh');
    });

    test('écriture : refresh_token AVANT access_token (m1)', () async {
      final storage = _FakeSecureStorage(initial: {'refresh_token': 'old-refresh'});
      final adapter = _ScriptedAdapter([
        {
          'data': {'access_token': 'new-access', 'refresh_token': 'new-refresh'},
        },
      ]);
      final client = ApiClient(storage, refreshDio: _scriptedDio(adapter));

      await client.ensureFreshAccessToken();

      expect(storage.writtenKeys, ['refresh_token', 'access_token']);
    });

    test('appels concurrents → un seul appel réseau (verrou _isRefreshing/_refreshFuture)', () async {
      final storage = _FakeSecureStorage(initial: {'refresh_token': 'old-refresh'});
      final adapter = _ScriptedAdapter([
        {
          'data': {'access_token': 'new-access', 'refresh_token': 'new-refresh'},
        },
      ]);
      final client = ApiClient(storage, refreshDio: _scriptedDio(adapter));

      final results = await Future.wait([
        client.ensureFreshAccessToken(),
        client.ensureFreshAccessToken(),
      ]);

      expect(results, [true, true]);
      expect(adapter.callCount, 1);
    });
  });

  group('ensureFreshAccessToken — refresh seulement si l\'access expire dans < 2 min (I4)', () {
    test('access valide encore 10 min → aucun appel réseau, true', () async {
      final access = _jwt(const Duration(minutes: 10));
      final storage = _FakeSecureStorage(initial: {'access_token': access, 'refresh_token': 'r'});
      final adapter = _ScriptedAdapter([]);
      final client = ApiClient(storage, refreshDio: _scriptedDio(adapter));

      expect(await client.ensureFreshAccessToken(), isTrue);
      expect(adapter.callCount, 0);
      expect(await storage.read(key: 'access_token'), access);
      expect(await storage.read(key: 'refresh_token'), 'r');
    });

    test('access expirant dans 1 min → refresh', () async {
      final storage = _FakeSecureStorage(
        initial: {'access_token': _jwt(const Duration(minutes: 1)), 'refresh_token': 'r'},
      );
      final adapter = _ScriptedAdapter([
        {
          'data': {'access_token': 'new-access', 'refresh_token': 'new-refresh'},
        },
      ]);
      final client = ApiClient(storage, refreshDio: _scriptedDio(adapter));

      expect(await client.ensureFreshAccessToken(), isTrue);
      expect(adapter.callCount, 1);
      expect(await storage.read(key: 'refresh_token'), 'new-refresh');
    });

    test('access déjà expiré → refresh', () async {
      final storage = _FakeSecureStorage(
        initial: {'access_token': _jwt(const Duration(minutes: -5)), 'refresh_token': 'r'},
      );
      final adapter = _ScriptedAdapter([
        {
          'data': {'access_token': 'new-access', 'refresh_token': 'new-refresh'},
        },
      ]);
      final client = ApiClient(storage, refreshDio: _scriptedDio(adapter));

      expect(await client.ensureFreshAccessToken(), isTrue);
      expect(adapter.callCount, 1);
    });

    for (final malformed in ['pas-un-jwt', 'a.b.c', 'a.${base64Url.encode(utf8.encode('{"sub":"u"}'))}.c']) {
      test('access malformé ou sans exp ($malformed) → refresh', () async {
        final storage = _FakeSecureStorage(initial: {'access_token': malformed, 'refresh_token': 'r'});
        final adapter = _ScriptedAdapter([
          {
            'data': {'access_token': 'new-access', 'refresh_token': 'new-refresh'},
          },
        ]);
        final client = ApiClient(storage, refreshDio: _scriptedDio(adapter));

        expect(await client.ensureFreshAccessToken(), isTrue);
        expect(adapter.callCount, 1);
      });
    }

    test('access expirant bientôt, appels concurrents → un seul refresh', () async {
      final storage = _FakeSecureStorage(
        initial: {'access_token': _jwt(const Duration(seconds: 30)), 'refresh_token': 'r'},
      );
      final adapter = _ScriptedAdapter([
        {
          'data': {'access_token': 'new-access', 'refresh_token': 'new-refresh'},
        },
      ]);
      final client = ApiClient(storage, refreshDio: _scriptedDio(adapter));

      final results = await Future.wait([client.ensureFreshAccessToken(), client.ensureFreshAccessToken()]);

      expect(results, [true, true]);
      expect(adapter.callCount, 1);
    });
  });

  group('ApiClient — retry après 401 d\'un envoi multipart', () {
    test('POST FormData : 401 → refresh → rejeu avec le corps complet', () async {
      final storage = _FakeSecureStorage(initial: {
        'access_token': 'expired-access',
        'refresh_token': 'old-refresh',
      });
      final mainAdapter = _ConsumingAdapter();
      final refreshAdapter = _ScriptedAdapter([
        {
          'data': {'access_token': 'new-access', 'refresh_token': 'new-refresh'},
        },
      ]);
      final client = ApiClient(
        storage,
        dio: _scriptedDio(mainAdapter),
        refreshDio: _scriptedDio(refreshAdapter),
      );
      final formData = FormData.fromMap({
        'pdf': MultipartFile.fromBytes(utf8.encode('%PDF-contenu'), filename: 'c.pdf'),
      });

      final response = await client.dio.post<Map<String, dynamic>>('/v1/colleges/24/import', data: formData);

      expect(response.statusCode, 200);
      expect(mainAdapter.authorizations, ['Bearer expired-access', 'Bearer new-access']);
      expect(mainAdapter.bodies, hasLength(2));
      expect(mainAdapter.bodies[1], contains('%PDF-contenu'));
    });
  });
}

/// Adapter qui consomme le corps comme le ferait le vrai client HTTP :
/// 1er appel → 401, appels suivants → 200.
class _ConsumingAdapter implements HttpClientAdapter {
  final List<String> bodies = [];
  final List<String?> authorizations = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    bodies.add(utf8.decode(bytes, allowMalformed: true));
    authorizations.add(options.headers['Authorization'] as String?);
    final status = bodies.length == 1 ? 401 : 200;
    return ResponseBody.fromBytes(
      utf8.encode(jsonEncode({'data': <String, dynamic>{}})),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

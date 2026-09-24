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
}

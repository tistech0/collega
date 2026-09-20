import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:collega_app/core/network/cloudflare_access.dart';
import 'package:collega_app/env.dart';

const _kAccessToken = 'access_token';
const _kRefreshToken = 'refresh_token';
const _kUserId = 'user_id';
const _kUserEmail = 'user_email';
const _kIsBeta = 'is_beta';
const _kIsSubscribed = 'is_subscribed';

class ApiClient {
  ApiClient(this._storage, {this.onForceLogout})
      : _dio = _buildDio(),
        _refreshDio = _buildDio() {
    _setupInterceptors();
  }

  final FlutterSecureStorage _storage;
  final void Function()? onForceLogout;
  final Dio _dio;
  final Dio _refreshDio;
  bool _isRefreshing = false;
  Future<bool>? _refreshFuture;

  Dio get dio => _dio;

  static Dio _buildDio() {
    return Dio(
      BaseOptions(
        baseUrl: backendBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          ...cloudflareAccessHeaders(
            clientId: cfAccessClientId,
            clientSecret: cfAccessClientSecret,
          ),
        },
      ),
    );
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: _kAccessToken);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final refreshed = await _getRefresh();
            if (refreshed) {
              final token = await _storage.read(key: _kAccessToken);
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $token';
              try {
                final response = await _dio.fetch(opts);
                handler.resolve(response);
                return;
              } catch (retryError) {
                handler.next(retryError is DioException ? retryError : error);
                return;
              }
            }
            await _clearAllTokens();
            onForceLogout?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<bool> _getRefresh() {
    if (_isRefreshing) return _refreshFuture!;
    _isRefreshing = true;
    _refreshFuture = _tryRefresh().whenComplete(() => _isRefreshing = false);
    return _refreshFuture!;
  }

  /// Force un refresh défensif de l'access_token, utile AVANT une connexion SSE
  /// (Story 7.2 AC #5 — JWT figé entre background/foreground).
  /// Retourne `true` si le token est valide ou a été rafraîchi avec succès.
  /// Gère les appels concurrents via le verrou interne `_isRefreshing` / `_refreshFuture`.
  Future<bool> ensureFreshAccessToken() => _getRefresh();

  Future<bool> _tryRefresh() async {
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken == null) return false;
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final newToken = (response.data!['data'] as Map)['access_token'] as String;
      await _storage.write(key: _kAccessToken, value: newToken);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearAllTokens() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kUserId),
      _storage.delete(key: _kUserEmail),
      _storage.delete(key: _kIsBeta),
      _storage.delete(key: _kIsSubscribed),
    ]);
  }

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? queryParameters}) =>
      _dio.get<T>(path, queryParameters: queryParameters);

  Future<Response<T>> post<T>(String path, {Object? data, Options? options}) =>
      _dio.post<T>(path, data: data, options: options);

  Future<Response<T>> patch<T>(String path, {Object? data}) =>
      _dio.patch<T>(path, data: data);

  Future<Response<T>> delete<T>(String path) => _dio.delete<T>(path);
}

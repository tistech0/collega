import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';

const _kAccessToken = 'access_token';
const _kRefreshToken = 'refresh_token';
const _kUserId = 'user_id';
const _kUserEmail = 'user_email';
const _kIsBeta = 'is_beta';
const _kIsSubscribed = 'is_subscribed';

class AuthRepository {
  AuthRepository({required Dio dio, required FlutterSecureStorage storage})
      : _dio = dio,
        _storage = storage;

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<AuthState> register(String email, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/register',
        data: {'email': email, 'password': password},
      );
      return _handleTokenResponse(response.data!['data'] as Map<String, dynamic>, email);
    } on DioException catch (e) {
      return AuthState(errorMessage: _extractError(e));
    }
  }

  Future<AuthState> login(String email, String password) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/login',
        data: {'email': email, 'password': password},
      );
      return _handleTokenResponse(response.data!['data'] as Map<String, dynamic>, email);
    } on DioException catch (e) {
      return AuthState(errorMessage: _extractError(e));
    }
  }

  Future<AuthState> loadStoredUser() async {
    try {
      final accessToken = await _storage.read(key: _kAccessToken);
      final userId = await _storage.read(key: _kUserId);
      final email = await _storage.read(key: _kUserEmail);
      final isBetaStr = await _storage.read(key: _kIsBeta);
      final isSubscribedStr = await _storage.read(key: _kIsSubscribed);

      if (accessToken == null || userId == null || email == null) {
        return const AuthState();
      }

      return AuthState(
        user: AuthUser(
          id: userId,
          email: email,
          isBeta: isBetaStr == 'true',
          isSubscribed: isSubscribedStr == 'true',
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to load stored user', tag: 'AuthRepository', error: e);
      return const AuthState();
    }
  }

  Future<void> logout() async {
    await Future.wait([
      _storage.delete(key: _kAccessToken),
      _storage.delete(key: _kRefreshToken),
      _storage.delete(key: _kUserId),
      _storage.delete(key: _kUserEmail),
      _storage.delete(key: _kIsBeta),
      _storage.delete(key: _kIsSubscribed),
    ]);
  }

  Future<AuthState> refreshFromMe() async {
    try {
      final accessToken = await _storage.read(key: _kAccessToken);
      if (accessToken == null) return const AuthState();

      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      final isSubscribed = data['is_subscribed'] as bool;
      final isBeta = data['is_beta'] as bool;

      await Future.wait([
        _storage.write(key: _kIsSubscribed, value: isSubscribed.toString()),
        _storage.write(key: _kIsBeta, value: isBeta.toString()),
      ]);

      final userId = await _storage.read(key: _kUserId) ?? '';
      final email = await _storage.read(key: _kUserEmail) ?? '';

      return AuthState(
        user: AuthUser(id: userId, email: email, isBeta: isBeta, isSubscribed: isSubscribed),
      );
    } on DioException catch (e) {
      AppLogger.error('refreshFromMe failed', tag: 'AuthRepository', error: e);
      return const AuthState(errorMessage: 'Impossible de synchroniser le statut');
    }
  }

  Future<AuthState> refreshSubscriptionStatus() async {
    try {
      final accessToken = await _storage.read(key: _kAccessToken);
      if (accessToken == null) return const AuthState();

      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/refresh-subscription',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      final isSubscribed = data['is_subscribed'] as bool;
      final isBeta = data['is_beta'] as bool;

      final userId = await _storage.read(key: _kUserId) ?? '';
      final email = await _storage.read(key: _kUserEmail) ?? '';

      await Future.wait([
        _storage.write(key: _kIsSubscribed, value: isSubscribed.toString()),
        _storage.write(key: _kIsBeta, value: isBeta.toString()),
      ]);

      return AuthState(
        user: AuthUser(id: userId, email: email, isBeta: isBeta, isSubscribed: isSubscribed),
      );
    } on DioException catch (e) {
      AppLogger.error('refreshSubscriptionStatus failed', tag: 'AuthRepository', error: e);
      return const AuthState(errorMessage: 'Impossible de synchroniser le statut');
    }
  }

  Future<AuthState> _handleTokenResponse(
    Map<String, dynamic> data,
    String email,
  ) async {
    final accessToken = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;
    final isBeta = data['is_beta'] as bool;
    final isSubscribed = data['is_subscribed'] as bool;

    String userId;
    try {
      final meResponse = await _dio.get<Map<String, dynamic>>(
        '/v1/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      userId = meResponse.data!['data']['id'] as String;
    } catch (e) {
      AppLogger.error('Failed to fetch user profile after login', tag: 'AuthRepository', error: e);
      return const AuthState(errorMessage: 'Impossible de récupérer le profil utilisateur');
    }

    try {
      await Future.wait([
        _storage.write(key: _kAccessToken, value: accessToken),
        _storage.write(key: _kRefreshToken, value: refreshToken),
        _storage.write(key: _kUserId, value: userId),
        _storage.write(key: _kUserEmail, value: email),
        _storage.write(key: _kIsBeta, value: isBeta.toString()),
        _storage.write(key: _kIsSubscribed, value: isSubscribed.toString()),
      ]);
    } catch (e) {
      AppLogger.error('Failed to persist tokens', tag: 'AuthRepository', error: e);
      await logout();
      return const AuthState(errorMessage: 'Erreur de stockage des tokens');
    }

    return AuthState(
      user: AuthUser(
        id: userId,
        email: email,
        isBeta: isBeta,
        isSubscribed: isSubscribed,
      ),
    );
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is Map) return detail['message'] as String? ?? 'Erreur inconnue';
      if (detail is String) return detail;
    }
    return switch (e.response?.statusCode) {
      401 => 'Identifiants incorrects',
      409 => 'Cet email est déjà utilisé',
      _ => 'Erreur réseau, veuillez réessayer',
    };
  }
}

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
const _kFirstName = 'first_name';
const _kYearGroup = 'year_group';
const _kFaculty = 'faculty';
const _kMonthlyReloads = 'monthly_reloads';
const _kMonthlyMax = 'monthly_max';

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
      final firstName = await _storage.read(key: _kFirstName);
      final yearGroup = await _storage.read(key: _kYearGroup);
      final faculty = await _storage.read(key: _kFaculty);
      final monthlyReloadsStr = await _storage.read(key: _kMonthlyReloads);
      final monthlyMaxStr = await _storage.read(key: _kMonthlyMax);

      if (accessToken == null || userId == null || email == null) {
        return const AuthState();
      }

      return AuthState(
        user: AuthUser(
          id: userId,
          email: email,
          isBeta: isBetaStr == 'true',
          isSubscribed: isSubscribedStr == 'true',
          firstName: firstName,
          yearGroup: yearGroup,
          faculty: faculty,
          monthlyReloads: int.tryParse(monthlyReloadsStr ?? '0') ?? 0,
          monthlyMax: int.tryParse(monthlyMaxStr ?? '3') ?? 3,
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
      _storage.delete(key: _kFirstName),
      _storage.delete(key: _kYearGroup),
      _storage.delete(key: _kFaculty),
      _storage.delete(key: _kMonthlyReloads),
      _storage.delete(key: _kMonthlyMax),
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
      final firstName = data['first_name'] as String?;
      final yearGroup = data['year_group'] as String?;
      final faculty = data['faculty'] as String?;
      final monthlyReloads = data['monthly_reloads'] as int? ?? 0;
      final monthlyMax = data['monthly_reloads_max'] as int? ?? 3;

      await Future.wait([
        _storage.write(key: _kIsSubscribed, value: isSubscribed.toString()),
        _storage.write(key: _kIsBeta, value: isBeta.toString()),
        _storage.write(key: _kFirstName, value: firstName),
        _storage.write(key: _kYearGroup, value: yearGroup),
        _storage.write(key: _kFaculty, value: faculty),
        _storage.write(key: _kMonthlyReloads, value: monthlyReloads.toString()),
        _storage.write(key: _kMonthlyMax, value: monthlyMax.toString()),
      ]);

      final userId = await _storage.read(key: _kUserId) ?? '';
      final email = await _storage.read(key: _kUserEmail) ?? '';

      return AuthState(
        user: AuthUser(
          id: userId,
          email: email,
          isBeta: isBeta,
          isSubscribed: isSubscribed,
          firstName: firstName,
          yearGroup: yearGroup,
          faculty: faculty,
          monthlyReloads: monthlyReloads,
          monthlyMax: monthlyMax,
        ),
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
      final firstName = await _storage.read(key: _kFirstName);
      final yearGroup = await _storage.read(key: _kYearGroup);
      final faculty = await _storage.read(key: _kFaculty);
      final monthlyReloadsStr = await _storage.read(key: _kMonthlyReloads);
      final monthlyMaxStr = await _storage.read(key: _kMonthlyMax);

      await Future.wait([
        _storage.write(key: _kIsSubscribed, value: isSubscribed.toString()),
        _storage.write(key: _kIsBeta, value: isBeta.toString()),
      ]);

      return AuthState(
        user: AuthUser(
          id: userId,
          email: email,
          isBeta: isBeta,
          isSubscribed: isSubscribed,
          firstName: firstName,
          yearGroup: yearGroup,
          faculty: faculty,
          monthlyReloads: int.tryParse(monthlyReloadsStr ?? '0') ?? 0,
          monthlyMax: int.tryParse(monthlyMaxStr ?? '3') ?? 3,
        ),
      );
    } on DioException catch (e) {
      AppLogger.error('refreshSubscriptionStatus failed', tag: 'AuthRepository', error: e);
      return const AuthState(errorMessage: 'Impossible de synchroniser le statut');
    }
  }

  Future<AuthState> updateProfile({
    String? firstName,
    String? yearGroup,
    String? faculty,
  }) async {
    if (firstName == null && yearGroup == null && faculty == null) {
      return loadStoredUser();
    }
    try {
      final accessToken = await _storage.read(key: _kAccessToken);
      if (accessToken == null) return const AuthState();
      await _dio.patch<Map<String, dynamic>>(
        '/v1/auth/profile',
        data: {
          if (firstName != null) 'first_name': firstName,
          if (yearGroup != null) 'year_group': yearGroup,
          if (faculty != null) 'faculty': faculty,
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      if (firstName != null) {
        await _storage.write(key: _kFirstName, value: firstName.isEmpty ? null : firstName);
      }
      if (yearGroup != null) {
        await _storage.write(key: _kYearGroup, value: yearGroup.isEmpty ? null : yearGroup);
      }
      if (faculty != null) {
        await _storage.write(key: _kFaculty, value: faculty.isEmpty ? null : faculty);
      }
      return loadStoredUser();
    } on DioException catch (e) {
      return AuthState(errorMessage: _extractError(e));
    }
  }

  /// Supprime le compte côté backend. **Ne touche PAS** au storage / DB locaux ;
  /// l'orchestration locale est faite par [AuthNotifier.deleteAccount].
  ///
  /// Retours :
  /// - `AuthState()` (vide, sans errorMessage) → succès serveur (200) → wipe local autorisé
  /// - `AuthState(errorMessage: ...)` → échec → l'appelant DOIT bloquer le wipe local
  Future<AuthState> deleteAccount() async {
    try {
      final accessToken = await _storage.read(key: _kAccessToken);
      if (accessToken == null) {
        return const AuthState(
          errorMessage: 'Session expirée — reconnecte-toi avant de supprimer ton compte',
        );
      }
      // Pas de type-arg `<Map<String, dynamic>>` : la réponse n'est pas lue,
      // et un body 2xx non-JSON (proxy/CDN renvoyant HTML, body vide) ne doit
      // pas faire échouer le cast Response.data → on évite un état zombie
      // (compte supprimé serveur mais wipe local bloqué). Voir review
      // findings 7.3. Sur les statuts d'erreur, la responseType par défaut
      // (JSON) est préservée pour que `_extractError` lise `detail.message`.
      await _dio.delete<dynamic>(
        '/v1/auth/account',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      return const AuthState();
    } on DioException catch (e) {
      AppLogger.warning('deleteAccount DioException: ${e.type}', tag: 'AuthRepository');
      return AuthState(errorMessage: _extractError(e));
    } catch (e) {
      AppLogger.error('deleteAccount unexpected error', tag: 'AuthRepository', error: e);
      return const AuthState(errorMessage: 'Erreur lors de la suppression du compte');
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
    String? firstName;
    String? yearGroup;
    String? faculty;
    int monthlyReloads = 0;
    int monthlyMax = 3;

    try {
      final meResponse = await _dio.get<Map<String, dynamic>>(
        '/v1/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final meData = meResponse.data!['data'] as Map<String, dynamic>;
      userId = meData['id'] as String;
      firstName = meData['first_name'] as String?;
      yearGroup = meData['year_group'] as String?;
      faculty = meData['faculty'] as String?;
      monthlyReloads = meData['monthly_reloads'] as int? ?? 0;
      monthlyMax = meData['monthly_reloads_max'] as int? ?? 3;
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
        _storage.write(key: _kFirstName, value: firstName),
        _storage.write(key: _kYearGroup, value: yearGroup),
        _storage.write(key: _kFaculty, value: faculty),
        _storage.write(key: _kMonthlyReloads, value: monthlyReloads.toString()),
        _storage.write(key: _kMonthlyMax, value: monthlyMax.toString()),
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
        firstName: firstName,
        yearGroup: yearGroup,
        faculty: faculty,
        monthlyReloads: monthlyReloads,
        monthlyMax: monthlyMax,
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

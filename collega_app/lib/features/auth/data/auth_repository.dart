import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:collega_app/core/network/network_errors.dart';
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
const _kMonthlyResetAt = 'monthly_reset_at';
const _kReminderHourUtc = 'reminder_hour_utc';
const _kReminderLocalHour = 'reminder_local_hour';

class AuthRepository {
  /// [logoutDio] : Dio utilisé pour `POST /v1/auth/logout` — SANS l'intercepteur
  /// 401→refresh→retry de [dio] (passer `ApiClient.rawDio`). Par défaut, [dio]
  /// (comportement historique dans les tests qui ne fournissent pas ce param).
  /// [ensureFreshAccessToken] : rafraîchissement défensif best-effort avant le
  /// logout (passer `ApiClient.ensureFreshAccessToken`) — voir [logout].
  AuthRepository({
    required Dio dio,
    required FlutterSecureStorage storage,
    Dio? logoutDio,
    Future<bool> Function()? ensureFreshAccessToken,
  })  : _dio = dio,
        _storage = storage,
        _logoutDio = logoutDio ?? dio,
        _ensureFreshAccessToken = ensureFreshAccessToken;

  final Dio _dio;
  final FlutterSecureStorage _storage;
  final Dio _logoutDio;
  final Future<bool> Function()? _ensureFreshAccessToken;

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
      return AuthState(errorMessage: _extractError(e), loginError: _loginError(e));
    }
  }

  static LoginError _loginError(DioException e) {
    if (isNetworkUnreachable(e)) return LoginError.network;
    return switch (e.response?.statusCode) {
      401 => LoginError.invalidCredentials,
      422 => LoginError.invalidEmail,
      429 => LoginError.tooManyAttempts,
      _ => LoginError.other,
    };
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
      final monthlyResetAtStr = await _storage.read(key: _kMonthlyResetAt);
      final reminderStr = await _storage.read(key: _kReminderHourUtc);
      final reminderLocalStr = await _storage.read(key: _kReminderLocalHour);

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
          monthlyResetAt: monthlyResetAtStr == null ? null : DateTime.tryParse(monthlyResetAtStr),
          reminderHourUtc: reminderStr == null ? null : int.tryParse(reminderStr),
          reminderLocalHour: reminderLocalStr == null ? null : int.tryParse(reminderLocalStr),
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to load stored user', tag: 'AuthRepository', error: e);
      return const AuthState();
    }
  }

  /// Déconnexion best-effort : l'appel serveur révoque la session côté back
  /// (rotation du refresh token — chantier 2 § 8) mais n'empêche JAMAIS la
  /// déconnexion locale. Le storage est effacé en dernière étape, y compris
  /// si l'appel échoue, timeout, ou lève (401 access token déjà expiré...).
  ///
  /// Fix round 1 : POSTer sur [_dio] (intercepté 401→refresh→retry) est
  /// dangereux ici — un 401 en cours d'appel ferait tourner le refresh token
  /// EN INTERNE puis rejouerait la requête avec le corps déjà sérialisé
  /// AVANT rotation (`{refresh_token: R1}`), alors que le refresh token
  /// courant est désormais R2 : R2 ne serait jamais révoqué côté serveur.
  /// On force donc une rotation défensive AVANT de lire les jetons (verrou
  /// partagé d'`ApiClient`, best-effort), puis on poste sur [_logoutDio] qui
  /// n'a PAS cet intercepteur : le jeton lu est bien celui envoyé, sans retry
  /// différé.
  Future<void> logout() async {
    try {
      await _ensureFreshAccessToken?.call();
    } catch (_) {
      // Best-effort : le logout suit avec les jetons actuellement stockés.
    }

    try {
      final accessToken = await _storage.read(key: _kAccessToken);
      if (accessToken != null) {
        final refreshToken = await _storage.read(key: _kRefreshToken);
        await _logoutDio.post<dynamic>(
          '/v1/auth/logout',
          data: refreshToken != null ? {'refresh_token': refreshToken} : null,
          options: Options(
            headers: {'Authorization': 'Bearer $accessToken'},
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      AppLogger.warning('logout: appel serveur ignoré (${e.runtimeType})', tag: 'AuthRepository');
    } finally {
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
        _storage.delete(key: _kMonthlyResetAt),
        _storage.delete(key: _kReminderHourUtc),
        _storage.delete(key: _kReminderLocalHour),
      ]);
    }
  }

  /// Rappel quotidien mémorisé (l'interrupteur du Profil au prochain démarrage),
  /// avec l'heure locale choisie (recalage au changement d'heure).
  Future<void> saveReminderHour(int? hourUtc, {int? localHour}) => Future.wait([
        _storage.write(key: _kReminderHourUtc, value: hourUtc?.toString()),
        _storage.write(key: _kReminderLocalHour, value: hourUtc == null ? null : localHour?.toString()),
      ]);

  Future<AuthState> refreshFromMe() async {
    try {
      final accessToken = await _storage.read(key: _kAccessToken);
      if (accessToken == null) return const AuthState();

      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
      final data = response.data!['data'] as Map<String, dynamic>;
      // Réponse tardive : déconnectée ou autre compte entre-temps → rien n'est écrit.
      final storedId = await _storage.read(key: _kUserId);
      if (storedId == null || storedId != data['id']) {
        return const AuthState(errorMessage: 'Compte changé pendant la synchronisation');
      }
      final isSubscribed = data['is_subscribed'] as bool;
      final isBeta = data['is_beta'] as bool;
      final firstName = data['first_name'] as String?;
      final yearGroup = data['year_group'] as String?;
      final faculty = data['faculty'] as String?;
      final monthlyReloads = data['monthly_reloads'] as int? ?? 0;
      final monthlyMax = data['monthly_reloads_max'] as int? ?? 3;
      final resetAtStr = data['monthly_reloads_reset_at'] as String?;
      final monthlyResetAt = resetAtStr == null ? null : DateTime.tryParse(resetAtStr);
      final reminderHourUtc = data['reminder_hour_utc'] as int?;
      // Heure locale choisie : gardée tant que le serveur a la même heure UTC.
      final storedUtc = int.tryParse(await _storage.read(key: _kReminderHourUtc) ?? '');
      final storedLocal = int.tryParse(await _storage.read(key: _kReminderLocalHour) ?? '');
      final reminderLocalHour = reminderHourUtc != null && reminderHourUtc == storedUtc ? storedLocal : null;

      await Future.wait([
        _storage.write(key: _kIsSubscribed, value: isSubscribed.toString()),
        _storage.write(key: _kIsBeta, value: isBeta.toString()),
        _storage.write(key: _kFirstName, value: firstName),
        _storage.write(key: _kYearGroup, value: yearGroup),
        _storage.write(key: _kFaculty, value: faculty),
        _storage.write(key: _kMonthlyReloads, value: monthlyReloads.toString()),
        _storage.write(key: _kMonthlyMax, value: monthlyMax.toString()),
        _storage.write(key: _kMonthlyResetAt, value: monthlyResetAt?.toIso8601String()),
        _storage.write(key: _kReminderHourUtc, value: reminderHourUtc?.toString()),
        _storage.write(key: _kReminderLocalHour, value: reminderLocalHour?.toString()),
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
          monthlyResetAt: monthlyResetAt,
          reminderHourUtc: reminderHourUtc,
          reminderLocalHour: reminderLocalHour,
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

      await Future.wait([
        _storage.write(key: _kIsSubscribed, value: isSubscribed.toString()),
        _storage.write(key: _kIsBeta, value: isBeta.toString()),
      ]);
      // Le reste du compte (profil, quota, rappel) tel que mémorisé.
      return loadStoredUser();
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
    DateTime? monthlyResetAt;
    int? reminderHourUtc;

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
      final resetAtStr = meData['monthly_reloads_reset_at'] as String?;
      monthlyResetAt = resetAtStr == null ? null : DateTime.tryParse(resetAtStr);
      reminderHourUtc = meData['reminder_hour_utc'] as int?;
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
        // Toujours réécrits : jamais le rappel d'un compte précédent sur cet appareil.
        _storage.write(key: _kMonthlyResetAt, value: monthlyResetAt?.toIso8601String()),
        _storage.write(key: _kReminderHourUtc, value: reminderHourUtc?.toString()),
        _storage.write(key: _kReminderLocalHour, value: null),
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
        monthlyResetAt: monthlyResetAt,
        reminderHourUtc: reminderHourUtc,
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

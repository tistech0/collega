import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.isBeta,
    required this.isSubscribed,
    this.firstName,
    this.yearGroup,
    this.faculty,
    this.monthlyReloads = 0,
    this.monthlyMax = 3,
    this.monthlyResetAt,
    this.reminderHourUtc,
  });

  final String id;
  final String email;
  final bool isBeta;
  final bool isSubscribed;
  final String? firstName;
  final String? yearGroup;
  final String? faculty;
  final int monthlyReloads;
  final int monthlyMax;

  /// Renouvellement du quota de réimports (UTC) ; inconnu avant le premier `/me`.
  final DateTime? monthlyResetAt;

  /// Rappel quotidien (heure UTC côté serveur) ; `null` = rappel éteint.
  final int? reminderHourUtc;

  AuthUser copyWith({
    String? id,
    String? email,
    bool? isBeta,
    bool? isSubscribed,
    Object? firstName = _absent,
    Object? yearGroup = _absent,
    Object? faculty = _absent,
    int? monthlyReloads,
    int? monthlyMax,
    Object? monthlyResetAt = _absent,
    Object? reminderHourUtc = _absent,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      isBeta: isBeta ?? this.isBeta,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      firstName: identical(firstName, _absent) ? this.firstName : firstName as String?,
      yearGroup: identical(yearGroup, _absent) ? this.yearGroup : yearGroup as String?,
      faculty: identical(faculty, _absent) ? this.faculty : faculty as String?,
      monthlyReloads: monthlyReloads ?? this.monthlyReloads,
      monthlyMax: monthlyMax ?? this.monthlyMax,
      monthlyResetAt: identical(monthlyResetAt, _absent) ? this.monthlyResetAt : monthlyResetAt as DateTime?,
      reminderHourUtc: identical(reminderHourUtc, _absent) ? this.reminderHourUtc : reminderHourUtc as int?,
    );
  }

  static const _absent = Object();
}

/// Pourquoi une connexion a échoué (story 8.12) : l'écran dit la bonne chose
/// au bon endroit (sous le champ, ou « pas de connexion »).
enum LoginError { invalidCredentials, invalidEmail, tooManyAttempts, network, other }

@immutable
class AuthState {
  const AuthState({
    this.user,
    this.errorMessage,
    this.loginError,
  });

  final AuthUser? user;
  final String? errorMessage;

  /// Renseigné seulement par une connexion échouée.
  final LoginError? loginError;

  bool get isAuthenticated => user != null;

  bool get hasAccess => user != null && (user!.isSubscribed || user!.isBeta);

  AuthState copyWith({
    AuthUser? user,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );
}

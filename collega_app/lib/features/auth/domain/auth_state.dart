import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.isBeta,
    required this.isSubscribed,
  });

  final String id;
  final String email;
  final bool isBeta;
  final bool isSubscribed;
}

@immutable
class AuthState {
  const AuthState({
    this.user,
    this.errorMessage,
  });

  final AuthUser? user;
  final String? errorMessage;

  bool get isAuthenticated => user != null;

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

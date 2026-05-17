import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/auth/data/auth_repository.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    dio: ref.read(apiClientProvider).dio,
    storage: ref.read(secureStorageProvider),
  ),
);

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    ref.listen(forceLogoutSignalProvider, (_, __) {
      state = const AsyncData(AuthState());
    });
    return ref.read(authRepositoryProvider).loadStoredUser();
  }

  Future<void> register(String email, String password) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).register(email, password);
    state = AsyncData(result);
    if (result.errorMessage != null) {
      AppLogger.warning('Register error: ${result.errorMessage}', tag: 'AuthNotifier');
    }
    if (result.user != null) {
      _rcLogIn(result.user!.id);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).login(email, password);
    state = AsyncData(result);
    if (result.errorMessage != null) {
      AppLogger.warning('Login error: ${result.errorMessage}', tag: 'AuthNotifier');
    }
    if (result.user != null) {
      _rcLogIn(result.user!.id);
    }
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    await ref.read(authRepositoryProvider).logout();
    _rcLogOut();
    state = const AsyncData(AuthState());
  }

  Future<String?> updateProfile({
    String? firstName,
    String? yearGroup,
    String? faculty,
  }) async {
    final result = await ref.read(authRepositoryProvider).updateProfile(
      firstName: firstName,
      yearGroup: yearGroup,
      faculty: faculty,
    );
    if (result.user != null) {
      state = AsyncData(result);
      return null;
    } else if (result.errorMessage != null) {
      AppLogger.warning('updateProfile error: ${result.errorMessage}', tag: 'AuthNotifier');
      return result.errorMessage;
    }
    return null;
  }

  Future<void> refreshSubscription() async {
    final current = state.valueOrNull;
    if (current?.user == null) return;
    try {
      final response = await ref.read(authRepositoryProvider).refreshSubscriptionStatus();
      if (response.user != null) {
        state = AsyncData(response);
      }
    } catch (e) {
      AppLogger.error('Failed to refresh subscription', tag: 'AuthNotifier', error: e);
    }
  }

  // Fire-and-forget — non-bloquant par design (achat possible même si logIn échoue)
  void _rcLogIn(String userId) {
    () async {
      try {
        await Purchases.logIn(userId);
      } catch (e) {
        AppLogger.warning('RevenueCat logIn failed', tag: 'AuthNotifier', error: e);
      }
    }();
  }

  void _rcLogOut() {
    () async {
      try {
        await Purchases.logOut();
      } catch (e) {
        AppLogger.warning('RevenueCat logOut failed', tag: 'AuthNotifier', error: e);
      }
    }();
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

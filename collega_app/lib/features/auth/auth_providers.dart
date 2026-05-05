import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).login(email, password);
    state = AsyncData(result);
    if (result.errorMessage != null) {
      AppLogger.warning('Login error: ${result.errorMessage}', tag: 'AuthNotifier');
    }
  }

  Future<void> logout() async {
    state = const AsyncLoading();
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(AuthState());
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

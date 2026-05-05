import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/data/auth_repository.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({
    AuthState? loadResult,
    AuthState? registerResult,
    AuthState? loginResult,
  })  : _loadResult = loadResult ?? const AuthState(),
        _registerResult = registerResult ?? const AuthState(),
        _loginResult = loginResult ?? const AuthState(),
        super(dio: Dio(), storage: const FlutterSecureStorage());

  final AuthState _loadResult;
  final AuthState _registerResult;
  final AuthState _loginResult;

  @override
  Future<AuthState> loadStoredUser() async => _loadResult;

  @override
  Future<AuthState> register(String email, String password) async => _registerResult;

  @override
  Future<AuthState> login(String email, String password) async => _loginResult;

  @override
  Future<void> logout() async {}
}

ProviderContainer _makeContainer(_FakeAuthRepository repo) {
  return ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
}

const _testUser = AuthUser(
  id: 'uid-1',
  email: 'test@example.com',
  isBeta: false,
  isSubscribed: false,
);

void main() {
  group('AuthNotifier', () {
    test('état initial : non authentifié', () async {
      final container = _makeContainer(_FakeAuthRepository());
      addTearDown(container.dispose);

      final state = await container.read(authProvider.future);
      expect(state.isAuthenticated, isFalse);
      expect(state.errorMessage, isNull);
    });

    test('register succès → utilisateur authentifié', () async {
      final container = _makeContainer(
        _FakeAuthRepository(registerResult: const AuthState(user: _testUser)),
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      await container.read(authProvider.notifier).register('test@example.com', 'password123');

      final state = container.read(authProvider).valueOrNull!;
      expect(state.isAuthenticated, isTrue);
      expect(state.user!.email, 'test@example.com');
    });

    test('login succès → utilisateur authentifié avec flag beta', () async {
      const betaUser = AuthUser(
        id: 'uid-2',
        email: 'beta@example.com',
        isBeta: true,
        isSubscribed: false,
      );
      final container = _makeContainer(
        _FakeAuthRepository(loginResult: const AuthState(user: betaUser)),
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      await container.read(authProvider.notifier).login('beta@example.com', 'password123');

      final state = container.read(authProvider).valueOrNull!;
      expect(state.isAuthenticated, isTrue);
      expect(state.user!.isBeta, isTrue);
    });

    test('logout → état non authentifié', () async {
      final container = _makeContainer(
        _FakeAuthRepository(loadResult: const AuthState(user: _testUser)),
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      await container.read(authProvider.notifier).logout();

      final state = container.read(authProvider).valueOrNull!;
      expect(state.isAuthenticated, isFalse);
    });

    test('register erreur → errorMessage non null', () async {
      final container = _makeContainer(
        _FakeAuthRepository(
          registerResult: const AuthState(errorMessage: 'Cet email est déjà utilisé'),
        ),
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      await container.read(authProvider.notifier).register('dup@example.com', 'pass1234');

      final state = container.read(authProvider).valueOrNull!;
      expect(state.isAuthenticated, isFalse);
      expect(state.errorMessage, 'Cet email est déjà utilisé');
    });
  });
}

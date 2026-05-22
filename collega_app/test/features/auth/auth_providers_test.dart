import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/data/auth_repository.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({
    AuthState? loadResult,
    AuthState? registerResult,
    AuthState? loginResult,
    this.onDeleteAccount,
    this.onLogout,
  })  : _loadResult = loadResult ?? const AuthState(),
        _registerResult = registerResult ?? const AuthState(),
        _loginResult = loginResult ?? const AuthState(),
        super(dio: Dio(), storage: const FlutterSecureStorage());

  final AuthState _loadResult;
  final AuthState _registerResult;
  final AuthState _loginResult;
  final Future<AuthState> Function()? onDeleteAccount;
  final Future<void> Function()? onLogout;

  @override
  Future<AuthState> loadStoredUser() async => _loadResult;

  @override
  Future<AuthState> register(String email, String password) async => _registerResult;

  @override
  Future<AuthState> login(String email, String password) async => _loginResult;

  @override
  Future<void> logout() async {
    if (onLogout != null) {
      await onLogout!();
    }
  }

  @override
  Future<AuthState> deleteAccount() async {
    if (onDeleteAccount != null) {
      return onDeleteAccount!();
    }
    return const AuthState();
  }
}

/// Spy `AppDatabase` qui trace les appels à `deleteEverything()` pour vérifier
/// l'ordre d'orchestration de [AuthNotifier.deleteAccount] (Story 7.3 T9).
class _SpyAppDatabase extends AppDatabase {
  _SpyAppDatabase(this._onDelete) : super.forTesting(NativeDatabase.memory());

  final Future<void> Function() _onDelete;

  @override
  Future<void> deleteEverything() async {
    await _onDelete();
  }
}

ProviderContainer _makeContainer(
  _FakeAuthRepository repo, {
  AppDatabase? database,
}) {
  return ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      if (database != null) databaseProvider.overrideWithValue(database),
      secureStorageProvider.overrideWithValue(const FlutterSecureStorage()),
    ],
  );
}

const _testUser = AuthUser(
  id: 'uid-1',
  email: 'test@example.com',
  isBeta: false,
  isSubscribed: false,
);

/// Séquence partagée par le mock channel RevenueCat et les fakes locaux —
/// permet d'asserter l'ordre exact `Purchases.logOut → db.deleteEverything →
/// repo.logout` au sein d'un test. Cf. review findings 7.3 : sans cette trace,
/// supprimer `await Purchases.logOut()` du notifier ne casserait aucun test.
List<String>? _activeSequence;

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Mock channel RC : capture le nom de la méthode appelée dans la séquence
    // active (si le test en a déclaré une) et renvoie `null` pour éviter
    // `MissingPluginException` à l'appel statique `Purchases.logOut()`.
    // Nom du canal : `purchases_flutter` (pas `com.revenuecat.…`) — voir
    // purchases_flutter:lib/purchases_flutter.dart:55.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('purchases_flutter'),
      (call) async {
        _activeSequence?.add('Purchases.${call.method}');
        return null;
      },
    );
    // Ancien stub erroné laissé pour compat — couverture de l'éventualité où
    // le plugin enregistre aussi un canal namespaced (sans-op).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.revenuecat.purchases_flutter'),
      (call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  tearDown(() {
    _activeSequence = null;
  });

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

  group('AuthNotifier.deleteAccount (Story 7.3 — séquence ordonnée)', () {
    test('serveur OK → séquence Purchases.logOut → Drift → storage → state reset', () async {
      final callOrder = <String>[];
      _activeSequence = callOrder;
      final repo = _FakeAuthRepository(
        loadResult: const AuthState(user: _testUser),
        onDeleteAccount: () async {
          callOrder.add('repo.deleteAccount');
          return const AuthState();
        },
        onLogout: () async => callOrder.add('repo.logout'),
      );
      final db = _SpyAppDatabase(() async => callOrder.add('db.deleteEverything'));
      addTearDown(db.close);
      final container = _makeContainer(repo, database: db);
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      final error = await container.read(authProvider.notifier).deleteAccount();

      expect(error, isNull);
      // Le mock channel RC capte `Purchases.logOut` dans la séquence partagée
      // — supprimer `await Purchases.logOut()` du notifier casse maintenant
      // ce test (avant : régression silencieuse possible).
      expect(callOrder, [
        'repo.deleteAccount',
        'Purchases.logOut',
        'db.deleteEverything',
        'repo.logout',
      ]);
      final state = container.read(authProvider).valueOrNull;
      expect(state, equals(const AuthState()));
    });

    test('serveur KO → aucun wipe, errorMessage propagé, session intacte', () async {
      final callOrder = <String>[];
      final repo = _FakeAuthRepository(
        loadResult: const AuthState(user: _testUser),
        onDeleteAccount: () async {
          callOrder.add('repo.deleteAccount');
          return const AuthState(errorMessage: 'Erreur réseau');
        },
        onLogout: () async => callOrder.add('repo.logout'),
      );
      final db = _SpyAppDatabase(() async => callOrder.add('db.deleteEverything'));
      addTearDown(db.close);
      final container = _makeContainer(repo, database: db);
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      final error = await container.read(authProvider.notifier).deleteAccount();

      expect(error, 'Erreur réseau');
      // Aucun wipe local : pas de db.deleteEverything ni repo.logout
      expect(callOrder, ['repo.deleteAccount']);
      // L'état utilisateur DOIT être préservé — la session n'a pas été reset
      final state = container.read(authProvider).valueOrNull;
      expect(state?.user, isNotNull);
      expect(state?.user?.id, 'uid-1');
    });

    test('Drift échoue mais serveur OK → state quand même reset (best-effort)',
        () async {
      final callOrder = <String>[];
      final repo = _FakeAuthRepository(
        loadResult: const AuthState(user: _testUser),
        onDeleteAccount: () async {
          callOrder.add('repo.deleteAccount');
          return const AuthState();
        },
        onLogout: () async => callOrder.add('repo.logout'),
      );
      final db = _SpyAppDatabase(() async {
        callOrder.add('db.deleteEverything-throw');
        throw StateError('Drift down');
      });
      addTearDown(db.close);
      final container = _makeContainer(repo, database: db);
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      final error = await container.read(authProvider.notifier).deleteAccount();

      // L'erreur Drift ne doit PAS remonter à l'UI
      expect(error, isNull);
      // Mais repo.logout doit quand même tenter
      expect(callOrder, [
        'repo.deleteAccount',
        'db.deleteEverything-throw',
        'repo.logout',
      ]);
      // Et le state DOIT être reset pour éviter une boucle 401
      final state = container.read(authProvider).valueOrNull;
      expect(state, equals(const AuthState()));
    });
  });
}

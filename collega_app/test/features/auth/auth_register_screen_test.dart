import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/data/auth_repository.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';
import 'package:collega_app/features/auth/presentation/auth_register_screen.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(this._result)
      : super(dio: Dio(), storage: const FlutterSecureStorage());

  final AuthState _result;

  @override
  Future<AuthState> loadStoredUser() async => const AuthState();

  @override
  Future<AuthState> register(String email, String password) async => _result;

  @override
  Future<AuthState> login(String email, String password) async => const AuthState();

  @override
  Future<void> logout() async {}
}

Widget _buildScreen(_FakeAuthRepository repo) {
  final router = GoRouter(
    initialLocation: '/register',
    routes: [
      GoRoute(
        path: '/register',
        builder: (_, __) => const AuthRegisterScreen(),
      ),
      GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('Accueil'))),
      GoRoute(path: '/auth/login', builder: (_, __) => const Scaffold(body: Text('Connexion'))),
      GoRoute(path: '/demo', builder: (_, __) => const Scaffold(body: Text('Démo'))),
    ],
  );

  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: ShadApp.router(
      theme: buildShadTheme(),
      routerConfig: router,
    ),
  );
}

void main() {
  group('AuthRegisterScreen', () {
    testWidgets('affiche les champs email et mot de passe', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeAuthRepository(const AuthState())));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Mot de passe'), findsOneWidget);
      expect(find.text("S'inscrire"), findsOneWidget);
    });

    testWidgets('affiche le lien vers connexion', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeAuthRepository(const AuthState())));
      await tester.pumpAndSettle();

      expect(find.textContaining('Connexion'), findsOneWidget);
    });

    testWidgets('validation : erreur si champs vides', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeAuthRepository(const AuthState())));
      await tester.pumpAndSettle();

      await tester.tap(find.text("S'inscrire"));
      await tester.pumpAndSettle();

      expect(find.text("L'email est requis"), findsOneWidget);
    });

    testWidgets('validation : erreur si mot de passe trop court', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeAuthRepository(const AuthState())));
      await tester.pumpAndSettle();

      // Entrer un email valide dans le premier champ EditableText
      final editableTexts = find.byType(EditableText);
      await tester.enterText(editableTexts.first, 'test@example.com');
      await tester.pumpAndSettle();

      await tester.tap(find.text("S'inscrire"));
      await tester.pumpAndSettle();

      expect(find.textContaining('8 caractères'), findsWidgets);
    });

    testWidgets('navigue vers /home après inscription réussie', (tester) async {
      const user = AuthUser(
        id: 'uid-1',
        email: 'test@example.com',
        isBeta: false,
        isSubscribed: false,
      );
      await tester.pumpWidget(
        _buildScreen(_FakeAuthRepository(const AuthState(user: user))),
      );
      await tester.pumpAndSettle();

      final editableTexts = find.byType(EditableText);
      await tester.enterText(editableTexts.at(0), 'test@example.com');
      await tester.pumpAndSettle();
      await tester.enterText(editableTexts.at(1), 'password123');
      await tester.pumpAndSettle();

      await tester.tap(find.text("S'inscrire"));
      await tester.pumpAndSettle();

      expect(find.text('Accueil'), findsOneWidget);
    });
  });
}

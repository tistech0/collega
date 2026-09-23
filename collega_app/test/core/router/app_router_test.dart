import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/router/app_router.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/data/colleges_repository.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/auth/presentation/auth_login_screen.dart';
import 'package:collega_app/features/auth/presentation/welcome_screen.dart';
import 'package:collega_app/features/demo/presentation/demo_screen.dart';
import 'package:collega_app/core/ui/components/cg_tab_bar.dart';
import 'package:collega_app/features/today/presentation/today_screen.dart';
import 'package:collega_app/features/planning/presentation/planning_screen.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransition;
import 'package:collega_app/features/colleges/presentation/colleges_screen.dart';
import 'package:collega_app/features/today/today_providers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._authState);
  final AuthState _authState;

  @override
  Future<AuthState> build() async => _authState;
}

/// Connexion réaliste : passe par AsyncLoading (comme le vrai notifier), puis échoue.
class _FailingLoginAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState();

  @override
  Future<void> login(String email, String password) async {
    state = const AsyncLoading<AuthState>().copyWithPrevious(state);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    state = const AsyncData(AuthState(loginError: LoginError.invalidCredentials, errorMessage: 'x'));
  }
}

class _FakeTodayNotifier extends TodayNotifier {
  @override
  Future<TodayState> build() async => const TodayNoCollege();
}

class _FakeCollegesRepository extends CollegesRepository {
  _FakeCollegesRepository() : super(dio: Dio());

  @override
  Future<List<UserCollegeStatus>> getUserColleges() async => const [];
}

final _authedUser = AuthUser(
  id: 'u1',
  email: 'auth@example.com',
  isBeta: false,
  isSubscribed: true,
);

Widget _buildApp(AuthState authState, AppDatabase db, {AuthNotifier Function()? auth}) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(auth ?? () => _FakeAuthNotifier(authState)),
      todayProvider.overrideWith(_FakeTodayNotifier.new),
      collegesRepositoryProvider
          .overrideWithValue(_FakeCollegesRepository()),
      databaseProvider.overrideWithValue(db),
    ],
    child: Consumer(builder: (ctx, ref, _) {
      return MaterialApp.router(
        theme: buildCgMaterialTheme(CgThemeData.light),
        routerConfig: ref.watch(routerProvider),
      );
    }),
  );
}

void main() {
  testWidgets('8.15 : changer d’onglet est immédiat (pas de glissement d’écran poussé)', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(_buildApp(AuthState(user: _authedUser), db));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(TodayScreen), findsOneWidget);
    final router = ProviderScope.containerOf(tester.element(find.byType(TodayScreen))).read(routerProvider);

    router.go('/colleges');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(TodayScreen), findsNothing);
    expect(find.byType(CollegesScreen), findsOneWidget);
    final x = tester.getTopLeft(find.byType(CollegesScreen)).dx;
    await tester.pump(const Duration(seconds: 1));
    expect(tester.getTopLeft(find.byType(CollegesScreen)).dx, x, reason: "déjà à sa place");
  });

  testWidgets('8.15 : un écran poussé dans un onglet garde la transition iOS (retour par balayage)', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(_buildApp(AuthState(user: _authedUser), db));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final router = ProviderScope.containerOf(tester.element(find.byType(TodayScreen))).read(routerProvider);
    router.go('/progress');
    await tester.pump();
    router.push('/progress/planning');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      find.ancestor(of: find.byType(PlanningScreen), matching: find.byType(CupertinoPageTransition)),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 1));
  });

  group('AppRouter — Story 7.1 R3 (redirect /demo si authentifié)', () {
    testWidgets('AC3: user authentifié sur /demo → Aujourd’hui rendu',
        (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(_buildApp(AuthState(user: _authedUser), db));
      // Plusieurs frames pour : 1) résoudre authProvider (AsyncLoading→Data),
      // 2) recréer le router, 3) appliquer le redirect, 4) build /home.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // AC3 : Aujourd'hui rendu (provider mocké).
      expect(find.byType(TodayScreen), findsOneWidget);
      // AC4 : DemoScreen ne doit jamais avoir été monté (pas de flash).
      expect(find.byType(DemoScreen), findsNothing);
    });

    testWidgets('8.12 : non connecté à l’ouverture → écran de marque', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(_buildApp(const AuthState(), db));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(TodayScreen), findsNothing);
    });

    testWidgets('8.12 : non connecté sur /demo → démo ; /auth/register n’existe plus', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(_buildApp(const AuthState(), db));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final router = ProviderScope.containerOf(tester.element(find.byType(WelcomeScreen))).read(routerProvider);
      router.go('/demo');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DemoScreen), findsOneWidget);
      router.go('/auth/register');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // fin de la transition de page
      expect(find.byType(WelcomeScreen), findsOneWidget, reason: 'ancien lien : retour à l’entrée');
    });
  });

  group('Story 8.3 — shell 4 onglets', () {
    Future<void> signedIn(WidgetTester tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildApp(AuthState(user: _authedUser), db));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('tab bar : Aujourd’hui · Bibliothèque · Progression · Profil (pas de Recherche)', (tester) async {
      await signedIn(tester);
      expect(find.byType(CgTabBar), findsOneWidget);
      for (final label in ['Aujourd’hui', 'Bibliothèque', 'Progression', 'Profil']) {
        expect(find.descendant(of: find.byType(CgTabBar), matching: find.text(label)), findsOneWidget, reason: label);
      }
      expect(find.descendant(of: find.byType(CgTabBar), matching: find.text('Recherche')), findsNothing);
    });

    testWidgets('/progress protégé : non connecté → écran de marque', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(_buildApp(const AuthState(), db));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final container = ProviderScope.containerOf(tester.element(find.byType(WelcomeScreen)));
      container.read(routerProvider).go('/progress');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Progression'), findsNothing);
    });
  });

  group('revue 8.12 — le routeur ne repart pas de zéro à chaque changement de connexion', () {
    testWidgets('connexion ratée : on reste sur la connexion et l’erreur s’affiche', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_buildApp(const AuthState(), db, auth: _FailingLoginAuth.new));
      await tester.pumpAndSettle();
      final router = ProviderScope.containerOf(tester.element(find.byType(WelcomeScreen))).read(routerProvider);
      router.push('/auth/login');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).at(0), 'lea@fac.fr');
      await tester.enterText(find.byType(EditableText).at(1), 'secret');
      await tester.tap(find.text('Se connecter').last);
      await tester.pump();
      expect(find.byType(AuthLoginScreen), findsOneWidget, reason: 'pas de retour à l’écran de marque pendant la requête');
      await tester.pumpAndSettle();
      expect(find.byType(AuthLoginScreen), findsOneWidget);
      expect(find.text('Email ou mot de passe incorrect.'), findsOneWidget);
    });

    testWidgets('compte connecté au démarrage : jamais l’écran de marque', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(_buildApp(AuthState(user: _authedUser), db));
      await tester.pump();
      expect(find.byType(WelcomeScreen), findsNothing);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(WelcomeScreen), findsNothing);
      expect(find.byType(TodayScreen), findsOneWidget);
    });
  });
}

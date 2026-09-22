import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/router/app_router.dart';
import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/data/colleges_repository.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/demo/presentation/demo_screen.dart';
import 'package:collega_app/core/ui/components/cg_state.dart';
import 'package:collega_app/core/ui/components/cg_tab_bar.dart';
import 'package:collega_app/features/today/presentation/today_screen.dart';
import 'package:collega_app/features/today/today_providers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._authState);
  final AuthState _authState;

  @override
  Future<AuthState> build() async => _authState;
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

Widget _buildApp(AuthState authState, AppDatabase db) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(() => _FakeAuthNotifier(authState)),
      todayProvider.overrideWith(_FakeTodayNotifier.new),
      collegesRepositoryProvider
          .overrideWithValue(_FakeCollegesRepository()),
      databaseProvider.overrideWithValue(db),
    ],
    child: Consumer(builder: (ctx, ref, _) {
      return ShadApp.router(
        theme: buildShadTheme(),
        routerConfig: ref.watch(routerProvider),
      );
    }),
  );
}

void main() {
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

    testWidgets('AC3: user non-authentifié sur /demo → DemoScreen rendu',
        (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(_buildApp(const AuthState(), db));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Pas de redirect → DemoScreen affiché.
      expect(find.byType(DemoScreen), findsOneWidget);
      expect(find.byType(TodayScreen), findsNothing);
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

    testWidgets('onglet Progression : état vide en attendant la story 8.8', (tester) async {
      await signedIn(tester);
      await tester.tap(find.descendant(of: find.byType(CgTabBar), matching: find.text('Progression')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CgState), findsOneWidget);
      expect(find.text('Ta première session remplira cette page'), findsOneWidget);
    });

    testWidgets('/progress protégé : non connecté → démo', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(_buildApp(const AuthState(), db));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final container = ProviderScope.containerOf(tester.element(find.byType(DemoScreen)));
      container.read(routerProvider).go('/progress');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DemoScreen), findsOneWidget);
      expect(find.text('Progression'), findsNothing);
    });
  });
}

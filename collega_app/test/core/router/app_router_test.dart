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
import 'package:collega_app/features/home/home_providers.dart';
import 'package:collega_app/features/home/presentation/home_screen.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._authState);
  final AuthState _authState;

  @override
  Future<AuthState> build() async => _authState;
}

class _FakeHomeNotifier extends HomeNotifier {
  _FakeHomeNotifier(this._fixedState);
  final HomeState _fixedState;

  @override
  Future<HomeState> build() async => _fixedState;
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
      homeProvider.overrideWith(() => _FakeHomeNotifier(const HomeEmpty())),
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
    testWidgets('AC3: user authentifié sur /demo → HomeScreen rendu',
        (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(_buildApp(AuthState(user: _authedUser), db));
      // Plusieurs frames pour : 1) résoudre authProvider (AsyncLoading→Data),
      // 2) recréer le router, 3) appliquer le redirect, 4) build /home.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // AC3 : HomeScreen rendu (les providers Home sont mockés).
      expect(find.byType(HomeScreen), findsOneWidget);
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
      expect(find.byType(HomeScreen), findsNothing);
    });
  });
}

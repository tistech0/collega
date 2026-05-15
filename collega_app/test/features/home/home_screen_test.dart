import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/data/colleges_repository.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/home/domain/home_session_config.dart';
import 'package:collega_app/features/home/home_providers.dart';
import 'package:collega_app/features/home/presentation/home_screen.dart';

// ─── Faux notifiers ───────────────────────────────────────────────────────────

class _FakeHomeNotifier extends HomeNotifier {
  _FakeHomeNotifier(this._fixedState);
  final HomeState _fixedState;

  @override
  Future<HomeState> build() async => _fixedState;
}

class _FakeCollegesRepository extends CollegesRepository {
  _FakeCollegesRepository(this._statuses) : super(dio: Dio());
  final List<UserCollegeStatus> _statuses;

  @override
  Future<List<UserCollegeStatus>> getUserColleges() async => _statuses;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

CollegeListEntry _readyEntry(int refId, String collegeId) {
  final catalog = kCollegeCatalog.firstWhere((e) => e.refId == refId);
  return CollegeListEntry(
    catalog: catalog,
    userStatus: UserCollegeStatus(
      refId: refId,
      collegeId: collegeId,
      status: 'generation_complete',
      cardCountA: 5,
      cardCountB: 3,
      cardCountC: 2,
    ),
  );
}

Widget _wrap(HomeState state, {List<CollegeListEntry>? colleges, required AppDatabase db}) {
  final importedStatuses = (colleges ?? [])
      .where((e) => e.userStatus != null)
      .map((e) => e.userStatus!)
      .toList();

  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (ctx, s) => const Scaffold(body: HomeScreen()),
      ),
      GoRoute(path: '/search', builder: (ctx, s) => const SizedBox()),
      GoRoute(path: '/colleges', builder: (ctx, s) => const SizedBox()),
    ],
  );

  return ProviderScope(
    overrides: [
      homeProvider.overrideWith(() => _FakeHomeNotifier(state)),
      collegesRepositoryProvider.overrideWithValue(
        _FakeCollegesRepository(importedStatuses),
      ),
      databaseProvider.overrideWithValue(db),
    ],
    child: ShadApp.router(
      theme: buildShadTheme(),
      routerConfig: router,
    ),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('HomeScreen — état HomeEmpty', () {
    testWidgets('affiche le message vide + bouton Voir les collèges', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(_wrap(const HomeEmpty(), db: db));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('Importe ton premier collège'),
        findsOneWidget,
      );
      expect(find.text('Voir les collèges'), findsOneWidget);
      expect(find.text('Commencer'), findsNothing);
    });
  });

  group('HomeScreen — état HomeOcrInProgress', () {
    testWidgets('affiche "Tes fiches arrivent..." sans bouton Commencer', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await tester.pumpWidget(
        _wrap(const HomeOcrInProgress(collegeName: 'Cardiologie'), db: db),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Tes fiches arrivent...'), findsOneWidget);
      expect(find.byType(ShadProgress), findsOneWidget);
      expect(find.text('Commencer'), findsNothing);
    });
  });

  group('HomeScreen — état HomeReady', () {
    testWidgets('affiche le CTA Commencer et le nombre de fiches', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final entry = _readyEntry(1, 'c1');
      final readyState = HomeReady(
        sessionConfig: HomeSessionConfig(
          collegeId: 'c1',
          collegeName: entry.catalog.name,
        ),
        recentColleges: [entry],
        totalCards: 10,
      );

      await tester.pumpWidget(_wrap(readyState, colleges: [entry], db: db));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Commencer'), findsOneWidget);
      expect(find.text('10 fiches'), findsOneWidget);
    });

    testWidgets('affiche la section collèges récents', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final entry = _readyEntry(1, 'c1');
      final readyState = HomeReady(
        sessionConfig: HomeSessionConfig(
          collegeId: 'c1',
          collegeName: entry.catalog.name,
        ),
        recentColleges: [entry],
        totalCards: 5,
      );

      await tester.pumpWidget(_wrap(readyState, colleges: [entry], db: db));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Mes collèges récents'), findsOneWidget);
    });

    testWidgets('SearchBar tap navigue vers /search', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final entry = _readyEntry(1, 'c1');
      final readyState = HomeReady(
        sessionConfig: HomeSessionConfig(
          collegeId: 'c1',
          collegeName: entry.catalog.name,
        ),
        recentColleges: [entry],
        totalCards: 5,
      );

      await tester.pumpWidget(_wrap(readyState, colleges: [entry], db: db));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byType(ShadInput).first);
      await tester.pumpAndSettle();

      // Après navigation vers /search, HomeScreen n'est plus visible
      expect(find.byType(HomeScreen), findsNothing);
    });
  });
}

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
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/home/home_providers.dart';
import 'package:collega_app/features/home/presentation/home_screen.dart';

class _FakeHomeNotifier extends HomeNotifier {
  @override
  Future<HomeState> build() async => const HomeEmpty();
}

class _FakeCollegesRepository extends CollegesRepository {
  _FakeCollegesRepository() : super(dio: Dio());

  @override
  Future<List<UserCollegeStatus>> getUserColleges() async => [];
}

void main() {
  testWidgets(
      'la barre de recherche est rendue sous la status bar (padding top)',
      (tester) async {
    // Repro iPhone 2026-09-21 : le shell (Scaffold sans SafeArea) + la Home
    // (CustomScrollView sans padding top) → ShadInput sous l'heure.
    const statusBar = 47.0;
    // FakeViewPadding est en pixels physiques.
    tester.view.padding =
        FakeViewPadding(top: statusBar * tester.view.devicePixelRatio);
    addTearDown(tester.view.reset);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const Scaffold(body: HomeScreen())),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        homeProvider.overrideWith(_FakeHomeNotifier.new),
        collegesRepositoryProvider.overrideWithValue(_FakeCollegesRepository()),
        databaseProvider.overrideWithValue(db),
      ],
      child: ShadApp.router(theme: buildShadTheme(), routerConfig: router),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final top = tester.getTopLeft(find.byType(ShadInput)).dy;
    expect(top, greaterThanOrEqualTo(statusBar));
  });
}

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/drill/data/drill_repository.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';
import 'package:collega_app/features/drill/drill_providers.dart';
import 'package:collega_app/features/drill/presentation/drill_screen.dart';
import 'package:collega_app/shared/widgets/bottom_nav_bar.dart';

class _FakeDrillRepository extends DrillRepository {
  _FakeDrillRepository(this._cards)
      : super(
          dio: Dio(),
          db: AppDatabase.forTesting(NativeDatabase.memory()),
        );

  final List<FlashCardModel> _cards;

  @override
  Future<List<FlashCardModel>> getCardsForDrill({
    required String collegeId,
    String? itemId,
    List<String>? rangs,
    bool onlyARevoir = false,
    int maxCards = 0,
  }) async =>
      List.from(_cards);

  @override
  Future<void> updateCardDrillLevel(
      String cardId, DrillEvaluationResult result) async {}
}

List<FlashCardModel> _makeCards(int count) => List.generate(
      count,
      (i) => FlashCardModel(
        id: 'card-$i',
        itemId: 'i1',
        collegeId: 'c1',
        cardType: 'classique',
        rang: 'A',
        recto: 'Q$i',
        verso: 'R$i',
        ocrConfidenceScore: 1.0,
        lowConfidence: false,
      ),
    );

const _params = DrillSessionParams(collegeId: 'c1', itemId: 'i1');

Widget _wrap(List<FlashCardModel> cards) => ProviderScope(
      overrides: [
        drillRepositoryProvider
            .overrideWithValue(_FakeDrillRepository(cards)),
      ],
      child: ShadApp(
        theme: buildShadTheme(),
        home: DrillScreen(params: _params),
      ),
    );

Widget _wrapWithRouter(List<FlashCardModel> cards, DrillSessionParams params) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => DrillScreen(params: params),
    ),
    GoRoute(path: '/search', builder: (_, __) => const Scaffold(body: Text('Search'))),
    GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('Home'))),
  ]);
  return ProviderScope(
    overrides: [
      drillRepositoryProvider.overrideWithValue(_FakeDrillRepository(cards)),
    ],
    child: ShadApp.router(
      theme: buildShadTheme(),
      routerConfig: router,
    ),
  );
}

void main() {
  group('DrillScreen', () {
    testWidgets('affiche header + progressbar + flashcard (vue active)',
        (tester) async {
      await tester.pumpWidget(_wrap(_makeCards(2)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.textContaining('/ 2 fiches'), findsOneWidget);
      expect(find.text('Q0'), findsOneWidget);
    });

    testWidgets('bottom nav absent', (tester) async {
      await tester.pumpWidget(_wrap(_makeCards(1)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(BottomNavBar), findsNothing);
    });

    testWidgets('isComplete → affiche Session terminée', (tester) async {
      await tester.pumpWidget(_wrap(_makeCards(1)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier = container.read(drillSessionProvider(_params).notifier);

      notifier.flip();
      await notifier.evaluate(DrillEvaluationResult.maitrise);
      notifier.advanceToNext();

      await tester.pumpAndSettle();

      expect(find.text('Session terminée'), findsOneWidget);
    });
  });

  group('DrillEndScreen — fromSearch', () {
    const fromSearchParams = DrillSessionParams(
      collegeId: 'c1',
      itemId: 'i1',
      fromSearch: true,
    );

    Future<void> completeSession(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier =
          container.read(drillSessionProvider(fromSearchParams).notifier);
      notifier.flip();
      await notifier.evaluate(DrillEvaluationResult.maitrise);
      notifier.advanceToNext();
      await tester.pumpAndSettle();
    }

    testWidgets('affiche "Nouvelle recherche" et "Retour à l\'accueil"',
        (tester) async {
      await tester.pumpWidget(
          _wrapWithRouter(_makeCards(1), fromSearchParams));
      await completeSession(tester);

      expect(find.text('Nouvelle recherche'), findsOneWidget);
      expect(find.text("Retour à l'accueil"), findsOneWidget);
    });

    testWidgets('tap "Nouvelle recherche" navigue vers /search', (tester) async {
      await tester.pumpWidget(
          _wrapWithRouter(_makeCards(1), fromSearchParams));
      await completeSession(tester);

      await tester.tap(find.text('Nouvelle recherche'));
      await tester.pumpAndSettle();

      expect(find.text('Search'), findsOneWidget);
    });

    testWidgets('fromSearch:false → pas de "Nouvelle recherche"',
        (tester) async {
      await tester.pumpWidget(_wrap(_makeCards(1)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      final notifier = container.read(drillSessionProvider(_params).notifier);
      notifier.flip();
      await notifier.evaluate(DrillEvaluationResult.maitrise);
      notifier.advanceToNext();
      await tester.pumpAndSettle();

      expect(find.text('Nouvelle recherche'), findsNothing);
    });
  });
}

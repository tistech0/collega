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
import 'package:collega_app/features/drill/widgets/timer_ring.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';
import 'package:collega_app/features/profile/profile_providers.dart';
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

/// Fake notifier qui retourne instantanément des prefs fixées (Story 7.4 T15).
class _FakeRevisionPrefsNotifier extends RevisionPrefsNotifier {
  _FakeRevisionPrefsNotifier(this._prefs);
  final RevisionPrefs _prefs;

  @override
  Future<RevisionPrefs> build() async => _prefs;

  @override
  Future<void> save(RevisionPrefs prefs) async {}
}

Widget _wrap(
  List<FlashCardModel> cards, {
  RevisionPrefs? prefs,
}) =>
    ProviderScope(
      overrides: [
        drillRepositoryProvider
            .overrideWithValue(_FakeDrillRepository(cards)),
        if (prefs != null)
          revisionPrefsProvider.overrideWith(
            () => _FakeRevisionPrefsNotifier(prefs),
          ),
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

    // ─── Story 7.4 — Timer + auto-flip ──────────────────────────────────

    testWidgets('timerEnabled=true → TimerRing affiché sur le recto',
        (tester) async {
      await tester.pumpWidget(_wrap(
        _makeCards(1),
        prefs: const RevisionPrefs(
          timerEnabled: true,
          timerDurationSeconds: 30,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TimerRing), findsOneWidget);
      // Bouton pause/reprise dans le header
      expect(find.byIcon(Icons.timer), findsOneWidget);

      // Cleanup pour éviter pending timer leak
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('timerEnabled=false → pas de TimerRing', (tester) async {
      await tester.pumpWidget(_wrap(
        _makeCards(1),
        prefs: const RevisionPrefs(timerEnabled: false),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TimerRing), findsNothing);
      expect(find.byIcon(Icons.timer), findsNothing);
    });

    testWidgets('timer expire → session.isFlipped + timerExpired + toast',
        (tester) async {
      await tester.pumpWidget(_wrap(
        _makeCards(1),
        prefs: const RevisionPrefs(
          timerEnabled: true,
          timerDurationSeconds: 1,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );

      // Avant expiration : recto, pas de toast
      expect(
        container.read(drillSessionProvider(_params)).value!.isFlipped,
        isFalse,
      );
      expect(find.text('Temps écoulé'), findsNothing);

      // Avance le ticker au-delà de la durée
      await tester.pump(const Duration(milliseconds: 1200));

      // Après expiration : flippé + timerExpired
      final state = container.read(drillSessionProvider(_params)).value!;
      expect(state.isFlipped, isTrue);
      expect(state.timerExpired, isTrue);
      expect(find.text('Temps écoulé'), findsOneWidget);

      // Cleanup
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('DrillScreen — rappel de réinsertion', () {
    Future<ProviderContainer> flipAndPump(WidgetTester tester, int n) async {
      await tester.pumpWidget(_wrap(_makeCards(n)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(DrillScreen)),
      );
      container.read(drillSessionProvider(_params).notifier).flip();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      return container;
    }

    testWidgets('1er « À revoir » → toast « reviendra dans quelques questions »',
        (tester) async {
      await flipAndPump(tester, 3);

      await tester.tap(find.text('À revoir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('reviendra dans quelques questions'),
          findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('le toast disparaît en ~2 s (5 s par défaut = trop long)',
        (tester) async {
      await flipAndPump(tester, 3);

      await tester.tap(find.text('À revoir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('reviendra'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('reviendra'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('« Bien » → pas de toast', (tester) async {
      await flipAndPump(tester, 3);

      await tester.tap(find.text('Bien'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('reviendra'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
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

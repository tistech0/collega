import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/drill/data/drill_repository.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';
import 'package:collega_app/features/drill/drill_providers.dart';
import 'package:collega_app/features/drill/presentation/drill_end_screen.dart';
import 'package:collega_app/features/today/today_providers.dart';

import '../../support/cg_golden.dart';

FlashCardModel _card(int i, String item) => FlashCardModel(
      id: 'card-$i', itemId: item, collegeId: 'c3', cardType: 'classique', rang: 'A',
      recto: 'Q$i', verso: 'R$i', ocrConfidenceScore: 1, lowConfidence: false,
    );

/// 24 fiches : 18 maîtrisées, 4 bien, 2 à revoir (maquette).
DrillSessionState _session({int mastered = 18, int good = 4, int review = 2, DateTime? startedAt}) {
  final cards = [for (var i = 0; i < mastered + good + review; i++) _card(i, i < 3 ? 'item-$i' : 'item-x')];
  final evals = <String, DrillEvaluationResult>{
    for (var i = 0; i < cards.length; i++)
      cards[i].id: i < mastered
          ? DrillEvaluationResult.maitrise
          : i < mastered + good
              ? DrillEvaluationResult.bien
              : DrillEvaluationResult.aRevoir,
  };
  return DrillSessionState(
    cards: cards,
    queue: [for (var i = 0; i < cards.length; i++) i],
    currentQueuePos: cards.length,
    evaluatedCount: cards.length,
    evaluations: evals,
    isComplete: true,
    startedAt: startedAt ?? DateTime.now().subtract(const Duration(minutes: 19, seconds: 10)),
  );
}

class _Today extends TodayNotifier {
  @override
  Future<TodayState> build() async => const TodayNoCollege();
}

class _Notifier extends DrillSessionNotifier {
  _Notifier(this.initial);
  final DrillSessionState initial;
  int restarts = 0;
  @override
  Future<DrillSessionState> build(DrillSessionParams arg) async => initial;
  @override
  void restartWithErrors() => restarts++;
}

void main() {
  late AppDatabase db;
  setUpAll(loadCgFonts);
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    for (final (id, n, title) in [('item-0', 310, 'Tumeurs du testicule'), ('item-1', 309, 'Tumeurs du poumon'),
        ('item-2', 290, 'Épidémiologie des cancers'), ('item-x', 312, 'Tumeurs du sein')]) {
      await db.into(db.items).insert(ItemsCompanion.insert(
            id: id, collegeId: 'c3', itemNumber: n, rang: 'A', chapterTitle: Value(title)));
    }
  });
  tearDown(() => db.close());

  Future<_Notifier> pump(WidgetTester tester, DrillSessionParams params, DrillSessionState state,
      {List<String>? visited, double width = 393, double scale = 1}) async {
    tester.view.physicalSize = Size(width, 852);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final notifier = _Notifier(state);
    final router = GoRouter(initialLocation: '/origin', routes: [
      GoRoute(path: '/home', builder: (_, __) { visited?.add('/home'); return const SizedBox(); }),
      GoRoute(path: '/origin', builder: (_, __) => const SizedBox(), routes: [
        GoRoute(path: 'end', builder: (context, _) => Consumer(builder: (context, ref, _) {
          final s = ref.watch(drillSessionProvider(params)).valueOrNull;
          if (s == null) return const SizedBox();
          return DrillEndScreen(session: s, notifier: ref.read(drillSessionProvider(params).notifier), params: params);
        })),
      ]),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        drillRepositoryProvider.overrideWithValue(DrillRepository(dio: Dio(), db: db)),
        drillSessionProvider.overrideWith(() => notifier),
        todayProvider.overrideWith(_Today.new),
      ],
      child: CgTheme(
        data: CgThemeData.light,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: buildCgMaterialTheme(CgThemeData.light),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
      ),
    ));
    router.push('/origin/end');
    await tester.pumpAndSettle();
    return notifier;
  }

  const daily = DrillSessionParams.daily(20000);
  const item = DrillSessionParams(collegeId: 'c3', itemId: 'item-0', itemName: 'Tumeurs du testicule');

  testWidgets('bloc sarcelle : « Session terminée · 19 min », score 18/24, « maîtrisées »', (tester) async {
    await pump(tester, daily, _session());
    expect(find.text('Session terminée · 19 min'), findsOneWidget);
    expect(find.text('18'), findsNWidgets(2)); // score + stat
    expect(find.text('/24'), findsOneWidget);
    expect(find.text('maîtrisées'), findsWidgets);
  });

  testWidgets('barre blanche segmentée : 3 segments visibles, proportionnels (maquette)', (tester) async {
    await pump(tester, daily, _session());
    final segments = tester.widgetList<ColoredBox>(find.descendant(
      of: find.byKey(const Key('end-score-bar')), matching: find.byType(ColoredBox))).toList();
    expect(segments, hasLength(3));
    final widths = [
      for (final e in find.descendant(of: find.byKey(const Key('end-score-bar')), matching: find.byType(ColoredBox)).evaluate())
        tester.getSize(find.byWidget(e.widget)).width,
    ];
    expect(widths[0], greaterThan(widths[1] * 3));
    expect(tester.getSize(find.byKey(const Key('end-score-bar'))).height, 10);
    for (final e in find.descendant(of: find.byKey(const Key('end-score-bar')), matching: find.byType(ColoredBox)).evaluate()) {
      expect(tester.getSize(find.byWidget(e.widget)).height, 10, reason: 'segment visible (pas de hauteur nulle)');
    }
  });

  testWidgets('stats : 18 maîtrisées · 4 bien · 2 à revoir', (tester) async {
    await pump(tester, daily, _session());
    expect(find.text('4'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('bien'), findsOneWidget);
    expect(find.text('à revoir'), findsOneWidget);
  });

  testWidgets('« Ce que tu as consolidé » : titres des items maîtrisés, 3 max + « et N autres »', (tester) async {
    await pump(tester, daily, _session());
    expect(find.text('Ce que tu as consolidé'), findsOneWidget);
    expect(find.textContaining('Tumeurs du testicule'), findsOneWidget);
    expect(find.textContaining('et\u00A01\u00A0autre'), findsOneWidget);
  });

  testWidgets('session du jour : « Prochaine session » + un seul primaire « Terminer »', (tester) async {
    await pump(tester, daily, _session());
    expect(find.text('Prochaine session'), findsOneWidget);
    expect(find.textContaining('Demain'), findsOneWidget);
    expect(find.textContaining('à revoir en priorité'), findsOneWidget);
    final primaries = tester.widgetList<CgButton>(find.byType(CgButton)).where((b) => b.variant == CgButtonVariant.primary);
    expect(primaries.map((b) => b.label), ['Terminer']);
    expect(find.textContaining('Session terminée ✓'), findsNothing);
  });

  testWidgets('« Refaire les 2 à revoir » relance les erreurs ; absent sans erreur', (tester) async {
    final n = await pump(tester, daily, _session());
    await tester.tap(find.text('Refaire les 2 à revoir'));
    expect(n.restarts, 1);
  });

  testWidgets('drill d’item sans erreur : pas de « Prochaine session », pas de « Refaire »', (tester) async {
    await pump(tester, item, _session(mastered: 5, good: 1, review: 0));
    expect(find.text('Prochaine session'), findsNothing);
    expect(find.textContaining('Refaire'), findsNothing);
  });

  testWidgets('« Terminer » revient à l’écran d’origine', (tester) async {
    final visited = <String>[];
    await pump(tester, item, _session(), visited: visited);
    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();
    expect(find.byType(DrillEndScreen), findsNothing);
    expect(visited, isEmpty, reason: 'pop vers l’origine, pas un saut à l’accueil');
  });

  testWidgets('recherche : « Retour à la recherche » (quiet) en plus de Terminer', (tester) async {
    await pump(tester, const DrillSessionParams(collegeId: 'c3', itemId: 'item-0', fromSearch: true), _session());
    expect(find.text('Retour à la recherche'), findsOneWidget);
  });

  testWidgets('recherche : « Terminer » ferme aussi la sheet de recherche restée dessous (revue 8.10)', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const params = DrillSessionParams(collegeId: 'c3', itemId: 'item-0', fromSearch: true);
    final notifier = _Notifier(_session());
    final router = GoRouter(initialLocation: '/home', routes: [
      ShellRoute(
        builder: (_, __, child) => child,
        routes: [GoRoute(path: '/home', builder: (_, __) => const Text('ACCUEIL'))],
      ),
      GoRoute(path: '/end', builder: (context, _) => Consumer(builder: (context, ref, _) {
        final s = ref.watch(drillSessionProvider(params)).valueOrNull;
        if (s == null) return const SizedBox();
        return DrillEndScreen(session: s, notifier: ref.read(drillSessionProvider(params).notifier), params: params);
      })),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        drillRepositoryProvider.overrideWithValue(DrillRepository(dio: Dio(), db: db)),
        drillSessionProvider.overrideWith(() => notifier),
        todayProvider.overrideWith(_Today.new),
      ],
      child: CgTheme(
        data: CgThemeData.light,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    // La sheet de recherche : route sans page sur le Navigator racine, puis le drill par-dessus.
    final homeContext = tester.element(find.text('ACCUEIL'));
    showCgSheet<void>(homeContext, builder: (_) => const Text('SHEET'));
    await tester.pumpAndSettle();
    router.push('/end');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminer'));
    await tester.pumpAndSettle();
    expect(find.text('SHEET'), findsNothing);
    expect(find.text('ACCUEIL'), findsOneWidget);
  });

  testWidgets('haptique de succès à l’apparition', (tester) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform,
        (call) async {
      if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments as String);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await pump(tester, daily, _session());
    expect(calls, contains('HapticFeedbackType.heavyImpact'));
  });

  testWidgets('VoiceOver : « 18 fiches maîtrisées sur 24 »', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, daily, _session());
    expect(find.bySemanticsLabel('18 fiches maîtrisées sur 24'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Dynamic Type 1,6 sur 375 : aucun débordement', (tester) async {
    await pump(tester, daily, _session(), width: 375, scale: 1.6);
    expect(tester.takeException(), isNull);
  });

  group('revue 8.5', () {
    testWidgets('pluriels : « Refaire la fiche à revoir », « 1 fiche maîtrisée sur 1 »', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, daily, _session(mastered: 1, good: 0, review: 1));
      expect(find.text('Refaire la fiche à revoir'), findsOneWidget);
      expect(find.bySemanticsLabel('1 fiche maîtrisée sur 2'), findsOneWidget);
      expect(find.text('maîtrisée'), findsWidgets);
      handle.dispose();
    });

    testWidgets('durée au-delà d’une heure : « 1 h 12 »', (tester) async {
      await pump(tester, item, _session(startedAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 12))));
      expect(find.text('Session terminée · 1 h 12'), findsOneWidget);
    });

    testWidgets('rien de jugé (fiches disparues) : message calme, pas de score 0/0', (tester) async {
      await pump(tester, daily, _session(mastered: 0, good: 0, review: 0));
      expect(find.text('0'), findsNothing);
      expect(find.text('Aucune fiche à réviser'), findsOneWidget);
      expect(find.text('Terminer'), findsOneWidget);
    });

    testWidgets('consolidé : un même item présent dans deux collèges n’apparaît qu’une fois', (tester) async {
      await db.into(db.items).insert(ItemsCompanion.insert(
            id: 'item-0-bis', collegeId: 'c34', itemNumber: 310, rang: 'A', chapterTitle: const Value('Tumeurs du testicule')));
      final s = _session(mastered: 2, good: 0, review: 0);
      final cards = [_card(0, 'item-0'), _card(1, 'item-0-bis')];
      await pump(tester, daily, DrillSessionState(
        cards: cards, queue: const [0, 1], currentQueuePos: 2, evaluatedCount: 2, isComplete: true,
        evaluations: {for (final c in cards) c.id: DrillEvaluationResult.maitrise}, startedAt: s.startedAt,
      ));
      expect(find.text('Tumeurs du testicule.'), findsOneWidget);
    });
  });

  group('goldens', () {
    for (final (name, params, state) in [
      ('daily', daily, _session()),
      ('item', item, _session(mastered: 5, good: 1, review: 0)),
    ]) {
      for (final width in cgGoldenWidths) {
        for (final scale in cgGoldenScales) {
          final tag = '${width.toInt()}_${scale.toString().replaceAll('.', '')}';
          testWidgets('golden drill_end_${name}_$tag', (tester) async {
            await pump(tester, params, state, width: width, scale: scale);
            await expectLater(find.byType(DrillEndScreen), matchesGoldenFile('goldens/drill_end_${name}_$tag.png'));
          });
        }
      }
    }
  });
}

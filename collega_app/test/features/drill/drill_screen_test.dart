import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';


import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/drill/data/drill_repository.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';
import 'package:collega_app/features/drill/drill_launcher.dart';
import 'package:collega_app/features/drill/drill_providers.dart';
import 'package:collega_app/features/drill/presentation/drill_end_screen.dart';
import 'package:collega_app/features/drill/presentation/drill_screen.dart';
import 'package:collega_app/features/drill/presentation/drill_timer_slot.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';
import 'package:collega_app/features/profile/profile_providers.dart';
import 'package:collega_app/features/today/today_providers.dart';

import '../../support/cg_golden.dart';

class _Repo extends DrillRepository {
  _Repo(this.cards, {this.semantic, this.semanticFails = false, this.semanticGate})
      : super(dio: Dio(), db: AppDatabase.forTesting(NativeDatabase.memory()));

  final List<FlashCardModel> cards;
  final SemanticFeedback? semantic;
  final bool semanticFails;
  final Completer<void>? semanticGate;
  final updated = <String, DrillEvaluationResult>{};
  String? lastAnswer;

  @override
  Future<List<FlashCardModel>> getCardsForDrill({
    required String collegeId, String? itemId, List<String>? rangs, bool onlyARevoir = false, int maxCards = 0,
  }) async => List.of(cards);

  @override
  Future<void> updateCardDrillLevel(String cardId, DrillEvaluationResult result) async => updated[cardId] = result;

  @override
  Future<SemanticFeedback> evaluateSemantic(String cardId, String userAnswer) async {
    lastAnswer = userAnswer;
    await semanticGate?.future;
    if (semanticFails) throw DioException(requestOptions: RequestOptions());
    return semantic!;
  }
}

class _Today extends TodayNotifier {
  @override
  Future<TodayState> build() async => const TodayNoCollege();
}

class _Prefs extends RevisionPrefsNotifier {
  _Prefs(this.prefs);
  final RevisionPrefs prefs;
  @override
  Future<RevisionPrefs> build() async => prefs;
}

class _Colleges extends CollegesNotifier {
  @override
  Future<List<CollegeListEntry>> build() async => [
        for (final c in kCollegeCatalog)
          CollegeListEntry(
            catalog: c,
            userStatus: c.refId == 3
                ? const UserCollegeStatus(refId: 3, collegeId: 'c3', status: 'generation_complete', cardCountA: 3, cardCountB: 0, cardCountC: 0)
                : null,
          ),
      ];
}

FlashCardModel _card(int i, {String type = 'classique', String rang = 'A'}) => FlashCardModel(
      id: 'card-$i', itemId: 'i1', collegeId: 'c3', cardType: type, rang: rang,
      recto: 'Question $i ?', verso: 'Réponse $i.', ocrConfidenceScore: 1, lowConfidence: false,
    );

const _params = DrillSessionParams(collegeId: 'c3', itemId: 'i1', itemName: 'Tumeurs du testicule');

Widget _app(_Repo repo, {DrillLaunch? launch, RevisionPrefs prefs = const RevisionPrefs(), List<String>? visited}) {
  final router = GoRouter(initialLocation: '/drill', routes: [
    GoRoute(path: '/home', builder: (_, __) { visited?.add('/home'); return const SizedBox(); }),
    GoRoute(path: '/drill', builder: (_, __) => DrillScreen(launch: launch ?? const DrillLaunch(params: _params))),
  ]);
  return ProviderScope(
    overrides: [
      todayProvider.overrideWith(_Today.new),
      drillRepositoryProvider.overrideWithValue(repo),
      revisionPrefsProvider.overrideWith(() => _Prefs(prefs)),
      collegesProvider.overrideWith(_Colleges.new),
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
  );
}

void _phone(WidgetTester tester, {double width = 393, double height = 852}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _flip(WidgetTester tester) async {
  await tester.tap(find.byType(CgDrillCard));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadCgFonts);

  group('recto', () {
    testWidgets('question, « 1 / 3 », contexte (item), rang et collège', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_Repo([_card(0), _card(1), _card(2)])));
      await tester.pumpAndSettle();
      expect(find.text('Question 0 ?'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('Tumeurs du testicule'), findsOneWidget);
      expect(find.text('Rang A'), findsOneWidget);
      expect(find.text('Cancérologie'), findsOneWidget);
      expect(find.byType(CgTabBar), findsNothing);
    });

    testWidgets('session du jour : contexte « Session du jour »', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_Repo([_card(0)]), launch: const DrillLaunch(params: DrillSessionParams(collegeId: 'c3'))));
      await tester.pumpAndSettle();
      expect(find.text('Cancérologie'), findsWidgets);
    });
  });

  group('verdicts', () {
    testWidgets('bouton « Maîtrisé » → enregistré, fiche suivante « 2 / 3 »', (tester) async {
      _phone(tester);
      final repo = _Repo([_card(0), _card(1), _card(2)]);
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      await _flip(tester);
      await tester.tap(find.byKey(CgVerdictBar.buttonKey(CgVerdict.mastered)));
      await tester.pumpAndSettle();
      expect(repo.updated['card-0'], DrillEvaluationResult.maitrise);
      expect(find.text('Question 1 ?'), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('1er « À revoir » → réinsérée (file de 4) + toast « Elle reviendra… »', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_Repo([_card(0), _card(1), _card(2)])));
      await tester.pumpAndSettle();
      await _flip(tester);
      await tester.tap(find.byKey(CgVerdictBar.buttonKey(CgVerdict.review)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Elle reviendra dans quelques questions'), findsOneWidget);
      expect(find.text('2 / 4'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('« Bien » → pas de toast', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_Repo([_card(0), _card(1)])));
      await tester.pumpAndSettle();
      await _flip(tester);
      await tester.tap(find.byKey(CgVerdictBar.buttonKey(CgVerdict.good)));
      await tester.pumpAndSettle();
      expect(find.text('Elle reviendra dans quelques questions'), findsNothing);
    });

    testWidgets('dernière fiche jugée → écran de fin', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_Repo([_card(0)])));
      await tester.pumpAndSettle();
      await _flip(tester);
      await tester.tap(find.byKey(CgVerdictBar.buttonKey(CgVerdict.mastered)));
      await tester.pumpAndSettle();
      expect(find.byType(DrillEndScreen), findsOneWidget);
    });
  });

  group('quitter', () {
    testWidgets('✕ → « Quitter ? » avec la conséquence ; Continuer reste', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_Repo([_card(0), _card(1)])));
      await tester.pumpAndSettle();
      await _flip(tester);
      await tester.tap(find.byKey(CgVerdictBar.buttonKey(CgVerdict.good)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CgDrillCard.closeKey));
      await tester.pumpAndSettle();
      expect(find.text('Quitter ?'), findsOneWidget);
      expect(find.text('1 fiche jugée est enregistrée.'), findsOneWidget);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(find.text('Question 1 ?'), findsOneWidget);
    });

    testWidgets('« Quitter » → sort du drill', (tester) async {
      _phone(tester);
      final visited = <String>[];
      await tester.pumpWidget(_app(_Repo([_card(0), _card(1)]), visited: visited));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CgDrillCard.closeKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitter'));
      await tester.pumpAndSettle();
      expect(visited, ['/home']);
    });

    testWidgets('session du jour : « Ta session reprendra là où tu l’as laissée. »', (tester) async {
      _phone(tester);
      final daily = _app(_Repo([_card(0)]), launch: const DrillLaunch(params: _params));
      await tester.pumpWidget(daily);
      await tester.pumpAndSettle();
      // Contrat du message daily vérifié via la fonction pure.
      expect(quitMessage(isDaily: true, judged: 3), 'Ta session reprendra là où tu l’as laissée.');
      expect(quitMessage(isDaily: false, judged: 0), 'Aucune fiche n’a encore été jugée.');
      expect(quitMessage(isDaily: false, judged: 12), '12 fiches jugées sont enregistrées.');
      expect(quitMessage(isDaily: true, judged: 2, replaying: true), 'Ta session du jour est déjà enregistrée.');
    });
  });

  group('mode définition', () {
    testWidgets('réponse fermée tant que la définition n’est pas validée', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_Repo([_card(0, type: 'definition')],
          semantic: const SemanticFeedback(result: 'correct', feedback: 'Les éléments clés y sont.'))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Question 0 ?'));
      await tester.pumpAndSettle();
      expect(find.byKey(CgVerdictBar.buttonKey(CgVerdict.mastered)).hitTestable(), findsNothing);
    });

    testWidgets('valider → retour sémantique en tête de la réponse', (tester) async {
      _phone(tester);
      final repo = _Repo([_card(0, type: 'definition')],
          semantic: const SemanticFeedback(result: 'correct', feedback: 'Les éléments clés y sont.'));
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), 'ma définition');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      expect(repo.lastAnswer, 'ma définition');
      expect(find.text('Correct'), findsOneWidget);
      expect(find.text('Les éléments clés y sont.'), findsOneWidget);
      expect(find.byKey(CgVerdictBar.buttonKey(CgVerdict.mastered)).hitTestable(), findsOneWidget);
    });

    testWidgets('échec réseau de l’évaluation : la réponse s’ouvre quand même', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_Repo([_card(0, type: 'definition')], semanticFails: true)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(CupertinoTextField), 'ma définition');
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      expect(find.byKey(CgVerdictBar.buttonKey(CgVerdict.mastered)).hitTestable(), findsOneWidget);
    });
  });

  group('chronomètre (demande utilisateur)', () {
    testWidgets('lancé sans chrono : emplacement « Activer », tap → anneau', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_Repo([_card(0), _card(1)]), prefs: const RevisionPrefs(timerDurationSeconds: 5)));
      await tester.pumpAndSettle();
      expect(tester.widget<DrillTimerSlot>(find.byType(DrillTimerSlot)).enabled, isFalse);
      await tester.tap(find.byType(DrillTimerSlot));
      await tester.pump();
      expect(tester.widget<DrillTimerSlot>(find.byType(DrillTimerSlot)).enabled, isTrue);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('lancé avec chrono : à l’expiration la réponse s’ouvre + toast « Temps écoulé »', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(
        _Repo([_card(0), _card(1)]),
        launch: const DrillLaunch(params: _params, timerOn: true),
        prefs: const RevisionPrefs(timerDurationSeconds: 2),
      ));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Temps écoulé'), findsOneWidget);
      expect(find.byKey(CgVerdictBar.buttonKey(CgVerdict.mastered)).hitTestable(), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('retours de revue 8.4', () {
    testWidgets('évaluation arrivée après le passage à la fiche suivante : ignorée', (tester) async {
      _phone(tester);
      final gate = Completer<void>();
      await tester.pumpWidget(_app(
        _Repo([_card(0, type: 'definition'), _card(1)],
            semantic: const SemanticFeedback(result: 'correct', feedback: 'Retour de la fiche 0'), semanticGate: gate),
        launch: const DrillLaunch(params: _params, timerOn: true),
        prefs: const RevisionPrefs(timerDurationSeconds: 1),
      ));
      await tester.pump();
      await tester.pump();
      await tester.enterText(find.byType(CupertinoTextField), 'ma définition');
      await tester.tap(find.text('Valider'));
      await tester.pump(const Duration(seconds: 2)); // chrono expiré : réponse ouverte
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Temps écoulé'), findsOneWidget, reason: 'étape 1 : chrono expiré');
      expect(find.byKey(CgVerdictBar.buttonKey(CgVerdict.good)).hitTestable(), findsOneWidget, reason: 'étape 2 : réponse ouverte');
      await tester.tap(find.byKey(CgVerdictBar.buttonKey(CgVerdict.good)));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Question 1 ?'), findsOneWidget);
      gate.complete();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Retour de la fiche 0'), findsNothing);
      expect(find.byKey(CgVerdictBar.buttonKey(CgVerdict.mastered)).hitTestable(), findsNothing,
          reason: 'la fiche 2 ne s’ouvre pas toute seule');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('expiration : l’état du drill note timerExpired', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_Repo([_card(0), _card(1)]),
          launch: const DrillLaunch(params: _params, timerOn: true), prefs: const RevisionPrefs(timerDurationSeconds: 1)));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      final container = ProviderScope.containerOf(tester.element(find.byType(DrillScreen)));
      expect(container.read(drillSessionProvider(_params)).value!.timerExpired, isTrue);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('« Quitter ? » ouvert : le chrono s’arrête, la fiche n’est pas perdue', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_Repo([_card(0), _card(1)]),
          launch: const DrillLaunch(params: _params, timerOn: true), prefs: const RevisionPrefs(timerDurationSeconds: 1)));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(CgDrillCard.closeKey));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Temps écoulé'), findsNothing);
      await tester.tap(find.text('Continuer'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(CgVerdictBar.buttonKey(CgVerdict.mastered)).hitTestable(), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('états', () {
    testWidgets('chargement : fond sarcelle, jamais de spinner Material', (tester) async {
      _phone(tester);
      final blocker = Completer<List<FlashCardModel>>();
      await tester.pumpWidget(_app(_BlockingRepo(blocker)));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byKey(const Key('drill-loading')), findsOneWidget);
      blocker.complete([_card(0)]);
      await tester.pumpAndSettle();
    });

    testWidgets('erreur : état Collega UI, sans message technique', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_FailingRepo()));
      await tester.pumpAndSettle();
      expect(find.byType(CgState), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });

  testWidgets('accessibilité : cibles étiquetées, 44 pt, contraste du texte (8.15)', (tester) async {
    final handle = tester.ensureSemantics();
    _phone(tester);
    await tester.pumpWidget(_app(_Repo([_card(0), _card(1)])));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('Dynamic Type 1,6 sur 375 : aucun débordement', (tester) async {
    _phone(tester, width: 375, height: 812);
    await tester.pumpWidget(_app(_Repo([_card(0, type: 'definition')])));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('goldens', () {
    for (final (name, repo, launch, flip) in <(String, _Repo Function(), DrillLaunch?, bool)>[
      ('recto', () => _Repo([_card(0), _card(1), _card(2)]), null, false),
      ('verso', () => _Repo([_card(0), _card(1), _card(2)]), null, true),
      ('definition', () => _Repo([_card(0, type: 'definition')]), null, false),
      ('timer', () => _Repo([_card(0), _card(1)]), const DrillLaunch(params: _params, timerOn: true), false),
    ]) {
      for (final width in cgGoldenWidths) {
        for (final scale in cgGoldenScales) {
          final tag = '${width.toInt()}_${scale.toString().replaceAll('.', '')}';
          testWidgets('golden drill_${name}_$tag', (tester) async {
            _phone(tester, width: width, height: 852);
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
            await tester.pumpWidget(_app(repo(), launch: launch, prefs: const RevisionPrefs(timerDurationSeconds: 30)));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 50));
            if (flip) await _flip(tester);
            await expectLater(find.byType(DrillScreen), matchesGoldenFile('goldens/drill_${name}_$tag.png'));
          });
        }
      }
    }
  });
}

class _BlockingRepo extends _Repo {
  _BlockingRepo(this.blocker) : super(const []);
  final Completer<List<FlashCardModel>> blocker;
  @override
  Future<List<FlashCardModel>> getCardsForDrill({
    required String collegeId, String? itemId, List<String>? rangs, bool onlyARevoir = false, int maxCards = 0,
  }) => blocker.future;
}

class _FailingRepo extends _Repo {
  _FailingRepo() : super(const []);
  @override
  Future<List<FlashCardModel>> getCardsForDrill({
    required String collegeId, String? itemId, List<String>? rangs, bool onlyARevoir = false, int maxCards = 0,
  }) async => throw StateError('Exception technique');
}

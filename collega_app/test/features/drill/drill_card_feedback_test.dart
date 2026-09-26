import 'dart:async';
import 'dart:ui' show SemanticsFlag;

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/colleges_detail_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/data/college_detail_repository.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/drill/data/drill_repository.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';
import 'package:collega_app/features/drill/drill_launcher.dart';
import 'package:collega_app/features/drill/drill_providers.dart';
import 'package:collega_app/features/drill/presentation/drill_screen.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';
import 'package:collega_app/features/profile/profile_providers.dart';
import 'package:collega_app/features/today/today_providers.dart';

class _DrillRepo extends DrillRepository {
  _DrillRepo(this.cards) : super(dio: Dio(), db: AppDatabase.forTesting(NativeDatabase.memory()));
  final List<FlashCardModel> cards;
  final updated = <String, DrillEvaluationResult>{};
  @override
  Future<List<FlashCardModel>> getCardsForDrill({
    required String collegeId, String? itemId, List<String>? rangs, bool onlyARevoir = false, int maxCards = 0,
  }) async => List.of(cards);
  @override
  Future<void> updateCardDrillLevel(String cardId, DrillEvaluationResult result) async => updated[cardId] = result;
}

class _CardsRepo extends CollegeDetailRepository {
  _CardsRepo({this.offline = false, this.regenGate, this.regenFails = false})
      : super(dio: Dio(), db: AppDatabase.forTesting(NativeDatabase.memory()));
  final bool offline;
  final Completer<void>? regenGate;
  final bool regenFails;
  final feedbacks = <String>[];
  final regenerated = <(String, String?)>[];

  DioException get _net => DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError);

  @override
  Future<List<FlashCardModel>> getCards(String collegeId, String itemId) async => const [];

  @override
  Future<void> submitFeedback(String cardId, String feedback) async {
    feedbacks.add('$cardId:$feedback');
    if (offline) throw _net;
  }

  @override
  Future<FlashCardModel> regenerateCard(String cardId, {String? userNote}) async {
    regenerated.add((cardId, userNote));
    await regenGate?.future;
    if (regenFails) throw _net;
    return _card(0).copyWith(recto: 'Question régénérée ?');
  }
}

class _Today extends TodayNotifier {
  @override
  Future<TodayState> build() async => const TodayNoCollege();
}

class _Prefs extends RevisionPrefsNotifier {
  @override
  Future<RevisionPrefs> build() async => const RevisionPrefs();
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

FlashCardModel _card(int i, {String? feedback}) => FlashCardModel(
      id: 'card-$i', itemId: 'i1', collegeId: 'c3', cardType: 'classique', rang: 'A',
      recto: 'Question $i ?', verso: 'Réponse $i.', ocrConfidenceScore: 1, lowConfidence: false,
      userFeedback: feedback,
    );

const _params = DrillSessionParams(collegeId: 'c3', itemId: 'i1', itemName: 'Tumeurs du testicule');

late ProviderContainer _container;

Widget _app(_DrillRepo drill, _CardsRepo cards, {List<String>? visited}) {
  final router = GoRouter(initialLocation: '/drill', routes: [
    GoRoute(path: '/home', builder: (_, __) { visited?.add('/home'); return const SizedBox(); }),
    GoRoute(path: '/drill', builder: (_, __) => const DrillScreen(launch: DrillLaunch(params: _params))),
  ]);
  _container = ProviderContainer(overrides: [
    todayProvider.overrideWith(_Today.new),
    drillRepositoryProvider.overrideWithValue(drill),
    collegeDetailRepositoryProvider.overrideWithValue(cards),
    revisionPrefsProvider.overrideWith(_Prefs.new),
    collegesProvider.overrideWith(_Colleges.new),
  ]);
  addTearDown(_container.dispose);
  return UncontrolledProviderScope(
    container: _container,
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

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _flip(WidgetTester tester) async {
  await tester.tap(find.byType(CgDrillCard));
  await tester.pumpAndSettle();
}

bool _selected(WidgetTester tester, Key key) =>
    tester.getSemantics(find.byKey(key)).hasFlag(SemanticsFlag.isSelected);

void main() {
  testWidgets('recto : pas d’avis ; verso : les deux icônes', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_DrillRepo([_card(0), _card(1)]), _CardsRepo()));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Fiche utile'), findsNothing);
    await _flip(tester);
    expect(find.bySemanticsLabel('Fiche utile'), findsOneWidget);
    expect(find.bySemanticsLabel('Signaler la fiche'), findsOneWidget);
  });

  testWidgets('avis déjà donné (Drift) : affiché choisi', (tester) async {
    _phone(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_DrillRepo([_card(0, feedback: 'positive')]), _CardsRepo()));
    await tester.pumpAndSettle();
    await _flip(tester);
    expect(_selected(tester, CgCardFeedback.usefulKey), isTrue);
    expect(_selected(tester, CgCardFeedback.reportKey), isFalse);
    handle.dispose();
  });

  testWidgets('« Utile » : enregistré, choisi, aucun verdict, la fiche reste', (tester) async {
    _phone(tester);
    final handle = tester.ensureSemantics();
    final drill = _DrillRepo([_card(0), _card(1)]);
    final cards = _CardsRepo();
    await tester.pumpWidget(_app(drill, cards));
    await tester.pumpAndSettle();
    await _flip(tester);
    await tester.tap(find.byKey(CgCardFeedback.usefulKey));
    await tester.pumpAndSettle();
    expect(cards.feedbacks, ['card-0:positive']);
    expect(_selected(tester, CgCardFeedback.usefulKey), isTrue);
    expect(drill.updated, isEmpty);
    expect(find.text('Réponse 0.'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('« Utile » hors ligne : toast, pas choisi', (tester) async {
    _phone(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_DrillRepo([_card(0)]), _CardsRepo(offline: true)));
    await tester.pumpAndSettle();
    await _flip(tester);
    await tester.tap(find.byKey(CgCardFeedback.usefulKey));
    await tester.pump();
    expect(find.text('Ton retour n’a pas pu s’enregistrer. Réessaie.'), findsOneWidget);
    expect(_selected(tester, CgCardFeedback.usefulKey), isFalse);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    handle.dispose();
  });

  testWidgets('« À corriger » → feuille ; « Continuer sans régénérer » → « Fiche signalée », drill intact', (tester) async {
    _phone(tester);
    final drill = _DrillRepo([_card(0), _card(1)]);
    final cards = _CardsRepo();
    await tester.pumpWidget(_app(drill, cards));
    await tester.pumpAndSettle();
    await _flip(tester);
    await tester.tap(find.byKey(CgCardFeedback.reportKey));
    await tester.pumpAndSettle();
    expect(cards.feedbacks, ['card-0:negative']);
    expect(find.text('Signaler cette fiche'), findsOneWidget);
    await tester.tap(find.text('Continuer sans régénérer'));
    await tester.pump();
    expect(find.text('Fiche signalée'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(cards.regenerated, isEmpty);
    expect(drill.updated, isEmpty);
    expect(find.text('Réponse 0.'), findsOneWidget);
    await tester.tap(find.byKey(CgVerdictBar.buttonKey(CgVerdict.mastered)));
    await tester.pumpAndSettle();
    expect(drill.updated['card-0'], DrillEvaluationResult.maitrise);
  });

  testWidgets('« Régénérer et continuer » : non bloquant, note transmise, on juge la même fiche', (tester) async {
    _phone(tester);
    final gate = Completer<void>();
    final drill = _DrillRepo([_card(0), _card(1)]);
    final cards = _CardsRepo(regenGate: gate);
    await tester.pumpWidget(_app(drill, cards));
    await tester.pumpAndSettle();
    await _flip(tester);
    await tester.tap(find.byKey(CgCardFeedback.reportKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Dose fausse');
    await tester.tap(find.text('Régénérer et continuer'));
    await tester.pump();
    expect(cards.regenerated, [('card-0', 'Dose fausse')]);
    expect(find.text('Nouvelle version en préparation'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    // Régénération toujours en cours : la fiche courante se juge normalement.
    expect(find.text('Réponse 0.'), findsOneWidget);
    await tester.tap(find.byKey(CgVerdictBar.buttonKey(CgVerdict.good)));
    await tester.pumpAndSettle();
    expect(drill.updated['card-0'], DrillEvaluationResult.bien);
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('régénération en échec : toast dédié', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_DrillRepo([_card(0), _card(1)]), _CardsRepo(regenFails: true)));
    await tester.pumpAndSettle();
    await _flip(tester);
    await tester.tap(find.byKey(CgCardFeedback.reportKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Régénérer et continuer'));
    await tester.pumpAndSettle();
    expect(find.text('La régénération a échoué. Réessaie plus tard depuis la fiche de l’item.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('quitter pendant la régénération : aucune exception, résultat ignoré', (tester) async {
    _phone(tester);
    final gate = Completer<void>();
    final visited = <String>[];
    await tester.pumpWidget(_app(_DrillRepo([_card(0), _card(1)]), _CardsRepo(regenGate: gate), visited: visited));
    await tester.pumpAndSettle();
    await _flip(tester);
    await tester.tap(find.byKey(CgCardFeedback.reportKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Régénérer et continuer'));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CgDrillCard.closeKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitter'));
    await tester.pumpAndSettle();
    expect(visited, ['/home']);
    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('après un avis, la vue item relira le serveur (itemDetailProvider invalidé)', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_DrillRepo([_card(0)]), _CardsRepo()));
    await tester.pumpAndSettle();
    var builds = 0;
    // Compte les reconstructions via un provider dérivé.
    final sub = _container.listen<int>(
      Provider<int>((ref) {
        ref.watch(itemDetailProvider('c3:i1'));
        return ++builds;
      }),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    final before = builds;
    await _flip(tester);
    await tester.tap(find.byKey(CgCardFeedback.usefulKey));
    await tester.pumpAndSettle();
    expect(builds, greaterThan(before));
  });
}

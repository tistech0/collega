import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
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
import 'package:collega_app/features/colleges/domain/drill_stats.dart';
import 'package:collega_app/features/colleges/presentation/college_detail_screen.dart';
import 'package:collega_app/features/colleges/presentation/item_detail_screen.dart';
import 'package:collega_app/features/drill/drill_launcher.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';
import 'package:collega_app/features/profile/profile_providers.dart';
import 'package:collega_app/features/search/presentation/search_sheet.dart';

import '../../support/cg_golden.dart';

FlashCardModel _card(String id, {String rang = 'A', String? feedback, double ocr = 0.95}) => FlashCardModel(
      id: id,
      itemId: 'i232',
      collegeId: 'c3',
      cardType: 'classique',
      rang: rang,
      recto: 'Question $id : quel marqueur doser ?',
      verso: 'Réponse $id : le BNP, élevé dans l’insuffisance cardiaque.',
      ocrConfidenceScore: ocr,
      lowConfidence: ocr < 0.7,
      userFeedback: feedback,
    );

const _item = ItemModel(
  id: 'i232', collegeId: 'c3', itemNumber: 232, rang: 'A', chapterTitle: 'Insuffisance cardiaque',
  ocrConfidenceScore: 0.9, lowConfidence: false, cardCountA: 3, cardCountB: 0, cardCountC: 0,
);

class _Repo extends CollegeDetailRepository {
  _Repo(this.cards) : super(dio: Dio(), db: AppDatabase.forTesting(NativeDatabase.memory()));
  List<FlashCardModel> cards;
  Object? error;
  bool failNegative = false;
  final feedbacks = <String>[];
  final deleted = <String>[];
  final regenerated = <(String, String?)>[];

  @override
  Future<List<FlashCardModel>> getCards(String collegeId, String itemId) async {
    if (error != null) throw error!;
    return cards;
  }

  @override
  Future<List<FlashCardModel>> getCardsFromDrift(String itemId) async => const [];
  @override
  Future<void> syncCardsToDrift(List<FlashCardModel> cards) async {}
  @override
  Future<void> submitFeedback(String cardId, String feedback) async {
    feedbacks.add('$cardId:$feedback');
    if (failNegative && feedback == 'negative') {
      throw DioException(requestOptions: RequestOptions(path: '/f'), type: DioExceptionType.connectionError);
    }
  }
  @override
  Future<void> deleteCard(String cardId) async => deleted.add(cardId);
  @override
  Future<FlashCardModel> regenerateCard(String cardId, {String? userNote}) async {
    regenerated.add((cardId, userNote));
    return _card(cardId).copyWith(recto: 'Question régénérée ?');
  }
}

class _Colleges extends CollegesNotifier {
  static String status = 'generation_complete';
  @override
  Future<List<CollegeListEntry>> build() async => [
        for (final c in kCollegeCatalog)
          CollegeListEntry(
            catalog: c,
            userStatus: c.refId == 3
                ? UserCollegeStatus(refId: 3, collegeId: 'c3', status: status,
                    cardCountA: 3, cardCountB: 0, cardCountC: 0)
                : null,
          ),
      ];
}

class _Detail extends CollegeDetailNotifier {
  static int builds = 0;
  @override
  Future<CollegeDetailState> build(String collegeId) async {
    builds++;
    return const CollegeDetailLoaded(items: [_item]);
  }
}

class _Prefs extends RevisionPrefsNotifier {
  @override
  Future<RevisionPrefs> build() async => const RevisionPrefs();
}

class _Visit {
  final paths = <String>[];
  Object? drillExtra;
}

late _Repo _repo;

Widget _app({_Visit? visit, bool fromSearch = false, double textScale = 1}) {
  var pushed = false;
  final router = GoRouter(initialLocation: '/start', routes: [
    GoRoute(path: '/start', builder: (_, __) => Builder(builder: (context) {
          if (!pushed) {
            pushed = true;
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => context.push('/colleges/3/items/i232', extra: fromSearch ? kFromSearch : null));
          }
          return const SizedBox();
        })),
    GoRoute(
      path: '/colleges/:ref/items/:item',
      builder: (_, s) => ItemDetailScreen(
        refId: int.parse(s.pathParameters['ref']!),
        itemId: s.pathParameters['item']!,
        origin: CollegeDetailOrigin.library,
        fromSearch: s.extra == kFromSearch,
      ),
    ),
    GoRoute(path: '/drill', builder: (_, s) {
      visit?.paths.add('/drill');
      visit?.drillExtra = s.extra;
      return const SizedBox();
    }),
  ]);
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  // Titre de l'item : lu dans Drift (pas de rechargement réseau du collège).
  db.into(db.items).insert(ItemsCompanion.insert(
        id: _item.id, collegeId: 'c3', itemNumber: _item.itemNumber, rang: 'A', chapterTitle: Value(_item.chapterTitle)));
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      collegesProvider.overrideWith(_Colleges.new),
      collegeDetailProvider.overrideWith(_Detail.new),
      collegeDetailRepositoryProvider.overrideWithValue(_repo),
      collegeDrillStatsByItemProvider.overrideWith(
          (ref, id) => Stream.value({'i232': const DrillStats(maitrise: 1, bien: 1)})),
      revisionPrefsProvider.overrideWith(_Prefs.new),
    ],
    child: CgTheme(
      data: CgThemeData.light,
      child: WidgetsApp.router(
        debugShowCheckedModeBanner: false,
        color: CgColors.light.accent,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: true),
          child: CgGoldenFrame(child: child!),
        ),
      ),
    ),
  );
}

void _phone(WidgetTester tester, {double width = 393, double height = 1200}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpApp(WidgetTester tester, {_Visit? visit, bool fromSearch = false, double textScale = 1}) async {
  await tester.pumpWidget(_app(visit: visit, fromSearch: fromSearch, textScale: textScale));
  await tester.pumpAndSettle();
}

Future<void> _expand(WidgetTester tester, String id) async {
  await tester.tap(find.text('Question $id : quel marqueur doser ?'));
  await tester.pumpAndSettle();
}

void main() {
  // Bases en mémoire distinctes (dépôt factice + provider) : voulu ici.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUpAll(loadCgFonts);
  setUp(() {
    _repo = _Repo([_card('k1'), _card('k2'), _card('k3', ocr: 0.4)]);
    _Colleges.status = 'generation_complete';
    _Detail.builds = 0;
  });
  tearDown(() => _repo.db.close());

  group('en-tête', () {
    testWidgets('titre d’item, « Item 232 · Cancérologie · 3 fiches », retour collège, barre + légende', (tester) async {
      _phone(tester);
      await _pumpApp(tester);
      expect(_Detail.builds, 0, reason: 'le titre vient de Drift : pas de rechargement du collège');
      expect(find.text('Insuffisance cardiaque'), findsWidgets);
      expect(find.text('Item 232 · Cancérologie · 3 fiches'), findsOneWidget);
      expect(find.text('Cancérologie'), findsOneWidget, reason: '« ‹ Cancérologie »');
      final bar = tester.widget<CgRankBar>(find.byWidgetPredicate((w) => w is CgRankBar && w.legend));
      expect([bar.mastered, bar.good, bar.review, bar.unseen], [1, 1, 0, 1]);
    });

    testWidgets('un seul rang : badge, pas de segmented', (tester) async {
      _phone(tester);
      await _pumpApp(tester);
      expect(find.text('Rang A'), findsOneWidget);
      expect(find.byType(CgSegmented<String?>), findsNothing);
    });

    testWidgets('plusieurs rangs : segmented des rangs présents, filtre', (tester) async {
      _phone(tester);
      _repo.cards = [_card('k1'), _card('k2', rang: 'B')];
      await _pumpApp(tester);
      expect(find.text('Toutes'), findsOneWidget);
      expect(find.text('Rang C'), findsNothing);
      await tester.tap(find.text('Rang B'));
      await tester.pumpAndSettle();
      expect(find.text('Question k1 : quel marqueur doser ?'), findsNothing);
      expect(find.text('Question k2 : quel marqueur doser ?'), findsOneWidget);
    });
  });

  group('fiches', () {
    testWidgets('filtre sur un rang qui disparaît (fiche supprimée) : retour à « Toutes »', (tester) async {
      _phone(tester);
      _repo.cards = [_card('k1'), _card('k2'), _card('k3', rang: 'C')];
      await _pumpApp(tester);
      await tester.tap(find.text('Rang C'));
      await tester.pumpAndSettle();
      await _expand(tester, 'k3');
      await tester.tap(find.bySemanticsLabel('Plus d’actions sur la fiche'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer la fiche'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Question k1 : quel marqueur doser ?'), findsOneWidget);
    });

    testWidgets('signalement non enregistré (réseau) : dit, pas « Fiche signalée »', (tester) async {
      _phone(tester);
      _repo.failNegative = true;
      await _pumpApp(tester);
      await _expand(tester, 'k1');
      await tester.tap(find.bySemanticsLabel('Signaler la fiche'));
      await tester.pumpAndSettle();
      expect(find.textContaining('enregistré'), findsNothing, reason: 'la sheet n’affirme rien');
      await tester.tap(find.text('Plus tard'));
      await tester.pump();
      expect(find.text('Le signalement n’a pas pu s’enregistrer. Réessaie.'), findsOneWidget);
      expect(find.text('Fiche signalée'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('dépliable : la réponse s’affiche au toucher, VoiceOver lit l’état', (tester) async {
      _phone(tester);
      final handle = tester.ensureSemantics();
      await _pumpApp(tester);
      expect(find.textContaining('Réponse k1'), findsNothing);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('item-card-k1'))),
        matchesSemantics(isButton: true, hasTapAction: true, hasExpandedState: true, isExpanded: false,
            label: 'Question k1 : quel marqueur doser ?'),
      );
      await _expand(tester, 'k1');
      expect(find.textContaining('Réponse k1'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('pouce haut : état visible « Utile », enregistré', (tester) async {
      _phone(tester);
      await _pumpApp(tester);
      await _expand(tester, 'k1');
      await tester.tap(find.bySemanticsLabel('Fiche utile'));
      await tester.pumpAndSettle();
      expect(_repo.feedbacks, ['k1:positive']);
      expect(find.text('Utile'), findsOneWidget);
    });

    testWidgets('pouce bas = signaler : sheet, « Plus tard » → « Fiche signalée », rien supprimé', (tester) async {
      _phone(tester);
      await _pumpApp(tester);
      await _expand(tester, 'k1');
      await tester.tap(find.bySemanticsLabel('Signaler la fiche'));
      await tester.pumpAndSettle();
      expect(_repo.feedbacks, ['k1:negative']);
      expect(find.text('Signaler cette fiche'), findsOneWidget);
      expect(find.text('Supprimer'), findsNothing, reason: 'jamais à côté du signalement');
      await tester.tap(find.text('Plus tard'));
      await tester.pump();
      expect(find.text('Fiche signalée'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(_repo.deleted, isEmpty);
      expect(find.text('À corriger'), findsOneWidget);
    });

    testWidgets('signaler puis « Régénérer la fiche » avec la note', (tester) async {
      _phone(tester);
      await _pumpApp(tester);
      await _expand(tester, 'k1');
      await tester.tap(find.bySemanticsLabel('Signaler la fiche'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'Réponse trop vague');
      await tester.tap(find.text('Régénérer la fiche'));
      await tester.pumpAndSettle();
      expect(_repo.regenerated, [('k1', 'Réponse trop vague')]);
      expect(find.text('Question régénérée ?'), findsOneWidget);
    });

    testWidgets('suppression séparée : « … » → action sheet → confirmation écrite', (tester) async {
      _phone(tester);
      await _pumpApp(tester);
      await _expand(tester, 'k2');
      await tester.tap(find.bySemanticsLabel('Plus d’actions sur la fiche'));
      await tester.pumpAndSettle();
      expect(find.text('Régénérer la fiche'), findsOneWidget);
      await tester.tap(find.text('Supprimer la fiche'));
      await tester.pumpAndSettle();
      expect(find.text('Supprimer cette fiche ?'), findsOneWidget);
      expect(find.textContaining('définitif'), findsOneWidget);
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      expect(_repo.deleted, ['k2']);
      expect(find.text('Question k2 : quel marqueur doser ?'), findsNothing);
    });

    testWidgets('badge OCR tapable : explication', (tester) async {
      _phone(tester);
      await _pumpApp(tester);
      await _expand(tester, 'k3');
      await tester.tap(find.text('À vérifier'));
      await tester.pumpAndSettle();
      expect(find.text('Source à vérifier'), findsOneWidget);
    });
  });

  group('réviser et retour', () {
    testWidgets('« Réviser cet item · 3 fiches » lance le drill de l’item', (tester) async {
      _phone(tester);
      final visit = _Visit();
      await _pumpApp(tester, visit: visit);
      await tester.tap(find.text('Réviser cet item · 3 fiches'));
      await tester.pumpAndSettle();
      final launch = visit.drillExtra! as DrillLaunch;
      expect(launch.params.itemId, 'i232');
      expect(launch.params.itemName, 'Insuffisance cardiaque');
    });

    testWidgets('depuis la recherche : le retour système (balayage) rouvre aussi la recherche', (tester) async {
      _phone(tester);
      await _pumpApp(tester, fromSearch: true);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SearchPanel), findsOneWidget);
    });

    testWidgets('ouvert depuis la recherche : « ‹ Recherche » rouvre la recherche', (tester) async {
      _phone(tester);
      await _pumpApp(tester, fromSearch: true);
      expect(find.text('Recherche'), findsOneWidget);
      await tester.tap(find.text('Recherche'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchPanel), findsOneWidget);
    });
  });

  group('états', () {
    testWidgets('hors-ligne sans cache : état hors-ligne', (tester) async {
      _phone(tester);
      _repo.error = DioException(requestOptions: RequestOptions(path: '/c'), type: DioExceptionType.connectionError);
      await _pumpApp(tester);
      expect(find.text('Pas de connexion pour l’instant'), findsOneWidget);
    });

    testWidgets('erreur serveur : état d’erreur sans détail technique', (tester) async {
      _phone(tester);
      _repo.error = DioException(requestOptions: RequestOptions(path: '/c'), type: DioExceptionType.badResponse);
      await _pumpApp(tester);
      expect(find.text('Cet item n’a pas pu s’ouvrir'), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
    });

    testWidgets('collège en cours de réimport : « Les fiches arrivent », pas « introuvable »', (tester) async {
      _phone(tester);
      _Colleges.status = 'processing';
      await _pumpApp(tester);
      expect(find.text('Les fiches arrivent'), findsOneWidget);
      expect(find.text('Cet item est introuvable'), findsNothing);
    });

    testWidgets('aucune fiche', (tester) async {
      _phone(tester);
      _repo.cards = const [];
      await _pumpApp(tester);
      expect(find.text('Aucune fiche pour cet item'), findsOneWidget);
      expect(find.textContaining('Réviser cet item'), findsNothing);
    });
  });

  group('accessibilité', () {
    testWidgets('Dynamic Type 1,6 sur 375 : aucun débordement (fiche dépliée)', (tester) async {
      _phone(tester, width: 375, height: 1400);
      await _pumpApp(tester, textScale: 1.6);
      await _expand(tester, 'k3');
      expect(tester.takeException(), isNull);
    });

    test('aucun widget Material ni shadcn', () {
      final src = File('lib/features/colleges/presentation/item_detail_screen.dart').readAsStringSync();
      expect(src, isNot(contains('material.dart')));
      expect(src, isNot(contains('shadcn_ui')));
    });
  });

  group('goldens', () {
    for (final (name, expand) in [('collapsed', false), ('expanded', true)]) {
      for (final width in cgGoldenWidths) {
        for (final scale in cgGoldenScales) {
          final tag = '${width.toInt()}_${scale.toString().replaceAll('.', '')}';
          testWidgets('golden item_detail_${name}_$tag', tags: const ['golden'], (tester) async {
            _phone(tester, width: width, height: 1300);
            _repo.cards = [_card('k1', feedback: 'positive'), _card('k2'), _card('k3', ocr: 0.4, feedback: 'negative')];
            await _pumpApp(tester, textScale: scale);
            if (expand) {
              await _expand(tester, 'k1');
              await _expand(tester, 'k3');
            }
            await expectLater(find.byType(CgGoldenFrame), matchesGoldenFile('goldens/item_detail_${name}_$tag.png'));
          });
        }
      }
    }
  });
}

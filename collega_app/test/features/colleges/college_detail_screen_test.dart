import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/colleges_detail_providers.dart';
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/data/college_import_repository.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/colleges/domain/drill_stats.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';
import 'package:collega_app/features/colleges/presentation/college_detail_screen.dart';
import 'package:collega_app/features/drill/drill_launcher.dart';
import 'package:collega_app/features/pdf/data/local_pdf_store.dart';
import 'package:collega_app/features/pdf/pdf_providers.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';
import 'package:collega_app/features/profile/profile_providers.dart';

import '../../support/cg_golden.dart';

UserCollegeStatus _status(String status) => UserCollegeStatus(
      refId: 3, collegeId: 'c3', status: status, cardCountA: 25, cardCountB: 5, cardCountC: 3,
      pdfVersion: 'j1', pdfSize: 398458880,
    );

ItemModel _item(String id, int number, String rang, int cards, {String? title, bool lowConfidence = false}) =>
    ItemModel(
      id: id,
      collegeId: 'c3',
      itemNumber: number,
      rang: rang,
      chapterTitle: title,
      ocrConfidenceScore: lowConfidence ? 0.5 : 0.95,
      lowConfidence: lowConfidence,
      cardCountA: rang == 'A' ? cards : 0,
      cardCountB: rang == 'B' ? cards : 0,
      cardCountC: rang == 'C' ? cards : 0,
    );

// Ordre volontairement mélangé : l'écran trie par numéro.
final _items = [
  _item('i314', 314, 'A', 7, title: 'Tumeurs de la prostate'),
  _item('i310', 310, 'A', 6, title: 'Tumeurs du testicule'),
  _item('i311', 311, 'A', 5, title: 'Tumeurs vésicales'),
  _item('i312', 312, 'A', 4, title: 'Tumeurs du rein', lowConfidence: true),
  _item('i300', 300, 'B', 5, title: 'Cancer du col utérin'),
  _item('i305', 305, 'C', 3),
];

final _stats = {
  'i310': const DrillStats(maitrise: 3, bien: 1, aRevoir: 1, notSeen: 1),
  'i314': const DrillStats(maitrise: 7),
  'i300': const DrillStats(bien: 2, notSeen: 3),
};

/// Fixtures à un seul rang par item : ses stats sont celles de ce rang.
Map<String, Map<String, DrillStats>> _byRang(Map<String, DrillStats> stats) {
  final out = <String, Map<String, DrillStats>>{};
  for (final i in _items) {
    final s = stats[i.id];
    if (s != null) out.putIfAbsent(i.rang, () => {})[i.id] = s;
  }
  return out;
}

class _Colleges extends CollegesNotifier {
  _Colleges(this.status);
  final UserCollegeStatus? status;
  @override
  Future<List<CollegeListEntry>> build() async => [
        for (final c in kCollegeCatalog)
          CollegeListEntry(catalog: c, userStatus: c.refId == 3 ? status : null),
      ];
}

/// Fin d'un premier import : la liste se recharge (valeur précédente : pas
/// encore importé) puis dit le collège prêt.
class _ReloadingColleges extends CollegesNotifier {
  static int builds = 0;
  @override
  Future<List<CollegeListEntry>> build() async {
    builds++;
    final ready = builds > 1;
    if (ready) await Future<void>.delayed(const Duration(milliseconds: 30));
    return [
      for (final c in kCollegeCatalog)
        CollegeListEntry(catalog: c, userStatus: ready && c.refId == 3 ? _status('generation_complete') : null),
    ];
  }
}

class _Detail extends CollegeDetailNotifier {
  _Detail(this.result);
  final FutureOr<CollegeDetailState> Function() result;
  @override
  Future<CollegeDetailState> build(String collegeId) async => result();
}

class _Prefs extends RevisionPrefsNotifier {
  @override
  Future<RevisionPrefs> build() async => const RevisionPrefs();
}

class _ImportRepo extends CollegeImportRepository {
  _ImportRepo(this.limits) : super(dio: Dio());
  final ReloadLimits? limits;
  @override
  Future<ReloadLimits> getReloadLimits(int refId) async {
    if (limits == null) throw DioException(requestOptions: RequestOptions(path: '/limits'));
    return limits!;
  }
}

const _limitsOk = ReloadLimits(
  collegeReloadCount: 1, collegeReloadMax: 2, monthlyReloads: 1, monthlyMax: 3,
  monthlyResetAt: '2026-10-01T00:00:00+00:00',
);

class _Visit {
  final paths = <String>[];
  Object? drillExtra;
  Object? progressExtra;
}

Widget _app({
  UserCollegeStatus? status,
  bool imported = true,
  String start = '/colleges/3',
  bool direct = false,
  Map<String, DrillStats>? stats,
  Map<String, Map<String, DrillStats>>? statsByRang,
  FutureOr<CollegeDetailState> Function()? detail,
  ReloadLimits? limits = _limitsOk,
  _Visit? visit,
  double textScale = 1,
  CollegesNotifier Function()? colleges,
  bool autoPush = true,
  LocalPdfStatus pdf = LocalPdfStatus.upToDate,
}) {
  var pushed = !autoPush;
  Widget detailPage(GoRouterState s) => CollegeDetailScreen(
        refId: int.parse(s.pathParameters['ref']!),
        origin: s.uri.path.startsWith('/home/') ? CollegeDetailOrigin.today : CollegeDetailOrigin.library,
      );
  final router = GoRouter(
    initialLocation: direct ? start : '/start',
    routes: [
      // Le détail est poussé (comme depuis la Bibliothèque) : le retour a un parent.
      GoRoute(path: '/start', builder: (_, __) => Builder(
            builder: (context) {
              if (!pushed) {
                pushed = true;
                WidgetsBinding.instance.addPostFrameCallback((_) => context.push(start));
              }
              return const SizedBox();
            },
          )),
      GoRoute(path: '/colleges', builder: (_, __) {
        visit?.paths.add('/colleges');
        return const SizedBox();
      }),
      GoRoute(path: '/colleges/:ref', builder: (_, s) => detailPage(s)),
      GoRoute(path: '/home/colleges/:ref', builder: (_, s) => detailPage(s)),
      GoRoute(path: '/home/colleges/:ref/items/:item', builder: (_, s) {
        visit?.paths.add('/home/colleges/${s.pathParameters['ref']}/items/${s.pathParameters['item']}');
        return const SizedBox();
      }),
      GoRoute(path: '/colleges/:ref/import/progress', builder: (_, s) {
        visit?.paths.add('/colleges/${s.pathParameters['ref']}/import/progress');
        visit?.progressExtra = s.extra;
        return const SizedBox();
      }),
      GoRoute(path: '/colleges/:ref/import', builder: (_, s) {
        visit?.paths.add('/colleges/${s.pathParameters['ref']}/import');
        return const SizedBox();
      }),
      GoRoute(path: '/colleges/:ref/items/:item', builder: (_, s) {
        visit?.paths.add('/colleges/${s.pathParameters['ref']}/items/${s.pathParameters['item']}');
        return const SizedBox();
      }),
      GoRoute(path: '/colleges/:ref/pdf', builder: (_, s) {
        visit?.paths.add(s.uri.toString());
        return const SizedBox();
      }),
      GoRoute(path: '/drill', builder: (_, s) {
        visit?.paths.add('/drill');
        visit?.drillExtra = s.extra;
        return const SizedBox();
      }),
    ],
  );
  return ProviderScope(
    overrides: [
      collegesProvider.overrideWith(colleges ?? () => _Colleges(imported ? status ?? _status('generation_complete') : null)),
      collegeDetailProvider.overrideWith(() => _Detail(detail ?? () => CollegeDetailLoaded(items: _items))),
      collegeDrillStatsByItemProvider.overrideWith((ref, id) => Stream.value(stats ?? _stats)),
      collegeDrillStatsByItemForRangProvider.overrideWith(
          (ref, arg) => Stream.value((statsByRang ?? _byRang(stats ?? _stats))[arg.$2] ?? const {})),
      collegeImportRepositoryProvider.overrideWithValue(_ImportRepo(limits)),
      revisionPrefsProvider.overrideWith(_Prefs.new),
      collegePdfStatusProvider.overrideWith((ref, key) async => pdf),
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

void _phone(WidgetTester tester, {double width = 393, double height = 1400}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder _rankBar({required bool legend}) =>
    find.byWidgetPredicate((w) => w is CgRankBar && w.legend == legend);

void main() {
  setUpAll(loadCgFonts);

  group('en-tête', () {
    testWidgets('titre, retour « Bibliothèque », sous-titre fiches · items', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Cancérologie'), findsWidgets);
      expect(find.text('Bibliothèque'), findsOneWidget);
      expect(find.text('CNEC · 30 fiches · 6 items'), findsOneWidget);
    });

    testWidgets('venu d’Aujourd’hui (/home/colleges/3) : « ‹ Aujourd’hui », items sous /home', (tester) async {
      _phone(tester);
      final visit = _Visit();
      await tester.pumpWidget(_app(start: '/home/colleges/3', visit: visit));
      await tester.pumpAndSettle();
      expect(find.text('Aujourd’hui'), findsOneWidget);
      await tester.tap(find.text('Tumeurs du testicule'));
      await tester.pumpAndSettle();
      expect(visit.paths, ['/home/colleges/3/items/i310']);
    });

    testWidgets('barre 10 pt + légende chiffrée : maîtrise des fiches du collège', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      final bar = tester.widget<CgRankBar>(_rankBar(legend: true));
      expect(bar.size, CgRankBarSize.header);
      // 3+7 maîtrisées, 1+2 bien, 1 à revoir ; non vues = 30 − 14.
      expect([bar.mastered, bar.good, bar.review, bar.unseen], [10, 3, 1, 16]);
    });
  });

  group('items', () {
    testWidgets('titrés, triés par numéro, « Item 310 · 6 fiches », OCR signalé, repli « Item 305 »', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(y('Cancer du col utérin'), lessThan(y('Item 305')));
      expect(y('Item 305'), lessThan(y('Tumeurs du testicule')));
      expect(y('Tumeurs du testicule'), lessThan(y('Tumeurs de la prostate')));
      expect(find.text('Item 310 · 6 fiches'), findsOneWidget);
      expect(find.text('Item 312 · 4 fiches · OCR à vérifier'), findsOneWidget);
      expect(find.text('Item 305 · 3 fiches'), findsOneWidget);
      expect(_rankBar(legend: false), findsNWidgets(6));
    });

    testWidgets('toucher un item ouvre son détail', (tester) async {
      _phone(tester);
      final visit = _Visit();
      await tester.pumpWidget(_app(visit: visit));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tumeurs du testicule'));
      await tester.pumpAndSettle();
      expect(visit.paths, ['/colleges/3/items/i310']);
    });

    testWidgets('segmented Rang B : items, en-tête et bouton filtrés', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rang B'));
      await tester.pumpAndSettle();
      expect(find.text('Cancer du col utérin'), findsOneWidget);
      expect(find.text('Tumeurs du testicule'), findsNothing);
      final bar = tester.widget<CgRankBar>(_rankBar(legend: true));
      expect([bar.mastered, bar.good, bar.review, bar.unseen], [0, 2, 0, 3]);
      expect(find.text('Réviser le rang B · 5 fiches'), findsOneWidget);
    });

    testWidgets('rang des fiches : un item A avec des fiches B figure sous « Rang B », comptes et drill de ses seules fiches B',
        (tester) async {
      _phone(tester);
      final visit = _Visit();
      const mixed = ItemModel(
        id: 'i320', collegeId: 'c3', itemNumber: 320, rang: 'A', chapterTitle: 'Tumeurs de la vessie',
        ocrConfidenceScore: 0.95, lowConfidence: false, cardCountA: 4, cardCountB: 2, cardCountC: 0,
      );
      await tester.pumpWidget(_app(
        visit: visit,
        detail: () => CollegeDetailLoaded(items: [..._items, mixed]),
        statsByRang: {
          ..._byRang(_stats),
          'B': {..._byRang(_stats)['B']!, 'i320': const DrillStats(maitrise: 1, notSeen: 1)},
        },
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rang B'));
      await tester.pumpAndSettle();
      expect(find.text('Tumeurs de la vessie'), findsOneWidget);
      expect(find.text('Item 320 · 2 fiches de rang B'), findsOneWidget);
      // Le badge de l'item reste son propre rang.
      final row = find.ancestor(of: find.text('Tumeurs de la vessie'), matching: find.byType(CgListRow));
      expect(find.descendant(of: row, matching: find.text('A')), findsOneWidget);
      // En-tête : fiches B seulement (col utérin 5 + vessie 2).
      final bar = tester.widget<CgRankBar>(_rankBar(legend: true));
      expect([bar.mastered, bar.good, bar.review, bar.unseen], [1, 2, 0, 4]);
      await tester.tap(find.text('Réviser le rang B · 7 fiches'));
      await tester.pumpAndSettle();
      expect((visit.drillExtra! as DrillLaunch).params.rangs, ['B']);
    });

    testWidgets('filtre sans item : message, pas de bouton', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(detail: () => CollegeDetailLoaded(items: _items.where((i) => i.rang == 'A').toList())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rang C'));
      await tester.pumpAndSettle();
      expect(find.text('Aucune fiche de rang C dans ce collège.'), findsOneWidget);
      expect(find.textContaining('Réviser'), findsNothing);
    });
  });

  group('réviser', () {
    testWidgets('« Réviser ce collège · N fiches » : N = fiches présentes sur l’iPhone (24 au plus), lance le drill du collège', (tester) async {
      _phone(tester);
      final visit = _Visit();
      await tester.pumpWidget(_app(visit: visit));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Réviser ce collège · 18 fiches'));
      await tester.pumpAndSettle();
      expect(visit.paths, ['/drill']);
      final launch = visit.drillExtra! as DrillLaunch;
      expect(launch.params.collegeId, 'c3');
      expect(launch.params.rangs, isNull);
      expect(launch.params.maxCards, 24);
    });

    testWidgets('filtré rang A : le drill ne prend que le rang A', (tester) async {
      _phone(tester);
      final visit = _Visit();
      await tester.pumpWidget(_app(visit: visit));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rang A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Réviser le rang A · 13 fiches'));
      await tester.pumpAndSettle();
      expect((visit.drillExtra! as DrillLaunch).params.rangs, ['A']);
    });
  });

  testWidgets('fiches pas encore sur l’iPhone : bouton inactif qui le dit (revue 8.7)', (tester) async {
    _phone(tester);
    final visit = _Visit();
    await tester.pumpWidget(_app(stats: const {}, visit: visit));
    await tester.pumpAndSettle();
    expect(find.text('Fiches en cours de téléchargement'), findsOneWidget);
    await tester.tap(find.text('Fiches en cours de téléchargement'));
    await tester.pumpAndSettle();
    expect(visit.paths, isEmpty);
  });

  testWidgets('le filtre de rang survit au rechargement du détail (revue 8.7)', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rang B'));
    await tester.pumpAndSettle();
    ProviderScope.containerOf(tester.element(find.byType(CollegeDetailScreen)))
        .invalidate(collegeDetailProvider('c3'));
    await tester.pumpAndSettle();
    expect(find.text('Réviser le rang B · 5 fiches'), findsOneWidget);
  });

  group('réimport (action sheet)', () {
    Future<void> openReimport(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Plus d’actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Réimporter le PDF'));
      await tester.pumpAndSettle();
    }

    testWidgets('conséquence écrite, « Réimporter » ouvre l’import', (tester) async {
      _phone(tester);
      final visit = _Visit();
      await tester.pumpWidget(_app(visit: visit));
      await tester.pumpAndSettle();
      await openReimport(tester);
      expect(find.text('Réimporter le PDF ?'), findsOneWidget);
      expect(find.textContaining('Les nouvelles fiches remplaceront les fiches existantes.'), findsOneWidget);
      expect(find.textContaining('Réimports utilisés : 1/2 pour ce collège · 1/3 ce mois'), findsOneWidget);
      await tester.tap(find.text('Réimporter'));
      await tester.pumpAndSettle();
      expect(visit.paths, ['/colleges/3/import']);
    });

    testWidgets('« Annuler » ne fait rien', (tester) async {
      _phone(tester);
      final visit = _Visit();
      await tester.pumpWidget(_app(visit: visit));
      await tester.pumpAndSettle();
      await openReimport(tester);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(visit.paths, isEmpty);
    });

    testWidgets('limite du collège atteinte : explication, pas d’import', (tester) async {
      _phone(tester);
      final visit = _Visit();
      await tester.pumpWidget(_app(
        visit: visit,
        limits: const ReloadLimits(
          collegeReloadCount: 2, collegeReloadMax: 2, monthlyReloads: 2, monthlyMax: 3, monthlyResetAt: '',
        ),
      ));
      await tester.pumpAndSettle();
      await openReimport(tester);
      expect(find.text('Ce collège ne peut plus être réimporté'), findsOneWidget);
      expect(find.textContaining('Tes fiches restent disponibles.'), findsOneWidget);
      await tester.tap(find.text('Compris'));
      await tester.pumpAndSettle();
      expect(visit.paths, isEmpty);
    });

    testWidgets('limite mensuelle atteinte : date de remise à zéro', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(
        limits: const ReloadLimits(
          collegeReloadCount: 0, collegeReloadMax: 2, monthlyReloads: 3, monthlyMax: 3,
          monthlyResetAt: '2026-10-01T00:00:00+00:00',
        ),
      ));
      await tester.pumpAndSettle();
      await openReimport(tester);
      expect(find.text('Plus de réimport ce mois-ci'), findsOneWidget);
      expect(find.textContaining('le 1er octobre'), findsOneWidget);
    });

    testWidgets('limites injoignables : toast, pas de dialogue', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(limits: null));
      await tester.pumpAndSettle();
      await openReimport(tester);
      expect(find.text('Impossible de vérifier tes réimports. Réessaie dans un instant.'), findsOneWidget);
      expect(find.text('Réimporter le PDF ?'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  });

  group('états', () {
    testWidgets('import en cours : « Les fiches arrivent » + « Suivre l’import »', (tester) async {
      _phone(tester);
      final visit = _Visit();
      await tester.pumpWidget(_app(status: _status('processing'), visit: visit));
      await tester.pumpAndSettle();
      expect(find.text('Les fiches arrivent'), findsOneWidget);
      expect(find.textContaining('Réviser'), findsNothing);
      await tester.tap(find.text('Suivre l’import'));
      await tester.pumpAndSettle();
      expect(visit.paths, ['/colleges/3/import/progress']);
      expect(visit.progressExtra, {'collegeId': 'c3', 'refId': 3, 'reimport': false});
    });

    testWidgets('import échoué : « Relancer l’import » ouvre l’import', (tester) async {
      _phone(tester);
      final visit = _Visit();
      await tester.pumpWidget(_app(status: _status('failed'), visit: visit));
      await tester.pumpAndSettle();
      expect(find.text('L’import n’a pas abouti'), findsOneWidget);
      await tester.tap(find.text('Relancer l’import'));
      await tester.pumpAndSettle();
      expect(visit.paths, ['/colleges/3/import']);
    });

    testWidgets('collège non importé : redirigé vers l’import', (tester) async {
      _phone(tester);
      final visit = _Visit();
      await tester.pumpWidget(_app(imported: false, visit: visit));
      await tester.pumpAndSettle();
      expect(visit.paths, ['/colleges/3/import']);
    });

    testWidgets('hors-ligne sans cache : état hors-ligne', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(
        detail: () => throw DioException(
          requestOptions: RequestOptions(path: '/items'),
          type: DioExceptionType.connectionError,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Pas de connexion pour l’instant'), findsOneWidget);
    });

    testWidgets('erreur serveur (500) : état d’erreur, pas « hors connexion »', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(
        detail: () => throw DioException(requestOptions: RequestOptions(path: '/items'), type: DioExceptionType.badResponse),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Ce collège n’a pas pu s’ouvrir'), findsOneWidget);
    });

    testWidgets('lien direct vers un collège non importé : l’import garde un retour vers la Bibliothèque', (tester) async {
      _phone(tester);
      final visit = _Visit();
      await tester.pumpWidget(_app(imported: false, direct: true, visit: visit));
      await tester.pumpAndSettle();
      // La Bibliothèque sous l'import : le retour y mène.
      expect(visit.paths, containsAllInOrder(['/colleges', '/colleges/3/import']));
      expect(visit.paths.last, anyOf('/colleges/3/import', '/colleges'));
      expect(visit.paths.where((p) => p == '/colleges/3/import'), hasLength(1));
    });

    testWidgets('autre erreur : état d’erreur sans message technique', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(detail: () => throw StateError('boom')));
      await tester.pumpAndSettle();
      expect(find.text('Ce collège n’a pas pu s’ouvrir'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
    });

    testWidgets('aucun item : état vide + « Réimporter »', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(detail: () => const CollegeDetailEmpty()));
      await tester.pumpAndSettle();
      expect(find.text('Aucune fiche dans ce collège'), findsOneWidget);
      expect(find.text('Réimporter'), findsOneWidget);
    });

    testWidgets('chargement : squelette, titre déjà connu', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(detail: () => Completer<CollegeDetailState>().future));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.text('Cancérologie'), findsWidgets);
      expect(find.byType(CgSkeletonList), findsOneWidget);
    });
  });

  group('accessibilité', () {
    testWidgets('Dynamic Type 1,6 sur 375 : aucun débordement', (tester) async {
      _phone(tester, width: 375, height: 812);
      await tester.pumpWidget(_app(textScale: 1.6));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    test('aucun widget Material ni shadcn', () {
      final src = File('lib/features/colleges/presentation/college_detail_screen.dart').readAsStringSync();
      expect(src, isNot(contains('material.dart')));
      expect(src, isNot(contains('shadcn_ui')));
    });
  });

  group('PDF du collège (partie B)', () {
    testWidgets('ligne « Mon PDF du collège » : sur ce téléphone → ouvre le lecteur', (tester) async {
      final visit = _Visit();
      await tester.pumpWidget(_app(visit: visit));
      await tester.pumpAndSettle();
      expect(find.text('Mon PDF du collège'), findsOneWidget);
      expect(find.textContaining('sur ce téléphone'), findsOneWidget);
      await tester.tap(find.byKey(const Key('college-pdf-row')));
      await tester.pumpAndSettle();
      expect(visit.paths.last, '/colleges/3/pdf');
    });

    testWidgets('PDF absent : « à télécharger · 380 Mo »', (tester) async {
      await tester.pumpWidget(_app(pdf: LocalPdfStatus.absent));
      await tester.pumpAndSettle();
      expect(find.textContaining('à télécharger · 380 Mo'), findsOneWidget);
    });

    testWidgets('aucun PDF annoncé par le serveur ni en local : « indisponible pour l’instant »', (tester) async {
      final visit = _Visit();
      await tester.pumpWidget(_app(
        status: const UserCollegeStatus(refId: 3, collegeId: 'c3', status: 'generation_complete',
            cardCountA: 25, cardCountB: 5, cardCountC: 3),
        pdf: LocalPdfStatus.absent,
        visit: visit,
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('indisponible pour l’instant'), findsOneWidget);
      await tester.tap(find.byKey(const Key('college-pdf-row')));
      await tester.pumpAndSettle();
      expect(visit.paths.last, '/colleges/3/pdf');
    });
  });

  group('goldens', () {
    for (final (name, rang) in <(String, String?)>[('loaded', null), ('rang_b', 'Rang B')]) {
      for (final width in cgGoldenWidths) {
        for (final scale in cgGoldenScales) {
          final tag = '${width.toInt()}_${scale.toString().replaceAll('.', '')}';
          testWidgets('golden college_detail_${name}_$tag', tags: const ['golden'], (tester) async {
            _phone(tester, width: width, height: 1300);
            await tester.pumpWidget(_app(textScale: scale));
            await tester.pumpAndSettle();
            if (rang != null) {
              await tester.tap(find.text(rang));
              await tester.pumpAndSettle();
            }
            await expectLater(
              find.byType(CgGoldenFrame),
              matchesGoldenFile('goldens/college_detail_${name}_$tag.png'),
            );
          });
        }
      }
    }
  });

  testWidgets('fin d’un premier import : pendant le rechargement de la liste, pas de renvoi vers l’import (revue 8.13)',
      (tester) async {
    _phone(tester);
    _ReloadingColleges.builds = 0;
    final visit = _Visit();
    await tester.pumpWidget(_app(colleges: _ReloadingColleges.new, autoPush: false, visit: visit));
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(SizedBox).first);
    final container = ProviderScope.containerOf(element);
    await container.read(collegesProvider.future); // pas encore importé
    container.invalidate(collegesProvider); // l'import vient de finir : rechargement
    GoRouter.of(element).push('/colleges/3');
    await tester.pump();
    await tester.pump();
    expect(visit.paths, isEmpty, reason: 'la liste se recharge : on attend, on ne redirige pas');
    await tester.pumpAndSettle();
    expect(visit.paths, isEmpty);
    expect(find.text('Réviser ce collège · 18 fiches'), findsOneWidget);
  });
}

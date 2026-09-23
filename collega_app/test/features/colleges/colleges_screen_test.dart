import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/core/upload/part_transport.dart';
import 'package:collega_app/core/upload/upload_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/colleges/domain/drill_stats.dart';
import 'package:collega_app/features/colleges/presentation/colleges_screen.dart';

import 'package:collega_app/features/search/presentation/search_sheet.dart';

import '../../support/cg_golden.dart';

const _cancero = UserCollegeStatus(
  refId: 3, collegeId: 'c3', status: 'generation_complete', cardCountA: 100, cardCountB: 50, cardCountC: 27,
);
const _pneumo = UserCollegeStatus(
  refId: 34, collegeId: 'c34', status: 'generation_complete', cardCountA: 100, cardCountB: 64, cardCountC: 0,
);
const _neuroEnCours = UserCollegeStatus(
  refId: 26, collegeId: 'c26', status: 'processing', cardCountA: 0, cardCountB: 0, cardCountC: 0,
);
const _dermatoEchoue = UserCollegeStatus(
  refId: 7, collegeId: 'c7', status: 'failed', cardCountA: 0, cardCountB: 0, cardCountC: 0,
);

List<CollegeListEntry> _entries(List<UserCollegeStatus> imported) {
  final byRef = {for (final s in imported) s.refId: s};
  return [for (final c in kCollegeCatalog) CollegeListEntry(catalog: c, userStatus: byRef[c.refId])];
}

class _Fixed extends CollegesNotifier {
  _Fixed(this.imported, {this.offline = false});
  final List<UserCollegeStatus> imported;
  final bool offline;
  @override
  bool get isOffline => offline;
  @override
  Future<List<CollegeListEntry>> build() async => _entries(imported);
}

class _FailThenHang extends CollegesNotifier {
  static int builds = 0;
  @override
  Future<List<CollegeListEntry>> build() {
    builds++;
    if (builds == 1) {
      return Future.error(DioException(
        requestOptions: RequestOptions(path: '/v1/colleges'),
        type: DioExceptionType.connectionError,
      ));
    }
    return Completer<List<CollegeListEntry>>().future;
  }
}

class _CountingOffline extends _Fixed {
  _CountingOffline() : super([_cancero], offline: true);
  static int builds = 0;
  @override
  Future<List<CollegeListEntry>> build() {
    builds++;
    return super.build();
  }
}

class _Loading extends CollegesNotifier {
  @override
  Future<List<CollegeListEntry>> build() => Completer<List<CollegeListEntry>>().future;
}

class _Failing extends CollegesNotifier {
  _Failing(this.error);
  final Object error;
  static int builds = 0;
  @override
  Future<List<CollegeListEntry>> build() async {
    builds++;
    throw error;
  }
}

final _stats = {
  'c3': const DrillStats(maitrise: 74, bien: 25, aRevoir: 11, notSeen: 67),
  'c34': const DrillStats(notSeen: 164),
};

/// Envoi en cours (reprise d'un upload par morceaux) vu par la Bibliothèque.
class _Uploading extends CollegeImportNotifier {
  static CollegeImportState value = const ImportIdle();
  @override
  Future<CollegeImportState> build() async => value;
  @override
  Future<void> resumePendingUpload() async {}
}

Widget _app(CollegesNotifier Function() notifier, {List<String>? visited, double textScale = 1}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const CollegesScreen()),
    GoRoute(path: '/colleges/:ref', builder: (_, s) { visited?.add('/colleges/${s.pathParameters['ref']}'); return const SizedBox(); }),
    GoRoute(path: '/colleges/:ref/import', builder: (_, s) { visited?.add('/colleges/${s.pathParameters['ref']}/import'); return const SizedBox(); }),
  ]);
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  return ProviderScope(
    overrides: [
      collegesProvider.overrideWith(notifier),
      collegeDrillStatsProvider.overrideWith((ref, id) => Stream.value(_stats[id] ?? const DrillStats())),
      // L'écran reprend un upload interrompu au montage (story 7.11).
      databaseProvider.overrideWithValue(db),
      partTransportProvider.overrideWithValue(InMemoryPartTransport()),
      uploadCacheDirProvider.overrideWith((_) async => Directory.systemTemp),
      collegeImportProvider.overrideWith(_Uploading.new),
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

void _phone(WidgetTester tester, {double width = 393, double height = 852}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(loadCgFonts);

  group('contenu', () {
    testWidgets('large title, mes collèges en tête puis le catalogue', (tester) async {
      _phone(tester, height: 3000);
      await tester.pumpWidget(_app(() => _Fixed([_pneumo, _cancero])));
      await tester.pumpAndSettle();

      expect(find.text('Bibliothèque'), findsWidgets);
      expect(find.text('Mes collèges'), findsOneWidget);
      expect(find.text('Catalogue · 37 collèges'), findsOneWidget);
      // Ordre : Cancérologie puis Pneumologie (alphabétique), puis le catalogue.
      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(y('Cancérologie'), lessThan(y('Pneumologie')));
      expect(y('Pneumologie'), lessThan(y('Catalogue · 37 collèges')));
      expect(y('Catalogue · 37 collèges'), lessThan(y('Anatomie pathologique')));
      expect(find.text('Importer'), findsNWidgets(37));
    });

    testWidgets('sous-titre : éditeur, fiches, maîtrise ; « à découvrir » avant tout drill', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _Fixed([_cancero, _pneumo])));
      await tester.pumpAndSettle();
      expect(find.text('CNEC · 177 fiches · 42 % maîtrisées'), findsOneWidget);
      expect(find.text('CEP · 164 fiches · à découvrir'), findsOneWidget);
      expect(find.byType(CgRankBar), findsNWidgets(2));
    });

    testWidgets('envoi repris en cours : le collège est dans « Mes collèges » avec l’envoi (pas « Importer »)',
        (tester) async {
      _phone(tester, height: 3000);
      _Uploading.value = const ImportUploading(refId: 12, progress: 0.42);
      addTearDown(() => _Uploading.value = const ImportIdle());
      final visited = <String>[];
      await tester.pumpWidget(_app(() => _Fixed(const []), visited: visited));
      await tester.pumpAndSettle();
      expect(find.text('SFH · envoi 42 %, reprend tout seul'), findsOneWidget);
      expect(find.text('Catalogue · 38 collèges'), findsOneWidget);
      expect(find.text('Importer'), findsNWidgets(38));
      await tester.tap(find.text('Hématologie'));
      await tester.pumpAndSettle();
      expect(visited, ['/colleges/12/import']);
    });

    testWidgets('import en cours et import échoué sont dits, sans barre', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _Fixed([_neuroEnCours, _dermatoEchoue])));
      await tester.pumpAndSettle();
      expect(find.text('CEN · import en cours, les fiches arrivent'), findsOneWidget);
      expect(find.text('CEDEF · l’import n’a pas abouti'), findsOneWidget);
      expect(find.byType(CgRankBar), findsNothing);
    });

    testWidgets('aucun collège : « Choisis un collège dans le catalogue »', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _Fixed(const [])));
      await tester.pumpAndSettle();
      expect(find.text('Choisis un collège dans le catalogue'), findsOneWidget);
      expect(find.text('Catalogue · 39 collèges'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('toucher un collège importé ouvre son détail', (tester) async {
      _phone(tester);
      final visited = <String>[];
      await tester.pumpWidget(_app(() => _Fixed([_cancero]), visited: visited));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancérologie'));
      await tester.pumpAndSettle();
      expect(visited, ['/colleges/3']);
    });

    testWidgets('« Importer » ouvre l’écran d’import du collège ; la ligne seule ne fait rien', (tester) async {
      _phone(tester);
      final visited = <String>[];
      await tester.pumpWidget(_app(() => _Fixed(const []), visited: visited));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anatomie pathologique'));
      await tester.pumpAndSettle();
      expect(visited, isEmpty);
      await tester.tap(find.text('Importer').first);
      await tester.pumpAndSettle();
      expect(visited, ['/colleges/1/import']);
    });

    testWidgets('le champ de recherche ouvre la recherche', (tester) async {
      _phone(tester);
      final visited = <String>[];
      await tester.pumpWidget(_app(() => _Fixed(const []), visited: visited));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Un item, un signe, une dose…'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchPanel), findsOneWidget, reason: 'sheet de recherche (8.10)');
    });
  });

  group('états', () {
    testWidgets('chargement : lignes squelettes', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_Loading.new));
      await tester.pump();
      expect(find.byType(CgSkeletonList), findsOneWidget);
    });

    testWidgets('réseau injoignable sans cache : état hors-ligne + Réessayer relance', (tester) async {
      _phone(tester);
      _Failing.builds = 0;
      await tester.pumpWidget(_app(() => _Failing(DioException(
            requestOptions: RequestOptions(path: '/v1/colleges'),
            type: DioExceptionType.connectionError,
          ))));
      await tester.pumpAndSettle();
      expect(find.text('Pas de connexion pour l’instant'), findsOneWidget);
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();
      expect(_Failing.builds, 2);
    });

    testWidgets('autre erreur : état d’erreur sans message technique', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _Failing(StateError('boom'))));
      await tester.pumpAndSettle();
      expect(find.text('La Bibliothèque n’a pas pu se charger'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
    });

    testWidgets('erreur serveur (500) sans cache : état d’erreur, pas « hors connexion »', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _Failing(DioException(
            requestOptions: RequestOptions(path: '/v1/colleges'),
            type: DioExceptionType.badResponse,
          ))));
      await tester.pumpAndSettle();
      expect(find.text('La Bibliothèque n’a pas pu se charger'), findsOneWidget);
      expect(find.text('Pas de connexion pour l’instant'), findsNothing);
    });

    testWidgets('« Réessayer » montre le squelette pendant la nouvelle tentative', (tester) async {
      _phone(tester);
      _FailThenHang.builds = 0;
      await tester.pumpWidget(_app(_FailThenHang.new));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Réessayer'));
      await tester.pump();
      expect(find.byType(CgSkeletonList), findsOneWidget);
      expect(find.text('Pas de connexion pour l’instant'), findsNothing);
    });

    testWidgets('hors connexion : le retour au premier plan retente le réseau', (tester) async {
      _phone(tester);
      _CountingOffline.builds = 0;
      await tester.pumpWidget(_app(_CountingOffline.new));
      await tester.pumpAndSettle();
      expect(_CountingOffline.builds, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(_CountingOffline.builds, 2);
    });

    testWidgets('liste servie par le cache : bandeau « Hors connexion »', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _Fixed([_cancero], offline: true)));
      await tester.pumpAndSettle();
      expect(find.text('Hors connexion'), findsOneWidget);
    });

    testWidgets('en ligne : pas de bandeau', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _Fixed([_cancero])));
      await tester.pumpAndSettle();
      expect(find.text('Hors connexion'), findsNothing);
    });
  });

  group('accessibilité', () {
    testWidgets('le champ de recherche est un bouton « Rechercher »', (tester) async {
      _phone(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(() => _Fixed(const [])));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(const Key('library-search'))),
        matchesSemantics(label: 'Rechercher un item, un signe, une dose', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('Dynamic Type 1,6 sur 375 : aucun débordement', (tester) async {
      _phone(tester, width: 375, height: 812);
      await tester.pumpWidget(_app(() => _Fixed([_cancero, _neuroEnCours]), textScale: 1.6));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    test('aucun widget Material ni shadcn', () {
      final src = File('lib/features/colleges/presentation/colleges_screen.dart').readAsStringSync();
      expect(src, isNot(contains('material.dart')));
      expect(src, isNot(contains('shadcn_ui')));
    });
  });

  group('goldens', () {
    for (final (name, notifier) in <(String, CollegesNotifier Function())>[
      ('mine', () => _Fixed([_cancero, _pneumo, _neuroEnCours])),
      ('empty', () => _Fixed(const [])),
      ('offline', () => _Fixed([_cancero], offline: true)),
    ]) {
      for (final width in cgGoldenWidths) {
        for (final scale in cgGoldenScales) {
          final tag = '${width.toInt()}_${scale.toString().replaceAll('.', '')}';
          testWidgets('golden library_${name}_$tag', (tester) async {
            _phone(tester, width: width, height: 1100);
            await tester.pumpWidget(_app(notifier, textScale: scale));
            await tester.pumpAndSettle();
            await expectLater(find.byType(CgGoldenFrame), matchesGoldenFile('goldens/library_${name}_$tag.png'));
          });
        }
      }
    }
  });
}

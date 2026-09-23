import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/planning/data/planning_repository.dart';
import 'package:collega_app/features/planning/planning_providers.dart';
import 'package:collega_app/features/planning/presentation/planning_screen.dart';
import 'package:collega_app/features/today/data/daily_session_repository.dart';

import '../../support/cg_golden.dart';

// Mercredi 23 septembre 2026 (modifiable par test).
var _now = DateTime(2026, 9, 23, 18);
int get _today => epochDayOf(_now);

const _cancero = UserCollegeStatus(
  refId: 3, collegeId: 'c3', status: 'generation_complete', cardCountA: 100, cardCountB: 50, cardCountC: 27,
);
const _pneumo = UserCollegeStatus(
  refId: 34, collegeId: 'c34', status: 'generation_complete', cardCountA: 100, cardCountB: 64, cardCountC: 0,
);
const _neuroEnCours = UserCollegeStatus(
  refId: 26, collegeId: 'c26', status: 'processing', cardCountA: 0, cardCountB: 0, cardCountC: 0,
);

class _Colleges extends CollegesNotifier {
  _Colleges(this.statuses, {this.error});
  final List<UserCollegeStatus> statuses;
  final Object? error;
  @override
  Future<List<CollegeListEntry>> build() async {
    if (error != null) throw error!;
    final byRef = {for (final s in statuses) s.refId: s};
    return [for (final c in kCollegeCatalog) CollegeListEntry(catalog: c, userStatus: byRef[c.refId])];
  }
}

PlanningConfig _config() => PlanningConfig(
      id: 'cfg',
      collegeIds: const ['c3'],
      startDate: DateTime(2026, 9, 21),
      endDate: DateTime(2026, 10, 20),
      dailyMinutes: 45,
      createdAt: DateTime.utc(2026, 9, 21),
    );

late AppDatabase _db;

Widget _app({
  List<UserCollegeStatus> statuses = const [_cancero, _pneumo],
  double textScale = 1,
  List<String>? visited,
  Object? collegesError,
}) {
  final router = GoRouter(
    initialLocation: '/start',
    routes: [
      GoRoute(path: '/start', builder: (_, __) => const _Start()),
      GoRoute(path: '/progress/planning', builder: (_, __) => const PlanningScreen()),
      GoRoute(path: '/colleges', builder: (_, __) {
        visited?.add('/colleges');
        return const SizedBox();
      }),
    ],
  );
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(_db),
      collegesProvider.overrideWith(() => _Colleges(statuses, error: collegesError)),
      planningClockProvider.overrideWithValue(() => _now),
    ],
    child: CgTheme(
      data: CgThemeData.light,
      child: WidgetsApp.router(
        debugShowCheckedModeBanner: false,
        color: CgColors.light.accent,
        routerConfig: router,
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: const [
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: true),
          child: CgGoldenFrame(child: child!),
        ),
      ),
    ),
  );
}

/// Pousse le planning (comme depuis Progression) : le retour a un parent.
class _Start extends StatefulWidget {
  const _Start();
  @override
  State<_Start> createState() => _StartState();
}

class _StartState extends State<_Start> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.push('/progress/planning'));
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

void _phone(WidgetTester tester, {double width = 393, double height = 1400}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

PlanningRepository _repo() => PlanningRepository(db: _db);

void main() {
  setUpAll(loadCgFonts);
  setUp(() {
    _now = DateTime(2026, 9, 23, 18);
    _db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => _db.close());

  group('formulaire', () {
    testWidgets('collèges prêts cochés par défaut ; aperçu vivant faisable', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(statuses: const [_cancero, _pneumo, _neuroEnCours]));
      await tester.pumpAndSettle();
      expect(find.text('Planifier'), findsWidgets);
      expect(find.text('Progression'), findsOneWidget, reason: '« ‹ Progression »');
      expect(find.text('Neurologie'), findsNothing, reason: 'import en cours : pas planifiable');
      expect(tester.widget<CgListRow>(find.widgetWithText(CgListRow, 'Cancérologie')).selected, isTrue);
      expect(tester.widget<CgListRow>(find.widgetWithText(CgListRow, 'Pneumologie')).selected, isTrue);
      expect(find.text('341 fiches · 30 jours · ~12 par jour'), findsOneWidget);
      expect(find.text('Faisable en 30 min par jour'), findsOneWidget);
    });

    testWidgets('décocher un collège recalcule l’aperçu ; aucun collège : bouton inactif', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pneumologie'));
      await tester.pumpAndSettle();
      expect(find.text('177 fiches · 30 jours · ~6 par jour'), findsOneWidget);
      await tester.tap(find.text('Cancérologie'));
      await tester.pumpAndSettle();
      expect(find.text('Choisis au moins un collège'), findsOneWidget);
      await tester.tap(find.widgetWithText(CgButton, 'Planifier'));
      await tester.pumpAndSettle();
      expect(await _repo().getActiveConfig(), isNull);
    });

    testWidgets('trop court : le dit avec le temps qu’il faudrait', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(statuses: const [
        UserCollegeStatus(refId: 3, collegeId: 'c3', status: 'generation_complete',
            cardCountA: 2000, cardCountB: 0, cardCountC: 0),
      ]));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15 min'));
      await tester.pumpAndSettle();
      expect(find.text('Trop court : 67 fiches par jour, ~56 min. Allonge la période ou le temps par jour.'),
          findsOneWidget);
    });

    testWidgets('dates : sélecteur iOS dans une sheet', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Examen'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsNothing);
      expect(find.text('22 oct.'), findsOneWidget);
    });

    testWidgets('« Planifier » enregistre puis montre le planning', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CgButton, 'Planifier'));
      await tester.pumpAndSettle();
      final saved = await _repo().getActiveConfig();
      expect(saved!.collegeIds.toSet(), {'c3', 'c34'});
      expect(saved.dailyMinutes, 30);
      expect(epochDayOf(saved.startDate), _today);
      expect(epochDayOf(saved.endDate), _today + 29);
      expect(find.text('23 sept. → 22 oct.'), findsOneWidget);
    });

    testWidgets('changement d’heure : 30 jours par défaut restent 30 jours (depuis le 1er oct.)', (tester) async {
      _phone(tester);
      _now = DateTime(2026, 10, 1, 9);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('30 oct.'), findsOneWidget);
      expect(find.text('341 fiches · 30 jours · ~12 par jour'), findsOneWidget);
    });

    testWidgets('réseau injoignable sans cache : état hors-ligne', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(
        collegesError: DioException(requestOptions: RequestOptions(path: '/c'), type: DioExceptionType.connectionError),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Pas de connexion pour l’instant'), findsOneWidget);
    });

    testWidgets('aucun collège prêt : état vide + Bibliothèque', (tester) async {
      _phone(tester);
      final visited = <String>[];
      await tester.pumpWidget(_app(statuses: const [_neuroEnCours], visited: visited));
      await tester.pumpAndSettle();
      expect(find.text('Importe un collège pour planifier'), findsOneWidget);
      await tester.tap(find.text('Aller à la Bibliothèque'));
      await tester.pumpAndSettle();
      expect(visited, ['/colleges']);
    });
  });

  group('vue du planning', () {
    testWidgets('période, résumé, collèges, calendrier lu par VoiceOver', (tester) async {
      _phone(tester, height: 1800);
      await _repo().replace(_config());
      final daily = DailySessionRepository(_db);
      await _db.into(_db.dailySessions).insert(DailySessionsCompanion.insert(
            day: Value(_today - 2), queueJson: '[]',
          ));
      await daily.complete(_today - 2);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('21 sept. → 20 oct.'), findsOneWidget);
      expect(find.text('45 min par jour · jour 3 sur 30'), findsOneWidget);
      expect(find.text('Cancérologie'), findsOneWidget);
      expect(find.bySemanticsLabel('lundi 21 septembre, session faite'), findsOneWidget);
      expect(find.bySemanticsLabel('mercredi 23 septembre, aujourd’hui'), findsOneWidget);
      expect(find.bySemanticsLabel('mardi 20 octobre, à venir'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('décaler aujourd’hui prolonge d’un jour ; annuler rétablit', (tester) async {
      _phone(tester, height: 1800);
      await _repo().replace(_config());
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Décaler aujourd’hui'));
      await tester.pumpAndSettle();
      expect(find.text('21 sept. → 21 oct.'), findsOneWidget);
      expect(find.text('45 min par jour · jour 3 sur 31 · aujourd’hui décalé'), findsOneWidget);
      await tester.tap(find.text('Annuler le décalage'));
      await tester.pumpAndSettle();
      expect(find.text('21 sept. → 20 oct.'), findsOneWidget);
    });

    testWidgets('session du jour déjà faite : rien à décaler', (tester) async {
      _phone(tester, height: 1800);
      await _repo().replace(_config());
      await _db.into(_db.dailySessions).insert(DailySessionsCompanion.insert(day: Value(_today), queueJson: '[]'));
      await DailySessionRepository(_db).complete(_today);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Décaler aujourd’hui'), findsNothing);
    });

    testWidgets('session du jour commencée : rien à décaler', (tester) async {
      _phone(tester, height: 1800);
      await _repo().replace(_config());
      await _db.into(_db.dailySessions).insert(DailySessionsCompanion.insert(
            day: Value(_today), queueJson: '["a"]', position: const Value(1)));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Décaler aujourd’hui'), findsNothing);
    });

    testWidgets('« Planifier à nouveau » puis « Annuler » : retour à la vue, rien de changé', (tester) async {
      _phone(tester, height: 1800);
      await _repo().replace(_config());
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planifier à nouveau'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('21 sept. → 20 oct.'), findsOneWidget);
      expect((await _repo().getActiveConfig())!.dailyMinutes, 45);
    });

    testWidgets('retour au premier plan après minuit : le calendrier suit le nouveau jour', (tester) async {
      _phone(tester, height: 1800);
      await _repo().replace(_config());
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      _now = DateTime(2026, 9, 24, 8);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('jeudi 24 septembre, aujourd’hui'), findsOneWidget);
      expect(find.text('45 min par jour · jour 4 sur 30'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('planning à cheval sur deux années : mois avec l’année', (tester) async {
      _phone(tester, height: 2600);
      await _repo().replace(PlanningConfig(
        id: 'cfg', collegeIds: const ['c3'], startDate: DateTime(2026, 12, 20), endDate: DateTime(2027, 1, 10),
        dailyMinutes: 30, createdAt: DateTime.utc(2026, 9, 21),
      ));
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('décembre 2026'), findsOneWidget);
      expect(find.text('janvier 2027'), findsOneWidget);
    });

    testWidgets('« Planifier à nouveau » : formulaire prérempli', (tester) async {
      _phone(tester, height: 1800);
      await _repo().replace(_config());
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planifier à nouveau'));
      await tester.pumpAndSettle();
      expect(tester.widget<CgListRow>(find.widgetWithText(CgListRow, 'Cancérologie')).selected, isTrue);
      expect(tester.widget<CgListRow>(find.widgetWithText(CgListRow, 'Pneumologie')).selected, isFalse);
      expect(tester.widget<CgSegmented<int>>(find.byType(CgSegmented<int>)).selected, 45);
      expect(find.text('20 oct.'), findsOneWidget);
    });

    testWidgets('supprimer : action sheet, confirmation écrite, puis formulaire', (tester) async {
      _phone(tester, height: 1800);
      await _repo().replace(_config());
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Plus d’actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer le planning'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tes fiches et ta progression restent.'), findsOneWidget);
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      expect(await _repo().getActiveConfig(), isNull);
      expect(find.text('Faisable en 30 min par jour'), findsOneWidget);
    });
  });

  group('accessibilité', () {
    testWidgets('Dynamic Type 1,6 sur 375 : formulaire et vue sans débordement', (tester) async {
      _phone(tester, width: 375, height: 2400);
      await tester.pumpWidget(_app(textScale: 1.6));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(CgButton, 'Planifier'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    test('aucun widget Material ni shadcn', () {
      final src = File('lib/features/planning/presentation/planning_screen.dart').readAsStringSync();
      expect(src, isNot(contains('material.dart')));
      expect(src, isNot(contains('shadcn_ui')));
    });
  });

  group('goldens', () {
    for (final (name, planned) in [('form', false), ('view', true)]) {
      for (final width in cgGoldenWidths) {
        for (final scale in cgGoldenScales) {
          final tag = '${width.toInt()}_${scale.toString().replaceAll('.', '')}';
          testWidgets('golden planning_${name}_$tag', (tester) async {
            _phone(tester, width: width, height: 1700);
            if (planned) await _repo().replace(_config());
            await tester.pumpWidget(_app(textScale: scale));
            await tester.pumpAndSettle();
            await expectLater(find.byType(CgGoldenFrame), matchesGoldenFile('goldens/planning_${name}_$tag.png'));
          });
        }
      }
    }
  });
}

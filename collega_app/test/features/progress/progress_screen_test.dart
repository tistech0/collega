import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/features/colleges/domain/college_icons.dart';
import 'package:collega_app/features/colleges/domain/drill_stats.dart';
import 'package:collega_app/features/planning/planning_providers.dart';
import 'package:collega_app/features/progress/progress_providers.dart';
import 'package:collega_app/features/progress/progress_screen.dart';

import '../../support/cg_golden.dart';

// Mercredi 23 septembre 2026.
final _now = DateTime(2026, 9, 23, 18);
final _today = epochDayOf(_now);

List<ProgressDay> _week(List<int> counts) => [
      for (var i = 0; i < 7; i++)
        ProgressDay(date: DateTime(2026, 9, 21 + i), count: counts[i], isToday: i == 2),
    ];

PlanningConfig _config() => PlanningConfig(
      id: 'cfg',
      collegeIds: const ['c3', 'c34'],
      startDate: DateTime(2026, 9, 21),
      endDate: DateTime(2026, 10, 20),
      dailyMinutes: 30,
      createdAt: DateTime.utc(2026, 9, 21),
    );

ProgressReady _ready({
  bool fresh = false,
  PlanningConfig? planning,
  Set<int> postponed = const {},
}) {
  const cancero = DrillStats(maitrise: 74, bien: 25, aRevoir: 11, notSeen: 67);
  const pneumo = DrillStats(maitrise: 30, bien: 15, aRevoir: 6, notSeen: 113);
  final colleges = fresh
      ? const [
          ProgressCollege(refId: 3, collegeId: 'c3', name: 'Cancérologie', icon: CollegeIcons.cancer,
              stats: DrillStats(notSeen: 177)),
          ProgressCollege(refId: 34, collegeId: 'c34', name: 'Pneumologie', icon: CollegeIcons.lungs,
              stats: DrillStats(notSeen: 164)),
        ]
      : const [
          ProgressCollege(refId: 3, collegeId: 'c3', name: 'Cancérologie', icon: CollegeIcons.cancer, stats: cancero),
          ProgressCollege(refId: 34, collegeId: 'c34', name: 'Pneumologie', icon: CollegeIcons.lungs, stats: pneumo),
        ];
  return ProgressReady(
    overall: fresh
        ? const DrillStats(notSeen: 341)
        : const DrillStats(maitrise: 104, bien: 40, aRevoir: 17, notSeen: 180),
    colleges: colleges,
    byRang: fresh
        ? const {'A': DrillStats(notSeen: 216), 'B': DrillStats(notSeen: 125)}
        : const {
            'A': DrillStats(maitrise: 104, bien: 35, aRevoir: 15, notSeen: 62),
            'B': DrillStats(bien: 5, aRevoir: 2, notSeen: 83),
            'C': DrillStats(notSeen: 35),
          },
    week: _week(fresh ? [0, 0, 0, 0, 0, 0, 0] : [24, 30, 18, 0, 0, 0, 0]),
    planning: PlanningState(config: planning, postponedDays: postponed, today: _today),
  );
}

Widget _app(Stream<ProgressState> Function() state, {List<String>? visited, double textScale = 1}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const ProgressScreen()),
    for (final path in ['/colleges', '/progress/colleges/:ref', '/progress/planning'])
      GoRoute(path: path, builder: (_, s) {
        visited?.add(s.uri.path);
        return const SizedBox();
      }),
  ]);
  return ProviderScope(
    overrides: [
      progressProvider.overrideWith((ref) => state()),
      progressClockProvider.overrideWithValue(() => _now),
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

Stream<ProgressState> _value(ProgressState s) => Stream.value(s);

void _phone(WidgetTester tester, {double width = 393, double height = 1600}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(loadCgFonts);

  group('tête', () {
    testWidgets('valeur en large title : « 30 % » (104 sur 341) de tes 341 fiches, barre 22 pt + légende', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _value(_ready())));
      await tester.pumpAndSettle();
      expect(find.text('30 %'), findsWidgets);
      expect(find.text('de tes 341 fiches sont maîtrisées'), findsOneWidget);
      final bar = tester.widget<CgRankBar>(find.byWidgetPredicate((w) => w is CgRankBar && w.legend));
      expect(bar.size, CgRankBarSize.hero);
      expect([bar.mastered, bar.good, bar.review, bar.unseen], [104, 40, 17, 180]);
    });

    testWidgets('rien révisé : jamais « 0 % », « 341 fiches à découvrir »', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _value(_ready(fresh: true))));
      await tester.pumpAndSettle();
      expect(find.text('341 fiches'), findsWidgets);
      expect(find.text('à découvrir · ta première session remplira cette page'), findsOneWidget);
      expect(find.textContaining('0 %'), findsNothing);
    });
  });

  group('semaine', () {
    testWidgets('« Cette semaine · 72 fiches », 7 jours lus par VoiceOver', (tester) async {
      _phone(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(() => _value(_ready())));
      await tester.pumpAndSettle();
      expect(find.text('Cette semaine · 72 fiches'), findsOneWidget);
      expect(find.bySemanticsLabel('lundi, 24 fiches'), findsOneWidget);
      expect(find.bySemanticsLabel('mercredi, aujourd’hui, 18 fiches'), findsOneWidget);
      expect(find.bySemanticsLabel('jeudi, aucune fiche'), findsOneWidget);
      handle.dispose();
    });
  });

  group('par collège et par rang', () {
    testWidgets('anneau, « 177 fiches · 74 maîtrisées », tap → détail sous Progression', (tester) async {
      _phone(tester);
      final visited = <String>[];
      await tester.pumpWidget(_app(() => _value(_ready()), visited: visited));
      await tester.pumpAndSettle();
      expect(find.byType(CgRing), findsNWidgets(2));
      expect(find.text('177 fiches · 74 maîtrisées'), findsOneWidget);
      await tester.tap(find.text('Cancérologie'));
      await tester.pumpAndSettle();
      expect(visited, ['/progress/colleges/3']);
    });

    testWidgets('collège neuf : « 164 fiches à découvrir »', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _value(_ready(fresh: true))));
      await tester.pumpAndSettle();
      expect(find.text('164 fiches à découvrir'), findsOneWidget);
    });

    testWidgets('rangs : badge, barre, part maîtrisée ; rang sans fiche absent', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _value(_ready(fresh: true))));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is CgBadge), findsNWidgets(2));
      expect(find.text('0 % maîtrisées'), findsNothing);
    });

    testWidgets('rang A : « 48 % » (104 sur 216)', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _value(_ready())));
      await tester.pumpAndSettle();
      expect(find.text('48 %'), findsOneWidget);
    });
  });

  group('planning', () {
    testWidgets('sans planning : « Planifier tes révisions » → Planning', (tester) async {
      _phone(tester);
      final visited = <String>[];
      await tester.pumpWidget(_app(() => _value(_ready()), visited: visited));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planifier tes révisions'));
      await tester.pumpAndSettle();
      expect(visited, ['/progress/planning']);
    });

    testWidgets('avec planning : période, minutes, jour N sur M', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _value(_ready(planning: _config()))));
      await tester.pumpAndSettle();
      expect(find.text('21 sept. → 20 oct.'), findsOneWidget);
      expect(find.text('30 min par jour · jour 3 sur 30'), findsOneWidget);
    });

    testWidgets('jour décalé : dit', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _value(_ready(planning: _config(), postponed: {_today}))));
      await tester.pumpAndSettle();
      expect(find.text('30 min par jour · jour 3 sur 30 · aujourd’hui décalé'), findsOneWidget);
    });
  });

  group('états', () {
    testWidgets('aucun collège prêt : état vide + Bibliothèque', (tester) async {
      _phone(tester);
      final visited = <String>[];
      await tester.pumpWidget(_app(() => _value(const ProgressEmpty()), visited: visited));
      await tester.pumpAndSettle();
      expect(find.text('Ta première session remplira cette page'), findsOneWidget);
      await tester.tap(find.text('Aller à la Bibliothèque'));
      await tester.pumpAndSettle();
      expect(visited, ['/colleges']);
    });

    testWidgets('chargement : anneaux squelettes', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => StreamController<ProgressState>().stream));
      await tester.pump();
      expect(find.byWidgetPredicate((w) => w is CgSkeleton), findsWidgets);
    });

    testWidgets('réseau injoignable sans cache : hors-ligne', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => Stream.error(DioException(
            requestOptions: RequestOptions(path: '/v1/colleges'),
            type: DioExceptionType.connectionError,
          ))));
      await tester.pumpAndSettle();
      expect(find.text('Pas de connexion pour l’instant'), findsOneWidget);
    });

    testWidgets('autre erreur : état d’erreur, sans détail technique', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => Stream.error(StateError('boom'))));
      await tester.pumpAndSettle();
      expect(find.text('Ta progression n’a pas pu se charger'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
    });
  });

  group('accessibilité', () {
    testWidgets('accessibilité : cibles étiquetées, 44 pt, contraste du texte (8.15)', (tester) async {
      final handle = tester.ensureSemantics();
      _phone(tester);
      await tester.pumpWidget(_app(() => _value(_ready(planning: _config()))));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('Dynamic Type 1,6 sur 375 : aucun débordement', (tester) async {
      _phone(tester, width: 375, height: 1800);
      await tester.pumpWidget(_app(() => _value(_ready(planning: _config())), textScale: 1.6));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    test('aucun widget Material ni shadcn', () {
      final src = File('lib/features/progress/progress_screen.dart').readAsStringSync();
      expect(src, isNot(contains('material.dart')));
      expect(src, isNot(contains('shadcn_ui')));
    });
  });

  group('goldens', () {
    for (final (name, state) in <(String, ProgressState)>[
      ('ready', _ready(planning: _config())),
      ('fresh', _ready(fresh: true)),
      ('empty', const ProgressEmpty()),
    ]) {
      for (final width in cgGoldenWidths) {
        for (final scale in cgGoldenScales) {
          final tag = '${width.toInt()}_${scale.toString().replaceAll('.', '')}';
          testWidgets('golden progress_${name}_$tag', (tester) async {
            _phone(tester, width: width, height: 1500);
            await tester.pumpWidget(_app(() => _value(state), textScale: scale));
            await tester.pumpAndSettle();
            await expectLater(find.byType(CgGoldenFrame), matchesGoldenFile('goldens/progress_${name}_$tag.png'));
          });
        }
      }
    }
  });
}

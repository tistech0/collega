import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/features/colleges/domain/drill_stats.dart';
import 'package:collega_app/features/today/data/daily_session_repository.dart';
import 'package:collega_app/features/today/presentation/today_screen.dart';
import 'package:collega_app/features/today/today_providers.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';
import 'package:collega_app/features/profile/profile_providers.dart';

import 'package:collega_app/features/search/presentation/search_sheet.dart';

import '../../support/cg_golden.dart';

final _date = DateTime(2026, 9, 21, 20); // lundi 21 septembre
final _day = epochDayOf(_date);

List<TodayWeekDay> _week({Set<int> done = const {}}) => [
      for (var i = 0; i < 7; i++)
        TodayWeekDay(date: DateTime(2026, 9, 21 + i), done: done.contains(i), isToday: i == 0),
    ];

TodayReady _ready({
  int position = 0,
  bool completed = false,
  int cardCount = 24,
  int toReview = 6,
  Map<String, int> verdicts = const {},
  int? planningDay = 1,
  bool postponedToday = false,
}) =>
    TodayReady(
      date: _date,
      session: DailySession(
        day: _day,
        cardIds: [for (var i = 0; i < cardCount; i++) 'c$i'],
        position: position,
        startedAt: position > 0 || completed ? _date : null,
        completedAt: completed ? _date : null,
      ),
      cardCount: cardCount,
      toReview: toReview,
      mix: const [
        TodayMix(collegeName: 'Cancérologie', count: 16, rangs: ['A']),
        TodayMix(collegeName: 'Pneumologie', count: 8, rangs: ['A', 'B']),
      ],
      week: _week(done: completed ? {0} : {}),
      colleges: const [
        TodayCollege(refId: 3, collegeId: 'c3', name: 'Cancérologie',
            stats: DrillStats(maitrise: 74, bien: 25, aRevoir: 11, notSeen: 67)),
        TodayCollege(refId: 34, collegeId: 'c34', name: 'Pneumologie',
            stats: DrillStats(notSeen: 164)),
      ],
      verdicts: verdicts,
      budget: 24,
      sessionCollegeIds: const {'c3', 'c34'},
      planningDay: planningDay,
      planningDays: planningDay == null ? null : 30,
      postponedToday: postponedToday,
    );

class _Prefs extends RevisionPrefsNotifier {
  @override
  Future<RevisionPrefs> build() async => const RevisionPrefs();
}

class _Fixed extends TodayNotifier {
  _Fixed(this.value);
  final TodayState value;
  @override
  Future<TodayState> build() async => value;
}

class _Counting extends TodayNotifier {
  _Counting(this.value);
  final TodayState value;
  static int builds = 0;
  @override
  Future<TodayState> build() async {
    builds++;
    return value;
  }
}

class _Loading extends TodayNotifier {
  @override
  Future<TodayState> build() => Completer<TodayState>().future;
}

class _Failing extends TodayNotifier {
  @override
  Future<TodayState> build() async => throw StateError('réseau');
}

Widget _app(TodayNotifier Function() notifier, {List<String>? visited, double textScale = 1}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => TodayScreen(now: () => _date)),
    GoRoute(path: '/colleges', builder: (_, __) { visited?.add('/colleges'); return const SizedBox(); }),
    GoRoute(path: '/home/colleges/:ref', builder: (_, s) { visited?.add('/home/colleges/${s.pathParameters['ref']}'); return const SizedBox(); }),
    GoRoute(path: '/drill', builder: (_, s) { visited?.add('/drill'); return const SizedBox(); }),
  ]);
  return ProviderScope(
    overrides: [
      todayProvider.overrideWith(notifier),
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

void _phone(WidgetTester tester, {double width = 393, double height = 852}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(loadCgFonts);

  group('en-tête', () {
    testWidgets('large title daté « Lundi 21 » + « septembre · jour 1 sur 30 du planning »', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _Fixed(_ready())));
      await tester.pumpAndSettle();
      expect(find.text('Lundi 21'), findsWidgets);
      expect(find.text('septembre · jour 1 sur 30 du planning'), findsOneWidget);
    });

    testWidgets('sans planning : « septembre »', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _Fixed(_ready(planningDay: null))));
      await tester.pumpAndSettle();
      expect(find.text('septembre'), findsOneWidget);
    });

    testWidgets('loupe → recherche', (tester) async {
      _phone(tester);
      final handle = tester.ensureSemantics();
      final visited = <String>[];
      await tester.pumpWidget(_app(() => _Fixed(_ready()), visited: visited));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Rechercher'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchPanel), findsOneWidget, reason: 'sheet de recherche (8.10)');
      handle.dispose();
    });
  });

  group('session prête', () {
    testWidgets('grand nombre, minutes, répartition, à revoir, un seul primaire « Commencer »', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _Fixed(_ready())));
      await tester.pumpAndSettle();
      expect(find.text('24'), findsOneWidget);
      expect(find.text('fiches · 20 min'), findsOneWidget);
      expect(find.text('Cancérologie'), findsWidgets);
      expect(find.text('16 · rang A'), findsOneWidget);
      expect(find.text('8 · rangs A–B'), findsOneWidget);
      expect(find.text('dont à revoir'), findsOneWidget);
      final primaries = tester.widgetList<CgButton>(find.byType(CgButton))
          .where((b) => b.variant == CgButtonVariant.primary);
      expect(primaries.map((b) => b.label), ['Commencer']);
      expect(find.text('Personnaliser la session'), findsOneWidget);
    });

    testWidgets('« Commencer » lance le drill de la session du jour', (tester) async {
      _phone(tester);
      final visited = <String>[];
      await tester.pumpWidget(_app(() => _Fixed(_ready()), visited: visited));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();
      expect(visited, ['/drill']);
    });

    testWidgets('répartition : 3 collèges max puis « et N autres »', (tester) async {
      _phone(tester);
      final many = TodayReady(
        date: _date,
        session: DailySession(day: _day, cardIds: const ['a'], position: 0),
        cardCount: 5,
        toReview: 0,
        mix: const [
          TodayMix(collegeName: 'Anatomie', count: 1, rangs: ['A']),
          TodayMix(collegeName: 'Biologie', count: 1, rangs: ['A']),
          TodayMix(collegeName: 'Cardiologie', count: 1, rangs: ['A']),
          TodayMix(collegeName: 'Dermatologie', count: 1, rangs: ['A']),
          TodayMix(collegeName: 'Endocrinologie', count: 1, rangs: ['A']),
        ],
        week: _week(),
        colleges: const [],
        verdicts: const {},
        budget: 24,
        sessionCollegeIds: const {'c3'},
      );
      await tester.pumpWidget(_app(() => _Fixed(many)));
      await tester.pumpAndSettle();
      expect(find.text('et 2 autres'), findsOneWidget);
      expect(find.text('Dermatologie'), findsNothing);
      expect(find.text('dont à revoir'), findsNothing, reason: 'masqué à 0');
    });
  });

  group('session commencée / faite', () {
    testWidgets('commencée : « 12 sur 24 » + « Reprendre », plus de Personnaliser', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _Fixed(_ready(position: 12))));
      await tester.pumpAndSettle();
      expect(find.text('12'), findsOneWidget);
      expect(find.text('sur 24 fiches'), findsOneWidget);
      expect(find.text('Reprendre'), findsOneWidget);
      expect(find.text('Commencer'), findsNothing);
      expect(find.text('Personnaliser la session'), findsNothing);
    });

    testWidgets('faite : « Session faite », verdicts du jour, prochaine session, aucun bouton « terminée »', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _Fixed(_ready(completed: true, verdicts: {'maitrise': 18, 'bien': 4, 'a_revoir': 2}))));
      await tester.pumpAndSettle();
      expect(find.text('Session faite'), findsOneWidget);
      expect(find.textContaining('18 maîtrisées'), findsWidgets);
      expect(find.text('Prochaine session demain'), findsOneWidget);
      expect(find.textContaining('terminée'), findsNothing);
      expect(find.text('Commencer'), findsNothing);
    });

    testWidgets('rien à réviser : message calme, pas de bouton primaire', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _Fixed(_ready(cardCount: 0, toReview: 0))));
      await tester.pumpAndSettle();
      expect(find.text('Tout est à jour'), findsOneWidget);
      expect(find.text('Commencer'), findsNothing);
    });
  });

  group('semaine et collèges', () {
    testWidgets('7 pastilles, lues par VoiceOver avec leur état', (tester) async {
      _phone(tester, height: 1400);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(() => _Fixed(_ready(completed: true))));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('lundi, aujourd’hui, session faite'), findsOneWidget);
      expect(find.bySemanticsLabel('mardi'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('mes collèges : progression chiffrée, collège neuf « à découvrir », tap → détail', (tester) async {
      _phone(tester, height: 1400);
      final visited = <String>[];
      await tester.pumpWidget(_app(() => _Fixed(_ready()), visited: visited));
      await tester.pumpAndSettle();
      expect(find.text('177 fiches · 42\u202F% maîtrisées'), findsOneWidget);
      expect(find.text('164 fiches à découvrir'), findsOneWidget);
      await tester.tap(find.text('Pneumologie').last);
      await tester.pumpAndSettle();
      expect(visited, ['/home/colleges/34']);
    });
  });

  group('quatre états', () {
    testWidgets('vide : « Importe ton premier collège » → Bibliothèque', (tester) async {
      _phone(tester);
      final visited = <String>[];
      await tester.pumpWidget(_app(() => _Fixed(const TodayNoCollege()), visited: visited));
      await tester.pumpAndSettle();
      expect(find.text('Importe ton premier collège'), findsOneWidget);
      await tester.tap(find.text('Aller à la Bibliothèque'));
      await tester.pumpAndSettle();
      expect(visited, ['/colleges']);
    });

    testWidgets('en préparation : pas d’action, le collège nommé', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _Fixed(const TodayPreparing(collegeName: 'Cancérologie'))));
      await tester.pumpAndSettle();
      expect(find.text('Ton premier collège est en préparation'), findsOneWidget);
      expect(find.textContaining('Cancérologie'), findsOneWidget);
    });

    testWidgets('chargement : skeleton, jamais de spinner', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_Loading.new));
      await tester.pump();
      expect(find.byType(CgSkeleton), findsWidgets);
    });

    testWidgets('erreur : rassure, explique, propose — sans message technique', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(_Failing.new));
      await tester.pumpAndSettle();
      expect(find.byType(CgState), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('StateError'), findsNothing);
      expect(find.textContaining('réseau'), findsNothing);
    });
  });

  testWidgets('session d’un autre jour (app restée ouverte après minuit) : recalcul', (tester) async {
    _phone(tester);
    _Counting.builds = 0;
    final yesterday = TodayReady(
      date: _date.subtract(const Duration(days: 1)),
      session: DailySession(day: _day - 1, cardIds: const ['a'], position: 0, completedAt: _date),
      cardCount: 1, toReview: 0, mix: const [], week: _week(), colleges: const [],
      verdicts: const {}, budget: 24, sessionCollegeIds: const {},
    );
    await tester.pumpWidget(_app(() => _Counting(yesterday)));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(_Counting.builds, greaterThanOrEqualTo(2));
  });

  testWidgets('retour au premier plan : recalcul si le jour a changé', (tester) async {
    _phone(tester);
    _Counting.builds = 0;
    await tester.pumpWidget(_app(() => _Counting(_ready())));
    await tester.pumpAndSettle();
    final before = _Counting.builds;
    for (final st in [
      AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused,
      AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(st);
    }
    await tester.pumpAndSettle();
    expect(_Counting.builds, before, reason: 'même jour : pas de recalcul inutile');
  });

  testWidgets('jour décalé (8.9) : « Session décalée à demain » + « Réviser quand même »', (tester) async {
    _phone(tester);
    final visited = <String>[];
    await tester.pumpWidget(_app(() => _Fixed(_ready(postponedToday: true)), visited: visited));
    await tester.pumpAndSettle();
    expect(find.text('Session décalée à demain'), findsOneWidget);
    expect(find.text('Commencer'), findsNothing);
    await tester.tap(find.text('Réviser quand même'));
    await tester.pumpAndSettle();
    expect(visited, ['/drill']);
  });

  testWidgets('jour décalé mais session déjà commencée : « Reprendre » reste', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(() => _Fixed(_ready(postponedToday: true, position: 5))));
    await tester.pumpAndSettle();
    expect(find.text('Reprendre'), findsOneWidget);
    expect(find.text('Session décalée à demain'), findsNothing);
  });

  for (final (name, state) in <(String, TodayState)>[
    ('prête', _ready()),
    ('commencée', _ready(position: 12)),
    ('faite', _ready(completed: true, verdicts: {'maitrise': 18, 'bien': 4, 'a_revoir': 2})),
    ('vide', const TodayNoCollege()),
  ]) {
    testWidgets('accessibilité ($name) : cibles étiquetées, 44 pt, contraste du texte (8.15)', (tester) async {
      final handle = tester.ensureSemantics();
      _phone(tester, height: 1100);
      await tester.pumpWidget(_app(() => _Fixed(state)));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }

  testWidgets('Dynamic Type 1,6 sur 375 : aucun débordement', (tester) async {
    _phone(tester, width: 375, height: 812);
    await tester.pumpWidget(_app(() => _Fixed(_ready()), textScale: 1.6));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('goldens', () {
    for (final (name, state) in <(String, TodayState)>[
      ('ready', _ready()),
      ('started', _ready(position: 12)),
      ('done', _ready(completed: true, verdicts: {'maitrise': 18, 'bien': 4, 'a_revoir': 2})),
      ('empty', const TodayNoCollege()),
    ]) {
      for (final width in cgGoldenWidths) {
        for (final scale in cgGoldenScales) {
          final tag = '${width.toInt()}_${scale.toString().replaceAll('.', '')}';
          testWidgets('golden today_${name}_$tag', (tester) async {
            _phone(tester, width: width, height: 1100);
            await tester.pumpWidget(_app(() => _Fixed(state), textScale: scale));
            await tester.pumpAndSettle();
            await expectLater(find.byType(CgGoldenFrame), matchesGoldenFile('goldens/today_${name}_$tag.png'));
          });
        }
      }
    }
  });
}

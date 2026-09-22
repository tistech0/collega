import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/features/colleges/data/college_cards_sync.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/domain/drill_stats.dart';
import 'package:collega_app/features/today/data/daily_session_repository.dart';
import 'package:collega_app/features/today/domain/daily_session_builder.dart';
import 'package:collega_app/features/today/presentation/today_customize_sheet.dart';
import 'package:collega_app/features/today/today_providers.dart';

import '../../support/cg_golden.dart';

FlashCardModel _card(String id, String college, String rang) => FlashCardModel(
      id: id, itemId: 'i', collegeId: college, cardType: 'classique', rang: rang,
      recto: 'Q', verso: 'R', ocrConfidenceScore: 0.9, lowConfidence: false,
    );

class _Spy extends TodayNotifier {
  _Spy(this.state0, {this.fail = false});
  final TodayReady state0;
  final bool fail;
  final calls = <Map<String, Object?>>[];

  @override
  Future<TodayState> build() async => state0;

  @override
  Future<void> customize({
    Set<String>? collegeIds,
    Set<String>? rangs,
    SessionStatusFilter status = SessionStatusFilter.all,
    int? maxCards,
  }) async {
    calls.add({'colleges': collegeIds, 'rangs': rangs, 'status': status, 'max': maxCards});
    if (fail) throw StateError('La session du jour est commencée');
  }
}

void main() {
  late AppDatabase db;
  final today = epochDayOf(DateTime.now());

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await syncCollegeCards(db, 'c3', [for (var i = 0; i < 10; i++) _card('a$i', 'c3', i < 6 ? 'A' : 'B')]);
    await syncCollegeCards(db, 'c34', [for (var i = 0; i < 4; i++) _card('p$i', 'c34', 'A')]);
  });
  tearDown(() => db.close());

  final ready = TodayReady(
    date: DateTime.now(),
    session: DailySession(day: today, cardIds: const ['a0'], position: 0),
    cardCount: 14,
    toReview: 0,
    mix: const [],
    week: const [],
    colleges: const [
      TodayCollege(refId: 3, collegeId: 'c3', name: 'Cancérologie', stats: DrillStats(notSeen: 10)),
      TodayCollege(refId: 34, collegeId: 'c34', name: 'Pneumologie', stats: DrillStats(notSeen: 4)),
    ],
    verdicts: const {},
    budget: 24,
    sessionCollegeIds: const {'c3', 'c34'},
  );

  Future<_Spy> pump(WidgetTester tester, {TodayReady? state, bool fail = false}) async {
    tester.view.physicalSize = const Size(393, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final spy = _Spy(state ?? ready, fail: fail);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        dailySessionRepositoryProvider.overrideWithValue(DailySessionRepository(db)),
        todayProvider.overrideWith(() => spy),
      ],
      child: cgTestApp(TodayCustomizePanel(state: state ?? ready), disableAnimations: true),
    ));
    await tester.pumpAndSettle();
    return spy;
  }

  testWidgets('collèges cochés par défaut, aperçu vivant « 14 fiches · 12 min »', (tester) async {
    await pump(tester);
    expect(find.text('Cancérologie'), findsOneWidget);
    expect(find.text('Pneumologie'), findsOneWidget);
    expect(find.text('14 fiches · 12 min'), findsOneWidget);
  });

  testWidgets('décocher un collège et choisir Rang A : l’aperçu suit', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Pneumologie'));
    await tester.pumpAndSettle();
    expect(find.text('10 fiches · 9 min'), findsOneWidget);
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(find.text('6 fiches · 5 min'), findsOneWidget);
  });

  testWidgets('« Enregistrer » transmet les réglages', (tester) async {
    final spy = await pump(tester);
    await tester.tap(find.text('Pneumologie'));
    await tester.tap(find.text('Non vues'));
    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(spy.calls.single['colleges'], {'c3'});
    expect(spy.calls.single['status'], SessionStatusFilter.unseen);
    expect(spy.calls.single['max'], 12);
  });

  testWidgets('aucun collège coché : « Enregistrer » désactivé, aperçu à 0', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Cancérologie'));
    await tester.tap(find.text('Pneumologie'));
    await tester.pumpAndSettle();
    final save = tester.widget<CgButton>(find.widgetWithText(CgButton, 'Enregistrer'));
    expect(save.onPressed, isNull);
    expect(find.text('Aucune fiche avec ces réglages'), findsOneWidget);
  });

  testWidgets('présélection : les collèges de la session (planning), pas tous les collèges prêts', (tester) async {
    await pump(tester, state: TodayReady(
      date: ready.date, session: ready.session, cardCount: 10, toReview: 0, mix: const [], week: const [],
      colleges: ready.colleges, verdicts: const {}, budget: 24, sessionCollegeIds: const {'c3'},
    ));
    expect(find.text('10 fiches · 9 min'), findsOneWidget);
  });

  testWidgets('réglages déjà personnalisés : rang et statut repris', (tester) async {
    await pump(tester, state: TodayReady(
      date: ready.date,
      session: DailySession(
        day: today, cardIds: const ['a0'], position: 0,
        settings: const DailySessionSettings(budget: 12, collegeIds: {'c3'}, rangs: {'A'}),
      ),
      cardCount: 6, toReview: 0, mix: const [], week: const [],
      colleges: ready.colleges, verdicts: const {}, budget: 12, sessionCollegeIds: const {'c3'},
    ));
    expect(find.text('6 fiches · 5 min'), findsOneWidget);
  });

  testWidgets('échec de l’enregistrement : message clair, bouton de nouveau actif', (tester) async {
    await pump(tester, fail: true);
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ta session est déjà commencée : elle ne se personnalise plus.'), findsOneWidget);
    final save = tester.widget<CgButton>(find.widgetWithText(CgButton, 'Enregistrer'));
    expect(save.loading, isFalse);
    await tester.pump(const Duration(seconds: 3));
  });
}

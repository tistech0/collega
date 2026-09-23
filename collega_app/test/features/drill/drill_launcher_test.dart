import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/drill_launcher.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';
import 'package:collega_app/features/profile/profile_providers.dart';

import '../../support/cg_golden.dart';

class _Prefs extends RevisionPrefsNotifier {
  _Prefs(this.prefs);
  final RevisionPrefs prefs;
  @override
  Future<RevisionPrefs> build() async => prefs;
}

/// Story 8.4 — lancement du drill et choix du chronomètre (mode « Demander »).
void main() {
  late List<DrillLaunch> launched;
  const params = DrillSessionParams(collegeId: 'c3');

  Widget app(RevisionPrefs prefs) {
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Consumer(
          builder: (context, ref, _) => Center(
            child: CgButton(label: 'Commencer', onPressed: () => launchDrill(context, ref, params)),
          ),
        ),
      ),
      GoRoute(path: '/drill', builder: (_, s) {
        launched.add(s.extra! as DrillLaunch);
        return const SizedBox();
      }),
    ]);
    return ProviderScope(
      overrides: [revisionPrefsProvider.overrideWith(() => _Prefs(prefs))],
      child: CgTheme(
        data: CgThemeData.light,
        child: WidgetsApp.router(color: CgColors.light.accent, routerConfig: router, builder: (c, child) => CgGoldenFrame(child: child!)),
      ),
    );
  }

  setUp(() => launched = []);

  testWidgets('chrono désactivé : lance directement, sans chrono', (tester) async {
    await tester.pumpWidget(app(const RevisionPrefs()));
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(launched.single.timerOn, isFalse);
    expect(launched.single.params, params);
  });

  testWidgets('chrono activé : lance directement, avec chrono', (tester) async {
    await tester.pumpWidget(app(const RevisionPrefs(timerMode: TimerMode.on)));
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(launched.single.timerOn, isTrue);
  });

  testWidgets('« Demander » : la sheet propose avec / sans chrono', (tester) async {
    await tester.pumpWidget(app(const RevisionPrefs(timerMode: TimerMode.ask, timerDurationSeconds: 45)));
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    expect(find.text('Avec chrono · 45 s'), findsOneWidget);
    await tester.tap(find.text('Avec chrono · 45 s'));
    await tester.pumpAndSettle();
    expect(launched.single.timerOn, isTrue);
  });

  testWidgets('« Demander » : « Sans chrono »', (tester) async {
    await tester.pumpWidget(app(const RevisionPrefs(timerMode: TimerMode.ask)));
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sans chrono'));
    await tester.pumpAndSettle();
    expect(launched.single.timerOn, isFalse);
  });

  testWidgets('« Demander » : fermer la sheet annule le lancement', (tester) async {
    await tester.pumpWidget(app(const RevisionPrefs(timerMode: TimerMode.ask)));
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20)); // voile
    await tester.pumpAndSettle();
    expect(launched, isEmpty);
  });

  testWidgets('double tap pendant le lancement : un seul drill (revue 8.4)', (tester) async {
    await tester.pumpWidget(app(const RevisionPrefs()));
    await tester.tap(find.text('Commencer'));
    await tester.tap(find.text('Commencer'));
    await tester.pumpAndSettle();
    // Pile de navigation : l'écran d'origine + un seul drill.
    final router = GoRouter.of(tester.element(find.byType(SizedBox).last));
    expect(router.routerDelegate.currentConfiguration.matches, hasLength(2));
  });

  testWidgets('« Demander » : deux taps n’ouvrent qu’une sheet', (tester) async {
    await tester.pumpWidget(app(const RevisionPrefs(timerMode: TimerMode.ask)));
    await tester.tap(find.text('Commencer'));
    await tester.tap(find.text('Commencer'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Sans chrono'), findsOneWidget);
  });
}

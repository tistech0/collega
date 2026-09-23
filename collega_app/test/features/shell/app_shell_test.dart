import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/shell/app_shell.dart';
import 'package:collega_app/features/shell/tab_reselect.dart';

import '../../support/cg_golden.dart';

/// Écran Collega UI : réserve lui-même la tab bar (CgPage.reserveTabBar).
class _Migrated extends StatelessWidget {
  const _Migrated();
  @override
  Widget build(BuildContext context) => const SizedBox.expand(key: Key('migrated'));
}

Widget _app(String initial, {List<int>? reselected}) {
  final router = GoRouter(initialLocation: initial, routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => Builder(builder: (context) {
          final r = TabReselectScope.maybeOf(context);
          r?.addListener(() => reselected?.add(r.index));
          return const SizedBox.expand();
        })),
        GoRoute(path: '/colleges', builder: (_, __) => const _Migrated()),
        GoRoute(path: '/colleges/3', builder: (_, __) => const _Migrated()),
        GoRoute(path: '/colleges/3/items/i1', builder: (_, __) => const _Migrated()),
        GoRoute(path: '/home/colleges/3', builder: (_, __) => const _Migrated()),
        GoRoute(path: '/home/colleges/3/items/i1', builder: (_, __) => const _Migrated()),
        GoRoute(path: '/progress/colleges/3', builder: (_, __) => const _Migrated()),
        GoRoute(path: '/progress/colleges/3/items/i1', builder: (_, __) => const _Migrated()),
        GoRoute(path: '/progress/planning', builder: (_, __) => const _Migrated()),
        GoRoute(path: '/progress', builder: (_, __) => const SizedBox.expand()),
        GoRoute(path: '/profile', builder: (_, __) => const _Migrated()),
      ],
    ),
  ]);
  return CgTheme(data: CgThemeData.light, child: MaterialApp.router(routerConfig: router));
}

void main() {
  setUpAll(loadCgFonts);

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.reset);
  }

  for (final path in [
    '/colleges', '/colleges/3', '/colleges/3/items/i1', '/home/colleges/3/items/i1',
    '/progress/colleges/3', '/progress/colleges/3/items/i1', '/progress/planning', '/profile',
  ]) {
    testWidgets('écrans Collega UI (8.6 → 8.14) : pleine hauteur, safe area intacte ($path)', (tester) async {
      phone(tester);
      await tester.pumpWidget(_app(path));
      await tester.pumpAndSettle();
      // Sinon la place de la tab bar est réservée deux fois (revue 8.6, bloquant).
      expect(tester.getRect(find.byKey(const Key('migrated'))).bottom, 844);
      final context = tester.element(find.byKey(const Key('migrated')));
      expect(MediaQuery.paddingOf(context).bottom, 34);
    });
  }

  test('onglet actif selon l’origine du détail (Aujourd’hui, Progression)', () {
    expect(AppShell.indexOf('/home/colleges/3'), 0);
    expect(AppShell.indexOf('/home/colleges/3/items/i1'), 0);
    expect(AppShell.indexOf('/progress/planning'), 2);
    expect(AppShell.indexOf('/progress/colleges/3'), 2);
  });

  testWidgets('onglet actif re-tapé : signal « remonter en haut »', (tester) async {
    phone(tester);
    final reselected = <int>[];
    await tester.pumpWidget(_app('/home', reselected: reselected));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aujourd’hui'));
    await tester.pump();
    expect(reselected, [0]);
  });

  testWidgets('dans un écran poussé de l’onglet, le re-tap revient à sa racine', (tester) async {
    phone(tester);
    await tester.pumpWidget(_app('/colleges/3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bibliothèque'));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(_Migrated)));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/colleges');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/shell/app_shell.dart';
import 'package:collega_app/features/shell/tab_reselect.dart';

import '../../support/cg_golden.dart';

/// Écran « ancien » (Material) : barre d'action collée en bas, sans SafeArea —
/// comme DrillLaunchBar du détail d'item (revue 8.3, bloquant).
class _Legacy extends StatelessWidget {
  const _Legacy();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: SizedBox(
          height: 56,
          child: TextButton(key: const Key('launch'), onPressed: () {}, child: const Text('Réviser')),
        ),
      );
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
        GoRoute(path: '/colleges', builder: (_, __) => const _Legacy()),
        GoRoute(path: '/colleges/3', builder: (_, __) => const _Legacy()),
        GoRoute(path: '/progress', builder: (_, __) => const SizedBox.expand()),
        GoRoute(path: '/profile', builder: (_, __) => const SizedBox.expand()),
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

  testWidgets('écran non migré : sa barre du bas reste au-dessus de la tab bar et tapable', (tester) async {
    phone(tester);
    await tester.pumpWidget(_app('/colleges/3'));
    await tester.pumpAndSettle();
    final launch = tester.getRect(find.byKey(const Key('launch')));
    const capsuleTop = 844 - 34 - CgSpace.tabBarBottom - CgSpace.tabBarHeight;
    expect(launch.bottom, lessThanOrEqualTo(capsuleTop));
    await tester.tap(find.byKey(const Key('launch'))); // atteint le bouton, pas la tab bar
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
    final router = GoRouter.of(tester.element(find.byType(_Legacy)));
    expect(router.routerDelegate.currentConfiguration.uri.path, '/colleges');
  });
}

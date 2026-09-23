import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/demo/presentation/demo_screen.dart';

import '../../support/cg_golden.dart';

Widget _app({List<String>? visited, double textScale = 1}) {
  final router = GoRouter(initialLocation: '/demo', routes: [
    GoRoute(path: '/demo', builder: (_, __) => const DemoScreen()),
    for (final p in ['/welcome', '/auth/login'])
      GoRoute(path: p, builder: (_, __) {
        visited?.add(p);
        return const SizedBox();
      }),
  ]);
  return ProviderScope(
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

Future<void> _judge(WidgetTester tester, String verdict) async {
  await tester.tap(find.byType(CgDrillCard)); // retourne la fiche
  await tester.pumpAndSettle();
  final v = CgVerdict.values.firstWhere((x) => x.label == verdict);
  await tester.tap(find.byKey(CgVerdictBar.buttonKey(v)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadCgFonts);

  testWidgets('la démo est le vrai drill : 3 fiches, contexte « Démo »', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(CgDrillCard), findsOneWidget);
    expect(find.textContaining('Quels sont les signes cliniques'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('Démo'), findsOneWidget);
  });

  testWidgets('trois verdicts → récap, « Se connecter » (primaire) et « Recommencer »', (tester) async {
    _phone(tester);
    final visited = <String>[];
    await tester.pumpWidget(_app(visited: visited));
    await tester.pumpAndSettle();
    await _judge(tester, 'Maîtrisé');
    expect(find.text('2 / 3'), findsOneWidget);
    await _judge(tester, 'Bien');
    await _judge(tester, 'Maîtrisé');
    expect(find.text('Démo terminée'), findsOneWidget);
    expect(find.text('2 maîtrisées · 1 bien · 0 à revoir'), findsOneWidget);
    await tester.tap(find.text('Recommencer'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
    for (final v in ['À revoir', 'À revoir', 'À revoir']) {
      await _judge(tester, v);
    }
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(visited, ['/auth/login']);
  });

  testWidgets('✕ : retour à l’écran de marque', (tester) async {
    _phone(tester);
    final visited = <String>[];
    await tester.pumpWidget(_app(visited: visited));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CgDrillCard.closeKey));
    await tester.pumpAndSettle();
    expect(visited, ['/welcome']);
  });

  test('aucun widget Material ni shadcn', () {
    final src = File('lib/features/demo/presentation/demo_screen.dart').readAsStringSync();
    expect(src, isNot(contains('material.dart')));
    expect(src, isNot(contains('shadcn_ui')));
  });

  group('goldens', () {
    for (final width in cgGoldenWidths) {
      for (final scale in cgGoldenScales) {
        final tag = '${width.toInt()}_${scale.toString().replaceAll('.', '')}';
        testWidgets('golden demo_recap_$tag', (tester) async {
          _phone(tester, width: width, height: 852);
          await tester.pumpWidget(_app(textScale: scale));
          await tester.pumpAndSettle();
          for (final v in ['Maîtrisé', 'Bien', 'À revoir']) {
            await _judge(tester, v);
          }
          await expectLater(find.byType(CgGoldenFrame), matchesGoldenFile('goldens/demo_recap_$tag.png'));
        });
      }
    }
  });
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';
import 'package:collega_app/features/colleges/presentation/import_progress_screen.dart';

import '../../support/cg_golden.dart';

class _Import extends CollegeImportNotifier {
  static CollegeImportState initial = const ImportIdle();
  static final reconnects = <String>[];
  static Future<void> Function()? onReconnect;

  @override
  Future<CollegeImportState> build() async => initial;

  @override
  Future<void> reconnectIfActive(String collegeId) async {
    reconnects.add(collegeId);
    await onReconnect?.call();
  }

  void emit(CollegeImportState s) => state = AsyncData(s);
}

const _reading = ImportStreaming(collegeId: 'c3', jobId: 'j', ocrProgress: 12, totalPages: 80, status: 'processing');
const _generating = ImportStreaming(
  collegeId: 'c3', jobId: 'j', ocrProgress: 80, totalPages: 80, status: 'ocr_complete',
  itemsDone: 3, itemsTotal: 32, cards: 21,
  preview: ['Quels sont les signes du cancer du testicule ?', 'Marqueurs tumoraux ?', 'Bilan d’extension ?'],
);

Widget _app({List<String>? visited, double textScale = 1, bool reimport = false}) {
  var pushed = false;
  final router = GoRouter(initialLocation: '/start', routes: [
    GoRoute(path: '/start', builder: (_, __) => Builder(builder: (context) {
          if (!pushed) {
            pushed = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => context.push('/progress'));
          }
          return const SizedBox();
        })),
    GoRoute(path: '/progress', builder: (_, __) => ImportProgressScreen(collegeId: 'c3', refId: 3, reimport: reimport)),
    for (final p in ['/colleges', '/colleges/:ref', '/colleges/:ref/import'])
      GoRoute(path: p, builder: (_, s) {
        visited?.add(s.uri.path);
        return const SizedBox();
      }),
  ]);
  return ProviderScope(
    overrides: [collegeImportProvider.overrideWith(_Import.new)],
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

void _phone(WidgetTester tester, {double width = 393, double height = 900}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

_Import _notifier(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ImportProgressScreen))).read(collegeImportProvider.notifier)
        as _Import;

void main() {
  setUpAll(loadCgFonts);
  setUp(() {
    _Import.initial = const ImportIdle();
    _Import.reconnects.clear();
    _Import.onReconnect = null;
  });

  testWidgets('lecture : étapes, « page 12 sur 80 », « tu peux fermer »', (tester) async {
    _phone(tester);
    _Import.initial = _reading;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('Cancérologie'), findsWidgets);
    for (final step in ['Envoi du PDF', 'Lecture du PDF', 'Génération des fiches', 'Classement']) {
      expect(find.text(step), findsOneWidget, reason: step);
    }
    expect(find.bySemanticsLabel('Lecture du PDF, en cours, page 12 sur 80'), findsOneWidget);
    expect(find.bySemanticsLabel('Envoi du PDF, fait'), findsOneWidget);
    expect(find.textContaining('Tu peux fermer Collega'), findsOneWidget);
    expect(find.text('fiches prêtes'), findsNothing);
    handle.dispose();
  });

  testWidgets('génération : compteur « 21 fiches prêtes » au fil de l’eau', (tester) async {
    _phone(tester);
    _Import.initial = _reading;
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    _notifier(tester).emit(_generating);
    await tester.pumpAndSettle();
    expect(find.text('21'), findsOneWidget);
    expect(find.text('fiches prêtes'), findsOneWidget);
    expect(find.text('Item 3 sur 32'), findsOneWidget);
    // Aperçu des dernières fiches (spec v2 § Parcours 4).
    expect(find.text('Marqueurs tumoraux ?'), findsOneWidget);
  });

  testWidgets('terminé : le collège prêt s’ouvre', (tester) async {
    _phone(tester);
    _Import.initial = _generating;
    final visited = <String>[];
    await tester.pumpWidget(_app(visited: visited));
    await tester.pumpAndSettle();
    _notifier(tester).emit(const ImportComplete(collegeId: 'c3'));
    await tester.pumpAndSettle();
    expect(visited, ['/colleges/3']);
  });

  testWidgets('échec : état d’erreur, « Relancer l’import »', (tester) async {
    _phone(tester);
    _Import.initial = _generating;
    final visited = <String>[];
    await tester.pumpWidget(_app(visited: visited));
    await tester.pumpAndSettle();
    _notifier(tester).emit(const ImportError(message: 'generation_failed'));
    await tester.pumpAndSettle();
    expect(find.text('L’import n’a pas abouti'), findsOneWidget);
    await tester.tap(find.text('Relancer l’import'));
    await tester.pumpAndSettle();
    expect(visited, ['/colleges/3/import']);
  });

  testWidgets('ouvert sans import suivi (retour dans l’app) : reprise auprès du serveur', (tester) async {
    _phone(tester);
    final pending = Completer<void>();
    _Import.onReconnect = () => pending.future;
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(_Import.reconnects, ['c3']);
    expect(find.text('Reprise de l’import…'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('reprise sans réponse utile : erreur + « Réessayer » (jamais « Reprise… » sans fin)', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.text('L’import n’a pas pu reprendre'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(_Import.reconnects, ['c3', 'c3']);
  });

  testWidgets('réimport en échec : « Tes fiches restent » en tête', (tester) async {
    _phone(tester);
    _Import.initial = _generating;
    await tester.pumpWidget(_app(reimport: true));
    await tester.pumpAndSettle();
    _notifier(tester).emit(const ImportError(message: 'generation_failed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tes fiches restent.'), findsOneWidget);
  });

  testWidgets('« Fermer » : l’import continue, le collège (« Les fiches arrivent ») s’ouvre', (tester) async {
    _phone(tester);
    _Import.initial = _reading;
    final visited = <String>[];
    await tester.pumpWidget(_app(visited: visited));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    expect(visited, ['/colleges/3']);
  });

  testWidgets('Dynamic Type 1,6 sur 375 : aucun débordement', (tester) async {
    _phone(tester, width: 375, height: 812);
    _Import.initial = _generating;
    await tester.pumpWidget(_app(textScale: 1.6));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('aucun widget Material ni shadcn', () {
    final src = File('lib/features/colleges/presentation/import_progress_screen.dart').readAsStringSync();
    expect(src, isNot(contains('material.dart')));
    expect(src, isNot(contains('shadcn_ui')));
  });

  group('goldens', () {
    for (final width in cgGoldenWidths) {
      for (final scale in cgGoldenScales) {
        final tag = '${width.toInt()}_${scale.toString().replaceAll('.', '')}';
        testWidgets('golden import_generating_$tag', (tester) async {
          _phone(tester, width: width, height: 900);
          _Import.initial = _generating;
          await tester.pumpWidget(_app(textScale: scale));
          await tester.pumpAndSettle();
          await expectLater(find.byType(CgGoldenFrame), matchesGoldenFile('goldens/import_generating_$tag.png'));
        });
      }
    }
  });
}

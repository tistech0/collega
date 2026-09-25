import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/data/college_import_repository.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';
import 'package:collega_app/features/colleges/presentation/college_import_screen.dart';

import '../../support/cg_golden.dart';

class _Import extends CollegeImportNotifier {
  static CollegeImportState initial = const ImportIdle();
  static final started = <(int, String)>[];
  static CollegeImportState? after;

  @override
  Future<CollegeImportState> build() async => initial;

  @override
  Future<void> reset() async {}

  @override
  Future<void> startImport(int refId, File file) async {
    started.add((refId, file.path));
    if (after != null) state = AsyncData(after!);
  }

  void emit(CollegeImportState s) => state = AsyncData(s);
}

class _Colleges extends CollegesNotifier {
  static bool imported = false;
  @override
  Future<List<CollegeListEntry>> build() async => [
        for (final c in kCollegeCatalog)
          CollegeListEntry(
            catalog: c,
            userStatus: imported && c.refId == 3
                ? const UserCollegeStatus(refId: 3, collegeId: 'c3', status: 'generation_complete',
                    cardCountA: 1, cardCountB: 0, cardCountC: 0)
                : null,
          ),
      ];
}

class _Repo extends CollegeImportRepository {
  _Repo() : super(dio: Dio());
  static ReloadLimits limits = const ReloadLimits(
    collegeReloadCount: 1, collegeReloadMax: 2, monthlyReloads: 0, monthlyMax: 3,
    monthlyResetAt: '2026-10-01T00:00:00+00:00',
  );
  @override
  Future<ReloadLimits> getReloadLimits(int refId) async => limits;
}

late PickedPdf _pdf;
Object? _pickError;

Widget _app({List<String>? visited, double textScale = 1}) {
  var pushed = false;
  final router = GoRouter(initialLocation: '/start', routes: [
    GoRoute(path: '/start', builder: (_, __) => Builder(builder: (context) {
          if (!pushed) {
            pushed = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => context.push('/colleges/3/import'));
          }
          return const SizedBox();
        })),
    GoRoute(path: '/colleges/:ref/import', builder: (_, s) => CollegeImportScreen(refId: int.parse(s.pathParameters['ref']!))),
    GoRoute(path: '/colleges/:ref/import/progress', builder: (_, s) {
      visited?.add(s.uri.path);
      return const SizedBox();
    }),
    GoRoute(path: '/paywall', builder: (_, __) {
      visited?.add('/paywall');
      return const SizedBox();
    }),
  ]);
  return ProviderScope(
    overrides: [
      collegeImportProvider.overrideWith(_Import.new),
      collegesProvider.overrideWith(_Colleges.new),
      collegeImportRepositoryProvider.overrideWithValue(_Repo()),
      pdfPickerProvider.overrideWithValue(() async {
        if (_pickError != null) throw _pickError!;
        return _pdf;
      }),
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

void _phone(WidgetTester tester, {double width = 393, double height = 1000}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Aucun accès disque : le sélecteur rend le fichier et sa taille.
PickedPdf _file(int bytes) => (file: File('/tmp/cours.pdf'), size: bytes);

_Import _notifier(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(CollegeImportScreen))).read(collegeImportProvider.notifier)
        as _Import;

void main() {
  setUpAll(loadCgFonts);
  setUp(() async {
    _Import.initial = const ImportIdle();
    _Import.started.clear();
    _Import.after = null;
    _Colleges.imported = false;
    _pickError = null;
  });

  group('avant l’envoi', () {
    testWidgets('dit tout : PDF officiel, 500 Mo, durée, quota, « tu peux fermer » ; un primaire', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Cancérologie'), findsWidgets);
      expect(find.text('Le PDF officiel du collège (CNEC)'), findsOneWidget);
      expect(find.text('500 Mo au plus'), findsOneWidget);
      expect(find.text('3 à 10 minutes selon la taille'), findsOneWidget);
      expect(find.text('Premier import de ce collège'), findsOneWidget);
      expect(find.textContaining('Tu peux fermer Collega'), findsOneWidget);
      final primaries = tester.widgetList<CgButton>(find.byType(CgButton)).where((b) => b.variant == CgButtonVariant.primary);
      expect(primaries.map((b) => b.label), ['Choisir le PDF']);
    });

    testWidgets('réimport : quota « Réimport 2/2 · 1/3 ce mois »', (tester) async {
      _phone(tester);
      _Colleges.imported = true;
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Réimport 2/2 · 1/3 ce mois'), findsOneWidget);
    });

    testWidgets('réimport impossible (limite) : dit, bouton inactif', (tester) async {
      _phone(tester);
      _Colleges.imported = true;
      _Repo.limits = const ReloadLimits(
        collegeReloadCount: 2, collegeReloadMax: 2, monthlyReloads: 0, monthlyMax: 3, monthlyResetAt: '',
      );
      addTearDown(() => _Repo.limits = const ReloadLimits(
            collegeReloadCount: 1, collegeReloadMax: 2, monthlyReloads: 0, monthlyMax: 3,
            monthlyResetAt: '2026-10-01T00:00:00+00:00',
          ));
      _pdf = _file(1000);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.textContaining('Tes fiches restent.'), findsOneWidget);
      await tester.tap(find.text('Choisir le PDF'));
      await tester.pumpAndSettle();
      expect(_Import.started, isEmpty);
    });
  });

  group('envoi', () {
    testWidgets('fichier trop lourd : erreur inline avec la taille, rien envoyé', (tester) async {
      _phone(tester);
      _pdf = _file(612 * 1024 * 1024);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir le PDF'));
      await tester.pumpAndSettle();
      expect(find.text('Ce fichier fait 612 Mo, maximum 500.'), findsOneWidget);
      expect(_Import.started, isEmpty);
    });

    testWidgets('PDF accepté : envoi lancé', (tester) async {
      _phone(tester);
      _pdf = _file(2000);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir le PDF'));
      await tester.pumpAndSettle();
      expect(_Import.started, [(3, '/tmp/cours.pdf')]);
    });

    testWidgets('pendant l’envoi : « Envoi 42 % · continue en arrière-plan »', (tester) async {
      _phone(tester);
      _Import.initial = const ImportUploading(refId: 3, progress: 0.42);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Envoi 42 % · continue en arrière-plan'), findsOneWidget);
    });

    testWidgets('import accepté : ouvre l’import en cours', (tester) async {
      _phone(tester);
      final visited = <String>[];
      await tester.pumpWidget(_app(visited: visited));
      await tester.pumpAndSettle();
      _notifier(tester).emit(const ImportStreaming(collegeId: 'c3', jobId: 'j', ocrProgress: 0, status: 'pending'));
      await tester.pumpAndSettle();
      expect(visited, ['/colleges/3/import/progress']);
    });

    testWidgets('erreur : phrase à l’écran (pas de toast, pas de code)', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      _notifier(tester).emit(const ImportError(message: 'upload_failed'));
      await tester.pumpAndSettle();
      expect(find.text('L’envoi s’est interrompu. Il repartira de là où il s’est arrêté à ta prochaine ouverture de Collega.'),
          findsOneWidget);
    });

    testWidgets('l’écran d’import en cours n’est ouvert qu’une fois (erreur puis reprise dessous)', (tester) async {
      _phone(tester);
      final visited = <String>[];
      await tester.pumpWidget(_app(visited: visited));
      await tester.pumpAndSettle();
      final notifier = _notifier(tester);
      notifier.emit(const ImportStreaming(collegeId: 'c3', jobId: 'j', ocrProgress: 0, status: 'pending'));
      await tester.pumpAndSettle();
      notifier.emit(const ImportError(message: 'session_expired'));
      await tester.pumpAndSettle();
      notifier.emit(const ImportStreaming(collegeId: 'c3', jobId: 'j', ocrProgress: 3, status: 'processing'));
      await tester.pumpAndSettle();
      expect(visited, ['/colleges/3/import/progress']);
    });

    testWidgets('un envoi d’un autre collège est en cours : dit, bouton inactif', (tester) async {
      _phone(tester);
      _Import.initial = const ImportUploading(refId: 26, progress: 0.3);
      _pdf = _file(1000);
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Le PDF de Neurologie est en cours d’envoi. Attends qu’il soit terminé pour en importer un autre.'),
          findsOneWidget);
      expect(find.textContaining('Envoi 30 %'), findsNothing);
      await tester.tap(find.text('Choisir le PDF'));
      await tester.pumpAndSettle();
      expect(_Import.started, isEmpty);
    });

    testWidgets('sélecteur de fichiers en échec : dit', (tester) async {
      _phone(tester);
      _pickError = StateError('picker');
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir le PDF'));
      await tester.pumpAndSettle();
      expect(find.text('Le fichier n’a pas pu être ouvert. Réessaie.'), findsOneWidget);
    });

    testWidgets('abonnement requis : paywall', (tester) async {
      _phone(tester);
      final visited = <String>[];
      await tester.pumpWidget(_app(visited: visited));
      await tester.pumpAndSettle();
      _notifier(tester).emit(const ImportError(message: 'subscription_required'));
      await tester.pumpAndSettle();
      expect(visited, ['/paywall']);
    });
  });

  group('accessibilité', () {
    testWidgets('Dynamic Type 1,6 sur 375 : aucun débordement', (tester) async {
      _phone(tester, width: 375, height: 812);
      await tester.pumpWidget(_app(textScale: 1.6));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    test('aucun widget Material ni shadcn', () {
      final src = File('lib/features/colleges/presentation/college_import_screen.dart').readAsStringSync();
      expect(src, isNot(contains('material.dart')));
      expect(src, isNot(contains('shadcn_ui')));
    });
  });

  group('goldens', () {
    for (final width in cgGoldenWidths) {
      for (final scale in cgGoldenScales) {
        final tag = '${width.toInt()}_${scale.toString().replaceAll('.', '')}';
        testWidgets('golden import_first_$tag', tags: const ['golden'], (tester) async {
          _phone(tester, width: width, height: 900);
          await tester.pumpWidget(_app(textScale: scale));
          await tester.pumpAndSettle();
          await expectLater(find.byType(CgGoldenFrame), matchesGoldenFile('goldens/import_first_$tag.png'));
        });
      }
    }
  });
}

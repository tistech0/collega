import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';
import 'package:collega_app/features/colleges/presentation/college_import_screen.dart';

Widget _buildScreen({
  required int refId,
  CollegeImportState initialState = const ImportIdle(),
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, s) => CollegeImportScreen(refId: refId),
      ),
      GoRoute(
        path: '/colleges/:refId/import/progress',
        builder: (ctx, s) => const _ProgressStub(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      collegeImportProvider.overrideWith(
        () => _FakeImportNotifier(initialState),
      ),
    ],
    child: ShadApp.router(routerConfig: router),
  );
}

class _ProgressStub extends StatelessWidget {
  const _ProgressStub();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('progress-stub'));
}

class _FakeImportNotifier extends CollegeImportNotifier {
  _FakeImportNotifier(this._initial);
  final CollegeImportState _initial;

  @override
  Future<CollegeImportState> build() async => _initial;

  @override
  Future<void> reset() async {}

  void emit(CollegeImportState s) => state = AsyncValue.data(s);
}

void main() {
  group('CollegeImportScreen', () {
    testWidgets('rendu initial — affiche le nom du collège et le bouton', (tester) async {
      await tester.pumpWidget(_buildScreen(refId: 26));
      await tester.pumpAndSettle();

      // Le refId 26 = Neurologie
      expect(find.text('Neurologie'), findsWidgets);
      expect(find.text('Choisir un PDF'), findsOneWidget);
    });

    testWidgets('pendant upload — indicateur de progression visible, bouton absent', (tester) async {
      await tester.pumpWidget(_buildScreen(
        refId: 26,
        initialState: const ImportUploading(),
      ));
      // LinearProgressIndicator est une animation infinie — pump() sans settle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Choisir un PDF'), findsNothing);
    });
    testWidgets(
      "n'empile qu'UN écran de progression malgré plusieurs états ImportStreaming",
      (tester) async {
        // Régression prod 2026-09-21 : chaque événement OCR produisait un nouvel
        // ImportStreaming → context.push à chaque fois → ~55 écrans empilés, dont les
        // 55 AppLifecycleListener rappelaient reconnectIfActive au retour premier plan.
        final notifier = _FakeImportNotifier(const ImportIdle());
        final container = ProviderContainer(
          overrides: [collegeImportProvider.overrideWith(() => notifier)],
        );
        addTearDown(container.dispose);
        final router = GoRouter(routes: [
          GoRoute(path: '/', builder: (ctx, s) => const CollegeImportScreen(refId: 26)),
          GoRoute(path: '/colleges/:refId/import/progress', builder: (ctx, s) => const _ProgressStub()),
        ]);
        await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: ShadApp.router(routerConfig: router),
        ));
        await tester.pumpAndSettle();

        notifier.emit(const ImportStreaming(collegeId: 'c1', jobId: 'j', ocrProgress: 1, status: 'processing'));
        await tester.pumpAndSettle();
        notifier.emit(const ImportStreaming(collegeId: 'c1', jobId: 'j', ocrProgress: 2, status: 'processing'));
        await tester.pumpAndSettle();
        notifier.emit(const ImportStreaming(collegeId: 'c1', jobId: 'j', ocrProgress: 3, status: 'processing'));
        await tester.pumpAndSettle();

        expect(find.byType(_ProgressStub, skipOffstage: false), findsOneWidget);
      },
    );
  });
}

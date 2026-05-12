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

class _FakeImportNotifier extends CollegeImportNotifier {
  _FakeImportNotifier(this._initial);
  final CollegeImportState _initial;

  @override
  Future<CollegeImportState> build() async => _initial;

  @override
  Future<void> reset() async {}
}

void main() {
  group('CollegeImportScreen', () {
    testWidgets('rendu initial — affiche le nom du collège et le bouton', (tester) async {
      await tester.pumpWidget(_buildScreen(refId: 15));
      await tester.pumpAndSettle();

      // Le refId 15 = Neurologie
      expect(find.text('Neurologie'), findsWidgets);
      expect(find.text('Choisir un PDF'), findsOneWidget);
    });

    testWidgets('pendant upload — indicateur de progression visible, bouton absent', (tester) async {
      await tester.pumpWidget(_buildScreen(
        refId: 15,
        initialState: const ImportUploading(),
      ));
      // LinearProgressIndicator est une animation infinie — pump() sans settle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Choisir un PDF'), findsNothing);
    });
  });
}

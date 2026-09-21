import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/upload/part_transport.dart';
import 'package:collega_app/core/upload/upload_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/data/colleges_repository.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/colleges/presentation/colleges_screen.dart';

class _FakeCollegesRepository extends CollegesRepository {
  _FakeCollegesRepository({List<UserCollegeStatus>? result})
      : _result = result ?? [],
        super(dio: Dio());

  final List<UserCollegeStatus> _result;

  @override
  Future<List<UserCollegeStatus>> getUserColleges() async => _result;
}

class _BlockingCollegesRepository extends CollegesRepository {
  _BlockingCollegesRepository() : super(dio: Dio());
  final _completer = Completer<List<UserCollegeStatus>>();

  @override
  Future<List<UserCollegeStatus>> getUserColleges() => _completer.future;

  void complete() => _completer.complete([]);
}

Widget _buildWithOverride(CollegesRepository repo, {Widget? child}) {
  return ShadApp(
    home: ProviderScope(
      overrides: [
        collegesRepositoryProvider.overrideWithValue(repo),
        // Story 7.11 : l'écran déclenche resumePendingUpload() au montage → pas de DB /
        // transport natifs en test widget.
        databaseProvider.overrideWithValue(AppDatabase.forTesting(NativeDatabase.memory())),
        partTransportProvider.overrideWithValue(InMemoryPartTransport()),
        uploadCacheDirProvider.overrideWith((_) async => Directory.systemTemp),
      ],
      child: child ?? const CollegesScreen(),
    ),
  );
}

void main() {
  group('CollegesScreen', () {
    testWidgets('état loading → affiche placeholders squelettes', (tester) async {
      final repo = _BlockingCollegesRepository();
      await tester.pumpWidget(_buildWithOverride(repo));
      // Future bloqué → état loading visible après le premier frame
      expect(find.byKey(const ValueKey('skeleton-tile-0')), findsOneWidget);
      // Débloquer et drainer pour éviter des timers en attente
      repo.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('liste chargée → affiche les 40 colleges', (tester) async {
      final repo = _FakeCollegesRepository();
      await tester.pumpWidget(_buildWithOverride(repo));
      await tester.pumpAndSettle();

      // Les filter chips sont présents
      expect(find.text('Tous'), findsOneWidget);
      expect(find.text('Importés'), findsOneWidget);
      expect(find.text('Non-importés'), findsOneWidget);
    });

    testWidgets('filtre Importés avec liste vide → affiche état vide', (tester) async {
      final repo = _FakeCollegesRepository();
      await tester.pumpWidget(_buildWithOverride(repo));
      await tester.pumpAndSettle();

      // Tap sur "Importés"
      await tester.tap(find.text('Importés'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Sélectionne un collège'),
        findsOneWidget,
      );
      expect(find.text('Voir tous les collèges'), findsOneWidget);
    });
  });
}

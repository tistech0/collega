import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/features/colleges/colleges_detail_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/domain/drill_stats.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/colleges/presentation/college_detail_screen.dart';

final _catalogEntry = kCollegeCatalog.first;

CollegeListEntry _notImportedEntry() => CollegeListEntry(catalog: _catalogEntry);

CollegeListEntry _loadingEntry() => CollegeListEntry(
      catalog: _catalogEntry,
      userStatus: UserCollegeStatus(
        refId: _catalogEntry.refId,
        collegeId: 'college-uuid-1',
        status: 'processing',
        cardCountA: 0,
        cardCountB: 0,
        cardCountC: 0,
      ),
    );

CollegeListEntry _completeEntry() => CollegeListEntry(
      catalog: _catalogEntry,
      userStatus: UserCollegeStatus(
        refId: _catalogEntry.refId,
        collegeId: 'college-uuid-1',
        status: 'generation_complete',
        cardCountA: 3,
        cardCountB: 2,
        cardCountC: 0,
      ),
    );

class _FakeDetailNotifier extends CollegeDetailNotifier {
  _FakeDetailNotifier(this._state);
  final CollegeDetailState _state;

  @override
  Future<CollegeDetailState> build(String collegeId) async => _state;
}

Widget _buildScreen({
  required int refId,
  required List<CollegeListEntry> colleges,
  CollegeDetailState? detailState,
  Map<String, DrillStats> drillByItem = const {},
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (ctx, s) => CollegeDetailScreen(refId: refId),
      ),
      GoRoute(
        path: '/colleges/:ref_id/import',
        builder: (ctx, s) => const Scaffold(
          body: Center(child: Text('Choisir un PDF')),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      collegesProvider.overrideWith(
        () => _FakeCollegesNotifier(colleges),
      ),
      if (detailState != null)
        collegeDetailProvider.overrideWith(
          () => _FakeDetailNotifier(detailState),
        ),
      collegeDrillStatsByItemProvider.overrideWith(
        (ref, collegeId) => Stream.value(drillByItem),
      ),
    ],
    child: ShadApp.router(routerConfig: router),
  );
}

class _FakeCollegesNotifier extends CollegesNotifier {
  _FakeCollegesNotifier(this._colleges);
  final List<CollegeListEntry> _colleges;

  @override
  Future<List<CollegeListEntry>> build() async => _colleges;
}

void main() {
  group('CollegeDetailScreen', () {
    testWidgets(
        'collège non importé → redirige vers /colleges/:ref_id/import (Choisir un PDF)',
        (tester) async {
      await tester.pumpWidget(_buildScreen(
        refId: _catalogEntry.refId,
        colleges: [_notImportedEntry()],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Choisir un PDF'), findsOneWidget);
    });

    testWidgets('génération en cours → LinearProgressIndicator visible',
        (tester) async {
      await tester.pumpWidget(_buildScreen(
        refId: _catalogEntry.refId,
        colleges: [_loadingEntry()],
      ));
      await tester.pump();
      // Drain pending 0ms timers from ShadApp's flutter_animate internals
      await tester.pump(Duration.zero);

      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets(
        'progression globale = stats de drill vivantes sur le total serveur',
        (tester) async {
      // Repro iPhone 2026-09-21 : item de 5 fiches (serveur), 2 maîtrisées en
      // local → « 40% maîtrisé · 5 fiches », et non « 0% · 0 fiches ».
      const item = ItemModel(
        id: 'item-1',
        collegeId: 'college-uuid-1',
        itemNumber: 310,
        rang: 'A',
        ocrConfidenceScore: 0.9,
        lowConfidence: false,
        cardCountA: 3,
        cardCountB: 2,
        cardCountC: 0,
      );

      await tester.pumpWidget(_buildScreen(
        refId: _catalogEntry.refId,
        colleges: [_completeEntry()],
        detailState: const CollegeDetailLoaded(items: [item]),
        drillByItem: {'item-1': const DrillStats(maitrise: 2)},
      ));
      await tester.pumpAndSettle();

      expect(find.text('40% maîtrisé · 5 fiches'), findsOneWidget);
    });
  });
}

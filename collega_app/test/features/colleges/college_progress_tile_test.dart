import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/colleges/domain/drill_stats.dart';
import 'package:collega_app/features/colleges/widgets/college_progress_tile.dart';

Widget _buildTile(
  CollegeListEntry entry, {
  DrillStats stats = const DrillStats(),
}) {
  return ShadApp(
    home: ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(
          AppDatabase.forTesting(NativeDatabase.memory()),
        ),
        collegeDrillStatsProvider.overrideWith(
          (ref, collegeId) => Stream.value(stats),
        ),
      ],
      child: Scaffold(
        body: CollegeProgressTile(entry: entry),
      ),
    ),
  );
}

void main() {
  group('CollegeProgressTile', () {
    testWidgets('affiche le tile non-importé pour un collège non importé',
        (tester) async {
      final entry = CollegeListEntry(catalog: kCollegeCatalog.first);

      await tester.pumpWidget(_buildTile(entry));
      await tester.pumpAndSettle();

      expect(find.text('Non-importé'), findsOneWidget);
    });

    testWidgets('affiche le tile importé avec les données drill',
        (tester) async {
      final status = UserCollegeStatus(
        refId: kCollegeCatalog.first.refId,
        collegeId: 'test-college-id',
        status: 'generation_complete',
        cardCountA: 5,
        cardCountB: 3,
        cardCountC: 2,
      );
      final entry = CollegeListEntry(
        catalog: kCollegeCatalog.first,
        userStatus: status,
      );
      const stats = DrillStats(maitrise: 5, bien: 3, aRevoir: 2, notSeen: 0);

      await tester.pumpWidget(_buildTile(entry, stats: stats));
      await tester.pumpAndSettle();

      expect(find.text('Non-importé'), findsNothing);
      expect(find.text(kCollegeCatalog.first.name), findsOneWidget);
    });

    testWidgets('affiche barre grise si stats.total == 0 (aucune fiche drillée)',
        (tester) async {
      final status = UserCollegeStatus(
        refId: kCollegeCatalog.first.refId,
        collegeId: 'empty-college-id',
        status: 'generation_complete',
        cardCountA: 0,
        cardCountB: 0,
        cardCountC: 0,
      );
      final entry = CollegeListEntry(
        catalog: kCollegeCatalog.first,
        userStatus: status,
      );

      await tester.pumpWidget(_buildTile(entry));
      await tester.pumpAndSettle();

      expect(find.text(kCollegeCatalog.first.name), findsOneWidget);
    });

    testWidgets(
        'le non-vu est calculé sur le total serveur, pas sur les fiches cachées',
        (tester) async {
      // Repro iPhone 2026-09-21 : 15 fiches d'un seul item cachées et drillées
      // sur un collège de 177 fiches → la barre était pleine (0 gris).
      final status = UserCollegeStatus(
        refId: kCollegeCatalog.first.refId,
        collegeId: 'cancero',
        status: 'generation_complete',
        cardCountA: 100,
        cardCountB: 50,
        cardCountC: 27,
      );
      final entry = CollegeListEntry(
        catalog: kCollegeCatalog.first,
        userStatus: status,
      );
      const stats = DrillStats(maitrise: 14, bien: 1, aRevoir: 0, notSeen: 0);

      await tester.pumpWidget(_buildTile(entry, stats: stats));
      await tester.pumpAndSettle();

      final flexes = tester
          .widgetList<Flexible>(find.byType(Flexible))
          .map((f) => f.flex)
          .toList();
      expect(flexes, containsAll([14, 1, 162]));
    });
  });
}

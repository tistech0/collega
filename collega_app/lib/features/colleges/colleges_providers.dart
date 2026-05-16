import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/features/colleges/data/colleges_repository.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/colleges/domain/drill_stats.dart';

final collegesRepositoryProvider = Provider<CollegesRepository>(
  (ref) => CollegesRepository(dio: ref.read(apiClientProvider).dio),
);

class CollegesNotifier extends AsyncNotifier<List<CollegeListEntry>> {
  @override
  Future<List<CollegeListEntry>> build() async {
    final imported = await ref.read(collegesRepositoryProvider).getUserColleges();
    final importedByRefId = {for (final s in imported) s.refId: s};
    return kCollegeCatalog
        .map(
          (entry) => CollegeListEntry(
            catalog: entry,
            userStatus: importedByRefId[entry.refId],
          ),
        )
        .toList();
  }
}

final collegesProvider =
    AsyncNotifierProvider<CollegesNotifier, List<CollegeListEntry>>(
  CollegesNotifier.new,
);

final collegeDrillStatsProvider =
    StreamProvider.family<DrillStats, String>((ref, collegeId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.flashCards)
        ..where((t) => t.collegeId.equals(collegeId)))
      .watch()
      .map((cards) {
    int maitrise = 0, bien = 0, aRevoir = 0, notSeen = 0;
    for (final c in cards) {
      switch (c.drillLevel) {
        case 'maitrise':
          maitrise++;
        case 'bien':
          bien++;
        case 'a_revoir':
          aRevoir++;
        case 'new':
          notSeen++;
        default:
          break;
      }
    }
    return DrillStats(
      maitrise: maitrise,
      bien: bien,
      aRevoir: aRevoir,
      notSeen: notSeen,
    );
  });
});

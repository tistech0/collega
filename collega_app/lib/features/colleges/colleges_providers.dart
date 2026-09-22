import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
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
    final imported = await _loadUserColleges();
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

extension on CollegesNotifier {
  /// Réseau d'abord (et mise en cache), sinon derniers collèges connus (hors-ligne).
  /// Sans cache, l'erreur réseau remonte : l'écran affiche son état d'erreur.
  Future<List<UserCollegeStatus>> _loadUserColleges() async {
    final db = ref.read(databaseProvider);
    try {
      final fresh = await ref.read(collegesRepositoryProvider).getUserColleges();
      await db.transaction(() async {
        await db.delete(db.userColleges).go();
        await db.batch((b) => b.insertAll(db.userColleges, [
              for (final s in fresh)
                UserCollegesCompanion.insert(
                  refId: Value(s.refId),
                  collegeId: s.collegeId,
                  status: s.status,
                  cardCountA: s.cardCountA,
                  cardCountB: s.cardCountB,
                  cardCountC: s.cardCountC,
                ),
            ]));
      });
      return fresh;
    } on DioException {
      final cached = await db.select(db.userColleges).get();
      if (cached.isEmpty) rethrow;
      return [
        for (final r in cached)
          UserCollegeStatus(
            refId: r.refId,
            collegeId: r.collegeId,
            status: r.status,
            cardCountA: r.cardCountA,
            cardCountB: r.cardCountB,
            cardCountC: r.cardCountC,
          ),
      ];
    }
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
      .map((cards) => DrillStats.fromDrillLevels(cards.map((c) => c.drillLevel)));
});

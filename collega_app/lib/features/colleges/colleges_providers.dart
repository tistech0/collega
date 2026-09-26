import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/network/network_errors.dart';
import 'package:collega_app/features/colleges/data/college_cards_sync.dart';
import 'package:collega_app/features/colleges/data/colleges_repository.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/colleges/domain/drill_stats.dart';

final collegesRepositoryProvider = Provider<CollegesRepository>(
  (ref) => CollegesRepository(dio: ref.read(apiClientProvider).dio),
);

class CollegesNotifier extends AsyncNotifier<List<CollegeListEntry>> {
  bool _offline = false;

  /// La dernière liste vient du cache local parce que le réseau manque : la
  /// Bibliothèque affiche « Hors connexion » (pas sur une erreur serveur).
  bool get isOffline => _offline;

  @override
  Future<List<CollegeListEntry>> build() async {
    final (imported, offline) = await _loadUserColleges();
    _offline = offline;
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
  Future<(List<UserCollegeStatus>, bool)> _loadUserColleges() async {
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
                  pdfVersion: Value(s.pdfVersion),
                  pdfSize: Value(s.pdfSize),
                ),
            ]));
        // Liste fraîche du serveur : le contenu local des collèges disparus
        // (vidage, suppression) part. Jamais sur un échec (cache hors-ligne).
        await pruneStaleColleges(db, {for (final s in fresh) s.collegeId});
      });
      return (fresh, false);
    } on DioException catch (e) {
      final cached = await db.select(db.userColleges).get();
      if (cached.isEmpty) rethrow;
      return ([
        for (final r in cached)
          UserCollegeStatus(
            refId: r.refId,
            collegeId: r.collegeId,
            status: r.status,
            cardCountA: r.cardCountA,
            cardCountB: r.cardCountB,
            cardCountC: r.cardCountC,
            pdfVersion: r.pdfVersion,
            pdfSize: r.pdfSize,
          ),
      ], isNetworkUnreachable(e));
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

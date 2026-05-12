import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/features/colleges/data/colleges_repository.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';

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

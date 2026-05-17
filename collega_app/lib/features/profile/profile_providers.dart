import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/features/profile/data/revision_prefs_repository.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';

final revisionPrefsRepositoryProvider = Provider<RevisionPrefsRepository>(
  (ref) => RevisionPrefsRepository(storage: ref.read(secureStorageProvider)),
);

class RevisionPrefsNotifier extends AsyncNotifier<RevisionPrefs> {
  @override
  Future<RevisionPrefs> build() async {
    return ref.read(revisionPrefsRepositoryProvider).load();
  }

  Future<void> save(RevisionPrefs prefs) async {
    await ref.read(revisionPrefsRepositoryProvider).save(prefs);
    state = AsyncData(prefs);
  }
}

final revisionPrefsProvider =
    AsyncNotifierProvider<RevisionPrefsNotifier, RevisionPrefs>(
  RevisionPrefsNotifier.new,
);

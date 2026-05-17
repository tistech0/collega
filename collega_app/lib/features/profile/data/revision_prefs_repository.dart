import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';

const _kRevisionRangs = 'revision_prefs_rangs';
const _kRevisionMaxCards = 'revision_prefs_max_cards';

class RevisionPrefsRepository {
  RevisionPrefsRepository({required FlutterSecureStorage storage})
      : _storage = storage;

  final FlutterSecureStorage _storage;

  Future<RevisionPrefs> load() async {
    final rangsStr = await _storage.read(key: _kRevisionRangs);
    final maxCardsStr = await _storage.read(key: _kRevisionMaxCards);
    final rangs = rangsStr != null && rangsStr.isNotEmpty
        ? rangsStr.split(',').where((r) => r.isNotEmpty).toList()
        : null;
    final maxCards = int.tryParse(maxCardsStr ?? '0') ?? 0;
    return RevisionPrefs(defaultRangs: rangs, defaultMaxCards: maxCards);
  }

  Future<void> save(RevisionPrefs prefs) async {
    final rangsStr = prefs.defaultRangs?.join(',') ?? '';
    await Future.wait([
      _storage.write(key: _kRevisionRangs, value: rangsStr),
      _storage.write(key: _kRevisionMaxCards, value: prefs.defaultMaxCards.toString()),
    ]);
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';

const _kRevisionRangs = 'revision_prefs_rangs';
const _kRevisionMaxCards = 'revision_prefs_max_cards';
const _kRevisionTimerEnabled = 'revision_prefs_timer_enabled';
const _kRevisionTimerDurationSeconds = 'revision_prefs_timer_duration_seconds';

class RevisionPrefsRepository {
  RevisionPrefsRepository({required FlutterSecureStorage storage})
      : _storage = storage;

  final FlutterSecureStorage _storage;

  Future<RevisionPrefs> load() async {
    final results = await Future.wait([
      _storage.read(key: _kRevisionRangs),
      _storage.read(key: _kRevisionMaxCards),
      _storage.read(key: _kRevisionTimerEnabled),
      _storage.read(key: _kRevisionTimerDurationSeconds),
    ]);
    final rangsStr = results[0];
    final maxCardsStr = results[1];
    final timerEnabledStr = results[2];
    final timerDurationStr = results[3];

    final rangs = rangsStr != null && rangsStr.isNotEmpty
        ? rangsStr.split(',').where((r) => r.isNotEmpty).toList()
        : null;
    final maxCards = int.tryParse(maxCardsStr ?? '0') ?? 0;
    final timerEnabled = timerEnabledStr == 'true';
    final timerDurationSeconds =
        int.tryParse(timerDurationStr ?? '') ?? 30;
    return RevisionPrefs(
      defaultRangs: rangs,
      defaultMaxCards: maxCards,
      timerEnabled: timerEnabled,
      timerDurationSeconds: timerDurationSeconds,
    );
  }

  Future<void> save(RevisionPrefs prefs) async {
    final rangsStr = prefs.defaultRangs?.join(',') ?? '';
    await Future.wait([
      _storage.write(key: _kRevisionRangs, value: rangsStr),
      _storage.write(
          key: _kRevisionMaxCards, value: prefs.defaultMaxCards.toString()),
      _storage.write(
          key: _kRevisionTimerEnabled,
          value: prefs.timerEnabled ? 'true' : 'false'),
      _storage.write(
          key: _kRevisionTimerDurationSeconds,
          value: prefs.timerDurationSeconds.toString()),
    ]);
  }
}

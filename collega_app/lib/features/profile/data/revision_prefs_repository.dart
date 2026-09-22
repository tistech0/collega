import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';

const _kRevisionRangs = 'revision_prefs_rangs';
const _kRevisionMaxCards = 'revision_prefs_max_cards';
/// Ancien réglage booléen (story 7.4), relu seulement pour migrer.
const _kRevisionTimerEnabled = 'revision_prefs_timer_enabled';
const _kRevisionTimerMode = 'revision_prefs_timer_mode';
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
      _storage.read(key: _kRevisionTimerMode),
    ]);
    final rangsStr = results[0];
    final maxCardsStr = results[1];
    final timerEnabledStr = results[2];
    final timerDurationStr = results[3];

    final rangs = rangsStr != null && rangsStr.isNotEmpty
        ? rangsStr.split(',').where((r) => r.isNotEmpty).toList()
        : null;
    final maxCards = int.tryParse(maxCardsStr ?? '0') ?? 0;
    final timerMode = TimerMode.values.firstWhere(
      (m) => m.name == results[4],
      orElse: () => timerEnabledStr == 'true' ? TimerMode.on : TimerMode.off,
    );
    final timerDurationSeconds =
        int.tryParse(timerDurationStr ?? '') ?? 30;
    return RevisionPrefs(
      defaultRangs: rangs,
      defaultMaxCards: maxCards,
      timerMode: timerMode,
      timerDurationSeconds: timerDurationSeconds,
    );
  }

  Future<void> save(RevisionPrefs prefs) async {
    final rangsStr = prefs.defaultRangs?.join(',') ?? '';
    await Future.wait([
      _storage.write(key: _kRevisionRangs, value: rangsStr),
      _storage.write(
          key: _kRevisionMaxCards, value: prefs.defaultMaxCards.toString()),
      _storage.write(key: _kRevisionTimerMode, value: prefs.timerMode.name),
      _storage.write(
          key: _kRevisionTimerDurationSeconds,
          value: prefs.timerDurationSeconds.toString()),
    ]);
  }
}

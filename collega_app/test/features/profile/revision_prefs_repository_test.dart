import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/profile/data/revision_prefs_repository.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';

/// Fake storage minimal pour les tests du repo (pattern Story 7.3 T8).
class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage({Map<String, String>? initial}) : _store = {...?initial};

  final Map<String, String> _store;
  final Map<String, String?> writtenValues = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    writtenValues[key] = value;
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }
}

void main() {
  group('RevisionPrefsRepository — timer (Story 7.4 AC #1)', () {
    test('load: storage vide → defaults (timer disabled, 30s)', () async {
      final storage = _FakeSecureStorage();
      final repo = RevisionPrefsRepository(storage: storage);
      final prefs = await repo.load();
      expect(prefs.timerEnabled, isFalse);
      expect(prefs.timerDurationSeconds, 30);
    });

    test('save: persiste timerEnabled + timerDurationSeconds', () async {
      final storage = _FakeSecureStorage();
      final repo = RevisionPrefsRepository(storage: storage);
      await repo.save(const RevisionPrefs(
        timerEnabled: true,
        timerDurationSeconds: 60,
      ));
      expect(storage.writtenValues['revision_prefs_timer_enabled'], 'true');
      expect(
        storage.writtenValues['revision_prefs_timer_duration_seconds'],
        '60',
      );
    });

    test('roundtrip: save puis load → mêmes valeurs', () async {
      final storage = _FakeSecureStorage();
      final repo = RevisionPrefsRepository(storage: storage);
      await repo.save(const RevisionPrefs(
        timerEnabled: true,
        timerDurationSeconds: 120,
      ));
      final prefs = await repo.load();
      expect(prefs.timerEnabled, isTrue);
      expect(prefs.timerDurationSeconds, 120);
    });

    test('load: timerEnabled persiste à false explicite', () async {
      final storage = _FakeSecureStorage(initial: {
        'revision_prefs_timer_enabled': 'false',
        'revision_prefs_timer_duration_seconds': '15',
      });
      final repo = RevisionPrefsRepository(storage: storage);
      final prefs = await repo.load();
      expect(prefs.timerEnabled, isFalse);
      expect(prefs.timerDurationSeconds, 15);
    });

    test('save: n\'écrase pas les autres champs (rangs, maxCards)', () async {
      final storage = _FakeSecureStorage();
      final repo = RevisionPrefsRepository(storage: storage);
      await repo.save(const RevisionPrefs(
        defaultRangs: ['A', 'B'],
        defaultMaxCards: 25,
        timerEnabled: true,
        timerDurationSeconds: 60,
      ));
      final prefs = await repo.load();
      expect(prefs.defaultRangs, ['A', 'B']);
      expect(prefs.defaultMaxCards, 25);
      expect(prefs.timerEnabled, isTrue);
      expect(prefs.timerDurationSeconds, 60);
    });
  });
}

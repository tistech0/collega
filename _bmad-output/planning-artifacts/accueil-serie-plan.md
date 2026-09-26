# Partie D — Accueil : session faite et série de jours — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sur l'onglet Aujourd'hui, une session du jour terminée se voit d'un coup d'œil (grand rond coché, coches dans la semaine, animation jouée une seule fois au retour du drill) et un badge « N jours d'affilée » encourage la régularité.

**Architecture:** Tout se passe dans l'app, sur le téléphone. Une petite table drift `quiet_days` (migration 8 → 9) garde les jours « rien à réviser », que la session du jour efface aujourd'hui. Une fonction pure `streakLength` calcule la série à partir des jours terminés (`daily_sessions.completedAtMs`) et des jours excusés (`quiet_days` ∪ jours décalés du planning). `TodayNotifier` expose `streak`, et `today_screen.dart` affiche le badge, les coches et le widget `DoneCheck` animé.

**Tech Stack:** Flutter 3.27.1, Riverpod 2, drift 2 (+ `build_runner`), flutter_test (widgets + goldens).

**Spec:** `_bmad-output/planning-artifacts/recherche-pdf-avis-drill-accueil-spec.md`, section **D** (lire aussi « Qualité et livraison »).

## Global Constraints

- Répertoire : `collega_app/`. Tests **par dossier** uniquement : `flutter test test/core`, `flutter test test/features/today` (jamais toute la suite d'un coup).
- Aucun changement serveur. La série vit **sur le téléphone uniquement** (elle ne suit pas un changement d'iPhone ni une réinstallation).
- Migration drift : `schemaVersion` passe de **8 à 9** (cette partie est livrée avant la partie PDF, qui prendra la 10).
- Badge affiché à partir de **2** jours, texte exact : « N jours d’affilée » (apostrophe typographique `’`). Jamais de message négatif quand la série casse : le badge disparaît simplement.
- Règles de série : un jour compte s'il a une session du jour terminée ; **aujourd'hui non terminé ne casse pas** ; jours décalés et jours « rien à réviser » **ne cassent pas** (et ne comptent pas).
- Animation **une seule fois**, au retour sur Aujourd'hui juste après avoir terminé la session du jour ; aucune si `CgMotion.reduced(context)` (réduction des animations).
- Textes de l'app en français, tutoiement. Couleurs et tailles via les jetons Collega UI (`CgTheme.of(context).colors`, `CgSpace`, `CgType`, `CgMotion`, `CgHaptics`), jamais de valeur en dur hors constantes `static const` du widget.
- Commits : messages en français, préfixe `feat(accueil)` / `test(accueil)`, terminés par `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
- Après modification des tables drift : `dart run build_runner build --delete-conflicting-outputs` (régénère `app_database.g.dart`).

## Review Focus

1. **Session commencée la veille et terminée après minuit** : elle reste comptée sur son jour (`complete(day)` écrit sur le jour de la session). La série doit compter ce jour-là, pas le lendemain. Testé en Task 3 (`streakLength` ne dépend que des jours) et en Task 4 (jour terminé = ligne `daily_sessions` du jour J).
2. **Personnaliser avec un filtre qui ne donne aucune fiche** : ce n'est pas un jour « rien à réviser », c'est un choix de l'utilisatrice. Il ne doit pas être enregistré dans `quiet_days`. Testé en Task 2.
3. **Jour calme puis session faite plus tard le même jour** (des fiches arrivent après une synchro) : le jour compte comme fait, sans double comptage. Testé en Task 3.
4. **Changement de compte** : les jours calmes de l'ancien compte ne doivent pas excuser les trous du nouveau. `deleteEverything` vide `quiet_days`. Testé en Task 1.
5. **Retour du drill sans avoir terminé** (quitter au milieu) : pas d'animation. **Retour sur une session déjà faite** (réviser encore) : pas d'animation non plus. Testé en Task 7.

## File Structure

Créés :
- `collega_app/lib/core/database/tables/quiet_days_table.dart` — table `QuietDays` (jours « rien à réviser »).
- `collega_app/lib/features/today/domain/streak.dart` — `streakLength(...)`, fonction pure.
- `collega_app/lib/features/today/presentation/done_check.dart` — `DoneCheck`, rond coché, animé une fois.
- `collega_app/test/core/database/migration_v9_test.dart`
- `collega_app/test/features/today/streak_test.dart`
- `collega_app/test/features/today/done_check_test.dart`

Modifiés :
- `collega_app/lib/core/database/app_database.dart` — table, `schemaVersion` 9, migration, `deleteEverything`.
- `collega_app/lib/core/database/app_database.g.dart` — régénéré.
- `collega_app/lib/features/today/data/daily_session_repository.dart` — `markQuiet` dans la branche `plan.isEmpty` (hors personnalisation), `quietDays(...)`, `resetDay` oublie aussi le jour calme.
- `collega_app/lib/features/today/today_providers.dart` — `TodayReady.streak`, calcul dans `TodayNotifier.build`.
- `collega_app/lib/features/today/presentation/today_screen.dart` — `_Done` (grand rond), `_Week` (coches), badge de série dans `_Hero`, drapeau de célébration dans `_TodayScreenState`.
- Tests : `test/features/today/daily_session_repository_test.dart`, `today_provider_test.dart`, `today_screen_test.dart` ; goldens `test/features/today/goldens/today_{ready,started,done}_*.png` régénérés.

---

### Task 1: Table `quiet_days` et migration 8 → 9

**Files:**
- Create: `collega_app/lib/core/database/tables/quiet_days_table.dart`
- Modify: `collega_app/lib/core/database/app_database.dart`, `collega_app/lib/core/database/app_database.g.dart` (généré)
- Test: `collega_app/test/core/database/migration_v9_test.dart`

**Interfaces:**
- Produces: table drift `QuietDays` (accesseur `db.quietDays`, ligne `QuietDayRow`, compagnon `QuietDaysCompanion.insert(day: Value(int))`), colonne unique `day` (jour epoch, clé primaire). `db.deleteEverything()` vide aussi `quietDays`.

- [ ] **Step 1: Write the failing test**

`collega_app/test/core/database/migration_v9_test.dart` :

```dart
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';

void main() {
  test('migration v8 → v9 : quiet_days créée, les sessions existantes intactes', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
      raw.execute('CREATE TABLE daily_sessions ('
          'day INTEGER NOT NULL PRIMARY KEY, queue_json TEXT NOT NULL, position INTEGER NOT NULL DEFAULT 0, '
          'settings_json TEXT NULL, started_at_ms INTEGER NULL, completed_at_ms INTEGER NULL)');
      raw.execute("INSERT INTO daily_sessions (day, queue_json, completed_at_ms) VALUES (20000, '[]', 1)");
      raw.execute('PRAGMA user_version = 8');
    }));
    addTearDown(db.close);

    expect((await db.select(db.dailySessions).get()).single.day, 20000);
    await db.into(db.quietDays).insert(QuietDaysCompanion.insert(day: const Value(20001)));
    expect((await db.select(db.quietDays).get()).single.day, 20001);
  });

  test('deleteEverything vide aussi les jours calmes (changement de compte)', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.into(db.quietDays).insert(QuietDaysCompanion.insert(day: const Value(20001)));
    await db.deleteEverything();
    expect(await db.select(db.quietDays).get(), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run (dans `collega_app/`) : `flutter test test/core/database/migration_v9_test.dart`
Expected: FAIL à la compilation (`quietDays` / `QuietDaysCompanion` introuvables).

- [ ] **Step 3: Write minimal implementation**

`collega_app/lib/core/database/tables/quiet_days_table.dart` :

```dart
import 'package:drift/drift.dart';

/// Jours « rien à réviser » (partie D) : la session du jour vide n'est pas
/// enregistrée, ce jour est noté ici pour ne pas casser la série.
@DataClassName('QuietDayRow')
class QuietDays extends Table {
  /// Jour local (`epochDayOf`).
  IntColumn get day => integer()();

  @override
  Set<Column> get primaryKey => {day};
}
```

Dans `collega_app/lib/core/database/app_database.dart` :

```dart
import 'tables/quiet_days_table.dart';
```

```dart
@DriftDatabase(tables: [
  CollegeImports, Items, FlashCards, PlanningConfigs, PlanningSessions, PendingUploads,
  DailySessions, ReviewLog, UserColleges, QuietDays,
])
```

```dart
  @override
  int get schemaVersion => 9;
```

À la fin de `onUpgrade`, après le bloc `from >= 7 && from < 8` :

```dart
          if (from < 9) {
            // Partie D : jours « rien à réviser » (série de l'Accueil).
            await m.createTable(quietDays);
          }
```

Dans `deleteEverything`, après `await delete(userColleges).go();` :

```dart
      await delete(quietDays).go();
```

Puis régénérer : `dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/database`
Expected: PASS (y compris `migration_v8_test.dart` et `pending_uploads_test.dart`).

- [ ] **Step 5: Commit**

```bash
git add collega_app/lib/core/database collega_app/test/core/database/migration_v9_test.dart
git commit -m "feat(accueil): table quiet_days et migration drift 8 → 9

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Noter les jours « rien à réviser » dans le dépôt de la session du jour

**Files:**
- Modify: `collega_app/lib/features/today/data/daily_session_repository.dart` (branche `if (plan.isEmpty)` de `_build`, `resetDay`, nouvelle méthode `quietDays`)
- Test: `collega_app/test/features/today/daily_session_repository_test.dart`

**Interfaces:**
- Consumes: `db.quietDays` (Task 1).
- Produces: `Future<Set<int>> DailySessionRepository.quietDays({required int from, required int to})` (bornes incluses, même convention que `completedDays`). La branche vide de `_build` insère le jour dans `quiet_days` **seulement si `custom == false`**.

- [ ] **Step 1: Write the failing test**

Ajouter à la fin de `main()` dans `collega_app/test/features/today/daily_session_repository_test.dart` (les variables `db`, `now`, `today` et le helper `_server` existent déjà dans ce fichier) :

```dart
  group('jours « rien à réviser » (série de l’Accueil)', () {
    test('session du jour vide : le jour est noté calme', () async {
      final repo = DailySessionRepository(db, clock: () => now);
      await repo.getOrBuild(day: today, budget: 24);
      expect(await repo.quietDays(from: today, to: today), {today});
    });

    test('Personnaliser sans aucune fiche : ce n’est pas un jour calme', () async {
      await syncCollegeCards(db, 'c1', [_server('a')]);
      final repo = DailySessionRepository(db, clock: () => now);
      await repo.rebuild(day: today, budget: 24, rangs: {'C'});
      expect(await repo.quietDays(from: today, to: today), isEmpty);
    });

    test('session avec des fiches : pas de jour calme', () async {
      await syncCollegeCards(db, 'c1', [_server('a')]);
      final repo = DailySessionRepository(db, clock: () => now);
      await repo.getOrBuild(day: today, budget: 24);
      expect(await repo.quietDays(from: today, to: today), isEmpty);
    });

    test('resetDay (outil de test) oublie aussi le jour calme', () async {
      final repo = DailySessionRepository(db, clock: () => now);
      await repo.getOrBuild(day: today, budget: 24);
      await repo.resetDay(today);
      expect(await repo.quietDays(from: today, to: today), isEmpty);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/today/daily_session_repository_test.dart`
Expected: FAIL à la compilation (`quietDays` n'existe pas).

- [ ] **Step 3: Write minimal implementation**

Dans `_build`, remplacer le début de la branche vide :

```dart
    if (plan.isEmpty) {
      // Rien à réviser : ne rien figer, la prochaine synchro pourra la remplir.
      await (db.delete(db.dailySessions)..where((t) => t.day.equals(day))).go();
```

par :

```dart
    if (plan.isEmpty) {
      // Rien à réviser : ne rien figer, la prochaine synchro pourra la remplir.
      await (db.delete(db.dailySessions)..where((t) => t.day.equals(day))).go();
      // Jour calme (série de l'Accueil) : pas un choix de « Personnaliser ».
      if (!custom) {
        await db.into(db.quietDays).insertOnConflictUpdate(QuietDaysCompanion.insert(day: Value(day)));
      }
```

Remplacer `resetDay` par :

```dart
  Future<void> resetDay(int day) => db.transaction(() async {
        await (db.delete(db.dailySessions)..where((t) => t.day.equals(day))).go();
        await (db.delete(db.reviewLog)..where((t) => t.day.equals(day) & t.daily.equals(true))).go();
        await (db.delete(db.quietDays)..where((t) => t.day.equals(day))).go();
      });
```

Ajouter après `completedDays` :

```dart
  /// Jours « rien à réviser » entre [from] et [to] inclus (série de l'Accueil).
  Future<Set<int>> quietDays({required int from, required int to}) async {
    final rows = await (db.select(db.quietDays)..where((t) => t.day.isBetweenValues(from, to))).get();
    return rows.map((r) => r.day).toSet();
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/today/daily_session_repository_test.dart`
Expected: PASS (tests existants compris).

- [ ] **Step 5: Commit**

```bash
git add collega_app/lib/features/today/data/daily_session_repository.dart collega_app/test/features/today/daily_session_repository_test.dart
git commit -m "feat(accueil): noter les jours sans fiche à réviser

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Calcul de la série (`streakLength`)

**Files:**
- Create: `collega_app/lib/features/today/domain/streak.dart`
- Test: `collega_app/test/features/today/streak_test.dart`

**Interfaces:**
- Produces: `int streakLength({required int today, required Set<int> completed, required Set<int> excused})`. Jours en epoch (`epochDayOf`). Constante `const kStreakMinShown = 2;` (seuil d'affichage du badge).

- [ ] **Step 1: Write the failing test**

`collega_app/test/features/today/streak_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/today/domain/streak.dart';

void main() {
  const t = 20000;

  int streak(Set<int> completed, {Set<int> excused = const {}}) =>
      streakLength(today: t, completed: completed, excused: excused);

  test('aucune session : 0', () => expect(streak({}), 0));

  test('aujourd’hui fait, rien avant : 1', () => expect(streak({t}), 1));

  test('aujourd’hui et les 2 jours d’avant : 3', () => expect(streak({t, t - 1, t - 2}), 3));

  test('aujourd’hui pas encore fait ne casse pas : on compte depuis hier', () {
    expect(streak({t - 1, t - 2}), 2);
  });

  test('un trou casse la série', () => expect(streak({t, t - 2, t - 3}), 1));

  test('hier manqué et aujourd’hui pas fait : 0', () => expect(streak({t - 2, t - 3}), 0));

  test('jour décalé ou calme : ne casse pas et ne compte pas', () {
    expect(streak({t, t - 2}, excused: {t - 1}), 2);
    expect(streak({t - 1, t - 3}, excused: {t - 2}), 2);
  });

  test('plusieurs jours excusés d’affilée', () {
    expect(streak({t, t - 4}, excused: {t - 1, t - 2, t - 3}), 2);
  });

  test('jour calme puis session faite le même jour : compté une fois', () {
    expect(streak({t, t - 1}, excused: {t}), 2);
  });

  test('seulement des jours excusés : 0', () => expect(streak({}, excused: {t - 1, t - 2}), 0));

  test('jours futurs ignorés', () => expect(streak({t + 1, t}), 1));

  test('seuil d’affichage du badge', () => expect(kStreakMinShown, 2));
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/today/streak_test.dart`
Expected: FAIL (fichier `streak.dart` introuvable).

- [ ] **Step 3: Write minimal implementation**

`collega_app/lib/features/today/domain/streak.dart` :

```dart
/// Série de l'Accueil (partie D) : badge « N jours d'affilée » à partir de 2.
const kStreakMinShown = 2;

/// Jours d'affilée avec une session du jour terminée, en remontant depuis
/// [today] (jours epoch).
///
/// - aujourd'hui non terminé ne casse pas : on compte alors depuis hier ;
/// - un jour [excused] (décalé, ou rien à réviser) ne casse pas et ne compte pas ;
/// - tout autre jour sans session terminée arrête la série.
int streakLength({required int today, required Set<int> completed, required Set<int> excused}) {
  if (completed.isEmpty) return 0;
  final oldest = completed.reduce((a, b) => a < b ? a : b);
  var count = completed.contains(today) ? 1 : 0;
  for (var day = today - 1; day >= oldest; day--) {
    if (completed.contains(day)) {
      count++;
    } else if (!excused.contains(day)) {
      break;
    }
  }
  return count;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/today/streak_test.dart`
Expected: PASS (12 tests).

- [ ] **Step 5: Commit**

```bash
git add collega_app/lib/features/today/domain/streak.dart collega_app/test/features/today/streak_test.dart
git commit -m "feat(accueil): calcul de la série de jours

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: `TodayReady.streak` calculé par `TodayNotifier`

**Files:**
- Modify: `collega_app/lib/features/today/today_providers.dart`
- Test: `collega_app/test/features/today/today_provider_test.dart`

**Interfaces:**
- Consumes: `streakLength` (Task 3), `DailySessionRepository.completedDays` (existant), `DailySessionRepository.quietDays` (Task 2), `PlanningState.postponedDays` (existant, `features/planning/planning_providers.dart`).
- Produces: champ `final int streak;` sur `TodayReady` (paramètre nommé optionnel `this.streak = 0`).

- [ ] **Step 1: Write the failing test**

Ajouter dans `main()` de `collega_app/test/features/today/today_provider_test.dart` (helpers `container`, `_status`, `_card`, `db`, `today`, `now` déjà présents ; `planningRepositoryProvider` et `PlanningConfig` sont déjà utilisés par le test « jour décalé ») :

```dart
  group('série (partie D)', () {
    Future<TodayReady> read(ProviderContainer c) async => await c.read(todayProvider.future) as TodayReady;

    Future<void> completeDay(int day) async {
      await db.into(db.dailySessions).insert(DailySessionsCompanion.insert(
            day: Value(day),
            queueJson: '[]',
            completedAtMs: Value(now.millisecondsSinceEpoch),
          ));
    }

    test('hier et avant-hier faits, aujourd’hui pas encore : 2', () async {
      final c = container(statuses: [_status(3, 'c3', a: 1)], server: {'c3': [_card('a', 'c3')]});
      await completeDay(today - 1);
      await completeDay(today - 2);
      expect((await read(c)).streak, 2);
    });

    test('un jour calme ne casse pas la série', () async {
      final c = container(statuses: [_status(3, 'c3', a: 1)], server: {'c3': [_card('a', 'c3')]});
      await completeDay(today - 1);
      await db.into(db.quietDays).insert(QuietDaysCompanion.insert(day: Value(today - 2)));
      await completeDay(today - 3);
      expect((await read(c)).streak, 2);
    });

    test('un jour décalé du planning ne casse pas la série', () async {
      final c = container(statuses: [_status(3, 'c3', a: 1)], server: {'c3': [_card('a', 'c3')]});
      final repo = c.read(planningRepositoryProvider);
      await repo.replace(PlanningConfig(
            id: 'cfg',
            collegeIds: const ['c3'],
            startDate: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 5)),
            endDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 20)),
            dailyMinutes: 20,
            createdAt: now,
          ));
      await completeDay(today - 1);
      await repo.addPostponed('cfg', today - 2);
      await completeDay(today - 3);
      expect((await read(c)).streak, 2);
    });

    test('aucune session faite : 0', () async {
      final c = container(statuses: [_status(3, 'c3', a: 1)], server: {'c3': [_card('a', 'c3')]});
      expect((await read(c)).streak, 0);
    });
  });
```

Ajouter en tête de fichier l'import drift s'il manque : `import 'package:drift/drift.dart' show Value;`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/today/today_provider_test.dart`
Expected: FAIL à la compilation (`streak` n'est pas un membre de `TodayReady`).

- [ ] **Step 3: Write minimal implementation**

Dans `today_providers.dart`, ajouter l'import :

```dart
import 'package:collega_app/features/today/domain/streak.dart';
```

Dans le constructeur de `TodayReady`, après `this.postponedToday = false,` :

```dart
    this.streak = 0,
```

et le champ, après `final bool postponedToday;` :

```dart
  /// Jours d'affilée avec la session du jour faite (sur ce téléphone), badge dès 2.
  final int streak;
```

Dans `TodayNotifier.build`, juste après `final done = await repo.completedDays(from: mondayDay, to: mondayDay + 6);` :

```dart
    // Série : tout l'historique local (une ligne par jour, peu de données).
    final streak = streakLength(
      today: day,
      completed: await repo.completedDays(from: 0, to: day),
      excused: {...await repo.quietDays(from: 0, to: day), ...planningState.postponedDays},
    );
```

et dans le `return TodayReady(...)`, après `postponedToday: ...,` :

```dart
      streak: streak,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/today/today_provider_test.dart`
Expected: PASS (tests existants compris).

- [ ] **Step 5: Commit**

```bash
git add collega_app/lib/features/today/today_providers.dart collega_app/test/features/today/today_provider_test.dart
git commit -m "feat(accueil): série exposée par l'état Aujourd'hui

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Widget `DoneCheck` (rond coché, animé une fois)

**Files:**
- Create: `collega_app/lib/features/today/presentation/done_check.dart`
- Test: `collega_app/test/features/today/done_check_test.dart`

**Interfaces:**
- Produces: `class DoneCheck extends StatefulWidget { const DoneCheck({super.key, required this.size, this.animate = false}); final double size; final bool animate; }`. Rond plein `colors.accent`, coche `CgIcons.check` couleur `colors.accentInk` (taille = `size * 0.55`). Si `animate` est vrai à la **création** et que les animations ne sont pas réduites : rebond (échelle 0.6 → 1.15 → 1) et coche révélée de gauche à droite, durée `DoneCheck.duration` (`CgMotion.slow * 2` = 800 ms), et un seul `CgHaptics.good()`. Un changement de `animate` après la création ne rejoue rien. Clés de test : `DoneCheck.scaleKey` sur le `Transform.scale`.

- [ ] **Step 1: Write the failing test**

`collega_app/test/features/today/done_check_test.dart` :

```dart
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/today/presentation/done_check.dart';

Widget _host(Widget child, {bool reduced = false}) => CgTheme(
      data: CgThemeData.light,
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Directionality(textDirection: TextDirection.ltr, child: Center(child: child)),
      ),
    );

double _scale(WidgetTester tester) =>
    tester.widget<Transform>(find.byKey(DoneCheck.scaleKey)).transform.getMaxScaleOnAxis();

void main() {
  late List<MethodCall> haptics;

  setUp(() {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
        return null;
      },
    );
  });

  testWidgets('sans animation : rond coché à sa taille finale, aucune vibration', (tester) async {
    await tester.pumpWidget(_host(const DoneCheck(size: 56)));
    expect(_scale(tester), 1.0);
    expect(haptics, isEmpty);
    expect(tester.getSize(find.byType(DoneCheck)), const Size(56, 56));
  });

  testWidgets('animé : rebondit puis se pose, une seule vibration', (tester) async {
    await tester.pumpWidget(_host(const DoneCheck(size: 56, animate: true)));
    expect(_scale(tester), lessThan(1.0));
    await tester.pump(DoneCheck.duration * 0.4);
    expect(_scale(tester), greaterThan(1.0));
    await tester.pumpAndSettle();
    expect(_scale(tester), 1.0);
    expect(haptics, hasLength(1));
  });

  testWidgets('réduction des animations : pas de rebond, pas de vibration', (tester) async {
    await tester.pumpWidget(_host(const DoneCheck(size: 56, animate: true), reduced: true));
    expect(_scale(tester), 1.0);
    await tester.pumpAndSettle();
    expect(haptics, isEmpty);
  });

  testWidgets('animate qui passe à vrai après coup : rien n’est rejoué', (tester) async {
    await tester.pumpWidget(_host(const DoneCheck(size: 56)));
    await tester.pumpWidget(_host(const DoneCheck(size: 56, animate: true)));
    expect(_scale(tester), 1.0);
    expect(haptics, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/today/done_check_test.dart`
Expected: FAIL (`done_check.dart` introuvable).

- [ ] **Step 3: Write minimal implementation**

`collega_app/lib/features/today/presentation/done_check.dart` :

```dart
import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/collega_ui.dart';

/// Rond coché de l'Accueil (partie D) : « Session faite » et jours faits de la
/// semaine. [animate] n'a d'effet qu'à la création : rebond, coche révélée de
/// gauche à droite et un retour haptique, une seule fois (jamais si les
/// animations sont réduites).
class DoneCheck extends StatefulWidget {
  const DoneCheck({super.key, required this.size, this.animate = false});

  final double size;
  final bool animate;

  static const duration = Duration(milliseconds: 800); // CgMotion.slow × 2
  static const scaleKey = ValueKey('done-check-scale');
  static const _checkRatio = 0.55;

  @override
  State<DoneCheck> createState() => _DoneCheckState();
}

class _DoneCheckState extends State<DoneCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: DoneCheck.duration);
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.15).chain(CurveTween(curve: CgMotion.out)), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: CgMotion.out)), weight: 20),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
  ]).animate(_controller);
  late final Animation<double> _reveal =
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.75, curve: Curves.easeOut));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.animate && !CgMotion.reduced(context)) {
      _controller.forward();
      CgHaptics.good();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Transform.scale(
          key: DoneCheck.scaleKey,
          scale: _scale.value,
          child: DecoratedBox(
            decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
            child: Center(
              child: ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: _reveal.value,
                  child: CgIcon(CgIcons.check, size: widget.size * DoneCheck._checkRatio, color: c.accentInk),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Note : `CgHaptics.good()` appelle `HapticFeedback.lightImpact()`, qui passe par `SystemChannels.platform` avec la méthode `HapticFeedback.vibrate` (argument `HapticFeedbackType.lightImpact`) : c'est ce que le test compte.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/today/done_check_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add collega_app/lib/features/today/presentation/done_check.dart collega_app/test/features/today/done_check_test.dart
git commit -m "feat(accueil): rond coché animé une fois

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Accueil — grand rond « Session faite », coches de la semaine, badge de série

**Files:**
- Modify: `collega_app/lib/features/today/presentation/today_screen.dart` (`_Hero`, `_Done`, `_Week`, nouveau `_StreakBadge`)
- Test: `collega_app/test/features/today/today_screen_test.dart`

**Interfaces:**
- Consumes: `DoneCheck` (Task 5), `TodayReady.streak` (Task 4), `kStreakMinShown` (Task 3).
- Produces: `_Hero` et `_Done` acceptent `bool celebrate` (utilisé en Task 7) ; `_Week` accepte `bool celebrate` (anime le rond d'aujourd'hui). Clés de test : `ValueKey('today-streak')` sur le badge.

- [ ] **Step 1: Write the failing test**

Dans `collega_app/test/features/today/today_screen_test.dart`, ajouter un paramètre `int streak = 0` à `_ready(...)` et le passer au constructeur (`streak: streak,`). Ajouter l'import :

```dart
import 'package:collega_app/features/today/presentation/done_check.dart';
```

Puis, dans `main()`, un groupe :

```dart
  group('session faite et série (partie D)', () {
    testWidgets('faite : grand rond coché + « 24 fiches »', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _Fixed(_ready(completed: true, verdicts: {'maitrise': 18, 'bien': 4, 'a_revoir': 2}))));
      await tester.pumpAndSettle();
      expect(find.byWidgetPredicate((w) => w is DoneCheck && w.size == 56), findsOneWidget);
      expect(find.text('24 fiches'), findsOneWidget);
      expect(find.text('Session faite'), findsOneWidget);
    });

    testWidgets('semaine : un rond coché par jour fait', (tester) async {
      _phone(tester, height: 1400);
      await tester.pumpWidget(_app(() => _Fixed(_ready(completed: true))));
      await tester.pumpAndSettle();
      // Le grand rond + le rond du lundi.
      expect(find.byType(DoneCheck), findsNWidgets(2));
    });

    testWidgets('badge « 5 jours d’affilée », session faite ou à faire', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(() => _Fixed(_ready(completed: true, streak: 5))));
      await tester.pumpAndSettle();
      expect(find.text('5 jours d’affilée'), findsOneWidget);

      await tester.pumpWidget(_app(() => _Fixed(_ready(streak: 5))));
      await tester.pumpAndSettle();
      expect(find.text('5 jours d’affilée'), findsOneWidget);
      expect(find.text('Commencer'), findsOneWidget);
    });

    testWidgets('série de 0 ou 1 : pas de badge', (tester) async {
      _phone(tester);
      for (final streak in [0, 1]) {
        await tester.pumpWidget(_app(() => _Fixed(_ready(completed: true, streak: streak))));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('today-streak')), findsNothing);
      }
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/today/today_screen_test.dart --exclude-tags golden`
Expected: FAIL (pas de `DoneCheck`, pas de « 24 fiches », pas de badge).

- [ ] **Step 3: Write minimal implementation**

Dans `today_screen.dart`, ajouter les imports :

```dart
import 'package:collega_app/features/today/domain/streak.dart';
import 'package:collega_app/features/today/presentation/done_check.dart';
```

`_readyChildren` passe le drapeau (valeur `false` pour l'instant, branchée en Task 7) :

```dart
  List<Widget> _readyChildren(BuildContext context, TodayReady s, {bool celebrate = false}) => [
        const SizedBox(height: _TodayScreenLayout.heroGap),
        _Hero(
          state: s,
          celebrate: celebrate,
          onStart: () => _start(s),
          onCustomize: () => showTodayCustomizeSheet(context, s),
        ),
        const CgSectionTitle('Cette semaine'),
        _Week(days: s.week, celebrate: celebrate),
```

(la suite de la liste est inchangée).

`_Hero` : ajouter le champ `final bool celebrate;` (constructeur `this.celebrate = false`), passer `_Done(state: state, celebrate: celebrate)`, et afficher le badge sous le nombre dans l'état « à faire / commencée ». Dans le `return Column(...)` final de `_Hero.build`, juste après le bloc `if (started) Padding(... 'Il reste ...')` :

```dart
      if (state.streak >= kStreakMinShown)
        Padding(
          padding: const EdgeInsets.only(top: CgSpace.s2),
          child: Align(alignment: Alignment.centerLeft, child: _StreakBadge(days: state.streak)),
        ),
```

Remplacer `_Done` par :

```dart
class _Done extends StatelessWidget {
  const _Done({required this.state, this.celebrate = false});

  final TodayReady state;
  final bool celebrate;

  static const _checkSize = 56.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final mastered = state.verdicts['maitrise'] ?? 0;
    final good = state.verdicts['bien'] ?? 0;
    final review = state.verdicts['a_revoir'] ?? 0;
    final cards = state.session.uniqueCount;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        DoneCheck(size: _checkSize, animate: celebrate),
        const SizedBox(width: CgSpace.s3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Semantics(header: true, child: Text('Session faite', style: CgType.title.copyWith(color: c.ink))),
            Text('$cards ${cards > 1 ? 'fiches' : 'fiche'}', style: CgType.bodyS.copyWith(color: c.ink2)),
          ]),
        ),
      ]),
      if (state.streak >= kStreakMinShown)
        Padding(
          padding: const EdgeInsets.only(top: CgSpace.s3),
          child: Align(alignment: Alignment.centerLeft, child: _StreakBadge(days: state.streak)),
        ),
      const SizedBox(height: CgSpace.s3),
      Text(
        '$mastered maîtrisées · $good bien · $review à revoir',
        style: CgType.bodyS.copyWith(color: c.ink2),
      ),
      const SizedBox(height: CgSpace.s3),
      CgRankBar(mastered: mastered, good: good, review: review, unseen: 0, size: CgRankBarSize.header),
      const SizedBox(height: CgSpace.s4),
      Text('Prochaine session demain', style: CgType.bodyS.copyWith(color: c.ink2)),
    ]);
  }
}

/// « 5 jours d’affilée » (partie D) : pastille `accentSoft`, dès 2 jours.
class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Container(
      key: const ValueKey('today-streak'),
      padding: const EdgeInsets.symmetric(horizontal: CgSpace.s3, vertical: CgSpace.s1),
      decoration: BoxDecoration(color: c.accentSoft, borderRadius: CgRadius.pill),
      child: Text('$days jours d’affilée', style: CgType.meta.copyWith(color: c.accent, fontWeight: FontWeight.w600)),
    );
  }
}
```

`_Week` : ajouter `this.celebrate = false` / `final bool celebrate;` et, pour un jour fait, remplacer le `DecoratedBox` par un `DoneCheck`. Dans `AspectRatio(aspectRatio: 1, child: ...)` :

```dart
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: d.done
                          ? LayoutBuilder(
                              builder: (context, box) => DoneCheck(
                                size: box.maxWidth,
                                animate: celebrate && d.isToday,
                              ),
                            )
                          : DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c.surface,
                                border: Border.all(
                                  color: d.isToday ? c.accent : c.line,
                                  width: d.isToday ? _todayBorder : _dotBorder,
                                ),
                              ),
                            ),
                    ),
```

Le libellé VoiceOver de la pastille (« lundi, aujourd’hui, session faite ») est inchangé : `DoneCheck` n'a pas de sémantique propre, elle est exclue par le `Semantics(excludeSemantics: true)` parent.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/today/today_screen_test.dart --exclude-tags golden`
Expected: PASS, y compris « faite : « Session faite », verdicts du jour… » et « 7 pastilles, lues par VoiceOver… ».

- [ ] **Step 5: Commit**

```bash
git add collega_app/lib/features/today/presentation/today_screen.dart collega_app/test/features/today/today_screen_test.dart
git commit -m "feat(accueil): grand rond coché, coches de la semaine et badge de série

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Animation jouée une seule fois au retour du drill

**Files:**
- Modify: `collega_app/lib/features/today/presentation/today_screen.dart` (`_TodayScreenState._start`, `build`)
- Test: `collega_app/test/features/today/today_screen_test.dart`

**Interfaces:**
- Consumes: `_Hero(celebrate:)`, `_Week(celebrate:)` (Task 6), `launchDrill` (existant, attend la fermeture du drill).
- Produces: champ privé `bool _celebrate` dans `_TodayScreenState`, vrai pendant **une** construction après un retour de drill où la session du jour est passée de « non terminée » à « terminée ».

- [ ] **Step 1: Write the failing test**

Dans `today_screen_test.dart` :

1. Dans `_app`, donner une clé à la route du drill :

```dart
    GoRoute(path: '/drill', builder: (_, s) { visited?.add('/drill'); return const SizedBox(key: Key('drill')); }),
```

2. Ajouter un notifier qui renvoie un état différent à chaque construction. `ref.invalidate` recrée le notifier (nouvelle instance via la fabrique d'`overrideWith`) : la file d'états est donc **partagée** entre les instances et consommée au fil des constructions :

```dart
class _Sequence extends TodayNotifier {
  _Sequence(this.states);

  /// Partagée entre instances : le premier état est retiré à chaque construction, le dernier reste.
  final List<TodayState> states;
  @override
  Future<TodayState> build() async => states.length > 1 ? states.removeAt(0) : states.first;
}
```

3. Ajouter le groupe :

```dart
  group('célébration au retour du drill (partie D)', () {
    bool animating(WidgetTester tester) =>
        tester.widgetList<DoneCheck>(find.byType(DoneCheck)).any((w) => w.animate);

    Future<void> finishDrill(WidgetTester tester) async {
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byKey(const Key('drill')))).pop();
      await tester.pump();
      await tester.pump();
    }

    testWidgets('session terminée pendant le drill : grand rond et rond du jour animés, une seule fois', (tester) async {
      _phone(tester, height: 1400);
      final states = <TodayState>[_ready(), _ready(completed: true)];
      await tester.pumpWidget(_app(() => _Sequence(states)));
      await tester.pumpAndSettle();
      await finishDrill(tester);
      expect(find.text('Session faite'), findsOneWidget);
      expect(tester.widgetList<DoneCheck>(find.byType(DoneCheck)).where((w) => w.animate), hasLength(2));

      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(() => _Fixed(_ready(completed: true))));
      await tester.pumpAndSettle();
      expect(animating(tester), isFalse);
    });

    testWidgets('drill quitté avant la fin : pas d’animation', (tester) async {
      _phone(tester, height: 1400);
      final states = <TodayState>[_ready(), _ready(position: 12)];
      await tester.pumpWidget(_app(() => _Sequence(states)));
      await tester.pumpAndSettle();
      await finishDrill(tester);
      expect(find.byType(DoneCheck), findsNothing);
    });

    testWidgets('Accueil ouvert sur une session déjà faite : pas d’animation', (tester) async {
      _phone(tester, height: 1400);
      await tester.pumpWidget(_app(() => _Fixed(_ready(completed: true))));
      await tester.pumpAndSettle();
      expect(animating(tester), isFalse);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/today/today_screen_test.dart --exclude-tags golden`
Expected: FAIL sur « session terminée pendant le drill » (aucun `DoneCheck` avec `animate` vrai).

- [ ] **Step 3: Write minimal implementation**

Dans `_TodayScreenState` :

```dart
  /// Vrai pendant une construction : la session du jour vient d'être terminée
  /// dans le drill (animation « Session faite », partie D).
  bool _celebrate = false;
```

Remplacer `_start` par :

```dart
  Future<void> _start(TodayReady state) async {
    final wasCompleted = state.session.isCompleted;
    await launchDrill(context, ref, DrillSessionParams.daily(state.session.day));
    // Au retour : progression, semaine et collèges ont pu changer.
    if (!mounted) return;
    ref.invalidate(todayProvider);
    final next = await ref.read(todayProvider.future);
    if (mounted && !wasCompleted && next is TodayReady && next.session.isCompleted) {
      setState(() => _celebrate = true);
    }
  }
```

Dans `build`, remplacer `TodayReady() => _readyChildren(context, state),` par :

```dart
        TodayReady() => _readyChildren(context, state, celebrate: _consumeCelebrate()),
```

et ajouter la méthode :

```dart
  /// La célébration ne vaut que pour la construction qui la montre : les
  /// `DoneCheck` créés à ce moment s'animent, les suivants non.
  bool _consumeCelebrate() {
    final celebrate = _celebrate;
    _celebrate = false;
    return celebrate;
  }
```

Les `DoneCheck` n'animent qu'à leur création (Task 5) : les reconstructions suivantes (`celebrate` faux) ne rejouent rien, et un nouvel Accueil ouvert sur une session déjà faite ne s'anime jamais.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/today/today_screen_test.dart --exclude-tags golden`
Expected: PASS (le test existant « « Commencer » lance le drill de la session du jour » aussi).

- [ ] **Step 5: Commit**

```bash
git add collega_app/lib/features/today/presentation/today_screen.dart collega_app/test/features/today/today_screen_test.dart
git commit -m "feat(accueil): animation « Session faite » au retour du drill

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Goldens, vérification par dossier, mémoire

**Files:**
- Modify: `collega_app/test/features/today/today_screen_test.dart` (golden `done` avec série), `collega_app/test/features/today/goldens/today_*.png` (régénérés)

**Interfaces:**
- Consumes: tout ce qui précède.

- [ ] **Step 1: Ajouter une série au golden « done »**

Dans le groupe `goldens` de `today_screen_test.dart`, remplacer la ligne `done` par :

```dart
      ('done', _ready(completed: true, verdicts: {'maitrise': 18, 'bien': 4, 'a_revoir': 2}, streak: 5)),
```

- [ ] **Step 2: Régénérer les goldens sur macOS**

Run : `flutter test test/features/today/today_screen_test.dart --update-goldens --tags golden`
Expected : `today_done_*` changent (grand rond, badge, coche du lundi). `today_ready_*` et `today_started_*` ne changent pas (aucune série, aucun jour fait). Ouvrir `today_done_393_10.png` et `today_done_375_16.png` et vérifier à l'œil : rond coché à gauche de « Session faite », badge « 5 jours d’affilée », coche blanche dans le rond du lundi, rien ne déborde en 1,6.

- [ ] **Step 3: Lancer les tests par dossier**

Run :
```bash
flutter test test/core
flutter test test/features/today
```
Expected : PASS partout. Si un autre dossier utilise `AppDatabase` (migration 9), lancer aussi `flutter test test/features/colleges` et `flutter test test/features/planning`.

- [ ] **Step 4: Analyse statique**

Run : `flutter analyze lib/features/today lib/core/database test/features/today test/core/database`
Expected : `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add collega_app/test/features/today
git commit -m "test(accueil): goldens de la session faite avec série

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 6: Mémoire du dépôt**

Appeler `kage_learn` (type `decision`) : série de l'Accueil calculée sur le téléphone (`streakLength`, `quiet_days` en schéma 9, jours décalés excusés, badge dès 2, animation une fois via `DoneCheck.animate` à la création), puis `kage_refresh`.

---

## Auto-revue

- **Couverture de la spec (section D)** : grand rond coché + « N fiches » → Task 6 ; coches de la semaine → Task 6 ; animation unique au retour, haptique, réduction des animations → Tasks 5 et 7 ; badge dès 2, aussi dans l'état « à faire » → Task 6 ; règles (aujourd'hui non fait, décalés, calmes) → Tasks 3 et 4 ; `quiet_days` et migration → Tasks 1 et 2 ; fonction pure testée → Task 3 ; goldens → Task 8. Limite « téléphone seulement » : aucune tâche serveur, voulu.
- **Placeholders** : aucun.
- **Cohérence des noms** : `streakLength`, `kStreakMinShown`, `quietDays(from:, to:)`, `QuietDays` / `QuietDaysCompanion` / `db.quietDays`, `DoneCheck(size:, animate:)`, `DoneCheck.scaleKey`, `DoneCheck.duration`, `TodayReady.streak`, `ValueKey('today-streak')` : identiques dans toutes les tâches.
- **Review Focus** : les 5 points ont leur test (Tasks 1, 2, 3, 7).

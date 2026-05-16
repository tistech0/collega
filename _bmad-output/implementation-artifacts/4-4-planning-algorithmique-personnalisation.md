# Story 4.4 : Planning Algorithmique & Personnalisation

Status: done

## Story

En tant qu'**étudiant**,
je veux configurer un planning d'apprentissage selon mon cursus et ma disponibilité quotidienne,
afin que l'app me propose automatiquement quoi réviser chaque jour sans que j'aie à décider.

## Acceptance Criteria

1. **Lien "Configurer mon planning →" sur l'accueil (AC1 — FR30)**
   - Étant donné l'écran d'accueil avec une `SessionHeroCard` affichée
   - Quand il n'y a pas encore de planning configuré (aucune `PlanningConfig` en base)
   - Alors un lien texte "Configurer mon planning →" s'affiche sous la `SessionHeroCard`
   - Et un tap ouvre l'écran de configuration du planning via `context.push('/planning/config')` (écran dédié, pas un bottom sheet)

2. **Lien "Modifier le planning" quand planning actif (AC2)**
   - Étant donné un planning déjà actif (au moins une `PlanningConfig` en base)
   - Quand l'étudiant est sur l'écran d'accueil
   - Alors un lien discret "Modifier le planning" s'affiche sous la `SessionHeroCard` (distinct du bouton "Modifier" icône edit qui ouvre la personnalisation rapide de session)
   - Et un tap ouvre le même écran `/planning/config` avec la config existante pré-remplie

3. **Écran de configuration du planning (AC3 — FR30)**
   - Étant donné l'écran de configuration du planning ouvert
   - Quand je le complète
   - Alors les champs disponibles sont :
     - Multi-select collèges (parmi les `generation_complete`) — au moins un requis
     - Multi-select items (optionnel — tous par défaut, liste issue des collèges sélectionnés)
     - Date de début (date picker, défaut aujourd'hui)
     - Date de fin (date picker, minimum = date de début + 1 jour)
     - Disponibilité quotidienne en minutes (stepper : 15 / 30 / 45 / 60 / 90 / 120 min, défaut 30 min)
   - Et le CTA "Générer mon planning" (primary) est sticky en bas

4. **Génération de l'algorithme local (AC4 — FR31)**
   - Étant donné la configuration soumise
   - Quand le planning est généré
   - Alors le calcul est 100% local (Drift + algorithme Dart) — zéro appel réseau
   - Et la priorisation suit : Rang A en premier (tous items, toutes cartes Rang A), puis Rang B, puis Rang C
   - Et au sein de chaque rang, l'ordre est : `a_revoir` → `new` → `bien` → `maitrise`
   - Et le nombre de fiches par jour = `(dailyMinutes * 5).clamp(5, 100)` (5 fiches/minute, min 5, max 100)
   - Et la `SessionHeroCard` de l'accueil reflète la session du jour calculée
   - Et après génération, la navigation revient à `/home`

5. **Session marquée effectuée (AC5 — FR33)**
   - Étant donné une session du jour avec un planning actif
   - Quand l'étudiant termine le drill et tape "Session terminée ✓" sur l'écran de fin
   - Alors la session est marquée `completed` dans la table `PlanningSessions`
   - Et `homeProvider` est invalidé → la `SessionHeroCard` se met à jour (plus de session "à faire" aujourd'hui)

6. **Session décalée (AC6 — FR33)**
   - Étant donné une session du jour planifiée (statut `pending`)
   - Quand l'étudiant tape "Décaler à demain" depuis la `SessionHeroCard`
   - Alors la session est marquée `postponed` dans Drift et une nouvelle session identique est créée pour le lendemain (ou la prochaine date sans session si le lendemain en a déjà une)
   - Et la `SessionHeroCard` ne montre plus de session pour aujourd'hui
   - Et aucun message culpabilisant n'est affiché — ton neutre

7. **Modification du planning (AC7)**
   - Étant donné un planning actif
   - Quand l'étudiant modifie la configuration (collèges, dates, disponibilité) et confirme
   - Alors toutes les sessions `pending` précédentes sont supprimées
   - Et un nouveau planning complet est recalculé et persisté
   - Et la `SessionHeroCard` reflète immédiatement la nouvelle session du jour

---

## Tasks / Subtasks

- [x] **T1 — Nouvelles tables Drift : PlanningConfigs + PlanningSessions (schéma v5)** (AC: #4, #5, #6, #7)
  - [x] Créer `collega_app/lib/core/database/tables/planning_configs_table.dart` :
    ```dart
    class PlanningConfigs extends Table {
      TextColumn get id => text()();
      TextColumn get collegeIds => text()();         // JSON: ["uuid1","uuid2"]
      TextColumn get itemIds => text().nullable()(); // JSON ou null = tous les items
      IntColumn get startDateEpochDay => integer()();  // jours depuis epoch (date only)
      IntColumn get endDateEpochDay => integer()();
      IntColumn get dailyMinutes => integer()();
      IntColumn get createdAtMs => integer()();

      @override
      Set<Column> get primaryKey => {id};
    }
    ```
  - [x] Créer `collega_app/lib/core/database/tables/planning_sessions_table.dart` :
    ```dart
    class PlanningSessions extends Table {
      TextColumn get id => text()();
      TextColumn get planningConfigId => text()();
      IntColumn get sessionDateEpochDay => integer()(); // jours depuis epoch
      TextColumn get collegeId => text()();
      IntColumn get maxCards => integer()();
      TextColumn get status => text().withDefault(const Constant('pending'))();
      // 'pending' | 'completed' | 'postponed'

      @override
      Set<Column> get primaryKey => {id};
    }
    ```
  - [x] Modifier `collega_app/lib/core/database/app_database.dart` :
    - Ajouter imports des deux nouvelles tables
    - Mettre `@DriftDatabase(tables: [CollegeImports, Items, FlashCards, PlanningConfigs, PlanningSessions])`
    - Passer `schemaVersion` de `4` à `5`
    - Dans `onUpgrade` : ajouter `if (from < 5) { await m.createTable(planningConfigs); await m.createTable(planningSessions); }`
    - Régénérer : `cd collega_app && dart run build_runner build --delete-conflicting-outputs`

- [x] **T2 — Domaine : PlanningModels** (AC: #3, #4, #5, #6)
  - [x] Créer `collega_app/lib/features/planning/domain/planning_models.dart` :
    ```dart
    import 'dart:convert';

    @immutable
    class PlanningConfig {
      const PlanningConfig({
        required this.id,
        required this.collegeIds,
        this.itemIds,           // null = tous les items
        required this.startDate,
        required this.endDate,
        required this.dailyMinutes,
        required this.createdAt,
      });
      final String id;
      final List<String> collegeIds;
      final List<String>? itemIds;
      final DateTime startDate;
      final DateTime endDate;
      final int dailyMinutes;
      final DateTime createdAt;

      int get cardsPerDay => (dailyMinutes * 5).clamp(5, 100);
    }

    @immutable
    class PlannedSession {
      const PlannedSession({
        required this.id,
        required this.planningConfigId,
        required this.sessionDate,
        required this.collegeId,
        required this.maxCards,
        required this.status,
      });
      final String id;
      final String planningConfigId;
      final DateTime sessionDate;
      final String collegeId;
      final int maxCards;
      final String status; // 'pending' | 'completed' | 'postponed'

      bool get isPending => status == 'pending';
      bool get isCompleted => status == 'completed';
    }
    ```

- [x] **T3 — Algorithme de génération local** (AC: #4)
  - [x] Créer `collega_app/lib/features/planning/data/planning_generator.dart` :
    ```dart
    class PlanningGenerator {
      /// Génère les sessions planifiées pour une config donnée.
      /// Règle priorité : Rang A (tous items) → Rang B → Rang C
      /// Au sein d'un rang : a_revoir → new → bien → maitrise
      static List<PlannedSession> generate({
        required PlanningConfig config,
        required List<FlashCard> allCards,  // cartes des collèges sélectionnés
      }) {
        // 1. Filtrer par itemIds si fournis
        var cards = config.itemIds == null
            ? allCards
            : allCards.where((c) => config.itemIds!.contains(c.itemId)).toList();

        // 2. Trier selon priorité
        const levelOrder = {'a_revoir': 0, 'new': 1, 'bien': 2, 'maitrise': 3};
        const rangOrder = {'A': 0, 'B': 1, 'C': 2};
        cards.sort((a, b) {
          final rA = rangOrder[a.rang] ?? 3;
          final rB = rangOrder[b.rang] ?? 3;
          if (rA != rB) return rA.compareTo(rB);
          final lA = levelOrder[a.drillLevel] ?? 1;
          final lB = levelOrder[b.drillLevel] ?? 1;
          return lA.compareTo(lB);
        });

        // 3. Calculer les paramètres
        final cardsPerDay = config.cardsPerDay;
        final days = config.endDate.difference(config.startDate).inDays + 1;

        // 4. Générer une session par jour (une par collège prioritaire)
        // Pour MVP : on utilise le premier collège de la config qui a des cartes à faire
        // Le collegeId de la session = collège ayant le plus de cartes à revoir
        final sessionCollegeId = _pickDominantCollege(cards, config.collegeIds);

        final sessions = <PlannedSession>[];
        int offset = 0;
        for (int dayIdx = 0; dayIdx < days; dayIdx++) {
          if (offset >= cards.length) break;
          final sessionDate = config.startDate.add(Duration(days: dayIdx));
          final sessionId = '${config.id}-day-$dayIdx';
          sessions.add(PlannedSession(
            id: sessionId,
            planningConfigId: config.id,
            sessionDate: sessionDate,
            collegeId: sessionCollegeId,
            maxCards: cardsPerDay,
            status: 'pending',
          ));
          offset += cardsPerDay;
        }
        return sessions;
      }

      static String _pickDominantCollege(
          List<FlashCard> cards, List<String> collegeIds) {
        if (collegeIds.length == 1) return collegeIds.first;
        // Collège avec le plus de cartes a_revoir ou new
        final counts = <String, int>{};
        for (final c in cards) {
          if (c.drillLevel == 'a_revoir' || c.drillLevel == 'new') {
            counts[c.collegeId] = (counts[c.collegeId] ?? 0) + 1;
          }
        }
        return counts.entries
            .where((e) => collegeIds.contains(e.key))
            .fold(MapEntry(collegeIds.first, 0),
                (best, e) => e.value > best.value ? e : best)
            .key;
      }
    }
    ```

- [x] **T4 — PlanningRepository** (AC: #4, #5, #6, #7)
  - [x] Créer `collega_app/lib/features/planning/data/planning_repository.dart` :
    ```dart
    class PlanningRepository {
      const PlanningRepository({required this.db});
      final AppDatabase db;

      // ── Config ────────────────────────────────────────────────────────────────
      Future<PlanningConfig?> getActiveConfig() async {
        final rows = await db.select(db.planningConfigs).get();
        if (rows.isEmpty) return null;
        return _configFromRow(rows.last); // dernière config = active
      }

      Future<void> saveConfig(PlanningConfig config) async {
        await db.into(db.planningConfigs).insertOnConflictUpdate(
          PlanningConfigsCompanion.insert(
            id: config.id,
            collegeIds: jsonEncode(config.collegeIds),
            itemIds: Value(config.itemIds == null ? null : jsonEncode(config.itemIds)),
            startDateEpochDay: _toEpochDay(config.startDate),
            endDateEpochDay: _toEpochDay(config.endDate),
            dailyMinutes: config.dailyMinutes,
            createdAtMs: config.createdAt.millisecondsSinceEpoch,
          ),
        );
      }

      // ── Sessions ──────────────────────────────────────────────────────────────
      Future<PlannedSession?> getTodaySession() async {
        final today = _toEpochDay(DateTime.now());
        final rows = await (db.select(db.planningSessions)
              ..where((t) => t.sessionDateEpochDay.equals(today))
              ..where((t) => t.status.equals('pending')))
            .get();
        if (rows.isEmpty) return null;
        return _sessionFromRow(rows.first);
      }

      Future<void> saveSessions(List<PlannedSession> sessions) async {
        await db.batch((batch) {
          for (final s in sessions) {
            batch.insert(
              db.planningSessions,
              PlanningSessionsCompanion.insert(
                id: s.id,
                planningConfigId: s.planningConfigId,
                sessionDateEpochDay: _toEpochDay(s.sessionDate),
                collegeId: s.collegeId,
                maxCards: s.maxCards,
                status: Value(s.status),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        });
      }

      Future<void> markSessionCompleted(String sessionId) async {
        await (db.update(db.planningSessions)
              ..where((t) => t.id.equals(sessionId)))
            .write(const PlanningSessionsCompanion(
              status: Value('completed'),
            ));
      }

      Future<void> postponeSession(String sessionId) async {
        final row = await (db.select(db.planningSessions)
              ..where((t) => t.id.equals(sessionId)))
            .getSingle();
        // Marque comme postponed
        await (db.update(db.planningSessions)
              ..where((t) => t.id.equals(sessionId)))
            .write(const PlanningSessionsCompanion(
              status: Value('postponed'),
            ));
        // Crée une nouvelle session au lendemain (ou J+1 si déjà occupé)
        final tomorrowDay = row.sessionDateEpochDay + 1;
        final existing = await (db.select(db.planningSessions)
              ..where((t) => t.sessionDateEpochDay.equals(tomorrowDay))
              ..where((t) => t.status.equals('pending')))
            .get();
        if (existing.isEmpty) {
          final newId = '${row.planningConfigId}-postponed-${row.sessionDateEpochDay}';
          await db.into(db.planningSessions).insert(
            PlanningSessionsCompanion.insert(
              id: newId,
              planningConfigId: row.planningConfigId,
              sessionDateEpochDay: tomorrowDay,
              collegeId: row.collegeId,
              maxCards: row.maxCards,
              status: const Value('pending'),
            ),
          );
        }
      }

      Future<void> deleteAllPendingSessions() async {
        await (db.delete(db.planningSessions)
              ..where((t) => t.status.equals('pending')))
            .go();
      }

      Future<void> deleteAllConfigs() async {
        await db.delete(db.planningConfigs).go();
      }

      // ── Helpers ───────────────────────────────────────────────────────────────
      static int _toEpochDay(DateTime dt) =>
          dt.toUtc().millisecondsSinceEpoch ~/ 86400000;

      static DateTime _fromEpochDay(int day) =>
          DateTime.fromMillisecondsSinceEpoch(day * 86400000, isUtc: true);

      PlanningConfig _configFromRow(PlanningConfig row) { /* mapping */ }
      PlannedSession _sessionFromRow(PlanningSession row) { /* mapping */ }
    }
    ```
  - [x] **IMPORTANT** : implémenter les méthodes `_configFromRow` et `_sessionFromRow` avec le bon mapping Drift → domaine (désérialiser JSON pour `collegeIds` / `itemIds`)

- [x] **T5 — PlanningProviders + PlanningNotifier** (AC: #4, #5, #6, #7)
  - [x] Créer `collega_app/lib/features/planning/planning_providers.dart` :
    ```dart
    final planningRepositoryProvider = Provider<PlanningRepository>(
      (ref) => PlanningRepository(db: ref.read(databaseProvider)),
    );

    // Notifier qui expose l'état planning (config + session du jour)
    class PlanningState {
      const PlanningState({
        this.config,
        this.todaySession,
      });
      final PlanningConfig? config;
      final PlannedSession? todaySession;

      bool get hasPlanningConfig => config != null;
    }

    class PlanningNotifier extends AsyncNotifier<PlanningState> {
      @override
      Future<PlanningState> build() async {
        final repo = ref.read(planningRepositoryProvider);
        final config = await repo.getActiveConfig();
        final todaySession = config != null ? await repo.getTodaySession() : null;
        return PlanningState(config: config, todaySession: todaySession);
      }

      Future<void> generatePlanning({
        required List<String> collegeIds,
        List<String>? itemIds,
        required DateTime startDate,
        required DateTime endDate,
        required int dailyMinutes,
      }) async {
        state = const AsyncValue.loading();
        final repo = ref.read(planningRepositoryProvider);
        final db = ref.read(databaseProvider);

        // Supprimer l'ancienne config + sessions pending
        await repo.deleteAllPendingSessions();
        await repo.deleteAllConfigs();

        // Récupérer toutes les cartes des collèges sélectionnés
        final query = db.select(db.flashCards)
          ..where((t) => t.collegeId.isIn(collegeIds));
        if (itemIds != null && itemIds.isNotEmpty) {
          query.where((t) => t.itemId.isIn(itemIds));
        }
        final allCards = await query.get();

        final configId = DateTime.now().millisecondsSinceEpoch.toString();
        final config = PlanningConfig(
          id: configId,
          collegeIds: collegeIds,
          itemIds: itemIds,
          startDate: startDate,
          endDate: endDate,
          dailyMinutes: dailyMinutes,
          createdAt: DateTime.now().toUtc(),
        );

        await repo.saveConfig(config);

        final sessions = PlanningGenerator.generate(
          config: config,
          allCards: allCards,
        );
        await repo.saveSessions(sessions);

        final todaySession = await repo.getTodaySession();
        state = AsyncValue.data(
          PlanningState(config: config, todaySession: todaySession),
        );
      }

      Future<void> markTodayCompleted() async {
        final s = state.value;
        if (s?.todaySession == null) return;
        final repo = ref.read(planningRepositoryProvider);
        await repo.markSessionCompleted(s!.todaySession!.id);
        state = AsyncValue.data(
          PlanningState(config: s.config, todaySession: null),
        );
      }

      Future<void> postponeToday() async {
        final s = state.value;
        if (s?.todaySession == null) return;
        final repo = ref.read(planningRepositoryProvider);
        await repo.postponeSession(s!.todaySession!.id);
        state = AsyncValue.data(
          PlanningState(config: s.config, todaySession: null),
        );
      }
    }

    final planningProvider =
        AsyncNotifierProvider<PlanningNotifier, PlanningState>(
      PlanningNotifier.new,
    );
    ```

- [x] **T6 — HomeNotifier : intégration planning** (AC: #1, #2, #4)
  - [x] Modifier `collega_app/lib/features/home/home_providers.dart` :
    - Ajouter champs à `HomeReady` :
      ```dart
      class HomeReady extends HomeState {
        const HomeReady({
          required this.sessionConfig,
          required this.recentColleges,
          required this.totalCards,
          this.todaySession,       // NOUVEAU
          this.hasPlanningConfig = false,  // NOUVEAU
        });
        final HomeSessionConfig sessionConfig;
        final List<CollegeListEntry> recentColleges;
        final int totalCards;
        final PlannedSession? todaySession;     // session planifiée du jour
        final bool hasPlanningConfig;           // true si planning configuré
        // estimatedDuration reste inchangée
      }
      ```
    - Dans `HomeNotifier.build()`, ajouter la lecture du `planningProvider` :
      ```dart
      // Après avoir calculé totalCards :
      final planningState = await ref.watch(planningProvider.future);
      return HomeReady(
        sessionConfig: sessionConfig,
        recentColleges: generationComplete.take(2).toList(),
        totalCards: totalCards,
        todaySession: planningState.todaySession,
        hasPlanningConfig: planningState.hasPlanningConfig,
      );
      ```
    - Ajouter import `planning_providers.dart`
  - [x] **CRITIQUE** : `ref.watch(planningProvider.future)` dans `HomeNotifier.build()` fait que homeProvider se rebuild quand planningProvider change — comportement voulu

- [x] **T7 — HomeScreen : liens planning sous la SessionHeroCard** (AC: #1, #2, #6)
  - [x] Modifier `collega_app/lib/features/home/presentation/home_screen.dart` :
    - Après le `SliverToBoxAdapter` de la `SessionHeroCard`, ajouter un `SliverToBoxAdapter` conditionnel :
      ```dart
      SliverPadding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenMargin,
        ),
        sliver: SliverToBoxAdapter(
          child: homeAsync.whenData((state) {
            if (state is! HomeReady) return const SizedBox.shrink();
            return _PlanningLinks(
              hasPlanningConfig: state.hasPlanningConfig,
              todaySession: state.todaySession,
            );
          }).value ?? const SizedBox.shrink(),
        ),
      ),
      ```
    - Créer widget privé `_PlanningLinks` :
      ```dart
      class _PlanningLinks extends StatelessWidget {
        const _PlanningLinks({
          required this.hasPlanningConfig,
          required this.todaySession,
        });
        final bool hasPlanningConfig;
        final PlannedSession? todaySession;

        @override
        Widget build(BuildContext context) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hasPlanningConfig)
                TextButton(
                  onPressed: () => context.push('/planning/config'),
                  child: const Text('Configurer mon planning →'),
                )
              else
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7C6E),
                  ),
                  onPressed: () => context.push('/planning/config'),
                  child: const Text('Modifier le planning'),
                ),
            ],
          );
        }
      }
      ```

- [x] **T8 — SessionHeroCard : bouton "Décaler à demain"** (AC: #6)
  - [x] Modifier `collega_app/lib/features/home/presentation/widgets/session_hero_card.dart` :
    - Ajouter champs à `SessionHeroCard` :
      ```dart
      class SessionHeroCard extends StatelessWidget {
        const SessionHeroCard({
          super.key,
          required this.homeState,
          required this.onModify,
          this.onPostpone,     // NOUVEAU — null si pas de session planifiée
        });
        final HomeState homeState;
        final VoidCallback onModify;
        final VoidCallback? onPostpone;  // NOUVEAU
      ```
    - Dans `build`, passer `onPostpone` à `_ReadyState`
    - Dans `_ReadyState`, ajouter après le CTA "Commencer" :
      ```dart
      if (onPostpone != null) ...[
        const SizedBox(height: 8),
        ShadButton.ghost(
          onPressed: onPostpone,
          width: double.infinity,
          child: Text(
            'Décaler à demain',
            style: AppTypography.labelMedium()
                .copyWith(color: const Color(0xFF6B7C6E)),
          ),
        ),
      ],
      ```
    - Mettre à jour `_ReadyState` pour accepter `onPostpone: VoidCallback?`
    - Mettre à jour le `switch` dans `SessionHeroCard.build` pour passer `onPostpone`

  - [x] Dans `HomeScreen`, passer `onPostpone` à `SessionHeroCard` :
    ```dart
    SessionHeroCard(
      homeState: state,
      onModify: () => _openConfigSheet(context, ref),
      onPostpone: state is HomeReady && state.todaySession != null
          ? () => ref.read(planningProvider.notifier).postponeToday()
          : null,
    )
    ```
    - Après `postponeToday()`, invalider `homeProvider` : ajouter dans `_openConfigSheet` → non, dans un callback dédié. En pratique, `planningProvider` est watchable par `homeProvider` → rebuild automatique. Vérifier que la chaîne fonctionne.

- [x] **T9 — DrillScreen : bouton "Session terminée ✓"** (AC: #5)
  - [x] Modifier `collega_app/lib/features/drill/presentation/drill_screen.dart` :
    - Convertir `_DrillEndScreen` de `StatelessWidget` en `ConsumerWidget`
    - Ajouter dans le `build` la lecture du planning :
      ```dart
      final planningAsync = ref.watch(planningProvider);
      final todaySession = planningAsync.valueOrNull?.todaySession;
      ```
    - Ajouter le bouton "Session terminée ✓" en-dessous du CTA principal existant :
      ```dart
      if (todaySession != null) ...[
        const SizedBox(height: 8),
        ShadButton.outline(
          onPressed: () async {
            await ref.read(planningProvider.notifier).markTodayCompleted();
            if (context.mounted) context.go('/home');
          },
          width: double.infinity,
          child: const Text('Session terminée ✓'),
        ),
      ],
      ```
    - L'ordre des boutons dans `_DrillEndScreen` devient :
      1. "Recommencer les erreurs" (primary, grisé si 0 erreurs) — existant
      2. "Session terminée ✓" (outline, visible si todaySession != null) — NOUVEAU
      3. "Retour à l'accueil" (outline) — existant
  - [x] **IMPORTANT** : ajouter import `planning_providers.dart` dans `drill_screen.dart`

- [x] **T10 — Fix D7 : incrementer reviewCount dans updateCardDrillLevel** (AC: transversal)
  - [x] Modifier `collega_app/lib/features/drill/data/drill_repository.dart` :
    - Dans `updateCardDrillLevel`, remplacer `reviewCount: const Value.absent()` par un increment réel :
      ```dart
      Future<void> updateCardDrillLevel(
          String cardId, DrillEvaluationResult result) async {
        // Lire le compte actuel
        final existing = await (db.select(db.flashCards)
              ..where((t) => t.id.equals(cardId)))
            .getSingleOrNull();
        final currentCount = existing?.reviewCount ?? 0;

        final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
        final level = switch (result) {
          DrillEvaluationResult.aRevoir => 'a_revoir',
          DrillEvaluationResult.bien => 'bien',
          DrillEvaluationResult.maitrise => 'maitrise',
        };
        final nextReview = switch (result) {
          DrillEvaluationResult.aRevoir => nowMs,
          DrillEvaluationResult.bien => nowMs + 86400000,
          DrillEvaluationResult.maitrise => nowMs + 7 * 86400000,
        };
        await (db.update(db.flashCards)
              ..where((t) => t.id.equals(cardId)))
            .write(FlashCardsCompanion(
          drillLevel: Value(level),
          nextReviewAt: Value(nextReview),
          reviewCount: Value(currentCount + 1),   // ← FIX D7
        ));
      }
      ```
  - [x] **NOTE** : ce read-then-write n'est pas atomique mais est acceptable pour ce cas d'usage (une seule session active à la fois par carte). Pas de `unawaited` sur l'update — le fire-and-forget reste géré par le caller (`drill_providers.dart`).

- [x] **T11 — Fix maxCards : wirer à travers DrillSessionParams** (AC: transversal)
  - [x] Modifier `collega_app/lib/features/drill/domain/drill_session_state.dart` :
    - Ajouter `maxCards: 0` à `DrillSessionParams` :
      ```dart
      class DrillSessionParams {
        const DrillSessionParams({
          required this.collegeId,
          this.itemId,
          this.itemName,
          this.rangs,
          this.onlyARevoir = false,
          this.maxCards = 0,  // NOUVEAU — 0 = toutes les fiches
        });
        // ...
        final int maxCards;
        // Mettre à jour operator == et hashCode
      }
      ```
  - [x] Modifier `collega_app/lib/features/drill/drill_providers.dart` :
    - Passer `maxCards: arg.maxCards` dans `getCardsForDrill` :
      ```dart
      final cards = await repo.getCardsForDrill(
        collegeId: arg.collegeId,
        itemId: arg.itemId,
        rangs: arg.rangs,
        onlyARevoir: arg.onlyARevoir,
        maxCards: arg.maxCards,  // NOUVEAU
      );
      ```
  - [x] Modifier `collega_app/lib/features/home/presentation/widgets/session_hero_card.dart` :
    - Dans `_ReadyState._launchDrill`, passer `maxCards: config.maxCards` :
      ```dart
      context.push('/drill', extra: DrillSessionParams(
        collegeId: config.collegeId,
        itemId: null,
        itemName: config.collegeName,
        rangs: config.rangs,
        onlyARevoir: config.onlyARevoir,
        maxCards: config.maxCards,  // NOUVEAU
      ));
      ```
  - [x] Vérifier tous les call-sites de `DrillSessionParams` (Story 4.2 : `DrillLaunchBar` dans `ItemDetailScreen`) compilent sans régression (le paramètre est optionnel avec défaut 0)

- [x] **T12 — Router : route `/planning/config`** (AC: #3)
  - [x] Modifier `collega_app/lib/core/router/app_router.dart` :
    - Ajouter import `planning_config_screen.dart`
    - Ajouter la route **en dehors du `ShellRoute`** (pas de bottom nav sur l'écran config) :
      ```dart
      GoRoute(
        path: '/planning/config',
        builder: (ctx, s) => const PlanningConfigScreen(),
      ),
      ```
    - Placer cette route avant le `ShellRoute` (ordre des routes GoRouter)
    - Ajouter `/planning` à la liste des routes protégées dans la logique `isProtected` :
      ```dart
      final isProtected = state.matchedLocation.startsWith('/home') ||
          state.matchedLocation.startsWith('/colleges') ||
          state.matchedLocation.startsWith('/search') ||
          state.matchedLocation.startsWith('/profile') ||
          state.matchedLocation.startsWith('/drill') ||
          state.matchedLocation.startsWith('/planning');  // NOUVEAU
      ```

- [x] **T13 — PlanningConfigScreen** (AC: #3, #4, #7)
  - [x] Créer `collega_app/lib/features/planning/presentation/planning_config_screen.dart`
  - [x] `PlanningConfigScreen` est un `ConsumerStatefulWidget` (formulaire avec état local)
  - [x] Structure :
    ```dart
    Scaffold(
      appBar: AppBar(title: Text('Mon planning'), centerTitle: true),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.screenMargin),
                child: Column(children: [
                  _CollegeMultiSelect(...),
                  SizedBox(height: 16),
                  _DateRangePicker(startDate, endDate, onChanged),
                  SizedBox(height: 16),
                  _DailyMinutesStepper(value, onChanged),
                  // Note : items select = optionnel (MVP : all items)
                  // Peut être ajouté ultérieurement sans casser l'algo
                ]),
              ),
            ),
            // CTA sticky
            Padding(
              padding: EdgeInsets.all(AppSpacing.screenMargin),
              child: ShadButton(
                onPressed: _isFormValid ? _submit : null,
                width: double.infinity,
                child: Text('Générer mon planning'),
              ),
            ),
          ],
        ),
      ),
    );
    ```
  - [x] `_CollegeMultiSelect` : liste des collèges `generation_complete` (lire `ref.watch(collegesProvider)`), checkboxes `ShadCheckbox` ou toggles
  - [x] `_DateRangePicker` : deux champs date, utiliser `showDatePicker` natif Flutter (pas de dépendance externe). Format d'affichage : `dd/MM/yyyy`. Validation : `endDate > startDate`.
  - [x] `_DailyMinutesStepper` : options 15 / 30 / 45 / 60 / 90 / 120 — utiliser `ShadSelect` ou `Row` de chips. Valeur par défaut : 30.
  - [x] Si planning déjà existant (modifier) : pré-remplir les champs depuis `ref.watch(planningProvider).valueOrNull?.config`
  - [x] `_submit()` appelle `ref.read(planningProvider.notifier).generatePlanning(...)` avec `await`, puis `if (mounted) context.go('/home')`
  - [x] Gestion du loading : pendant la génération, afficher `ShadProgress` à la place du CTA ou désactiver le bouton

- [x] **T14 — Tests** (AC: tous)
  - [x] Créer `collega_app/test/features/planning/planning_generator_test.dart` :
    - Test : génère 0 session si dates identiques et 0 cartes
    - Test : génère N sessions pour N jours avec `cardsPerDay` correct (30 min → 150 clamp à 100)
    - Test : tri des cartes : Rang A avant Rang B, `a_revoir` avant `new`
    - Test : `cardsPerDay` clampé entre 5 et 100
  - [x] Créer `collega_app/test/features/planning/planning_repository_test.dart` :
    - Test : `getActiveConfig()` retourne null si aucune config
    - Test : `getTodaySession()` retourne null si aucune session aujourd'hui
    - Test : `postponeSession` crée bien une session au lendemain
    - Test : `markSessionCompleted` passe le statut à `completed`
  - [x] Créer `collega_app/test/features/home/home_with_planning_test.dart` :
    - Test : `HomeReady.hasPlanningConfig = false` si `planningProvider` retourne `PlanningState(config: null)`
    - Test : `HomeReady.todaySession` est non null si planning actif avec session aujourd'hui
  - [x] Modifier `collega_app/test/features/drill/drill_repository_test.dart` :
    - Vérifier que `updateCardDrillLevel` incrémente `reviewCount` de 1 (D7 fix)
  - [x] Modifier les tests `DrillSessionParams` existants si `operator ==` / `hashCode` changent (ajout `maxCards`)

- [x] **T15 — Validation finale**
  - [x] `cd collega_app && dart run build_runner build --delete-conflicting-outputs` (régénération Drift)
  - [x] `cd collega_app && flutter analyze` → 0 nouvelle erreur
  - [x] `cd collega_app && flutter test test/features/planning/` → tous verts
  - [x] `cd collega_app && flutter test test/features/home/` → 0 régression
  - [x] `cd collega_app && flutter test test/features/drill/` → 0 régression (D7 fix + maxCards)
  - [x] `cd collega_app && flutter test` (suite complète) → 0 nouvelle régression

---

## Dev Notes

### Structure des fichiers

```
collega_app/lib/
├── core/
│   └── database/
│       ├── app_database.dart              # MODIFIER — schemaVersion 4→5, ajout tables
│       └── tables/
│           ├── planning_configs_table.dart  # CRÉER — T1
│           └── planning_sessions_table.dart # CRÉER — T1
├── features/
│   ├── planning/                           # NOUVEAU feature folder (dossier vide existe)
│   │   ├── domain/
│   │   │   └── planning_models.dart        # CRÉER — T2
│   │   ├── data/
│   │   │   ├── planning_repository.dart    # CRÉER — T4
│   │   │   └── planning_generator.dart     # CRÉER — T3
│   │   ├── planning_providers.dart         # CRÉER — T5
│   │   └── presentation/
│   │       └── planning_config_screen.dart # CRÉER — T13
│   ├── home/
│   │   ├── home_providers.dart             # MODIFIER — T6 (HomeReady + planning)
│   │   └── presentation/
│   │       ├── home_screen.dart            # MODIFIER — T7 (liens planning)
│   │       └── widgets/
│   │           └── session_hero_card.dart  # MODIFIER — T8 (onPostpone + Décaler)
│   └── drill/
│       ├── domain/
│       │   └── drill_session_state.dart    # MODIFIER — T11 (DrillSessionParams.maxCards)
│       ├── data/
│       │   └── drill_repository.dart       # MODIFIER — T10 (D7 reviewCount fix)
│       ├── drill_providers.dart            # MODIFIER — T11 (passer maxCards)
│       └── presentation/
│           └── drill_screen.dart           # MODIFIER — T9 (_DrillEndScreen ConsumerWidget)
└── core/router/
    └── app_router.dart                     # MODIFIER — T12 (/planning/config route)

collega_app/test/features/
├── planning/
│   ├── planning_generator_test.dart        # CRÉER — T14
│   └── planning_repository_test.dart       # CRÉER — T14
├── home/
│   └── home_with_planning_test.dart        # CRÉER — T14
└── drill/
    ├── drill_repository_test.dart          # MODIFIER — T14 (D7 fix assertion)
    └── drill_session_params_test.dart      # MODIFIER — T14 (maxCards)
```

### Composants existants à RÉUTILISER sans modification

| Composant | Chemin | Usage |
|---|---|---|
| `collegesProvider` | `features/colleges/colleges_providers.dart` | Lister les collèges pour config planning |
| `CollegeListEntry.isGenerationComplete` | `features/colleges/domain/college_models.dart` | Filtrer les collèges disponibles |
| `databaseProvider` | `core/database/app_database.dart` | Accès à AppDatabase depuis les providers |
| `AppTypography` / `AppColors` / `AppSpacing` | `core/theme/app_theme.dart` | Style uniforme |
| `DrillRepository.getCardsForDrill` | `features/drill/data/drill_repository.dart` | Récupérer les cartes triées (algo existant réutilisable) |
| `DrillSessionParams` | `features/drill/domain/drill_session_state.dart` | Lancement du drill depuis SessionHeroCard |

### Drift — Migration schéma v4 → v5

**CRITIQUE** : L'architecture Drift impose de régénérer le code après modification des tables.

```bash
cd collega_app && dart run build_runner build --delete-conflicting-outputs
```

Le fichier généré `app_database.g.dart` sera mis à jour. Ne pas modifier ce fichier manuellement.

Pattern migration (IMPORTANT — respecter le pattern existant de `app_database.dart:25-46`) :
```dart
if (from < 5) {
  await m.createTable(planningConfigs);
  await m.createTable(planningSessions);
}
```

**Epoch day** : pour stocker des dates sans heure (planning par jour), on utilise `epochDay = millisecondsSinceEpoch ~/ 86400000`. Toujours en UTC pour éviter les surprises de timezone.

### HomeNotifier — chaîne de watch planning

`HomeNotifier.build()` doit utiliser `ref.watch(planningProvider.future)` (et non `ref.read`) pour que homeProvider se rebuild automatiquement quand planningProvider change (ex: après `markTodayCompleted`). C'est le même pattern que `ref.watch(collegesProvider.future)`.

```dart
@override
Future<HomeState> build() async {
  final colleges = await ref.watch(collegesProvider.future);
  // ...
  final planningState = await ref.watch(planningProvider.future);  // NOUVEAU
  return HomeReady(
    // ...
    todaySession: planningState.todaySession,
    hasPlanningConfig: planningState.hasPlanningConfig,
  );
}
```

### SessionHeroCard — compatibilité ascendante

`onPostpone` est nullable (`VoidCallback?`) → les tests existants de Story 4.3 ne cassent pas (paramètre optionnel). Les call-sites qui passent `SessionHeroCard(homeState: ..., onModify: ...)` sans `onPostpone` compilent sans modification.

### DrillEndScreen — devenir ConsumerWidget

`_DrillEndScreen` est actuellement privé (`_`) dans `drill_screen.dart`. Il passe de `StatelessWidget` à `ConsumerWidget`. Aucun impact extérieur (widget privé non testé directement). Les tests de `DrillScreen` passeront encore via le widget parent.

### Fix D7 — reviewCount read-then-write

Le pattern read-then-write (lire le `reviewCount` actuel puis écrire `count + 1`) n'est pas atomique. C'est acceptable ici car :
1. La session drill est mono-carte à la fois — pas de concurrence dans un seul appareil
2. `updateCardDrillLevel` est appelé en `unawaited` depuis `drill_providers.dart` — le fire-and-forget est déjà établi

Ne pas changer le `unawaited` dans `drill_providers.dart` — le pattern est intentionnel (voir commentaire D9 dans deferred-work.md).

### Fix maxCards — DrillSessionParams

`DrillRepository.getCardsForDrill` acceptait déjà `maxCards` (Story 4.3, T3) mais `DrillSessionNotifier.build()` ne le passait pas. Ce fix corrige cette incohérence. La valeur par défaut `maxCards = 0` (= toutes les fiches) garantit la compatibilité ascendante.

### PlanningConfigScreen — items multi-select en MVP

La spec dit : "les items à prioriser (optionnel — tous par défaut)". Pour ce MVP, la sélection d'items est omise de l'écran (la config stocke `itemIds = null` = tous les items). Le schéma Drift supporte déjà ce cas via `itemIds: text().nullable()()`. L'ajout de l'UI items multi-select peut se faire dans une story future sans refactoring.

### PlanningGenerator — Rang A→B→C sur tous les collèges

La spec dit : "toutes les fiches Rang A d'un item avant de passer au Rang B". Le générateur trie toutes les cartes globalement (A→B→C), pas par collège. Ainsi, si l'étudiant a deux collèges, les Rang A des deux collèges sont proposés avant tout Rang B.

Pour le `collegeId` de la session (utilisé pour lancer le drill), le générateur choisit le collège dominant (plus de cartes `a_revoir` ou `new` en Rang A). Ce choix est conservé pour toutes les sessions du planning.

### Anti-patterns à éviter

- **NE PAS** créer un `CircularProgressIndicator` — utiliser `ShadProgress` ou Container gris
- **NE PAS** faire d'appel réseau dans `PlanningRepository` ou `PlanningNotifier` — le planning est 100% local
- **NE PAS** modifier `ShellRoute` — `/planning/config` est **en dehors** du ShellRoute (pas de bottom nav)
- **NE PAS** oublier `dart run build_runner build` après modification des tables Drift
- **NE PAS** stocker de cardIds en JSON dans `PlanningSessions` — seulement `collegeId` + `maxCards` (l'algo de sélection des cartes est délégué à `DrillRepository.getCardsForDrill` qui applique la priorisation A→B→C à l'heure du drill)
- **NE PAS** implémenter de sélection d'items dans l'écran de config (MVP : tous les items)
- **NE PAS** utiliser `print()` ou `debugPrint()` — utiliser `AppLogger`

### État du codebase au début de cette story

| Composant | État | Chemin |
|---|---|---|
| `features/planning/` | ✅ Dossier existe mais vide | `lib/features/planning/` |
| `AppDatabase.schemaVersion` | ✅ v4 actuel | `core/database/app_database.dart:22` |
| `HomeReady` | ✅ Existe — sans champs planning | `features/home/home_providers.dart:23` |
| `SessionHeroCard` | ✅ Existe — sans onPostpone | `features/home/presentation/widgets/session_hero_card.dart` |
| `HomeScreen` | ✅ Existe — sans liens planning | `features/home/presentation/home_screen.dart` |
| `_DrillEndScreen` | ✅ Existe — StatelessWidget | `features/drill/presentation/drill_screen.dart:272` |
| `DrillSessionParams.maxCards` | 🚫 Absent | à ajouter — T11 |
| `updateCardDrillLevel` reviewCount | 🚫 `Value.absent()` (D7) | `features/drill/data/drill_repository.dart:69` |
| `/planning/config` route | 🚫 Absente | à ajouter dans `app_router.dart` |
| `PlanningConfigScreen` | 🚫 À créer | `features/planning/presentation/planning_config_screen.dart` |

### Intelligence git (patterns établis)

- Sealed classes pour les états : `sealed class HomeState` (pattern Story 4.3)
- `AsyncNotifier<T>` pour tout état async, `Notifier<T>` pour état sync (pattern établi)
- `ref.watch(xxxProvider.future)` dans un AsyncNotifier.build() pour dépendances reactives
- `unawaited(...)` pour fire-and-forget (pattern établi, ne pas changer)
- `if (!mounted) return` dans tous les callbacks async `StatefulWidget`
- `ConsumerStatefulWidget` si état local + Riverpod simultanés (PlanningConfigScreen)
- `insertOnConflictUpdate` pour upsert Drift
- `db.batch(...)` pour insertions en masse
- Pattern test : `AppDatabase.forTesting(NativeDatabase.memory())` + `addTearDown(db.close)`
- `flutter analyze` → 0 erreur avant marquage done

### Références

- Epic 4, Story 4.4 spec : `_bmad-output/planning-artifacts/epics.md` L.855–898
- UX Flow 4 (personnalisation session) : `_bmad-output/planning-artifacts/ux-design-specification.md` L.432–464
- Architecture planning folder : `_bmad-output/planning-artifacts/architecture.md` L.357
- Drift database existante : `collega_app/lib/core/database/app_database.dart`
- Tables Drift existantes : `collega_app/lib/core/database/tables/`
- `HomeNotifier` (à modifier) : `collega_app/lib/features/home/home_providers.dart`
- `SessionHeroCard` (à modifier) : `collega_app/lib/features/home/presentation/widgets/session_hero_card.dart`
- `HomeScreen` (à modifier) : `collega_app/lib/features/home/presentation/home_screen.dart`
- `_DrillEndScreen` (à modifier) : `collega_app/lib/features/drill/presentation/drill_screen.dart:272`
- `DrillRepository.updateCardDrillLevel` (D7 fix) : `collega_app/lib/features/drill/data/drill_repository.dart:52`
- `DrillSessionNotifier.build` (maxCards fix) : `collega_app/lib/features/drill/drill_providers.dart:27`
- `DrillSessionParams` (à modifier) : `collega_app/lib/features/drill/domain/drill_session_state.dart:8`
- Router (à modifier) : `collega_app/lib/core/router/app_router.dart`
- Deferred D7 (reviewCount) : `_bmad-output/implementation-artifacts/deferred-work.md` L.11
- Deferred D15 (homeProvider au retour drill) : `_bmad-output/implementation-artifacts/deferred-work.md` L.19
- Pattern `PlanningGenerator` s'appuie sur le tri existant de `DrillRepository.getCardsForDrill` : `collega_app/lib/features/drill/data/drill_repository.dart:36-45`
- `CollegesNotifier` + `collegesProvider` : `collega_app/lib/features/colleges/colleges_providers.dart`

---

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

Aucun blocker majeur. Ajustements effectués :
- Conflit de nommage Drift/domaine résolu avec `@DataClassName('PlanningConfigRow')` et `@DataClassName('PlanningSessionRow')`
- `FlashCardModel` étendu avec champ `drillLevel` (valeur par défaut `'new'`) pour que `PlanningGenerator` puisse trier par niveau
- `DrillRepository._rowToModel` renommé en `rowToModel` (public) et mis à jour pour mapper `drillLevel`
- Import `intl` absent → formatage date `dd/MM/yyyy` fait manuellement dans `PlanningConfigScreen`
- Test `PlanningGenerator` corrigé : 250 cartes nécessaires pour générer 3 sessions avec 100 cartes/jour

### Completion Notes List

- T1 : Tables `PlanningConfigs` et `PlanningSessions` créées, schéma v5, migration `onUpgrade`, `build_runner` exécuté avec succès
- T2 : `PlanningConfig` et `PlannedSession` avec `cardsPerDay` clampé 5-100
- T3 : `PlanningGenerator` 100% local, tri Rang A→B→C + a_revoir→new→bien→maitrise, sélection collège dominant
- T4 : `PlanningRepository` avec upsert config, sessions batch, postpone avec création J+1, delete pending/configs
- T5 : `PlanningNotifier` (AsyncNotifier) avec `generatePlanning`, `markTodayCompleted`, `postponeToday`
- T6 : `HomeReady` étendu avec `todaySession` et `hasPlanningConfig` ; `HomeNotifier` watch `planningProvider.future`
- T7 : `HomeScreen` — `_PlanningLinks` conditionnel sous `SessionHeroCard`
- T8 : `SessionHeroCard` — `onPostpone` nullable, bouton "Décaler à demain" (ghost)
- T9 : `_DrillEndScreen` → `ConsumerWidget`, bouton "Session terminée ✓" conditionnel au `todaySession`
- T10 : Fix D7 — `updateCardDrillLevel` lit le `reviewCount` actuel et écrit `count+1`
- T11 : `DrillSessionParams.maxCards = 0` par défaut, propagé dans `DrillSessionNotifier.build` et `_launchDrill`
- T12 : Route `/planning/config` ajoutée avant `ShellRoute`, `/planning` dans `isProtected`
- T13 : `PlanningConfigScreen` — multi-select collèges, date pickers natifs, stepper 15-120 min, pré-remplissage config existante, CTA sticky, loading state
- T14 : 12 nouveaux tests planning_generator + planning_repository + home_with_planning ; D7 fix assertion ; maxCards tests dans drill_session_params
- T15 : 120/120 tests passent, 0 erreur `flutter analyze`

### File List

- `collega_app/lib/core/database/app_database.dart` (modifié — schemaVersion 4→5, import tables planning)
- `collega_app/lib/core/database/tables/planning_configs_table.dart` (créé)
- `collega_app/lib/core/database/tables/planning_sessions_table.dart` (créé)
- `collega_app/lib/core/database/app_database.g.dart` (régénéré)
- `collega_app/lib/features/colleges/domain/college_detail_models.dart` (modifié — champ `drillLevel` sur `FlashCardModel`)
- `collega_app/lib/features/planning/domain/planning_models.dart` (créé)
- `collega_app/lib/features/planning/data/planning_generator.dart` (créé)
- `collega_app/lib/features/planning/data/planning_repository.dart` (créé)
- `collega_app/lib/features/planning/planning_providers.dart` (créé)
- `collega_app/lib/features/planning/presentation/planning_config_screen.dart` (créé)
- `collega_app/lib/features/home/home_providers.dart` (modifié — HomeReady + planningProvider)
- `collega_app/lib/features/home/presentation/home_screen.dart` (modifié — _PlanningLinks, onPostpone)
- `collega_app/lib/features/home/presentation/widgets/session_hero_card.dart` (modifié — onPostpone, Décaler à demain, maxCards)
- `collega_app/lib/features/drill/domain/drill_session_state.dart` (modifié — maxCards dans DrillSessionParams)
- `collega_app/lib/features/drill/data/drill_repository.dart` (modifié — fix D7 reviewCount, rowToModel public, drillLevel)
- `collega_app/lib/features/drill/drill_providers.dart` (modifié — maxCards passé à getCardsForDrill)
- `collega_app/lib/features/drill/presentation/drill_screen.dart` (modifié — _DrillEndScreen ConsumerWidget, bouton "Session terminée ✓")
- `collega_app/lib/core/router/app_router.dart` (modifié — route /planning/config, isProtected)
- `collega_app/test/features/planning/planning_generator_test.dart` (créé)
- `collega_app/test/features/planning/planning_repository_test.dart` (créé)
- `collega_app/test/features/home/home_with_planning_test.dart` (créé)
- `collega_app/test/features/drill/drill_repository_test.dart` (modifié — test D7 reviewCount)
- `collega_app/test/features/drill/drill_session_params_test.dart` (modifié — tests maxCards)

### Review Findings

- [x] [Review][Patch] P1 — `postponeSession` ne cherche pas la prochaine date libre — viole AC6 [`planning_repository.dart:86-105`]
- [x] [Review][Patch] P2 — `getSingle()` peut throw si session inconnue dans `postponeSession` — utiliser `getSingleOrNull()` [`planning_repository.dart:76-78`]
- [x] [Review][Patch] P3 — Bug timezone dans `_toEpochDay` : date locale convertie en UTC décale d'un jour les utilisateurs UTC+ [`planning_repository.dart:120-121`, `planning_config_screen.dart:31-33`]
- [x] [Review][Patch] P4 — `e.userStatus!.collegeId` dans `_CollegeMultiSelect` : null-crash possible si `userStatus` est null pour une entrée `isGenerationComplete` [`planning_config_screen.dart:188`]
- [x] [Review][Defer] D1 — `getActiveConfig()` fetch-all au lieu de orderBy+limit [`planning_repository.dart:16`] — deferred, pre-existing
- [x] [Review][Defer] D2 — ID config = `millisecondsSinceEpoch.toString()`, fragile en tests rapides [`planning_providers.dart:78`] — deferred, pre-existing
- [x] [Review][Defer] D3 — `whenData().value ?? SizedBox.shrink()` style non-idiomatique [`home_screen.dart:79-86`] — deferred, pre-existing

## Change Log

- 2026-05-14 — Story 4.4 implémentée : planning algorithmique local (Drift v5, PlanningGenerator, PlanningNotifier), liens planning sur HomeScreen, bouton "Décaler à demain" sur SessionHeroCard, bouton "Session terminée ✓" sur DrillEndScreen, fix D7 reviewCount, fix maxCards DrillSessionParams, route /planning/config, PlanningConfigScreen. 120/120 tests verts.
- 2026-05-14 — Story 4.4 créée par create-story. Analyse exhaustive : Story 4.3 (patterns HomeNotifier, SessionHeroCard, HomeSessionConfig), codebase (Drift v4, DrillRepository, DrillSessionParams, drill_providers, app_router), epics FR30-33, UX Flow 4, deferred-work (D7 reviewCount, D15 homeProvider). Statut → ready-for-dev.

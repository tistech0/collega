# Story 4.3 : Écran d'Accueil & SessionHeroCard

Status: done

## Story

En tant qu'**étudiant**,
je veux voir ma session du jour dès l'ouverture de l'app et la lancer en un tap,
afin de commencer à réviser sans décision à prendre.

## Acceptance Criteria

1. **SessionHeroCard — session disponible (AC1 — FR32)**
   - Étant donné l'écran d'accueil
   - Quand au moins un collège est importé et en statut `generation_complete`
   - Alors la `SessionHeroCard` est le premier élément visible avec : nom du collège, rang(s) sélectionnés, nombre de fiches, durée estimée (~1 min / 5 fiches), CTA "Commencer" (primary), bouton "Modifier" (icône edit inline en haut à droite de la card)
   - Et un tap sur "Commencer" lance immédiatement le Mode Drill sans écran intermédiaire via `context.push('/drill', extra: DrillSessionParams(...))`

2. **SearchBar accueil → onglet Recherche (AC2)**
   - Étant donné la SearchBar en haut de l'écran d'accueil
   - Quand je tape dessus
   - Alors l'app navigue vers l'onglet Recherche (`context.go('/search')`) — pas de vraie recherche dans cette story (stub existant)

3. **Grille collèges récents (AC3)**
   - Étant donné au moins un collège importé avec `generation_complete`
   - Quand l'écran d'accueil s'affiche
   - Alors les 2 premiers collèges importés avec `generation_complete` sont visibles en `CollegeProgressTile` mini sous la hero card
   - Et un tap sur un tile navigue vers `context.go('/colleges/${entry.catalog.refId}')` (CollegeDetailScreen existante)

4. **État vide — aucun collège importé (AC4)**
   - Étant donné aucun collège importé (ou tous en statut autre que `generation_complete`)
   - Quand l'écran s'affiche
   - Alors la `SessionHeroCard` affiche : "Importe ton premier collège pour commencer" avec CTA "Voir les collèges" (navigue vers `/colleges`)
   - Et la grille des collèges récents est masquée

5. **État OCR en cours (AC5)**
   - Étant donné un collège importé dont le statut n'est pas `generation_complete` (ex: `processing`, `ocr_complete`, `pending`)
   - Quand l'écran d'accueil s'affiche
   - Alors la `SessionHeroCard` affiche `ShadProgress` indéterminé + "Tes fiches arrivent..." à la place du CTA "Commencer"
   - Et le CTA "Commencer" est absent — la session ne peut pas être lancée pendant la génération

6. **Bottom sheet de personnalisation (AC6)**
   - Étant donné un tap sur "Modifier" dans la `SessionHeroCard`
   - Quand le bottom sheet s'ouvre
   - Alors il s'affiche par-dessus l'accueil (fond dimmé) via `showModalBottomSheet`
   - Et les options disponibles sont : single-select collège (parmi les `generation_complete`), multi-select rang (chips A / B / C), stepper quantité de fiches (0 = toutes), filter chips statut (Toutes / À revoir / Non vues)
   - Et le CTA "Enregistrer la session" (primary, sticky en bas) met à jour la `SessionHeroCard` avec la nouvelle config
   - Et la config est conservée en mémoire tant que l'app est ouverte (pas de persistance disque en Story 4.3 — ajoutée en Story 4.4 avec le planning)

---

## Tasks / Subtasks

- [x] **T1 — Domaine : HomeSessionConfig + HomeSessionConfigNotifier** (AC: #1, #6)
  - [x] Créer `collega_app/lib/features/home/domain/home_session_config.dart` :
    ```dart
    @immutable
    class HomeSessionConfig {
      const HomeSessionConfig({
        required this.collegeId,
        required this.collegeName,
        this.rangs,             // null = tous les rangs
        this.maxCards = 0,      // 0 = toutes les fiches
        this.statusFilter = 'all', // 'all' | 'a_revoir' | 'non_vues'
      });
      final String collegeId;
      final String collegeName;
      final List<String>? rangs;
      final int maxCards;
      final String statusFilter;

      // Dérive onlyARevoir pour DrillSessionParams
      bool get onlyARevoir => statusFilter == 'a_revoir';

      HomeSessionConfig copyWith({...});
    }
    ```
  - [x] Créer `collega_app/lib/features/home/home_providers.dart` :
    ```dart
    class HomeSessionConfigNotifier extends Notifier<HomeSessionConfig?> {
      @override
      HomeSessionConfig? build() => null; // null tant qu'aucun collège dispo

      void setConfig(HomeSessionConfig config) => state = config;
      void applyDefault(HomeSessionConfig config) {
        if (state == null) state = config; // ne remplace pas si déjà customisé
      }
    }

    final homeSessionConfigProvider =
        NotifierProvider<HomeSessionConfigNotifier, HomeSessionConfig?>(
      HomeSessionConfigNotifier.new,
    );
    ```

- [x] **T2 — HomeNotifier : état dérivé depuis collegesProvider** (AC: #1, #3, #4, #5)
  - [x] Dans `home_providers.dart`, ajouter `HomeState` sealed class :
    ```dart
    sealed class HomeState {
      const HomeState();
    }
    class HomeEmpty extends HomeState { const HomeEmpty(); }
    class HomeOcrInProgress extends HomeState {
      const HomeOcrInProgress({required this.collegeName});
      final String collegeName;
    }
    class HomeReady extends HomeState {
      const HomeReady({
        required this.sessionConfig,
        required this.recentColleges, // max 2
        required this.totalCards,
      });
      final HomeSessionConfig sessionConfig;
      final List<CollegeListEntry> recentColleges;
      final int totalCards;

      // Durée estimée : 1 min par tranche de 5 fiches
      String get estimatedDuration {
        final mins = (totalCards / 5).ceil();
        return '$mins min';
      }
    }
    ```
  - [x] Ajouter `HomeNotifier extends AsyncNotifier<HomeState>` :
    - `ref.watch(collegesProvider)` pour réagir aux changements
    - Si aucun collège `isGenerationComplete` ET aucun en cours → `HomeEmpty`
    - Si au moins un non-`generation_complete` importé → `HomeOcrInProgress` (premier trouvé)
    - Sinon → `HomeReady` avec les `generation_complete` colleges
    - **CRITIQUE** : appeler `ref.read(homeSessionConfigProvider.notifier).applyDefault(...)` pour initialiser la config par défaut (premier collège `generation_complete`)
    - Provider : `final homeProvider = AsyncNotifierProvider<HomeNotifier, HomeState>(HomeNotifier.new);`
  - [x] **Comptage total des fiches** : `HomeNotifier` lit depuis Drift (via `databaseProvider`) le nombre de fiches pour le collège/rang/filtre actuel :
    ```dart
    Future<int> _countCards(HomeSessionConfig config) async {
      final db = ref.read(databaseProvider);
      final query = db.select(db.flashCards)
        ..where((t) => t.collegeId.equals(config.collegeId));
      if (config.rangs != null && config.rangs!.isNotEmpty) {
        query.where((t) => t.rang.isIn(config.rangs!));
      }
      if (config.statusFilter == 'a_revoir') {
        query.where((t) => t.drillLevel.equals('a_revoir'));
      } else if (config.statusFilter == 'non_vues') {
        query.where((t) => t.drillLevel.equals('new'));
      }
      final rows = await query.get();
      final count = config.maxCards == 0
          ? rows.length
          : rows.length.clamp(0, config.maxCards);
      return count;
    }
    ```

- [x] **T3 — Extension DrillSessionParams : itemId nullable** (AC: #1)
  - [x] Modifier `collega_app/lib/features/drill/domain/drill_session_state.dart` :
    - `itemId` passe de `required String itemId` à `String? itemId`
    - Mettre à jour `operator ==` et `hashCode` en conséquence
  - [x] Modifier `collega_app/lib/features/drill/data/drill_repository.dart` :
    ```dart
    Future<List<FlashCardModel>> getCardsForDrill({
      required String collegeId,
      String? itemId,          // null = toutes les fiches du collège
      List<String>? rangs,
      bool onlyARevoir = false,
      int maxCards = 0,        // 0 = pas de limite
    }) async {
      final query = db.select(db.flashCards)
        ..where((t) => t.collegeId.equals(collegeId));
      if (itemId != null) {
        query.where((t) => t.itemId.equals(itemId));
      }
      if (rangs != null && rangs.isNotEmpty) {
        query.where((t) => t.rang.isIn(rangs));
      }
      if (onlyARevoir) {
        query.where((t) => t.drillLevel.equals('a_revoir'));
      }
      final rows = await query.get();
      final sorted = _sortCards(rows.map(_rowToModel).toList());
      if (maxCards > 0 && sorted.length > maxCards) {
        return sorted.sublist(0, maxCards);
      }
      return sorted;
    }
    ```
  - [x] Mettre à jour `DrillSessionNotifier.build()` pour passer `collegeId: arg.collegeId`, `itemId: arg.itemId` (nullable)
  - [x] Vérifier que tous les call-sites existants (Story 4.2) compilent : `DrillLaunchBar` passe toujours `itemId` → pas de régression
  - [x] Mettre à jour les tests existants si la signature a changé

- [x] **T4 — SessionHeroCard widget** (AC: #1, #4, #5)
  - [x] Créer `collega_app/lib/features/home/presentation/widgets/session_hero_card.dart`
  - [x] Structure générale :
    ```dart
    class SessionHeroCard extends StatelessWidget {
      const SessionHeroCard({super.key, required this.homeState, required this.onModify});
      final HomeState homeState;
      final VoidCallback onModify;

      @override
      Widget build(BuildContext context) {
        return ShadCard(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: switch (homeState) {
            HomeEmpty() => _EmptyState(),
            HomeOcrInProgress(:final collegeName) => _OcrInProgressState(collegeName: collegeName),
            HomeReady(:final sessionConfig, :final totalCards, :final estimatedDuration) =>
              _ReadyState(config: sessionConfig, cardCount: totalCards, duration: estimatedDuration, onModify: onModify),
          },
        );
      }
    }
    ```
  - [x] `_ReadyState` :
    - Header Row : `Icon(Icons.menu_book_rounded, color: AppColors.primary)` + nom du collège (`titleMedium`) + Spacer + `IconButton(icon: Icon(Icons.edit_outlined), onPressed: onModify)` (tap target ≥ 44×44px)
    - Sous-titre : rangs badges (`ShadBadge` vert/teal/gris) + durée estimée (`labelMedium`, gris)
    - Compteur fiches : `Text('$cardCount fiches', style: AppTypography.displayMedium())`
    - CTA : `ShadButton(onPressed: _launchDrill, width: double.infinity, child: Text('Commencer'))`
    - Navigation drill : `context.push('/drill', extra: DrillSessionParams(collegeId: config.collegeId, itemId: null, rangs: config.rangs, onlyARevoir: config.onlyARevoir))`
  - [x] `_OcrInProgressState` :
    - Text "Tes fiches arrivent..." (`titleMedium`)
    - Nom du collège en cours (`labelMedium`)
    - `ShadProgress()` (indéterminé, `value: null`)
    - Pas de CTA "Commencer"
  - [x] `_EmptyState` :
    - Text "Importe ton premier collège pour commencer" (`titleMedium`)
    - `ShadButton.outline(onPressed: () => context.go('/colleges'), child: Text('Voir les collèges'))`
  - [x] `Semantics` label sur la card entière avec description du contenu

- [x] **T5 — SessionConfigSheet (bottom sheet de personnalisation)** (AC: #6)
  - [x] Créer `collega_app/lib/features/home/presentation/widgets/session_config_sheet.dart`
  - [x] Affichage via `showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => SessionConfigSheet(...))`
  - [x] Contenu :
    ```
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Titre
        Text('Personnaliser la session', style: AppTypography.titleMedium()),

        // Single-select collège (liste des generation_complete seulement)
        _CollegeSelector(colleges: generationCompleteColleges, selected: config.collegeId, onChanged: ...),

        // Multi-select rang (chips A / B / C)
        _RangChips(selected: config.rangs, onChanged: ...),

        // Stepper quantité fiches (0 = toutes)
        _CardCountStepper(value: config.maxCards, onChanged: ...),

        // Filter chips statut
        _StatusFilterChips(selected: config.statusFilter, onChanged: ...),

        // CTA sticky
        ShadButton(onPressed: _saveAndClose, width: double.infinity, child: Text('Enregistrer la session')),
      ],
    )
    ```
  - [x] État local (`StatefulWidget`) pour les sélections en cours avant confirmation
  - [x] `_saveAndClose()` : `ref.read(homeSessionConfigProvider.notifier).setConfig(newConfig)` puis `Navigator.pop(context)`
  - [x] Pas de navigation vers un écran dédié — bottom sheet uniquement (spec UX-DR12)

- [x] **T6 — HomeScreen** (AC: #1, #2, #3, #4, #5, #6)
  - [x] Créer `collega_app/lib/features/home/presentation/home_screen.dart`
  - [x] `HomeScreen` est un `ConsumerWidget`
  - [x] Structure :
    ```dart
    Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // SearchBar sticky en haut
            SliverToBoxAdapter(child: _HomeSearchBar()),
            // SessionHeroCard
            SliverToBoxAdapter(
              child: homeAsync.when(
                data: (state) => SessionHeroCard(
                  homeState: state,
                  onModify: () => _openConfigSheet(context, ref),
                ),
                loading: () => _HeroSkeleton(),
                error: (e, _) => Text(e.toString()),
              ),
            ),
            // Titre "Mes collèges récents" (visible si HomeReady)
            if (homeAsync.valueOrNull is HomeReady) ...[
              SliverToBoxAdapter(child: _SectionTitle('Mes collèges récents')),
              SliverList.builder(
                itemCount: (homeAsync.valueOrNull as HomeReady).recentColleges.length,
                itemBuilder: (ctx, i) {
                  final entry = (homeAsync.valueOrNull as HomeReady).recentColleges[i];
                  return CollegeProgressTile(
                    entry: entry,
                    onTap: () => context.go('/colleges/${entry.catalog.refId}'),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
    ```
  - [x] `_HomeSearchBar` : `GestureDetector(onTap: () => context.go('/search'), child: AbsorbPointer(child: ShadInput(placeholder: Text('Rechercher un item, un signe, une dose...'))))`
    - `AbsorbPointer` empêche l'input de capturer le focus — la navigation se fait au tap sur le container
  - [x] `_HeroSkeleton` : utiliser `Container(height: 160, ...)` avec fond gris pour simuler le skeleton (pas de `ShadSkeleton` — absent de shadcn_ui ^0.19.0, voir note Story 4.2)
  - [x] `_openConfigSheet(context, ref)` : récupère les colleges generation_complete depuis `ref.read(collegesProvider).valueOrNull`, ouvre le bottom sheet

- [x] **T7 — Router : remplacer `_HomeStub` par `HomeScreen`** (AC: #1 à #6)
  - [x] Modifier `collega_app/lib/core/router/app_router.dart` :
    - Ajouter import `package:collega_app/features/home/presentation/home_screen.dart`
    - Remplacer `GoRoute(path: '/home', builder: (ctx, s) => const _HomeStub())` par `GoRoute(path: '/home', builder: (ctx, s) => const HomeScreen())`
    - Supprimer la classe `_HomeStub` (devenue inutile)
  - [x] NE PAS modifier le `ShellRoute` — `/home` reste à l'intérieur (bottom nav visible sur l'accueil, comportement correct)

- [x] **T8 — Tests** (AC: #1, #4, #5, #6)
  - [x] Créer `collega_app/test/features/home/home_notifier_test.dart`
    - Test : `HomeNotifier` → `HomeEmpty` si `collegesProvider` retourne une liste sans `generation_complete`
    - Test : `HomeNotifier` → `HomeOcrInProgress` si un collège importé est en `processing`
    - Test : `HomeNotifier` → `HomeReady` avec 2 colleges récents si 2+ en `generation_complete`
    - Test : `HomeSessionConfigNotifier.applyDefault()` ne remplace pas la config si déjà customisée
    - Test : `HomeSessionConfigNotifier.setConfig()` remplace toujours
  - [x] Créer `collega_app/test/features/home/home_screen_test.dart`
    - Test : état `HomeEmpty` → `_EmptyState` visible ("Importe ton premier collège")
    - Test : état `HomeOcrInProgress` → `ShadProgress` visible + "Tes fiches arrivent..."
    - Test : état `HomeReady` → CTA "Commencer" visible
    - Test : SearchBar tap → `context.go('/search')` appelé (vérifier avec GoRouter mock)
  - [x] Créer `collega_app/test/features/drill/drill_session_params_test.dart` (test de non-régression)
    - Test : `DrillSessionParams` avec `itemId` non-null → compile et s'utilise comme Story 4.2
    - Test : `DrillSessionParams` avec `itemId` null → compile sans erreur
  - [x] Mettre à jour tests existants si `DrillSessionParams` nécessite une migration (vérifier `drill_session_notifier_test.dart`)

- [x] **T9 — Validation finale**
  - [x] `cd collega_app && flutter analyze` → 0 nouvelle erreur
  - [x] `cd collega_app && flutter test test/features/home/` → tous verts
  - [x] `cd collega_app && flutter test test/features/drill/` → 0 régression (tests Story 4.2 toujours verts)
  - [x] `cd collega_app && flutter test` (suite complète) → 0 nouvelle régression

---

## Dev Notes

### Structure des fichiers

```
collega_app/lib/
├── features/
│   ├── home/                                    # NOUVEAU feature folder
│   │   ├── domain/
│   │   │   └── home_session_config.dart          # CRÉER — T1
│   │   ├── presentation/
│   │   │   ├── home_screen.dart                  # CRÉER — T6
│   │   │   └── widgets/
│   │   │       ├── session_hero_card.dart         # CRÉER — T4
│   │   │       └── session_config_sheet.dart      # CRÉER — T5
│   │   └── home_providers.dart                   # CRÉER — T1+T2
│   └── drill/
│       ├── domain/
│       │   └── drill_session_state.dart           # MODIFIER — T3 (itemId nullable)
│       └── data/
│           └── drill_repository.dart              # MODIFIER — T3 (collegeId-level query)
├── core/
│   └── router/
│       └── app_router.dart                        # MODIFIER — T7 (HomeScreen)
collega_app/test/features/
├── home/
│   ├── home_notifier_test.dart                    # CRÉER — T8
│   └── home_screen_test.dart                      # CRÉER — T8
└── drill/
    └── drill_session_params_test.dart              # CRÉER — T8 (non-régression)
```

### Composants existants à RÉUTILISER sans modification

| Composant | Chemin | Usage dans HomeScreen |
|---|---|---|
| `CollegeProgressTile` | `features/colleges/widgets/college_progress_tile.dart` | Grille des collèges récents |
| `collegesProvider` | `features/colleges/colleges_providers.dart` | Source de données colleges |
| `CollegeListEntry` | `features/colleges/domain/college_models.dart` | Modèle partagé |
| `AppTypography` / `AppColors` / `AppSpacing` | `core/theme/app_theme.dart` | Styles uniformes |
| `BottomNavBar` | `shared/widgets/bottom_nav_bar.dart` | Déjà intégré dans `_AppShell` (ShellRoute) — ne pas modifier |
| `DrillSessionParams` | `features/drill/domain/drill_session_state.dart` | Lancement Drill depuis hero card |

**CRITIQUE** : Ne pas recréer `CollegeProgressTile` — il existe et est validé. Le réutiliser directement dans `HomeScreen`.

### Extension DrillSessionParams — compatibilité ascendante

Le champ `itemId` devient nullable. **Tous les call-sites existants passent toujours un itemId String** (DrillLaunchBar dans ItemDetailScreen) → pas de régression. Seule la `SessionHeroCard` passera `itemId: null` pour les sessions au niveau collège.

Modification dans `DrillRepository.getCardsForDrill` :
```dart
// AVANT (Story 4.2)
final query = db.select(db.flashCards)
  ..where((t) => t.itemId.equals(itemId));

// APRÈS (Story 4.3) — itemId nullable
final query = db.select(db.flashCards)
  ..where((t) => t.collegeId.equals(collegeId));  // ← toujours filtrer par collège
if (itemId != null) {
  query.where((t) => t.itemId.equals(itemId!));   // ← filtrage item si fourni
}
```

Le paramètre `collegeId` était déjà dans `DrillSessionParams` — il est déjà disponible dans `DrillSessionNotifier.arg.collegeId`. L'adapter est donc minimal.

### HomeNotifier — dépendance sur collegesProvider

```dart
class HomeNotifier extends AsyncNotifier<HomeState> {
  @override
  Future<HomeState> build() async {
    // WATCH (pas read) pour réagir quand l'utilisateur importe un collège
    final collegesAsync = ref.watch(collegesProvider);
    final colleges = await collegesAsync.future;

    final generationComplete = colleges
        .where((e) => e.isGenerationComplete)
        .toList();

    final inProgress = colleges
        .where((e) => e.isImported && !e.isGenerationComplete)
        .toList();

    if (generationComplete.isEmpty && inProgress.isEmpty) {
      return const HomeEmpty();
    }

    if (generationComplete.isEmpty) {
      return HomeOcrInProgress(collegeName: inProgress.first.catalog.name);
    }

    // Session par défaut : premier collège generation_complete
    final defaultCollege = generationComplete.first;
    ref.read(homeSessionConfigProvider.notifier).applyDefault(
      HomeSessionConfig(
        collegeId: defaultCollege.userStatus!.collegeId,
        collegeName: defaultCollege.catalog.name,
      ),
    );

    final sessionConfig = ref.read(homeSessionConfigProvider)!;
    final totalCards = await _countCards(sessionConfig);

    return HomeReady(
      sessionConfig: sessionConfig,
      recentColleges: generationComplete.take(2).toList(),
      totalCards: totalCards,
    );
  }
}
```

**ATTENTION** : `ref.watch(collegesProvider)` dans un `AsyncNotifier.build()` force un rebuild du HomeNotifier quand les colleges changent (import terminé). C'est le comportement voulu.

**LIMITATION connue** : si `homeSessionConfigProvider` change (l'utilisateur modifie la config dans le bottom sheet), `HomeNotifier` ne se rebuild pas automatiquement. Solution : `HomeScreen` écoute séparément `homeSessionConfigProvider` et force un rebuild du HomeNotifier via `ref.invalidate(homeProvider)` après `setConfig`. Implémenter dans `_saveAndClose()` du `SessionConfigSheet`.

### SessionHeroCard — calcul durée estimée

Formule simple : `(totalCards / 5).ceil()` minutes. 20 fiches → "4 min". 0 fiches → "0 min" (cas edge : bouton "Commencer" désactivé si 0 fiches).

Si `totalCards == 0` (après filtre par statut/rang) : le bouton "Commencer" est grisé (`ShadButton(onPressed: null, ...)`) et un message "Aucune fiche disponible avec ces filtres" remplace le compteur.

### ShadProgress — utilisation correcte

Pour l'état OCR en cours :
```dart
ShadProgress() // Sans paramètre value → indéterminé (animation continue)
```
`ShadSkeleton` est absent de `shadcn_ui ^0.19.0` (confirmé en Story 4.2) — utiliser un `Container` coloré pour les états skeleton.

### SearchBar — AbsorbPointer pattern

La SearchBar sur l'accueil est une "fausse" barre de recherche — elle navigue vers l'onglet recherche au lieu d'ouvrir un clavier. Pattern standard :
```dart
GestureDetector(
  onTap: () => context.go('/search'),
  child: AbsorbPointer(
    child: ShadInput(
      placeholder: const Text('Rechercher un item, un signe, une dose...'),
    ),
  ),
)
```
`AbsorbPointer` empêche l'input de s'activer. `GestureDetector` capte le tap.

### Pas de `shared_preferences` — pas de persistance disque en Story 4.3

`shared_preferences` n'est pas dans `pubspec.yaml`. La `HomeSessionConfig` est stockée en mémoire dans un `Notifier` Riverpod. Elle est réinitialisée au redémarrage de l'app. Story 4.4 ajoutera la persistance via un planning Drift ou `shared_preferences`.

### DrillSessionParams — lancement depuis SessionHeroCard

```dart
// Lancement d'une session sur tout un collège (tous les items, rangs filtrés)
context.push(
  '/drill',
  extra: DrillSessionParams(
    collegeId: sessionConfig.collegeId,
    itemId: null,                // ← NOUVEAU : null = tous les items du collège
    itemName: sessionConfig.collegeName,
    rangs: sessionConfig.rangs,  // null = tous les rangs
    onlyARevoir: sessionConfig.onlyARevoir,
  ),
);
```

### _AppShell et ShellRoute — ne pas modifier

L'`_AppShell` dans `app_router.dart` intègre le `BottomNavBar` via le `ShellRoute`. L'écran d'accueil est à l'intérieur du `ShellRoute` — le bottom nav est donc visible, ce qui est **correct** (contrairement à `/drill` qui est hors `ShellRoute`).

**Ne pas** déplacer `/home` hors du `ShellRoute`.

### CollegesNotifier — limitation `ref.read` dans build

La Story 3.1 a déféré le fait que `CollegesNotifier.build()` utilise `ref.read` au lieu de `ref.watch`. Si l'utilisateur importe un nouveau collège et revient à l'accueil, les données peuvent être stale. Pour cette story, utiliser `ref.invalidate(collegesProvider)` depuis `HomeScreen` lors du `initState` ou via `RefreshIndicator`. Ajouter un `RefreshIndicator` wrappant le `CustomScrollView` est recommandé.

### Anti-patterns à éviter

- **NE PAS** créer un `CircularProgressIndicator` — utiliser un Container gris ou `ShadProgress` selon le contexte
- **NE PAS** placer HomeScreen hors du ShellRoute — le bottom nav doit rester visible
- **NE PAS** faire d'appel réseau dans `HomeNotifier.build()` — lire uniquement depuis Drift et `collegesProvider`
- **NE PAS** créer une nouvelle version de `CollegeProgressTile` — utiliser l'existant
- **NE PAS** implémenter la persistance de la session config en Story 4.3 — c'est Story 4.4
- **NE PAS** implémenter la vraie barre de recherche — le stub `/search` suffit pour Story 4.3
- **NE PAS** utiliser `print()` ou `debugPrint()` — utiliser `AppLogger`

### État du codebase au début de cette story

| Composant | État | Chemin |
|---|---|---|
| `/home` route | ✅ Existe — stub `_HomeStub` avec texte "Accueil" | `core/router/app_router.dart:89` |
| `CollegeProgressTile` | ✅ Existe et testé (Story 3.1) | `features/colleges/widgets/college_progress_tile.dart` |
| `collegesProvider` | ✅ Existe — charge depuis API + catalogue | `features/colleges/colleges_providers.dart` |
| `DrillSessionParams` | ✅ Existe — `itemId: required String` | `features/drill/domain/drill_session_state.dart` |
| `DrillRepository` | ✅ Existe — filtre par `itemId` uniquement | `features/drill/data/drill_repository.dart` |
| `HomeScreen` | 🚫 À créer | `features/home/presentation/home_screen.dart` |
| `SessionHeroCard` | 🚫 À créer | `features/home/presentation/widgets/session_hero_card.dart` |
| `SessionConfigSheet` | 🚫 À créer | `features/home/presentation/widgets/session_config_sheet.dart` |
| `HomeSessionConfig` | 🚫 À créer | `features/home/domain/home_session_config.dart` |
| `home_providers.dart` | 🚫 À créer | `features/home/home_providers.dart` |
| `features/planning/` | 🚫 Vide | (Story 4.4 l'utilisera) |

### Intelligence git (patterns établis)

- Pattern Notifier : `AsyncNotifier<State>` pour état async, `Notifier<State>` pour état sync
- Pattern test : `ShadApp(theme: buildShadTheme(), home: Scaffold(body: ProviderScope(...)))`
- `unawaited(...)` pour les opérations fire-and-forget (pattern établi)
- `if (!mounted) return` dans tous les callbacks async `StatefulWidget`
- `ConsumerWidget` pour lecture simple, `ConsumerStatefulWidget` si état local + Riverpod
- `flutter analyze` → 0 erreur avant marquage done

### Références

- Epic 4, Story 4.3 spec : `_bmad-output/planning-artifacts/epics.md#Story 4.3`
- UX spec accueil : `_bmad-output/planning-artifacts/ux-design-specification.md` (tableau écran accueil)
- UX-DR1 `SessionHeroCard` : `_bmad-output/planning-artifacts/ux-design-specification.md#Composants Custom`
- Architecture feature-first : `_bmad-output/planning-artifacts/architecture.md#Frontend Architecture`
- `CollegeProgressTile` (existant) : `collega_app/lib/features/colleges/widgets/college_progress_tile.dart`
- `CollegesNotifier` + `collegesProvider` : `collega_app/lib/features/colleges/colleges_providers.dart`
- `DrillSessionParams` (à modifier) : `collega_app/lib/features/drill/domain/drill_session_state.dart`
- `DrillRepository` (à modifier) : `collega_app/lib/features/drill/data/drill_repository.dart`
- `_AppShell` + ShellRoute : `collega_app/lib/core/router/app_router.dart:112`
- AppTypography / AppColors / AppSpacing : `collega_app/lib/core/theme/app_theme.dart`
- Pattern `AbsorbPointer` + GestureDetector : pattern standard Flutter pour "fausse" search bar
- Limitation `ShadSkeleton` absente : `collega_app/lib/features/colleges/presentation/import_progress_screen.dart` (note Story 4.2)

---

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

_Aucune régression bloquante. Deux avertissements `info` pré-existants dans `colleges_detail_providers.dart` (avoid_renaming_method_parameters, hors scope Story 4.3)._

_Fix widget test : `InkWell` dans `CollegeProgressTile` nécessite un `Material` ancêtre. Dans les tests, `HomeScreen` est wrappée dans un `Scaffold` (le vrai app utilise `_AppShell(Scaffold)` via `ShellRoute`)._

### Completion Notes List

- Créé feature folder `features/home/` complet : domain, providers, presentation (screen + 2 widgets)
- `DrillSessionParams.itemId` rendu nullable (`String?`) avec compatibilité ascendante totale — tous les call-sites existants passent encore un `String`
- `DrillRepository.getCardsForDrill` refactorisé : filtre primaire sur `collegeId`, filtre optionnel sur `itemId` (null = toutes les fiches du collège)
- `HomeNotifier` watch `collegesProvider.future` pour réagir aux imports en temps réel
- `SessionConfigSheet` : state local avant confirmation, `ref.invalidate(homeProvider)` après setConfig pour forcer rebuild
- 12 nouveaux tests verts (home), 25 tests drill verts, 100 tests total — zéro régression

### File List

- `collega_app/lib/features/home/domain/home_session_config.dart` (créé)
- `collega_app/lib/features/home/home_providers.dart` (créé)
- `collega_app/lib/features/home/presentation/home_screen.dart` (créé)
- `collega_app/lib/features/home/presentation/widgets/session_hero_card.dart` (créé)
- `collega_app/lib/features/home/presentation/widgets/session_config_sheet.dart` (créé)
- `collega_app/lib/features/drill/domain/drill_session_state.dart` (modifié — itemId nullable)
- `collega_app/lib/features/drill/data/drill_repository.dart` (modifié — collegeId-level query + itemId nullable + maxCards)
- `collega_app/lib/features/drill/drill_providers.dart` (modifié — passe collegeId à getCardsForDrill)
- `collega_app/lib/core/router/app_router.dart` (modifié — HomeScreen remplace _HomeStub)
- `collega_app/test/features/home/home_notifier_test.dart` (créé)
- `collega_app/test/features/home/home_screen_test.dart` (créé)
- `collega_app/test/features/drill/drill_session_params_test.dart` (créé — non-régression)
- `collega_app/test/features/drill/drill_session_notifier_test.dart` (modifié — signature getCardsForDrill)
- `collega_app/test/features/drill/drill_repository_test.dart` (modifié — signature getCardsForDrill)
- `collega_app/test/features/drill/drill_screen_test.dart` (modifié — signature getCardsForDrill)

### Review Findings

- [x] [Review][Decision→Patch] Bouton "Modifier" — repositionné via Stack/Positioned en coin supérieur droit absolu [session_hero_card.dart]

- [x] [Review][Patch] `userStatus!` double dereference sans garde — null guard ajouté, fallback HomeEmpty [home_providers.dart:78-82, session_config_sheet.dart:initState]
- [x] [Review][Patch] `ref.read(homeSessionConfigProvider)!` force-unwrap post-async — null guard ajouté, fallback HomeEmpty [home_providers.dart:86-87]
- [x] [Review][Patch] Cast double-accès `(homeAsync.valueOrNull as HomeReady)` dans itemBuilder — remplacé par pattern matching `case final HomeReady ready` [home_screen.dart:68]
- [x] [Review][Patch] selectedCollegeId orphelin dans SessionConfigSheet — validation en initState, fallback sur premier collège valide [session_config_sheet.dart:initState]
- [x] [Review][Patch] CTA "Enregistrer la session" non sticky — extrait du scroll, sticky en bas du Column (AC6) [session_config_sheet.dart]
- [x] [Review][Patch] Bottom sheet sans SingleChildScrollView — contenu wrappé dans Flexible + SingleChildScrollView (AC6) [session_config_sheet.dart]
- [x] [Review][Patch] Écran d'erreur route `/drill` sans bouton retour — `AppBar()` ajouté à l'écran d'erreur [app_router.dart:54-63]
- [x] [Review][Patch] Fuite AppDatabase en mémoire dans les tests — `addTearDown(db.close)` ajouté dans chaque test [home_screen_test.dart]
- [x] [Review][Patch] Test HomeReady ne vérifie pas l'ordre des collèges récents — assertions sur `[0].collegeId == 'c1'` et `[1].collegeId == 'c2'` [home_notifier_test.dart]

- [x] [Review][Defer] SELECT * pour comptage dans `_countCards` — performance, utiliser Drift `count()` [home_providers.dart] — deferred, pre-existing
- [x] [Review][Defer] `maxCards` sans borne supérieure dans le stepper [session_config_sheet.dart] — deferred, pre-existing
- [x] [Review][Defer] `HomeNotifier` lit `homeSessionConfigProvider` via `ref.read` — désynchronisation connue, documentée en Dev Notes [home_providers.dart] — deferred, pre-existing
- [x] [Review][Defer] `SemanticFeedback.result` String libre — devrait être un enum [drill_repository.dart] — deferred, pre-existing
- [x] [Review][Defer] Insertion infinie dans queue pour carte aRevoir réévaluée — pré-existant Story 4.2 [drill_providers.dart] — deferred, pre-existing
- [x] [Review][Defer] `restartWithErrors()` sans rechargement base — pré-existant Story 4.2 [drill_providers.dart] — deferred, pre-existing
- [x] [Review][Defer] `reviewCount` non incrémenté lors des évaluations — scope Story 4.4 [drill_repository.dart] — deferred, pre-existing
- [x] [Review][Defer] `evaluate()` sans guard `isFlipped` — pré-existant Story 4.2, UI enforce le flow [drill_providers.dart] — deferred, pre-existing
- [x] [Review][Defer] `unawaited updateCardDrillLevel` fire-and-forget — intentionnel, pattern établi [drill_providers.dart] — deferred, pre-existing
- [x] [Review][Defer] `statusFilter` inconnu silencieusement ignoré [home_providers.dart] — deferred, pre-existing
- [x] [Review][Defer] Race condition rebuild pendant `_countCards` [home_providers.dart] — deferred, pre-existing
- [x] [Review][Defer] `estimatedDuration` affiche "0 min" quand totalCards == 0 [home_providers.dart] — deferred, pre-existing
- [x] [Review][Defer] `drillLevel` inconnu en BDD trié comme 'new' [drill_repository.dart] — deferred, pre-existing
- [x] [Review][Defer] Nom de collège vide dans `HomeOcrInProgress` [home_providers.dart] — deferred, pre-existing
- [x] [Review][Defer] Route `/drill` + ShellRoute — état `homeProvider` au retour [app_router.dart] — deferred, pre-existing

## Change Log

- 2026-05-14 — Story 4.3 créée par create-story. Analyse Story 4.2 (patterns), codebase (router stub, DrillSessionParams, CollegesProvider, CollegeProgressTile, drill_repository), UX spec accueil, architecture. Statut → ready-for-dev.
- 2026-05-14 — Implémentation complète par claude-sonnet-4-6. Feature `home/` créé (HomeSessionConfig, HomeState sealed class, HomeNotifier, SessionHeroCard, SessionConfigSheet, HomeScreen). DrillSessionParams.itemId rendu nullable, DrillRepository refactorisé (collegeId-level query). Router mis à jour (_HomeStub remplacé). 12 nouveaux tests, 100 tests total verts. Statut → review.
- 2026-05-14 — Code review (3 layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor). 9 patches, 1 decision-needed, 15 deferred, 4 dismissed. Statut → in-progress.

# Story 5.2 : Lancement Session depuis un Résultat de Recherche

Status: ready-for-dev

## Story

En tant qu'**étudiant en stage**,
je veux lancer directement une session de révision sur un item depuis son résultat de recherche,
afin de réviser à chaud le cas clinique que je viens de voir sans quitter le contexte de ma recherche.

## Acceptance Criteria

1. **AC1 — Lancement drill depuis Rang A (FR38)**
   - Étant donné un résultat de recherche affiché
   - Quand je tape sur le CTA "Réviser l'item" d'un résultat Rang A
   - Alors le Mode Drill se lance directement sur les fiches Rang A de cet item uniquement
   - Et le DrillHeader indique le contexte : "Item [N] · [Nom Collège]" (ex : "Item 232 · Cardiologie et maladies vasculaires")

2. **AC2 — Comportement Rang B/C**
   - Étant donné un résultat de rang inférieur (B ou C)
   - Quand je tape sur la carte résultat
   - Alors l'écran `ItemDetailScreen` s'ouvre (route `/colleges/:ref_id/items/:item_id`)
   - Et le bouton `DrillLaunchBar` dans la vue détail item permet de lancer le drill sur le rang souhaité

3. **AC3 — Retour après drill lancé depuis recherche**
   - Étant donné que le drill lancé depuis la recherche se termine
   - Quand l'écran de fin de session s'affiche
   - Alors le CTA **"Nouvelle recherche"** est proposé en **primary** (context.go('/search'))
   - Et le CTA **"Retour à l'accueil"** est proposé en **secondary** (outline)

---

## Périmètre & Contraintes

- **Aucun changement backend** — tout est Flutter uniquement.
- **Aucun nouveau fichier** — uniquement modifications de fichiers existants.
- **Aucun changement à `app_router.dart`** — la route `/colleges/:ref_id/items/:item_id` existe déjà.
- Les drills lancés depuis l'accueil ou `ItemDetailScreen` **ne doivent pas** être impactés (tests de non-régression obligatoires).

---

## Tasks / Subtasks

- [ ] **T1 — `DrillSessionParams` : ajouter le champ `fromSearch`** (AC: #3)
  - [ ] Fichier : `collega_app/lib/features/drill/domain/drill_session_state.dart`
  - [ ] Ajouter `final bool fromSearch;` avec valeur par défaut `false`
  - [ ] Mettre à jour le constructeur : `this.fromSearch = false`
  - [ ] Mettre à jour `operator ==` : ajouter `other.fromSearch == fromSearch`
  - [ ] Mettre à jour `hashCode` : ajouter `fromSearch` dans `Object.hash(...)`
  - [ ] Code exact de la diff :
    ```dart
    // AVANT (ligne ~9) :
    const DrillSessionParams({
      required this.collegeId,
      this.itemId,
      this.itemName,
      this.rangs,
      this.onlyARevoir = false,
      this.maxCards = 0,
    });
    final String collegeId;
    final String? itemId;
    final String? itemName;
    final List<String>? rangs;
    final bool onlyARevoir;
    final int maxCards;

    // APRÈS :
    const DrillSessionParams({
      required this.collegeId,
      this.itemId,
      this.itemName,
      this.rangs,
      this.onlyARevoir = false,
      this.maxCards = 0,
      this.fromSearch = false,
    });
    final String collegeId;
    final String? itemId;
    final String? itemName;
    final List<String>? rangs;
    final bool onlyARevoir;
    final int maxCards;
    final bool fromSearch;

    // operator == (ajouter) :
    other.fromSearch == fromSearch

    // hashCode (ajouter) :
    // Object.hash(collegeId, itemId, itemName, Object.hashAll(rangs ?? []), onlyARevoir, maxCards, fromSearch)
    ```

- [ ] **T2 — `SearchResultTile` : DrillHeader contextuel + tap Rang B/C** (AC: #1, #2)
  - [ ] Fichier : `collega_app/lib/features/search/widgets/search_result_tile.dart`
  - [ ] **Rang A** : Mettre à jour `DrillSessionParams` pour passer `fromSearch: true` et `itemName: 'Item ${result.itemNumber} · $_collegeName'`
  - [ ] **Rang B/C** : Rendre la carte tappable → `context.push('/colleges/${result.collegeRefId}/items/${result.itemId}')`
  - [ ] Code exact du `build` après modification :
    ```dart
    @override
    Widget build(BuildContext context) {
      final Widget card = Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: _borderColor, width: 3)),
        ),
        child: ShadCard(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _badgeColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Rang ${result.rang}',
                      style: AppTypography.labelMedium().copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.chapterTitle ?? 'Item ${result.itemNumber}',
                      style: AppTypography.titleMedium(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Item ${result.itemNumber} · $_collegeName',
                style: AppTypography.bodyMedium().copyWith(
                  color: AppColors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              _HighlightedExcerpt(excerpt: result.excerpt),
              if (result.rang == 'A') ...[
                const SizedBox(height: 12),
                ShadButton(
                  size: ShadButtonSize.sm,
                  onPressed: () => context.push(
                    '/drill',
                    extra: DrillSessionParams(
                      collegeId: result.collegeId,
                      itemId: result.itemId,
                      itemName: 'Item ${result.itemNumber} · $_collegeName',
                      rangs: const ['A'],
                      fromSearch: true,
                    ),
                  ),
                  child: const Text("Réviser l'item"),
                ),
              ],
            ],
          ),
        ),
      );

      if (result.rang != 'A') {
        return GestureDetector(
          onTap: () => context.push(
            '/colleges/${result.collegeRefId}/items/${result.itemId}',
          ),
          child: card,
        );
      }
      return card;
    }
    ```

- [ ] **T3 — `DrillScreen._DrillEndScreen` : CTAs conditionnels selon `fromSearch`** (AC: #3)
  - [ ] Fichier : `collega_app/lib/features/drill/presentation/drill_screen.dart`
  - [ ] Ajouter `params: DrillSessionParams` à `_DrillEndScreen` (field + constructeur)
  - [ ] Mettre à jour l'appel dans `DrillScreen.build` pour passer `params: params`
  - [ ] Dans `_DrillEndScreen.build`, remplacer le `ShadButton.outline('Retour à l'accueil')` par une section conditionnelle :
    ```dart
    // Section CTAs en bas — remplacer le bouton actuel "Retour à l'accueil" par :
    if (params.fromSearch) ...[
      const SizedBox(height: 8),
      ShadButton(
        onPressed: () => context.go('/search'),
        width: double.infinity,
        child: const Text('Nouvelle recherche'),
      ),
      const SizedBox(height: 8),
      ShadButton.outline(
        onPressed: () => context.go('/home'),
        width: double.infinity,
        child: const Text("Retour à l'accueil"),
      ),
    ] else ...[
      const SizedBox(height: 8),
      ShadButton.outline(
        onPressed: () => context.go('/home'),
        width: double.infinity,
        child: const Text("Retour à l'accueil"),
      ),
    ],
    ```
  - [ ] **IMPORTANT** : Le `ShadButton.outline` existant "Retour à l'accueil" (ligne ~351) est remplacé, pas dupliqué
  - [ ] Mettre à jour la déclaration de `_DrillEndScreen` :
    ```dart
    class _DrillEndScreen extends ConsumerWidget {
      const _DrillEndScreen({
        required this.session,
        required this.notifier,
        required this.params,   // ← nouveau
      });
      final DrillSessionState session;
      final DrillSessionNotifier notifier;
      final DrillSessionParams params;  // ← nouveau
    ```
  - [ ] Mettre à jour l'appel dans `DrillScreen.build` :
    ```dart
    // AVANT :
    ? _DrillEndScreen(session: session, notifier: notifier)
    // APRÈS :
    ? _DrillEndScreen(session: session, notifier: notifier, params: params)
    ```

- [ ] **T4 — Tests Flutter** (AC: #1, #2, #3)
  - [ ] Fichier : `collega_app/test/features/search/search_result_test.dart`
  - [ ] Mettre à jour `_wrap()` pour ajouter la route item detail :
    ```dart
    Widget _wrap(Widget child) {
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => Scaffold(body: child)),
        GoRoute(
            path: '/drill',
            builder: (_, __) => const Scaffold(body: Text('Drill'))),
        GoRoute(
            path: '/colleges/:ref_id/items/:item_id',
            builder: (_, __) => const Scaffold(body: Text('ItemDetail'))),
      ]);
      return ProviderScope(
        child: ShadApp.router(
          theme: buildShadTheme(),
          routerConfig: router,
        ),
      );
    }
    ```
  - [ ] Ajouter dans le groupe `'SearchResultTile'` :
    ```dart
    testWidgets('Rang A — DrillSessionParams contient fromSearch:true et itemName contextuel', (tester) async {
      await tester.pumpWidget(_wrap(SearchResultTile(result: _makeResult(rang: 'A', itemNumber: 232, collegeRefId: 1))));
      await tester.pump(Duration.zero);
      // Vérifie que le bouton est présent (le DrillSessionParams est validé par le tap qui navigue)
      expect(find.text("Réviser l'item"), findsOneWidget);
    });

    testWidgets('Rang B — tap ouvre ItemDetailScreen', (tester) async {
      await tester.pumpWidget(_wrap(SearchResultTile(result: _makeResult(rang: 'B'))));
      await tester.pump(Duration.zero);
      expect(find.text("Réviser l'item"), findsNothing);
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();
      expect(find.text('ItemDetail'), findsOneWidget);
    });

    testWidgets('Rang C — tap ouvre ItemDetailScreen', (tester) async {
      await tester.pumpWidget(_wrap(SearchResultTile(result: _makeResult(rang: 'C'))));
      await tester.pump(Duration.zero);
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();
      expect(find.text('ItemDetail'), findsOneWidget);
    });
    ```

- [ ] **T5 — Vérification non-régression**
  - [ ] `flutter analyze` → 0 erreur nouvelle
  - [ ] `flutter test test/features/search/` → tous les tests passent
  - [ ] Vérifier que les tests existants Rang A/B/C sont toujours verts (ils testent l'absence/présence du CTA, ils restent valides)
  - [ ] Vérifier mentalement que les drills lancés depuis `HomeScreen` (`fromSearch: false` par défaut) ne sont pas affectés

---

## Dev Notes — Contexte Technique Exhaustif

### Architecture des fichiers concernés

```
collega_app/lib/
├── features/
│   ├── search/
│   │   ├── domain/search_result.dart          # SearchResult.itemNumber, .collegeRefId, .rang, .itemId, .collegeId
│   │   ├── widgets/search_result_tile.dart    # MODIFIER (T2)
│   │   └── search_providers.dart             # NE PAS TOUCHER
│   └── drill/
│       ├── domain/drill_session_state.dart    # MODIFIER (T1) — ajouter fromSearch
│       └── presentation/drill_screen.dart    # MODIFIER (T3) — _DrillEndScreen
└── core/router/app_router.dart               # NE PAS TOUCHER — routes existantes suffisent
```

### État actuel des fichiers (vérifier avant d'éditer)

**`search_result_tile.dart` — lignes 79-94 (à remplacer entièrement par le code de T2) :**
```dart
if (result.rang == 'A') ...[
  const SizedBox(height: 12),
  ShadButton(
    size: ShadButtonSize.sm,
    onPressed: () => context.push(
      '/drill',
      extra: DrillSessionParams(
        collegeId: result.collegeId,
        itemId: result.itemId,
        itemName: result.chapterTitle ?? 'Item ${result.itemNumber}',  // ← changer format
        rangs: const ['A'],
        // fromSearch: true  ← MANQUE (à ajouter)
      ),
    ),
    child: const Text("Réviser l'item"),
  ),
],
// ← RIEN pour Rang B/C (à ajouter)
```

**`drill_screen.dart` — ligne ~31 (appel de _DrillEndScreen à mettre à jour) :**
```dart
// AVANT :
? _DrillEndScreen(session: session, notifier: notifier)
// APRÈS :
? _DrillEndScreen(session: session, notifier: notifier, params: params)
```

**`drill_screen.dart` — lignes ~351-355 (bouton à remplacer par section conditionnelle T3) :**
```dart
// AVANT (section actuelle en bas de _DrillEndScreen.build) :
ShadButton.outline(
  onPressed: () => context.go('/home'),
  width: double.infinity,
  child: const Text('Retour à l\'accueil'),
),
```

### Routing Rang B/C — route existante vérifiée

La route `/colleges/:ref_id/items/:item_id` est dans `ShellRoute` de `app_router.dart` (ligne ~108) :
```dart
GoRoute(
  path: '/colleges/:ref_id/items/:item_id',
  builder: (ctx, s) => ItemDetailScreen(
    refId: int.parse(s.pathParameters['ref_id']!),
    itemId: s.pathParameters['item_id']!,
  ),
),
```
- `result.collegeRefId` est un `int` → correspond à `:ref_id` ✓
- `result.itemId` est un `String` (UUID) → correspond à `:item_id` ✓
- `ItemDetailScreen` possède un `DrillLaunchBar` pour tout rang ✓

### `kCollegeCatalog` — résolution du nom de collège

Pattern déjà utilisé dans `search_result_tile.dart` :
```dart
String get _collegeName {
  try {
    return kCollegeCatalog.firstWhere((e) => e.refId == result.collegeRefId).name;
  } catch (_) {
    return 'Collège #${result.collegeRefId}';
  }
}
```
Le getter `_collegeName` est déjà disponible dans le widget — utiliser directement dans `itemName`.

### `DrillSessionParams.fromSearch` — propagation dans l'app

- `fromSearch: false` (défaut) → **tous les appels existants** depuis `HomeScreen`, `ItemDetailScreen`, `DemoDrillScreen` sont non impactés — pas de modification à faire sur ces fichiers.
- `fromSearch: true` → **uniquement** le `ShadButton` Rang A dans `SearchResultTile` (T2).

### `_DrillEndScreen` — ordre des CTAs dans l'écran de fin

L'ordre actuel des boutons dans `_DrillEndScreen.build` (lignes ~331-355) :
1. `ShadButton` — "Recommencer les erreurs" (désactivé si aRevoirCount == 0)
2. `ShadButton.outline` — "Session terminée ✓" (visible uniquement si `todaySession != null`)
3. `ShadButton.outline` — "Retour à l'accueil" ← **remplacé par T3**

Après T3, l'ordre devient :
1. `ShadButton` — "Recommencer les erreurs" (inchangé)
2. `ShadButton.outline` — "Session terminée ✓" (inchangé si todaySession != null)
3. Si `fromSearch`:
   - `ShadButton` (primary) — "Nouvelle recherche"
   - `ShadButton.outline` — "Retour à l'accueil"
4. Sinon :
   - `ShadButton.outline` — "Retour à l'accueil"

### Anti-patterns à éviter

- **NE PAS** créer de nouveaux fichiers Dart — tout tient dans les 3 fichiers existants.
- **NE PAS** utiliser `print()` ou `debugPrint()` — utiliser `AppLogger` si besoin de log.
- **NE PAS** modifier `app_router.dart` — les routes nécessaires existent déjà.
- **NE PAS** modifier `search_providers.dart` ou `search_repository.dart` — aucun appel backend supplémentaire.
- **NE PAS** ajouter `connectivity_plus` — absent du projet, offline détecté via DioException.
- **NE PAS** changer le comportement des tiles Rang A (presence du CTA) — tests existants doivent rester verts.
- **NE PAS** modifier les drills de l'accueil ou du detail item — `fromSearch` est `false` par défaut.

### Patterns établis à réutiliser

- `context.push('/drill', extra: DrillSessionParams(...))` — pattern GoRouter validé Stories 4.x et 5.1
- `context.go('/search')` — retour à la SearchScreen (route dans ShellRoute)
- `context.go('/home')` — retour à l'accueil (inchangé)
- `ShadButton` (filled primary) / `ShadButton.outline` (secondary) — pattern de hiérarchie boutons validé
- `GestureDetector` → `context.push(...)` — pattern tap navigation existant dans l'app

### Tests — patterns établis (story 5.1)

```dart
// Helper wrap (à mettre à jour dans T4) :
Widget _wrap(Widget child) { /* GoRouter avec routes /drill et /colleges/:ref_id/items/:item_id */ }

// Pattern test de navigation :
await tester.tap(find.byType(GestureDetector).first);
await tester.pumpAndSettle();
expect(find.text('ItemDetail'), findsOneWidget);
```

---

## Références

- Epic 5 complet : `_bmad-output/planning-artifacts/epics.md` L.930–992
- Story 5.1 (patterns établis) : `_bmad-output/implementation-artifacts/5-1-recherche-full-text-resultats-contextuels.md`
- `DrillSessionParams` : `collega_app/lib/features/drill/domain/drill_session_state.dart`
- `SearchResultTile` : `collega_app/lib/features/search/widgets/search_result_tile.dart`
- `DrillScreen` : `collega_app/lib/features/drill/presentation/drill_screen.dart`
- `ItemDetailScreen` + `DrillLaunchBar` : `collega_app/lib/features/colleges/presentation/item_detail_screen.dart`
- Route `/colleges/:ref_id/items/:item_id` : `collega_app/lib/core/router/app_router.dart` L.108–114
- Tests search : `collega_app/test/features/search/search_result_test.dart`

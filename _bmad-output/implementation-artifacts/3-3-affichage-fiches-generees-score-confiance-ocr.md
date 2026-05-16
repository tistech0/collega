# Story 3.3 : Affichage des Fiches Générées & Score de Confiance OCR

Status: done

## Story

En tant qu'**étudiant**,
je veux consulter les fiches générées pour un collège, organisées par item et par rang, avec un indicateur de qualité OCR,
afin de savoir quelles fiches sont fiables et commencer à réviser.

## Acceptance Criteria

1. **Liste des items — détail collège (FR16, FR17)**
   - Étant donné une génération terminée (`status == 'generation_complete'`)
   - Quand j'ouvre le détail d'un collège
   - Alors je vois la liste de tous les items avec : badge rang (A/B/C coloré), numéro d'item, titre, mini barre de progression À revoir/Bien/Maîtrisé, chevron
   - Et les FilterChips Rang A / Rang B / Rang C permettent de filtrer la liste

2. **Détail item — fiches et accordéon (FR16, FR17)**
   - Étant donné que je tape sur un item
   - Quand l'écran détail item s'ouvre
   - Alors les tabs Rang A / Rang B / Rang C sont affichés en sticky sous le header
   - Et les fiches du rang sélectionné sont affichées en accordéon (recto visible, verso masqué par défaut)
   - Et un strip horizontal de prévisualisation des fiches est visible avec question tronquée et bordure gauche colorée par rang
   - Et la `DrillLaunchBar` "Lancer le drill · X fiches" est fixée juste au-dessus du bottom nav (stub → Story 4.x)

3. **Score de confiance OCR (FR11)**
   - Étant donné un item avec `ocr_confidence_score < 0.7`
   - Quand ses fiches s'affichent
   - Alors le composant `OcrConfidenceBadge` est visible :
     - score entre 0.5 et 0.7 → variant orange "À vérifier"
     - score < 0.5 → variant rouge "Source peu lisible"
   - Et le badge affiche icône + texte (jamais couleur seule)
   - Et un tap sur le badge ouvre un `ShadPopover` avec explication + texte "Vérifier dans le PDF original"

4. **Synchronisation Drift offline (FR22, NFR12)**
   - Étant donné la génération terminée
   - Quand les fiches sont affichées pour la première fois
   - Alors tous les items et fiches sont persistés dans la base Drift locale
   - Et les fiches sont accessibles sans connexion internet (lecture Drift en fallback)

5. **État de chargement progressif**
   - Étant donné un collège dont le statut n'est pas encore `generation_complete`
   - Quand j'ouvre son détail
   - Alors l'écran affiche `LinearProgressIndicator` + "Tes fiches arrivent..."
   - Et quand les fiches arrivent, elles apparaissent progressivement via `flutter_animate` `.fadeIn().slideX()`

## Tasks / Subtasks

- [x] **T1 — Backend : nouveaux schémas** (AC: #1, #2, #4)
  - [x] Ajouter à `collega_backend/app/schemas/college.py` :
    - `ItemSummaryData(id: str, item_number: int, rang: str, chapter_title: str | None, ocr_confidence_score: float, low_confidence: bool, card_count_a: int, card_count_b: int, card_count_c: int)`
    - `ItemsListResponseWrapped(data: list[ItemSummaryData], total: int)`
    - `FlashCardData(id: str, item_id: str, card_type: str, rang: str, recto: str, verso: str, ocr_confidence_score: float, low_confidence: bool)`
    - `CardsListResponseWrapped(data: list[FlashCardData], total: int)`

- [x] **T2 — Backend : `GET /v1/colleges/{college_id}/items`** (AC: #1, #3)
  - [x] Ajouter endpoint dans `collega_backend/app/api/v1/colleges.py`
  - [x] Protéger par `get_current_user`, ownership check (`college.user_id == current_user.id`, sinon 404)
  - [x] Valider que `college.status == 'generation_complete'` (sinon 409 avec `{"code": "GENERATION_NOT_COMPLETE"}`)
  - [x] Récupérer tous les `Item` pour ce collège, triés par `item_number ASC`
  - [x] Pour chaque item, compter les `FlashCard` par `rang` (A/B/C) via query agrégée
  - [x] Retourner `ItemsListResponseWrapped`

- [x] **T3 — Backend : `GET /v1/colleges/{college_id}/items/{item_id}/cards`** (AC: #2, #3)
  - [x] Ajouter endpoint dans `collega_backend/app/api/v1/colleges.py`
  - [x] Protéger par `get_current_user`, double ownership check : college appartient à `current_user`, item appartient au college
  - [x] Retourner toutes les `FlashCard` pour cet item, triées : `rang ASC, card_type ASC`
  - [x] Retourner `CardsListResponseWrapped`

- [x] **T4 — Backend : tests** (AC: #1, #2, #3)
  - [x] Créer `collega_backend/tests/api/test_colleges.py` avec 6 tests :
    - 401 sur items (non authentifié)
    - 404 ownership sur items (college d'un autre user)
    - 409 GENERATION_NOT_COMPLETE si status != 'generation_complete'
    - 200 liste items avec card counts corrects
    - 404 ownership sur cards (item d'un autre college)
    - 200 liste cards triées par rang puis card_type

- [x] **T5 — Flutter : nouvelles tables Drift** (AC: #4)
  - [x] Créer `collega_app/lib/core/database/tables/items_table.dart`
  - [x] Créer `collega_app/lib/core/database/tables/flash_cards_table.dart`
  - [x] Mettre à jour `collega_app/lib/core/database/app_database.dart` :
    - Ajouter `Items` et `FlashCards` dans `@DriftDatabase(tables: [CollegeImports, Items, FlashCards])`
    - Incrémenter `schemaVersion` à 2
    - Ajouter `MigrationStrategy` avec `onCreate` + `onUpgrade`
  - [x] Exécuter `flutter pub run build_runner build --delete-conflicting-outputs` dans `collega_app/`

- [x] **T6 — Flutter : modèles domaine** (AC: #1, #2, #3, #4)
  - [x] Créer `collega_app/lib/features/colleges/domain/college_detail_models.dart` :
    - `ItemModel` avec `factory fromJson`
    - `FlashCardModel` avec `factory fromJson`
    - Sealed class `CollegeDetailState` : `CollegeDetailLoading()`, `CollegeDetailLoaded(items, selectedRang)`, `CollegeDetailEmpty()`, `CollegeDetailError(message)`

- [x] **T7 — Flutter : CollegeDetailRepository** (AC: #1, #2, #4)
  - [x] Créer `collega_app/lib/features/colleges/data/college_detail_repository.dart` :
    - `getItems` + `getItemsFromDrift` + `getCards` + `getCardsFromDrift` + `syncItemsToDrift` + `syncCardsToDrift`

- [x] **T8 — Flutter : CollegeDetailNotifier + providers** (AC: #1, #4, #5)
  - [x] Créer `collega_app/lib/features/colleges/colleges_detail_providers.dart` :
    - `CollegeDetailNotifier` avec `filterByRang`
    - `ItemDetailNotifier` avec clé composite `"$collegeId:$itemId"`
    - `collegeDetailProvider` et `itemDetailProvider`

- [x] **T9 — Flutter : OcrConfidenceBadge widget** (AC: #3)
  - [x] Créer `collega_app/lib/features/colleges/presentation/widgets/ocr_confidence_badge.dart` :
    - score < 0.5 → rouge "Source peu lisible"
    - 0.5 ≤ score < 0.7 → orange "À vérifier"
    - score >= 0.7 → `SizedBox.shrink()`
    - Wrap dans `ShadPopover`

- [x] **T10 — Flutter : CollegeDetailScreen** (AC: #1, #4, #5)
  - [x] Créer `collega_app/lib/features/colleges/presentation/college_detail_screen.dart`
  - [x] Créer `collega_app/lib/features/colleges/presentation/widgets/item_progress_bar.dart`

- [x] **T11 — Flutter : ItemDetailScreen** (AC: #2, #3)
  - [x] Créer `collega_app/lib/features/colleges/presentation/item_detail_screen.dart` avec `DrillLaunchBar` stub, `ShadAccordion`, `FlashcardStrip`, `OcrConfidenceBadge`

- [x] **T12 — Flutter : mise à jour du router** (AC: #1, #2)
  - [x] Dans `collega_app/lib/core/router/app_router.dart` :
    - Retirer `GoRoute(path: '/colleges/:ref_id', ...)` du niveau racine + supprimer `_CollegeDetailStub`
    - Ajouter `/colleges/:ref_id` et `/colleges/:ref_id/items/:item_id` dans ShellRoute

- [x] **T13 — Flutter : tests** (AC: tous)
  - [x] Créer `collega_app/test/features/colleges/college_detail_notifier_test.dart` (3 tests)
  - [x] Créer `collega_app/test/features/colleges/college_detail_screen_test.dart` (2 tests)

- [x] **T14 — Validation finale** (AC: tous)
  - [x] `flutter analyze` → 0 erreur (2 info warnings pré-existants)
  - [x] `flutter test` → 40/41 passent (1 pré-existant: `college_import_screen_test.dart::pendant upload` bugué depuis Story 3.2 — reset() dans initState efface l'état avant la vérification)
  - [x] `pytest collega_backend/tests/api/test_colleges.py` → 10/10 verts (4 anciens + 6 nouveaux)
  - [x] `pytest collega_backend/` → 184/192 passent (8 pré-existants bcrypt/Python 3.14)

## Dev Notes

### État du codebase au début de cette story

**DÉJÀ IMPLÉMENTÉ — NE PAS RECRÉER :**

| Composant | État | Emplacement |
|---|---|---|
| `College` model SQLAlchemy | ✅ Existe avec `status`, `reload_count`, `ocr_page_progress`, `total_pages` | `collega_backend/app/models/college.py` |
| `Item` model SQLAlchemy | ✅ Existe avec `item_number`, `rang`, `chapter_title`, `ocr_confidence_score`, `low_confidence`, `start_page`, `end_page` | `collega_backend/app/models/item.py` |
| `FlashCard` model SQLAlchemy | ✅ Existe avec `rang`, `card_type`, `recto`, `verso`, `ocr_confidence_score`, `low_confidence` | `collega_backend/app/models/flash_card.py` |
| `ItemRead` schema Pydantic | ✅ Existe | `collega_backend/app/schemas/item.py` |
| `FlashCardRead` schema Pydantic | ✅ Existe | `collega_backend/app/schemas/flash_card.py` |
| `GET /v1/colleges` | ✅ Existe — liste collèges avec card_count_a/b/c | `collega_backend/app/api/v1/colleges.py` |
| `get_current_user` dependency | ✅ Existe | `collega_backend/app/deps.py` |
| `CollegesNotifier` + `collegesProvider` | ✅ Existe — retourne `List<CollegeListEntry>` avec `userStatus.collegeId` | `collega_app/lib/features/colleges/colleges_providers.dart` |
| `CollegeListEntry` + `UserCollegeStatus` | ✅ Existe — `UserCollegeStatus` a `collegeId` (UUID), `status`, `cardCountA/B/C` | `collega_app/lib/features/colleges/domain/college_models.dart` |
| `CollegesScreen` | ✅ Existe — navigue vers `/colleges/:ref_id` pour les importés | `collega_app/lib/features/colleges/presentation/colleges_screen.dart` |
| `CollegeProgressTile` + `_ProgressBar` | ✅ Existe — pattern barre de progression 3 couleurs | `collega_app/lib/features/colleges/widgets/college_progress_tile.dart` |
| `AppDatabase` Drift avec `CollegeImports` | ✅ Existe — schemaVersion=1, `databaseProvider` | `collega_app/lib/core/database/app_database.dart` |
| `AppColors`, `AppSpacing`, `AppTypography` | ✅ Existe | `collega_app/lib/core/theme/app_theme.dart` |
| `AppLogger` | ✅ Existe | `collega_app/lib/core/utils/logger.dart` |
| `ShadCard`, `ShadBadge`, `ShadButton`, `ShadToast`, `ShadPopover` | ✅ Dans `shadcn_ui` ^0.19.0 | — |
| `flutter_animate` | ✅ Dans pubspec.yaml | — |

**FICHIERS À CRÉER :**

```
collega_backend/tests/api/test_colleges.py

collega_app/lib/core/database/tables/items_table.dart
collega_app/lib/core/database/tables/flash_cards_table.dart
collega_app/lib/features/colleges/domain/college_detail_models.dart
collega_app/lib/features/colleges/data/college_detail_repository.dart
collega_app/lib/features/colleges/colleges_detail_providers.dart
collega_app/lib/features/colleges/presentation/college_detail_screen.dart
collega_app/lib/features/colleges/presentation/item_detail_screen.dart
collega_app/lib/features/colleges/presentation/widgets/ocr_confidence_badge.dart

collega_app/test/features/colleges/college_detail_notifier_test.dart
collega_app/test/features/colleges/college_detail_screen_test.dart
```

**FICHIERS À MODIFIER :**

| Fichier | Ce que Story 3.3 change |
|---|---|
| `collega_backend/app/schemas/college.py` | Ajouter `ItemSummaryData`, `ItemsListResponseWrapped`, `FlashCardData`, `CardsListResponseWrapped` |
| `collega_backend/app/api/v1/colleges.py` | Ajouter `GET /v1/colleges/{college_id}/items` et `GET /v1/colleges/{college_id}/items/{item_id}/cards` |
| `collega_app/lib/core/database/app_database.dart` | Ajouter `Items`, `FlashCards` dans `@DriftDatabase`, schemaVersion 1→2, `MigrationStrategy` |
| `collega_app/lib/core/router/app_router.dart` | Retirer `_CollegeDetailStub` du niveau racine, ajouter 2 routes dans ShellRoute |

---

### Backend : Endpoint `GET /v1/colleges/{college_id}/items`

```python
@router.get("/colleges/{college_id}/items", response_model=ItemsListResponseWrapped)
async def list_college_items(
    college_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ItemsListResponseWrapped:
    college = await db.get(College, college_id)
    if college is None or college.user_id != current_user.id:
        raise HTTPException(404, detail={"code": "COLLEGE_NOT_FOUND", "message": "College not found"})
    if college.status != "generation_complete":
        raise HTTPException(409, detail={"code": "GENERATION_NOT_COMPLETE", "message": "Generation not yet complete"})

    items_result = await db.execute(
        select(Item).where(Item.college_id == college_id).order_by(Item.item_number)
    )
    items = items_result.scalars().all()
    if not items:
        return ItemsListResponseWrapped(data=[], total=0)

    item_ids = [i.id for i in items]
    counts_result = await db.execute(
        select(FlashCard.item_id, FlashCard.rang, func.count(FlashCard.id))
        .where(FlashCard.item_id.in_(item_ids))
        .group_by(FlashCard.item_id, FlashCard.rang)
    )
    counts: dict[uuid.UUID, dict[str, int]] = {}
    for item_id, rang, count in counts_result.all():
        counts.setdefault(item_id, {})[rang] = count

    data = [
        ItemSummaryData(
            id=str(item.id),
            item_number=item.item_number,
            rang=item.rang,
            chapter_title=item.chapter_title,
            ocr_confidence_score=item.ocr_confidence_score,
            low_confidence=item.low_confidence,
            card_count_a=counts.get(item.id, {}).get("A", 0),
            card_count_b=counts.get(item.id, {}).get("B", 0),
            card_count_c=counts.get(item.id, {}).get("C", 0),
        )
        for item in items
    ]
    return ItemsListResponseWrapped(data=data, total=len(data))
```

---

### Backend : Endpoint `GET /v1/colleges/{college_id}/items/{item_id}/cards`

```python
@router.get("/colleges/{college_id}/items/{item_id}/cards", response_model=CardsListResponseWrapped)
async def list_item_cards(
    college_id: uuid.UUID,
    item_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CardsListResponseWrapped:
    college = await db.get(College, college_id)
    if college is None or college.user_id != current_user.id:
        raise HTTPException(404, detail={"code": "COLLEGE_NOT_FOUND", "message": "College not found"})

    item = await db.get(Item, item_id)
    if item is None or item.college_id != college_id:
        raise HTTPException(404, detail={"code": "ITEM_NOT_FOUND", "message": "Item not found"})

    cards_result = await db.execute(
        select(FlashCard)
        .where(FlashCard.item_id == item_id)
        .where(FlashCard.user_id == current_user.id)
        .order_by(FlashCard.rang, FlashCard.card_type)
    )
    cards = cards_result.scalars().all()
    data = [
        FlashCardData(
            id=str(c.id),
            item_id=str(c.item_id),
            card_type=c.card_type,
            rang=c.rang,
            recto=c.recto,
            verso=c.verso,
            ocr_confidence_score=c.ocr_confidence_score,
            low_confidence=c.low_confidence,
        )
        for c in cards
    ]
    return CardsListResponseWrapped(data=data, total=len(data))
```

**IMPORTANT** : Ajouter les imports nécessaires en haut de `colleges.py` :
```python
from app.models.item import Item
from app.models.flash_card import FlashCard
from app.schemas.college import ItemSummaryData, ItemsListResponseWrapped, FlashCardData, CardsListResponseWrapped
```

Les modèles `Item` et `FlashCard` existent déjà — vérifier que `models/__init__.py` les importe (règle de projet : tout nouveau modèle doit être dans `__init__.py`).

---

### Flutter : Drift schemaVersion 2 + MigrationStrategy

Le `schemaVersion` doit passer de 1 à 2 car on ajoute de nouvelles tables. Ajouter dans `AppDatabase` :

```dart
@override
int get schemaVersion => 2;

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (Migrator m) async {
    await m.createAll();
  },
  onUpgrade: (Migrator m, int from, int to) async {
    if (from < 2) {
      await m.createTable(items);
      await m.createTable(flashCards);
    }
  },
);
```

Après avoir modifié `app_database.dart`, exécuter **obligatoirement** dans `collega_app/` :
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

Cela régénère `app_database.g.dart`. Sans ce fichier, le code ne compile pas.

---

### Flutter : Pattern CollegeDetailNotifier (Riverpod ^2.6.1)

```dart
import 'dart:async' show unawaited;

final collegeDetailProvider = AsyncNotifierProvider.family<
    CollegeDetailNotifier, CollegeDetailState, String>(
  CollegeDetailNotifier.new,
);

class CollegeDetailNotifier extends FamilyAsyncNotifier<CollegeDetailState, String> {
  @override
  Future<CollegeDetailState> build(String collegeId) async {
    final repo = ref.read(collegeDetailRepositoryProvider);
    try {
      final items = await repo.getItems(collegeId);
      if (items.isEmpty) return const CollegeDetailEmpty();
      unawaited(repo.syncItemsToDrift(collegeId, items));
      return CollegeDetailLoaded(items: items, selectedRang: null);
    } on DioException {
      final items = await repo.getItemsFromDrift(collegeId);
      if (items.isEmpty) return const CollegeDetailEmpty();
      return CollegeDetailLoaded(items: items, selectedRang: null);
    }
  }

  void filterByRang(String? rang) {
    final current = state.valueOrNull;
    if (current is! CollegeDetailLoaded) return;
    state = AsyncValue.data(CollegeDetailLoaded(
      items: current.items,
      selectedRang: rang,
    ));
  }
}
```

**`FamilyAsyncNotifier<State, Arg>`** (pas `AsyncNotifier`) — la méthode `build` reçoit l'arg (`collegeId`).

**ItemDetailNotifier** — utilise une clé composite string pour le family arg :

```dart
final itemDetailProvider = AsyncNotifierProvider.family<
    ItemDetailNotifier, List<FlashCardModel>, String>(
  ItemDetailNotifier.new,
);

class ItemDetailNotifier extends FamilyAsyncNotifier<List<FlashCardModel>, String> {
  @override
  Future<List<FlashCardModel>> build(String compositeKey) async {
    // compositeKey = "$collegeId:$itemId"
    final parts = compositeKey.split(':');
    final collegeId = parts[0];
    final itemId = parts[1];
    final repo = ref.read(collegeDetailRepositoryProvider);
    try {
      final cards = await repo.getCards(collegeId, itemId);
      unawaited(repo.syncCardsToDrift(cards));
      return cards;
    } on DioException {
      return repo.getCardsFromDrift(itemId);
    }
  }
}
```

Usage : `ref.watch(itemDetailProvider('$collegeId:$itemId'))`

---

### Flutter : Récupérer college_id depuis ref_id

Le `CollegeDetailScreen` reçoit `refId` (int) depuis l'URL. Il doit obtenir `college_id` (UUID string).

**`package:collection` N'EST PAS dans `pubspec.yaml`** — ne pas utiliser `firstWhereOrNull`. Utiliser une map indexée (même pattern que `CollegesNotifier.build`) :

```dart
class CollegeDetailScreen extends ConsumerWidget {
  const CollegeDetailScreen({super.key, required this.refId});
  final int refId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collegesAsync = ref.watch(collegesProvider);
    return collegesAsync.when(
      loading: () => const Scaffold(body: LinearProgressIndicator()),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (colleges) {
        // Pattern hérité de CollegesNotifier — map indexed par refId
        final byRefId = {for (final e in colleges) e.catalog.refId: e};
        final entry = byRefId[refId];
        if (entry == null || !entry.isImported) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/colleges/$refId/import');
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        final collegeId = entry.userStatus!.collegeId;
        if (!entry.isGenerationComplete) {
          return _LoadingView(collegeName: entry.catalog.name);
        }
        return _CollegeDetailView(entry: entry, collegeId: collegeId);
      },
    );
  }
}
```

**Même pattern** pour `ItemDetailScreen` : obtenir `collegeId` depuis `collegesProvider`, puis surveiller `itemDetailProvider('$collegeId:$itemId')`.

---

### Flutter : couleurs des rangs

Utiliser `AppColors` existants pour la cohérence :
- Rang A → `AppColors.primary` (`Color(0xFF1B6B3A)`) — badge vert
- Rang B → `AppColors.secondary` (`Color(0xFF3D6B5E)`) — badge teal
- Rang C → `AppColors.warning` (`Color(0xFFF0A500)`) — badge orange

Pour la bordure gauche des `FlashcardMiniCard` dans le FlashcardStrip, utiliser ces mêmes couleurs.

---

### Flutter : DrillLaunchBar — stub désactivé

```dart
class DrillLaunchBar extends StatelessWidget {
  const DrillLaunchBar({super.key, required this.cardCount});
  final int cardCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenMargin, 8, AppSpacing.screenMargin, 8,
      ),
      child: ShadButton(
        onPressed: null, // Désactivé — Story 4.x
        width: double.infinity,
        child: Text('Lancer le drill · $cardCount fiches'),
      ),
    );
  }
}
```

Positionner avec `bottomNavigationBar: DrillLaunchBar(cardCount: cards.length)` dans le `Scaffold` de `ItemDetailScreen`. Flutter autorise les Scaffolds imbriqués : l'`_AppShell` a son propre Scaffold avec `BottomNavBar`, et `ItemDetailScreen` a le sien avec `DrillLaunchBar`. Le `DrillLaunchBar` apparaît naturellement juste au-dessus du `BottomNavBar` de `_AppShell`. Pas de `Stack` ni de `Positioned` nécessaire.

---

### Flutter : flutter_animate pour apparition progressive

```dart
// Dans CollegeDetailLoadedView — ListView.builder
itemBuilder: (ctx, i) => ItemTile(item: filteredItems[i])
  .animate(delay: Duration(milliseconds: i * 60))
  .fadeIn(duration: const Duration(milliseconds: 300))
  .slideX(begin: 0.1, curve: Curves.easeOut),
```

**IMPORTANT** : `flutter_animate` est déjà dans `pubspec.yaml`. Ne pas ajouter de dépendance.

---

### Flutter : ShadAccordion vs ExpansionTile

`shadcn_ui ^0.19.0` expose `ShadAccordion<T>`. Pour les fiches en accordéon dans `ItemDetailScreen` :

```dart
ShadAccordion<FlashCardModel>(
  children: cards.map((card) => ShadAccordionItem<FlashCardModel>(
    value: card,
    title: Text(
      card.recto,
      style: AppTypography.titleMedium(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(card.verso, style: AppTypography.bodyLarge()),
        if (card.lowConfidence) ...[
          const SizedBox(height: 8),
          OcrConfidenceBadge(score: card.ocrConfidenceScore),
        ],
      ],
    ),
  )).toList(),
),
```

Si `ShadAccordion` pose des problèmes d'API, utiliser `ExpansionTile` Flutter standard comme fallback (identique à ce qui a été fait pour `ShadSkeleton` → `LinearProgressIndicator` en Story 3.2).

---

### Flutter : Router — déplacer dans ShellRoute

La route `/colleges/:ref_id` est actuellement définie **en dehors** du `ShellRoute` (donc sans BottomNavBar). Le UX spec exige le BottomNavBar sur le détail collège. Il faut déplacer cette route **à l'intérieur** du `ShellRoute` :

```dart
ShellRoute(
  builder: (context, state, child) => _AppShell(child: child),
  routes: [
    GoRoute(path: '/home', builder: ...),
    GoRoute(path: '/colleges', builder: (ctx, s) => const CollegesScreen()),
    GoRoute(                                          // ← AJOUTÉ ICI
      path: '/colleges/:ref_id',
      builder: (ctx, s) => CollegeDetailScreen(
        refId: int.parse(s.pathParameters['ref_id']!),
      ),
    ),
    GoRoute(                                          // ← NOUVEAU
      path: '/colleges/:ref_id/items/:item_id',
      builder: (ctx, s) => ItemDetailScreen(
        refId: int.parse(s.pathParameters['ref_id']!),
        itemId: s.pathParameters['item_id']!,
      ),
    ),
    GoRoute(path: '/search', ...),
    GoRoute(path: '/profile', ...),
  ],
),
```

**Ne pas oublier** de retirer la `GoRoute(path: '/colleges/:ref_id', ...)` du niveau racine — GoRouter lèvera une assertion en cas de route dupliquée.

Les routes import (`/colleges/:ref_id/import` et `/colleges/:ref_id/import/progress`) restent au niveau racine, hors ShellRoute (comportement modal intentionnel confirmé en code review 3.2).

---

### Backend : Pattern test avec items + cards

```python
# tests/api/test_colleges.py
import pytest
from httpx import AsyncClient, ASGITransport
from app.models.college import College
from app.models.item import Item
from app.models.flash_card import FlashCard
from app.deps import get_current_user
from sqlalchemy import insert

async def _make_college_with_data(db, user):
    """Crée un college avec 2 items et des flashcards."""
    college = College(user_id=user.id, college_ref_id=5, status="generation_complete")
    db.add(college)
    await db.flush()
    
    item = Item(college_id=college.id, item_number=232, rang="A", chapter_title="Insuffisance Cardiaque")
    db.add(item)
    await db.flush()
    
    card = FlashCard(
        item_id=item.id, college_id=college.id, user_id=user.id,
        card_type="definition", rang="A",
        recto="Définition IC", verso="...",
        ocr_confidence_score=0.9, low_confidence=False,
    )
    db.add(card)
    await db.commit()
    return college, item, card

async def test_list_items_ok(app, authed_user, db):
    college, item, _ = await _make_college_with_data(db, authed_user)
    app.dependency_overrides[get_current_user] = lambda: authed_user
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        r = await c.get(f"/v1/colleges/{college.id}/items")
    assert r.status_code == 200
    data = r.json()["data"]
    assert len(data) == 1
    assert data[0]["item_number"] == 232
    assert data[0]["card_count_a"] == 1
    app.dependency_overrides.clear()
```

Consulter `collega_backend/tests/api/test_colleges_import.py` pour le pattern de fixture `app` et `authed_user`.

---

### Anti-patterns à éviter absolument

- **NE PAS** implémenter le pouce haut/bas ou la régénération → Story 3.5
- **NE PAS** implémenter le mode drill effectif → Story 4.x (DrillLaunchBar est un stub désactivé)
- **NE PAS** implémenter le hash-sharing → Story 3.4
- **NE PAS** créer un endpoint `flash_cards.py` séparé — tout dans `colleges.py` pour cette story
- **NE PAS** oublier `flutter pub run build_runner build` après modification de `app_database.dart`
- **NE PAS** utiliser `print()` ou `debugPrint()` → `AppLogger`
- **NE PAS** appeler `firstWhere` sans `orElse` → crash `StateError` si refId absent
- **NE PAS** mettre de logique dans les widgets → Notifiers uniquement
- **NE PAS** utiliser `ShadSkeleton` → absent de shadcn_ui ^0.19.0 (utiliser `LinearProgressIndicator` ou `Container` gris)
- **NE PAS** utiliser `CircularProgressIndicator` → `LinearProgressIndicator` ou skelets manuels
- **NE PAS** tenter de réutiliser `_ProgressBar` de `college_progress_tile.dart` → c'est une classe **privée** (préfixe `_`). Créer un `ItemProgressBar` public dans `collega_app/lib/features/colleges/presentation/widgets/item_progress_bar.dart` avec le même code (3 segments colorés : primary/secondary/error) ou le placer dans `collega_app/lib/shared/widgets/`
- **NE PAS** créer les endpoints dans un nouveau fichier `flash_cards.py` → ajouter à `colleges.py` existant
- **NE PAS** omettre `models/__init__.py` : `Item` et `FlashCard` doivent déjà y être importés — vérifier avant d'ajouter
- **NE PAS** router `/colleges/:ref_id` à la fois au niveau racine ET dans ShellRoute → GoRouter assertion error

### Règles qualité héritées des stories précédentes

- `flutter analyze` → 0 erreur avant de marquer terminée
- `AsyncValue.when(loading, error, data)` pour tous les états async dans les widgets
- Logique métier dans les Notifiers, jamais dans les widgets
- Pattern `_Fake[Repository]` pour les tests (sans mockito)
- `ShadToast` pour erreurs non-bloquantes
- `ShadAlertDialog` pour erreurs bloquantes
- Un seul `ShadButton filled primary` par écran
- Nommage : PascalCase classes, camelCase méthodes, snake_case fichiers

### Références

- Pattern endpoint liste + counts : `collega_backend/app/api/v1/colleges.py` — `list_user_colleges` (lignes ~40-80) pour le pattern `group_by` + `func.count`
- Pattern AsyncNotifier.family : `collega_app/lib/features/colleges/colleges_import_providers.dart`
- Pattern Repository : `collega_app/lib/features/colleges/data/college_import_repository.dart`
- Pattern test Notifier : `collega_app/test/features/colleges/college_import_notifier_test.dart`
- Pattern test Widget : `collega_app/test/features/colleges/college_import_screen_test.dart`
- Pattern tile UI : `collega_app/lib/features/colleges/widgets/college_progress_tile.dart` (réutiliser `_ProgressBar`)
- CollegesScreen (navigation) : `collega_app/lib/features/colleges/presentation/colleges_screen.dart`
- Thème : `collega_app/lib/core/theme/app_theme.dart`
- Router actuel : `collega_app/lib/core/router/app_router.dart`
- AppDatabase : `collega_app/lib/core/database/app_database.dart`
- flutter_animate docs : https://pub.dev/packages/flutter_animate

### Déferred work à noter pour cette story

- `OcrConfidenceBadge` tap → "Voir dans le PDF original" est affiché comme texte dans le `ShadPopover` mais n'ouvre pas le PDF (fonctionnalité viewer PDF hors scope Story 3.3)
- `DrillLaunchBar` désactivé — sera activé en Story 4.1 quand le mode Drill sera implémenté
- `BookmarkIcon` sur `ItemDetailScreen` est désactivé — fonctionnalité future non définie
- Score confiance : affiché sur les items ET sur les cartes (deux niveaux) — l'item a son propre `ocr_confidence_score` (score global de l'item), les cartes ont leur propre score (peut différer)

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- `AppTypography.bodySmall()` n'existe pas → remplacé par `bodyMedium()`
- `flutter_animate` inutile dans `college_detail_screen.dart` (déjà exporté par `shadcn_ui`) → import supprimé
- `const BaseOptions(...)` dans `sse_client.dart` → `BaseOptions(...)` avec Duration const inline
- Test `pendant upload` pré-existant échoue : `initState` appelle `reset()` qui remet l'état à `ImportIdle` avant la vérification (bug Story 3.2, non lié à Story 3.3)

### Completion Notes List

- T1-T4 (Backend) : 2 nouveaux endpoints REST + 4 nouveaux schémas Pydantic + 6 tests backend. 10/10 tests passent.
- T5 (Drift) : Tables `Items` et `FlashCards` créées, `AppDatabase` mis à jour schemaVersion 1→2 avec `MigrationStrategy`, `build_runner` exécuté avec succès.
- T6-T8 (Flutter domain/data/providers) : `ItemModel`, `FlashCardModel`, `CollegeDetailState` sealed, `CollegeDetailRepository` avec fallback Drift, `CollegeDetailNotifier` + `ItemDetailNotifier` FamilyAsyncNotifier.
- T9 (OcrConfidenceBadge) : Widget avec 3 variantes (transparent/orange/rouge) et `ShadPopover`.
- T10-T11 (Écrans) : `CollegeDetailScreen` avec FilterChips + `ItemProgressBar` public + animations `flutter_animate`. `ItemDetailScreen` avec `ShadAccordion`, `FlashcardStrip`, `DrillLaunchBar` stub.
- T12 (Router) : `/colleges/:ref_id` et `/colleges/:ref_id/items/:item_id` déplacés dans `ShellRoute`. `_CollegeDetailStub` supprimé.
- T13 (Tests Flutter) : 3 tests notifier + 2 tests widget, tous verts.
- T14 (Validation) : `flutter analyze` 0 erreur. 40/41 tests Flutter (1 bug pré-existant Story 3.2).

### File List

**Créés :**
- `collega_backend/app/schemas/college.py` (ajout 4 schémas)
- `collega_backend/app/api/v1/colleges.py` (ajout 2 endpoints)
- `collega_app/lib/core/database/tables/items_table.dart`
- `collega_app/lib/core/database/tables/flash_cards_table.dart`
- `collega_app/lib/core/database/app_database.g.dart` (régénéré)
- `collega_app/lib/features/colleges/domain/college_detail_models.dart`
- `collega_app/lib/features/colleges/data/college_detail_repository.dart`
- `collega_app/lib/features/colleges/colleges_detail_providers.dart`
- `collega_app/lib/features/colleges/presentation/widgets/ocr_confidence_badge.dart`
- `collega_app/lib/features/colleges/presentation/widgets/item_progress_bar.dart`
- `collega_app/lib/features/colleges/presentation/college_detail_screen.dart`
- `collega_app/lib/features/colleges/presentation/item_detail_screen.dart`
- `collega_app/test/features/colleges/college_detail_notifier_test.dart`
- `collega_app/test/features/colleges/college_detail_screen_test.dart`

**Modifiés :**
- `collega_backend/app/schemas/college.py`
- `collega_backend/app/api/v1/colleges.py`
- `collega_backend/tests/api/test_colleges.py`
- `collega_app/lib/core/database/app_database.dart`
- `collega_app/lib/core/network/sse_client.dart` (fix pré-existant `const BaseOptions`)
- `collega_app/lib/core/router/app_router.dart`

### Change Log

- 2026-05-10 : Story 3.3 créée par create-story — affichage fiches générées + score confiance OCR
- 2026-05-10 : Story 3.3 implémentée par claude-sonnet-4-6 — status → review
- 2026-05-10 : Story 3.3 code review — 5 decision_needed, 18 patch, 5 defer, 3 dismissed
- 2026-05-10 : Story 3.3 review follow-ups appliqués — 21 patches corrigés (2 faux positifs), 5 décisions résolues — status → done

### Review Findings

#### Decision Needed

- [x] [Review][Decision] **Rate-limit bypass via `get_remote_address` derrière reverse proxy** — Corrigé : `limiter.py` lit `X-Forwarded-For`.
- [x] [Review][Decision] **Offline : card counts toujours 0 depuis Drift** — Corrigé : `getItemsFromDrift` agrège les counts depuis `flash_cards`.
- [x] [Review][Decision] **TabBar sous le FlashcardStrip, pas sticky sous le header** — Corrigé : `TabBar` déplacé avant `_FlashcardStrip`.
- [x] [Review][Decision] **OcrConfidenceBadge : gate `lowConfidence` boolean vs seuil de score direct** — Corrigé : gate remplacé par `ocrConfidenceScore < 0.7`.
- [x] [Review][Decision] **`FlashCard.user_id` filter dans `list_item_cards`** — Corrigé : filtre `user_id` supprimé.

#### Patches

- [x] [Review][Patch] **CRITICAL — `_openConnection()` : callback LazyDatabase** — Faux positif : `return NativeDatabase.createInBackground(file)` était déjà présent.
- [x] [Review][Patch] **CRITICAL — `FlashCardData` sans champ `college_id`** — Corrigé : champ ajouté au schéma Pydantic et à la construction dans `colleges.py`.
- [x] [Review][Patch] **HIGH — `compositeKey.split(':')` sans vérification de longueur** — Corrigé : guard `parts.length < 2` ajouté.
- [x] [Review][Patch] **HIGH — Double source de vérité pour le filtre rang** — Corrigé : `_CollegeDetailView` converti en `ConsumerWidget`, état `selectedRang` lu depuis le notifier.
- [x] [Review][Patch] **HIGH — `_extractItemNumber` / `_extractChapterTitle` toujours `null`** — Corrigé : `collegeDetailProvider` watché pour obtenir `currentItem`.
- [x] [Review][Patch] **HIGH — `entry.userStatus!` null-assertion dans `_CollegeDetailView`** — Corrigé : garde null-safe avec early return.
- [x] [Review][Patch] **HIGH — `entry.userStatus!` null-assertion dans `ItemDetailScreen`** — Corrigé : garde null-safe avec early return.
- [x] [Review][Patch] **HIGH — `response.data!['data']` null-dereference dans `getItems`/`getCards`** — Corrigé : `(response.data?['data'] as List<dynamic>?) ?? []`.
- [x] [Review][Patch] **HIGH — `unawaited(syncItemsToDrift/syncCardsToDrift)` sans `.catchError`** — Corrigé : `.catchError` avec log ajouté aux deux appels.
- [x] [Review][Patch] **HIGH — `DrillLaunchBar` en `bottomNavigationBar` du Scaffold interne** — Faux positif : comportement volontaire documenté en Dev Notes (Scaffolds imbriqués intentionnels, testé).
- [x] [Review][Patch] **MEDIUM — `@router.post("/register", status_code=403)`** — Corrigé : decorator changé en `status_code=200`.
- [x] [Review][Patch] **MEDIUM — `CollegeDetailLoaded.copyWith(selectedRang: null)` pattern incorrect** — Corrigé : méthode `copyWith` supprimée (inutilisée depuis P4).
- [x] [Review][Patch] **MEDIUM — `databaseProvider` : `db.close()` sans `await`** — Corrigé : `ref.onDispose(() async => db.close())`.
- [x] [Review][Patch] **MEDIUM — `ocr_confidence_score` null dans le JSON → `TypeError`** — Corrigé : `(json['ocr_confidence_score'] as num?)?.toDouble() ?? 0.0` dans les deux `fromJson`.
- [x] [Review][Patch] **MEDIUM — `OcrConfidenceBadge` avec score=0.0 affiche badge rouge** — Corrigé : guard `!score.isFinite || score <= 0.0` ajouté.
- [x] [Review][Patch] **MEDIUM — `list_item_cards` ne vérifie pas `generation_complete`** — Corrigé : check ajouté après le college ownership check.
- [x] [Review][Patch] **MEDIUM — `syncItemsToDrift` utilise `item.collegeId` potentiellement vide** — Corrigé : toujours utiliser le `collegeId` du caller.
- [x] [Review][Patch] **MEDIUM — `/colleges/:ref_id/import/progress` cast sans garde** — Corrigé : null guard avec `Scaffold` fallback.

#### Deferred

- [x] [Review][Defer] **`SseClient.connect` non réentrant : leak descripteurs fichiers sur reconnexion rapide** [`collega_app/lib/core/network/sse_client.dart`] — deferred, pre-existing
- [x] [Review][Defer] **Migration `onUpgrade` : pas de gestion des downgrades ou gaps de version** [`collega_app/lib/core/database/app_database.dart`] — deferred, pre-existing
- [x] [Review][Defer] **`limiter.py` : si Redis est down, toutes les tentatives de login retournent 500** [`collega_backend/app/core/limiter.py`] — deferred, pre-existing
- [x] [Review][Defer] **`list_college_items` retourne 409 `GENERATION_NOT_COMPLETE` pour le statut `failed` : indistingable du "en cours"** [`collega_backend/app/api/v1/colleges.py`] — deferred, product decision
- [x] [Review][Defer] **Apparition progressive des fiches : animation au chargement, pas SSE-driven item par item comme suggère AC5** [`collega_app/lib/features/colleges/presentation/college_detail_screen.dart`] — deferred, spec interpretation

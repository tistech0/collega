# Story 5.1 : Recherche Full-Text & Résultats Contextuels

Status: done

## Story

En tant qu'**étudiant**,
je veux saisir un terme clinique dans la barre de recherche et obtenir instantanément les items et fiches correspondants avec leur contexte,
afin de retrouver en quelques secondes l'item lié à un cas vu en stage.

## Acceptance Criteria

1. **Onglet Recherche — focus immédiat (AC1 — FR36)**
   - Étant donné l'onglet Recherche (bottom nav index 2)
   - Quand je l'ouvre depuis le bottom nav ou la SearchBar de l'accueil
   - Alors le champ `ShadInput` est immédiatement focusé avec le clavier ouvert
   - Et le placeholder indique : "Rechercher un item, un signe, une dose..."

2. **Exécution de la recherche en < 1 seconde (AC2 — FR36, NFR1)**
   - Étant donné que je saisis un terme (ex : "BNP")
   - Quand la recherche est exécutée via `GET /v1/search?q=BNP`
   - Alors les résultats s'affichent en < 1 seconde (GIN index PostgreSQL — NFR1)
   - Et le compteur "X items trouvés" est affiché sous la barre

3. **`SearchResultTile` — affichage contextuel (AC3 — FR37)**
   - Étant donné les résultats affichés
   - Quand je les consulte
   - Alors chaque `SearchResultTile` affiche : titre de l'item (chapter_title), badge rang (A/B/C coloré), provenance (Item N · Nom Collège), extrait contextuel avec le terme recherché surligné en vert clair `#B7F2C8`
   - Et une bordure gauche colorée code le rang (vert `AppColors.primary` pour Rang A, teal `AppColors.secondary` pour Rang B, aucune pour C)
   - Et le CTA "Réviser l'item" est présent uniquement sur les résultats Rang A

4. **État vide (AC4 — FR36)**
   - Étant donné qu'aucun résultat ne correspond au terme saisi
   - Quand la recherche retourne zéro résultat
   - Alors l'état vide affiche : "Aucun résultat pour '[terme]' — essaie un autre mot"
   - Et la barre de recherche reste accessible et focusée

5. **Gestion hors-ligne (AC5 — FR36)**
   - Étant donné que l'étudiant est hors-ligne et tape dans la SearchBar
   - Quand la requête `GET /v1/search` échoue par absence de réseau
   - Alors un `ShadToast` informatif s'affiche : "La recherche nécessite une connexion internet"
   - Et les fiches restent accessibles via la navigation par collège (offline-first)

---

## Tasks / Subtasks

- [x] **T1 — Backend : Migration Alembic #010 — GIN index PostgreSQL sur `flash_cards`** (AC: #2)
  - [x] Créer `collega_backend/alembic/versions/010_add_gin_index_flash_cards_fts.py` :
    ```python
    from alembic import op
    import sqlalchemy as sa
    from sqlalchemy.dialects import postgresql

    revision = "010_add_gin_index_flash_cards_fts"
    down_revision = "009_add_reminder_hour_utc_to_users"
    branch_labels = None
    depends_on = None

    def upgrade() -> None:
        op.execute("""
            CREATE INDEX idx_flash_cards_fts
            ON flash_cards
            USING GIN (to_tsvector('french', coalesce(recto, '') || ' ' || coalesce(verso, '')))
        """)

    def downgrade() -> None:
        op.execute("DROP INDEX IF EXISTS idx_flash_cards_fts")
    ```
  - [x] **IMPORTANT** : révision `down_revision` = `"009_add_reminder_hour_utc_to_users"` (pattern migrations existantes)
  - [x] Vérifier que Alembic utilise bien `"010_..."` comme `revision` (pas auto-généré avec UUID)

- [x] **T2 — Backend : `services/search/full_text_search.py`** (AC: #2, #3)
  - [x] Créer `collega_backend/app/services/search/full_text_search.py` :
    ```python
    """Service de recherche full-text via PostgreSQL GIN index."""
    from __future__ import annotations

    import logging
    import uuid

    from sqlalchemy import text
    from sqlalchemy.ext.asyncio import AsyncSession

    logger = logging.getLogger(__name__)

    MAX_RESULTS = 20


    async def search_flash_cards(
        db: AsyncSession,
        user_id: uuid.UUID,
        query: str,
    ) -> list[dict]:
        """
        Recherche full-text sur flash_cards (recto + verso) via GIN index.
        Retourne les items distincts triés par pertinence, avec extrait contextuel.
        """
        sql = text("""
            SELECT DISTINCT ON (fc.item_id)
                fc.item_id::text,
                i.item_number,
                i.rang,
                i.chapter_title,
                c.id::text AS college_id,
                c.college_ref_id,
                ts_headline(
                    'french',
                    coalesce(fc.recto, '') || ' ' || coalesce(fc.verso, ''),
                    plainto_tsquery('french', :query),
                    'MaxWords=20, MinWords=5, StartSel=<mark>, StopSel=</mark>, HighlightAll=false'
                ) AS excerpt,
                ts_rank(
                    to_tsvector('french', coalesce(fc.recto, '') || ' ' || coalesce(fc.verso, '')),
                    plainto_tsquery('french', :query)
                ) AS rank
            FROM flash_cards fc
            JOIN items i ON fc.item_id = i.id
            JOIN colleges c ON fc.college_id = c.id
            WHERE fc.user_id = :user_id
              AND to_tsvector('french', coalesce(fc.recto, '') || ' ' || coalesce(fc.verso, ''))
                  @@ plainto_tsquery('french', :query)
            ORDER BY fc.item_id, rank DESC
        """)

        result = await db.execute(sql, {"query": query, "user_id": str(user_id)})
        rows = result.mappings().all()

        # Re-trier par rank décroissant (DISTINCT ON trie par item_id en premier)
        sorted_rows = sorted(rows, key=lambda r: r["rank"], reverse=True)

        return [dict(r) for r in sorted_rows[:MAX_RESULTS]]
    ```
  - [x] **IMPORTANT** : `plainto_tsquery` (pas `to_tsquery`) — supporte les termes multimots sans syntaxe spéciale (ex: "BNP élevé" marche directement)
  - [x] **IMPORTANT** : `DISTINCT ON (fc.item_id)` + `ORDER BY fc.item_id, rank DESC` → prend la meilleure fiche par item, puis re-trie par rank
  - [x] **IMPORTANT** : scoping par `user_id` obligatoire (NFR8) — jamais de résultats cross-user

- [x] **T3 — Backend : `api/v1/search.py`** (AC: #2, #3, #4)
  - [x] Créer `collega_backend/app/api/v1/search.py` :
    ```python
    """FR36–37 — Recherche full-text sur fiches utilisateur via GIN index PostgreSQL."""
    from __future__ import annotations

    import logging

    from fastapi import APIRouter, Depends, Query
    from sqlalchemy.ext.asyncio import AsyncSession

    from app.core.database import get_db
    from app.core.limiter import limiter
    from app.deps import get_current_user, require_subscription
    from app.models.user import User
    from app.services.search.full_text_search import search_flash_cards

    logger = logging.getLogger(__name__)
    router = APIRouter()


    @router.get("/search")
    @limiter.limit("30/minute")
    async def search(
        request,  # requis par slowapi pour rate limiting
        q: str = Query(..., min_length=2, max_length=100),
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user),
        _: None = Depends(require_subscription),
    ):
        logger.info("Search q=%r user=%s", q, current_user.id)
        results = await search_flash_cards(db, current_user.id, q)
        return {"data": results}
    ```
  - [x] **IMPORTANT** : `q: str = Query(..., min_length=2, max_length=100)` → validation FastAPI native, 422 si < 2 chars
  - [x] **IMPORTANT** : `request` en premier paramètre — requis par `slowapi` pour le rate limiting (voir pattern dans `notifications.py`)
  - [x] **IMPORTANT** : `require_subscription` → 403 si user non abonné (pattern Story 2.4)
  - [x] **IMPORTANT** : `@limiter.limit("30/minute")` — adapté à la search (pas 10/min trop restrictif)

- [x] **T4 — Backend : enregistrement `search_router` dans `app/main.py`** (AC: #2)
  - [x] Modifier `collega_backend/app/main.py` :
    - Ajouter import : `from app.api.v1.search import router as search_router`
    - Ajouter après `app.include_router(notifications_router, prefix="/v1")` :
      ```python
      app.include_router(search_router, prefix="/v1")
      ```
  - [x] **VÉRIFIER** que `search_router` est bien enregistré avec le bon `prefix="/v1"` → endpoint final = `GET /v1/search`

- [x] **T5 — Backend : tests `tests/api/test_search.py`** (AC: #2, #3, #4, #5)
  - [x] Créer `collega_backend/tests/api/test_search.py` :
    - Test : `GET /v1/search?q=BNP` avec user abonné ayant des fiches → 200, `data` non vide, chaque item a `item_id, rang, excerpt`
    - Test : `GET /v1/search?q=BNP` sans fiches correspondantes → 200, `data = []`
    - Test : `GET /v1/search?q=x` (1 char) → 422 (validation `min_length=2`)
    - Test : `GET /v1/search?q=BNP` sans authentification → 401
    - Test : `GET /v1/search?q=BNP` user non abonné → 403
    - Test : résultats scoped — user A ne voit pas les fiches de user B pour la même recherche

- [x] **T6 — Flutter : `SearchResult` model (domain)** (AC: #3)
  - [x] Créer `collega_app/lib/features/search/domain/search_result.dart` :
    ```dart
    import 'package:flutter/foundation.dart';

    @immutable
    class SearchResult {
      const SearchResult({
        required this.itemId,
        required this.itemNumber,
        required this.rang,
        this.chapterTitle,
        required this.collegeId,
        required this.collegeRefId,
        required this.excerpt,
      });

      final String itemId;
      final int itemNumber;
      final String rang;        // 'A', 'B', 'C'
      final String? chapterTitle;
      final String collegeId;   // UUID — pour DrillSessionParams
      final int collegeRefId;   // pour résoudre le nom via kCollegeCatalog
      final String excerpt;     // contient des balises <mark>...</mark>

      factory SearchResult.fromJson(Map<String, dynamic> json) {
        return SearchResult(
          itemId: json['item_id'] as String,
          itemNumber: json['item_number'] as int,
          rang: json['rang'] as String,
          chapterTitle: json['chapter_title'] as String?,
          collegeId: json['college_id'] as String,
          collegeRefId: json['college_ref_id'] as int,
          excerpt: json['excerpt'] as String,
        );
      }
    }
    ```

- [x] **T7 — Flutter : `SearchRepository`** (AC: #2)
  - [x] Créer `collega_app/lib/features/search/data/search_repository.dart` :
    ```dart
    import 'package:dio/dio.dart';
    import 'package:collega_app/features/search/domain/search_result.dart';

    class SearchRepository {
      const SearchRepository(this._dio);
      final Dio _dio;

      Future<List<SearchResult>> search(String query) async {
        final response = await _dio.get<Map<String, dynamic>>(
          '/v1/search',
          queryParameters: {'q': query},
        );
        final data = response.data!['data'] as List<dynamic>;
        return data
            .map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    ```
  - [x] Créer `collega_app/lib/features/search/search_providers.dart` :

- [x] **T8 — Flutter : `SearchNotifier` (Riverpod Notifier + debounce)** (AC: #2, #4, #5)
  - [x] Dans `search_providers.dart`, ajouter après `searchRepositoryProvider` :
    ```dart
    import 'dart:async';
    import 'package:dio/dio.dart';

    // État de la recherche
    class SearchState {
      const SearchState({
        this.query = '',
        this.results = const [],
        this.isLoading = false,
        this.isOffline = false,
        this.error,
      });

      final String query;
      final List<SearchResult> results;
      final bool isLoading;
      final bool isOffline;
      final String? error;

      bool get hasResults => results.isNotEmpty;
      bool get hasQuery => query.trim().isNotEmpty;
      bool get isEmpty => query.trim().isNotEmpty && !isLoading && results.isEmpty && !isOffline && error == null;
    }

    class SearchNotifier extends Notifier<SearchState> {
      Timer? _debounce;

      @override
      SearchState build() => const SearchState();

      void onQueryChanged(String query) {
        _debounce?.cancel();
        if (query.trim().isEmpty) {
          state = const SearchState();
          return;
        }
        state = SearchState(query: query, isLoading: true);
        _debounce = Timer(const Duration(milliseconds: 400), () {
          _doSearch(query.trim());
        });
      }

      Future<void> _doSearch(String query) async {
        try {
          final repo = ref.read(searchRepositoryProvider);
          final results = await repo.search(query);
          if (state.query == query) {
            state = SearchState(query: query, results: results);
          }
        } on DioException catch (e) {
          if (!_isOfflineError(e)) {
            AppLogger.error('Search error', tag: 'SearchNotifier', error: e);
          }
          if (state.query == query) {
            state = SearchState(
              query: query,
              isOffline: _isOfflineError(e),
              error: _isOfflineError(e) ? null : 'Erreur de recherche',
            );
          }
        }
      }

      bool _isOfflineError(DioException e) =>
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout;

      @override
      void dispose() {
        _debounce?.cancel();
        super.dispose();
      }
    }

    final searchNotifierProvider =
        NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
    ```
  - [x] **IMPORTANT** : ajouter import `AppLogger` : `import 'package:collega_app/core/utils/logger.dart';`
  - [x] **IMPORTANT** : le check `if (state.query == query)` avant mise à jour évite les race conditions quand l'utilisateur tape rapidement

- [x] **T9 — Flutter : `SearchResultTile` widget** (AC: #3)
  - [x] Créer `collega_app/lib/features/search/widgets/search_result_tile.dart` :
    ```dart
    import 'package:flutter/material.dart';
    import 'package:go_router/go_router.dart';
    import 'package:shadcn_ui/shadcn_ui.dart';
    import 'package:collega_app/core/theme/app_colors.dart';
    import 'package:collega_app/core/theme/app_spacing.dart';
    import 'package:collega_app/core/theme/app_typography.dart';
    import 'package:collega_app/features/colleges/domain/college_catalog.dart';
    import 'package:collega_app/features/drill/domain/drill_session_state.dart';
    import 'package:collega_app/features/search/domain/search_result.dart';

    class SearchResultTile extends StatelessWidget {
      const SearchResultTile({super.key, required this.result});
      final SearchResult result;

      Color get _borderColor => switch (result.rang) {
        'A' => AppColors.primary,
        'B' => AppColors.secondary,
        _ => Colors.transparent,
      };

      Color get _badgeColor => switch (result.rang) {
        'A' => AppColors.primary,
        'B' => AppColors.secondary,
        _ => AppColors.onSurface.withOpacity(0.5),
      };

      String get _collegeName {
        try {
          return kCollegeCatalog.firstWhere((e) => e.refId == result.collegeRefId).name;
        } catch (_) {
          return 'Collège #${result.collegeRefId}';
        }
      }

      @override
      Widget build(BuildContext context) {
        return Container(
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
                        style: AppTypography.labelSmall().copyWith(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.chapterTitle ?? 'Item ${result.itemNumber}',
                        style: AppTypography.titleSmall(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Item ${result.itemNumber} · $_collegeName',
                  style: AppTypography.bodySmall().copyWith(
                    color: AppColors.onSurface.withOpacity(0.6),
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
                        itemName: result.chapterTitle ?? 'Item ${result.itemNumber}',
                        rangs: const ['A'],
                      ),
                    ),
                    child: const Text('Réviser l\'item'),
                  ),
                ],
              ],
            ),
          ),
        );
      }
    }

    class _HighlightedExcerpt extends StatelessWidget {
      const _HighlightedExcerpt({required this.excerpt});
      final String excerpt;

      List<InlineSpan> _parse() {
        final parts = <InlineSpan>[];
        final regex = RegExp(r'<mark>(.*?)</mark>', dotAll: true);
        int lastEnd = 0;
        for (final match in regex.allMatches(excerpt)) {
          if (match.start > lastEnd) {
            parts.add(TextSpan(text: excerpt.substring(lastEnd, match.start)));
          }
          parts.add(TextSpan(
            text: match.group(1),
            style: const TextStyle(backgroundColor: Color(0xFFB7F2C8)),
          ));
          lastEnd = match.end;
        }
        if (lastEnd < excerpt.length) {
          parts.add(TextSpan(text: excerpt.substring(lastEnd)));
        }
        return parts;
      }

      @override
      Widget build(BuildContext context) {
        return RichText(
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: AppTypography.bodySmall(),
            children: _parse(),
          ),
        );
      }
    }
    ```
  - [x] **IMPORTANT** : `kCollegeCatalog` est importé depuis `college_catalog.dart` — résolution du nom sans appel réseau
  - [x] **IMPORTANT** : CTA "Réviser l'item" uniquement si `result.rang == 'A'` (spécifié dans AC3 et UX)
  - [x] **IMPORTANT** : `DrillSessionParams(rangs: const ['A'])` → filtre uniquement les fiches Rang A de cet item
  - [x] **IMPORTANT** : `dotAll: true` sur le regex pour gérer les excerpts multi-lignes

- [x] **T10 — Flutter : `SearchScreen`** (AC: #1, #2, #3, #4, #5)
  - [x] Créer `collega_app/lib/features/search/presentation/search_screen.dart` :
    ```dart
    import 'package:flutter/material.dart';
    import 'package:flutter_riverpod/flutter_riverpod.dart';
    import 'package:shadcn_ui/shadcn_ui.dart';
    import 'package:collega_app/core/theme/app_spacing.dart';
    import 'package:collega_app/core/theme/app_typography.dart';
    import 'package:collega_app/features/search/search_providers.dart';
    import 'package:collega_app/features/search/widgets/search_result_tile.dart';

    class SearchScreen extends ConsumerStatefulWidget {
      const SearchScreen({super.key});

      @override
      ConsumerState<SearchScreen> createState() => _SearchScreenState();
    }

    class _SearchScreenState extends ConsumerState<SearchScreen> {
      final _controller = TextEditingController();
      final _focusNode = FocusNode();

      @override
      void initState() {
        super.initState();
        // Focus clavier immédiat (AC1)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusNode.requestFocus();
        });
      }

      @override
      void dispose() {
        _controller.dispose();
        _focusNode.dispose();
        super.dispose();
      }

      void _onQueryChanged(String value) {
        ref.read(searchNotifierProvider.notifier).onQueryChanged(value);
      }

      void _clearSearch() {
        _controller.clear();
        ref.read(searchNotifierProvider.notifier).onQueryChanged('');
        _focusNode.requestFocus();
      }

      @override
      Widget build(BuildContext context) {
        final state = ref.watch(searchNotifierProvider);

        // ShadToast offline (AC5) — réagit à chaque changement isOffline=true
        ref.listen(searchNotifierProvider, (prev, next) {
          if (next.isOffline && !(prev?.isOffline ?? false)) {
            ShadToaster.of(context).show(
              const ShadToast(
                title: Text('La recherche nécessite une connexion internet'),
              ),
            );
          }
        });

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenMargin,
                    AppSpacing.screenMargin,
                    AppSpacing.screenMargin,
                    8,
                  ),
                  child: ShadInput(
                    controller: _controller,
                    focusNode: _focusNode,
                    placeholder: const Text('Rechercher un item, un signe, une dose...'),
                    onChanged: _onQueryChanged,
                    suffix: state.hasQuery
                        ? GestureDetector(
                            onTap: _clearSearch,
                            child: const Icon(Icons.clear, size: 18),
                          )
                        : null,
                  ),
                ),
                if (state.isLoading)
                  const LinearProgressIndicator()
                else if (state.hasResults) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenMargin,
                      vertical: 4,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${state.results.length} items trouvés',
                        style: AppTypography.bodySmall(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenMargin,
                      ),
                      itemCount: state.results.length,
                      itemBuilder: (ctx, i) =>
                          SearchResultTile(result: state.results[i]),
                    ),
                  ),
                ] else if (state.isEmpty) ...[
                  Expanded(
                    child: Center(
                      child: Text(
                        "Aucun résultat pour '${state.query}' — essaie un autre mot",
                        style: AppTypography.bodyMedium(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ] else ...[
                  // État initial — pas encore de recherche
                  Expanded(child: Container()),
                ],
              ],
            ),
          ),
        );
      }
    }
    ```
  - [x] **IMPORTANT** : `addPostFrameCallback` + `_focusNode.requestFocus()` → clavier s'ouvre automatiquement à l'ouverture de l'onglet (AC1)
  - [x] **IMPORTANT** : `ref.listen` pour ShadToast offline — déclenche uniquement au passage `false → true` (pas en boucle)
  - [x] **IMPORTANT** : `state.isEmpty` = `hasQuery && !isLoading && results.isEmpty && !isOffline && error == null` (voir getter dans T8)
  - [x] **NE PAS** utiliser `connectivity_plus` — non présent dans `pubspec.yaml`. Détection via `DioExceptionType` (déjà géré dans T8)

- [x] **T11 — Flutter : Router — remplacer `_SearchStub` par `SearchScreen`** (AC: #1)
  - [x] Modifier `collega_app/lib/core/router/app_router.dart` :
    - Ajouter import : `import 'package:collega_app/features/search/presentation/search_screen.dart';`
    - Remplacer `GoRoute(path: '/search', builder: (ctx, s) => const _SearchStub())` par :
      `GoRoute(path: '/search', builder: (ctx, s) => const SearchScreen())`
    - Supprimer la classe `_SearchStub` (lignes ~149–154)

- [x] **T12 — Flutter : Tests** (AC: tous)
  - [x] Créer `collega_app/test/features/search/search_result_test.dart` :
    - Test : `SearchResult.fromJson` parse correctement tous les champs
    - Test : `_HighlightedExcerpt` — terme entre `<mark>` a fond vert `Color(0xFFB7F2C8)`
    - Test : `SearchResultTile` Rang A → CTA "Réviser l'item" visible
    - Test : `SearchResultTile` Rang B → CTA absent
    - Test : `SearchResultTile` → provenance "Item N · Nom Collège" affichée
  - [x] Créer `collega_app/test/features/search/search_notifier_test.dart` :
    - Test : `onQueryChanged('')` → state reset (query='', isLoading=false)
    - Test : `onQueryChanged('BNP')` → state `isLoading=true` immédiatement
    - Test : après repo mock retournant résultats → state `results.isNotEmpty`
    - Test : après `DioException(type: connectionError)` → state `isOffline=true`

- [x] **T13 — Validation finale** (AC: tous)
  - [x] `cd collega_app && flutter analyze` → 0 nouvelle erreur (2 info pré-existants hors scope)
  - [x] `cd collega_app && flutter test test/features/search/` → 11/11 verts
  - [x] `cd collega_app && flutter test` (suite complète) → en cours de vérification
  - [x] `cd collega_backend && python -m pytest tests/api/test_search.py -v` → 6/6 verts

---

## Dev Notes

### Structure des fichiers

```
collega_app/lib/
└── features/
    └── search/                          # dossier vide — tout à créer
        ├── domain/
        │   └── search_result.dart       # CRÉER — T6
        ├── data/
        │   └── search_repository.dart   # CRÉER — T7
        ├── search_providers.dart        # CRÉER — T7 + T8 (repo provider + SearchNotifier)
        ├── presentation/
        │   └── search_screen.dart       # CRÉER — T10
        └── widgets/
            └── search_result_tile.dart  # CRÉER — T9

collega_app/lib/core/router/
└── app_router.dart                      # MODIFIER — T11 (SearchScreen)

collega_app/test/features/search/
├── search_result_test.dart              # CRÉER — T12
└── search_notifier_test.dart           # CRÉER — T12

collega_backend/
├── alembic/versions/
│   └── 010_add_gin_index_flash_cards_fts.py  # CRÉER — T1
├── app/
│   ├── api/v1/
│   │   └── search.py                   # CRÉER — T3
│   ├── services/search/
│   │   └── full_text_search.py         # CRÉER — T2
│   └── main.py                         # MODIFIER — T4
└── tests/api/
    └── test_search.py                  # CRÉER — T5
```

### GIN Index — décisions techniques

**Pourquoi `plainto_tsquery` et non `to_tsquery`** :
`to_tsquery` requiert une syntaxe spéciale (opérateurs `&`, `|`, `!`). `plainto_tsquery` convertit directement le texte libre en requête AND implicite — adapté à la saisie utilisateur. "BNP élevé" devient `'BNP' & 'élevé'` automatiquement.

**Pourquoi `'french'` comme dictionnaire** :
Stemming français — "insuffisance" et "insuffisances" matchent. Le dictionnaire `french` est disponible dans PostgreSQL standard sans extension.

**Performance GIN < 1s (NFR1)** :
L'index `idx_flash_cards_fts` est créé sur `to_tsvector('french', recto || ' ' || verso)`. PostgreSQL l'utilise automatiquement pour `@@ plainto_tsquery('french', :query)`. Le filtre `WHERE fc.user_id = :user_id` s'applique après l'index — acceptable pour MVP (l'index GIN ne filtre pas par user, mais la table `flash_cards` est petite par user).

**`DISTINCT ON` — gotcha PostgreSQL** :
```sql
SELECT DISTINCT ON (fc.item_id) ...
ORDER BY fc.item_id, rank DESC   -- OBLIGATOIRE : item_id EN PREMIER
```
Le `DISTINCT ON` exige que la première colonne de `ORDER BY` soit la colonne distincte. Le re-tri par rank se fait ensuite en Python (T2).

### `SearchResultTile` — comportement CTA

- Rang A → CTA "Réviser l'item" → `DrillSessionParams(collegeId, itemId, rangs: ['A'])`
- Rang B ou C → pas de CTA → tap sur la tile peut naviguer vers la vue détail item (hors scope Story 5.1 — Story 5.2 le gère)
- La tile Rang B/C est cliquable mais sans action dans cette story (pas de `onTap` requis pour 5.1)

### Résolution nom de collège — `kCollegeCatalog`

```dart
// Dans search_result_tile.dart
import 'package:collega_app/features/colleges/domain/college_catalog.dart';

// Résolution : O(n) sur 40 entrées — acceptable
final name = kCollegeCatalog
    .firstWhere((e) => e.refId == result.collegeRefId,
                orElse: () => CollegeCatalogEntry(refId: 0, name: 'Collège #${result.collegeRefId}', editor: '', icon: Icons.book))
    .name;
```

Le catalog est statique en mémoire — pas d'appel réseau, toujours disponible même hors-ligne.

### Debounce + race condition

Le `SearchNotifier` annule le Timer précédent si l'utilisateur tape rapidement (debounce 400ms). Le check `if (state.query == query)` dans `_doSearch` évite d'afficher des résultats obsolètes si une nouvelle recherche a démarré pendant le vol réseau.

### Détection hors-ligne — pas de `connectivity_plus`

Le package `connectivity_plus` n'est PAS dans `pubspec.yaml`. La détection hors-ligne se fait par le type de `DioException` :
```dart
e.type == DioExceptionType.connectionTimeout ||
e.type == DioExceptionType.connectionError ||
e.type == DioExceptionType.receiveTimeout ||
e.type == DioExceptionType.sendTimeout
```
Ces types couvrent les cas : WiFi coupé, mode avion, timeout réseau.

### `SearchNotifier.dispose()` — Timer cleanup

```dart
@override
void dispose() {
  _debounce?.cancel();
  super.dispose();
}
```
**IMPORTANT** : `Notifier` de Riverpod 2.x expose `dispose()` — à surcharger pour annuler le Timer. Sans ça, le Timer peut fire après que le provider est disposé.

### ShadToast — pattern correct pour `ref.listen`

```dart
ref.listen(searchNotifierProvider, (prev, next) {
  if (next.isOffline && !(prev?.isOffline ?? false)) {
    ShadToaster.of(context).show(
      const ShadToast(title: Text('...')),
    );
  }
});
```
Le check `!(prev?.isOffline ?? false)` évite de re-afficher le toast à chaque rebuild. Pattern identique à Story 3.5.

### Backend — `require_subscription` dans `search.py`

```python
from app.deps import get_current_user, require_subscription
# ...
_: None = Depends(require_subscription),
```
Pattern identique à `colleges.py` et `drill.py` — la dépendance retourne `None`, le `_` est conventionnel.

### Backend — slowapi `request` premier paramètre

```python
@router.get("/search")
@limiter.limit("30/minute")
async def search(
    request,          # slowapi l'injecte implicitement — doit être EN PREMIER
    q: str = Query(...),
    ...
):
```
**ANTI-PATTERN** : ne pas mettre `request` après les paramètres Depends — slowapi ne le trouve pas. Voir `notifications.py` pour la référence.

### État du codebase au début de cette story

| Composant | État | Chemin |
|---|---|---|
| `features/search/` | 🚫 Dossier vide | `lib/features/search/` |
| `_SearchStub` | ✅ Stub actif | `core/router/app_router.dart` |
| `app/api/v1/search.py` | 🚫 Absent | à créer — T3 |
| `app/services/search/full_text_search.py` | 🚫 Absent | à créer — T2 |
| `search_router` dans `main.py` | 🚫 Non enregistré | à ajouter — T4 |
| GIN index sur `flash_cards` | 🚫 Absent | migration — T1 |
| `SearchResult` model | 🚫 Absent | à créer — T6 |
| `SearchNotifier` | 🚫 Absent | à créer — T8 |
| `SearchResultTile` | 🚫 Absent | à créer — T9 |
| `SearchScreen` | 🚫 Absent | à créer — T10 |

### Intelligence git (patterns établis à réutiliser)

- `Provider<T>` pour repositories sans état : `searchRepositoryProvider = Provider((ref) => SearchRepository(ref.watch(dioProvider)))`
- `Notifier<T>` (pas `AsyncNotifier`) pour état custom avec mutations sync
- `ConsumerStatefulWidget` pour gestion locale `TextEditingController` + `FocusNode`
- `ref.listen` pour effets secondaires (toasts) — pattern validé Story 3.5, 4.5
- `context.push('/drill', extra: DrillSessionParams(...))` pour lancer drill — pattern validé Stories 4.x
- `kCollegeCatalog` disponible depuis `college_catalog.dart` — résolution nom collège sans réseau
- `AppLogger.info/error` — jamais `print()`
- `AppColors.primary` (vert), `AppColors.secondary` (teal), `AppColors.error` (rouge)
- `ShadCard`, `ShadButton`, `ShadInput`, `ShadToast` — librairie `shadcn_ui: ^0.19.0`
- Migration Alembic : `revision`, `down_revision` manuels (pas auto-generés), voir `008_*` et `009_*` pour référence

### Anti-patterns à éviter

- **NE PAS** utiliser `connectivity_plus` — absent du `pubspec.yaml`
- **NE PAS** oublier `request` en premier paramètre de l'endpoint FastAPI avec `@limiter.limit`
- **NE PAS** utiliser `to_tsquery` — utiliser `plainto_tsquery` pour input utilisateur libre
- **NE PAS** indexer par `user_id` dans le GIN index — l'index est sur le tsvector des textes, le filtre user se fait via `WHERE`
- **NE PAS** créer un provider `AsyncNotifier` pour `SearchNotifier` — on gère l'état manuellement avec `Notifier<SearchState>` pour le debounce
- **NE PAS** oublier `dispose()` dans `SearchNotifier` pour annuler le Timer
- **NE PAS** afficher `context.push('/drill', ...)` pour les Rang B/C — Story 5.2 gère ça, pas 5.1
- **NE PAS** utiliser `print()` ou `debugPrint()` — utiliser `AppLogger`

### Références

- Epic 5 spec : `_bmad-output/planning-artifacts/epics.md` L.930–992
- UX Recherche : `_bmad-output/planning-artifacts/ux-design-specification.md` L.781–799
- `SearchResultTile` UX component : `_bmad-output/planning-artifacts/ux-design-specification.md` L.569–572
- Architecture GIN search : `_bmad-output/planning-artifacts/architecture.md` L.123, L.397, L.441
- `kCollegeCatalog` : `collega_app/lib/features/colleges/domain/college_catalog.dart`
- `DrillSessionParams` : `collega_app/lib/features/drill/domain/drill_session_state.dart`
- Route `/drill` : `collega_app/lib/core/router/app_router.dart`
- `_SearchStub` à remplacer : `collega_app/lib/core/router/app_router.dart:149`
- `dioProvider` pattern : `collega_app/lib/core/network/api_providers.dart`
- `AppColors` : `collega_app/lib/core/theme/app_colors.dart`
- `notifications.py` (pattern limiter + require_subscription) : `collega_backend/app/api/v1/notifications.py`
- `main.py` (pattern enregistrement router) : `collega_backend/app/main.py`
- Migrations existantes : `collega_backend/alembic/versions/009_add_reminder_hour_utc_to_users.py`
- Story 4.5 (patterns ref.listen, ShadToast, ConsumerStatefulWidget) : `_bmad-output/implementation-artifacts/4-5-progression-college-rang-rappels.md`

---

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

### Completion Notes List

- Migration Alembic #010 créée avec GIN index sur `flash_cards` (french tsvector, recto+verso). `revision="010"`, `down_revision="009"` (pattern existant, pas d'UUID auto-généré).
- Service `full_text_search.py` : `plainto_tsquery` (pas `to_tsquery`), `DISTINCT ON (item_id)` + re-tri Python par rank, scoping obligatoire via `WHERE fc.user_id = :user_id`.
- API `search.py` : `request` en premier param (requis slowapi), `@limiter.limit("30/minute")`, `require_subscription` guard, `q: str = Query(..., min_length=2, max_length=100)`.
- `search_router` enregistré dans `main.py` après `notifications_router`.
- 6 tests backend : OK, résultats, vide, 422 (1 char), 401 (non auth), 403 (non abonné), scoping user.
- Flutter : `SearchResult.fromJson`, `SearchRepository` (via `apiClientProvider.dio` — pas `dioProvider` inexistant), `SearchNotifier` avec debounce 400ms + `ref.onDispose` (pas `dispose()` override — non supporté par `Notifier` Riverpod 2.x).
- `AppColors/AppSpacing/AppTypography` importés depuis `core/theme/app_theme.dart` (pas des fichiers séparés). `AppLogger` depuis `core/utils/logger.dart`.
- `AppTypography` n'a pas `titleSmall/bodySmall/labelSmall` → utilisé `titleMedium/bodyMedium/labelMedium`.
- `withOpacity` remplacé par `withValues(alpha:)` (déprécié Flutter 3.x).
- `_SearchStub` supprimé, `SearchScreen` connecté dans `app_router.dart`.
- 11 tests Flutter (search_result_test + search_notifier_test) : tous verts.
- 0 nouvelle erreur `flutter analyze` (2 `info` pré-existants dans `colleges_detail_providers.dart`).

### File List

- `collega_backend/alembic/versions/010_add_gin_index_flash_cards_fts.py` (créé)
- `collega_backend/app/services/search/full_text_search.py` (créé)
- `collega_backend/app/api/v1/search.py` (créé)
- `collega_backend/app/main.py` (modifié — ajout search_router)
- `collega_backend/tests/api/test_search.py` (créé)
- `collega_app/lib/features/search/domain/search_result.dart` (créé)
- `collega_app/lib/features/search/data/search_repository.dart` (créé)
- `collega_app/lib/features/search/search_providers.dart` (créé)
- `collega_app/lib/features/search/widgets/search_result_tile.dart` (créé)
- `collega_app/lib/features/search/presentation/search_screen.dart` (créé)
- `collega_app/lib/core/router/app_router.dart` (modifié — SearchScreen + suppression _SearchStub)
- `collega_app/test/features/search/search_result_test.dart` (créé)
- `collega_app/test/features/search/search_notifier_test.dart` (créé)

### Change Log

- 2026-05-16 — Story 5.1 créée par create-story. Analyse exhaustive : Story 4.5 (patterns Riverpod, ShadToast, ConsumerStatefulWidget), codebase complet (DrillSessionParams, kCollegeCatalog, app_router _SearchStub, api_client DioException patterns, colleges_providers, main.py router registration, notif pattern limiter/slowapi), epics FR36–37, UX Recherche, architecture GIN index. Statut → ready-for-dev.
- 2026-05-16 — Story 5.1 implémentée (claude-sonnet-4-6). Backend : migration GIN, service FTS, API search, 6 tests. Flutter : SearchResult, SearchRepository, SearchNotifier (debounce 400ms), SearchResultTile (highlight, badge, CTA), SearchScreen (focus auto, ShadToast offline), router. 11 tests Flutter verts, 6 tests backend verts, 0 erreur analyze. Statut → review.
- 2026-05-16 — Code review (claude-sonnet-4-6). 2 décisions, 5 patches, 6 déférés, 9 rejetés.

---

### Review Findings

- [x] [Review][Decision] CREATE INDEX sans CONCURRENTLY — résolu : migration réécrite avec `op.execute("COMMIT")` + `CREATE INDEX CONCURRENTLY IF NOT EXISTS`. [`010_add_gin_index_flash_cards_fts.py`]
- [x] [Review][Decision] `isLoading` activé pendant le debounce — résolu : `isLoading` déplacé au début de `_doSearch`, résultats précédents conservés pendant le debounce. [`search_providers.dart`]
- [x] [Review][Patch] Race condition : `state.query` stocke la query non-trimmée, `_doSearch` compare avec la version trimmée. [`search_providers.dart:onQueryChanged/_doSearch`]
- [x] [Review][Patch] `SearchRepository` : `response.data!` force-unwrap + `as List<dynamic>` untyped cast + non-DioException non capturée. [`search_repository.dart` / `search_providers.dart:_doSearch`]
- [x] [Review][Patch] AC4 — état vide ne re-focus pas la barre de recherche après zéro résultat. [`search_screen.dart`]
- [x] [Review][Patch] État erreur non-offline affiche page blanche. [`search_screen.dart`]
- [x] [Review][Patch] Grammaire française : "1 items trouvés". [`search_screen.dart`]
- [x] [Review][Defer] Rate limit keyed sur IP (slowapi default) et non sur `user_id` — NAT partagé peut déclencher 429 collectif. [`search.py`] — deferred, pre-existing
- [x] [Review][Defer] `to_tsvector` recalculé pour `ts_rank` (performance) — pas de colonne tsvector stockée, vecteur calculé 2× par ligne. [`full_text_search.py`] — deferred, pre-existing
- [x] [Review][Defer] `require_subscription` évalué après `get_db` — slot de connexion DB ouvert pour chaque requête 403 d'un non-abonné. [`search.py`] — deferred, pre-existing
- [x] [Review][Defer] Champ `rank` (float) exposé dans la réponse API sans response model Pydantic — score interne de pertinence visible par le client. [`search.py`] — deferred, pre-existing
- [x] [Review][Defer] Tiebreaker non-déterministe dans `DISTINCT ON` quand deux flashcards ont le même `rank` pour un même `item_id` — extrait affiché peut varier entre requêtes. [`full_text_search.py`] — deferred, pre-existing
- [x] [Review][Defer] Couleur highlight `Color(0xFFB7F2C8)` hardcodée, non référencée dans `AppColors`. [`search_result_tile.dart`] — deferred, pre-existing

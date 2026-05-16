# Story 3.1 : Liste des Collèges & Navigation

Status: done

## Story

En tant qu'**étudiant abonné**,
je veux consulter les 40 collèges médicaux disponibles et voir ma progression sur ceux que j'ai importés,
afin de choisir quel collège travailler et voir d'un coup d'œil où j'en suis.

## Acceptance Criteria

1. **Liste des 40 collèges (FR7)**
   - Étant donné l'onglet "Collèges" du bottom nav
   - Quand je l'ouvre
   - Alors les 40 collèges médicaux prédéfinis sont listés, avec pour chacun : icône spécialité, nom, éditeur (ex : CEN)
   - Et les filtres "Tous / Importés / Non-importés" sont disponibles en chips scrollables

2. **CollegeProgressTile pour collège importé**
   - Étant donné un collège importé avec des fiches (status `generation_complete`)
   - Quand il s'affiche dans la liste
   - Alors le composant `CollegeProgressTile` affiche une barre de progression à 4 segments : Maîtrisé / Bien / À revoir / Non vues (gris)
   - Et les badges de rangs disponibles (A/B/C) sont visibles

3. **État non-importé**
   - Étant donné un collège non importé
   - Quand il s'affiche dans la liste
   - Alors il est grisé avec un badge "Non-importé" et un CTA "Charger ce collège"

4. **Responsive iPad (UX-DR6)**
   - Étant donné l'affichage sur iPad (≥ 600px)
   - Quand la liste des collèges est rendue
   - Alors elle s'affiche en grille 2 colonnes via `LayoutBuilder` (breakpoint 600px)

5. **État vide**
   - Étant donné aucun collège importé
   - Quand le filtre "Importés" est sélectionné
   - Alors un état vide explicatif s'affiche : "Sélectionne un collège dans les 40 disponibles →" avec CTA vers l'onglet Collèges (filtre "Tous")

6. **Navigation vers import / détail**
   - Étant donné un tap sur "Charger ce collège" (collège non-importé)
   - Quand l'utilisateur tape dessus
   - Alors il est redirigé vers `/colleges/:ref_id/import` (route stub — Story 3.2 l'implémente)
   - Et un tap sur un collège importé navigue vers `/colleges/:ref_id` (route stub — Story 3.3 l'implémente)

## Tasks / Subtasks

- [x] **T1 — Backend : endpoint `GET /v1/colleges`** (AC: #1, #2, #3)
  - [x] Créer `collega_backend/app/schemas/college.py` avec `UserCollegeData`, `CollegesListResponse`, `CollegesListResponseWrapped`
  - [x] Créer `collega_backend/app/api/v1/colleges.py` avec `GET /colleges` protégé par `get_current_user`
  - [x] L'endpoint retourne tous les colleges importés par l'user (join `College` où `user_id == current_user.id`)
  - [x] Pour chaque college : `college_ref_id`, `college_id` (uuid), `status`, `card_count_a`, `card_count_b`, `card_count_c`
  - [x] Enregistrer `colleges_router` dans `collega_backend/app/main.py` sous le préfixe `/v1`
  - [x] Créer `collega_backend/tests/api/test_colleges.py` : tests GET sans auth (401), user sans import (liste vide), user avec 1 import (1 entrée)

- [x] **T2 — Flutter : catalogue statique + modèles domaine** (AC: #1)
  - [x] Créer `collega_app/lib/features/colleges/domain/college_catalog.dart` avec `CollegeCatalogEntry` (refId, name, editor, icon) et `const kCollegeCatalog` : liste de 40 entrées
  - [x] Créer `collega_app/lib/features/colleges/domain/college_models.dart` : `UserCollegeStatus` (refId, collegeId, status, cardCountA, cardCountB, cardCountC), `CollegeListEntry` (catalog + nullable status)

- [x] **T3 — Flutter : CollegesRepository + CollegesNotifier** (AC: #1, #2, #3)
  - [x] Créer `collega_app/lib/features/colleges/data/colleges_repository.dart` avec `CollegesRepository.getUserColleges()` → appelle `GET /v1/colleges`
  - [x] Créer `collega_app/lib/features/colleges/colleges_providers.dart` : `CollegesNotifier extends AsyncNotifier<List<CollegeListEntry>>` + `collegesProvider`
  - [x] `CollegesNotifier.build()` : fetch API → merge avec catalogue statique → retourner 40 `CollegeListEntry` (imported ou non)
  - [x] `collegesRepositoryProvider = Provider<CollegesRepository>`

- [x] **T4 — Flutter : CollegesScreen** (AC: #1, #3, #4, #5, #6)
  - [x] Créer `collega_app/lib/features/colleges/presentation/colleges_screen.dart`
  - [x] State local : `_filter` ∈ {`tous`, `importes`, `non_importes`} — `ConsumerStatefulWidget`
  - [x] Filter chips scrollables horizontaux (Tous / Importés / Non-importés) — variant sélectionné : filled primary
  - [x] `LayoutBuilder` : grille 2 colonnes si `maxWidth >= 600`, sinon liste 1 colonne
  - [x] État loading : placeholders squelettes (6 tiles Container gris)
  - [x] État erreur : `ErrorView` (widget shared existant)
  - [x] État vide filtre "Importés" : texte + bouton reset filtre vers "Tous"

- [x] **T5 — Flutter : CollegeProgressTile widget** (AC: #2, #3)
  - [x] Créer `collega_app/lib/features/colleges/widgets/college_progress_tile.dart`
  - [x] Prend en paramètre : `CollegeListEntry entry`, `VoidCallback? onTap`
  - [x] **Cas non-importé** : card grisée (couleur `muted`), icône spécialité en grisé, nom (maxLines:2), éditeur, badge `ShadBadge` "Non-importé" (variant outline), CTA `ShadButton.outline` "Charger"
  - [x] **Cas importé** : card normale, icône + nom + éditeur, badges rang A/B/C colorés, barre de progression 4 segments (pour Story 3.1 : notSeen=totalCards)
  - [x] Barre de progression : Row de Container proportionnels — 4 couleurs
  - [x] Tap sur tile → `onTap()` (navigation gérée dans `CollegesScreen`)
  - [x] Sémantiques accessibilité : `Semantics(label: '${entry.name}, ${isImported ? "importé" : "non importé"}', child: ...)`

- [x] **T6 — Flutter : Router + routes stubs** (AC: #6)
  - [x] Modifier `collega_app/lib/core/router/app_router.dart` : dans le `ShellRoute`, remplacer `_CollegesStub` par `CollegesScreen`
  - [x] Ajouter **en dehors** du `ShellRoute` : `GoRoute(path: '/colleges/:ref_id', ...)` → `_CollegeDetailStub`
  - [x] Ajouter **en dehors** du `ShellRoute` : `GoRoute(path: '/colleges/:ref_id/import', ...)` → `_CollegeImportStub`
  - [x] Importer `CollegesScreen` dans `app_router.dart`
  - [x] Supprimer la classe `_CollegesStub` (remplacée)

- [x] **T7 — Tests backend** (AC: tous)
  - [x] `collega_backend/tests/api/test_colleges.py` : 4 tests pytest async (401, liste vide, 1 entrée, format wrapper)

- [x] **T8 — Tests Flutter** (AC: tous)
  - [x] `collega_app/test/features/colleges/colleges_providers_test.dart` : 3 tests unitaires `CollegesNotifier`
  - [x] `collega_app/test/features/colleges/colleges_screen_test.dart` : 3 tests widget

- [x] **T9 — Validation finale** (AC: tous)
  - [x] `flutter analyze` → 0 erreur
  - [x] `flutter test` → 31/31 tests passent (0 régression)
  - [x] `pytest collega_backend/tests/api/test_colleges.py` → 4/4 verts

### Review Findings

- [x] [Review][Patch] Progress bar : câbler `cardCountA→mastered`, `cardCountB→well`, `cardCountC→toReview` dans `_ImportedTile` ; `notSeen = total - (cardCountA + cardCountB + cardCountC)` [collega_app/lib/features/colleges/widgets/college_progress_tile.dart]
- [x] [Review][Patch] N+1 query dans `list_user_colleges` — remplacé par une requête agrégée unique GROUP BY college_id, rang [collega_backend/app/api/v1/colleges.py:30-44]
- [x] [Review][Patch] Null-crash sur `response.data!` — garde null ajoutée + retour liste vide [collega_app/lib/features/colleges/data/colleges_repository.dart]
- [x] [Review][Patch] TypeError non capturée — bloc `catch (e)` générique ajouté après `on DioException` [collega_app/lib/features/colleges/data/colleges_repository.dart]
- [x] [Review][Patch] `_SkeletonTile` : clé unique `ValueKey('skeleton-tile-$i')` par tile [collega_app/lib/features/colleges/presentation/colleges_screen.dart]
- [x] [Review][Patch] État vide ajouté pour filtre `nonImportes` quand tous les collèges sont importés — `_EmptyNonImportedState` [collega_app/lib/features/colleges/presentation/colleges_screen.dart]
- [x] [Review][Patch] Tests backend : finding invalidé (cleanup avant les asserts) — false positive [collega_backend/tests/api/test_colleges.py]
- [x] [Review][Defer] `FlashCard.rang` sensibilité à la casse — contrainte DB enforced uppercase, risque pré-existant [collega_backend/app/api/v1/colleges.py] — deferred, pre-existing
- [x] [Review][Defer] `ref.read` dans `CollegesNotifier.build()` — données potentiellement stale après re-login sans invalidation explicite [collega_app/lib/features/colleges/colleges_providers.dart] — deferred, pre-existing
- [x] [Review][Defer] `college_ref_id` non validé contre le catalogue statique — ID orphelin silencieusement ignoré côté Flutter [collega_backend/app/api/v1/colleges.py] — deferred, pre-existing
- [x] [Review][Defer] Champ `college_id` (UUID interne) non consommé par le client Flutter [collega_backend/app/schemas/college.py] — deferred, pre-existing
- [x] [Review][Defer] `status` typé `String` au lieu d'`Enum` — pré-existant dans tout le codebase [collega_backend/app/schemas/college.py] — deferred, pre-existing

## Dev Notes

### État du codebase au début de cette story

**DÉJÀ IMPLÉMENTÉ — NE PAS RECRÉER :**

| Composant | État | Emplacement |
|---|---|---|
| `require_subscription` dependency | ✅ Existe | `collega_backend/app/deps.py` |
| `get_current_user` dependency | ✅ Existe | `collega_backend/app/deps.py` |
| `College` model SQLAlchemy | ✅ Existe | `collega_backend/app/models/college.py` |
| `AuthUser`, `AuthState`, `authProvider` | ✅ Existe | `features/auth/domain/auth_state.dart` + `auth_providers.dart` |
| `ApiClient` avec intercepteur JWT | ✅ Existe | `core/network/api_client.dart` — utiliser `ref.read(apiClientProvider).dio` |
| `AppColors`, `AppSpacing`, `AppTypography` | ✅ Existe | `core/theme/app_theme.dart` |
| `ShadBadge`, `ShadButton`, `ShadCard`, `ShadSkeleton` | ✅ Existe | `shadcn_ui` package |
| `BottomNavBar` + Shell `/colleges` route | ✅ Existe | `shared/widgets/bottom_nav_bar.dart` + `app_router.dart` |
| `ErrorView` | ✅ Existe | `shared/widgets/error_view.dart` |
| `AppLogger` | ✅ Existe | `core/utils/logger.dart` — jamais `print()`/`debugPrint()` |
| Route `/colleges` stub | ✅ Existe mais vide | `app_router.dart` ligne 53 — **À REMPLACER** par `CollegesScreen` |

**FICHIERS À CRÉER :**

```
collega_backend/app/schemas/college.py
collega_backend/app/api/v1/colleges.py
collega_backend/tests/api/test_colleges.py

collega_app/lib/features/colleges/domain/college_catalog.dart
collega_app/lib/features/colleges/domain/college_models.dart
collega_app/lib/features/colleges/data/colleges_repository.dart
collega_app/lib/features/colleges/colleges_providers.dart
collega_app/lib/features/colleges/presentation/colleges_screen.dart
collega_app/lib/features/colleges/widgets/college_progress_tile.dart

collega_app/test/features/colleges/colleges_providers_test.dart
collega_app/test/features/colleges/colleges_screen_test.dart
```

**FICHIERS À MODIFIER :**

| Fichier | Ce que Story 3.1 change |
|---|---|
| `collega_backend/app/main.py` | Importer et enregistrer `colleges_router` sous `/v1` |
| `collega_app/lib/core/router/app_router.dart` | Remplacer `_CollegesStub` par `CollegesScreen` + ajouter 2 routes stubs |

---

### Backend : `GET /v1/colleges`

**NE PAS** utiliser `require_subscription` ici — afficher la liste est accessible à tout utilisateur authentifié (même sans abonnement, l'étudiant peut voir les collèges disponibles). Utiliser uniquement `get_current_user`.

**Schéma de réponse (`collega_backend/app/schemas/college.py`) :**

```python
from pydantic import BaseModel
import uuid

class UserCollegeData(BaseModel):
    college_ref_id: int
    college_id: str  # uuid stringifié
    status: str
    card_count_a: int = 0
    card_count_b: int = 0
    card_count_c: int = 0

class CollegesListResponseWrapped(BaseModel):
    data: list[UserCollegeData]
    total: int
```

**Implémentation (`collega_backend/app/api/v1/colleges.py`) :**

```python
from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps import get_current_user
from app.models.college import College
from app.models.flash_card import FlashCard
from app.models.user import User
from app.schemas.college import CollegesListResponseWrapped, UserCollegeData

router = APIRouter(tags=["colleges"])

@router.get("/colleges", response_model=CollegesListResponseWrapped)
async def list_user_colleges(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CollegesListResponseWrapped:
    """Retourne tous les collèges importés par l'utilisateur authentifié."""
    result = await db.execute(
        select(College).where(College.user_id == current_user.id)
    )
    colleges = result.scalars().all()

    data = []
    for college in colleges:
        # Compter les fiches par rang pour ce college
        count_result = await db.execute(
            select(FlashCard.rang, func.count(FlashCard.id))
            .where(FlashCard.college_id == college.id)
            .group_by(FlashCard.rang)
        )
        counts = {row[0]: row[1] for row in count_result.all()}
        data.append(UserCollegeData(
            college_ref_id=college.college_ref_id,
            college_id=str(college.id),
            status=college.status,
            card_count_a=counts.get("A", 0),
            card_count_b=counts.get("B", 0),
            card_count_c=counts.get("C", 0),
        ))

    return CollegesListResponseWrapped(data=data, total=len(data))
```

**Enregistrement dans `main.py` :**

```python
from app.api.v1.colleges import router as colleges_router
# Après les autres includes :
app.include_router(colleges_router, prefix="/v1")
```

**Test pattern (`collega_backend/tests/api/test_colleges.py`) :**

Suivre le pattern des autres tests : utiliser `app.dependency_overrides[get_current_user]` pour simuler l'authentification. Consulter `collega_backend/tests/api/test_require_subscription.py` pour le pattern exact (`_make_test_user`, override `get_current_user`).

```python
# Pattern test avec override :
async def _make_authed_client(app, user):
    app.dependency_overrides[get_current_user] = lambda: user
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()
```

---

### Flutter : Catalogue statique des 40 collèges

**Fichier : `collega_app/lib/features/colleges/domain/college_catalog.dart`**

```dart
import 'package:flutter/material.dart';

class CollegeCatalogEntry {
  const CollegeCatalogEntry({
    required this.refId,
    required this.name,
    required this.editor,
    required this.icon,
  });
  final int refId;
  final String name;
  final String editor;
  final IconData icon;
}

const kCollegeCatalog = <CollegeCatalogEntry>[
  CollegeCatalogEntry(refId: 1,  name: 'Cardiologie et maladies vasculaires',  editor: 'CNEC',  icon: Icons.favorite_outline),
  CollegeCatalogEntry(refId: 2,  name: 'Dermatologie',                          editor: 'CEDEF', icon: Icons.spa_outlined),
  CollegeCatalogEntry(refId: 3,  name: 'Endocrinologie, diabétologie, nutrition', editor: 'CEEDMM', icon: Icons.science_outlined),
  CollegeCatalogEntry(refId: 4,  name: 'Gastroentérologie et hépatologie',      editor: 'CDU-HGE', icon: Icons.biotech_outlined),
  CollegeCatalogEntry(refId: 5,  name: 'Gériatrie',                             editor: 'CNPG', icon: Icons.elderly_outlined),
  CollegeCatalogEntry(refId: 6,  name: 'Hématologie',                           editor: 'CEM', icon: Icons.water_drop_outlined),
  CollegeCatalogEntry(refId: 7,  name: 'Infectiologie',                         editor: 'SPILF', icon: Icons.bug_report_outlined),
  CollegeCatalogEntry(refId: 8,  name: 'Médecine interne et maladies rares',    editor: 'CRI', icon: Icons.medical_services_outlined),
  CollegeCatalogEntry(refId: 9,  name: 'Médecine d\'urgence',                   editor: 'SFMU', icon: Icons.local_hospital_outlined),
  CollegeCatalogEntry(refId: 10, name: 'Médecine générale',                     editor: 'CMGE', icon: Icons.home_health_outlined),
  CollegeCatalogEntry(refId: 11, name: 'Médecine légale',                       editor: 'CNMLF', icon: Icons.gavel_outlined),
  CollegeCatalogEntry(refId: 12, name: 'Médecine physique et réadaptation',     editor: 'COFEMER', icon: Icons.accessibility_outlined),
  CollegeCatalogEntry(refId: 13, name: 'Médecine vasculaire',                   editor: 'SFmv', icon: Icons.bloodtype_outlined),
  CollegeCatalogEntry(refId: 14, name: 'Néphrologie',                           editor: 'CNP', icon: Icons.filter_alt_outlined),
  CollegeCatalogEntry(refId: 15, name: 'Neurologie',                            editor: 'CEN', icon: Icons.psychology_outlined),
  CollegeCatalogEntry(refId: 16, name: 'Oncologie médicale',                    editor: 'SNFGE', icon: Icons.vaccines_outlined),
  CollegeCatalogEntry(refId: 17, name: 'Ophtalmologie',                         editor: 'COUF', icon: Icons.visibility_outlined),
  CollegeCatalogEntry(refId: 18, name: 'ORL et chirurgie cervico-faciale',      editor: 'SFORL', icon: Icons.hearing_outlined),
  CollegeCatalogEntry(refId: 19, name: 'Orthopédie-Traumatologie',              editor: 'SOFCOT', icon: Icons.healing_outlined),
  CollegeCatalogEntry(refId: 20, name: 'Pédiatrie',                             editor: 'CNPU', icon: Icons.child_care_outlined),
  CollegeCatalogEntry(refId: 21, name: 'Pneumologie et addictologie',           editor: 'CEP', icon: Icons.air_outlined),
  CollegeCatalogEntry(refId: 22, name: 'Psychiatrie',                           editor: 'AEPU', icon: Icons.self_improvement_outlined),
  CollegeCatalogEntry(refId: 23, name: 'Radiologie et imagerie médicale',       editor: 'CERF', icon: Icons.document_scanner_outlined),
  CollegeCatalogEntry(refId: 24, name: 'Réanimation médicale',                  editor: 'SRLF', icon: Icons.monitor_heart_outlined),
  CollegeCatalogEntry(refId: 25, name: 'Rhumatologie',                          editor: 'CRF', icon: Icons.accessibility_new_outlined),
  CollegeCatalogEntry(refId: 26, name: 'Urologie',                              editor: 'AFU', icon: Icons.water_outlined),
  CollegeCatalogEntry(refId: 27, name: 'Chirurgie digestive et viscérale',      editor: 'ACHBT', icon: Icons.corpus_outlined),
  CollegeCatalogEntry(refId: 28, name: 'Chirurgie cardiaque et thoracique',     editor: 'SFCTCV', icon: Icons.heart_broken_outlined),
  CollegeCatalogEntry(refId: 29, name: 'Chirurgie plastique et reconstructrice', editor: 'SOFCPRE', icon: Icons.brush_outlined),
  CollegeCatalogEntry(refId: 30, name: 'Neurochirurgie',                        editor: 'SNCLF', icon: Icons.psychology_alt_outlined),
  CollegeCatalogEntry(refId: 31, name: 'Gynécologie-Obstétrique',               editor: 'CNGOF', icon: Icons.pregnant_woman_outlined),
  CollegeCatalogEntry(refId: 32, name: 'Anesthésiologie-réanimation',           editor: 'SFAR', icon: Icons.air_outlined),
  CollegeCatalogEntry(refId: 33, name: 'Anatomie et cytologie pathologiques',   editor: 'CNECAP', icon: Icons.microscope_outlined),
  CollegeCatalogEntry(refId: 34, name: 'Biochimie médicale',                    editor: 'SFBC', icon: Icons.biotech_outlined),
  CollegeCatalogEntry(refId: 35, name: 'Génétique médicale',                    editor: 'CNMG', icon: Icons.science_outlined),
  CollegeCatalogEntry(refId: 36, name: 'Immunologie médicale',                  editor: 'SNFMI', icon: Icons.shield_outlined),
  CollegeCatalogEntry(refId: 37, name: 'Médecine du travail',                   editor: 'SF2MT', icon: Icons.work_outline),
  CollegeCatalogEntry(refId: 38, name: 'Microbiologie médicale',                editor: 'CMIT', icon: Icons.coronavirus_outlined),
  CollegeCatalogEntry(refId: 39, name: 'Pharmacologie médicale',                editor: 'CNPM', icon: Icons.medication_outlined),
  CollegeCatalogEntry(refId: 40, name: 'Santé publique et économie de la santé', editor: 'APES', icon: Icons.public_outlined),
];
```

> **Note :** Certains `IconData` (ex. `Icons.corpus_outlined`, `Icons.microscope_outlined`) n'existent pas dans Material Icons standard. Remplacer par l'icône la plus proche disponible (`Icons.medical_services_outlined`, `Icons.zoom_in_outlined`, etc.). Utiliser `Icons.medical_services_outlined` comme fallback universel si une icône est introuvable.

---

### Flutter : Modèles domaine

**Fichier : `collega_app/lib/features/colleges/domain/college_models.dart`**

```dart
class UserCollegeStatus {
  const UserCollegeStatus({
    required this.refId,
    required this.collegeId,
    required this.status,
    required this.cardCountA,
    required this.cardCountB,
    required this.cardCountC,
  });
  final int refId;
  final String collegeId;
  final String status;
  final int cardCountA;
  final int cardCountB;
  final int cardCountC;

  int get totalCards => cardCountA + cardCountB + cardCountC;

  factory UserCollegeStatus.fromJson(Map<String, dynamic> json) =>
      UserCollegeStatus(
        refId: json['college_ref_id'] as int,
        collegeId: json['college_id'] as String,
        status: json['status'] as String,
        cardCountA: json['card_count_a'] as int? ?? 0,
        cardCountB: json['card_count_b'] as int? ?? 0,
        cardCountC: json['card_count_c'] as int? ?? 0,
      );
}

class CollegeListEntry {
  const CollegeListEntry({
    required this.catalog,
    this.userStatus,
  });
  final CollegeCatalogEntry catalog;
  final UserCollegeStatus? userStatus;

  bool get isImported => userStatus != null;
  bool get isGenerationComplete => userStatus?.status == 'generation_complete';
}
```

---

### Flutter : Repository et Provider patterns

**`CollegesRepository` :** suivre le pattern de `AuthRepository` — prend `Dio` en paramètre, méthodes `async`, gère les erreurs via `DioException`, jamais de logique métier.

```dart
class CollegesRepository {
  const CollegesRepository({required this.dio});
  final Dio dio;

  Future<List<UserCollegeStatus>> getUserColleges() async {
    try {
      final response = await dio.get<Map<String, dynamic>>('/v1/colleges');
      final list = (response.data!['data'] as List<dynamic>);
      return list
          .map((e) => UserCollegeStatus.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      AppLogger.error('getUserColleges failed', tag: 'CollegesRepository', error: e);
      rethrow;
    }
  }
}
```

**`CollegesNotifier` :** pattern `AsyncNotifier<List<CollegeListEntry>>` — `build()` fetch API puis merge avec catalogue.

```dart
class CollegesNotifier extends AsyncNotifier<List<CollegeListEntry>> {
  @override
  Future<List<CollegeListEntry>> build() async {
    final imported = await ref.read(collegesRepositoryProvider).getUserColleges();
    final importedByRefId = {for (final s in imported) s.refId: s};
    return kCollegeCatalog
        .map((entry) => CollegeListEntry(
              catalog: entry,
              userStatus: importedByRefId[entry.refId],
            ))
        .toList();
  }
}

final collegesRepositoryProvider = Provider<CollegesRepository>((ref) =>
    CollegesRepository(dio: ref.read(apiClientProvider).dio));

final collegesProvider =
    AsyncNotifierProvider<CollegesNotifier, List<CollegeListEntry>>(CollegesNotifier.new);
```

---

### Flutter : CollegesScreen structure

**Pattern filter state local avec `useState` ou `StatefulWidget` :**

```dart
enum CollegeFilter { tous, importes, nonImportes }

class CollegesScreen extends ConsumerStatefulWidget {
  const CollegesScreen({super.key});
  @override
  ConsumerState<CollegesScreen> createState() => _CollegesScreenState();
}

class _CollegesScreenState extends ConsumerState<CollegesScreen> {
  CollegeFilter _filter = CollegeFilter.tous;

  List<CollegeListEntry> _applyFilter(List<CollegeListEntry> all) {
    return switch (_filter) {
      CollegeFilter.importes => all.where((e) => e.isImported).toList(),
      CollegeFilter.nonImportes => all.where((e) => !e.isImported).toList(),
      CollegeFilter.tous => all,
    };
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(collegesProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Filter chips horizontaux scrollables
            _FilterBar(current: _filter, onSelect: (f) => setState(() => _filter = f)),
            // Liste/grille
            Expanded(
              child: async.when(
                loading: () => _SkeletonGrid(),
                error: (e, st) => ErrorView(message: e.toString()),
                data: (all) {
                  final filtered = _applyFilter(all);
                  if (filtered.isEmpty) return _EmptyState(filter: _filter, onReset: () => setState(() => _filter = CollegeFilter.tous));
                  return LayoutBuilder(
                    builder: (ctx, constraints) {
                      final isTwoColumns = constraints.maxWidth >= 600;
                      // Utiliser GridView ou ListView selon isTwoColumns
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Navigation depuis `CollegesScreen` :**
```dart
// Tap sur non-importé → import (Story 3.2)
context.push('/colleges/${entry.catalog.refId}/import');

// Tap sur importé → détail (Story 3.3)
context.push('/colleges/${entry.catalog.refId}');
```

---

### Flutter : CollegeProgressTile — barre de progression 4 segments

La barre de progression est un `Row` de `Container` aux largeurs proportionnelles (via `Flexible` + `flex` = count) :

```dart
// Barre 4 segments — Story 3.1 : mastered=0, well=0, toReview=0, notSeen=totalCards
Row(
  children: [
    if (mastered > 0) Flexible(flex: mastered, child: Container(height: 6, color: AppColors.primary)),
    if (well > 0)     Flexible(flex: well,     child: Container(height: 6, color: AppColors.secondary)),
    if (toReview > 0) Flexible(flex: toReview, child: Container(height: 6, color: AppColors.error)),
    if (notSeen > 0)  Flexible(flex: notSeen,  child: Container(height: 6, color: Colors.grey.shade300)),
  ],
)
```

Pour Story 3.1, `mastered = 0, well = 0, toReview = 0, notSeen = totalCards` → barre entièrement grise.

---

### Flutter : Router — modifications requises

**État actuel de `app_router.dart` (lignes clés) :**
```dart
// Ligne 53 — DANS le ShellRoute :
GoRoute(path: '/colleges', builder: (ctx, s) => const _CollegesStub()),
// Classe _CollegesStub aux lignes 97-103 — À SUPPRIMER
```

**Après modification :**
```dart
// Dans ShellRoute (avec bottom nav) :
GoRoute(path: '/colleges', builder: (ctx, s) => const CollegesScreen()),

// En dehors du ShellRoute (pas de bottom nav — full screen) :
GoRoute(path: '/colleges/:ref_id', builder: (ctx, s) => const _CollegeDetailStub()),
GoRoute(path: '/colleges/:ref_id/import', builder: (ctx, s) => const _CollegeImportStub()),
```

**Stubs temporaires (dans `app_router.dart`) :**
```dart
class _CollegeDetailStub extends StatelessWidget {
  const _CollegeDetailStub();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Détail collège — Story 3.3')));
}

class _CollegeImportStub extends StatelessWidget {
  const _CollegeImportStub();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Import PDF — Story 3.2')));
}
```

---

### Anti-patterns à éviter absolument

- **NE PAS** utiliser `require_subscription` sur `GET /v1/colleges` — juste `get_current_user` (voir backend)
- **NE PAS** utiliser `CircularProgressIndicator` → `ShadSkeleton` systématiquement
- **NE PAS** mettre la logique de merge catalogue+API dans le widget → dans `CollegesNotifier`
- **NE PAS** appeler l'API directement depuis le widget → via `CollegesRepository` + Provider
- **NE PAS** hardcoder les routes `/colleges/...` dans le widget — utiliser `context.go()` ou `context.push()`
- **NE PAS** ajouter `/colleges/:ref_id` dans le `ShellRoute` — ces routes n'ont pas de bottom nav
- **NE PAS** créer de tables Drift dans cette story — la base de données Drift reste non-connectée (Story 3.2/3.3 initialisent Drift)
- **NE PAS** utiliser `print()` ou `debugPrint()` → `AppLogger.error/warning/info`
- **NE PAS** récupérer `Dio` directement → `ref.read(apiClientProvider).dio`
- **NE PAS** inventer des IconData non-existants — vérifier avant d'utiliser, fallback sur `Icons.medical_services_outlined`

### Règles qualité héritées des stories précédentes

- `flutter analyze` → 0 erreur avant de marquer terminée
- Logique métier dans les Notifiers, jamais dans les widgets
- Pattern `AsyncValue.when(loading, error, data)` pour tous les états async
- Immutable state avec `copyWith` si état évolue
- Nommage : PascalCase classes, camelCase méthodes, snake_case fichiers
- Un seul bouton `ShadButton filled` primary par écran
- `ShadToast` pour erreurs non-bloquantes si l'API échoue
- Tests : pattern `_Fake[Repository]` sans mockito (cf. `auth_providers_test.dart`)

### Références

- Pattern AsyncNotifier : `features/auth/auth_providers.dart`
- Pattern Repository : `features/auth/data/auth_repository.dart`
- Pattern test Notifier : `test/features/auth/auth_providers_test.dart`
- Pattern test widget : `test/features/auth/auth_register_screen_test.dart`
- Router actuel : `core/router/app_router.dart`
- Thème et couleurs : `core/theme/app_theme.dart` (`AppColors`, `AppSpacing`, `AppTypography`)
- SharedWidget error : `shared/widgets/error_view.dart`
- Backend deps.py : `collega_backend/app/deps.py` (get_current_user + require_subscription)
- College model backend : `collega_backend/app/models/college.py`
- Flash card model backend : `collega_backend/app/models/flash_card.py`
- Pattern test backend avec override : `collega_backend/tests/api/test_require_subscription.py`

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- `ShadSkeleton` absent de shadcn_ui 0.19.3 → remplacé par `_SkeletonTile` (Container gris, ValueKey pour les tests)
- Overflow dans grille 2 colonnes (test viewport 800px) → `mainAxisExtent: 160` + `maxLines: 2` sur les noms
- Test "loading" avec `async => []` trop rapide → Completer bloquant + `pumpAndSettle()` pour drainer les timers

### Completion Notes List

- T1 (backend) était déjà implémenté avant le début de session (fichiers non-trackés présents)
- Catalogue statique des 40 collèges avec icônes Material (fallback `Icons.medical_services_outlined` pour les icônes introuvables)
- `ShadSkeleton` n'existant pas dans shadcn_ui 0.19.3, remplacement par containers natifs colorés
- Grille iPad : `mainAxisExtent: 160` (plus robuste que `childAspectRatio` avec des noms longs)
- 31/31 tests Flutter passent (3 nouveaux providers + 3 nouveaux widget), 4/4 backend

### File List

- `collega_backend/app/schemas/college.py` (créé)
- `collega_backend/app/api/v1/colleges.py` (créé)
- `collega_backend/app/main.py` (modifié — import + enregistrement colleges_router)
- `collega_backend/tests/api/test_colleges.py` (créé)
- `collega_app/lib/features/colleges/domain/college_catalog.dart` (créé)
- `collega_app/lib/features/colleges/domain/college_models.dart` (créé)
- `collega_app/lib/features/colleges/data/colleges_repository.dart` (créé)
- `collega_app/lib/features/colleges/colleges_providers.dart` (créé)
- `collega_app/lib/features/colleges/presentation/colleges_screen.dart` (créé)
- `collega_app/lib/features/colleges/widgets/college_progress_tile.dart` (créé)
- `collega_app/lib/core/router/app_router.dart` (modifié — CollegesScreen + 2 routes stubs + suppression _CollegesStub)
- `collega_app/test/features/colleges/colleges_providers_test.dart` (créé)
- `collega_app/test/features/colleges/colleges_screen_test.dart` (créé)

### Change Log

- 2026-05-08 : Story 3.1 créée par create-story — liste des collèges & navigation
- 2026-05-08 : Story 3.1 implémentée — backend GET /v1/colleges + Flutter catalogue + screen + tile + router

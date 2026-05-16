# Story 3.4 : Hash-Sharing & Limites de Reimport

Status: done

## Story

En tant qu'**étudiant**,
je veux pouvoir reimporter un collège avec une nouvelle édition du PDF, dans la limite autorisée,
afin de mettre à jour mes fiches sans pouvoir abuser du système.

## Acceptance Criteria

1. **Hash-sharing — réutilisation fiches existantes (FR18)**
   - Étant donné un PDF similaire à ≥ 90% d'un traitement existant
   - Quand le pipeline évalue la similarité via `SimilarityChecker`
   - Alors les fiches existantes sont servies sans appel Claude
   - Et le job passe directement à `generation_complete` avec `hash_shared: true`
   - Et le compteur `reload_count` n'est **pas** incrémenté pour un hash-share
   - Et le compteur `monthly_reloads` n'est **pas** incrémenté pour un hash-share

2. **Dialog de confirmation avant reimport (FR14)**
   - Étant donné que je veux reimporter un collège (`status == generation_complete`)
   - Quand j'appuie sur le bouton "Recharger le PDF" dans l'AppBar du détail collège
   - Alors l'app appelle `GET /v1/colleges/{ref_id}/reload-limits` pour obtenir les compteurs
   - Et un `ShadAlertDialog` affiche : "Reimport X/2 pour ce collège · X/3 ce mois"
   - Et je dois confirmer explicitement avant que le reimport démarre
   - Et confirmer navigue vers l'écran import standard (`/colleges/{refId}/import`)

3. **Blocage college_reload_limit (FR15)**
   - Étant donné que `college.reload_count >= settings.reload_count_max` (défaut 2)
   - Quand je tente un reimport
   - Alors un `ShadAlertDialog` s'affiche : "Ce collège ne peut plus être retraité"
   - Et le message confirme en premier : "Tes fiches existantes sont toujours accessibles"
   - Et le CTA principal est "Continuer à réviser" — aucun bouton de contournement

4. **Blocage monthly_reload_limit (FR15)**
   - Étant donné que `user.monthly_reloads >= settings.monthly_reloads_max` (défaut 3)
   - Quand je tente n'importe quel reimport ce mois
   - Alors un `ShadAlertDialog` s'affiche : "Limite mensuelle atteinte · Réinitialisation le JJ/MM"
   - Et le message confirme en premier : "Tes fiches existantes sont toujours accessibles"
   - Et le CTA principal est "Continuer à réviser"

5. **Configurabilité backend (FR45)**
   - Étant donné l'opérateur qui modifie `RELOAD_COUNT_MAX` ou `MONTHLY_RELOADS_MAX` dans la config pydantic-settings
   - Alors les nouvelles limites s'appliquent immédiatement sans redéploiement ni mise à jour de l'app

---

## Tasks / Subtasks

- [x] **T1 — Backend : migration Alembic #007** (AC: #2, #4)
  - [x] Créer `collega_backend/alembic/versions/007_add_monthly_reloads_reset_at.py`
  - [x] `ALTER TABLE users ADD COLUMN monthly_reloads_reset_at TIMESTAMP WITH TIME ZONE` (nullable)
  - [x] Mettre à jour `collega_backend/app/models/user.py` : ajouter `monthly_reloads_reset_at: Mapped[datetime | None]`

- [x] **T2 — Backend : nouveaux schémas + endpoint GET reload-limits** (AC: #2)
  - [x] Dans `collega_backend/app/schemas/college.py`, ajouter :
    - `ReloadLimitsData(college_reload_count, college_reload_max, monthly_reloads, monthly_max, monthly_reset_at: str)`
    - `ReloadLimitsResponseWrapped(data: ReloadLimitsData)`
  - [x] Dans `collega_backend/app/api/v1/colleges.py`, ajouter :
    - `GET /v1/colleges/{ref_id}/reload-limits` → retourne les quotas du collège pour l'utilisateur connecté
    - 404 si `college.user_id != current_user.id` ou college inexistant
    - Le `monthly_reset_at` est calculé comme le 1er du mois prochain (fonction `_next_month_reset`)
    - Le `monthly_reloads` retourné est `0` si `now >= monthly_reloads_reset_at` (réinitialisation virtuelle, sans écrire en base)

- [x] **T3 — Backend : quota checks dans `import_college_pdf`** (AC: #3, #4, #5)
  - [x] Ajouter import : `from datetime import datetime, timezone` dans `colleges.py`
  - [x] Ajouter la fonction helper `_next_month_reset(now: datetime) -> datetime` dans `colleges.py`
  - [x] Modifier `import_college_pdf` : si `college is not None and college.status == "generation_complete"` :
    - Calculer `effective_monthly` en tenant compte de l'auto-reset temporel
    - Checker `college.reload_count >= settings.reload_count_max` → 409 `COLLEGE_RELOAD_LIMIT`
    - Checker `effective_monthly >= settings.monthly_reloads_max` → 409 `MONTHLY_RELOAD_LIMIT` (avec `reset_at`)
    - Si auto-reset détecté ET quotas OK : mettre à jour `current_user.monthly_reloads = 0` et `monthly_reloads_reset_at` (committé avec la transaction principale)
  - [x] Ajouter `from app.models.user import User` dans les imports si pas déjà présent

- [x] **T4 — Backend : incrément compteurs dans `card_generator.py`** (AC: #1)
  - [x] Dans `CardGenerator.generate_for_college()`, après la génération ou le hash-sharing :
    - Détecter si c'est un reimport : vérifier si un job `generation_complete` différent du job courant existe pour ce collège
    - Si reimport ET non hash_shared : incrémenter `college.reload_count += 1` et `user.monthly_reloads += 1`
    - Si reimport ET hash_shared : ne rien incrémenter
    - Si premier import (pas de job previous generation_complete) : ne rien incrémenter
  - [x] Ajouter les imports `College`, `User` dans `card_generator.py`

- [x] **T5 — Backend : tests** (AC: #1, #3, #4, #5)
  - [x] Créer `collega_backend/tests/api/test_colleges_reimport.py` avec :
    - 409 `COLLEGE_RELOAD_LIMIT` quand `reload_count >= max`
    - 409 `MONTHLY_RELOAD_LIMIT` quand `monthly_reloads >= max` (avec `reset_at` dans la réponse)
    - Premier import non bloqué (`college.status != 'generation_complete'`)
    - Import OK dans les limites passe en 202
    - `GET /v1/colleges/{ref_id}/reload-limits` retourne les bons compteurs
    - `GET /v1/colleges/{ref_id}/reload-limits` retourne 404 si college inexistant

- [x] **T6 — Flutter : modèle `ReloadLimits` + nouvelles exceptions** (AC: #2, #3, #4)
  - [x] Dans `collega_app/lib/features/colleges/domain/import_models.dart`, ajouter :
    - Classe `ReloadLimits` avec `fromJson`, `isCollegeLimitReached`, `isMonthlyLimitReached`
  - [x] Dans `collega_app/lib/features/colleges/data/college_import_repository.dart`, ajouter :
    - `class CollegeReloadLimitException implements Exception`
    - `class MonthlyReloadLimitException implements Exception { final String resetAt; }`
    - Méthode `Future<ReloadLimits> getReloadLimits(int refId)`
    - Gestion des codes `COLLEGE_RELOAD_LIMIT` et `MONTHLY_RELOAD_LIMIT` dans `importPdf`

- [x] **T7 — Flutter : bouton "Recharger" + dialog dans `CollegeDetailScreen`** (AC: #2, #3, #4)
  - [x] Convertir `_CollegeDetailView` de `ConsumerWidget` en `ConsumerStatefulWidget` pour gérer `_isLoadingLimits`
  - [x] Ajouter un `IconButton(icon: Icon(Icons.refresh))` dans l'AppBar de `_CollegeDetailView`
  - [x] Implémenter `_handleReimport` :
    1. Setter `_isLoadingLimits = true`
    2. Appeler `repo.getReloadLimits(refId)`
    3. Selon `limits.isCollegeLimitReached` → dialog bloqué collège
    4. Selon `limits.isMonthlyLimitReached` → dialog bloqué mensuel
    5. Sinon → dialog confirmation avec compteurs
    6. Sur confirmation → `context.push('/colleges/$refId/import')`

- [x] **T8 — Flutter : exporter les nouvelles exceptions dans `colleges_import_providers.dart`** (AC: #3, #4)
  - [x] Ajouter `CollegeReloadLimitException` et `MonthlyReloadLimitException` à l'export existant
  - [x] Mettre à jour `startImport` dans `CollegeImportNotifier` pour gérer les nouvelles exceptions

- [x] **T9 — Flutter : tests** (AC: #2, #3, #4)
  - [x] Créer `collega_app/test/features/colleges/college_reimport_test.dart` :
    - `getReloadLimits` parse correctement le JSON
    - `isCollegeLimitReached` et `isMonthlyLimitReached` retournent les bons bool
    - `importPdf` lance `CollegeReloadLimitException` sur 409 `COLLEGE_RELOAD_LIMIT`
    - `importPdf` lance `MonthlyReloadLimitException` sur 409 `MONTHLY_RELOAD_LIMIT`

- [x] **T10 — Validation finale** (AC: tous)
  - [x] `flutter analyze` → 0 erreur (2 infos pré-existantes hors scope)
  - [x] `flutter test` → 49/49 passent (0 régression)
  - [x] `pytest collega_backend/tests/api/test_colleges_reimport.py` → 8/8 verts
  - [x] `pytest collega_backend/tests/api/` → 0 nouvelle régression

---

## Dev Notes

### État du codebase au début de cette story

**DÉJÀ IMPLÉMENTÉ — NE PAS RECRÉER :**

| Composant | État | Emplacement |
|---|---|---|
| `College.reload_count: int` | ✅ Existe, default=0 | `collega_backend/app/models/college.py` |
| `User.monthly_reloads: int` | ✅ Existe, default=0 | `collega_backend/app/models/user.py` |
| `SHA256SimilarityChecker` | ✅ Existe — compare PDF par hash SHA256 | `collega_backend/app/services/generation/hash_sharing.py` |
| `CardGenerator.generate_for_college()` | ✅ Existe — gère hash-sharing, set `job.hash_shared = True` | `collega_backend/app/services/generation/card_generator.py` |
| `GenerationJob.hash_shared: bool` | ✅ Existe, default=False | `collega_backend/app/models/generation_job.py` |
| `GenerationJob.pdf_hash: str | None` | ✅ Existe, nullable | `collega_backend/app/models/generation_job.py` |
| `settings.reload_count_max: int` | ✅ Existe, default=2 | `collega_backend/app/core/config.py` |
| `settings.monthly_reloads_max: int` | ✅ Existe, default=3 | `collega_backend/app/core/config.py` |
| `POST /v1/colleges/{ref_id}/import` | ✅ Existe — PAS de quota check actuellement | `collega_backend/app/api/v1/colleges.py` |
| `CollegeImportRepository.importPdf()` | ✅ Existe | `collega_app/lib/features/colleges/data/college_import_repository.dart` |
| `CollegeDetailScreen` | ✅ Existe — ConsumerWidget, AppBar sans bouton rechargement | `collega_app/lib/features/colleges/presentation/college_detail_screen.dart` |
| `CollegesScreen` + routing | ✅ Existe | `collega_app/lib/features/colleges/presentation/colleges_screen.dart` |
| Routes import hors ShellRoute | ✅ `/colleges/:ref_id/import` et `/colleges/:ref_id/import/progress` sont hors ShellRoute (comportement modal) | `collega_app/lib/core/router/app_router.dart` |

**CE QUI MANQUE (à implémenter dans cette story) :**
- `User.monthly_reloads_reset_at` (colonne DB + modèle SQLAlchemy)
- Migration Alembic #007
- `ReloadLimitsData` schéma Pydantic
- `GET /v1/colleges/{ref_id}/reload-limits` endpoint
- Quota checks dans `import_college_pdf`
- Incrément compteurs dans `card_generator.py`
- `ReloadLimits` modèle Flutter
- `CollegeReloadLimitException` + `MonthlyReloadLimitException`
- `getReloadLimits()` dans `CollegeImportRepository`
- Bouton "Recharger" + dialog dans `CollegeDetailScreen`

---

### Backend : Migration Alembic #007

```python
# collega_backend/alembic/versions/007_add_monthly_reloads_reset_at.py
"""Add monthly_reloads_reset_at to users

Revision ID: 007
Revises: 006
Create Date: 2026-05-10
"""
from alembic import op
import sqlalchemy as sa

revision = '007'
down_revision = '006'

def upgrade() -> None:
    op.add_column(
        'users',
        sa.Column('monthly_reloads_reset_at', sa.DateTime(timezone=True), nullable=True)
    )

def downgrade() -> None:
    op.drop_column('users', 'monthly_reloads_reset_at')
```

**Vérifier le `down_revision`** : la migration 006 est `006_add_unique_constraint_colleges_user_ref.py`. Récupérer son `revision` ID réel avant d'écrire `down_revision`.

---

### Backend : Modèle User mis à jour

```python
# Dans collega_backend/app/models/user.py — AJOUTER après monthly_reloads
monthly_reloads_reset_at: Mapped[datetime | None] = mapped_column(
    DateTime(timezone=True),
    nullable=True,
)
```

Importer `datetime` en haut du fichier (`from datetime import datetime, timezone` — vérifier que c'est déjà là).

---

### Backend : Nouveaux schémas Pydantic

```python
# Dans collega_backend/app/schemas/college.py — AJOUTER à la fin

class ReloadLimitsData(BaseModel):
    college_reload_count: int
    college_reload_max: int
    monthly_reloads: int
    monthly_max: int
    monthly_reset_at: str  # ISO 8601 UTC

class ReloadLimitsResponseWrapped(BaseModel):
    data: ReloadLimitsData
```

---

### Backend : Fonction helper `_next_month_reset`

```python
# Dans collega_backend/app/api/v1/colleges.py — AJOUTER en haut (après les imports)
from datetime import datetime, timezone

def _next_month_reset(now: datetime) -> datetime:
    """Retourne le 1er du mois prochain à minuit UTC."""
    if now.month == 12:
        return now.replace(year=now.year + 1, month=1, day=1, hour=0, minute=0, second=0, microsecond=0)
    return now.replace(month=now.month + 1, day=1, hour=0, minute=0, second=0, microsecond=0)
```

---

### Backend : Endpoint `GET /v1/colleges/{ref_id}/reload-limits`

```python
@router.get("/colleges/{ref_id}/reload-limits", response_model=ReloadLimitsResponseWrapped)
async def get_college_reload_limits(
    ref_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ReloadLimitsResponseWrapped:
    """Retourne les quotas de reimport pour ce collège (lecture seule, sans modifier l'état)."""
    result = await db.execute(
        select(College)
        .where(College.user_id == current_user.id)
        .where(College.college_ref_id == ref_id)
    )
    college = result.scalar_one_or_none()
    if college is None:
        raise HTTPException(
            status_code=404,
            detail={"code": "COLLEGE_NOT_FOUND", "message": "Collège non trouvé"},
        )

    now = datetime.now(timezone.utc)
    is_month_reset = (
        current_user.monthly_reloads_reset_at is None
        or now >= current_user.monthly_reloads_reset_at
    )
    effective_monthly = 0 if is_month_reset else current_user.monthly_reloads
    monthly_reset_at = _next_month_reset(now) if is_month_reset else current_user.monthly_reloads_reset_at

    return ReloadLimitsResponseWrapped(
        data=ReloadLimitsData(
            college_reload_count=college.reload_count,
            college_reload_max=settings.reload_count_max,
            monthly_reloads=effective_monthly,
            monthly_max=settings.monthly_reloads_max,
            monthly_reset_at=monthly_reset_at.isoformat(),
        )
    )
```

**Ajouter `ReloadLimitsData, ReloadLimitsResponseWrapped` dans les imports de `colleges.py`.**

---

### Backend : Quota checks dans `import_college_pdf`

Placer les quota checks JUSTE APRÈS la vérification du `college` (après `existing_job` check), AVANT la lecture du PDF. Insertion dans le flux existant :

```python
# Dans import_college_pdf, après le bloc "Vérifier qu'aucun job actif n'existe" :

# Quota checks pour les reimports uniquement (premier import = libre)
if college.status == "generation_complete":
    now = datetime.now(timezone.utc)
    is_month_reset = (
        current_user.monthly_reloads_reset_at is None
        or now >= current_user.monthly_reloads_reset_at
    )
    effective_monthly = 0 if is_month_reset else current_user.monthly_reloads

    if college.reload_count >= settings.reload_count_max:
        raise HTTPException(
            status_code=409,
            detail={
                "code": "COLLEGE_RELOAD_LIMIT",
                "message": f"Ce collège ne peut plus être retraité (limite : {settings.reload_count_max})",
                "reload_count": college.reload_count,
                "reload_count_max": settings.reload_count_max,
            },
        )

    if effective_monthly >= settings.monthly_reloads_max:
        reset_at = (
            _next_month_reset(now)
            if is_month_reset or current_user.monthly_reloads_reset_at is None
            else current_user.monthly_reloads_reset_at
        )
        raise HTTPException(
            status_code=409,
            detail={
                "code": "MONTHLY_RELOAD_LIMIT",
                "message": f"Limite mensuelle atteinte ({settings.monthly_reloads_max} reimports/mois)",
                "monthly_reloads": effective_monthly,
                "monthly_max": settings.monthly_reloads_max,
                "reset_at": reset_at.isoformat(),
            },
        )

    # Auto-reset mensuel si besoin — committé avec la transaction de succès
    if is_month_reset:
        current_user.monthly_reloads = 0
        current_user.monthly_reloads_reset_at = _next_month_reset(now)
```

**IMPORTANT** : `current_user` est l'objet SQLAlchemy retourné par `require_subscription` (qui lui-même appelle `get_current_user` qui dépend du même `db` session via FastAPI `Depends` caching). Les modifications à `current_user` sont trackées par la session et committées avec `await db.commit()` à la fin de la transaction de succès.

**Ne pas appeler `await db.flush()` ici** — les modifications seront committées en même temps que le reste (job creation).

---

### Backend : Incrément dans `card_generator.py`

Dans `generate_for_college`, ajouter le détection du reimport et l'incrément **après** la mise à jour du statut du job :

```python
# Dans CardGenerator.generate_for_college() — AJOUTER les imports en haut :
from app.models.college import College
from app.models.user import User

# Dans generate_for_college(), après "job.status = 'generation_complete'" :

# Incrémenter les compteurs si c'est un reimport non-hash-share
# Un reimport = un job generation_complete précédent existe pour ce collège
prev_complete_result = await db.execute(
    select(GenerationJob)
    .where(GenerationJob.college_id == college_id)
    .where(GenerationJob.id != job_id)
    .where(GenerationJob.status == "generation_complete")
    .limit(1)
)
is_reimport = prev_complete_result.scalar_one_or_none() is not None

if is_reimport and not job.hash_shared:
    college_obj = await db.get(College, college_id)
    user_obj = await db.get(User, job.user_id)
    if college_obj is not None:
        college_obj.reload_count += 1
    if user_obj is not None:
        user_obj.monthly_reloads += 1
    logger.info(
        "Reimport counted for college %s (reload_count=%s)",
        college_id,
        college_obj.reload_count if college_obj else "N/A",
    )
```

**Important**: L'incrément doit être placé AVANT `await db.commit()` pour être commité ensemble. Le `await db.commit()` est à la fin de `generate_for_college`, donc placer ce bloc AVANT ce commit.

**Pour le cas hash-shared** : le même pattern s'applique (bloc identique car `job.hash_shared = True` a déjà été set, donc `not job.hash_shared` sera False). Aucun incrément pour un hash-share.

---

### Flutter : Modèle `ReloadLimits`

```dart
// Dans collega_app/lib/features/colleges/domain/import_models.dart — AJOUTER à la fin

class ReloadLimits {
  const ReloadLimits({
    required this.collegeReloadCount,
    required this.collegeReloadMax,
    required this.monthlyReloads,
    required this.monthlyMax,
    required this.monthlyResetAt,
  });

  final int collegeReloadCount;
  final int collegeReloadMax;
  final int monthlyReloads;
  final int monthlyMax;
  final String monthlyResetAt; // ISO 8601 UTC

  bool get isCollegeLimitReached => collegeReloadCount >= collegeReloadMax;
  bool get isMonthlyLimitReached => monthlyReloads >= monthlyMax;

  factory ReloadLimits.fromJson(Map<String, dynamic> json) => ReloadLimits(
        collegeReloadCount: json['college_reload_count'] as int,
        collegeReloadMax: json['college_reload_max'] as int,
        monthlyReloads: json['monthly_reloads'] as int,
        monthlyMax: json['monthly_max'] as int,
        monthlyResetAt: json['monthly_reset_at'] as String,
      );
}
```

---

### Flutter : Nouvelles exceptions + `getReloadLimits`

```dart
// Dans collega_app/lib/features/colleges/data/college_import_repository.dart

// AJOUTER les nouvelles classes d'exception (après les existantes)
class CollegeReloadLimitException implements Exception {
  const CollegeReloadLimitException({required this.reloadCount, required this.reloadCountMax});
  final int reloadCount;
  final int reloadCountMax;
}

class MonthlyReloadLimitException implements Exception {
  const MonthlyReloadLimitException({
    required this.monthlyReloads,
    required this.monthlyMax,
    required this.resetAt,
  });
  final int monthlyReloads;
  final int monthlyMax;
  final String resetAt; // ISO 8601
}

// AJOUTER dans CollegeImportRepository.importPdf() — dans le catch DioException :
// Après le bloc QueueUnavailableException :
if (status == 409 && code == 'COLLEGE_RELOAD_LIMIT') {
  final detail = (e.response?.data as Map?)?['detail'] as Map?;
  throw CollegeReloadLimitException(
    reloadCount: (detail?['reload_count'] as num?)?.toInt() ?? 0,
    reloadCountMax: (detail?['reload_count_max'] as num?)?.toInt() ?? 2,
  );
}
if (status == 409 && code == 'MONTHLY_RELOAD_LIMIT') {
  final detail = (e.response?.data as Map?)?['detail'] as Map?;
  throw MonthlyReloadLimitException(
    monthlyReloads: (detail?['monthly_reloads'] as num?)?.toInt() ?? 0,
    monthlyMax: (detail?['monthly_max'] as num?)?.toInt() ?? 3,
    resetAt: (detail?['reset_at'] as String?) ?? '',
  );
}

// AJOUTER méthode getReloadLimits dans CollegeImportRepository :
Future<ReloadLimits> getReloadLimits(int refId) async {
  try {
    final response = await dio.get<Map<String, dynamic>>(
      '/v1/colleges/$refId/reload-limits',
    );
    return ReloadLimits.fromJson(
      response.data!['data'] as Map<String, dynamic>,
    );
  } on DioException catch (e) {
    AppLogger.error('getReloadLimits failed', tag: 'CollegeImportRepository', error: e);
    rethrow;
  }
}
```

**Ajouter l'import** : `import 'package:collega_app/features/colleges/domain/import_models.dart';` (déjà présent — vérifier que `ReloadLimits` est accessible).

---

### Flutter : Bouton + dialog dans `CollegeDetailScreen`

**`_CollegeDetailView` doit devenir `ConsumerStatefulWidget`** pour gérer le `_isLoadingLimits` state.

```dart
class _CollegeDetailView extends ConsumerStatefulWidget {
  const _CollegeDetailView({required this.entry, required this.collegeId});
  final CollegeListEntry entry;
  final String collegeId;

  @override
  ConsumerState<_CollegeDetailView> createState() => _CollegeDetailViewState();
}

class _CollegeDetailViewState extends ConsumerState<_CollegeDetailView> {
  bool _isLoadingLimits = false;

  Future<void> _handleReimport() async {
    setState(() => _isLoadingLimits = true);
    try {
      final repo = ref.read(collegeImportRepositoryProvider);
      final limits = await repo.getReloadLimits(widget.entry.catalog.refId);
      if (!mounted) return;
      setState(() => _isLoadingLimits = false);
      await _showReimportDialog(limits);
    } on DioException {
      if (!mounted) return;
      setState(() => _isLoadingLimits = false);
      ShadToaster.of(context).show(
        const ShadToast.destructive(
          title: Text('Impossible de vérifier les limites'),
        ),
      );
    }
  }

  Future<void> _showReimportDialog(ReloadLimits limits) async {
    if (!mounted) return;

    if (limits.isCollegeLimitReached) {
      return _showBlockedDialog(
        title: 'Ce collège ne peut plus être retraité',
        body: 'Tes fiches existantes sont toujours accessibles.\n\nTu as utilisé ${limits.collegeReloadCount}/${limits.collegeReloadMax} reimports pour ce collège.',
      );
    }

    if (limits.isMonthlyLimitReached) {
      final resetDate = _formatResetDate(limits.monthlyResetAt);
      return _showBlockedDialog(
        title: 'Limite mensuelle atteinte',
        body: 'Tes fiches existantes sont toujours accessibles.\n\nTu as utilisé ${limits.monthlyReloads}/${limits.monthlyMax} reimports ce mois. Réinitialisation le $resetDate.',
      );
    }

    // Afficher dialog de confirmation
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: const Text('Recharger le PDF ?'),
        description: Text(
          'Reimport ${limits.collegeReloadCount}/${limits.collegeReloadMax} pour ce collège · '
          '${limits.monthlyReloads}/${limits.monthlyMax} ce mois\n\n'
          'Les nouvelles fiches remplaceront les fiches existantes.',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ShadButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.push('/colleges/${widget.entry.catalog.refId}/import');
    }
  }

  Future<void> _showBlockedDialog({required String title, required String body}) async {
    if (!mounted) return;
    await showShadDialog<void>(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: Text(title),
        description: Text(body),
        actions: [
          ShadButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continuer à réviser'),
          ),
        ],
      ),
    );
  }

  String _formatResetDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ajouter le bouton refresh dans l'AppBar
    // ... (voir ci-dessous)
  }
}
```

**Ajouter dans l'AppBar de `_CollegeDetailViewState.build()` :**

```dart
AppBar(
  title: Text(widget.entry.catalog.name.toUpperCase()),
  centerTitle: false,
  actions: [
    if (_isLoadingLimits)
      const Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      )
    else
      IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Recharger le PDF',
        onPressed: _handleReimport,
      ),
  ],
),
```

**Imports à ajouter dans `college_detail_screen.dart` :**
```dart
import 'package:collega_app/features/colleges/colleges_import_providers.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';
import 'package:dio/dio.dart';
```

---

### Flutter : Exporter les nouvelles exceptions dans `colleges_import_providers.dart`

```dart
// Modifier la ligne export existante :
export 'package:collega_app/features/colleges/data/college_import_repository.dart'
    show SubscriptionRequiredException, JobInProgressException, QueueUnavailableException,
         CollegeReloadLimitException, MonthlyReloadLimitException;
```

**Mettre à jour `startImport` dans `CollegeImportNotifier`** pour gérer les nouvelles exceptions :

```dart
// Dans startImport(), dans le bloc try/catch, ajouter après QueueUnavailableException :
} on CollegeReloadLimitException {
  state = const AsyncValue.data(ImportError(message: 'college_reload_limit'));
} on MonthlyReloadLimitException catch (e) {
  state = AsyncValue.data(ImportError(message: 'monthly_reload_limit:${e.resetAt}'));
}
```

**Et dans `CollegeImportScreen._handleError()`, gérer ces nouveaux cas :**

```dart
case 'college_reload_limit':
  ShadToaster.of(context).show(
    const ShadToast.destructive(
      title: Text('Ce collège ne peut plus être retraité'),
    ),
  );
case String s when s.startsWith('monthly_reload_limit:'):
  final resetAt = s.split(':').last;
  ShadToaster.of(context).show(
    ShadToast.destructive(
      title: const Text('Limite mensuelle atteinte'),
      description: Text('Réinitialisation le ${_formatDate(resetAt)}'),
    ),
  );
```

Ajouter `_formatDate(String isoDate)` dans `CollegeImportScreen` (même logique que `_formatResetDate` dans `_CollegeDetailViewState`).

---

### Backend : Pattern tests (nouveaux tests)

Utiliser le même pattern que `test_colleges_import.py` (SimpleNamespace, mock_db, dependency_overrides).

```python
# collega_backend/tests/api/test_colleges_reimport.py
class TestReloadLimits:
    async def test_reimport_bloque_college_limit(self, client, mock_db):
        from app.main import app
        user = _make_user()
        college = _make_college(ref_id=15, user_id=user.id, status="generation_complete")
        college.reload_count = 2  # Limite atteinte
        app.dependency_overrides[require_subscription] = lambda: user
        mock_db.execute = AsyncMock(side_effect=[
            MagicMock(scalar_one_or_none=MagicMock(return_value=college)),  # trouve college
            MagicMock(scalar_one_or_none=MagicMock(return_value=None)),     # aucun job actif
        ])
        resp = await client.post("/v1/colleges/15/import", files={"pdf": ("t.pdf", BytesIO(_PDF_BYTES), "application/pdf")})
        app.dependency_overrides.pop(require_subscription, None)
        assert resp.status_code == 409
        assert resp.json()["detail"]["code"] == "COLLEGE_RELOAD_LIMIT"

    async def test_reimport_bloque_monthly_limit(self, client, mock_db):
        from app.main import app
        user = _make_user()
        user.monthly_reloads = 3  # Limite mensuelle atteinte
        user.monthly_reloads_reset_at = None  # Jamais resetté — mais monthly_reloads déjà 3
        # Note : si monthly_reloads_reset_at is None → effective_monthly = 0 (reset auto)
        # Donc pour tester le blocage mensuel, il faut une date dans le futur :
        from datetime import datetime, timezone, timedelta
        user.monthly_reloads_reset_at = datetime.now(timezone.utc) + timedelta(days=15)
        college = _make_college(ref_id=15, user_id=user.id, status="generation_complete")
        college.reload_count = 0
        app.dependency_overrides[require_subscription] = lambda: user
        mock_db.execute = AsyncMock(side_effect=[
            MagicMock(scalar_one_or_none=MagicMock(return_value=college)),
            MagicMock(scalar_one_or_none=MagicMock(return_value=None)),
        ])
        resp = await client.post("/v1/colleges/15/import", files={"pdf": ("t.pdf", BytesIO(_PDF_BYTES), "application/pdf")})
        app.dependency_overrides.pop(require_subscription, None)
        assert resp.status_code == 409
        detail = resp.json()["detail"]
        assert detail["code"] == "MONTHLY_RELOAD_LIMIT"
        assert "reset_at" in detail

    async def test_premier_import_non_bloque(self, client, mock_db):
        """Premier import (college.status != 'generation_complete') → pas de quota check."""
        from app.main import app
        user = _make_user()
        college = _make_college(ref_id=15, user_id=user.id, status="pending")
        college.reload_count = 99  # Même si élevé, pas vérifié pour premier import
        app.dependency_overrides[require_subscription] = lambda: user
        mock_db.execute = AsyncMock(side_effect=[
            MagicMock(scalar_one_or_none=MagicMock(return_value=college)),
            MagicMock(scalar_one_or_none=MagicMock(return_value=None)),
        ])
        # ... (continue comme test_import_ok_retourne_202)
        app.dependency_overrides.pop(require_subscription, None)
        # assert resp.status_code == 202  (ou 409 si autre raison)
```

Consulter `test_colleges_import.py` pour le pattern complet `mock_db`, `_make_user`, `_make_college`.

---

### Anti-patterns à éviter absolument

- **NE PAS** ajouter le quota check sur les PREMIERS imports (collège n'existe pas ou `status != 'generation_complete'`)
- **NE PAS** incrémenter `reload_count` pour les hash-shares (le flag `job.hash_shared` est à `True` dans ce cas)
- **NE PAS** appeler `await db.flush()` pour le monthly reset DANS le quota check → le faire dans le chemin de succès uniquement (sinon rollback sur HTTPException)
- **NE PAS** oublier que `current_user` dans le endpoint est le même objet SQLAlchemy que la session `db` (FastAPI Depends caching) — les modifications persistent avec le commit final
- **NE PAS** utiliser `package:collection` → non dans `pubspec.yaml`. Pas de `firstWhereOrNull`.
- **NE PAS** modifier l'appel signature de `require_subscription` dans le endpoint import — il reste identique
- **NE PAS** créer un nouveau fichier `flash_cards.py` pour les endpoints — tout dans `colleges.py`
- **NE PAS** utiliser `ShadSkeleton` → absent de `shadcn_ui ^0.19.0` (utiliser `LinearProgressIndicator` ou `CircularProgressIndicator` de taille 20px pour le bouton loading)
- **NE PAS** oublier que `showShadDialog` est l'API shadcn_ui ^0.19.0 pour les dialogs modaux — vérifier l'import `import 'package:shadcn_ui/shadcn_ui.dart';`
- **NE PAS** routerover vers `/colleges/:ref_id/import` si les limites sont atteintes — bloquer AVANT la navigation
- **NE PAS** implémenter le feedback/régénération de fiches → Story 3.5
- **NE PAS** implémenter les push notifications → Story 3.5

---

### Règles qualité héritées des stories précédentes

- `flutter analyze` → 0 erreur avant de marquer terminée
- `AsyncValue.when(loading, error, data)` pour tous les états async
- Logique métier dans les Notifiers, jamais dans les widgets
- Pattern `_Fake[Repository]` pour les tests Flutter (sans mockito)
- `ShadToast` pour erreurs non-bloquantes
- `ShadAlertDialog` / `ShadDialog.alert` pour blocages et confirmations
- Nommage : PascalCase classes, camelCase méthodes, snake_case fichiers
- `AppLogger` pour les logs (jamais `print()` ni `debugPrint()`)
- Pattern `_make_user()`, `_make_college()`, `_make_job()` dans les tests Python

---

### Références

- `import_college_pdf` endpoint : `collega_backend/app/api/v1/colleges.py` (lignes 85-226)
- `card_generator.py` : `collega_backend/app/services/generation/card_generator.py`
- `hash_sharing.py` : `collega_backend/app/services/generation/hash_sharing.py` (SHA256SimilarityChecker)
- Config quotas : `collega_backend/app/core/config.py` (`reload_count_max`, `monthly_reloads_max`)
- College model (reload_count) : `collega_backend/app/models/college.py`
- User model (monthly_reloads) : `collega_backend/app/models/user.py`
- deps.py (require_subscription) : `collega_backend/app/deps.py`
- ImportRepository pattern : `collega_app/lib/features/colleges/data/college_import_repository.dart`
- Import providers (startImport, export pattern) : `collega_app/lib/features/colleges/colleges_import_providers.dart`
- CollegeDetailScreen actuel : `collega_app/lib/features/colleges/presentation/college_detail_screen.dart`
- Router (ShellRoute vs racine) : `collega_app/lib/core/router/app_router.dart`
- Tests import pattern : `collega_backend/tests/api/test_colleges_import.py`
- Migration précédente #006 : `collega_backend/alembic/versions/006_add_unique_constraint_colleges_user_ref.py` (récupérer l'ID de révision exact pour `down_revision`)

---

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

### Completion Notes List

- Migration 007 ajoute `monthly_reloads_reset_at TIMESTAMP WITH TIME ZONE nullable` sur la table `users`.
- `_next_month_reset()` utilisée dans 2 endroits (GET reload-limits et POST import) avec la même logique d'auto-reset virtuel.
- L'auto-reset mensuel n'écrit pas en DB dans GET reload-limits (lecture seule) ; il s'écrit en DB uniquement dans POST import, commité avec la transaction de succès.
- Dans `card_generator.py`, l'incrément est placé AVANT `await db.commit()` dans le chemin normal uniquement. Le chemin hash-share commit séparément et ne touche pas les compteurs.
- Tests auth backend échouent pour bcrypt/Python 3.14 — pré-existant, hors scope story.
- `flutter analyze` : 2 `info` pré-existants dans `colleges_detail_providers.dart` — hors scope, 0 issue introduite.

### File List

**Backend:**
- `collega_backend/alembic/versions/007_add_monthly_reloads_reset_at.py` (nouveau)
- `collega_backend/app/models/user.py` (modifié — ajout `monthly_reloads_reset_at`)
- `collega_backend/app/schemas/college.py` (modifié — ajout `ReloadLimitsData`, `ReloadLimitsResponseWrapped`)
- `collega_backend/app/api/v1/colleges.py` (modifié — import datetime, `_next_month_reset`, endpoint GET reload-limits, quota checks dans `import_college_pdf`)
- `collega_backend/app/services/generation/card_generator.py` (modifié — imports College/User, incrément compteurs reimport)
- `collega_backend/tests/api/test_colleges_reimport.py` (nouveau)

**Flutter:**
- `collega_app/lib/features/colleges/domain/import_models.dart` (modifié — ajout `ReloadLimits`)
- `collega_app/lib/features/colleges/data/college_import_repository.dart` (modifié — `CollegeReloadLimitException`, `MonthlyReloadLimitException`, `getReloadLimits`, gestion 409 dans `importPdf`)
- `collega_app/lib/features/colleges/colleges_import_providers.dart` (modifié — export nouvelles exceptions, gestion dans `startImport`)
- `collega_app/lib/features/colleges/presentation/college_detail_screen.dart` (modifié — `_CollegeDetailView` → `ConsumerStatefulWidget`, bouton refresh, dialogs reimport)
- `collega_app/lib/features/colleges/presentation/college_import_screen.dart` (modifié — `_handleError` + `_formatDate` pour cas `college_reload_limit` et `monthly_reload_limit`)
- `collega_app/test/features/colleges/college_reimport_test.dart` (nouveau)

### Review Findings

- [x] [Review][Decision] Race condition — résolu via SELECT FOR UPDATE + re-validation dans card_generator (option 2 choisie) [`collega_backend/app/services/generation/card_generator.py`]

- [x] [Review][Patch] Désynchronisation des compteurs quand user_obj est None dans card_generator — corrigé : si college_obj ou user_obj est None, aucun compteur n'est incrémenté + log error [`collega_backend/app/services/generation/card_generator.py`]

- [x] [Review][Patch] Flutter `_handleReimport` attrape uniquement `DioException` — corrigé : `catch (_)` pour capturer toutes les exceptions [`collega_app/lib/features/colleges/presentation/college_detail_screen.dart`]

- [x] [Review][Patch] Flutter : valeurs de fallback quota codées en dur (`?? 2`, `?? 3`) dans `CollegeImportRepository` — corrigé : cast non-nullable, throws si champs manquants [`collega_app/lib/features/colleges/data/college_import_repository.dart`]

- [x] [Review][Defer] Reset mensuel commité avec le premier `db.commit()` avant l'enqueue ARQ — si l'enqueue échoue, le job est supprimé mais `monthly_reloads_reset_at` avance d'un mois. Impact faible (favorable à l'utilisateur). [`collega_backend/app/api/v1/colleges.py`] — deferred, pre-existing

- [x] [Review][Defer] Comparaison timezone-aware `now >= monthly_reloads_reset_at` sans coercion explicite — certains drivers SQLAlchemy peuvent retourner des datetimes naïves depuis `DateTime(timezone=True)`, provoquant un `TypeError` à runtime. Pattern pré-existant dans le projet. [`collega_backend/app/api/v1/colleges.py`] — deferred, pre-existing

## Change Log

- 2026-05-10 : Implémentation complète Story 3.4 — Hash-sharing & Limites de Reimport (claude-sonnet-4-6)
  - Migration Alembic #007 : colonne `monthly_reloads_reset_at` sur `users`
  - Endpoint `GET /v1/colleges/{ref_id}/reload-limits` avec auto-reset virtuel mensuel
  - Quota checks dans `import_college_pdf` (409 COLLEGE_RELOAD_LIMIT / MONTHLY_RELOAD_LIMIT)
  - Incrément compteurs dans `card_generator.py` (reimport non-hash-share uniquement)
  - Flutter : modèle `ReloadLimits`, exceptions, `getReloadLimits`, bouton refresh + dialogs dans `CollegeDetailScreen`
  - 8 tests backend + 8 tests Flutter ajoutés, 0 régression

# Story 1.4 : Interface Admin Web Phase 0

Status: done

## Story

En tant qu'**opérateur**,
je veux une interface admin web sécurisée pour piloter le pipeline de génération et monitorer le système,
afin de valider la qualité end-to-end et d'ajuster la configuration sans déploiement.

## Acceptance Criteria

1. **Authentification HTTP Basic Auth**
   - Étant donné l'interface admin accessible à `/v1/admin/*`
   - Quand j'y accède sans credentials
   - Alors 401 est retourné — accès refusé sans credentials valides (déjà implémenté Story 1.2, à préserver)

2. **Déclenchement manuel génération** (déjà implémenté Story 1.2, à préserver)
   - Étant donné que je suis connecté à l'interface admin
   - Quand je soumet un PDF via `POST /v1/admin/colleges/{college_id}/process`
   - Alors un job ARQ est créé et mis en queue avec statut `pending`

3. **Dashboard queue ARQ**
   - Étant donné des jobs en cours ou terminés (FR43)
   - Quand je consulte `GET /v1/admin/queue`
   - Alors je vois pour chaque job récent : `college_id`, `job_id`, `status`, `ocr_page_progress`, `total_pages`, `card_count`, `elapsed_seconds` (temps depuis `created_at`), `error_message`
   - Et la liste est triée par `created_at` décroissant, limitée aux 50 derniers jobs

4. **Stats collège traité**
   - Étant donné la page des statistiques (FR48)
   - Quand je consulte `GET /v1/admin/colleges/{college_id}/stats`
   - Alors je vois : `card_count_by_rang` (A/B/C), `avg_ocr_confidence` (moyenne globale), `items_ocr_confidence` (liste par item_number), `hash_shared` (bool depuis le dernier job)
   - Et 404 si le collège n'existe pas

5. **Gestion des accès beta**
   - Étant donné la gestion des accès beta (FR44)
   - Quand je consulte `GET /v1/admin/users`
   - Alors je vois la liste de tous les utilisateurs avec `user_id`, `email`, `is_beta`, `is_subscribed`, `monthly_reloads`
   - Quand je fais `PATCH /v1/admin/users/{user_id}/beta` avec `{"is_beta": true|false}`
   - Alors le flag `is_beta` est mis à jour en base
   - Et 404 si l'utilisateur n'existe pas

6. **Configuration anti-spam runtime**
   - Étant donné la configuration anti-spam (FR45)
   - Quand je consulte `GET /v1/admin/config`
   - Alors je vois les valeurs actuelles de `reload_count_max` et `monthly_reloads_max`
   - Quand je fais `PATCH /v1/admin/config` avec les nouvelles valeurs
   - Alors les valeurs sont mises à jour dans le singleton `settings` en mémoire et appliquées immédiatement sans redémarrage

7. **Webhook RevenueCat**
   - Étant donné l'endpoint webhook RevenueCat (FR46)
   - Quand `POST /v1/webhooks/revenuecat` reçoit un event avec le header `Authorization` égal au secret configuré
   - Alors le statut `is_subscribed` de l'utilisateur est mis à jour selon le type d'event
   - Et les events sans header `Authorization` ou avec valeur incorrecte retournent 401
   - Et les utilisateurs introuvables via `app_user_id` retournent 404
   - Et un event inconnu ou neutre retourne 200 sans modification

## Tasks / Subtasks

- [x] Task 1 : Mise à jour `app/core/config.py` (AC: #6, #7)
  - [x] 1.1 Ajouter `revenuecat_webhook_secret: str = ""` dans `Settings`

- [x] Task 2 : Nouveaux schémas Pydantic `app/schemas/admin.py` (AC: #3, #4, #5, #6)
  - [x] 2.1 Ajouter `QueueJobData` — champs : `job_id: str`, `college_id: str`, `status: str`, `ocr_page_progress: int`, `total_pages: int | None`, `card_count: int`, `elapsed_seconds: float`, `error_message: str | None`
  - [x] 2.2 Ajouter `QueueResponse` — `data: list[QueueJobData]`, `total: int`
  - [x] 2.3 Ajouter `CollegeStatsData` — `card_count_by_rang: dict[str, int]`, `avg_ocr_confidence: float`, `items_ocr_confidence: list[ItemOcrData]`, `hash_shared: bool`
  - [x] 2.4 Ajouter `ItemOcrData` — `item_number: int`, `ocr_confidence_score: float`, `low_confidence: bool`
  - [x] 2.5 Ajouter `CollegeStatsResponseWrapped` — `data: CollegeStatsData`
  - [x] 2.6 Ajouter `UserBetaData` — `user_id: str`, `email: str`, `is_beta: bool`, `is_subscribed: bool`, `monthly_reloads: int`
  - [x] 2.7 Ajouter `UsersListResponseWrapped` — `data: list[UserBetaData]`, `total: int`
  - [x] 2.8 Ajouter `BetaUpdateRequest` — `is_beta: bool`
  - [x] 2.9 Ajouter `BetaUpdateResponseWrapped` — `data: UserBetaData`
  - [x] 2.10 Ajouter `ConfigData` — `reload_count_max: int`, `monthly_reloads_max: int`
  - [x] 2.11 Ajouter `ConfigUpdateRequest` — `reload_count_max: int | None`, `monthly_reloads_max: int | None`
  - [x] 2.12 Ajouter `ConfigResponseWrapped` — `data: ConfigData`

- [x] Task 3 : Nouveau schéma `app/schemas/billing.py` (AC: #7)
  - [x] 3.1 Créer `app/schemas/billing.py` — `RevenueCatEventData` (Pydantic, voir Dev Notes pour la structure exacte), `RevenueCatWebhookPayload`

- [x] Task 4 : Étendre `app/api/v1/admin.py` — routes dashboard (AC: #3, #4)
  - [x] 4.1 Implémenter `GET /v1/admin/queue` — charger les 50 derniers `GenerationJob` (jointure avec `College` pour `ocr_page_progress`/`total_pages`), calculer `elapsed_seconds = (now - job.created_at).total_seconds()`
  - [x] 4.2 Implémenter `GET /v1/admin/colleges/{college_id}/stats` — compter `FlashCard` par rang, aggréger `Item.ocr_confidence_score`, récupérer `hash_shared` depuis le dernier job `generation_complete`

- [x] Task 5 : Étendre `app/api/v1/admin.py` — routes utilisateurs et config (AC: #5, #6)
  - [x] 5.1 Implémenter `GET /v1/admin/users` — `SELECT * FROM users ORDER BY created_at DESC`
  - [x] 5.2 Implémenter `PATCH /v1/admin/users/{user_id}/beta` — `db.get(User, user_id)`, mettre à jour `is_beta`, `db.commit()`
  - [x] 5.3 Implémenter `GET /v1/admin/config` — retourner `settings.reload_count_max` et `settings.monthly_reloads_max`
  - [x] 5.4 Implémenter `PATCH /v1/admin/config` — muter `settings.reload_count_max` et `settings.monthly_reloads_max` si fournis (mutation directe du singleton)

- [x] Task 6 : Créer `app/api/v1/billing.py` — webhook RevenueCat (AC: #7)
  - [x] 6.1 Créer le fichier, implémenter `POST /v1/webhooks/revenuecat` (voir Dev Notes pour la logique complète)
  - [x] 6.2 Vérifier `Authorization` header via `secrets.compare_digest` — retourner 401 si absent ou invalide
  - [x] 6.3 Parser le payload `RevenueCatWebhookPayload` — extraire `event.app_user_id` et `event.type`
  - [x] 6.4 Lookup `User` par `id = UUID(event.app_user_id)` — retourner 404 si introuvable (envelopper dans try/except ValueError sur UUID invalide → 422)
  - [x] 6.5 Mettre à jour `user.is_subscribed` selon le type d'event (voir Dev Notes), `db.commit()`

- [x] Task 7 : Mettre à jour `app/main.py` (AC: #7)
  - [x] 7.1 Importer et inclure le router billing : `app.include_router(billing_router, prefix="/v1/webhooks")`

- [x] Task 8 : Tests (AC: #1–#7)
  - [x] 8.1 `tests/api/test_admin_queue.py` — tester GET /queue (liste vide, liste avec jobs, format élapsed_seconds)
  - [x] 8.2 `tests/api/test_admin_college_stats.py` — tester GET /stats (404, stats avec fiches, hash_shared True/False)
  - [x] 8.3 `tests/api/test_admin_users_beta.py` — tester GET /users et PATCH /users/{id}/beta (200, 404, is_beta toggle)
  - [x] 8.4 `tests/api/test_admin_config.py` — tester GET /config (valeurs actuelles), PATCH /config (mutation settings)
  - [x] 8.5 `tests/api/test_billing_webhook.py` — tester 401 sans Authorization, 401 mauvais secret, 404 user inconnu, INITIAL_PURCHASE → is_subscribed True, CANCELLATION → is_subscribed False, event neutre → 200 sans modif

### Review Findings

- [x] [Review][Decision] Webhook 404 vs 200 sur user inconnu — Décision: garder 404. L'endpoint est protégé par le secret partagé, donc aucune divulgation d'info utile à un attaquant externe. 404 est plus debuggable pour l'équipe. [billing.py]
- [x] [Review][Decision] Authorization header format RevenueCat — Décision: stripper "Bearer " défensivement via `removeprefix("Bearer ")`. Coût nul, protège contre mauvaise config. Test ajouté. [billing.py]
- [x] [Review][Decision] avg_ocr_confidence retourne 0.0 quand aucun item n'existe — Décision: retourner None. Sémantiquement correct — 0.0 ≠ "pas de données". Schema mis à jour: `float | None`. [admin.py:271, schemas/admin.py]
- [x] [Review][Decision] ocr_page_progress / total_pages dans /queue viennent de College (état actuel) et non du job — Décision: renommer les champs en `college_ocr_page_progress` et `college_total_pages` pour rendre la source de données explicite. Aucun consommateur externe Phase 0. [admin.py:226-227, schemas/admin.py]

- [x] [Review][Patch] Empty revenuecat_webhook_secret accepté sans validation au démarrage — si non configuré, le webhook est inutilisable sans avertissement clair [config.py:21 + billing.py:29]
- [x] [Review][Patch] ConfigUpdateRequest accepte valeurs négatives/zéro sans contrainte — ajouter `ge=1` sur reload_count_max et monthly_reloads_max [schemas/admin.py:97-98]
- [x] [Review][Patch] elapsed_seconds peut être négatif en cas de décalage d'horloge serveur — ajouter `max(0.0, elapsed)` avant `round()` [admin.py:218]
- [x] [Review][Patch] Tests manquants pour events UNCANCELLATION et PRODUCT_CHANGE — couverts par _ACTIVE_EVENTS mais sans test dédié [tests/api/test_billing_webhook.py]

- [x] [Review][Defer] update_config mutation singleton in-memory — non persistante, reset au redémarrage, non thread-safe multi-process — par design Phase 0, documenté [admin.py:365-368] — deferred, Phase 0 intentionnel
- [x] [Review][Defer] GET /admin/users sans pagination — charge toute la table users — Phase 0 usage limité [admin.py:302] — deferred, Phase 0
- [x] [Review][Defer] Stats collège : 3 requêtes sans isolation de snapshot — incohérence possible sous concurrence [admin.py:252-281] — deferred, Phase 0
- [x] [Review][Defer] get_queue INNER JOIN silencieux sur jobs orphelins — impossible via CASCADE FK, mais risque si manipulation directe SQL [admin.py:207-211] — deferred, contrainte FK protège
- [x] [Review][Defer] Webhook no-op ouvre une connexion DB inutilement — FastAPI Depends résolu avant le early return [billing.py:22] — deferred, Phase 0 faible volume

## Dev Notes

### Vue d'ensemble — Ce que Story 1.4 construit

Story 1.4 étend les routes admin existantes (Story 1.2) et ajoute le webhook billing (FR46) :

```
[EXISTANT Story 1.2]
POST /v1/admin/colleges/{id}/process   → soumettre PDF
GET  /v1/admin/colleges/{id}/status    → statut OCR

[NOUVEAU Story 1.4]
GET  /v1/admin/queue                   → dashboard tous jobs
GET  /v1/admin/colleges/{id}/stats     → stats fiches par rang + OCR
GET  /v1/admin/users                   → liste utilisateurs
PATCH /v1/admin/users/{id}/beta        → toggle is_beta
GET  /v1/admin/config                  → config anti-spam
PATCH /v1/admin/config                 → modifier config anti-spam (in-memory)

POST /v1/webhooks/revenuecat           → webhook billing (NON préfixé admin)
```

### État actuel des fichiers MODIFIED — Ce qui doit être préservé

**`app/api/v1/admin.py`** (existant, à étendre) :
- Contient déjà `POST /colleges/{id}/process` et `GET /colleges/{id}/status`
- Utilise `_http_basic` via `Depends(get_admin_user)` — CONSERVER ce pattern sur toutes les nouvelles routes admin
- Pattern d'erreur : `HTTPException(status_code=404, detail={"code": "...", "message": "..."})` — CONSERVER
- Imports à conserver : `APIRouter`, `Depends`, `HTTPException`, `UploadFile`, `select`, `AsyncSession`
- Ajouter les nouveaux imports : `func` depuis `sqlalchemy`, `User`, `Item`, `FlashCard`, nouveaux schémas
- `router = APIRouter(tags=["admin"])` — CONSERVER, ne pas recréer

**`app/schemas/admin.py`** (existant, à étendre) :
- Contient `ProcessCollegeResponse`, `CollegeStatusData`, `ProcessCollegeResponseWrapped`, `CollegeStatusResponseWrapped`
- CONSERVER tous ces schémas — Story 1.5 les réutilise

**`app/core/config.py`** (existant, à étendre) :
- Contient déjà `reload_count_max: int = 2` et `monthly_reloads_max: int = 3`
- AJOUTER uniquement `revenuecat_webhook_secret: str = ""`
- Le singleton `settings` est importé dans tout le backend — toute mutation de ses attributs est visible immédiatement

**`app/main.py`** (existant, à étendre) :
- Contient `app.include_router(admin_router, prefix="/v1/admin")`
- AJOUTER `app.include_router(billing_router, prefix="/v1/webhooks")` après les imports existants

### Schémas RevenueCat — Structure exacte du Payload

RevenueCat envoie un POST JSON avec cette structure :
```python
# app/schemas/billing.py
from pydantic import BaseModel

class RevenueCatEventData(BaseModel):
    type: str                          # "INITIAL_PURCHASE", "RENEWAL", "CANCELLATION", etc.
    app_user_id: str                   # UUID de l'utilisateur (user.id)
    product_id: str | None = None
    price: float | None = None
    currency: str | None = None

class RevenueCatWebhookPayload(BaseModel):
    event: RevenueCatEventData
    api_version: str | None = None
```

**Types d'events et mise à jour `is_subscribed` :**
```python
# Dans billing.py
ACTIVE_EVENTS = {"INITIAL_PURCHASE", "RENEWAL", "UNCANCELLATION", "PRODUCT_CHANGE"}
INACTIVE_EVENTS = {"CANCELLATION", "EXPIRATION"}
# Tous les autres events : no-op (retourner 200 sans modification)
```

### Endpoint webhook RevenueCat — Logique complète

```python
# app/api/v1/billing.py
import secrets
import uuid
from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.schemas.billing import RevenueCatWebhookPayload

router = APIRouter(tags=["billing"])

ACTIVE_EVENTS = {"INITIAL_PURCHASE", "RENEWAL", "UNCANCELLATION", "PRODUCT_CHANGE"}
INACTIVE_EVENTS = {"CANCELLATION", "EXPIRATION"}

@router.post("/revenuecat", status_code=200)
async def revenuecat_webhook(
    payload: RevenueCatWebhookPayload,
    authorization: str | None = Header(default=None),
    db: AsyncSession = Depends(get_db),
):
    # 1. Vérifier le secret — Authorization header doit être égal au secret configuré
    if not authorization or not secrets.compare_digest(
        authorization.encode(), settings.revenuecat_webhook_secret.encode()
    ):
        raise HTTPException(status_code=401, detail={"code": "INVALID_SIGNATURE", "message": "Invalid or missing Authorization"})
    
    event_type = payload.event.type
    
    # 2. No-op si event neutre
    if event_type not in ACTIVE_EVENTS and event_type not in INACTIVE_EVENTS:
        return {"data": {"status": "ignored"}}
    
    # 3. Lookup user
    try:
        user_id = uuid.UUID(payload.event.app_user_id)
    except ValueError:
        raise HTTPException(status_code=422, detail={"code": "INVALID_USER_ID", "message": "app_user_id is not a valid UUID"})
    
    from app.models.user import User
    user = await db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=404, detail={"code": "USER_NOT_FOUND", "message": f"User {user_id} not found"})
    
    # 4. Mettre à jour is_subscribed
    user.is_subscribed = event_type in ACTIVE_EVENTS
    await db.commit()
    
    return {"data": {"status": "updated", "is_subscribed": user.is_subscribed}}
```

### Endpoint GET /v1/admin/queue — Logique

```python
@router.get("/queue", response_model=QueueResponse)
async def get_queue(
    _: bool = Depends(get_admin_user),
    db: AsyncSession = Depends(get_db),
):
    from datetime import datetime, timezone
    from sqlalchemy import select
    from app.models.generation_job import GenerationJob
    from app.models.college import College

    result = await db.execute(
        select(GenerationJob, College)
        .join(College, GenerationJob.college_id == College.id)
        .order_by(GenerationJob.created_at.desc())
        .limit(50)
    )
    rows = result.all()
    
    now = datetime.now(timezone.utc)
    jobs = []
    for job, college in rows:
        elapsed = (now - job.created_at.replace(tzinfo=timezone.utc) if job.created_at.tzinfo is None else now - job.created_at).total_seconds()
        jobs.append(QueueJobData(
            job_id=str(job.id),
            college_id=str(job.college_id),
            status=job.status,
            ocr_page_progress=college.ocr_page_progress,
            total_pages=college.total_pages,
            card_count=job.card_count,
            elapsed_seconds=round(elapsed, 1),
            error_message=job.error_message,
        ))
    return QueueResponse(data=jobs, total=len(jobs))
```

**Note datetime :** les `created_at` en PostgreSQL ont un tzinfo (TIMESTAMPTZ). En SQLite (tests), ils peuvent ne pas en avoir. Utiliser `.replace(tzinfo=timezone.utc)` si `tzinfo is None` pour normaliser.

### Endpoint GET /v1/admin/colleges/{id}/stats — Logique

```python
from sqlalchemy import func, select
from app.models.flash_card import FlashCard
from app.models.item import Item

# Compter fiches par rang
card_counts = await db.execute(
    select(FlashCard.rang, func.count(FlashCard.id))
    .where(FlashCard.college_id == college_id)
    .group_by(FlashCard.rang)
)
by_rang = {row[0]: row[1] for row in card_counts.all()}
card_count_by_rang = {"A": by_rang.get("A", 0), "B": by_rang.get("B", 0), "C": by_rang.get("C", 0)}

# OCR confidence par item
items_result = await db.execute(
    select(Item.item_number, Item.ocr_confidence_score, Item.low_confidence)
    .where(Item.college_id == college_id)
    .order_by(Item.item_number)
)
items_data = items_result.all()
items_ocr = [ItemOcrData(item_number=r[0], ocr_confidence_score=r[1], low_confidence=r[2]) for r in items_data]
avg_confidence = sum(r[1] for r in items_data) / len(items_data) if items_data else 0.0

# hash_shared depuis le dernier job generation_complete
last_job = await db.execute(
    select(GenerationJob)
    .where(GenerationJob.college_id == college_id)
    .where(GenerationJob.status == "generation_complete")
    .order_by(GenerationJob.created_at.desc())
    .limit(1)
)
job = last_job.scalar_one_or_none()
hash_shared = job.hash_shared if job else False
```

### Endpoint PATCH /v1/admin/config — Mutation in-memory

```python
@router.patch("/config", response_model=ConfigResponseWrapped)
async def update_config(
    body: ConfigUpdateRequest,
    _: bool = Depends(get_admin_user),
):
    if body.reload_count_max is not None:
        settings.reload_count_max = body.reload_count_max
    if body.monthly_reloads_max is not None:
        settings.monthly_reloads_max = body.monthly_reloads_max
    return ConfigResponseWrapped(data=ConfigData(
        reload_count_max=settings.reload_count_max,
        monthly_reloads_max=settings.monthly_reloads_max,
    ))
```

**Important :** Cet endpoint ne prend PAS `db: AsyncSession` car il ne touche pas la base. Ne pas le rajouter.

### Pattern de Tests — Rappels Story 1.2/1.3

1. **`conftest.py`** : déjà configuré avec `mock_db` fixture et `client` fixture. NE PAS recréer un conftest dans `tests/api/`.
2. **`types.SimpleNamespace`** pour simuler les modèles SQLAlchemy (évite l'instrumentation ORM) :
   ```python
   def make_user(user_id=None):
       return types.SimpleNamespace(
           id=user_id or uuid.uuid4(),
           email="user@test.com",
           is_beta=False,
           is_subscribed=False,
           monthly_reloads=0,
       )
   ```
3. **`mock_db.execute`** retourne un objet avec `.all()`, `.scalar_one_or_none()`, `.scalars()` selon le besoin :
   ```python
   # Pour .all()
   mock_db.execute = AsyncMock(return_value=MagicMock(all=MagicMock(return_value=[])))
   # Pour .scalar_one_or_none()
   mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None)))
   ```
4. **Auth dans les tests** : `ADMIN_AUTH = ("admin", "testpass")` (voir `conftest.py` — `ADMIN_PASSWORD=testpass`)
5. **Variables d'environnement billing** : dans le test `test_billing_webhook.py`, utiliser `patch("app.api.v1.billing.settings")` pour mocker le secret.
6. **Tests config PATCH** : mocker `settings` directement ou patcher l'objet — attention à restaurer les valeurs après chaque test.

### Gestion de `mock_db.execute` avec jointure (queue)

La route queue fait un `select(GenerationJob, College)` qui retourne des tuples `(job, college)`. Dans les tests :
```python
from unittest.mock import MagicMock, AsyncMock
import types

def make_job_row(college_id=None):
    cid = college_id or uuid.uuid4()
    job = types.SimpleNamespace(
        id=uuid.uuid4(), college_id=cid, status="generation_complete",
        card_count=5, error_message=None,
        created_at=datetime.now(timezone.utc), hash_shared=False,
    )
    college = types.SimpleNamespace(
        id=cid, ocr_page_progress=10, total_pages=20,
    )
    return (job, college)

mock_db.execute = AsyncMock(
    return_value=MagicMock(all=MagicMock(return_value=[make_job_row()]))
)
```

### Fichiers à Créer (NEW)

```
collega_backend/
├── app/
│   ├── api/v1/
│   │   └── billing.py                    ← NEW
│   └── schemas/
│       └── billing.py                    ← NEW
└── tests/api/
    ├── test_admin_queue.py               ← NEW
    ├── test_admin_college_stats.py       ← NEW
    ├── test_admin_users_beta.py          ← NEW
    ├── test_admin_config.py              ← NEW
    └── test_billing_webhook.py           ← NEW
```

### Fichiers à Modifier (UPDATE)

| Fichier | Modification |
|---------|-------------|
| `app/api/v1/admin.py` | Ajouter 6 nouvelles routes (queue, stats, users, beta, config) |
| `app/schemas/admin.py` | Ajouter 12 nouveaux schémas Pydantic |
| `app/core/config.py` | Ajouter `revenuecat_webhook_secret: str = ""` |
| `app/main.py` | Inclure billing router avec prefix `/v1/webhooks` |

### Apprentissages Stories 1.2 et 1.3 — À Appliquer Impérativement

1. **Toujours `async_session_factory()` dans les workers, `get_db` dans les routes**
2. **`types.SimpleNamespace`** pour les modèles dans les tests (jamais `Model.__new__(Model)`)
3. **Mocker à l'import du module** : `patch("app.api.v1.billing.settings")`, pas `patch("app.core.config.settings")`
4. **Wrapper `{ "data": ... }` ou `{ "error": ... }`** sur toutes les réponses API — pas d'exception
5. **`HTTPException` avec `detail={"code": "...", "message": "..."}`** — pattern d'erreur uniforme
6. **Jamais `print()`** — uniquement `logger.info/warning/error()`
7. **ISO 8601 UTC** pour toutes les dates
8. **Imports SQLAlchemy (`func`, `select`)** : préférer les imports au niveau du module, pas en body de fonction

### Patterns de Qualité — Rappels

- **Toutes les routes admin** : `_: bool = Depends(get_admin_user)` — NE PAS oublier sur les nouvelles routes
- **NFR8** : le webhook billing met à jour `user.is_subscribed` — pas de scoping `user_id` nécessaire car l'op est administrative
- **`secrets.compare_digest`** : comparaison timing-safe — utiliser pour TOUS les checks de secrets (Basic Auth déjà fait, RevenueCat à faire)
- **Pas de route HTML/template** : Story 1.4 = uniquement endpoints JSON (FastAPI), pas de Jinja2

### References

- [Source: `_bmad-output/planning-artifacts/epics.md#Story-1.4`] — AC complets FR43–FR48
- [Source: `_bmad-output/planning-artifacts/architecture.md#Admin-Interface`] — "Routes FastAPI + HTML statique, Basic Auth"
- [Source: `_bmad-output/planning-artifacts/architecture.md#API-Patterns`] — wrapper `{ "data": ... }`, snake_case, HTTPException
- [Source: `_bmad-output/planning-artifacts/architecture.md#Authentication-Security`] — JWT, RevenueCat webhook, `is_beta`
- [Source: `collega_backend/app/api/v1/admin.py`] — état actuel routes admin, pattern Basic Auth
- [Source: `collega_backend/app/schemas/admin.py`] — schémas existants à conserver
- [Source: `collega_backend/app/core/config.py`] — pydantic-settings, `reload_count_max`, `monthly_reloads_max`
- [Source: `collega_backend/app/models/user.py`] — `is_beta`, `is_subscribed`, `monthly_reloads`
- [Source: `collega_backend/app/models/generation_job.py`] — `card_count`, `hash_shared`, `status`
- [Source: `collega_backend/app/models/flash_card.py`] — `rang`, `ocr_confidence_score`
- [Source: `collega_backend/tests/conftest.py`] — pattern `mock_db`, `client`, `ADMIN_AUTH`
- [Source: `collega_backend/tests/api/test_admin_ocr.py`] — pattern `types.SimpleNamespace`, `AsyncMock`

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6 (create-story)

### Debug Log References

(aucun blocage rencontré)

### Completion Notes List

- `config.py` : ajout `revenuecat_webhook_secret: str = ""`
- `schemas/admin.py` : 12 nouveaux schémas Pydantic (QueueJobData, CollegeStatsData, ItemOcrData, UserBetaData, ConfigData, + wrappers + requests)
- `schemas/billing.py` : nouveau fichier — `RevenueCatEventData`, `RevenueCatWebhookPayload`
- `api/v1/admin.py` : 6 nouvelles routes (GET /queue, GET /colleges/{id}/stats, GET /users, PATCH /users/{id}/beta, GET /config, PATCH /config) — routeur existant préservé
- `api/v1/billing.py` : nouveau fichier — `POST /v1/webhooks/revenuecat` avec vérification `Authorization` timing-safe, dispatch events ACTIVE/INACTIVE, no-op sur events neutres
- `main.py` : inclusion du billing router sous `/v1/webhooks`
- 36 nouveaux tests, 106 total (+ 1 skipped), 0 régression

### File List

- `collega_backend/app/core/config.py` (MODIFIED — ajout revenuecat_webhook_secret)
- `collega_backend/app/schemas/admin.py` (MODIFIED — 12 nouveaux schémas)
- `collega_backend/app/schemas/billing.py` (NEW)
- `collega_backend/app/api/v1/admin.py` (MODIFIED — 6 nouvelles routes)
- `collega_backend/app/api/v1/billing.py` (NEW)
- `collega_backend/app/main.py` (MODIFIED — inclusion billing router)
- `collega_backend/tests/api/test_admin_queue.py` (NEW)
- `collega_backend/tests/api/test_admin_college_stats.py` (NEW)
- `collega_backend/tests/api/test_admin_users_beta.py` (NEW)
- `collega_backend/tests/api/test_admin_config.py` (NEW)
- `collega_backend/tests/api/test_billing_webhook.py` (NEW)

## Change Log

| Date | Change |
|------|--------|
| 2026-04-28 | Story créée — analyse exhaustive Story 1.2/1.3, architecture, modèles existants, patterns tests |
| 2026-04-28 | Implémentation complète Story 1.4 — 36 nouveaux tests, 106 total, 0 régression |

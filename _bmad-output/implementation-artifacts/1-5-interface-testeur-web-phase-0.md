# Story 1.5 : Interface Testeur Web Phase 0

Status: done

## Story

En tant que **testeuse**,
je veux naviguer dans les fiches d'un collège généré via une interface web dédiée et donner mon feedback fiche par fiche,
afin de valider la pertinence médicale des fiches pour le go/no-go du MVP Flutter.

## Acceptance Criteria

1. **Authentification tester distincte de l'admin** (AC #1)
   - Étant donné l'interface testeur accessible à `/v1/tester/`
   - Quand j'y accède sans credentials
   - Alors HTTP 401 est retourné avec `WWW-Authenticate: Basic` — accès refusé
   - Et les credentials tester sont **distincts** des credentials admin (variables d'env `TESTER_USERNAME` / `TESTER_PASSWORD`, jamais identiques à `ADMIN_USERNAME` / `ADMIN_PASSWORD`)

2. **Navigation collèges et fiches** (FR49)
   - Étant donné que je suis connectée à l'interface testeur
   - Quand je consulte `GET /v1/tester/colleges`
   - Alors je vois la liste des collèges ayant au moins un job `generation_complete`
   - Quand je consulte `GET /v1/tester/colleges/{college_id}/items`
   - Alors je vois tous les items avec leurs fiches, chaque fiche incluant : `recto`, `verso`, `rang`, `card_type`, `low_confidence` (true si `ocr_confidence_score < 0.7`)
   - Et si un feedback existe déjà pour une fiche (par ce tester ou tout autre), il est retourné dans la réponse
   - Et 404 si le collège n'existe pas

3. **Feedback fiche par fiche** (FR50)
   - Étant donné une fiche affichée
   - Quand je fais `POST /v1/tester/flash-cards/{card_id}/feedback` avec `{"is_pertinent": true|false}`
   - Alors le feedback est enregistré en base dans `tester_feedbacks` avec `tester_id` (username depuis Basic Auth), `is_pertinent`, `created_at`
   - Et si un feedback existe déjà pour cette fiche **par ce même tester**, il est mis à jour (UPSERT via SELECT + UPDATE)
   - Et 404 si la fiche n'existe pas

4. **Résumé par item**
   - Étant donné ma session de feedback sur un collège
   - Quand je consulte `GET /v1/tester/colleges/{college_id}/summary`
   - Alors je vois pour chaque item : `item_number`, `rang`, `total_cards`, `pertinent_count`, `not_pertinent_count`, `pending_count` (total - feedbacks évalués)
   - Et 404 si le collège n'existe pas

5. **Feedback visible par l'opérateur admin**
   - Étant donné le feedback consolidé (AC #5)
   - Quand l'opérateur consulte `GET /v1/admin/colleges/{college_id}/stats`
   - Alors la réponse inclut un champ `pertinence_stats` avec `global_pertinent`, `global_not_pertinent`, `total_evaluated`, et `by_rang` (par rang A/B/C : pertinent + not_pertinent)
   - Et `pertinence_stats` est `null` si aucun feedback n'existe encore

6. **Interface web tester** (`/tester`)
   - Étant donné un fichier `app/static/index.html` servi via `StaticFiles`
   - Quand la testeuse ouvre `/tester` dans son navigateur
   - Alors elle peut sélectionner un collège, naviguer dans les fiches une par une, et donner son feedback via des boutons "Pertinente" / "Non pertinente"
   - Et l'authentification HTTP Basic est déclenchée nativement par le navigateur sur le premier appel API

## Tasks / Subtasks

- [x] Task 1 : Migration Alembic 005 — table `tester_feedbacks` (AC: #3)
  - [x] 1.1 Créer `alembic/versions/005_add_tester_feedbacks.py` — table `tester_feedbacks` avec colonnes : id (UUID PK), flash_card_id (FK flash_cards.id CASCADE), college_id (FK colleges.id CASCADE), tester_id (String 100), is_pertinent (Boolean), created_at (DateTime tz)
  - [x] 1.2 Contrainte UNIQUE sur `(flash_card_id, tester_id)` nommée `uq_tester_feedbacks_card_tester`
  - [x] 1.3 Index sur `ix_tester_feedbacks_flash_card_id` et `ix_tester_feedbacks_college_id`

- [x] Task 2 : Nouveau modèle `app/models/tester_feedback.py` (AC: #3)
  - [x] 2.1 Créer `TesterFeedback(Base)` avec tous les champs de la migration
  - [x] 2.2 Ajouter `from app.models.tester_feedback import TesterFeedback` dans `app/models/__init__.py` ET dans `__all__`

- [x] Task 3 : Nouveaux schémas `app/schemas/tester.py` (AC: #2, #3, #4)
  - [x] 3.1 `CollegeTesterData` — `college_id: str`, `college_ref_id: int`, `card_count: int`, `feedback_count: int`
  - [x] 3.2 `CollegesListResponse` — `data: list[CollegeTesterData]`, `total: int`
  - [x] 3.3 `FeedbackData` — `is_pertinent: bool`, `tester_id: str`, `created_at: str`
  - [x] 3.4 `FlashCardTesterData` — `card_id: str`, `card_type: str`, `rang: str`, `recto: str`, `verso: str`, `low_confidence: bool`, `ocr_confidence_score: float`, `feedback: FeedbackData | None`
  - [x] 3.5 `ItemTesterData` — `item_id: str`, `item_number: int`, `rang: str`, `chapter_title: str | None`, `flash_cards: list[FlashCardTesterData]`
  - [x] 3.6 `CollegeItemsData` — `college_id: str`, `items: list[ItemTesterData]`
  - [x] 3.7 `CollegeItemsResponse` — `data: CollegeItemsData`
  - [x] 3.8 `FeedbackRequest` — `is_pertinent: bool`
  - [x] 3.9 `FeedbackResponseData` — `feedback_id: str`, `card_id: str`, `is_pertinent: bool`, `tester_id: str`, `created_at: str`
  - [x] 3.10 `FeedbackResponseWrapped` — `data: FeedbackResponseData`
  - [x] 3.11 `ItemSummaryData` — `item_id: str`, `item_number: int`, `rang: str`, `total_cards: int`, `pertinent_count: int`, `not_pertinent_count: int`, `pending_count: int`
  - [x] 3.12 `CollegeSummaryData` — `college_id: str`, `items: list[ItemSummaryData]`
  - [x] 3.13 `CollegeSummaryResponse` — `data: CollegeSummaryData`

- [x] Task 4 : Étendre `app/core/config.py` (AC: #1)
  - [x] 4.1 Ajouter `tester_username: str = "tester"` dans `Settings`
  - [x] 4.2 Ajouter `tester_password: str = "change-me"` dans `Settings`

- [x] Task 5 : Étendre `app/deps.py` (AC: #1, #3)
  - [x] 5.1 Créer une instance HTTPBasic séparée : `_http_basic_tester = HTTPBasic()`
  - [x] 5.2 Ajouter `get_tester_user` — vérifie credentials via `secrets.compare_digest`, retourne `credentials.username: str` (le tester_id) — **retourne str, pas bool**
  - [x] 5.3 Exporter `get_tester_user` dans `__all__`

- [x] Task 6 : Créer `app/api/v1/tester.py` — routes JSON (AC: #2, #3, #4)
  - [x] 6.1 `GET /v1/tester/colleges` — lister les colleges ayant un job `generation_complete`, compter cards et feedbacks
  - [x] 6.2 `GET /v1/tester/colleges/{college_id}/items` — 404 si college inexistant, puis items + flash_cards + feedback existant (LEFT JOIN) par item, ordonnés par `item_number`
  - [x] 6.3 `POST /v1/tester/flash-cards/{card_id}/feedback` — 404 si card inexistante, UPSERT feedback (tester_id depuis `Depends(get_tester_user)`)
  - [x] 6.4 `GET /v1/tester/colleges/{college_id}/summary` — 404 si college inexistant, agrégation par item

- [x] Task 7 : Créer `app/static/index.html` — interface web (AC: #6)
  - [x] 7.1 Page HTML + vanilla JS — appelle `/v1/tester/colleges` au chargement (Basic Auth déclenché par navigateur)
  - [x] 7.2 Sélecteur de collège, chargement des fiches via `/v1/tester/colleges/{id}/items`
  - [x] 7.3 Affichage recto/verso, badge rang (A/B/C), indicateur visuel si `low_confidence: true`
  - [x] 7.4 Boutons "Pertinente" (vert) / "Non pertinente" (rouge) → `POST /v1/tester/flash-cards/{id}/feedback`
  - [x] 7.5 Auto-avance à la fiche suivante après chaque feedback
  - [x] 7.6 Affichage résumé par item (appel `/v1/tester/colleges/{id}/summary`)

- [x] Task 8 : Étendre admin pour pertinence (AC: #5)
  - [x] 8.1 Dans `app/schemas/admin.py` : ajouter `PertinenceByRang(BaseModel)` (pertinent: int, not_pertinent: int), `PertinenceStats(BaseModel)` (global_pertinent: int, global_not_pertinent: int, total_evaluated: int, by_rang: dict[str, PertinenceByRang])
  - [x] 8.2 Dans `CollegeStatsData` : ajouter `pertinence_stats: PertinenceStats | None = None`
  - [x] 8.3 Dans `app/api/v1/admin.py` : importer `TesterFeedback`, ajouter requête sur `tester_feedbacks` dans `get_college_stats`, calculer et remplir `pertinence_stats`

- [x] Task 9 : Mettre à jour `app/main.py` (AC: #6)
  - [x] 9.1 Importer `tester_router` depuis `app.api.v1.tester`
  - [x] 9.2 `app.include_router(tester_router, prefix="/v1/tester")` **avant** le montage StaticFiles
  - [x] 9.3 `from fastapi.staticfiles import StaticFiles` et `app.mount("/tester", StaticFiles(directory="app/static", html=True), name="tester-static")` — en DERNIER dans main.py après tous les routeurs

- [x] Task 10 : Mettre à jour `tests/conftest.py`
  - [x] 10.1 Ajouter `os.environ.setdefault("TESTER_USERNAME", "tester")` et `os.environ.setdefault("TESTER_PASSWORD", "testpass")`

- [x] Task 11 : Tests (AC: #1–#5)
  - [x] 11.1 `tests/api/test_tester_colleges.py` — 401 sans auth, liste vide, liste avec collèges generation_complete
  - [x] 11.2 `tests/api/test_tester_items.py` — 401 sans auth, 404 college inexistant, items avec cards, feedback existant dans la réponse
  - [x] 11.3 `tests/api/test_tester_feedback.py` — 401 sans auth, 404 card inconnue, feedback créé, UPSERT si feedback existant
  - [x] 11.4 `tests/api/test_tester_summary.py` — 401 sans auth, 404 college inexistant, compteurs corrects (pertinent/not_pertinent/pending)
  - [x] 11.5 `tests/api/test_admin_college_stats.py` — étendre tests existants : vérifier `pertinence_stats` null si aucun feedback, et non-null avec valeurs correctes si feedbacks existent

### Review Findings (AI Code Review — 2026-04-30)

**Decision Needed**
- [x] [Review][Decision] D1 — Native browser Basic Auth vs. custom HTML form (AC #6) — **Décision : conserver la form custom** (meilleure UX acceptée, déviation AC #6 consciente pour Phase 0). Déviation spécifiée dans deferred-work.md.
- [x] [Review][Decision] D2 — Feedback scope dans `/items` et `/summary` : all-tester vs. tester actuel — **Décision : filtrer par `tester_id` courant** → converti en patch P8.

**Patches**
- [x] [Review][Patch] P1 — Aucun validator tester_creds ≠ admin_creds (AC #1) [app/core/config.py] ✅ applied
- [x] [Review][Patch] P2 — `by_rang` variable shadowing dans `get_college_stats` [app/api/v1/admin.py] ✅ applied (renommé card_rang_counts + pertinence_by_rang)
- [x] [Review][Patch] P3 — `StaticFiles(directory="app/static")` chemin relatif crash hors project root [app/main.py] ✅ applied (Path(__file__).parent / "static")
- [x] [Review][Patch] P4 — `nextCard()` boucle infinie quand toutes les fiches sont évaluées [app/static/index.html] ✅ applied
- [x] [Review][Patch] P5 — `login()` ignore erreurs non-401 (500/503 → état "connecté" cassé) [app/static/index.html] ✅ applied
- [x] [Review][Patch] P6 — `FeedbackData.created_at` typé `str` au lieu de `datetime` [app/schemas/tester.py] ✅ applied
- [x] [Review][Patch] P7 — `pertinence_stats.by_rang` omet les rangs sans feedback (frontend peut recevoir des rangs manquants) [app/api/v1/admin.py] ✅ applied (initialisé A/B/C)
- [x] [Review][Patch] P8 — Filtrer les feedbacks par `tester_id` courant dans `get_college_items` et `get_college_summary` [app/api/v1/tester.py] ✅ applied

**Deferred**
- [x] [Review][Defer] W1 — `REVENUECAT_WEBHOOK_SECRET` validator crash démarrage [app/core/config.py] — deferred, pré-existant Story 1.3/1.4
- [x] [Review][Defer] W2 — Tester unique : tous partagent `tester_id="tester"` [app/deps.py] — deferred, Phase 0 mono-tester intentionnel
- [x] [Review][Defer] W3 — Race condition UPSERT feedback (double-clic) [app/api/v1/tester.py] — deferred, Phase 0 mono-utilisateur, risque négligeable
- [x] [Review][Defer] W4 — N+1 queries `list_colleges` [app/api/v1/tester.py] — deferred, performance Phase 0 acceptable
- [x] [Review][Defer] W5 — N+1 queries `get_college_summary` [app/api/v1/tester.py] — deferred, performance Phase 0 acceptable
- [x] [Review][Defer] W6 — Pas de `updated_at` sur TesterFeedback [app/models/tester_feedback.py] — deferred, Phase 0 pas de besoin d'audit trail
- [x] [Review][Defer] W7 — `avg_confidence` TypeError si `ocr_confidence_score` NULL [app/api/v1/admin.py] — deferred, pré-existant Story 1.4

## Dev Notes

### Vue d'ensemble — Ce que Story 1.5 construit

Story 1.5 ajoute l'interface testeur (FR49–FR50) sur l'infrastructure admin existante (Stories 1.2–1.4) :

```
[EXISTANT Stories 1.2–1.4 — PRÉSERVER]
POST /v1/admin/colleges/{id}/process   → soumettre PDF
GET  /v1/admin/colleges/{id}/status    → statut OCR
GET  /v1/admin/queue                   → dashboard tous jobs
GET  /v1/admin/colleges/{id}/stats     → stats fiches + OCR  ← ÉTENDU (pertinence_stats)
GET  /v1/admin/users                   → liste utilisateurs
PATCH /v1/admin/users/{id}/beta        → toggle is_beta
GET  /v1/admin/config                  → config anti-spam
PATCH /v1/admin/config                 → modifier config anti-spam
POST /v1/webhooks/revenuecat           → webhook billing

[NOUVEAU Story 1.5]
GET  /v1/tester/colleges               → liste collèges generation_complete
GET  /v1/tester/colleges/{id}/items    → items + fiches + feedback existant
POST /v1/tester/flash-cards/{id}/feedback → enregistrer feedback (UPSERT)
GET  /v1/tester/colleges/{id}/summary  → résumé par item
GET  /tester  (StaticFiles)            → interface HTML statique
```

### Modèle TesterFeedback — Définition complète

```python
# app/models/tester_feedback.py
import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, ForeignKey, String, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class TesterFeedback(Base):
    __tablename__ = "tester_feedbacks"
    __table_args__ = (
        UniqueConstraint("flash_card_id", "tester_id", name="uq_tester_feedbacks_card_tester"),
    )

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    flash_card_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("flash_cards.id", ondelete="CASCADE"), nullable=False, index=True
    )
    college_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), nullable=False, index=True
    )
    tester_id: Mapped[str] = mapped_column(String(100), nullable=False)
    is_pertinent: Mapped[bool] = mapped_column(Boolean, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )
```

**Note `models/__init__.py`** : Règle dérivée du deferred-work.md — chaque nouveau `models/xxx.py` DOIT être importé dans `__init__.py`. Ajouter :
```python
from app.models.tester_feedback import TesterFeedback
__all__ = [..., "TesterFeedback"]
```

### Migration 005 — Structure exacte

```python
# alembic/versions/005_add_tester_feedbacks.py
# Revises: 004

def upgrade() -> None:
    op.create_table(
        "tester_feedbacks",
        sa.Column("id", sa.UUID(), nullable=False, server_default=sa.text("gen_random_uuid()")),
        sa.Column("flash_card_id", sa.UUID(), nullable=False),
        sa.Column("college_id", sa.UUID(), nullable=False),
        sa.Column("tester_id", sa.String(100), nullable=False),
        sa.Column("is_pertinent", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("NOW()")),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["flash_card_id"], ["flash_cards.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["college_id"], ["colleges.id"], ondelete="CASCADE"),
        sa.UniqueConstraint("flash_card_id", "tester_id", name="uq_tester_feedbacks_card_tester"),
    )
    op.create_index("ix_tester_feedbacks_flash_card_id", "tester_feedbacks", ["flash_card_id"])
    op.create_index("ix_tester_feedbacks_college_id", "tester_feedbacks", ["college_id"])

def downgrade() -> None:
    op.drop_index("ix_tester_feedbacks_college_id", table_name="tester_feedbacks")
    op.drop_index("ix_tester_feedbacks_flash_card_id", table_name="tester_feedbacks")
    op.drop_table("tester_feedbacks")
```

### Pattern `get_tester_user` dans deps.py

**Différence critique avec `get_admin_user`** : `get_tester_user` retourne `str` (le username = tester_id), pas `bool`. Ainsi les routes utilisent `tester_id: str = Depends(get_tester_user)` pour avoir l'auth ET le tester_id en une seule dépendance.

```python
# À ajouter dans app/deps.py
_http_basic_tester = HTTPBasic()  # instance distincte de _http_basic (admin)

async def get_tester_user(
    credentials: HTTPBasicCredentials = Depends(_http_basic_tester),
) -> str:
    correct_username = secrets.compare_digest(
        credentials.username.encode("utf-8"),
        settings.tester_username.encode("utf-8"),
    )
    correct_password = secrets.compare_digest(
        credentials.password.encode("utf-8"),
        settings.tester_password.encode("utf-8"),
    )
    if not (correct_username and correct_password):
        raise HTTPException(
            status_code=401,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Basic"},
        )
    return credentials.username
```

### Endpoint GET /v1/tester/colleges — Logique

Approche en deux requêtes (plus lisible que la jointure complexe) :
```python
# 1. Récupérer les college_ids ayant un job generation_complete
job_result = await db.execute(
    select(GenerationJob.college_id).where(GenerationJob.status == "generation_complete").distinct()
)
college_ids = [r for r in job_result.scalars().all()]

if not college_ids:
    return CollegesListResponse(data=[], total=0)

# 2. Charger les colleges
colleges_result = await db.execute(
    select(College).where(College.id.in_(college_ids))
)
colleges = colleges_result.scalars().all()

# 3. Pour chaque college, compter cards et feedbacks
data = []
for college in colleges:
    card_count = (await db.execute(
        select(func.count(FlashCard.id)).where(FlashCard.college_id == college.id)
    )).scalar_one()
    feedback_count = (await db.execute(
        select(func.count(TesterFeedback.id)).where(TesterFeedback.college_id == college.id)
    )).scalar_one()
    data.append(CollegeTesterData(
        college_id=str(college.id),
        college_ref_id=college.college_ref_id,
        card_count=card_count,
        feedback_count=feedback_count,
    ))
```

### Endpoint GET /v1/tester/colleges/{college_id}/items — Logique

```python
# 1. Vérifier l'existence du college
college = await db.get(College, college_id)
if college is None:
    raise HTTPException(status_code=404, detail={"code": "COLLEGE_NOT_FOUND", ...})

# 2. Charger les items
items_result = await db.execute(
    select(Item).where(Item.college_id == college_id).order_by(Item.item_number)
)
items = items_result.scalars().all()

# 3. Pour chaque item, charger les fiches + feedback existant (LEFT JOIN)
items_data = []
for item in items:
    cards_result = await db.execute(
        select(FlashCard, TesterFeedback)
        .outerjoin(TesterFeedback, TesterFeedback.flash_card_id == FlashCard.id)
        .where(FlashCard.item_id == item.id)
        .order_by(FlashCard.rang, FlashCard.created_at)
    )
    cards_rows = cards_result.all()  # liste de tuples (FlashCard, TesterFeedback|None)
    
    cards_data = []
    for card, feedback in cards_rows:
        fb_data = None
        if feedback is not None:
            fb_data = FeedbackData(
                is_pertinent=feedback.is_pertinent,
                tester_id=feedback.tester_id,
                created_at=feedback.created_at.isoformat(),
            )
        cards_data.append(FlashCardTesterData(
            card_id=str(card.id),
            card_type=card.card_type,
            rang=card.rang,
            recto=card.recto,
            verso=card.verso,
            low_confidence=card.low_confidence,
            ocr_confidence_score=card.ocr_confidence_score,
            feedback=fb_data,
        ))
    items_data.append(ItemTesterData(...))
```

**IMPORTANT** : Le LEFT JOIN `outerjoin(TesterFeedback, ...)` sans filtre sur `tester_id` retourne **tous** les feedbacks de tous les testers. C'est intentionnel — la vue montre si une fiche a déjà été évaluée (quel que soit le tester). Si plusieurs testers ont évalué la même fiche, le LEFT JOIN peut retourner plusieurs lignes. Pour Phase 0 (un seul tester), ce n'est pas un problème.

### Endpoint POST /v1/tester/flash-cards/{card_id}/feedback — Logique UPSERT

```python
@router.post("/flash-cards/{card_id}/feedback", response_model=FeedbackResponseWrapped)
async def submit_feedback(
    card_id: uuid.UUID,
    body: FeedbackRequest,
    tester_id: str = Depends(get_tester_user),
    db: AsyncSession = Depends(get_db),
) -> FeedbackResponseWrapped:
    # 1. Vérifier que la fiche existe
    card = await db.get(FlashCard, card_id)
    if card is None:
        raise HTTPException(status_code=404, detail={"code": "CARD_NOT_FOUND", "message": f"FlashCard {card_id} not found"})
    
    # 2. UPSERT — SELECT + INSERT ou UPDATE
    existing_result = await db.execute(
        select(TesterFeedback)
        .where(TesterFeedback.flash_card_id == card_id)
        .where(TesterFeedback.tester_id == tester_id)
    )
    feedback = existing_result.scalar_one_or_none()
    
    if feedback is None:
        feedback = TesterFeedback(
            flash_card_id=card_id,
            college_id=card.college_id,
            tester_id=tester_id,
            is_pertinent=body.is_pertinent,
        )
        db.add(feedback)
    else:
        feedback.is_pertinent = body.is_pertinent
    
    await db.commit()
    await db.refresh(feedback)
    
    return FeedbackResponseWrapped(data=FeedbackResponseData(
        feedback_id=str(feedback.id),
        card_id=str(feedback.flash_card_id),
        is_pertinent=feedback.is_pertinent,
        tester_id=feedback.tester_id,
        created_at=feedback.created_at.isoformat(),
    ))
```

### Endpoint GET /v1/tester/colleges/{college_id}/summary — Logique

Approche Python (plus portable que SQL agrégé complexe, Phase 0) :
```python
# 1. Vérifier college
# 2. Charger items
items = (await db.execute(select(Item).where(Item.college_id == college_id).order_by(Item.item_number))).scalars().all()

items_data = []
for item in items:
    # IDs des fiches de l'item
    card_ids = (await db.execute(select(FlashCard.id).where(FlashCard.item_id == item.id))).scalars().all()
    total = len(card_ids)
    
    if card_ids:
        feedbacks = (await db.execute(
            select(TesterFeedback)
            .where(TesterFeedback.flash_card_id.in_(card_ids))
        )).scalars().all()
        pertinent = sum(1 for f in feedbacks if f.is_pertinent)
        not_pertinent = sum(1 for f in feedbacks if not f.is_pertinent)
    else:
        pertinent, not_pertinent = 0, 0
    
    items_data.append(ItemSummaryData(
        item_id=str(item.id),
        item_number=item.item_number,
        rang=item.rang,
        total_cards=total,
        pertinent_count=pertinent,
        not_pertinent_count=not_pertinent,
        pending_count=total - (pertinent + not_pertinent),
    ))
```

### Extension admin — pertinence_stats dans get_college_stats

Ajouter APRÈS le calcul de `hash_shared`, AVANT le return :
```python
# Importer TesterFeedback en haut du fichier admin.py
from app.models.tester_feedback import TesterFeedback

# Dans get_college_stats() :
feedbacks_result = await db.execute(
    select(TesterFeedback, FlashCard.rang)
    .join(FlashCard, TesterFeedback.flash_card_id == FlashCard.id)
    .where(TesterFeedback.college_id == college_id)
)
fb_rows = feedbacks_result.all()  # (TesterFeedback, rang: str)

pertinence_stats = None
if fb_rows:
    by_rang: dict[str, dict[str, int]] = {}
    for fb, rang in fb_rows:
        if rang not in by_rang:
            by_rang[rang] = {"pertinent": 0, "not_pertinent": 0}
        if fb.is_pertinent:
            by_rang[rang]["pertinent"] += 1
        else:
            by_rang[rang]["not_pertinent"] += 1
    total_p = sum(v["pertinent"] for v in by_rang.values())
    total_np = sum(v["not_pertinent"] for v in by_rang.values())
    pertinence_stats = PertinenceStats(
        global_pertinent=total_p,
        global_not_pertinent=total_np,
        total_evaluated=total_p + total_np,
        by_rang={r: PertinenceByRang(**v) for r, v in by_rang.items()},
    )

return CollegeStatsResponseWrapped(
    data=CollegeStatsData(
        ...  # champs existants inchangés
        pertinence_stats=pertinence_stats,
    )
)
```

**Schémas à ajouter dans `schemas/admin.py`** (AVANT `CollegeStatsData`) :
```python
class PertinenceByRang(BaseModel):
    pertinent: int
    not_pertinent: int

class PertinenceStats(BaseModel):
    global_pertinent: int
    global_not_pertinent: int
    total_evaluated: int
    by_rang: dict[str, PertinenceByRang]
```

Et modifier `CollegeStatsData` :
```python
class CollegeStatsData(BaseModel):
    card_count_by_rang: dict[str, int]
    avg_ocr_confidence: float | None
    items_ocr_confidence: list[ItemOcrData]
    hash_shared: bool
    pertinence_stats: PertinenceStats | None = None  # ← AJOUT
```

### Configuration `main.py` — Ordre critique

```python
# app/main.py
from fastapi.staticfiles import StaticFiles  # NOUVEAU

from app.api.v1.tester import router as tester_router  # NOUVEAU

app.include_router(health_router)
app.include_router(admin_router, prefix="/v1/admin")
app.include_router(billing_router, prefix="/v1/webhooks")
app.include_router(tester_router, prefix="/v1/tester")  # NOUVEAU — avant StaticFiles
app.mount("/tester", StaticFiles(directory="app/static", html=True), name="tester-static")  # DERNIER
```

**Vérifier que `aiofiles` est dans `pyproject.toml`** — requis par `StaticFiles`. Si absent : `aiofiles = "^24.1.0"`.

### Interface HTML `app/static/index.html` — Comportement attendu

Page HTML + JavaScript vanilla (pas de framework) :
1. **Initialisation** : appel `GET /v1/tester/colleges` avec fetch (le navigateur déclenche la dialog Basic Auth native)
2. **Sélecteur collège** : `<select>` peuplé avec les collèges retournés (afficher `college_ref_id` + `card_count` + `feedback_count/card_count`)
3. **Chargement fiches** : au changement du sélecteur, appeler `GET /v1/tester/colleges/{id}/items`, flatter toutes les fiches en liste ordonnée
4. **Navigation fiche unique** : afficher `recto`, `verso` (caché par défaut, clic pour révéler), `rang` (badge coloré), badge rouge si `low_confidence: true`
5. **Boutons feedback** : "✓ Pertinente" (vert) + "✗ Non pertinente" (rouge) → POST + auto-advance
6. **Résumé** : bouton "Voir le résumé" → appel `GET /v1/tester/colleges/{id}/summary` + tableau

**Stockage des credentials** : pas de stockage custom — le navigateur gère Basic Auth nativement. Les credentials sont inclus dans chaque requête fetch via `headers: {"Authorization": "Basic " + btoa(user+":"+pass)}` après que l'utilisateur les a saisis dans la dialog native (ou on peut utiliser un formulaire HTML simple).

### Fichiers à Créer (NEW)

```
collega_backend/
├── alembic/versions/
│   └── 005_add_tester_feedbacks.py              ← NEW (Revises: 004)
├── app/
│   ├── models/
│   │   └── tester_feedback.py                   ← NEW
│   ├── schemas/
│   │   └── tester.py                            ← NEW
│   ├── api/v1/
│   │   └── tester.py                            ← NEW
│   └── static/
│       └── index.html                           ← NEW (interface web)
└── tests/api/
    ├── test_tester_colleges.py                  ← NEW
    ├── test_tester_items.py                     ← NEW
    ├── test_tester_feedback.py                  ← NEW
    └── test_tester_summary.py                   ← NEW
```

### Fichiers à Modifier (UPDATE)

| Fichier | Modification |
|---------|-------------|
| `app/core/config.py` | Ajouter `tester_username: str = "tester"` et `tester_password: str = "change-me"` |
| `app/deps.py` | Ajouter `_http_basic_tester`, `get_tester_user` (retourne `str`), export dans `__all__` |
| `app/main.py` | Inclure `tester_router` + monter `StaticFiles` (en dernier) |
| `app/models/__init__.py` | Importer `TesterFeedback`, ajouter à `__all__` |
| `app/schemas/admin.py` | Ajouter `PertinenceByRang`, `PertinenceStats`, étendre `CollegeStatsData` |
| `app/api/v1/admin.py` | Importer `TesterFeedback`, étendre `get_college_stats` |
| `tests/conftest.py` | Ajouter `TESTER_USERNAME` et `TESTER_PASSWORD` dans `os.environ.setdefault` |

### Apprentissages Stories 1.2–1.4 — À Appliquer Impérativement

1. **`types.SimpleNamespace`** pour les modèles dans les tests — jamais `Model.__new__(Model)`
2. **Mocker à l'import du module** : `patch("app.api.v1.tester.settings")`, pas `patch("app.core.config.settings")`
3. **Wrapper `{ "data": ... }` ou `{ "error": ... }`** sur toutes les réponses API — aucune exception
4. **`HTTPException(status_code=404, detail={"code": "...", "message": "..."})`** — pattern uniforme
5. **Jamais `print()`** — `logger.info/warning/error()` uniquement
6. **ISO 8601 UTC** pour toutes les dates — `.isoformat()` sur les datetime
7. **Auth dans les tests** : `TESTER_AUTH = ("tester", "testpass")` — conftest initialisé avec `TESTER_PASSWORD=testpass`
8. **`mock_db.execute` retourne `.all()` pour les tuples** (jointures LEFT JOIN) — utiliser `MagicMock(all=MagicMock(return_value=[...]))` pour les listes de tuples `(FlashCard, TesterFeedback|None)`
9. **`mock_db.execute` retourne `.scalar_one_or_none()`** pour les requêtes single-value
10. **`mock_db.execute` retourne `.scalars().all()`** pour les listes simples — chaîner les mocks : `MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[...]))))`
11. **`db.add` ne peuple pas l'id** — TesterFeedback doit avoir `default=uuid.uuid4` pour que l'objet ait un id avant `db.commit()`

### Pattern Tests — Exemple test_tester_feedback.py

```python
import types
import uuid
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock
import pytest

TESTER_AUTH = ("tester", "testpass")

def make_flash_card(card_id=None, college_id=None):
    return types.SimpleNamespace(
        id=card_id or uuid.uuid4(),
        college_id=college_id or uuid.uuid4(),
        item_id=uuid.uuid4(),
        rang="A",
        card_type="classique",
        recto="Question ?",
        verso="Réponse.",
        low_confidence=False,
        ocr_confidence_score=0.85,
    )

def make_feedback(card_id, is_pertinent=True):
    return types.SimpleNamespace(
        id=uuid.uuid4(),
        flash_card_id=card_id,
        college_id=uuid.uuid4(),
        tester_id="tester",
        is_pertinent=is_pertinent,
        created_at=datetime.now(timezone.utc),
    )

@pytest.mark.asyncio
async def test_submit_feedback_unauthorized(client):
    resp = await client.post("/v1/tester/flash-cards/some-id/feedback", json={"is_pertinent": True})
    assert resp.status_code == 401

@pytest.mark.asyncio
async def test_submit_feedback_card_not_found(client, mock_db):
    mock_db.get = AsyncMock(return_value=None)
    resp = await client.post(
        f"/v1/tester/flash-cards/{uuid.uuid4()}/feedback",
        json={"is_pertinent": True},
        auth=TESTER_AUTH,
    )
    assert resp.status_code == 404
    assert resp.json()["detail"]["code"] == "CARD_NOT_FOUND"

@pytest.mark.asyncio
async def test_submit_feedback_creates_new(client, mock_db):
    card_id = uuid.uuid4()
    card = make_flash_card(card_id=card_id)
    mock_db.get = AsyncMock(return_value=card)
    # SELECT existing → None (pas de feedback existant)
    mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None)))
    # db.refresh ne fait rien (le SimpleNamespace a déjà les bons champs)
    
    resp = await client.post(
        f"/v1/tester/flash-cards/{card_id}/feedback",
        json={"is_pertinent": True},
        auth=TESTER_AUTH,
    )
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["is_pertinent"] is True
    assert data["tester_id"] == "tester"
    mock_db.add.assert_called_once()
    mock_db.commit.assert_called_once()
```

**Note `db.refresh` dans les tests** : après `db.add(feedback)` + `db.commit()`, `db.refresh(feedback)` est appelé mais le mock ne modifie pas l'objet. Le `feedback` est le `TesterFeedback` instancié dans la route — il a déjà son `id` (via `default=uuid.uuid4`). L'assertion sur `data["feedback_id"]` sera un UUID valide.

### Schéma du test test_admin_college_stats.py — Extension

Le test existant `test_admin_college_stats.py` vérifie `card_count_by_rang`, `avg_ocr_confidence`, etc. Étendre pour couvrir `pertinence_stats` :

```python
# Cas "aucun feedback" → pertinence_stats doit être null
def test_college_stats_no_pertinence(client, mock_db):
    ...
    # mock_db.execute appelé 4 fois maintenant (cards, items, last_job, feedbacks)
    # Pour le 4ème appel (feedbacks), retourner liste vide
    # pertinence_stats doit être None dans la réponse

# Cas "avec feedbacks" → pertinence_stats rempli
def test_college_stats_with_pertinence(client, mock_db):
    ...
```

**Important** : `get_college_stats` fait maintenant 4 requêtes DB (pas 3). Les tests mockant `mock_db.execute` avec un seul side_effect doivent en avoir 4.

### References

- [Source: `_bmad-output/planning-artifacts/epics.md#Story-1.5`] — AC complets FR49–FR50
- [Source: `_bmad-output/planning-artifacts/architecture.md#Admin-Interface`] — "Routes FastAPI + HTML statique, Basic Auth"
- [Source: `_bmad-output/planning-artifacts/architecture.md#Authentication-Security`] — `secrets.compare_digest`, Basic Auth pattern
- [Source: `collega_backend/app/api/v1/admin.py`] — pattern routes, `get_admin_user`, HTTPException format
- [Source: `collega_backend/app/deps.py`] — pattern `get_admin_user` → à reproduire pour `get_tester_user` avec retour `str`
- [Source: `collega_backend/app/models/flash_card.py`] — FlashCard : `recto`, `verso`, `rang`, `card_type`, `low_confidence`, `ocr_confidence_score`, `college_id`
- [Source: `collega_backend/app/models/item.py`] — Item : `item_number`, `rang`, `chapter_title`, `college_id`
- [Source: `collega_backend/app/models/college.py`] — `CollegeStatus.generation_complete`, `college_ref_id`
- [Source: `collega_backend/app/schemas/admin.py`] — schémas existants Story 1.4 à préserver ; `CollegeStatsData` à étendre
- [Source: `collega_backend/app/core/config.py`] — Settings existants, pattern pydantic-settings
- [Source: `collega_backend/tests/conftest.py`] — `make_mock_db`, `client` fixture, pattern `os.environ.setdefault`
- [Source: `_bmad-output/implementation-artifacts/deferred-work.md`] — règle `models/__init__.py` : chaque nouveau modèle doit y être importé

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6 (create-story + dev-story)

### Completion Notes List

- Analyse exhaustive Stories 1.2–1.4, architecture, modèles existants (FlashCard, Item, College, GenerationJob), deps.py, conftest.py, deferred-work.md
- Story 1.5 construit sur l'infrastructure admin existante (Stories 1.2–1.4) — tous les patterns préservés
- Approche API-only + HTML statique (StaticFiles), cohérente avec la simplification Phase 0 de Story 1.4
- UPSERT feedback via SELECT + INSERT/UPDATE (portable SQLite/PostgreSQL, pas de dialect-specific)
- `get_tester_user` retourne `str` (pas `bool`) pour exposer `tester_id` sans double dépendance
- Extension `CollegeStatsData` avec `pertinence_stats: PertinenceStats | None = None` — backward compatible
- StaticFiles monté en DERNIER dans main.py (après tous les routeurs API) — ordre critique
- Régression test_admin_college_stats.py détectée et corrigée : `get_college_stats` fait 4 requêtes DB (ajout requête feedbacks), tous les tests mockaient 3 side_effects → réécriture complète avec helper `stats_side_effects()`
- 19 fichiers créés/modifiés, 134 tests passants, 1 skipped, 0 régression

## Change Log

| Date | Change |
|------|--------|
| 2026-04-30 | Story créée — analyse exhaustive Stories 1.2–1.4, modèles, deps, conftest, deferred-work |
| 2026-04-30 | Implémentation complète — 19 fichiers créés/modifiés, 134 tests passants (red-green-refactor) |

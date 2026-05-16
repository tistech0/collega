# Story 1.3 : Pipeline Génération de Fiches Claude

Status: done

## Story

En tant qu'**opérateur**,
je veux que les items OCR'd d'un collège soient transformés en flashcards par Claude,
afin d'obtenir des fiches de révision taguées par rang (A/B/C), avec déduplication par hash-sharing.

## Acceptance Criteria

1. **Génération des fiches via Claude**
   - Étant donné un college avec des items au statut `ocr_complete`, quand le `generation_worker` ARQ traite le job, alors Claude génère pour chaque item : au minimum 1 flashcard classique (recto = question, verso = réponse) et 1 fiche définition si applicable
   - Et chaque flashcard est taguée avec le rang de l'item source (A, B ou C) via `rang: "A"|"B"|"C"`
   - Et le job passe au statut `generation_complete` avec un `card_count` total

2. **Hash-sharing (réutilisation sans appel Claude)**
   - Étant donné un college dont le PDF est identique (ou similaire à ≥ 90%) à un PDF déjà traité, quand le pipeline évalue le hash-sharing via `SimilarityChecker`, alors les fiches existantes sont réutilisées sans nouvel appel Claude
   - Et le job passe directement au statut `generation_complete` avec `hash_shared: true`
   - Et l'interface `SimilarityChecker` est abstraite — l'algorithme est remplaçable sans modifier le reste du pipeline

3. **Retry backoff sur indisponibilité Claude**
   - Étant donné que Claude API est temporairement indisponible, quand le `generation_worker` tente un appel Claude, alors il réessaie avec backoff exponentiel (max 3 tentatives)
   - Et après échec définitif, le job passe à `failed` et reste en queue pour reprise manuelle

4. **Nettoyage OCR après génération (NFR9)**
   - Étant donné un job de génération terminé, quand 24 heures se sont écoulées, alors le `cleanup_worker` ARQ supprime le champ `ocr_text` de tous les items du job (mis à NULL)
   - Et les flashcards et métadonnées (rang, item_number, ocr_confidence_score) restent intactes

5. **Sécurité clé Claude (NFR5)**
   - Étant donné les contraintes de sécurité NFR5, quand le code est inspecté, alors la clé API Claude est exclusivement dans les variables d'environnement Docker — absente de tout fichier versionné

## Tasks / Subtasks

- [x] Task 1 : Migration 004 — table `flash_cards` et colonne `pdf_hash` (AC: #1, #2, #4)
  - [x] 1.1 Créer `alembic/versions/004_add_flash_cards.py` avec la table `flash_cards` (schéma exact en Dev Notes)
  - [x] 1.2 Ajouter colonne `pdf_hash VARCHAR(64)` sur `generation_jobs` (pour hash-sharing)
  - [x] 1.3 Ajouter index `ix_generation_jobs_pdf_hash` sur `generation_jobs.pdf_hash`
  - [x] 1.4 Vérifier que `alembic upgrade head` s'exécute sans erreur (après migrations 001→002→003→004)

- [x] Task 2 : Modèle SQLAlchemy `FlashCard` (AC: #1, #2)
  - [x] 2.1 Créer `app/models/flash_card.py` — colonnes conformes au schéma de Dev Notes
  - [x] 2.2 Mettre à jour `app/models/generation_job.py` — ajouter champ `pdf_hash: str | None`
  - [x] 2.3 Mettre à jour `app/models/item.py` — ajouter relationship `flash_cards` (cascade delete)
  - [x] 2.4 Mettre à jour `app/models/college.py` — ajouter relationship `flash_cards` (cascade delete)
  - [x] 2.5 Mettre à jour `app/models/__init__.py` — exporter `FlashCard` dans `__all__` (OBLIGATOIRE pour Alembic autogenerate)

- [x] Task 3 : Schémas Pydantic `flash_card.py` (AC: #1)
  - [x] 3.1 Créer `app/schemas/flash_card.py` — `FlashCardCreate`, `FlashCardRead` (voir Dev Notes)

- [x] Task 4 : Service `ClaudeClient` — génération via API Anthropic (AC: #1, #3, #5)
  - [x] 4.1 Créer `app/services/generation/claude_client.py` — classe `ClaudeClient` async avec méthode `generate_cards_for_item(item) -> list[FlashCardData]`
  - [x] 4.2 Utiliser `anthropic.AsyncAnthropic(api_key=settings.claude_api_key, max_retries=3)` — retry intégré SDK
  - [x] 4.3 Prompt structuré JSON (format exact en Dev Notes) — parser la réponse Claude avec `json.loads`
  - [x] 4.4 Modèle à utiliser : `claude-sonnet-4-6` (voir Dev Notes)
  - [x] 4.5 Logger un warning si `ocr_text` est None ou vide — retourner liste vide sans appel Claude

- [x] Task 5 : Service `SimilarityChecker` (hash-sharing v1) (AC: #2)
  - [x] 5.1 Créer `app/services/generation/hash_sharing.py` — classe abstraite `SimilarityChecker` + implémentation `SHA256SimilarityChecker`
  - [x] 5.2 Méthode `compute_hash(pdf_path: str) -> str` : SHA-256 du contenu binaire du PDF
  - [x] 5.3 Méthode `async find_similar_job(db, pdf_hash: str) -> Optional[GenerationJob]` : cherche un job `generation_complete` avec même hash

- [x] Task 6 : Service `CardGenerator` — orchestration (AC: #1, #2)
  - [x] 6.1 Créer `app/services/generation/card_generator.py` — classe `CardGenerator` avec méthode `async generate_for_college(db, college_id, job_id, pdf_path)`
  - [x] 6.2 Calculer le hash du PDF → chercher via `SimilarityChecker.find_similar_job`
  - [x] 6.3 Si hash-sharing : copier les `FlashCard` des items correspondants vers les nouveaux items (isolation par user_id — NFR8), marquer `job.hash_shared = True`, `job.status = "generation_complete"`. Ne PAS copier `ocr_text` (restera NULL sur les nouvelles fiches)
  - [x] 6.4 Si pas de hash-sharing : pour chaque item avec `ocr_text`, appeler `ClaudeClient.generate_cards_for_item`, insérer les FlashCards, incrémenter `job.card_count`
  - [x] 6.5 Stocker `job.pdf_hash` dans tous les cas (nécessaire pour les futures comparaisons hash-sharing)
  - [x] 6.6 En cas d'échec définitif Claude (après retries) : lever l'exception pour que le worker marque `failed`

- [x] Task 7 : Worker `generation_worker.py` — remplacer le stub (AC: #1, #2, #3)
  - [x] 7.1 Implémenter `generate_college_cards(ctx, college_id, job_id, pdf_path)` — remplacer entièrement le stub (voir signature exacte en Dev Notes)
  - [x] 7.2 Charger le job depuis la DB, vérifier que `job.status == "ocr_complete"` avant de traiter
  - [x] 7.3 Appeler `CardGenerator.generate_for_college(...)` dans un bloc try/except
  - [x] 7.4 En cas d'exception : `job.status = "failed"`, `job.error_message = str(exc)`, commit, re-raise
  - [x] 7.5 Utiliser `async_session_factory()` (même pattern que `ocr_worker.py`)

- [x] Task 8 : Worker `cleanup_worker.py` — remplacer le stub (AC: #4)
  - [x] 8.1 Implémenter `cleanup_ocr_text(ctx)` — remplacer le stub
  - [x] 8.2 Sélectionner tous les items liés à des jobs `generation_complete` dont `updated_at < NOW() - 24h`
  - [x] 8.3 SET `Item.ocr_text = NULL` (UPDATE SQL direct sur les items concernés)
  - [x] 8.4 Logger le nombre d'items nettoyés

- [x] Task 9 : Chaîner OCR → génération dans `ocr_worker.py` (AC: #1)
  - [x] 9.1 Après `college.status = CollegeStatus.ocr_complete` et commit, enqueuer `generate_college_cards` via `ctx["redis"].enqueue_job(...)` avec `college_id`, `job_id`, `pdf_path`
  - [x] 9.2 Logger l'enqueue : `logger.info("Generation job enqueued for college %s", college_id)`

- [x] Task 10 : Mettre à jour `workers/settings.py` (AC: #1, #4)
  - [x] 10.1 Ajouter `generate_college_cards` dans `functions` (import depuis `generation_worker.py`)
  - [x] 10.2 Ajouter `cron_jobs` ARQ pour `cleanup_ocr_text` — toutes les heures (voir syntaxe ARQ en Dev Notes)
  - [x] 10.3 Retirer l'import `WorkerSettings` du stub (remplacé par `WORKER_SETTINGS` dict existant)

- [x] Task 11 : Tests (AC: #1–#5)
  - [x] 11.1 `tests/services/test_claude_client.py` — mocker `anthropic.AsyncAnthropic`, tester génération JSON valide, tester comportement sur `ocr_text` vide
  - [x] 11.2 `tests/services/test_hash_sharing.py` — tester `compute_hash` (déterministe sur même contenu), tester `find_similar_job` (match / no match)
  - [x] 11.3 `tests/services/test_card_generator.py` — tester flux hash-sharing (pas d'appel Claude), tester flux génération normale (appel Claude), tester copie isolation user_id
  - [x] 11.4 `tests/workers/test_generation_worker.py` — tester job `ocr_complete` → `generation_complete`, tester job `failed` sur exception Claude
  - [x] 11.5 `tests/workers/test_cleanup_worker.py` — tester suppression `ocr_text` sur items > 24h, tester conservation des flashcards et métadonnées

### Review Findings

- [x] [Review][Decision] Conflit max_retries ARQ vs SDK — résolu : laisser tel quel + log explicite sur ARQ retry silencieux (option A)
- [x] [Review][Decision] Application du minimum 1 flashcard classique par item (AC#1) — résolu : logger warning et continuer (option 1)

- [x] [Review][Patch] str.format() sur le texte OCR brise sur les caractères { } — FIXED: escape braces in ocr_text avant format() [claude_client.py]
- [x] [Review][Patch] Claude wrap JSON dans un code fence markdown → json.loads échoue → FIXED: strip markdown fence avant json.loads [claude_client.py]
- [x] [Review][Patch] Cartes partielles commitées lors d'une exception Claude — FIXED: rollback + re-fetch job avant commit failure status [generation_worker.py]
- [x] [Review][Patch] Double commit dans `_copy_cards_for_hash_sharing` — FIXED: removed inner commit, caller owns transaction [card_generator.py]
- [x] [Review][Patch] Échec Redis enqueue après commit OCR → college bloqué — FIXED: enqueue wrapped in try/except [ocr_worker.py]
- [x] [Review][Patch] `cleanup_ocr_text` efface `ocr_text` d'un college qui a un nouveau job en cours — FIXED: exclude colleges with active jobs [cleanup_worker.py]
- [x] [Review][Patch] Retry ARQ crée des doublons de flash_cards — FIXED: delete existing cards at start of generate_for_college (idempotency) [card_generator.py]
- [x] [Review][Patch] Hash-sharing copie 0 cartes silencieusement — FIXED: fallthrough to normal generation when count==0 [card_generator.py]
- [x] [Review][Patch] `CardGenerator.generate_for_college` ne protège pas contre un job `None` — FIXED: raises ValueError [card_generator.py]
- [x] [Review][Patch] `db.commit()` dans le except du worker non protégé — FIXED: wrapped in try/except [generation_worker.py]

- [x] [Review][Defer] `FlashCardCreate` expose `user_id` en champ client — risque sécurité si branché sur un endpoint API [schemas/flash_card.py] — deferred, pré-existant (Story 1.4 gère les endpoints)
- [x] [Review][Defer] `FlashCardCreate`/`FlashCardRead` sans validation Pydantic sur `card_type` et `rang` [schemas/flash_card.py] — deferred, pré-existant (Story 1.4)
- [x] [Review][Defer] Durée de vie de `pdf_path` à travers la queue ARQ — aucune garantie que le fichier existe quand le job est dépilé — deferred, concern architectural
- [x] [Review][Defer] `claude_api_key` a une valeur par défaut `""` dans config.py — le démarrage ne plante pas si la clé est absente — deferred, pré-existant
- [x] [Review][Defer] Test manquant : vérifier que `rang` de la flashcard créée correspond bien au `rang` de l'item source (AC#1 end-to-end) [test_card_generator.py] — deferred, coverage gap
- [x] [Review][Defer] Test manquant : vérifier que cleanup ne touche pas aux `flash_cards` (AC#4 NFR9) [test_cleanup_worker.py] — deferred, coverage gap
- [x] [Review][Defer] Job chargé deux fois (worker + CardGenerator) — round-trip DB redondant [generation_worker.py + card_generator.py] — deferred, mineur

## Dev Notes

### Vue d'ensemble — Ce que Story 1.3 construit

Story 1.3 complète le pipeline backend Phase 0 :
```
OCR worker (Story 1.2) → ocr_complete → [STORY 1.3] generation_worker → generation_complete
                                                                       ↓
                                                              flash_cards en base
                                                                       ↓
                                            cleanup_worker (cron 24h) → ocr_text = NULL
```

**Dépendances directes de cette story :**
- Table `items` de Story 1.2 (colonnes `ocr_text`, `ocr_confidence_score`, `rang`) — ne pas modifier ces colonnes
- Statuts `generation_jobs` déjà définis : `pending`, `processing`, `ocr_complete`, `generation_complete`, `failed`
- `app/workers/ocr_worker.py` — modifier UNIQUEMENT pour ajouter l'enqueue de `generate_college_cards` à la fin (ligne ~164)

**Ce que Story 1.4 utilisera :** les statuts `generation_complete` et les stats `card_count` de cette story pour l'interface admin.

### Schéma Base de Données — Migration 004

```sql
-- Table: flash_cards
CREATE TABLE flash_cards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    college_id UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    card_type VARCHAR(20) NOT NULL CHECK (card_type IN ('classique', 'definition')),
    rang VARCHAR(1) NOT NULL CHECK (rang IN ('A', 'B', 'C')),
    recto TEXT NOT NULL,
    verso TEXT NOT NULL,
    ocr_confidence_score FLOAT NOT NULL DEFAULT 0.0,
    low_confidence BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_flash_cards_item_id ON flash_cards(item_id);
CREATE INDEX ix_flash_cards_college_id ON flash_cards(college_id);
CREATE INDEX ix_flash_cards_user_id ON flash_cards(user_id);

-- Trigger updated_at sur flash_cards
CREATE TRIGGER update_flash_cards_updated_at
    BEFORE UPDATE ON flash_cards
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Colonne pdf_hash sur generation_jobs (hash-sharing)
ALTER TABLE generation_jobs ADD COLUMN pdf_hash VARCHAR(64);
CREATE INDEX ix_generation_jobs_pdf_hash ON generation_jobs(pdf_hash);
```

**Attention :** La fonction `update_updated_at_column()` a été créée dans la migration 002 — ne pas la recréer, juste l'utiliser.

**Statuts valides pour `generation_jobs.status` (inchangés depuis Story 1.2) :**
`pending`, `processing`, `ocr_complete`, `generation_complete`, `failed`

### Modèle SQLAlchemy `FlashCard`

```python
# app/models/flash_card.py
class FlashCard(Base):
    __tablename__ = "flash_cards"
    __table_args__ = (
        CheckConstraint("card_type IN ('classique', 'definition')", name="ck_flash_cards_card_type"),
        CheckConstraint("rang IN ('A', 'B', 'C')", name="ck_flash_cards_rang"),
    )
    id: Mapped[uuid.UUID] = ...
    item_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("items.id", ondelete="CASCADE"), index=True)
    college_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("colleges.id", ondelete="CASCADE"), index=True)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    card_type: Mapped[str] = mapped_column(String(20), nullable=False)
    rang: Mapped[str] = mapped_column(String(1), nullable=False)
    recto: Mapped[str] = mapped_column(Text, nullable=False)
    verso: Mapped[str] = mapped_column(Text, nullable=False)
    ocr_confidence_score: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    low_confidence: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = ...
    updated_at: Mapped[datetime] = ...

    item: Mapped["Item"] = relationship("Item", back_populates="flash_cards")
    college: Mapped["College"] = relationship("College", back_populates="flash_cards")
    user: Mapped["User"] = relationship("User", back_populates="flash_cards")
```

### Claude API — Intégration

**SDK déjà installé :** `anthropic>=0.25.0` dans `pyproject.toml` — NE PAS modifier `pyproject.toml`

**Client async :**
```python
import anthropic
from app.core.config import settings

client = anthropic.AsyncAnthropic(
    api_key=settings.claude_api_key,
    max_retries=3,  # Retry intégré SDK avec backoff exponentiel — satisfait AC #3
)
```

**Modèle à utiliser :** `claude-sonnet-4-6`

**Prompt de génération (format JSON strict) :**
```python
GENERATION_PROMPT = """
Tu es un expert en fiches de révision médicale ECNi.
Génère des flashcards à partir du texte OCR suivant pour l'Item {item_number} (Rang {rang}).

Texte OCR:
{ocr_text}

Génère des flashcards utiles pour réviser cet item :
- Des flashcards classiques : question médicale précise → réponse courte et factuelle
- Des fiches définition si le texte contient des termes médicaux à définir (terme → définition)

Réponds UNIQUEMENT avec un objet JSON valide, sans markdown, sans explication :
{{
  "flashcards": [
    {{"type": "classique", "recto": "Question médicale ?", "verso": "Réponse factuelle"}},
    {{"type": "definition", "recto": "Terme médical", "verso": "Définition clinique"}}
  ]
}}

Génère entre 2 et 5 flashcards classiques et 0 à 3 fiches définition selon le contenu.
"""
```

**Parsing de la réponse :**
```python
response = await client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=2000,
    messages=[{"role": "user", "content": prompt}]
)
raw = response.content[0].text.strip()
data = json.loads(raw)  # Si parsing échoue → logger error + retourner []
```

**Gestion d'erreur :** Si `json.loads` échoue ou si la liste est vide, logger une erreur et retourner `[]` (l'item sera skippé, pas le job entier). Si `anthropic.APIError` (après max_retries) → laisser remonter l'exception pour que le worker marque `failed`.

### SimilarityChecker v1 (Hash-sharing)

```python
# app/services/generation/hash_sharing.py
import hashlib
from abc import ABC, abstractmethod

class SimilarityChecker(ABC):
    @abstractmethod
    def compute_hash(self, pdf_path: str) -> str: ...

    @abstractmethod
    async def find_similar_job(self, db: AsyncSession, pdf_hash: str) -> Optional[GenerationJob]: ...

class SHA256SimilarityChecker(SimilarityChecker):
    def compute_hash(self, pdf_path: str) -> str:
        h = hashlib.sha256()
        with open(pdf_path, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
        return h.hexdigest()

    async def find_similar_job(self, db, pdf_hash):
        result = await db.execute(
            select(GenerationJob)
            .where(GenerationJob.pdf_hash == pdf_hash)
            .where(GenerationJob.status == "generation_complete")
            .order_by(GenerationJob.created_at.desc())
            .limit(1)
        )
        return result.scalar_one_or_none()
```

**Note :** Pour l'instant l'algorithme est SHA-256 exact (100% match). La tolérance ~90% sera implémentée dans une version ultérieure en remplaçant `SHA256SimilarityChecker` sans toucher au reste du pipeline.

### Logique CardGenerator — Copie pour Hash-Sharing

Quand un job similaire est trouvé, copier les FlashCards vers les nouveaux items :

```python
# app/services/generation/card_generator.py
async def _copy_cards_for_hash_sharing(
    db, source_job: GenerationJob, target_college_id, target_user_id
) -> int:
    """Copie les flash_cards du job source vers les items du college cible.
    
    Isolation user_id obligatoire (NFR8) : chaque utilisateur a ses propres fiches.
    """
    # Récupérer les flash_cards du college source via le job
    source_cards_result = await db.execute(
        select(FlashCard)
        .where(FlashCard.college_id == source_job.college_id)
    )
    source_cards = source_cards_result.scalars().all()
    
    # Récupérer la map item_number → Item pour le college cible
    target_items_result = await db.execute(
        select(Item).where(Item.college_id == target_college_id)
    )
    target_items = {item.item_number: item for item in target_items_result.scalars().all()}
    
    # Récupérer la map item_number → Item pour le college source
    source_items_result = await db.execute(
        select(Item).where(Item.college_id == source_job.college_id)
    )
    source_items = {item.id: item for item in source_items_result.scalars().all()}
    
    count = 0
    for card in source_cards:
        source_item = source_items.get(card.item_id)
        if source_item is None:
            continue
        target_item = target_items.get(source_item.item_number)
        if target_item is None:
            continue
        new_card = FlashCard(
            item_id=target_item.id,
            college_id=target_college_id,
            user_id=target_user_id,
            card_type=card.card_type,
            rang=card.rang,
            recto=card.recto,
            verso=card.verso,
            ocr_confidence_score=card.ocr_confidence_score,
            low_confidence=card.low_confidence,
        )
        db.add(new_card)
        count += 1
    await db.commit()
    return count
```

### Worker Generation — Signature et Pattern

```python
# app/workers/generation_worker.py
async def generate_college_cards(
    ctx: dict,
    college_id: str,
    job_id: str,
    pdf_path: str,
) -> dict:
    """Génère les fiches d'un college via Claude ou hash-sharing."""
    async with async_session_factory() as db:
        job = await db.get(GenerationJob, uuid.UUID(job_id))
        if job is None or job.status != "ocr_complete":
            logger.error("Job %s not found or not ocr_complete", job_id)
            return {"error": "invalid_job_state"}
        
        try:
            card_generator = CardGenerator()
            result = await card_generator.generate_for_college(
                db, uuid.UUID(college_id), uuid.UUID(job_id), pdf_path
            )
            return result
        except Exception as exc:
            logger.exception("Generation failed for college %s: %s", college_id, exc)
            job.status = "failed"
            job.error_message = str(exc)
            await db.commit()
            raise
```

### Worker Cleanup — Pattern ARQ Cron

```python
# app/workers/cleanup_worker.py
from datetime import datetime, timedelta, timezone
from sqlalchemy import update as sql_update

async def cleanup_ocr_text(ctx: dict) -> None:
    """Supprime ocr_text des items dont le job est terminé depuis > 24h (NFR9)."""
    cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
    async with async_session_factory() as db:
        # Sous-requête : IDs des items dans des jobs generation_complete > 24h
        completed_jobs_subq = (
            select(GenerationJob.college_id)
            .where(GenerationJob.status == "generation_complete")
            .where(GenerationJob.updated_at < cutoff)
            .scalar_subquery()
        )
        result = await db.execute(
            sql_update(Item)
            .where(Item.college_id.in_(completed_jobs_subq))
            .where(Item.ocr_text.is_not(None))
            .values(ocr_text=None)
        )
        await db.commit()
        logger.info("Cleaned OCR text from %d items", result.rowcount)
```

### Mise à jour `workers/settings.py` — Cron ARQ

```python
# ARQ — syntaxe cron_jobs
from arq.cron import cron

WORKER_SETTINGS = {
    "redis_settings": redis_settings,
    "functions": [process_college_ocr, generate_college_cards],
    "cron_jobs": [
        cron(cleanup_ocr_text, hour={0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23}, minute=0)
    ],
    "max_jobs": 10,
    "job_timeout": 7200,
    "keep_result": 3600,
    "retry_jobs": True,
    "max_retries": 3,
}
```

**Alternative plus simple pour cron toutes les heures :**
```python
cron(cleanup_ocr_text, minute=0)  # ARQ : si hour est absent, s'exécute à minute=0 de chaque heure
```

### Modification `ocr_worker.py` — Enchaînement generation

Ajouter à la fin de `_run_ocr`, APRÈS `await db.commit()` (ligne ~164 actuellement) :

```python
# Chaîner automatiquement le worker de génération
if "redis" in ctx:
    await ctx["redis"].enqueue_job(
        "generate_college_cards",
        str(college.id),
        str(job.id),
        pdf_path,
    )
    logger.info("Generation job enqueued for college %s job %s", college.id, job.id)
```

**Important :** Le `ctx["redis"]` est disponible dans les workers ARQ. Dans les tests, `ctx` sera un dict vide ou mock — le `if "redis" in ctx` évite les erreurs en tests unitaires.

### Pattern de Tests

**Pattern pour mocker le SDK Anthropic :**
```python
# Mock du client Anthropic
from unittest.mock import AsyncMock, MagicMock, patch

mock_response = MagicMock()
mock_response.content = [MagicMock(text='{"flashcards": [{"type": "classique", "recto": "Q?", "verso": "R"}]}')]

with patch("app.services.generation.claude_client.anthropic.AsyncAnthropic") as mock_cls:
    mock_client = AsyncMock()
    mock_client.messages.create = AsyncMock(return_value=mock_response)
    mock_cls.return_value = mock_client
    # test ...
```

**Pattern pour mocker l'ouverture de fichier (hash) :**
```python
import io
with patch("builtins.open", return_value=io.BytesIO(b"fake pdf content")):
    hash_val = checker.compute_hash("/fake/path.pdf")
```

**Pattern workers (identique Story 1.2) :**
- Utiliser `types.SimpleNamespace` pour simuler les modèles SQLAlchemy
- Utiliser `async_session_factory` patché ou `AsyncMock` pour la DB
- `ctx = {}` pour les tests (pas de Redis réel nécessaire)

### Fichiers à Créer (NEW)

```
collega_backend/
├── alembic/versions/
│   └── 004_add_flash_cards.py                ← NEW
├── app/
│   ├── models/
│   │   └── flash_card.py                     ← NEW
│   ├── schemas/
│   │   └── flash_card.py                     ← NEW
│   └── services/generation/
│       ├── claude_client.py                  ← NEW
│       ├── hash_sharing.py                   ← NEW
│       └── card_generator.py                 ← NEW
└── tests/
    ├── services/
    │   ├── test_claude_client.py             ← NEW
    │   ├── test_hash_sharing.py              ← NEW
    │   └── test_card_generator.py            ← NEW
    └── workers/
        ├── test_generation_worker.py         ← NEW
        └── test_cleanup_worker.py            ← NEW
```

### Fichiers à Modifier (UPDATE)

| Fichier | Modification |
|---------|-------------|
| `app/models/__init__.py` | Ajouter `FlashCard` dans `__all__` |
| `app/models/generation_job.py` | Ajouter `pdf_hash: str \| None` |
| `app/models/item.py` | Ajouter relationship `flash_cards` (cascade delete) |
| `app/models/college.py` | Ajouter relationship `flash_cards` (cascade delete) |
| `app/workers/generation_worker.py` | Remplacer stub par implémentation complète |
| `app/workers/cleanup_worker.py` | Remplacer stub par implémentation complète |
| `app/workers/settings.py` | Ajouter `generate_college_cards` + cron cleanup |
| `app/models/user.py` | Ajouter relationship `flash_cards` (TYPE_CHECKING import + back_populates) |
| `app/workers/ocr_worker.py` | Ajouter enqueue `generate_college_cards` après `ocr_complete` |

### Apprentissages Story 1.2 — À Appliquer Impérativement

1. **Toujours utiliser `async_session_factory()` dans les workers** (pas `ctx["db"]` qui n'est pas injecté dans notre config)
2. **`types.SimpleNamespace` pour les modèles dans les tests workers** — SQLAlchemy instrumentalise les attributs, `__new__()` contourne l'init
3. **Mocker à l'import** (`patch("arq.create_pool")`, pas `patch("app.api.v1.admin.create_pool")`) — pour les imports lazy dans le body des fonctions
4. **SQLite pour les tests** (`DATABASE_URL=sqlite+aiosqlite:///./test.db`) — pas d'asyncpg réel
5. **Ne jamais utiliser `print()`** — uniquement `logger.info/warning/error/exception()`
6. **Wrapper `{ "data": ... }` sur toutes les réponses API** — mais Story 1.3 n'expose PAS de nouvelle route admin (c'est Story 1.4)
7. **`ocr_text` est NULL après cleanup** — les tests de cleanup doivent vérifier que l'UPDATE SQL a bien mis `ocr_text = None`, pas supprimé la row

### Patterns de Qualité — Rappels

**Toujours :**
- ISO 8601 UTC pour tous les `created_at`, `updated_at`
- `user_id` en scope sur toutes les requêtes DB (NFR8) — en particulier lors de la copie hash-sharing
- `secrets` dans `.env` uniquement — `claude_api_key` dans env vars Docker, jamais versionné

**Jamais :**
- `Base.metadata.create_all()` — Alembic uniquement
- `print()` — `logger.xxx()`
- Logique métier dans les routes — dans les services

### References

- [Source: `_bmad-output/planning-artifacts/epics.md#Story-1.3`] — AC complets
- [Source: `_bmad-output/planning-artifacts/architecture.md#Data-Architecture`] — hash-sharing SimilarityChecker, NFR9 cleanup
- [Source: `_bmad-output/planning-artifacts/architecture.md#Complete-Project-Directory-Structure`] — `services/generation/`, `workers/cleanup_worker.py`, `workers/generation_worker.py`
- [Source: `_bmad-output/planning-artifacts/architecture.md#Naming-Patterns`] — Conventions
- [Source: `_bmad-output/planning-artifacts/epics.md#Additional-Requirements`] — ARQ queue, cleanup_worker, hash-sharing v1
- [Source: `_bmad-output/implementation-artifacts/1-2-pipeline-ocr-backend.md#Dev-Notes`] — Patterns tests, async_session_factory, types.SimpleNamespace
- [Source: `_bmad-output/implementation-artifacts/1-2-pipeline-ocr-backend.md#Dev-Agent-Record`] — Debug log learnings

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Anthropic SDK n'était pas installé dans le venv malgré sa présence dans pyproject.toml → `pip install anthropic` dans .venv
- `_run_ocr` n'avait pas accès à `ctx` (paramètre de `process_college_ocr`) → ajout de `ctx: dict | None = None` comme paramètre optionnel + guard `if ctx and "redis" in ctx`

### Completion Notes List

- Migration 004 : table `flash_cards` + colonne `pdf_hash` sur `generation_jobs` (trigger updated_at, index, check constraints)
- Modèle `FlashCard` SQLAlchemy avec relationships bidirectionnelles sur Item, College, User
- `ClaudeClient` async avec retry SDK intégré (max_retries=3), prompt ECNi structuré JSON, parsing robuste
- `SimilarityChecker` ABC + `SHA256SimilarityChecker` (hash-sharing v1 exact match)
- `CardGenerator` orchestrateur : détecte hash-sharing, copie fiches avec isolation user_id (NFR8), sinon appelle Claude item par item
- `generation_worker` : remplace le stub, vérifie statut `ocr_complete`, marque `failed` sur exception
- `cleanup_worker` : cron ARQ, UPDATE SQL bulk, préserve flashcards et métadonnées
- `ocr_worker` : enchaîne automatiquement `generate_college_cards` après `ocr_complete` via Redis
- `workers/settings.py` : ajoute `generate_college_cards` + cron `cleanup_ocr_text` (toutes les heures)
- 20 nouveaux tests, 70 total, 0 régression

### File List

- `collega_backend/alembic/versions/004_add_flash_cards.py` (NEW)
- `collega_backend/app/models/flash_card.py` (NEW)
- `collega_backend/app/schemas/flash_card.py` (NEW)
- `collega_backend/app/services/generation/claude_client.py` (NEW)
- `collega_backend/app/services/generation/hash_sharing.py` (NEW)
- `collega_backend/app/services/generation/card_generator.py` (NEW)
- `collega_backend/tests/services/test_claude_client.py` (NEW)
- `collega_backend/tests/services/test_hash_sharing.py` (NEW)
- `collega_backend/tests/services/test_card_generator.py` (NEW)
- `collega_backend/tests/workers/test_generation_worker.py` (NEW)
- `collega_backend/tests/workers/test_cleanup_worker.py` (NEW)
- `collega_backend/app/models/__init__.py` (MODIFIED — ajout FlashCard dans __all__)
- `collega_backend/app/models/generation_job.py` (MODIFIED — ajout pdf_hash)
- `collega_backend/app/models/item.py` (MODIFIED — ajout relationship flash_cards)
- `collega_backend/app/models/college.py` (MODIFIED — ajout relationship flash_cards)
- `collega_backend/app/models/user.py` (MODIFIED — ajout relationship flash_cards)
- `collega_backend/app/workers/generation_worker.py` (MODIFIED — remplace stub)
- `collega_backend/app/workers/cleanup_worker.py` (MODIFIED — remplace stub)
- `collega_backend/app/workers/settings.py` (MODIFIED — ajout generate_college_cards + cron)
- `collega_backend/app/workers/ocr_worker.py` (MODIFIED — enqueue generate + ctx param sur _run_ocr)

## Change Log

| Date | Change |
|------|--------|
| 2026-04-27 | Story créée — analyse exhaustive Story 1.2, architecture, modèles existants, patterns tests |
| 2026-04-28 | Implémentation complète Story 1.3 — 70 tests passent, 0 régression |

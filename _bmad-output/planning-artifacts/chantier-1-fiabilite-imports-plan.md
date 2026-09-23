# Chantier 1 — Fiabilité des imports : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un import ou réimport ne perd jamais de contenu, ne régénère que les items modifiés, ne repaie jamais Claude pour un item déjà généré, et ne bloque jamais un collège.

**Architecture:** Stockage de contenu adressé par empreinte (`ocr_pages`, `item_texts`, `item_generations`), brouillon par job (`job_pages`, `job_items`) et bascule en une transaction verrouillée vers `items`/`flash_cards`. Statut du collège = contenu ; statut du job = import.

**Tech Stack:** FastAPI, SQLAlchemy 2 async + asyncpg, Postgres 16, Alembic, ARQ, pytest + pytest-asyncio ; Flutter/Riverpod pour le petit changement app.

**Spec:** `_bmad-output/planning-artifacts/chantier-1-fiabilite-imports-spec.md` (lire en entier avant de commencer).

## Global Constraints

- Branche : `feat/chantier-1-fiabilite-imports`. Répertoire backend : `collega_backend/`, venv `collega_backend/.venv` (Python 3.14 local, image 3.11 : pas de syntaxe > 3.11).
- Tests backend : `.venv/bin/python -m pytest -q` depuis `collega_backend/`. Les tests marqués `pg` exigent le Postgres de test (Task 1) ; ils **échouent** (pas de skip) s'il n'est pas lancé.
- Format d'erreur API : `{"detail": {"code": "...", "message": "..."}}` ; réponses `{"data": ...}`.
- Messages utilisateur en français, tutoiement, apostrophe typographique `’` côté app.
- Empreintes : SHA-256 hexadécimal (64 caractères).
- `GENERATION_VERSION = "claude-sonnet-4-6:p1"` (modèle `claude-sonnet-4-6`, prompt v1).
- Seuil jobs bloqués : 30 min sans progression ; cron toutes les 10 min.
- Aucun appel réseau réel à Claude ou APNs dans les tests.
- Commits : messages en français, préfixes `feat(chantier-1)`, `test(chantier-1)`, etc., terminés par `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

## File Structure

Backend — créés :
- `collega_backend/docker-compose.test.yml` — Postgres de test (`127.0.0.1:55432`).
- `collega_backend/tests/pg.py` — fixtures `pg_engine`, `pg_session`, `pg_factory` (schéma par `alembic upgrade head`).
- `collega_backend/app/services/content/__init__.py`, `fingerprint.py` (empreintes, normalisation), `store.py` (accès aux tables de contenu).
- `collega_backend/app/models/content.py` — `OcrPage`, `ItemText`, `ItemGeneration`, `JobPage`, `JobItem`, `CollegePage`.
- `collega_backend/alembic/versions/018_content_store.py`.
- `collega_backend/app/services/jobs/job_failure.py` — `fail_job`.
- `collega_backend/app/services/generation/pipeline.py` — `generate_job_items`.
- `collega_backend/app/services/generation/publish.py` — `publish_job`, `ImportSummary`.
- `collega_backend/app/services/content/purge.py` — `purge_unreferenced_content`, `delete_college_pdfs`, `purge_orphan_pdfs`.
- `collega_backend/app/services/ocr/pdf_check.py` — `assert_pdf_readable`.
- `collega_backend/app/workers/maintenance_worker.py` — crons `fail_stale_jobs`, `purge_content`.
- `collega_backend/scripts/backfill_content_store.py`.
- Tests : `tests/services/content/test_fingerprint.py`, `tests/services/content/test_store.py`, `tests/db/test_schema_alignment.py`, `tests/services/test_job_failure.py`, `tests/workers/test_ocr_pipeline.py`, `tests/services/test_publish.py`, `tests/services/test_generation_pipeline.py`, `tests/services/content/test_purge.py`, `tests/workers/test_maintenance_worker.py`, `tests/api/test_import_status_contract.py`, `tests/api/test_pdf_damaged.py`, `tests/scripts/test_backfill_content_store.py`, `tests/services/test_notification_messages.py`.

Backend — modifiés : `app/models/{item,flash_card,generation_job,college,__init__}.py`, `app/services/generation/claude_client.py`, `app/workers/{ocr_worker,generation_worker,settings,cleanup_worker}.py`, `app/api/v1/{colleges,admin,auth,flash_cards}.py`, `app/schemas/{college,item}.py`, `app/services/notifications/apns_service.py`, `app/core/limiter.py`, `tests/conftest.py`, tests existants devenus obsolètes (listés par tâche).

Backend — supprimés : `app/services/generation/card_generator.py` (remplacé par `pipeline.py` + `publish.py`), `app/services/generation/hash_sharing.py`, leurs tests (`tests/services/test_card_generator.py`, `tests/services/test_hash_sharing.py` s'il existe, `tests/services/test_token_usage_capture.py` réécrit dans `test_generation_pipeline.py`).

App — modifiés : `collega_app/lib/features/colleges/domain/import_models.dart`, `colleges_import_providers.dart`, `domain/import_messages.dart`, `presentation/import_progress_screen.dart` ; tests associés.

Docs : `_bmad-output/planning-artifacts/architecture.md`, `collega_app/assets/legal/privacy.md`, `collega_backend/docs/restore.md`, `collega_backend/docs/testing.md` (créé).

---

### Task 1: Postgres de test et tests indépendants de Redis

**Files:**
- Create: `collega_backend/docker-compose.test.yml`, `collega_backend/tests/pg.py`, `collega_backend/docs/testing.md`
- Modify: `collega_backend/tests/conftest.py`, `collega_backend/pyproject.toml` (marqueur `pg`)
- Test: `collega_backend/tests/db/test_pg_fixture.py`

**Interfaces:**
- Produces: fixtures `pg_engine` (AsyncEngine, schéma migré à `head`), `pg_session` (AsyncSession), `pg_factory` (async_sessionmaker lié au même engine). Marqueur `@pytest.mark.pg`. Variable `TEST_PG_URL` (défaut `postgresql+asyncpg://postgres:postgres@127.0.0.1:55432/collega_test`).

- [ ] **Step 1: Postgres de test**

`collega_backend/docker-compose.test.yml` :
```yaml
# Postgres jetable pour les tests « pg » : docker compose -f docker-compose.test.yml up -d
services:
  postgres-test:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: collega_test
    ports:
      - "127.0.0.1:55432:5432"
    tmpfs:
      - /var/lib/postgresql/data
```
Run: `cd collega_backend && docker compose -f docker-compose.test.yml up -d` — Expected: conteneur `postgres-test` démarré.

- [ ] **Step 2: Test de la fixture (doit échouer : fixture absente)**

`collega_backend/tests/db/__init__.py` vide ; `collega_backend/tests/db/test_pg_fixture.py` :
```python
import pytest
from sqlalchemy import text

from tests.pg import pg_engine, pg_factory, pg_session  # noqa: F401

pytestmark = pytest.mark.pg


async def test_schema_is_migrated_to_head(pg_session):
    version = (await pg_session.execute(text("select version_num from alembic_version"))).scalar_one()
    assert version == "017"
```
Run: `.venv/bin/python -m pytest tests/db/test_pg_fixture.py -q` — Expected: FAIL (`ModuleNotFoundError: tests.pg`).

- [ ] **Step 3: Fixtures**

`collega_backend/tests/pg.py` :
```python
"""Postgres réel pour les tests du pipeline d'import (chantier 1).

Lancer d'abord : docker compose -f docker-compose.test.yml up -d
Chaque test part d'un schéma neuf migré par Alembic (`upgrade head`), donc les
index et contraintes réels (index unique partiel, FK, cascades) sont en place.
"""
from __future__ import annotations

import os
from collections.abc import AsyncIterator

import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine

TEST_PG_URL = os.environ.get(
    "TEST_PG_URL", "postgresql+asyncpg://postgres:postgres@127.0.0.1:55432/collega_test"
)
_BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _alembic_upgrade(url: str, revision: str = "head") -> None:
    cfg = Config(os.path.join(_BACKEND_DIR, "alembic.ini"))
    cfg.set_main_option("script_location", os.path.join(_BACKEND_DIR, "alembic"))
    cfg.attributes["test_url"] = url
    command.upgrade(cfg, revision)


@pytest.fixture
async def pg_engine() -> AsyncIterator[AsyncEngine]:
    engine = create_async_engine(TEST_PG_URL)
    try:
        async with engine.begin() as conn:
            await conn.execute(text("DROP SCHEMA public CASCADE"))
            await conn.execute(text("CREATE SCHEMA public"))
    except OSError as exc:  # connexion refusée
        pytest.fail(
            f"Postgres de test injoignable ({exc}). Lancer : "
            "docker compose -f docker-compose.test.yml up -d"
        )
    await engine.dispose()
    import asyncio

    await asyncio.to_thread(_alembic_upgrade, TEST_PG_URL)
    engine = create_async_engine(TEST_PG_URL)
    yield engine
    await engine.dispose()


@pytest.fixture
def pg_factory(pg_engine) -> async_sessionmaker[AsyncSession]:
    return async_sessionmaker(pg_engine, class_=AsyncSession, expire_on_commit=False)


@pytest.fixture
async def pg_session(pg_factory) -> AsyncIterator[AsyncSession]:
    async with pg_factory() as session:
        yield session
```

`collega_backend/alembic/env.py` : lire l'URL de test si fournie. Remplacer
```python
config.set_main_option("sqlalchemy.url", settings.database_url)
```
par
```python
config.set_main_option("sqlalchemy.url", config.attributes.get("test_url") or settings.database_url)
```
et, dans `run_migrations_online` (la fonction qui appelle `asyncio.run(run_async_migrations())`), rien d'autre à changer. `fileConfig` : l'entourer de `if config.config_file_name is not None and "test_url" not in config.attributes:` pour ne pas écraser la config de logs de pytest.

`collega_backend/pyproject.toml`, section `[tool.pytest.ini_options]` (la créer si absente, en conservant `asyncio_mode` existant) : ajouter
```toml
markers = ["pg: nécessite le Postgres de test (docker-compose.test.yml)"]
```

- [ ] **Step 4: Limiteur en mémoire pendant les tests**

`collega_backend/app/core/limiter.py` : remplacer la construction du `Limiter` par
```python
limiter = Limiter(
    key_func=get_client_ip,
    storage_uri=settings.rate_limit_storage_uri or settings.redis_url,
)
```
`collega_backend/app/core/config.py`, dans `Settings` après `redis_url` :
```python
    # Tests : "memory://" (compteurs par processus, plus de Redis local requis).
    rate_limit_storage_uri: str = ""
```
`collega_backend/tests/conftest.py`, avec les autres `os.environ.setdefault` en tête :
```python
os.environ.setdefault("RATE_LIMIT_STORAGE_URI", "memory://")
```
et une fixture autouse :
```python
@pytest.fixture(autouse=True)
def _reset_rate_limits():
    from app.core.limiter import limiter

    limiter.reset()
    yield
```

- [ ] **Step 5: Vérifier**

Run: `.venv/bin/python -m pytest tests/db/test_pg_fixture.py -q` — Expected: PASS.
Run deux fois de suite : `.venv/bin/python -m pytest -q` — Expected : les deux passes vertes (plus de `429 == 200`).
Run (Postgres arrêté : `docker compose -f docker-compose.test.yml stop`) : `.venv/bin/python -m pytest tests/db -q` — Expected: FAIL avec « Postgres de test injoignable ». Relancer le conteneur.

- [ ] **Step 6: Doc et commit**

`collega_backend/docs/testing.md` :
```markdown
# Tests backend

- Unitaires et API : `.venv/bin/python -m pytest -q` (SQLite en mémoire et mocks ; plus besoin de Redis).
- Tests `pg` (pipeline d'import, schéma) : Postgres réel.
  `docker compose -f docker-compose.test.yml up -d` puis `pytest -q`. Sans lui, ces tests échouent avec un message explicite.
- Uniquement les tests pg : `pytest -m pg -q` ; les autres : `pytest -m "not pg" -q`.
```
```bash
git add collega_backend/docker-compose.test.yml collega_backend/tests/pg.py collega_backend/tests/db collega_backend/alembic/env.py collega_backend/pyproject.toml collega_backend/app/core/limiter.py collega_backend/app/core/config.py collega_backend/tests/conftest.py collega_backend/docs/testing.md
git commit -m "test(chantier-1): Postgres de test réel + limiteur en mémoire pendant les tests"
```

---

### Task 2: Empreintes et normalisation

**Files:**
- Create: `collega_backend/app/services/content/__init__.py` (vide), `collega_backend/app/services/content/fingerprint.py`
- Test: `collega_backend/tests/services/content/__init__.py` (vide), `collega_backend/tests/services/content/test_fingerprint.py`

**Interfaces:**
- Produces: `page_hash(text: str) -> str`, `normalize_item_text(text: str) -> str`, `item_hash(text: str) -> str` (64 caractères hex).

- [ ] **Step 1: Tests**

```python
from app.services.content.fingerprint import item_hash, normalize_item_text, page_hash


def test_page_hash_is_sha256_of_raw_text():
    assert page_hash("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    assert page_hash("abc ") != page_hash("abc")


def test_normalization_drops_page_numbers_blank_lines_and_extra_spaces():
    raw = "Item 304  Tumeurs\n\n233\n  Le   foie\tsain\nPage 12 / 436\n12 sur 40\n  7 \nFin"
    assert normalize_item_text(raw) == "Item 304 Tumeurs\nLe foie sain\nFin"


def test_item_hash_ignores_page_renumbering():
    before = "Tumeurs du foie\n233\nLe foie\n234\nMétastases"
    after = "Tumeurs du foie\n241\nLe foie\n242\nMétastases"
    assert item_hash(before) == item_hash(after)


def test_item_hash_changes_when_content_changes():
    assert item_hash("Le foie\nMétastases") != item_hash("Le foie\nMétastases hépatiques")


def test_numbers_inside_a_line_are_kept():
    assert item_hash("Dose 233 mg") != item_hash("Dose 234 mg")
```
Run: `.venv/bin/python -m pytest tests/services/content/test_fingerprint.py -q` — Expected: FAIL (module absent).

- [ ] **Step 2: Implémentation**

```python
"""Empreintes du stockage de contenu (chantier 1).

- Page : SHA-256 du texte brut extrait (stockage dédoublonné).
- Item : SHA-256 du texte normalisé — décide « même contenu, on garde les
  fiches » vs « modifié, on régénère ». La normalisation retire ce qui bouge
  sans que le contenu change (numéros de page imprimés, espaces) ; elle ne sert
  qu'au calcul de l'empreinte, jamais au texte stocké ni envoyé à Claude.
"""
import hashlib
import re

_SPACES = re.compile(r"\s+")
_PAGE_NUMBER_LINE = re.compile(r"^(page\s*)?\d+(\s*(/|sur)\s*\d+)?$", re.IGNORECASE)


def _sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def page_hash(text: str) -> str:
    return _sha256(text)


def normalize_item_text(text: str) -> str:
    lines = []
    for line in text.splitlines():
        compact = _SPACES.sub(" ", line).strip()
        if not compact or _PAGE_NUMBER_LINE.match(compact):
            continue
        lines.append(compact)
    return "\n".join(lines)


def item_hash(text: str) -> str:
    return _sha256(normalize_item_text(text))
```

- [ ] **Step 3: Vérifier et commit**

Run: `.venv/bin/python -m pytest tests/services/content/test_fingerprint.py -q` — Expected: 5 passed.
```bash
git add collega_backend/app/services/content collega_backend/tests/services/content
git commit -m "feat(chantier-1): empreintes de pages et d'items normalisées"
```

---

### Task 3: Modèle de données, migration 018 et alignement Alembic

**Files:**
- Create: `collega_backend/app/models/content.py`, `collega_backend/alembic/versions/018_content_store.py`
- Modify: `collega_backend/app/models/{item,flash_card,generation_job,college,__init__}.py`, `collega_backend/app/schemas/item.py`
- Test: `collega_backend/tests/db/test_schema_alignment.py`, `collega_backend/tests/db/test_pg_fixture.py` (version attendue → `"018"`)

**Interfaces:**
- Produces (SQLAlchemy, `app.models`) :
  - `OcrPage(hash: str PK, text: str, tables_json: str, confidence: float, method: str, created_at)`
  - `ItemText(hash: str PK, text: str, created_at)`
  - `ItemGeneration(id: UUID PK, text_hash: str FK, generation_version: str, cards_json: str, model: str, input_tokens: int, output_tokens: int, created_at)` ; UNIQUE `uq_item_generations_hash_version`
  - `JobPage(job_id: UUID FK cascade, page_number: int, page_hash: str FK)` PK (job_id, page_number)
  - `JobItem(job_id FK cascade, item_number: int, rang, chapter_title, start_page, end_page, ocr_confidence_score, low_confidence, text_hash FK, generation_id FK NULL)` PK (job_id, item_number)
  - `CollegePage(college_id FK cascade, page_number, page_hash FK)` PK (college_id, page_number)
  - `Item.text_hash: str | None` (FK `item_texts.hash`), plus de `Item.ocr_text`
  - `FlashCard.generation_id: UUID | None` (FK `item_generations.id`, `ondelete="SET NULL"`)
  - `GenerationJob.summary_json: str | None`, plus de `GenerationJob.page_texts_json`

- [ ] **Step 1: Test d'alignement (doit échouer)**

`collega_backend/tests/db/test_schema_alignment.py` :
```python
"""`alembic check` : les modèles déclarent exactement le schéma produit par les migrations."""
import asyncio

import pytest
from alembic import command
from alembic.config import Config
from alembic.autogenerate import compare_metadata
from alembic.migration import MigrationContext

import app.models  # noqa: F401
from app.core.database import Base
from tests.pg import TEST_PG_URL, _BACKEND_DIR, pg_engine  # noqa: F401

pytestmark = pytest.mark.pg


async def test_models_match_migrations(pg_engine):
    async with pg_engine.connect() as conn:
        diff = await conn.run_sync(
            lambda sync_conn: compare_metadata(MigrationContext.configure(sync_conn), Base.metadata)
        )
    assert diff == []


async def test_migration_018_downgrade_then_upgrade(pg_engine):
    import os

    cfg = Config(os.path.join(_BACKEND_DIR, "alembic.ini"))
    cfg.set_main_option("script_location", os.path.join(_BACKEND_DIR, "alembic"))
    cfg.attributes["test_url"] = TEST_PG_URL
    await asyncio.to_thread(command.downgrade, cfg, "017")
    await asyncio.to_thread(command.upgrade, cfg, "head")
```
Run: `.venv/bin/python -m pytest tests/db/test_schema_alignment.py -q` — Expected: FAIL ; noter la liste `diff` (drift actuel : `uq_colleges_user_ref_id`, `idx_one_active_job_per_college`, `ix_generation_jobs_unique_active`, `idx_flash_cards_fts`, `users_email_key`/`ix_users_email`, nullabilité de `card_count`, etc.).

- [ ] **Step 2: Modèles de contenu**

`collega_backend/app/models/content.py` :
```python
"""Stockage de contenu adressé par empreinte + brouillon d'import (chantier 1)."""
import uuid
from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


def _now() -> datetime:
    return datetime.now(timezone.utc)


class OcrPage(Base):
    __tablename__ = "ocr_pages"

    hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    tables_json: Mapped[str] = mapped_column(Text, nullable=False, default="[]")
    confidence: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    method: Mapped[str] = mapped_column(String(20), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=_now)


class ItemText(Base):
    __tablename__ = "item_texts"

    hash: Mapped[str] = mapped_column(String(64), primary_key=True)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=_now)


class ItemGeneration(Base):
    __tablename__ = "item_generations"
    __table_args__ = (
        UniqueConstraint("text_hash", "generation_version", name="uq_item_generations_hash_version"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    text_hash: Mapped[str] = mapped_column(String(64), ForeignKey("item_texts.hash"), nullable=False)
    generation_version: Mapped[str] = mapped_column(String(100), nullable=False)
    cards_json: Mapped[str] = mapped_column(Text, nullable=False)
    model: Mapped[str] = mapped_column(String(100), nullable=False)
    input_tokens: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    output_tokens: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=_now)


class JobPage(Base):
    __tablename__ = "job_pages"

    job_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("generation_jobs.id", ondelete="CASCADE"), primary_key=True
    )
    page_number: Mapped[int] = mapped_column(Integer, primary_key=True)
    page_hash: Mapped[str] = mapped_column(String(64), ForeignKey("ocr_pages.hash"), nullable=False)


class JobItem(Base):
    __tablename__ = "job_items"

    job_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("generation_jobs.id", ondelete="CASCADE"), primary_key=True
    )
    item_number: Mapped[int] = mapped_column(Integer, primary_key=True)
    rang: Mapped[str] = mapped_column(String(1), nullable=False)
    chapter_title: Mapped[str | None] = mapped_column(String(500), nullable=True)
    start_page: Mapped[int | None] = mapped_column(Integer, nullable=True)
    end_page: Mapped[int | None] = mapped_column(Integer, nullable=True)
    ocr_confidence_score: Mapped[float] = mapped_column(Float, nullable=False, default=0.0)
    low_confidence: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    text_hash: Mapped[str] = mapped_column(String(64), ForeignKey("item_texts.hash"), nullable=False)
    generation_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("item_generations.id"), nullable=True
    )


class CollegePage(Base):
    __tablename__ = "college_pages"

    college_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("colleges.id", ondelete="CASCADE"), primary_key=True
    )
    page_number: Mapped[int] = mapped_column(Integer, primary_key=True)
    page_hash: Mapped[str] = mapped_column(String(64), ForeignKey("ocr_pages.hash"), nullable=False)
```
`app/models/__init__.py` : importer et exporter `CollegePage, ItemGeneration, ItemText, JobItem, JobPage, OcrPage` depuis `app.models.content`.

- [ ] **Step 3: Modèles existants**

- `app/models/item.py` : supprimer `ocr_text` ; ajouter
```python
    text_hash: Mapped[str | None] = mapped_column(String(64), ForeignKey("item_texts.hash"), nullable=True)
```
- `app/models/flash_card.py` : ajouter
```python
    # Sortie Claude d'origine ; NULL = fiche antérieure au chantier 1 ou régénérée par l'utilisatrice.
    generation_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("item_generations.id", ondelete="SET NULL"), nullable=True
    )
```
et, dans `__table_args__`, l'index plein texte (identique à la migration 010) :
```python
        Index(
            "idx_flash_cards_fts",
            text("to_tsvector('french'::regconfig, (COALESCE(recto, ''::text) || ' '::text) || COALESCE(verso, ''::text))"),
            postgresql_using="gin",
        ),
```
(imports `Index`, `text` depuis `sqlalchemy`). Si `compare_metadata` signale encore l'index après la migration, garder cette déclaration et ajouter `info={"skip_autogenerate": True}` n'est PAS permis : ajuster l'expression textuelle pour qu'elle corresponde exactement à `pg_get_indexdef` (la relever avec `select pg_get_indexdef('idx_flash_cards_fts'::regclass)` sur la base de test).
- `app/models/generation_job.py` : supprimer `page_texts_json` ; ajouter
```python
    # Résumé de la bascule (chantier 1) : {changed, added, removed, unchanged, cards, claude_calls, quota_refunded}
    summary_json: Mapped[str | None] = mapped_column(Text, nullable=True)
```
passer `card_count` en `mapped_column(Integer, nullable=False, default=0)` ; ajouter dans `__table_args__` l'index unique partiel existant :
```python
        Index(
            "idx_one_active_job_per_college",
            "college_id",
            unique=True,
            postgresql_where=text("status IN ('pending', 'processing', 'ocr_complete')"),
        ),
```
(relever la clause exacte avec `select pg_get_indexdef('idx_one_active_job_per_college'::regclass)` et la recopier).
- `app/models/college.py` : `__table_args__ = (UniqueConstraint("user_id", "college_ref_id", name="uq_colleges_user_ref_id"),)`.
- `app/models/user.py` : `email` est aujourd'hui `unique=True, index=True` ; le schéma réel a une contrainte `users_email_key` (sans index `ix_users_email`) ou l'inverse — aligner la déclaration sur ce que rapporte le diff (ex. `unique=True` sans `index=True`).
- `app/schemas/item.py` : retirer `ocr_text` de `ItemCreate`.

- [ ] **Step 4: Migration 018**

`collega_backend/alembic/versions/018_content_store.py` :
```python
"""stockage de contenu par empreinte + brouillon d'import (chantier 1)

Revision ID: 018
Revises: 017
Create Date: 2026-09-24
"""
import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "018"
down_revision = "017"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "ocr_pages",
        sa.Column("hash", sa.String(64), primary_key=True),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("tables_json", sa.Text(), nullable=False),
        sa.Column("confidence", sa.Float(), nullable=False),
        sa.Column("method", sa.String(20), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_table(
        "item_texts",
        sa.Column("hash", sa.String(64), primary_key=True),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_table(
        "item_generations",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("text_hash", sa.String(64), sa.ForeignKey("item_texts.hash"), nullable=False),
        sa.Column("generation_version", sa.String(100), nullable=False),
        sa.Column("cards_json", sa.Text(), nullable=False),
        sa.Column("model", sa.String(100), nullable=False),
        sa.Column("input_tokens", sa.Integer(), nullable=False),
        sa.Column("output_tokens", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("text_hash", "generation_version", name="uq_item_generations_hash_version"),
    )
    op.create_table(
        "job_pages",
        sa.Column("job_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("generation_jobs.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("page_number", sa.Integer(), primary_key=True),
        sa.Column("page_hash", sa.String(64), sa.ForeignKey("ocr_pages.hash"), nullable=False),
    )
    op.create_table(
        "job_items",
        sa.Column("job_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("generation_jobs.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("item_number", sa.Integer(), primary_key=True),
        sa.Column("rang", sa.String(1), nullable=False),
        sa.Column("chapter_title", sa.String(500), nullable=True),
        sa.Column("start_page", sa.Integer(), nullable=True),
        sa.Column("end_page", sa.Integer(), nullable=True),
        sa.Column("ocr_confidence_score", sa.Float(), nullable=False),
        sa.Column("low_confidence", sa.Boolean(), nullable=False),
        sa.Column("text_hash", sa.String(64), sa.ForeignKey("item_texts.hash"), nullable=False),
        sa.Column("generation_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("item_generations.id"), nullable=True),
    )
    op.create_table(
        "college_pages",
        sa.Column("college_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("colleges.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("page_number", sa.Integer(), primary_key=True),
        sa.Column("page_hash", sa.String(64), sa.ForeignKey("ocr_pages.hash"), nullable=False),
    )
    op.add_column("items", sa.Column("text_hash", sa.String(64), sa.ForeignKey("item_texts.hash"), nullable=True))
    op.drop_column("items", "ocr_text")
    op.add_column(
        "flash_cards",
        sa.Column("generation_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("item_generations.id", ondelete="SET NULL"), nullable=True),
    )
    op.add_column("generation_jobs", sa.Column("summary_json", sa.Text(), nullable=True))
    op.drop_column("generation_jobs", "page_texts_json")
    # Alignement modèles ↔ migrations : ajouter ici UNIQUEMENT les opérations
    # rapportées par test_models_match_migrations (Step 1) qui ne se règlent pas
    # en corrigeant la déclaration du modèle, par exemple :
    op.drop_index("ix_generation_jobs_unique_active", table_name="generation_jobs")
    op.execute("UPDATE generation_jobs SET card_count = 0 WHERE card_count IS NULL")
    op.alter_column("generation_jobs", "card_count", nullable=False)


def downgrade() -> None:
    op.alter_column("generation_jobs", "card_count", nullable=True)
    op.create_index(
        "ix_generation_jobs_unique_active", "generation_jobs", ["college_id"], unique=True,
        postgresql_where=sa.text("status IN ('pending', 'processing', 'ocr_complete')"),
    )
    op.add_column("generation_jobs", sa.Column("page_texts_json", sa.Text(), nullable=True))
    op.drop_column("generation_jobs", "summary_json")
    op.drop_column("flash_cards", "generation_id")
    op.add_column("items", sa.Column("ocr_text", sa.Text(), nullable=True))
    op.drop_column("items", "text_hash")
    for table in ("college_pages", "job_items", "job_pages", "item_generations", "item_texts", "ocr_pages"):
        op.drop_table(table)
```
Recopier dans le `downgrade` la définition exacte d'origine de `ix_generation_jobs_unique_active` (relevée par `pg_get_indexdef` avant suppression).

- [ ] **Step 5: Itérer jusqu'à un diff vide**

Run: `.venv/bin/python -m pytest tests/db -q` — corriger modèles et migration jusqu'à : `test_models_match_migrations` PASS, `test_migration_018_downgrade_then_upgrade` PASS, `test_schema_is_migrated_to_head` PASS (version `"018"`).

- [ ] **Step 6: Commit**

Les autres tests qui référencent `Item.ocr_text` / `page_texts_json` échoueront : ils sont réécrits ou supprimés par les tâches 6 à 9 ; noter la liste (`.venv/bin/python -m pytest -q 2>&1 | tail -30`) dans le message de commit.
```bash
git add collega_backend/app/models collega_backend/alembic/versions/018_content_store.py collega_backend/app/schemas/item.py collega_backend/tests/db
git commit -m "feat(chantier-1): tables de contenu par empreinte, brouillon d'import, modèles alignés sur les migrations"
```

---

### Task 4: Accès au stockage de contenu

**Files:**
- Create: `collega_backend/app/services/content/store.py`
- Test: `collega_backend/tests/services/content/test_store.py`

**Interfaces:**
- Consumes: modèles Task 3, `page_hash`/`item_hash` Task 2.
- Produces:
  - `async put_page(db, text: str, tables: list, confidence: float, method: str) -> str` (empreinte ; ON CONFLICT DO NOTHING)
  - `async load_pages(db, hashes: list[str]) -> dict[str, OcrPage]`
  - `async put_item_text(db, text: str) -> str` (empreinte normalisée ; stocke le texte brut)
  - `async get_item_text(db, text_hash: str) -> str | None`
  - `async find_generation(db, text_hash: str, version: str) -> ItemGeneration | None`
  - `async put_generation(db, text_hash, version, cards: list[dict], model, input_tokens, output_tokens) -> ItemGeneration` (en cas de conflit : renvoie la ligne existante)
  - `generation_cards(gen: ItemGeneration) -> list[dict]` (`[{"card_type","recto","verso"}]`)

- [ ] **Step 1: Tests (pg)**

```python
import pytest
from sqlalchemy import func, select

from app.models.content import ItemGeneration, OcrPage
from app.services.content import store
from app.services.content.fingerprint import item_hash
from tests.pg import pg_engine, pg_factory, pg_session  # noqa: F401

pytestmark = pytest.mark.pg


async def test_same_page_is_stored_once(pg_session):
    h1 = await store.put_page(pg_session, "texte", [[["A"]]], 0.9, "pdfplumber")
    h2 = await store.put_page(pg_session, "texte", [[["A"]]], 0.9, "pdfplumber")
    await pg_session.commit()
    assert h1 == h2
    assert (await pg_session.execute(select(func.count()).select_from(OcrPage))).scalar_one() == 1
    pages = await store.load_pages(pg_session, [h1])
    assert pages[h1].text == "texte" and pages[h1].tables_json == '[[["A"]]]'


async def test_item_text_keyed_by_normalized_hash_keeps_raw_text(pg_session):
    h = await store.put_item_text(pg_session, "Le foie\n233\nsain")
    await pg_session.commit()
    assert h == item_hash("Le foie\n999\nsain")
    assert await store.get_item_text(pg_session, h) == "Le foie\n233\nsain"


async def test_generation_is_unique_per_hash_and_version(pg_session):
    h = await store.put_item_text(pg_session, "texte item")
    cards = [{"card_type": "classique", "recto": "Q ?", "verso": "R"}]
    g1 = await store.put_generation(pg_session, h, "v1", cards, "m", 10, 5)
    g2 = await store.put_generation(pg_session, h, "v1", [], "m", 99, 99)
    await pg_session.commit()
    assert g1.id == g2.id and store.generation_cards(g2) == cards
    assert await store.find_generation(pg_session, h, "v2") is None
    g3 = await store.put_generation(pg_session, h, "v2", cards, "m", 1, 1)
    await pg_session.commit()
    assert g3.id != g1.id
    assert (await pg_session.execute(select(func.count()).select_from(ItemGeneration))).scalar_one() == 2
```
Run: `.venv/bin/python -m pytest tests/services/content/test_store.py -q` — Expected: FAIL (module absent).

- [ ] **Step 2: Implémentation**

```python
"""Accès aux tables de contenu adressées par empreinte (chantier 1).

Écritures en INSERT … ON CONFLICT DO NOTHING : deux imports concurrents (même
PDF chez deux utilisatrices) peuvent écrire la même empreinte sans erreur.
"""
import json
import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.content import ItemGeneration, ItemText, OcrPage
from app.services.content.fingerprint import item_hash, page_hash


async def put_page(db: AsyncSession, text: str, tables: list, confidence: float, method: str) -> str:
    h = page_hash(text)
    await db.execute(
        insert(OcrPage)
        .values(hash=h, text=text, tables_json=json.dumps(tables, ensure_ascii=False),
                confidence=confidence, method=method)
        .on_conflict_do_nothing(index_elements=["hash"])
    )
    return h


async def load_pages(db: AsyncSession, hashes: list[str]) -> dict[str, OcrPage]:
    if not hashes:
        return {}
    rows = await db.execute(select(OcrPage).where(OcrPage.hash.in_(set(hashes))))
    return {p.hash: p for p in rows.scalars()}


async def put_item_text(db: AsyncSession, text: str) -> str:
    h = item_hash(text)
    await db.execute(insert(ItemText).values(hash=h, text=text).on_conflict_do_nothing(index_elements=["hash"]))
    return h


async def get_item_text(db: AsyncSession, text_hash: str) -> str | None:
    row = await db.get(ItemText, text_hash)
    return row.text if row else None


async def find_generation(db: AsyncSession, text_hash: str, version: str) -> ItemGeneration | None:
    rows = await db.execute(
        select(ItemGeneration)
        .where(ItemGeneration.text_hash == text_hash)
        .where(ItemGeneration.generation_version == version)
    )
    return rows.scalar_one_or_none()


async def put_generation(
    db: AsyncSession, text_hash: str, version: str, cards: list[dict[str, Any]],
    model: str, input_tokens: int, output_tokens: int,
) -> ItemGeneration:
    await db.execute(
        insert(ItemGeneration)
        .values(id=uuid.uuid4(), text_hash=text_hash, generation_version=version,
                cards_json=json.dumps(cards, ensure_ascii=False), model=model,
                input_tokens=input_tokens, output_tokens=output_tokens)
        .on_conflict_do_nothing(constraint="uq_item_generations_hash_version")
    )
    gen = await find_generation(db, text_hash, version)
    assert gen is not None
    return gen


def generation_cards(gen: ItemGeneration) -> list[dict[str, Any]]:
    return json.loads(gen.cards_json)
```
Note : les `insert` ne renseignent pas `created_at` ; ajouter `server_default=sa.func.now()` dans la migration 018 **et** `server_default=func.now()` dans les modèles pour `created_at` des trois tables de contenu (le diff d'alignement doit rester vide).

- [ ] **Step 3: Vérifier et commit**

Run: `.venv/bin/python -m pytest tests/services/content tests/db -q` — Expected: PASS.
```bash
git add collega_backend/app/services/content/store.py collega_backend/tests/services/content/test_store.py collega_backend/app/models/content.py collega_backend/alembic/versions/018_content_store.py
git commit -m "feat(chantier-1): accès au stockage de contenu (pages, textes, générations)"
```

---

### Task 5: Client Claude à partir d'un texte + version de génération

**Files:**
- Modify: `collega_backend/app/services/generation/claude_client.py`
- Test: `collega_backend/tests/services/test_claude_client.py` (adapter l'existant s'il appelle `generate_cards_for_item(item)` ; sinon créer)

**Interfaces:**
- Produces: `GENERATION_MODEL = "claude-sonnet-4-6"`, `PROMPT_VERSION = "p1"`, `GENERATION_VERSION = f"{GENERATION_MODEL}:{PROMPT_VERSION}"` ; `async ClaudeClient.generate_cards(item_number: int, rang: str, text: str) -> CardGenResult` ; `async ClaudeClient.regenerate_single_card(card, item, source_text: str, user_note: str | None)`.

- [ ] **Step 1: Test**

```python
from types import SimpleNamespace
from unittest.mock import AsyncMock

from app.services.generation import claude_client as cc


async def test_generate_cards_from_text_uses_versioned_model():
    client = cc.ClaudeClient()
    response = SimpleNamespace(
        usage=SimpleNamespace(input_tokens=100, output_tokens=20),
        content=[SimpleNamespace(text='{"flashcards":[{"type":"classique","recto":"Q ?","verso":"R"}]}')],
    )
    client._client = SimpleNamespace(messages=SimpleNamespace(create=AsyncMock(return_value=response)))

    result = await client.generate_cards(304, "B", "Texte {avec} accolades")

    assert [c.recto for c in result.cards] == ["Q ?"]
    assert (result.input_tokens, result.output_tokens) == (100, 20)
    kwargs = client._client.messages.create.await_args.kwargs
    assert kwargs["model"] == cc.GENERATION_MODEL
    assert "Texte {avec} accolades" in kwargs["messages"][0]["content"]
    assert cc.GENERATION_VERSION == "claude-sonnet-4-6:p1"


async def test_empty_text_makes_no_call():
    client = cc.ClaudeClient()
    client._client = SimpleNamespace(messages=SimpleNamespace(create=AsyncMock()))
    result = await client.generate_cards(1, "A", "   ")
    assert result.cards == [] and client._client.messages.create.await_count == 0
```
Run: `.venv/bin/python -m pytest tests/services/test_claude_client.py -q` — Expected: FAIL.

- [ ] **Step 2: Implémentation**

Dans `claude_client.py` :
- ajouter sous les imports :
```python
GENERATION_MODEL = "claude-sonnet-4-6"
# Incrémenter à chaque changement de GENERATION_PROMPT : les items déjà vus seront régénérés
# (clé des item_generations = empreinte + version), sans effacer les anciennes générations.
PROMPT_VERSION = "p1"
GENERATION_VERSION = f"{GENERATION_MODEL}:{PROMPT_VERSION}"
```
- remplacer `generate_cards_for_item(self, item)` par `generate_cards(self, item_number: int, rang: str, text: str)` : même corps, avec `if not text.strip(): return CardGenResult(cards=[], input_tokens=0, output_tokens=0)`, `safe_ocr_text = text.replace("{", "{{").replace("}", "}}")`, `item_number=item_number, rang=rang` dans `format`, `model=GENERATION_MODEL`, et les logs `item %s` → `item_number`.
- `regenerate_single_card(self, card, item, source_text: str, user_note)` : remplacer les lectures de `item.ocr_text` par `source_text` (garde « texte vide → None » conservée).

- [ ] **Step 3: Vérifier et commit**

Run: `.venv/bin/python -m pytest tests/services/test_claude_client.py -q` — Expected: PASS.
```bash
git add collega_backend/app/services/generation/claude_client.py collega_backend/tests/services/test_claude_client.py
git commit -m "feat(chantier-1): génération Claude à partir d'un texte, version de génération explicite"
```

---

### Task 6: Échec d'un job (service partagé) et notifications

**Files:**
- Create: `collega_backend/app/services/jobs/job_failure.py`
- Modify: `collega_backend/app/services/notifications/apns_service.py`
- Test: `collega_backend/tests/services/test_job_failure.py`, `collega_backend/tests/services/test_notification_messages.py`

**Interfaces:**
- Produces:
  - `async fail_job(session_factory, job_id: uuid.UUID, message: str, *, event: str = "failed", notify: bool = True) -> bool` — nouvelle session ; `False` si le job n'existe plus ou n'est plus actif ; sinon job `failed` + `error_message` + événement, `job_pages`/`job_items` du job supprimés, `College.status = failed` **seulement** si le collège n'est pas `generation_complete`, PDF `{college_id}_{job_id}.pdf` supprimé, notification d'échec (best-effort) ; `True`.
  - `completion_message(summary: dict | None) -> tuple[str, str]` et `failure_message(reimport: bool, college_name: str) -> tuple[str, str]` (titre, corps) dans `apns_service.py`.
  - `NotificationService.send_generation_complete(apns_token, college_ref_id, summary: dict | None = None)`, `NotificationService.send_import_failed(apns_token, college_ref_id, reimport: bool)`.
- Nom d'un collège pour les messages : `f"ton collège n°{ref_id}"` (le catalogue des noms vit côté app).

- [ ] **Step 1: Tests des messages**

```python
from app.services.notifications.apns_service import completion_message, failure_message


def test_first_import_message():
    assert completion_message(None) == ("Fiches prêtes", "Tes fiches t’attendent dans Collega.")


def test_reimport_with_changes():
    s = {"changed": 3, "added": 1, "removed": 0, "unchanged": 20, "claude_calls": 4, "quota_refunded": False}
    assert completion_message(s)[1] == "3 items mis à jour, 1 nouveau, 20 inchangés."


def test_reimport_without_changes():
    s = {"changed": 0, "added": 0, "removed": 0, "unchanged": 24, "claude_calls": 0, "quota_refunded": True}
    assert completion_message(s) == ("Aucun changement", "Aucun changement dans ce PDF : ton réimport n’a pas été décompté.")


def test_failure_messages():
    assert failure_message(True, "ton collège n°34") == (
        "Réimport interrompu", "Le réimport de ton collège n°34 n’a pas abouti. Tes fiches actuelles sont intactes."
    )
    assert failure_message(False, "ton collège n°34")[1] == "L’import de ton collège n°34 n’a pas abouti. Relance-le depuis l’app."
```
Règles de pluriel : `1 item mis à jour` / `N items mis à jour`, `1 nouveau` / `N nouveaux`, `1 supprimé` / `N supprimés`, `1 inchangé` / `N inchangés` ; n'afficher que les compteurs non nuls, séparés par `, `, point final. Ajouter un test `{"changed":1,"added":0,"removed":2,"unchanged":1}` → `"1 item mis à jour, 2 supprimés, 1 inchangé."`.

- [ ] **Step 2: Implémentation des messages et des méthodes**

Dans `apns_service.py`, fonctions module :
```python
def _plural(n: int, one: str, many: str) -> str:
    return f"{n} {one if n == 1 else many}"


def completion_message(summary: dict | None) -> tuple[str, str]:
    if not summary:
        return "Fiches prêtes", "Tes fiches t’attendent dans Collega."
    if not (summary.get("changed") or summary.get("added") or summary.get("removed")):
        return "Aucun changement", "Aucun changement dans ce PDF : ton réimport n’a pas été décompté."
    parts = [
        _plural(summary["changed"], "item mis à jour", "items mis à jour") if summary.get("changed") else None,
        _plural(summary["added"], "nouveau", "nouveaux") if summary.get("added") else None,
        _plural(summary["removed"], "supprimé", "supprimés") if summary.get("removed") else None,
        _plural(summary["unchanged"], "inchangé", "inchangés") if summary.get("unchanged") else None,
    ]
    return "Fiches mises à jour", ", ".join(p for p in parts if p) + "."


def failure_message(reimport: bool, college_name: str) -> tuple[str, str]:
    if reimport:
        return "Réimport interrompu", f"Le réimport de {college_name} n’a pas abouti. Tes fiches actuelles sont intactes."
    return "Import interrompu", f"L’import de {college_name} n’a pas abouti. Relance-le depuis l’app."
```
Note : « Aucun changement » n'affirme « non décompté » que si `quota_refunded` est vrai ; sinon corps `"Aucun changement dans ce PDF."`. Ajouter le test correspondant.

`NotificationService` : ajouter les abstraites `send_import_failed(self, apns_token, college_ref_id, reimport)` et le paramètre `summary: dict | None = None` à `send_generation_complete`. `NullNotificationService` : `logger.debug` pour les deux. `APNsNotificationService` : extraire l'envoi en `async def _send_alert(self, apns_token, title, body, extra: dict)` (même `NotificationRequest` qu'aujourd'hui, `badge` uniquement pour la complétion) ; `send_generation_complete` → `title, body = completion_message(summary)` ; `send_import_failed` → `failure_message(reimport, f"ton collège n°{college_ref_id}")`.

- [ ] **Step 3: Tests `fail_job` (pg)**

Fichier `tests/services/test_job_failure.py`. Fixture locale `seed` qui crée via `pg_session` : un `User`, un `College` (`status` paramétrable), un `GenerationJob` actif (`status="ocr_complete"`), une ligne `ocr_pages` + `item_texts` + `job_pages` + `job_items` pour ce job, et un fichier PDF vide `{college_id}_{job_id}.pdf` dans `tmp_path` (monkeypatch `settings.pdf_storage_path = str(tmp_path)`).
```python
async def test_reimport_failure_keeps_college_content(pg_factory, seed_reimport):
    ok = await fail_job(pg_factory, seed_reimport.job_id, "Claude indisponible", notify=False)
    assert ok
    async with pg_factory() as s:
        job = await s.get(GenerationJob, seed_reimport.job_id)
        college = await s.get(College, seed_reimport.college_id)
        assert (job.status, job.error_message) == ("failed", "Claude indisponible")
        assert college.status == "generation_complete"
        assert (await s.execute(select(func.count()).select_from(JobPage))).scalar_one() == 0
        assert (await s.execute(select(func.count()).select_from(JobItem))).scalar_one() == 0
    assert not seed_reimport.pdf_path.exists()


async def test_first_import_failure_marks_college_failed(pg_factory, seed_first_import):
    await fail_job(pg_factory, seed_first_import.job_id, "boom", notify=False)
    async with pg_factory() as s:
        assert (await s.get(College, seed_first_import.college_id)).status == "failed"


async def test_already_failed_job_is_left_alone(pg_factory, seed_reimport):
    await fail_job(pg_factory, seed_reimport.job_id, "premier", notify=False)
    assert await fail_job(pg_factory, seed_reimport.job_id, "second", notify=False) is False
    async with pg_factory() as s:
        assert (await s.get(GenerationJob, seed_reimport.job_id)).error_message == "premier"


async def test_failure_notifies_owner(pg_factory, seed_reimport, monkeypatch):
    sent = []
    class Spy:
        async def send_import_failed(self, token, ref_id, reimport):
            sent.append((token, ref_id, reimport))
    monkeypatch.setattr("app.services.jobs.job_failure.get_notification_service", lambda: Spy())
    await fail_job(pg_factory, seed_reimport.job_id, "boom")
    assert sent == [(seed_reimport.apns_token, seed_reimport.ref_id, True)]
```
Run: Expected FAIL (module absent).

- [ ] **Step 4: Implémentation `fail_job`**

```python
"""Échec d'un import — un seul chemin pour le worker, le Stop admin et le cron
des jobs bloqués. Nouvelle session : celle de l'appelant peut être cassée
(rollback, connexion perdue, CancelledError)."""
import logging
import uuid
from pathlib import Path

from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.config import settings
from app.models.college import College, CollegeStatus
from app.models.content import JobItem, JobPage
from app.models.generation_job import GenerationJob
from app.models.user import User
from app.services.jobs.job_events import record_job_event
from app.services.notifications.apns_service import get_notification_service

logger = logging.getLogger(__name__)
ACTIVE_JOB_STATUSES = ("pending", "processing", "ocr_complete")


async def fail_job(
    session_factory: async_sessionmaker[AsyncSession], job_id: uuid.UUID, message: str,
    *, event: str = "failed", notify: bool = True,
) -> bool:
    async with session_factory() as db:
        job = (await db.execute(
            select(GenerationJob).where(GenerationJob.id == job_id).with_for_update()
        )).scalar_one_or_none()
        if job is None or job.status not in ACTIVE_JOB_STATUSES:
            return False
        college = await db.get(College, job.college_id)
        reimport = college is not None and college.status == CollegeStatus.generation_complete
        job.status = "failed"
        job.error_message = message
        await record_job_event(db, job.id, event, message=message)
        await db.execute(delete(JobPage).where(JobPage.job_id == job.id))
        await db.execute(delete(JobItem).where(JobItem.job_id == job.id))
        if college is not None and not reimport:
            college.status = CollegeStatus.failed
        user = await db.get(User, job.user_id)
        ref_id = college.college_ref_id if college else None
        token = user.apns_token if user else None
        await db.commit()

    Path(settings.pdf_storage_path, f"{job.college_id}_{job.id}.pdf").unlink(missing_ok=True)
    if notify and ref_id is not None:
        try:
            await get_notification_service().send_import_failed(token, ref_id, reimport)
        except Exception:  # noqa: BLE001 — une notification ne fait jamais échouer
            logger.warning("Notification d'échec non envoyée (job %s)", job_id, exc_info=True)
    return True
```
Vérifier que `record_job_event` accepte un `event` libre (« failed », « stale ») ; sinon étendre sa liste.

- [ ] **Step 5: Vérifier et commit**

Run: `.venv/bin/python -m pytest tests/services/test_job_failure.py tests/services/test_notification_messages.py -q` — Expected: PASS.
```bash
git add collega_backend/app/services/jobs/job_failure.py collega_backend/app/services/notifications/apns_service.py collega_backend/tests/services/test_job_failure.py collega_backend/tests/services/test_notification_messages.py
git commit -m "feat(chantier-1): échec d'import centralisé, notifications de résumé et d'échec"
```

---

### Task 7: Worker OCR — pages par empreinte, reprise, brouillon d'items

**Files:**
- Modify: `collega_backend/app/workers/ocr_worker.py`
- Test: `collega_backend/tests/workers/test_ocr_pipeline.py` (pg) ; supprimer ou réécrire les cas de `tests/workers/test_ocr_worker.py` qui dépendent de `page_texts_json`/`Item.ocr_text` (les garder s'ils testent la déduplication ou les titres, en les portant sur `job_items`).

**Interfaces:**
- Consumes: `store.put_page`, `store.load_pages`, `store.put_item_text`, `fail_job`, `JobPage`, `JobItem`.
- Produces: `process_college_ocr(ctx, college_id, job_id, pdf_path)` (signature inchangée) ; `async run_ocr(session_factory, college_id: uuid.UUID, job_id: uuid.UUID, pdf_path: str, processor, ctx=None) -> dict` (testable, `processor` = objet avec `count_pages(path) -> int` et `process_page(path, n) -> OcrPageResult`).

Comportement (spec §6.2, §6.3) :
1. job introuvable ou pas actif → retour `{"error": "invalid_job_state"}` ;
2. `total = count_pages` ; 0 → `fail_job(..., "PDF vide ou illisible")` ;
3. `college.total_pages = total`, `ocr_page_progress = nb job_pages déjà faites` ; **si `college.status != generation_complete`** : `college.status = processing` ; champs `generation_*` remis à zéro ; `job.status = processing` ; événement `ocr_started` ; commit ;
4. pour chaque page non faite : vérification d'arrêt (`select status` du job : `None` ou `failed` → retour `{"error": "cancelled"}`), `process_page` en thread, `put_page`, `JobPage`, `ocr_page_progress`, événement throttlé, commit ;
5. détection sur les pages du job (`load_pages`, `json.loads(tables_json)`), dédoublonnage et titres **inchangés** (code existant déplacé) ;
6. pour chaque item : `text_hash = await put_item_text(db, detected.ocr_text)`, `JobItem(...)` ; aucune écriture dans `items` ;
7. `job.status = "ocr_complete"`, si `college.status != generation_complete` → `college.status = ocr_complete` ; événement `ocr_complete` ; commit ; enqueue de `generate_college_cards` (inchangé, avec repointage `arq_job_id`) ;
8. `process_college_ocr` entoure `run_ocr` d'un `try: … except BaseException as exc: await fail_job(async_session_factory, job_uuid, f"OCR : {exc!r}"[:500]); raise`.

- [ ] **Step 1: Tests (pg)** — `FakeProcessor` : pages `["Item 304 Tumeurs\nRang Rubrique\nTexte A", "suite A\n233", "Item 305 Autre\nTexte B"]`, compteur d'appels ; seed d'un collège + job `pending` (+ PDF factice).
  - `test_first_run_stores_pages_and_draft_items` : après `run_ocr`, `job_pages` = 3, `ocr_pages` = 3, `job_items` = numéros détectés, `items` vide, job `ocr_complete`, collège `ocr_complete`.
  - `test_resume_skips_done_pages` : insérer au préalable `JobPage` pour la page 0 (via `put_page`) ; `run_ocr` n'appelle `process_page` que pour 1 et 2.
  - `test_reimport_keeps_college_ready` : collège `generation_complete` avec un `Item` existant ; après `run_ocr`, collège toujours `generation_complete`, l'`Item` existant intact.
  - `test_stop_between_pages` : `FakeProcessor.process_page` met le job à `failed` (session séparée) à la page 1 → retour `cancelled`, page 2 jamais traitée.
  - `test_crash_marks_job_failed` : `process_page` lève `RuntimeError` → `process_college_ocr` relève l'exception ; job `failed`, collège `failed` (premier import).
  - `test_cancelled_error_marks_job_failed` : `process_page` lève `asyncio.CancelledError` → idem (job `failed`).
  - `test_duplicate_pages_stored_once` : deux pages de même texte → `ocr_pages` = 1, `job_pages` = 2.
  Les textes des pages doivent être reconnus par `ItemDetector` : s'inspirer des fixtures de `tests/services/test_item_detector.py` (format « Item N » en tête de page, avec tableau de rang) pour construire des pages valides.
  Run : Expected FAIL.

- [ ] **Step 2: Implémentation** — réécrire `ocr_worker.py` selon le comportement ci-dessus (garder `_resolve_title`, `_RANG_PRIORITY`, la déduplication et l'enqueue tels quels). Supprimer `delete(Item)` et tout usage de `page_texts_json`.

- [ ] **Step 3: Vérifier et commit**

Run: `.venv/bin/python -m pytest tests/workers/test_ocr_pipeline.py tests/workers/test_ocr_worker.py tests/services/test_item_detector.py -q` — Expected: PASS.
```bash
git add collega_backend/app/workers/ocr_worker.py collega_backend/tests/workers
git commit -m "feat(chantier-1): OCR par empreinte avec reprise, items en brouillon (plus de suppression avant génération)"
```

---

### Task 8: Bascule (publication d'un import)

**Files:**
- Create: `collega_backend/app/services/generation/publish.py`
- Test: `collega_backend/tests/services/test_publish.py` (pg)

**Interfaces:**
- Consumes: `JobItem`, `JobPage`, `CollegePage`, `ItemGeneration`, `store.generation_cards`.
- Produces:
  - `@dataclass ImportSummary(changed: int, added: int, removed: int, unchanged: int, cards: int, claude_calls: int, quota_refunded: bool)` avec `as_dict()`.
  - `async publish_job(db, job_id: uuid.UUID, *, claude_calls: int) -> ImportSummary | None` — `None` si le job n'est plus `ocr_complete` (rejouable) ; **ne commit pas** (l'appelant commit) ; ne supprime aucun fichier.
  - `def stale_pdfs(college_id, keep_job_id) -> list[Path]` : les `{college_id}_*.pdf` autres que celui du job.

Algorithme (spec §6.5) :
```python
college = (await db.execute(select(College).where(College.id == job.college_id).with_for_update())).scalar_one()
job = (await db.execute(select(GenerationJob).where(GenerationJob.id == job_id).with_for_update())).scalar_one_or_none()
if job is None or job.status != "ocr_complete": return None
was_ready = college.status == CollegeStatus.generation_complete
drafts = {ji.item_number: ji for ji in job_items}
live = {it.item_number: it for it in items of college}
for number, draft in drafts.items():
    item = live.get(number)
    if item is None:           # nouveau
        item = Item(college_id=..., item_number=number, ...métadonnées..., text_hash=draft.text_hash); db.add(item); await db.flush()
        added += 1; await _insert_cards(item, draft)
    elif item.text_hash == draft.text_hash:   # inchangé
        _copy_metadata(item, draft); unchanged += 1
    else:                      # modifié
        _copy_metadata(item, draft); item.text_hash = draft.text_hash
        await db.execute(delete(FlashCard).where(FlashCard.item_id == item.id))
        changed += 1; await _insert_cards(item, draft)
for number, item in live.items():
    if number not in drafts: await db.delete(item); removed += 1
```
- `_copy_metadata` : `rang`, `chapter_title`, `start_page`, `end_page`, `ocr_confidence_score`, `low_confidence`.
- `_insert_cards` : si `draft.generation_id` → une `FlashCard` par entrée de `generation_cards(gen)` (`card_type`, `recto`, `verso`, `rang=item.rang`, `ocr_confidence_score`/`low_confidence` de l'item, `user_id=college.user_id`, `college_id`, `generation_id=gen.id`).
- `college_pages` : `delete` puis insertion depuis `job_pages` ; `delete` de `job_pages`/`job_items` du job.
- Quota : `quota_refunded = was_ready and claude_calls == 0` → les deux `UPDATE … WHERE … > 0` (code de `card_generator.py:111-122` déplacé).
- Job : `status="generation_complete"`, `card_count` = `count(flash_cards where college_id)`, `hash_shared = claude_calls == 0`, `summary_json = json.dumps(summary.as_dict())` ; `college.status = generation_complete` ; `college.generation_items_total = None` ; événement `generation_complete` avec le message `f"{changed} modifiés, {added} nouveaux, {removed} supprimés, {unchanged} inchangés"`.
- Items d'un **premier import** (collège sans items) : tous `added` ; `summary` stocké quand même, mais la notification traitera `was_ready=False` comme premier import (voir Task 9).

- [ ] **Step 1: Tests (pg)** — helper `make_draft(job, number, text, cards)` qui crée `item_texts`, une `item_generations` (si `cards` non `None`) et la `JobItem`.
  - `test_first_import_creates_items_and_cards` ;
  - `test_unchanged_item_keeps_cards_ids_feedback_and_user_changes` : item vivant même `text_hash`, fiche avec `user_feedback="positive"`, une fiche supprimée avant, une fiche régénérée (`generation_id=None`, recto modifié) → après bascule, mêmes ids, feedback et recto, rien de recréé ;
  - `test_changed_item_keeps_item_id_replaces_cards` ;
  - `test_removed_item_is_deleted_with_cards` ;
  - `test_item_without_generation_is_published_without_cards` ;
  - `test_quota_refunded_only_when_no_claude_call_on_reimport` (reload_count 1 → 0 et monthly 1 → 0 avec `claude_calls=0` ; inchangé avec `claude_calls=2` ; premier import : rien) ;
  - `test_second_publish_is_a_noop` (retourne `None`) ;
  - `test_college_pages_replaced_and_draft_cleared` ;
  - `test_summary_persisted_on_job`.
  Run : Expected FAIL.

- [ ] **Step 2: Implémentation** — `publish.py` selon l'algorithme.

- [ ] **Step 3: Vérifier et commit**

Run: `.venv/bin/python -m pytest tests/services/test_publish.py -q` — Expected: PASS.
```bash
git add collega_backend/app/services/generation/publish.py collega_backend/tests/services/test_publish.py
git commit -m "feat(chantier-1): bascule transactionnelle d'un import (inchangé / modifié / nouveau / supprimé)"
```

---

### Task 9: Génération par item, réutilisation, worker de génération

**Files:**
- Create: `collega_backend/app/services/generation/pipeline.py`
- Modify: `collega_backend/app/workers/generation_worker.py`
- Delete: `collega_backend/app/services/generation/card_generator.py`, `collega_backend/app/services/generation/hash_sharing.py`, `tests/services/test_card_generator.py`, `tests/services/test_token_usage_capture.py`, tests de hash-sharing
- Test: `collega_backend/tests/services/test_generation_pipeline.py` (pg), adapter `tests/workers/test_generation_worker.py`

**Interfaces:**
- Consumes: `store.*`, `GENERATION_VERSION`, `ClaudeClient.generate_cards`, `publish_job`, `stale_pdfs`, `fail_job`, `report_generation_progress` (déplacée ici depuis `card_generator.py`, même signature).
- Produces: `async generate_job_items(session_factory, job_id, claude, progress=None) -> int | None` (nombre d'appels Claude de **cette** exécution ; `None` si arrêté) ; `generate_college_cards(ctx, college_id, job_id, pdf_path)` (signature ARQ inchangée).

`generate_job_items` :
```python
async with session_factory() as db:
    drafts = job_items du job triés par item_number ; college_id
claude_calls = 0 ; cards = cards déjà générées (drafts avec generation_id) ; done = nb drafts avec generation_id
await _report(... items_done=done, items_total=len(drafts), cards=...)
for draft in drafts (sans generation_id):
    async with session_factory() as db:
        status = select GenerationJob.status ; None ou "failed" → return None
        gen = await store.find_generation(db, draft.text_hash, GENERATION_VERSION)
        if gen is None:
            text = await store.get_item_text(db, draft.text_hash)
    if gen is None:
        result = await claude.generate_cards(draft.item_number, draft.rang, text)   # aucune session ouverte ici
        claude_calls += 1
    async with session_factory() as db:
        if gen is None:
            job.input_tokens = (job.input_tokens or 0) + result.input_tokens ; idem output
            if result.cards:
                gen = await store.put_generation(db, draft.text_hash, GENERATION_VERSION,
                    [{"card_type": c.card_type, "recto": c.recto, "verso": c.verso} for c in result.cards],
                    GENERATION_MODEL, result.input_tokens, result.output_tokens)
        if gen is not None:
            update job_items set generation_id = gen.id where (job_id, item_number)
        await record_job_event(db, job_id, "generation_progress", message=f"item {draft.item_number}")
        await db.commit()
    publier l'avancement (items_done, cards, preview = 3 derniers rectos)
return claude_calls
```
Un item sans fiche (`result.cards` vide) garde `generation_id = NULL` et n'est pas retenté dans la même exécution. L'événement `generation_progress` par item sert aussi de « progression » au cron des jobs bloqués ; si `record_job_event` n'accepte pas ce type, l'ajouter.

`generate_college_cards` :
```python
job_uuid = uuid.UUID(job_id)
try:
    async with async_session_factory() as db:
        job = await db.get(GenerationJob, job_uuid)
        if job is None or job.status != "ocr_complete":
            return {"error": "invalid_job_state"}
        await record_job_event(db, job_uuid, "generation_started"); await db.commit()
    calls = await generate_job_items(async_session_factory, job_uuid, ClaudeClient(), report_generation_progress)
    if calls is None:
        return {"error": "cancelled"}
    async with async_session_factory() as db:
        college = await db.get(College, uuid.UUID(college_id))
        was_ready = college.status == CollegeStatus.generation_complete
        summary = await publish_job(db, job_uuid, claude_calls=_total_claude_calls(...))
        await db.commit()
    if summary is None:
        return {"error": "invalid_job_state"}
    for path in stale_pdfs(uuid.UUID(college_id), job_uuid): path.unlink(missing_ok=True)
    notification : send_generation_complete(token, ref_id, summary.as_dict() if was_ready else None)  (best-effort)
    return {"college_id": college_id, "job_id": job_id, **summary.as_dict()}
except BaseException as exc:
    await fail_job(async_session_factory, job_uuid, f"Génération : {exc!r}"[:500])
    raise
```
`claude_calls` total pour le quota : une relance ARQ ne voit que ses propres appels ; le total fiable est « le job a-t-il consommé des tokens » → passer `claude_calls = 0 if (job.input_tokens or 0) == 0 else max(calls, 1)` à `publish_job` (relire `job.input_tokens` dans la session de bascule).

- [ ] **Step 1: Tests (pg)** avec `FakeClaude` (compte les appels, renvoie `CardGenResult` paramétrable, peut lever à l'appel n) :
  - `test_generates_each_draft_and_publishes` ;
  - `test_reuses_existing_generation_without_calling_claude` (même empreinte déjà générée par un autre collège d'une autre utilisatrice → 0 appel ; fiches copiées = sortie d'origine même si l'autre utilisatrice a régénéré sa fiche) ;
  - `test_new_generation_version_calls_claude_again` (monkeypatch `GENERATION_VERSION`) ;
  - `test_crash_midway_then_retry_does_not_repay` (FakeClaude lève à l'item 2 → job `failed` via `generate_college_cards` ; remettre le job `ocr_complete` comme le ferait une relance ARQ ; 2e exécution → FakeClaude appelé seulement pour les items restants) ;
  - `test_tokens_accumulated_even_without_cards` ;
  - `test_stop_between_items` ;
  - `test_same_pdf_reimport_zero_calls_quota_refunded_summary_no_change` (bout en bout : `run_ocr` Task 7 avec FakeProcessor + `generate_college_cards` deux fois sur le même collège) ;
  - `test_old_pdf_deleted_after_publish_current_kept`.
  Run : Expected FAIL.

- [ ] **Step 2: Implémentation** — `pipeline.py`, réécriture de `generation_worker.py`, suppression de `card_generator.py`/`hash_sharing.py` et de leurs tests ; `grep -rn "card_generator\|hash_sharing\|SHA256SimilarityChecker" app tests` doit être vide (déplacer `report_generation_progress` dans `pipeline.py` et mettre à jour ses imports, y compris `test_generation_progress` éventuel).

- [ ] **Step 3: Vérifier et commit**

Run: `.venv/bin/python -m pytest tests/services tests/workers -q` — Expected: PASS.
```bash
git add -A collega_backend/app/services/generation collega_backend/app/workers/generation_worker.py collega_backend/tests
git commit -m "feat(chantier-1): génération par item réutilisable et partagée, relance sans repayer Claude"
```

---

### Task 10: Contrat d'API — statut du job, SSE, PDF endommagé, Stop admin

**Files:**
- Create: `collega_backend/app/services/ocr/pdf_check.py`
- Modify: `collega_backend/app/api/v1/colleges.py`, `collega_backend/app/api/v1/admin.py`, `collega_backend/app/schemas/college.py`
- Test: `collega_backend/tests/api/test_import_status_contract.py` (pg, via `AsyncClient` + override `get_db` sur `pg_factory` et `get_current_user`), `collega_backend/tests/api/test_pdf_damaged.py`, adapter `tests/api/test_colleges_stream.py`, `tests/api/test_admin_*stop*`

**Interfaces:**
- Produces: `async assert_pdf_readable(path: Path) -> int` (lève `HTTPException(422, {"code": "PDF_DAMAGED", "message": "Ce PDF est endommagé : il ne s'ouvre pas. Réessaie avec une autre copie."})`, sinon renvoie le nombre de pages) ; `CollegeStatusData.summary: dict | None = None` et `CollegeStatusData.reimport: bool = False`.

Changements :
1. `/status` : `status = latest_job.status if latest_job else college.status` ; `summary = json.loads(latest_job.summary_json)` si présent et job `generation_complete` ; `reimport = latest_job is not None and college.status == "generation_complete" and latest_job.status == "failed"`.
2. SSE : la route n'utilise plus `Depends(get_db)` ; vérification d'accès dans `async with async_session_factory() as s:` avant de construire le flux. Dans la boucle : lire `college` **et** le dernier job (même session courte) ; `status = job.status if job else college.status` remplace `c.status` dans toutes les conditions ; `generation_complete` → `data` inclut `"summary": json.loads(job.summary_json) if job.summary_json else None` ; `failed` → `data` inclut `"message": job.error_message, "reimport": college.status == "generation_complete"`.
3. PDF endommagé : dans `import_college_pdf`, **déplacer** `_apply_reimport_quota` après l'écriture du fichier, puis `await assert_pdf_readable(pdf_file_path)` (supprimer le fichier et relever sur échec) avant le quota. Dans `complete_chunked_import` : `await assert_pdf_readable(assembled)` juste après `store.assemble` (dans le `try`, le `except HTTPException` existant purge les morceaux car 422 ≠ 503). `assert_pdf_readable` appelle `OcrProcessor().count_pages` dans `asyncio.to_thread` ; exception ou 0 → 422.
4. Admin Stop : après l'abort ARQ, remplacer les lignes qui forcent le statut par `await fail_job(async_session_factory, job.id, "Annulé par l'admin", event="cancelled")` ; relire le job pour la réponse.

- [ ] **Step 1: Tests**
  - `test_status_follows_job_during_reimport_and_content_stays_readable` : collège `generation_complete` + items/fiches + job `processing` → `/status.status == "processing"`, `/items` 200, `/cards` 200.
  - `test_status_exposes_summary_after_reimport`.
  - `test_status_reimport_failed_flag`.
  - `test_stream_emits_summary_on_completion` et `test_stream_stops_on_job_failure_with_reimport_flag` (patch `_SSE_POLL_INTERVAL = 0.01`).
  - `test_stream_does_not_hold_request_session` : la dépendance `get_db` n'est pas appelée par la route SSE (override `get_db` par un générateur qui lève) → 200.
  - `test_damaged_pdf_rejected_without_quota_or_job` : envoyer les octets de `%PDF-1.6\n` + déchets + `%%EOF` (magic valide, contenu illisible) sur `/import` pour un collège déjà `generation_complete` avec `reload_count=0` → 422 `PDF_DAMAGED`, `reload_count` toujours 0, aucun `GenerationJob` créé, aucun fichier restant dans `pdf_storage_path`.
  - `test_admin_stop_keeps_content_of_ready_college`.
  Run : Expected FAIL.

- [ ] **Step 2: Implémentation** selon « Changements ».

- [ ] **Step 3: Vérifier et commit**

Run: `.venv/bin/python -m pytest tests/api -q` — Expected: PASS.
```bash
git add collega_backend/app/api collega_backend/app/schemas/college.py collega_backend/app/services/ocr/pdf_check.py collega_backend/tests/api
git commit -m "feat(chantier-1): statut d'import suivi par job, SSE sans session retenue, PDF endommagé refusé, Stop sans perte"
```

---

### Task 11: Purges, suppression de compte, régénération, crons

**Files:**
- Create: `collega_backend/app/services/content/purge.py`, `collega_backend/app/workers/maintenance_worker.py`
- Modify: `collega_backend/app/api/v1/auth.py` (`delete_account`), `collega_backend/app/api/v1/admin.py` (`delete_college`), `collega_backend/app/api/v1/flash_cards.py` (`regenerate_card`), `collega_backend/app/workers/cleanup_worker.py` (retirer `cleanup_ocr_text`), `collega_backend/app/workers/settings.py`
- Test: `collega_backend/tests/services/content/test_purge.py` (pg), `collega_backend/tests/workers/test_maintenance_worker.py` (pg), adapter `tests/workers/test_cleanup_worker.py`, `tests/api/test_flash_cards*.py`, `tests/api/test_auth.py` (suppression de compte)

**Interfaces:**
- Produces:
  - `async purge_unreferenced_content(db) -> dict[str, int]` (supprime, dans cet ordre, `item_generations` puis `item_texts` puis `ocr_pages` non référencés ; renvoie les compteurs ; ne commit pas).
  - `delete_college_pdfs(college_id) -> int`, `purge_orphan_pdfs(active_pdf_names: set[str], now) -> int` (supprime les `*.pdf` du stockage absents de l'ensemble et les `incoming_*.pdf` de plus de 24 h).
  - `async fail_stale_jobs(ctx) -> int`, `async purge_content(ctx) -> None` (crons).

SQL des purges (Postgres) :
```sql
DELETE FROM item_generations g
WHERE NOT EXISTS (SELECT 1 FROM flash_cards f WHERE f.generation_id = g.id)
  AND NOT EXISTS (SELECT 1 FROM job_items j WHERE j.generation_id = g.id)
  AND NOT EXISTS (SELECT 1 FROM items i WHERE i.text_hash = g.text_hash)
  AND NOT EXISTS (SELECT 1 FROM job_items j2 WHERE j2.text_hash = g.text_hash);
DELETE FROM item_texts t
WHERE NOT EXISTS (SELECT 1 FROM items i WHERE i.text_hash = t.hash)
  AND NOT EXISTS (SELECT 1 FROM job_items j WHERE j.text_hash = t.hash)
  AND NOT EXISTS (SELECT 1 FROM item_generations g WHERE g.text_hash = t.hash);
DELETE FROM ocr_pages p
WHERE NOT EXISTS (SELECT 1 FROM job_pages j WHERE j.page_hash = p.hash)
  AND NOT EXISTS (SELECT 1 FROM college_pages c WHERE c.page_hash = p.hash);
```
Fichiers actifs pour `purge_orphan_pdfs` : `{college_id}_{job_id}.pdf` pour chaque job actif **et** pour le dernier job `generation_complete` de chaque collège.

`fail_stale_jobs` : jobs actifs dont `max(generation_job_events.created_at, job.updated_at) < now - 30 min` ; ignorer ceux dont `arq:in-progress:{arq_job_id}` existe dans `ctx["redis"]` ; pour les autres `fail_job(async_session_factory, id, "Import bloqué : aucune progression depuis 30 min", event="stale")`.

Crons dans `WORKER_SETTINGS` : retirer `cron(cleanup_ocr_text, minute=0)` ; ajouter `cron(fail_stale_jobs, minute={0, 10, 20, 30, 40, 50})` et `cron(purge_content, hour=4, minute=15)` (`purge_content` = `purge_unreferenced_content` + commit + `purge_orphan_pdfs`).

`delete_account` : avant `db.delete(current_user)`, lister les ids de ses collèges ; après commit : `delete_college_pdfs` pour chacun, puis `purge_unreferenced_content` + commit (best-effort, logguer les erreurs). `delete_college` (admin) : après la suppression existante des PDF, `purge_unreferenced_content` + commit.

`regenerate_card` : `source = await store.get_item_text(db, item.text_hash) if item.text_hash else None` ; `None` → 409 `{"code": "SOURCE_UNAVAILABLE", "message": "Le texte source de cet item n'est pas disponible : réimporte le PDF pour pouvoir régénérer."}` ; appel `claude.regenerate_single_card(card, item, source, body.user_note)` ; après mise à jour : `card.generation_id = None`.

- [ ] **Step 1: Tests**
  - purge : contenu d'un collège supprimé → ses pages/textes/générations disparaissent ; contenu partagé avec un 2e collège (même empreintes) → conservé ; une génération référencée seulement par une `job_items` en cours → conservée.
  - suppression de compte (pg + fichiers tmp) : PDF de ses collèges supprimés, contenu non partagé purgé.
  - `fail_stale_jobs` : job actif avec dernier événement à -31 min → `failed` événement `stale` ; à -5 min → intact ; présent dans `arq:in-progress` (FakeRedis de `tests/fakes/fake_redis.py`) → intact.
  - `purge_orphan_pdfs` : PDF courant gardé, ancien supprimé, `incoming_` récent gardé, ancien supprimé.
  - régénération : texte présent → Claude reçoit le texte, `generation_id` remis à NULL ; item sans `text_hash` → 409 `SOURCE_UNAVAILABLE`.
  Run : Expected FAIL.

- [ ] **Step 2: Implémentation**.

- [ ] **Step 3: Vérifier et commit**

Run: `.venv/bin/python -m pytest -q` (suite complète, Postgres de test lancé) — Expected: PASS, et `grep -rn "ocr_text\|page_texts_json\|cleanup_ocr_text" app` ne renvoie que des occurrences légitimes (le prompt `{ocr_text}` de `claude_client.py` peut garder son nom de variable de format).
```bash
git add -A collega_backend/app collega_backend/tests
git commit -m "feat(chantier-1): purges du contenu non référencé, suppression de compte complète, régénération sans limite de temps, cron des jobs bloqués"
```

---

### Task 12: Remplissage des collèges existants

**Files:**
- Create: `collega_backend/scripts/backfill_content_store.py`
- Test: `collega_backend/tests/scripts/test_backfill_content_store.py` (pg)

**Interfaces:**
- Consumes: `store.put_page`, `store.put_item_text`, `ItemDetector`, `OcrProcessor`, déduplication de `ocr_worker` (extraire la fonction `dedupe_items(detected) -> list[DetectedItem]` dans `ocr_worker.py` en Task 7 si ce n'est pas déjà fait, et l'importer ici).
- Produces: `async backfill_college(db, college_id, processor, pdf_dir: Path) -> dict` (`{"pages", "matched", "unmatched"}`) ; CLI `python -m scripts.backfill_content_store [--dry-run] [--college <uuid>]`.

Comportement : PDF = `{college_id}_{job_id}.pdf` du dernier job `generation_complete` (absent → rapport « PDF manquant », collège ignoré) ; OCR page par page (`asyncio.to_thread`) → `put_page` + `college_pages` (remplace l'existant) ; détection + dédoublonnage ; pour chaque item détecté dont le numéro existe dans `items` du collège : `put_item_text` puis `items.text_hash = h` ; **aucune** création/suppression d'item ou de fiche, aucune `item_generations`. `--dry-run` : rollback final, rapport identique. Commit par collège. Idempotent.

- [ ] **Step 1: Tests** : collège avec 2 items vivants (304, 305) et fiches, PDF factice + FakeProcessor (pages des items 304 et 306) → `matched=1`, `unmatched=1` (306), `items[304].text_hash` renseigné, `items[305].text_hash` NULL, fiches inchangées ; 2e exécution → mêmes compteurs, aucune ligne en double ; `--dry-run` → rien écrit.

- [ ] **Step 2: Implémentation** (logger chaque collège : pages, rapprochés, non rapprochés).

- [ ] **Step 3: Vérifier et commit**

Run: `.venv/bin/python -m pytest tests/scripts/test_backfill_content_store.py -q` — Expected: PASS.
```bash
git add collega_backend/scripts/backfill_content_store.py collega_backend/tests/scripts collega_backend/app/workers/ocr_worker.py
git commit -m "feat(chantier-1): commande de remplissage du stockage de contenu pour les collèges existants"
```

---

### Task 13: App — résumé et échec de réimport

**Files:**
- Modify: `collega_app/lib/features/colleges/domain/import_models.dart` (`ImportComplete.summary`, `CollegeStatusResponse.summary`/`reimport`, classe `ImportSummary`), `collega_app/lib/features/colleges/colleges_import_providers.dart`, `collega_app/lib/features/colleges/domain/import_messages.dart`, `collega_app/lib/features/colleges/presentation/import_progress_screen.dart`
- Test: `collega_app/test/features/colleges/import_summary_test.dart`, `college_import_notifier_test.dart`, `import_progress_screen_test.dart` (existants à compléter)

**Interfaces:**
- Produces (Dart) :
```dart
class ImportSummary {
  const ImportSummary({required this.changed, required this.added, required this.removed, required this.unchanged, required this.quotaRefunded});
  factory ImportSummary.fromJson(Map<String, dynamic> j) => ImportSummary(
        changed: j['changed'] as int? ?? 0, added: j['added'] as int? ?? 0,
        removed: j['removed'] as int? ?? 0, unchanged: j['unchanged'] as int? ?? 0,
        quotaRefunded: j['quota_refunded'] as bool? ?? false);
  final int changed, added, removed, unchanged;
  final bool quotaRefunded;
  bool get nothingChanged => changed == 0 && added == 0 && removed == 0;
}
String importSummaryText(ImportSummary s); // mêmes règles que completion_message côté serveur
```
- `ImportComplete({required collegeId, ImportSummary? summary})` ; `ImportError(message: 'reimport_failed')` quand l'événement `generation_failed` a `reimport: true` (ou `/status` avec `reimport: true`).

Comportement :
- `_handleSseEvent` : `generation_complete` → `ImportComplete(collegeId, summary: data['summary'] is Map ? ImportSummary.fromJson(...) : null)` ; `generation_failed` → `ImportError(message: data['reimport'] == true ? 'reimport_failed' : 'generation_failed')`. Même logique dans `_reconnectIfActive` à partir de `CollegeStatusResponse`.
- `importErrorMessage('reimport_failed', …)` → « Le réimport n’a pas abouti. Tes fiches actuelles sont intactes. »
- `ImportProgressScreen._openCollege` : si `summary != null`, après `context.go`, `showCgToast(context, importSummaryText(summary))` (texte : « 3 items mis à jour, 1 nouveau, 20 inchangés » ; si rien n’a changé : « Aucun changement dans ce PDF » + « : réimport non décompté » si `quotaRefunded`).

- [ ] **Step 1: Tests Dart** : `importSummaryText` (cas changé, aucun changement décompté / non décompté, pluriels) ; notifier : événement `generation_complete` avec `summary` → `ImportComplete.summary` renseigné ; `generation_failed` avec `reimport: true` → `ImportError('reimport_failed')` ; écran : `ImportError('reimport_failed')` affiche le message « Tes fiches actuelles sont intactes ».
  Run: `cd collega_app && flutter test test/features/colleges` — Expected: FAIL.
- [ ] **Step 2: Implémentation**.
- [ ] **Step 3: Vérifier et commit**

Run: `flutter test test/features/colleges test/core` et `flutter analyze lib/features/colleges` — Expected: PASS / aucune nouvelle issue.
```bash
git add collega_app/lib/features/colleges collega_app/test/features/colleges
git commit -m "feat(chantier-1): l'app affiche le résumé d'un réimport et son échec sans perte"
```

---

### Task 14: Documentation, mémoire, vérification finale

**Files:**
- Modify: `_bmad-output/planning-artifacts/architecture.md` (NFR9 et § stockage), `collega_app/assets/legal/privacy.md`, `collega_backend/docs/restore.md`, `_bmad-output/planning-artifacts/audit-back-infra-2026-09-23.md` (chantier 1 → fait après déploiement)

- [ ] **Step 1: architecture.md** — remplacer chaque mention de NFR9 « texte OCR supprimé ≤ 24h » par « texte OCR conservé avec le collège (stockage par empreinte `ocr_pages`/`item_texts`), supprimé avec lui ; décision chantier 1 du 2026-09-23 » ; remplacer la ligne `cleanup_worker.py # suppression ocr_text ≤ 24h (NFR9)` par `maintenance_worker.py # jobs bloqués, purge du contenu non référencé`.
- [ ] **Step 2: privacy.md** — dans le tableau des données, après « PDF de collèges importés », ajouter la ligne `| Texte extrait des PDF | Traitement de l’import | Génération et régénération des fiches |` ; dans « Durées de conservation », après la ligne PDF : `- **Texte extrait des PDF** : conservé tant que le collège associé est dans ton compte, supprimé avec lui.`
- [ ] **Step 3: restore.md** — dans « Vérifier un dump », ajouter le comptage `select count(*) from ocr_pages; select count(*) from item_texts; select count(*) from item_generations;` et la remarque « les nouvelles tables sont dans le même dump, rien à faire de plus ».
- [ ] **Step 4: Vérification complète**

Run (Postgres de test lancé) : `cd collega_backend && .venv/bin/python -m pytest -q` deux fois de suite — Expected: tout vert les deux fois.
Run : `cd collega_app && flutter test test/features/colleges test/core test/features/today test/features/drill` — Expected: PASS.
- [ ] **Step 5: Commit**
```bash
git add _bmad-output/planning-artifacts/architecture.md collega_app/assets/legal/privacy.md collega_backend/docs/restore.md
git commit -m "docs(chantier-1): texte OCR conservé avec le collège (NFR9 remplacée), restauration et confidentialité à jour"
```

---

### Task 15: Déploiement et validation (avec l'utilisateur)

Suivre `collega_backend/docs/restore.md` et le runbook de déploiement (mémoire Kage « Déployer le backend Collega sur le NAS »).

- [ ] **Step 1:** image `tistech0/collega-backend:<sha>` + `latest`, contenu vérifié (`grep -c publish_job app/services/generation/publish.py`), push.
- [ ] **Step 2:** sur le NAS : aucun job actif (`arq:in-progress` et `arq:queue` à 0) ; dump : `docker exec collega-db-1 sh -c 'pg_dumpall -U postgres' | gzip > /mnt/user/appdata/collega/backups/collega_pre_chantier1_$(date +%Y%m%d-%H%M).sql.gz`.
- [ ] **Step 3:** `docker compose pull -q api worker migrate && docker compose up -d` ; attendre `healthy` ; `docker logs collega-migrate-1` montre `017 -> 018` ; `/health` OK.
- [ ] **Step 4:** `docker exec collega-worker-1 python -m scripts.backfill_content_store --dry-run` puis sans `--dry-run` ; vérifier `select count(*) from items where text_hash is null` (items non rapprochés attendus : 0 ou listés dans le rapport).
- [ ] **Step 5 (utilisateur) :** réimport de PNEUMO (même fichier) depuis l'iPhone → toast « Aucun changement dans ce PDF : réimport non décompté », 0 token pour ce job dans la console admin, quota inchangé, progression PNEUMO intacte ; `collega-health` n'a rien signalé.
- [ ] **Step 6:** fusion dans `main` (après accord), push, mémoire Kage (`kage_learn` : architecture du stockage de contenu, bascule, piège « normalisation des numéros de page ») ; `kage_refresh` + `kage_pr_check`.

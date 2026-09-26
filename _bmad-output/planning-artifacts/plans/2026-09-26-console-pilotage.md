# Console de pilotage de la beta — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer la console admin MVP par un poste de pilotage de la beta (activité des testeuses, imports, qualité, coûts) au style de l'app, alimenté par un résumé d'activité envoyé par l'app, avec alerte Telegram sur import en échec.

**Architecture:** Backend FastAPI : deux colonnes/tables nouvelles (`users.last_seen_at`, `activity_days`), un service `admin_pilot` qui calcule accueil, pastilles et fiche testeuse, une commande `scripts.import_alerts` lue par le script de santé du NAS. Front : modules ES natifs sans build servis par `StaticFiles` sous `/admin`. App Flutter : un `ActivityReporter` qui envoie les compteurs du jour (`PUT /v1/activity/{day}`, idempotent).

**Tech Stack:** Python 3.11, FastAPI, SQLAlchemy 2 async, Alembic, Postgres (tests `pg`), pytest ; HTML/CSS/JS (ES2022, modules natifs) ; Flutter 3.27.1, Riverpod, Dio, drift.

**Spec:** `_bmad-output/planning-artifacts/console-pilotage-spec.md` (lire aussi son § 7 « Amendements »).

## Global Constraints

- Branche : `feat/console-pilotage` (existe déjà, contient la spec). Ne pas merger, ne pas déployer, ne pas pousser sans demande : l'utilisateur relit à la fin.
- Erreurs : toujours `AppError` / fabriques de `app/core/errors.py`, jamais `HTTPException`. Format `{"detail": {"code", "message"}}` ; succès `{"data": …}`.
- Couches : `app/api/v1` = HTTP seulement ; logique dans `app/services`.
- Qualité backend (depuis `collega_backend/`) : `.venv/bin/ruff check .`, `.venv/bin/ruff format --check .`, `.venv/bin/mypy app/core app/services` (0 erreur), `docker compose -f docker-compose.test.yml up -d` puis `.venv/bin/python -m pytest -q`, `.venv/bin/alembic check` (avec la base de test migrée).
- App : `flutter test` **par dossier** (`test/core`, puis chaque `test/features/<dossier>`), jamais toute la suite.
- **Aucun emoji** : ni dans la console, ni dans les messages Telegram, ni dans les textes ajoutés.
- Couleurs, typo, icônes : uniquement celles de l'app (`collega_app/lib/core/ui/tokens/*`, `cg_icon.dart`). Police Instrument Sans servie localement (pas de Google Fonts).
- Aucune dépendance npm, aucune étape de build front, aucune bibliothèque de graphiques.
- Tout texte venant de la base (e-mails, recto/verso, messages d'erreur) est inséré dans le DOM via `textContent`, jamais `innerHTML`.
- Seuls SVG insérés en `innerHTML` : ceux de `icons.js` (générés depuis le dépôt).
- Contenu publié (confidentialité) : éditeur Matthis Lesur, contact@matthislesur.com.
- Mémoire : `kage_learn` pour les apprentissages durables, `kage_refresh` puis `kage_pr_check` avant de rendre la main (voir `CLAUDE.md`).

## Review Focus

1. **Base vide ou testeuse sans activité** : l'accueil, la fiche testeuse et les pastilles doivent s'afficher avec des zéros et des états vides lisibles, jamais une erreur 500 ni un `NaN` — tests : Task 4 (`test_pilot_base_vide`), Task 5 (`test_detail_sans_activite`).
2. **App qui renvoie plusieurs fois le même jour, ou un jour hors borne** : jamais de double compte ; `422 ACTIVITY_DAY_OUT_OF_RANGE` pour un jour trop ancien ou futur — tests : Task 2.
3. **Collège ou compte supprimé pendant qu'un import est suivi** : `college_name` inconnu → « Collège n°X », e-mail absent → « compte supprimé » ; la commande d'alerte ne plante pas — tests : Task 3 (`college_name` inconnu), Task 6 (job d'un collège sans nom connu).
4. **Texte hostile venant de la base** (`<img onerror>` dans un recto ou un e-mail) : affiché tel quel, jamais interprété — test : Task 7 (`test_admin_front_n_utilise_pas_innerhtml_hors_icones`).
5. **Premier passage de la commande d'alerte en prod** (historique d'échecs déjà en base) : aucune rafale de messages ; seuls les échecs postérieurs au premier passage sont annoncés — test : Task 6 (`test_premier_passage_silencieux`).

---

## Carte des fichiers

Backend (`collega_backend/`) :
- Create `alembic/versions/022_activity_last_seen.py` — colonne `users.last_seen_at`, table `activity_days`.
- Create `app/models/activity_day.py` ; Modify `app/models/user.py`, `app/models/__init__.py`.
- Create `app/services/activity.py` — `touch_last_seen`, `check_day_in_range`, `upsert_day`.
- Create `app/schemas/activity.py`, `app/api/v1/activity.py` ; Modify `app/main.py`, `app/api/v1/auth.py`.
- Create `scripts/gen_admin_assets.py` → génère `app/core/college_catalog.py` et `app/static/admin/js/icons.js`.
- Create `app/services/admin_pilot.py`, `app/schemas/admin_pilot.py`, `app/api/v1/admin/pilot.py` ; Modify `app/api/v1/admin/__init__.py`, `app/api/v1/admin/users.py`, `app/api/v1/admin/config.py`, `app/api/v1/admin/colleges.py`, `app/schemas/admin.py`, `app/services/app_settings.py`.
- Create `scripts/import_alerts.py` ; Modify `ops/nas/collega-health.sh`, `docs/deployment.md`.
- Replace `app/static/admin/index.html` ; Create `app/static/admin/css/{tokens,ui}.css`, `app/static/admin/fonts/*.ttf`, `app/static/admin/js/{main,api,router,ui,icons}.js`, `app/static/admin/js/views/{login,pilotage,testeuses,testeuse,imports,import,qualite,couts,reglages}.js`.
- Modify `app/static/legal/privacy.md`.
- Tests : `tests/api/test_activity_pg.py`, `tests/scripts/test_gen_admin_assets.py`, `tests/api/test_admin_pilot_pg.py`, `tests/api/test_admin_user_detail_pg.py` (remplace `tests/api/test_admin_user_detail.py`), `tests/scripts/test_import_alerts_pg.py`, `tests/api/test_admin_front_assets.py`.

App (`collega_app/`) :
- Modify `lib/core/ui/foundation/cg_icon.dart` (icônes `euro`, `settings`).
- Create `lib/features/today/data/activity_reporter.dart` ; Modify `lib/features/drill/drill_providers.dart`, `lib/app.dart`, `assets/legal/privacy.md`.
- Test `test/features/today/activity_reporter_test.dart`.

---

### Task 1: Données — `users.last_seen_at` et table `activity_days`

**Files:**
- Create: `collega_backend/alembic/versions/022_activity_last_seen.py`
- Create: `collega_backend/app/models/activity_day.py`
- Modify: `collega_backend/app/models/user.py`, `collega_backend/app/models/__init__.py`
- Test: `collega_backend/tests/api/test_activity_pg.py` (premier test)

**Interfaces:**
- Produces: `User.last_seen_at: datetime | None` ; modèle `ActivityDay(user_id: UUID, day: date, cards_reviewed: int, session_completed: bool, streak: int, updated_at: datetime)`, table `activity_days`, PK `(user_id, day)`, FK `users.id ON DELETE CASCADE`.

- [ ] **Step 1: Démarrer la base de test**

Run (depuis `collega_backend/`) : `docker compose -f docker-compose.test.yml up -d`

- [ ] **Step 2: Écrire le test qui échoue**

`tests/api/test_activity_pg.py` :

```python
"""Activité des testeuses : last_seen_at et PUT /v1/activity/{day} (console de pilotage)."""

from __future__ import annotations

from datetime import date

import pytest
from sqlalchemy import select

from app.models.activity_day import ActivityDay
from tests.factories import make_user

pytestmark = pytest.mark.pg


async def test_activity_day_cascade_a_la_suppression_du_compte(pg_session):
    user = await make_user(pg_session)
    pg_session.add(
        ActivityDay(user_id=user.id, day=date(2026, 9, 26), cards_reviewed=3, session_completed=True, streak=2)
    )
    await pg_session.flush()
    assert user.last_seen_at is None

    await pg_session.delete(user)
    await pg_session.flush()
    rows = (await pg_session.execute(select(ActivityDay))).scalars().all()
    assert rows == []
```

- [ ] **Step 3: Vérifier l'échec**

Run: `.venv/bin/python -m pytest tests/api/test_activity_pg.py -q`
Expected: FAIL `ModuleNotFoundError: No module named 'app.models.activity_day'`

- [ ] **Step 4: Modèle**

`app/models/activity_day.py` :

```python
"""Résumé quotidien d'activité envoyé par l'app (console de pilotage de la beta).

Une ligne par utilisatrice et par jour local de l'app : l'app renvoie toujours le
total du jour, la ligne est remplacée (jamais additionnée)."""

import uuid
from datetime import UTC, date, datetime

from sqlalchemy import Boolean, CheckConstraint, Date, DateTime, ForeignKey, Integer
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class ActivityDay(Base):
    __tablename__ = "activity_days"
    __table_args__ = (
        CheckConstraint("cards_reviewed >= 0", name="ck_activity_days_cards_reviewed"),
        CheckConstraint("streak >= 0", name="ck_activity_days_streak"),
    )

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    day: Mapped[date] = mapped_column(Date, primary_key=True)
    cards_reviewed: Mapped[int] = mapped_column(Integer, nullable=False)
    session_completed: Mapped[bool] = mapped_column(Boolean, nullable=False)
    streak: Mapped[int] = mapped_column(Integer, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=lambda: datetime.now(UTC), onupdate=lambda: datetime.now(UTC)
    )
```

Dans `app/models/user.py`, après `subscription_event_at` :

```python
    # Dernière ouverture de l'app (login, refresh, /me, envoi d'activité), écrite au plus
    # toutes les 10 min (services/activity.py). NULL : jamais connectée depuis la création.
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
```

La relation `User.flash_cards` a `cascade="all, delete-orphan"` : pour que `db.delete(user)` n'essaie pas de mettre `user_id` à NULL sur `activity_days`, **ne pas** déclarer de relation ORM vers `ActivityDay` (la FK `ON DELETE CASCADE` suffit).

Dans `app/models/__init__.py` : `from app.models.activity_day import ActivityDay` et `"ActivityDay"` dans `__all__` (ordre alphabétique).

- [ ] **Step 5: Migration**

`alembic/versions/022_activity_last_seen.py` :

```python
"""console de pilotage : users.last_seen_at et activity_days

Revision ID: 022
Revises: 021
Create Date: 2026-09-26
"""

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision = "022"
down_revision = "021"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True))
    op.create_table(
        "activity_days",
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            primary_key=True,
        ),
        sa.Column("day", sa.Date(), primary_key=True),
        sa.Column("cards_reviewed", sa.Integer(), nullable=False),
        sa.Column("session_completed", sa.Boolean(), nullable=False),
        sa.Column("streak", sa.Integer(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.CheckConstraint("cards_reviewed >= 0", name="ck_activity_days_cards_reviewed"),
        sa.CheckConstraint("streak >= 0", name="ck_activity_days_streak"),
    )


def downgrade() -> None:
    op.drop_table("activity_days")
    op.drop_column("users", "last_seen_at")
```

- [ ] **Step 6: Vérifier**

Run: `.venv/bin/python -m pytest tests/api/test_activity_pg.py -q` → PASS.
Run: `.venv/bin/alembic check` (même URL de base que la CI : lire `.github/workflows/ci.yml` pour la variable `DATABASE_URL` utilisée, et migrer la base de test avec `.venv/bin/alembic upgrade head` avant) → `No new upgrade operations detected.` Si `alembic check` signale un écart (`server_default` de `updated_at`), aligner le modèle en ajoutant `server_default=func.now()` plutôt que de changer la migration.

- [ ] **Step 7: Commit**

```bash
git add collega_backend/alembic/versions/022_activity_last_seen.py collega_backend/app/models collega_backend/tests/api/test_activity_pg.py
git commit -m "feat(activité): users.last_seen_at et table activity_days"
```

---

### Task 2: Service d'activité, `PUT /v1/activity/{day}` et mise à jour de `last_seen_at`

**Files:**
- Create: `collega_backend/app/services/activity.py`, `collega_backend/app/schemas/activity.py`, `collega_backend/app/api/v1/activity.py`
- Modify: `collega_backend/app/main.py`, `collega_backend/app/api/v1/auth.py` (login, refresh, me)
- Test: `collega_backend/tests/api/test_activity_pg.py`

**Interfaces:**
- Consumes: `ActivityDay`, `User.last_seen_at` (Task 1).
- Produces:
  - `activity.LAST_SEEN_THROTTLE = timedelta(minutes=10)`
  - `activity.touch_last_seen(user: User, now: datetime) -> bool` (True si modifié ; l'appelant commite)
  - `activity.check_day_in_range(day: date, today: date) -> None` (lève `unprocessable("ACTIVITY_DAY_OUT_OF_RANGE", …)`)
  - `async activity.upsert_day(db, user_id: UUID, day: date, cards_reviewed: int, session_completed: bool, streak: int) -> None`
  - Route `PUT /v1/activity/{day}` (jour `YYYY-MM-DD`), corps `{"cards_reviewed", "session_completed", "streak"}`, réponse `{"data": {"day", "cards_reviewed", "session_completed", "streak"}}`.

- [ ] **Step 1: Tests qui échouent** (ajouter à `tests/api/test_activity_pg.py`)

```python
from datetime import UTC, datetime, timedelta

from httpx import AsyncClient

from app.models.user import User
from app.services import activity
from tests.api_pg import login_as


def _today() -> date:
    return datetime.now(UTC).date()


async def _user(pg_factory) -> User:
    async with pg_factory() as db:
        user = await make_user(db)
        await db.commit()
        return user


async def test_put_cree_puis_remplace_sans_additionner(pg_client: AsyncClient, pg_factory):
    user = await _user(pg_factory)
    login_as(user)
    day = _today().isoformat()
    body = {"cards_reviewed": 12, "session_completed": False, "streak": 3}
    resp = await pg_client.put(f"/v1/activity/{day}", json=body)
    assert resp.status_code == 200
    assert resp.json() == {"data": {"day": day, **body}}

    body2 = {"cards_reviewed": 20, "session_completed": True, "streak": 4}
    assert (await pg_client.put(f"/v1/activity/{day}", json=body2)).status_code == 200
    assert (await pg_client.put(f"/v1/activity/{day}", json=body2)).status_code == 200

    async with pg_factory() as db:
        rows = (await db.execute(select(ActivityDay).where(ActivityDay.user_id == user.id))).scalars().all()
        assert [(r.cards_reviewed, r.session_completed, r.streak) for r in rows] == [(20, True, 4)]
        assert (await db.get(User, user.id)).last_seen_at is not None


@pytest.mark.parametrize("offset", [2, -31])
async def test_put_jour_hors_borne_422(pg_client: AsyncClient, pg_factory, offset):
    login_as(await _user(pg_factory))
    day = (_today() + timedelta(days=offset)).isoformat()
    resp = await pg_client.put(f"/v1/activity/{day}", json={"cards_reviewed": 1, "session_completed": False, "streak": 0})
    assert resp.status_code == 422
    assert resp.json()["detail"]["code"] == "ACTIVITY_DAY_OUT_OF_RANGE"


@pytest.mark.parametrize(
    "body",
    [
        {"cards_reviewed": -1, "session_completed": False, "streak": 0},
        {"cards_reviewed": 5001, "session_completed": False, "streak": 0},
        {"cards_reviewed": 1, "session_completed": False, "streak": 3651},
    ],
)
async def test_put_compteurs_invalides_422(pg_client: AsyncClient, pg_factory, body):
    login_as(await _user(pg_factory))
    resp = await pg_client.put(f"/v1/activity/{_today().isoformat()}", json=body)
    assert resp.status_code == 422


async def test_put_sans_jeton_401(pg_client: AsyncClient):
    resp = await pg_client.put(f"/v1/activity/{_today().isoformat()}", json={"cards_reviewed": 1, "session_completed": False, "streak": 0})
    assert resp.status_code == 401


def test_touch_last_seen_au_plus_toutes_les_10_minutes():
    now = datetime(2026, 9, 26, 12, 0, tzinfo=UTC)
    user = User(last_seen_at=None)
    assert activity.touch_last_seen(user, now) is True
    assert user.last_seen_at == now
    assert activity.touch_last_seen(user, now + timedelta(minutes=9)) is False
    assert user.last_seen_at == now
    assert activity.touch_last_seen(user, now + timedelta(minutes=10)) is True
    assert user.last_seen_at == now + timedelta(minutes=10)
```

Test du login (même fichier) :

```python
async def test_login_ecrit_last_seen_at(pg_client: AsyncClient, pg_factory):
    from app.core.security import hash_password

    async with pg_factory() as db:
        user = await make_user(db)
        user.hashed_password = hash_password("motdepasse1")
        await db.commit()
    resp = await pg_client.post("/v1/auth/login", json={"email": user.email, "password": "motdepasse1"})
    assert resp.status_code == 200
    async with pg_factory() as db:
        assert (await db.get(User, user.id)).last_seen_at is not None
```

Note : `test_put_sans_jeton_401` doit s'exécuter sans `login_as` actif. `login_as` pose des `dependency_overrides` nettoyés par `pg_client` à la fin de chaque test : c'est suffisant tant que ce test ne partage pas de client avec un autre.

- [ ] **Step 2: Vérifier l'échec**

Run: `.venv/bin/python -m pytest tests/api/test_activity_pg.py -q` → FAIL (404 sur la route, `activity` introuvable).

- [ ] **Step 3: Service**

`app/services/activity.py` :

```python
"""Activité des testeuses (console de pilotage) : dernière ouverture et résumé quotidien."""

from __future__ import annotations

import uuid
from datetime import date, datetime, timedelta

from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import unprocessable
from app.models.activity_day import ActivityDay
from app.models.user import User

LAST_SEEN_THROTTLE = timedelta(minutes=10)
MAX_DAYS_BACK = 30
MAX_DAYS_AHEAD = 1  # jour local de l'app en avance sur l'UTC du serveur


def touch_last_seen(user: User, now: datetime) -> bool:
    """Met `last_seen_at` à `now` si elle est vide ou date de 10 min ou plus. L'appelant commite."""
    if user.last_seen_at is not None and now - user.last_seen_at < LAST_SEEN_THROTTLE:
        return False
    user.last_seen_at = now
    return True


def check_day_in_range(day: date, today: date) -> None:
    if not (today - timedelta(days=MAX_DAYS_BACK) <= day <= today + timedelta(days=MAX_DAYS_AHEAD)):
        raise unprocessable("ACTIVITY_DAY_OUT_OF_RANGE", "Jour d'activité hors de la période acceptée.")


async def upsert_day(
    db: AsyncSession,
    user_id: uuid.UUID,
    day: date,
    cards_reviewed: int,
    session_completed: bool,
    streak: int,
) -> None:
    """Remplace le résumé du jour (jamais d'addition : l'app envoie toujours le total)."""
    values = {"cards_reviewed": cards_reviewed, "session_completed": session_completed, "streak": streak}
    stmt = insert(ActivityDay).values(user_id=user_id, day=day, **values)
    stmt = stmt.on_conflict_do_update(
        index_elements=[ActivityDay.user_id, ActivityDay.day],
        set_={**values, "updated_at": stmt.excluded.updated_at},
    )
    await db.execute(stmt)
```

Attention : `stmt.excluded.updated_at` n'a de valeur que si l'INSERT la fournit ; le `default` Python de `updated_at` est appliqué par SQLAlchemy Core sur `insert()` — vérifier dans le test que `updated_at` change, sinon remplacer par `"updated_at": func.now()`.

- [ ] **Step 4: Schéma et route**

`app/schemas/activity.py` :

```python
from datetime import date

from pydantic import BaseModel, Field


class ActivityDayRequest(BaseModel):
    cards_reviewed: int = Field(..., ge=0, le=5000)
    session_completed: bool
    streak: int = Field(..., ge=0, le=3650)


class ActivityDayData(ActivityDayRequest):
    day: date


class ActivityDayResponseWrapped(BaseModel):
    data: ActivityDayData
```

`app/api/v1/activity.py` :

```python
"""Résumé quotidien d'activité envoyé par l'app (console de pilotage de la beta)."""

from __future__ import annotations

from datetime import UTC, date, datetime

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.deps import get_current_user, get_db
from app.models.user import User
from app.schemas.activity import ActivityDayData, ActivityDayRequest, ActivityDayResponseWrapped
from app.services import activity

router = APIRouter(tags=["activity"])


@router.put("/activity/{day}", response_model=ActivityDayResponseWrapped)
async def put_activity_day(
    day: date,
    body: ActivityDayRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ActivityDayResponseWrapped:
    now = datetime.now(UTC)
    activity.check_day_in_range(day, now.date())
    await activity.upsert_day(db, current_user.id, day, body.cards_reviewed, body.session_completed, body.streak)
    activity.touch_last_seen(current_user, now)
    await db.commit()
    return ActivityDayResponseWrapped(data=ActivityDayData(day=day, **body.model_dump()))
```

Dans `app/main.py` : `from app.api.v1.activity import router as activity_router` (avec les autres imports de routeurs) et `app.include_router(activity_router, prefix="/v1")` juste après `search_router`.

- [ ] **Step 5: `last_seen_at` dans l'authentification**

Dans `app/api/v1/auth.py`, ajouter `from app.services import activity` (à côté de `app_settings`) et :
- `login` : avant `return`, `if activity.touch_last_seen(user, datetime.now(UTC)): await db.commit()`
- `refresh` : juste avant `logger.debug("refresh : jeton renouvelé …")`, même ligne.
- `get_me` : après le calcul de `now`, `if activity.touch_last_seen(current_user, now): await db.commit()`.

Puis vérifier les tests d'authentification existants, qui utilisent un faux `db` : Run `.venv/bin/python -m pytest tests/api/test_auth.py tests/api/test_auth_rotation_pg.py -q`. Si un faux utilisateur (`SimpleNamespace`) n'a pas d'attribut `last_seen_at`, ajouter `last_seen_at=None` à sa fabrique dans le test concerné (ne pas rendre le code tolérant à l'absence d'attribut).

- [ ] **Step 6: Vérifier**

Run: `.venv/bin/python -m pytest tests/api/test_activity_pg.py tests/api/test_auth.py tests/api/test_auth_rotation_pg.py -q` → PASS.
Run: `.venv/bin/mypy app/core app/services` → 0 erreur.

- [ ] **Step 7: Commit**

```bash
git add collega_backend/app collega_backend/tests/api
git commit -m "feat(activité): PUT /v1/activity/{day} idempotent et last_seen_at"
```

---

### Task 3: Générateur d'assets partagés (noms de collèges, icônes) + 2 icônes

**Files:**
- Create: `collega_backend/scripts/gen_admin_assets.py`
- Create (généré) : `collega_backend/app/core/college_catalog.py`, `collega_backend/app/static/admin/js/icons.js`
- Modify: `collega_app/lib/core/ui/foundation/cg_icon.dart` (ajout `euro`, `settings`)
- Test: `collega_backend/tests/scripts/test_gen_admin_assets.py`

**Interfaces:**
- Produces:
  - `app.core.college_catalog.COLLEGE_NAMES: dict[int, str]` et `college_name(ref_id: int) -> str` (inconnu → `"Collège n°{ref_id}"`).
  - `icons.js` : `export const ICONS = { today: '<svg …>', … }` (toutes les clés de `CgIcons`, SVG avec `stroke="currentColor"`).
  - `python -m scripts.gen_admin_assets` (écrit) et `python -m scripts.gen_admin_assets --check` (code 1 si un fichier généré n'est pas à jour).

- [ ] **Step 1: Ajouter les deux icônes à l'app**

Dans `collega_app/lib/core/ui/foundation/cg_icon.dart`, dans `CgIcons`, après `sparkle` (même trait 1,8, grille 24) :

```dart
  static const euro = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6.5a7 7 0 1 0 0 11"/><path d="M4 10.5h9M4 13.5h9"/></svg>';
  static const settings = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 7h9M17 7h3M4 17h3M11 17h9"/><circle cx="15" cy="7" r="2"/><circle cx="9" cy="17" r="2"/></svg>';
```

Si un test de l'app liste les icônes (galerie, golden), le lancer : `cd collega_app && flutter test test/core` et régénérer un golden seulement si c'est la galerie d'icônes qui a changé (`--update-goldens` sur ce seul fichier).

- [ ] **Step 2: Test qui échoue**

`tests/scripts/test_gen_admin_assets.py` :

```python
"""Assets partagés app → console : noms de collèges et icônes générés et à jour."""

from app.core.college_catalog import COLLEGE_NAMES, college_name
from scripts.gen_admin_assets import generated_files, main


def test_fichiers_generes_a_jour():
    assert main(["--check"]) == 0, "lancer : python -m scripts.gen_admin_assets"


def test_noms_de_colleges():
    assert COLLEGE_NAMES[4] == "Cardiologie"
    assert college_name(4) == "Cardiologie"
    assert college_name(999) == "Collège n°999"


def test_icones_en_currentcolor():
    icons_js = next(content for path, content in generated_files() if path.name == "icons.js")
    assert "thumbDown:" in icons_js and "euro:" in icons_js and "settings:" in icons_js
    assert 'stroke="#000"' not in icons_js and 'stroke="currentColor"' in icons_js
```

Run: `.venv/bin/python -m pytest tests/scripts/test_gen_admin_assets.py -q` → FAIL (module introuvable).

- [ ] **Step 3: Générateur**

`scripts/gen_admin_assets.py` :

```python
"""Génère, depuis l'app Flutter (source de vérité), les assets partagés avec la console admin.

- app/core/college_catalog.py : noms des collèges par college_ref_id ;
- app/static/admin/js/icons.js : icônes CgIcons (trait en currentColor).

Usage : python -m scripts.gen_admin_assets [--check]
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1]
APP = BACKEND.parent / "collega_app"
ICONS_DART = APP / "lib/core/ui/foundation/cg_icon.dart"
CATALOG_DART = APP / "lib/features/colleges/domain/college_catalog.dart"
CATALOG_PY = BACKEND / "app/core/college_catalog.py"
ICONS_JS = BACKEND / "app/static/admin/js/icons.js"


def _icons_js() -> str:
    source = ICONS_DART.read_text(encoding="utf-8")
    icons = re.findall(r"static const (\w+) = '(<svg.*?</svg>)';", source)
    lines = [f"  {name}: {json.dumps(svg.replace('stroke=\"#000\"', 'stroke=\"currentColor\"'))}," for name, svg in icons]
    return (
        "// GÉNÉRÉ par scripts/gen_admin_assets.py depuis collega_app/lib/core/ui/foundation/cg_icon.dart.\n"
        "// Ne pas modifier à la main.\n"
        "export const ICONS = {\n" + "\n".join(lines) + "\n};\n"
    )


def _catalog_py() -> str:
    source = CATALOG_DART.read_text(encoding="utf-8")
    entries = re.findall(r"refId:\s*(\d+),\s*name:\s*'((?:[^'\\]|\\.)*)'", source)
    body = "\n".join(f"    {int(ref)}: {json.dumps(name.replace(chr(92) + chr(39), chr(39)), ensure_ascii=False)}," for ref, name in entries)
    return (
        '"""GÉNÉRÉ par scripts/gen_admin_assets.py depuis collega_app/.../college_catalog.dart.\n\n'
        'Ne pas modifier à la main."""\n\n'
        "COLLEGE_NAMES: dict[int, str] = {\n" + body + "\n}\n\n\n"
        "def college_name(ref_id: int) -> str:\n"
        '    return COLLEGE_NAMES.get(ref_id, f"Collège n°{ref_id}")\n'
    )


def generated_files() -> list[tuple[Path, str]]:
    return [(CATALOG_PY, _catalog_py()), (ICONS_JS, _icons_js())]


def main(argv: list[str] | None = None) -> int:
    check = "--check" in (argv if argv is not None else sys.argv[1:])
    stale = []
    for path, content in generated_files():
        current = path.read_text(encoding="utf-8") if path.exists() else None
        if current == content:
            continue
        if check:
            stale.append(path)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
            print(f"écrit : {path.relative_to(BACKEND)}")
    for path in stale:
        print(f"pas à jour : {path.relative_to(BACKEND)}", file=sys.stderr)
    return 1 if stale else 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Vérifier le motif de `college_catalog.dart` : chaque entrée est `CollegeCatalogEntry(refId: 4,  name: 'Cardiologie', …)` ; s'il y a des apostrophes échappées (`\'`), le remplacement ci-dessus les rend en `'`. Si le nombre d'entrées lues ne correspond pas au nombre de `CollegeCatalogEntry(` du fichier, corriger la regex (ajouter un test `len(COLLEGE_NAMES) == <nombre d'entrées>`).

- [ ] **Step 4: Générer et vérifier**

Run: `.venv/bin/python -m scripts.gen_admin_assets` puis `.venv/bin/python -m pytest tests/scripts/test_gen_admin_assets.py -q` → PASS.
Run: `.venv/bin/ruff check . && .venv/bin/ruff format --check .` : si `ruff format` veut reformater `college_catalog.py`, ajuster le gabarit du générateur (pas le fichier généré) jusqu'à ce que la sortie soit déjà au format ruff.

- [ ] **Step 5: Commit**

```bash
git add collega_app/lib/core/ui/foundation/cg_icon.dart collega_backend/scripts/gen_admin_assets.py collega_backend/app/core/college_catalog.py collega_backend/app/static/admin/js/icons.js collega_backend/tests/scripts/test_gen_admin_assets.py
git commit -m "feat(console): assets partagés générés depuis l'app (collèges, icônes)"
```

---

### Task 4: Service de pilotage — accueil, pastilles, réglages, liste des collèges

**Files:**
- Create: `collega_backend/app/services/admin_pilot.py`, `collega_backend/app/schemas/admin_pilot.py`, `collega_backend/app/api/v1/admin/pilot.py`
- Modify: `collega_backend/app/api/v1/admin/__init__.py`, `collega_backend/app/services/app_settings.py`, `collega_backend/app/api/v1/admin/config.py`, `collega_backend/app/schemas/admin.py` (`ConfigData`, `ConfigUpdateRequest`, `AdminFlashCardData`, `CreateUserRequest`), `collega_backend/app/api/v1/admin/colleges.py` (cartes), `collega_backend/app/api/v1/admin/users.py` (création)
- Test: `collega_backend/tests/api/test_admin_pilot_pg.py` ; mettre à jour `tests/api/test_admin_config_pg.py`, `tests/api/test_admin_college_cards.py`, `tests/api/test_admin_users_create.py` si leurs assertions d'égalité stricte cassent.

**Interfaces:**
- Consumes: `ActivityDay`, `User.last_seen_at` (Task 1), `college_name` (Task 3), `UsageTotals` (`app/services/generation/token_cost.py`).
- Produces (dans `app/services/admin_pilot.py`) :
  - constantes `INACTIVITY_DAYS = "inactivity_days"` (défaut `5`), `QUALITY_SEEN_AT = "quality_seen_at"`, `TESTFLIGHT_URL = "testflight_url"` (défaut `""`), `ACTIVE_JOB_STATUSES = ("pending", "processing", "ocr_complete")`, `STALL_AFTER = timedelta(minutes=15)`, `FAILED_WINDOW = timedelta(days=7)`.
  - `tester_status(last_seen_at: datetime | None, now: datetime, inactivity_days: int) -> str` → `"never_seen" | "inactive" | "active"`.
  - `async pilot_settings(db) -> tuple[int, str]` → `(inactivity_days, testflight_url)`.
  - `async badges(db, now) -> BadgesData` ; `async mark_quality_seen(db, now) -> None`.
  - `async pilot(db, now) -> PilotData`.
  - `async list_colleges(db) -> list[AdminCollegeRow]`.
  - `async tester_rows(db, now, today) -> list[TesterRow]` (réutilisée par Task 5).
- Routes : `GET /v1/admin/pilot`, `GET /v1/admin/badges`, `POST /v1/admin/badges/quality-seen` (204), `GET /v1/admin/colleges`.
- `GET/PATCH /v1/admin/config` renvoient aussi `inactivity_days` (1–60) et `testflight_url` (`""` ou `https://…`, 300 caractères max).
- `GET /v1/admin/colleges/{id}/cards` : chaque fiche porte `user_feedback: "positive" | "negative" | null`.
- `POST /v1/admin/users` accepte `first_name` (optionnel, 100 caractères max).

- [ ] **Step 1: Schémas**

`app/schemas/admin_pilot.py` :

```python
from pydantic import BaseModel


class Kpi(BaseModel):
    value: float
    previous: float


class TesterRow(BaseModel):
    user_id: str
    email: str
    first_name: str | None
    is_beta: bool
    created_at: str
    last_seen_at: str | None
    status: str  # active | inactive | never_seen
    streak: int
    cards_7d: int
    college_count: int


class WatchJob(BaseModel):
    job_id: str
    college_id: str
    college_name: str
    user_email: str | None
    status: str
    kind: str  # failed | stalled
    message: str | None
    updated_at: str


class WatchFeedback(BaseModel):
    college_id: str
    college_name: str
    negative_count: int


class RunningJob(BaseModel):
    job_id: str
    college_name: str
    user_email: str | None
    status: str
    progress: float  # 0..1


class PilotData(BaseModel):
    testers_total: int
    active_7d: Kpi
    cards_7d: Kpi
    failed_imports_7d: Kpi
    cost_30d_eur: Kpi
    testers: list[TesterRow]
    watch_jobs: list[WatchJob]
    watch_feedback: list[WatchFeedback]
    running_jobs: list[RunningJob]


class PilotResponseWrapped(BaseModel):
    data: PilotData


class BadgesData(BaseModel):
    testers: int
    imports: int
    quality: int


class BadgesResponseWrapped(BaseModel):
    data: BadgesData


class AdminCollegeRow(BaseModel):
    college_id: str
    college_ref_id: int
    college_name: str
    user_email: str | None
    status: str
    card_count: int
    negative_count: int
    created_at: str


class AdminCollegesResponseWrapped(BaseModel):
    data: list[AdminCollegeRow]
```

- [ ] **Step 2: Tests qui échouent**

`tests/api/test_admin_pilot_pg.py` (fixtures du dépôt : `pg_client`, `pg_factory`, `ADMIN_AUTH`) :

```python
"""Console de pilotage : GET /v1/admin/pilot, /badges, /colleges, réglages."""

from __future__ import annotations

from datetime import UTC, date, datetime, timedelta

import pytest
from httpx import AsyncClient

from app.models.activity_day import ActivityDay
from app.models.claude_usage import ClaudeUsage
from app.models.generation_job_event import GenerationJobEvent
from app.services.admin_pilot import tester_status
from tests.api_pg import ADMIN_AUTH
from tests.factories import make_card, make_college, make_item, make_job, make_user

pytestmark = pytest.mark.pg

NOW = datetime(2026, 9, 26, 12, 0, tzinfo=UTC)


def test_tester_status():
    assert tester_status(None, NOW, 5) == "never_seen"
    assert tester_status(NOW - timedelta(days=4, hours=23), NOW, 5) == "active"
    assert tester_status(NOW - timedelta(days=5, minutes=1), NOW, 5) == "inactive"


async def test_401_sans_identifiants(pg_client: AsyncClient):
    for path in ("/v1/admin/pilot", "/v1/admin/badges", "/v1/admin/colleges"):
        assert (await pg_client.get(path)).status_code == 401


async def test_pilot_base_vide(pg_client: AsyncClient):
    resp = await pg_client.get("/v1/admin/pilot", auth=ADMIN_AUTH)
    assert resp.status_code == 200
    data = resp.json()["data"]
    assert data["testers_total"] == 0
    assert data["active_7d"] == {"value": 0, "previous": 0}
    assert data["testers"] == [] and data["watch_jobs"] == [] and data["running_jobs"] == []
    assert (await pg_client.get("/v1/admin/badges", auth=ADMIN_AUTH)).json()["data"] == {
        "testers": 0,
        "imports": 0,
        "quality": 0,
    }


async def test_pilot_chiffres_et_testeuses(pg_client: AsyncClient, pg_factory):
    today = datetime.now(UTC).date()
    now = datetime.now(UTC)
    async with pg_factory() as db:
        active = await make_user(db)
        active.is_beta, active.first_name, active.last_seen_at = True, "Camille", now
        never = await make_user(db)
        never.is_beta = True
        db.add_all(
            [
                ActivityDay(user_id=active.id, day=today, cards_reviewed=30, session_completed=True, streak=6),
                ActivityDay(user_id=active.id, day=today - timedelta(days=3), cards_reviewed=10, session_completed=True, streak=3),
                ActivityDay(user_id=active.id, day=today - timedelta(days=9), cards_reviewed=7, session_completed=False, streak=0),
            ]
        )
        await db.commit()

    data = (await pg_client.get("/v1/admin/pilot", auth=ADMIN_AUTH)).json()["data"]
    assert data["testers_total"] == 2
    assert data["active_7d"] == {"value": 1, "previous": 1}
    assert data["cards_7d"] == {"value": 40, "previous": 7}
    rows = {r["email"]: r for r in data["testers"]}
    assert rows[active.email]["status"] == "active"
    assert rows[active.email]["streak"] == 6
    assert rows[active.email]["cards_7d"] == 40
    assert rows[never.email]["status"] == "never_seen"
    assert (await pg_client.get("/v1/admin/badges", auth=ADMIN_AUTH)).json()["data"]["testers"] == 1


async def test_imports_en_echec_et_bloques(pg_client: AsyncClient, pg_factory):
    now = datetime.now(UTC)
    async with pg_factory() as db:
        user = await make_user(db)
        failed = await make_job(db, await make_college(db, user, ref_id=4), status="failed")
        failed.error_message = "OCR illisible"
        old_failed = await make_job(db, await make_college(db, user, ref_id=5), status="failed")
        old_failed.updated_at = now - timedelta(days=8)
        stalled = await make_job(db, await make_college(db, user, ref_id=6), status="processing")
        db.add(GenerationJobEvent(generation_job_id=stalled.id, event_type="ocr_progress", created_at=now - timedelta(minutes=20)))
        running = await make_job(db, await make_college(db, user, ref_id=7), status="processing")
        db.add(GenerationJobEvent(generation_job_id=running.id, event_type="ocr_progress", created_at=now - timedelta(minutes=1)))
        await db.commit()

    data = (await pg_client.get("/v1/admin/pilot", auth=ADMIN_AUTH)).json()["data"]
    kinds = {(w["college_name"], w["kind"]) for w in data["watch_jobs"]}
    assert kinds == {("Cardiologie", "failed"), (_name(6), "stalled")}
    assert [r["job_id"] for r in data["running_jobs"]] == [str(running.id)]
    assert data["failed_imports_7d"]["value"] == 1
    assert (await pg_client.get("/v1/admin/badges", auth=ADMIN_AUTH)).json()["data"]["imports"] == 2


def _name(ref_id: int) -> str:
    from app.core.college_catalog import college_name

    return college_name(ref_id)


async def test_pastille_qualite_et_visite(pg_client: AsyncClient, pg_factory):
    async with pg_factory() as db:
        user = await make_user(db)
        college = await make_college(db, user, ref_id=4)
        item = await make_item(db, college)
        await make_card(db, item, user_feedback="negative")
        await make_card(db, item, user_feedback="positive")
        await db.commit()

    assert (await pg_client.get("/v1/admin/badges", auth=ADMIN_AUTH)).json()["data"]["quality"] == 1
    colleges = (await pg_client.get("/v1/admin/colleges", auth=ADMIN_AUTH)).json()["data"]
    assert colleges[0]["college_name"] == "Cardiologie" and colleges[0]["negative_count"] == 1
    assert (await pg_client.post("/v1/admin/badges/quality-seen", auth=ADMIN_AUTH)).status_code == 204
    assert (await pg_client.get("/v1/admin/badges", auth=ADMIN_AUTH)).json()["data"]["quality"] == 0


async def test_cout_30_jours(pg_client: AsyncClient, pg_factory):
    now = datetime.now(UTC)
    async with pg_factory() as db:
        db.add_all(
            [
                ClaudeUsage(created_at=now - timedelta(days=1), kind="generation", model="claude-sonnet-4-6", input_tokens=1_000_000, output_tokens=0),
                ClaudeUsage(created_at=now - timedelta(days=40), kind="generation", model="claude-sonnet-4-6", input_tokens=1_000_000, output_tokens=0),
            ]
        )
        await db.commit()
    cost = (await pg_client.get("/v1/admin/pilot", auth=ADMIN_AUTH)).json()["data"]["cost_30d_eur"]
    assert cost["value"] > 0 and cost["value"] == cost["previous"]


async def test_reglages_pilotage(pg_client: AsyncClient):
    data = (await pg_client.get("/v1/admin/config", auth=ADMIN_AUTH)).json()["data"]
    assert data["inactivity_days"] == 5 and data["testflight_url"] == ""
    resp = await pg_client.patch(
        "/v1/admin/config", json={"inactivity_days": 3, "testflight_url": "https://testflight.apple.com/join/abc"}, auth=ADMIN_AUTH
    )
    assert resp.json()["data"]["inactivity_days"] == 3
    assert (await pg_client.patch("/v1/admin/config", json={"testflight_url": "javascript:alert(1)"}, auth=ADMIN_AUTH)).status_code == 422
    assert (await pg_client.patch("/v1/admin/config", json={"inactivity_days": 0}, auth=ADMIN_AUTH)).status_code == 422
```

Vérifier avant d'exécuter : `make_card` accepte `**kw` (oui, `tests/factories.py:71`) et `ClaudeUsage` a un `id` par défaut (sinon passer `id=uuid.uuid4()`) ; `GenerationJobEvent` : lire `app/models/generation_job_event.py` pour ses champs obligatoires et compléter. `make_job` ne fixe pas `updated_at` : le modifier après coup comme ci-dessus déclenche `onupdate` au flush — si la valeur est écrasée par `onupdate`, la fixer par un `UPDATE` SQL explicite (`await db.execute(update(GenerationJob).where(...).values(updated_at=...))`).

Run: `.venv/bin/python -m pytest tests/api/test_admin_pilot_pg.py -q` → FAIL.

- [ ] **Step 3: Réglages**

Dans `app/services/app_settings.py`, rien à changer (les clés vivent dans `admin_pilot`).

Dans `app/schemas/admin.py` :

```python
class ConfigData(BaseModel):
    reload_count_max: int
    monthly_reloads_max: int
    inactivity_days: int
    testflight_url: str


class ConfigUpdateRequest(BaseModel):
    reload_count_max: int | None = Field(default=None, ge=0)
    monthly_reloads_max: int | None = Field(default=None, ge=0)
    inactivity_days: int | None = Field(default=None, ge=1, le=60)
    testflight_url: str | None = Field(default=None, max_length=300, pattern=r"^(|https://\S+)$")
```

`AdminFlashCardData` : ajouter `user_feedback: str | None = None` et, dans `get_college_cards` (`app/api/v1/admin/colleges.py`), passer `user_feedback=card.user_feedback`.
`CreateUserRequest` : ajouter `first_name: str | None = Field(default=None, max_length=100)` et, dans `create_user`, `first_name=(body.first_name or "").strip() or None`.

Dans `app/api/v1/admin/config.py`, factoriser la construction de la réponse :

```python
async def _config(db: AsyncSession) -> ConfigData:
    reload_count_max, monthly_reloads_max = await app_settings.anti_spam_limits(db)
    inactivity_days, testflight_url = await admin_pilot.pilot_settings(db)
    return ConfigData(
        reload_count_max=reload_count_max,
        monthly_reloads_max=monthly_reloads_max,
        inactivity_days=inactivity_days,
        testflight_url=testflight_url,
    )
```

`get_config` renvoie `ConfigResponseWrapped(data=await _config(db))` ; `update_config` enregistre aussi `inactivity_days` (`admin_pilot.INACTIVITY_DAYS`) et `testflight_url` (`admin_pilot.TESTFLIGHT_URL`) quand ils ne sont pas `None`, commite, puis renvoie `_config(db)`. Mettre à jour `tests/api/test_admin_config_pg.py` : les égalités strictes sur `{"reload_count_max", "monthly_reloads_max"}` deviennent des comparaisons sur ces deux clés (`{k: data[k] for k in (...)}`).

- [ ] **Step 4: Service**

`app/services/admin_pilot.py` :

```python
"""Console de pilotage de la beta : accueil, pastilles du menu, fiche testeuse.

Petite échelle (quelques dizaines de testeuses) : on lit les lignes utiles et on
agrège en Python, ce qui garde les règles lisibles et testables."""

from __future__ import annotations

import uuid
from collections import defaultdict
from datetime import date, datetime, timedelta

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.college_catalog import college_name
from app.models.activity_day import ActivityDay
from app.models.claude_usage import ClaudeUsage
from app.models.college import College
from app.models.flash_card import FlashCard
from app.models.generation_job import GenerationJob
from app.models.generation_job_event import GenerationJobEvent
from app.models.user import User
from app.schemas.admin_pilot import (
    AdminCollegeRow,
    BadgesData,
    Kpi,
    PilotData,
    RunningJob,
    TesterRow,
    WatchFeedback,
    WatchJob,
)
from app.services import app_settings
from app.services.generation.token_cost import UsageTotals

INACTIVITY_DAYS = "inactivity_days"
QUALITY_SEEN_AT = "quality_seen_at"
TESTFLIGHT_URL = "testflight_url"
DEFAULT_INACTIVITY_DAYS = 5
ACTIVE_JOB_STATUSES = ("pending", "processing", "ocr_complete")
STALL_AFTER = timedelta(minutes=15)
FAILED_WINDOW = timedelta(days=7)
QUALITY_DEFAULT_WINDOW = timedelta(days=7)


def tester_status(last_seen_at: datetime | None, now: datetime, inactivity_days: int) -> str:
    if last_seen_at is None:
        return "never_seen"
    return "inactive" if now - last_seen_at > timedelta(days=inactivity_days) else "active"


async def pilot_settings(db: AsyncSession) -> tuple[int, str]:
    inactivity = await app_settings.get_setting(db, INACTIVITY_DAYS, DEFAULT_INACTIVITY_DAYS)
    url = await app_settings.get_setting(db, TESTFLIGHT_URL, "")
    return int(inactivity), str(url)


async def _quality_since(db: AsyncSession, now: datetime) -> datetime:
    raw = await app_settings.get_setting(db, QUALITY_SEEN_AT, None)
    return datetime.fromisoformat(raw) if raw else now - QUALITY_DEFAULT_WINDOW


async def mark_quality_seen(db: AsyncSession, now: datetime) -> None:
    await app_settings.set_setting(db, QUALITY_SEEN_AT, now.isoformat())
    await db.commit()


async def _activity_rows(db: AsyncSession, since: date) -> list[ActivityDay]:
    return list((await db.execute(select(ActivityDay).where(ActivityDay.day >= since))).scalars().all())


async def tester_rows(db: AsyncSession, now: datetime, today: date) -> list[TesterRow]:
    inactivity_days, _ = await pilot_settings(db)
    users = (await db.execute(select(User).order_by(User.created_at.desc()))).scalars().all()
    college_counts = dict(
        (await db.execute(select(College.user_id, func.count()).group_by(College.user_id))).all()
    )
    rows = await _activity_rows(db, today - timedelta(days=60))
    last_streak: dict[uuid.UUID, tuple[date, int]] = {}
    cards_7d: dict[uuid.UUID, int] = defaultdict(int)
    for r in rows:
        if r.user_id not in last_streak or r.day > last_streak[r.user_id][0]:
            last_streak[r.user_id] = (r.day, r.streak)
        if r.day > today - timedelta(days=7):
            cards_7d[r.user_id] += r.cards_reviewed
    return [
        TesterRow(
            user_id=str(u.id),
            email=u.email,
            first_name=u.first_name,
            is_beta=u.is_beta,
            created_at=u.created_at.isoformat(),
            last_seen_at=u.last_seen_at.isoformat() if u.last_seen_at else None,
            status=tester_status(u.last_seen_at, now, inactivity_days),
            streak=last_streak.get(u.id, (today, 0))[1],
            cards_7d=cards_7d.get(u.id, 0),
            college_count=college_counts.get(u.id, 0),
        )
        for u in users
    ]


async def _jobs_to_watch(db: AsyncSession, now: datetime) -> tuple[list[WatchJob], list[RunningJob]]:
    last_event = (
        select(GenerationJobEvent.generation_job_id, func.max(GenerationJobEvent.created_at).label("at"))
        .group_by(GenerationJobEvent.generation_job_id)
        .subquery()
    )
    result = await db.execute(
        select(GenerationJob, College, User.email, last_event.c.at)
        .join(College, College.id == GenerationJob.college_id)
        .outerjoin(User, User.id == GenerationJob.user_id)
        .outerjoin(last_event, last_event.c.generation_job_id == GenerationJob.id)
        .where(
            (GenerationJob.status.in_(ACTIVE_JOB_STATUSES))
            | and_(GenerationJob.status == "failed", GenerationJob.updated_at >= now - FAILED_WINDOW)
        )
        .order_by(GenerationJob.updated_at.desc())
    )
    watch: list[WatchJob] = []
    running: list[RunningJob] = []
    for job, college, email, event_at in result.all():
        name = college_name(college.college_ref_id)
        if job.status == "failed":
            watch.append(_watch(job, college, name, email, "failed"))
            continue
        # Dernier signe de vie : le dernier événement du job (le worker en émet pendant
        # l'OCR et la génération), à défaut sa dernière mise à jour.
        last_activity = event_at or job.updated_at
        if now - last_activity > STALL_AFTER:
            watch.append(_watch(job, college, name, email, "stalled"))
        else:
            running.append(
                RunningJob(job_id=str(job.id), college_name=name, user_email=email, status=job.status, progress=_progress(college))
            )
    return watch, running


def _watch(job: GenerationJob, college: College, name: str, email: str | None, kind: str) -> WatchJob:
    return WatchJob(
        job_id=str(job.id),
        college_id=str(college.id),
        college_name=name,
        user_email=email,
        status=job.status,
        kind=kind,
        message=job.error_message,
        updated_at=job.updated_at.isoformat(),
    )


def _progress(college: College) -> float:
    """OCR = première moitié, génération = seconde moitié (comme l'écran d'import de l'app)."""
    ocr = college.ocr_page_progress / college.total_pages if college.total_pages else 0.0
    gen = college.generation_items_done / college.generation_items_total if college.generation_items_total else 0.0
    return round(min(1.0, 0.5 * ocr + 0.5 * gen), 3)


async def _negative_feedback(db: AsyncSession, since: datetime) -> list[WatchFeedback]:
    result = await db.execute(
        select(College.id, College.college_ref_id, func.count())
        .join(FlashCard, FlashCard.college_id == College.id)
        .where(FlashCard.user_feedback == "negative", FlashCard.updated_at > since)
        .group_by(College.id, College.college_ref_id)
    )
    return [
        WatchFeedback(college_id=str(cid), college_name=college_name(ref), negative_count=count)
        for cid, ref, count in result.all()
    ]


async def _cost(db: AsyncSession, start: datetime, end: datetime) -> float:
    totals = UsageTotals()
    result = await db.execute(
        select(ClaudeUsage.model, func.sum(ClaudeUsage.input_tokens), func.sum(ClaudeUsage.output_tokens))
        .where(ClaudeUsage.created_at >= start, ClaudeUsage.created_at < end)
        .group_by(ClaudeUsage.model)
    )
    for model, u_in, u_out in result.all():
        totals.add(model, u_in or 0, u_out or 0)
    return totals.cost_eur


async def _failed_count(db: AsyncSession, start: datetime, end: datetime) -> int:
    result = await db.execute(
        select(func.count())
        .select_from(GenerationJob)
        .where(GenerationJob.status == "failed", GenerationJob.updated_at >= start, GenerationJob.updated_at < end)
    )
    return int(result.scalar_one())


async def pilot(db: AsyncSession, now: datetime) -> PilotData:
    today = now.date()
    testers = await tester_rows(db, now, today)
    rows = await _activity_rows(db, today - timedelta(days=13))
    week, prev_week = today - timedelta(days=6), today - timedelta(days=13)

    def period(start: date, end: date) -> list[ActivityDay]:
        return [r for r in rows if start <= r.day <= end]

    current, previous = period(week, today), period(prev_week, week - timedelta(days=1))
    watch, running = await _jobs_to_watch(db, now)
    return PilotData(
        testers_total=sum(1 for t in testers if t.is_beta),
        active_7d=Kpi(
            value=len({r.user_id for r in current if r.cards_reviewed > 0}),
            previous=len({r.user_id for r in previous if r.cards_reviewed > 0}),
        ),
        cards_7d=Kpi(value=sum(r.cards_reviewed for r in current), previous=sum(r.cards_reviewed for r in previous)),
        failed_imports_7d=Kpi(
            value=await _failed_count(db, now - FAILED_WINDOW, now),
            previous=await _failed_count(db, now - 2 * FAILED_WINDOW, now - FAILED_WINDOW),
        ),
        cost_30d_eur=Kpi(
            value=await _cost(db, now - timedelta(days=30), now),
            previous=await _cost(db, now - timedelta(days=60), now - timedelta(days=30)),
        ),
        testers=[t for t in testers if t.is_beta],
        watch_jobs=watch,
        watch_feedback=await _negative_feedback(db, await _quality_since(db, now)),
        running_jobs=running,
    )


async def badges(db: AsyncSession, now: datetime) -> BadgesData:
    testers = await tester_rows(db, now, now.date())
    watch, _ = await _jobs_to_watch(db, now)
    feedback = await _negative_feedback(db, await _quality_since(db, now))
    return BadgesData(
        testers=sum(1 for t in testers if t.is_beta and t.status != "active"),
        imports=len(watch),
        quality=sum(f.negative_count for f in feedback),
    )


async def list_colleges(db: AsyncSession) -> list[AdminCollegeRow]:
    cards = (
        select(
            FlashCard.college_id,
            func.count().label("cards"),
            func.count().filter(FlashCard.user_feedback == "negative").label("negative"),
        )
        .group_by(FlashCard.college_id)
        .subquery()
    )
    result = await db.execute(
        select(College, User.email, cards.c.cards, cards.c.negative)
        .outerjoin(User, User.id == College.user_id)
        .outerjoin(cards, cards.c.college_id == College.id)
        .order_by(College.created_at.desc())
    )
    return [
        AdminCollegeRow(
            college_id=str(c.id),
            college_ref_id=c.college_ref_id,
            college_name=college_name(c.college_ref_id),
            user_email=email,
            status=c.status,
            card_count=n_cards or 0,
            negative_count=n_negative or 0,
            created_at=c.created_at.isoformat(),
        )
        for c, email, n_cards, n_negative in result.all()
    ]
```

Remarque : `tester_status` sur la base de `testers_total` compte seulement `is_beta` ; la pastille Testeuses aussi (comptes de test non beta ignorés). `testers` dans `PilotData` = beta seulement ; l'écran Testeuses de la console utilise `GET /v1/admin/pilot` pour la liste des beta **et** `GET /v1/admin/users` n'est plus nécessaire. `tester_rows` renvoie tout le monde (Task 5 et un filtre « non beta » éventuel).

- [ ] **Step 5: Routes**

`app/api/v1/admin/pilot.py` :

```python
"""Routes admin — pilotage de la beta : accueil, pastilles du menu, liste des collèges.

Toutes les routes sont protégées par HTTP Basic Auth."""

from __future__ import annotations

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.deps import get_admin_user
from app.schemas.admin_pilot import AdminCollegesResponseWrapped, BadgesResponseWrapped, PilotResponseWrapped
from app.services import admin_pilot

router = APIRouter()


@router.get("/pilot", response_model=PilotResponseWrapped)
async def get_pilot(_: bool = Depends(get_admin_user), db: AsyncSession = Depends(get_db)) -> PilotResponseWrapped:
    return PilotResponseWrapped(data=await admin_pilot.pilot(db, datetime.now(UTC)))


@router.get("/badges", response_model=BadgesResponseWrapped)
async def get_badges(_: bool = Depends(get_admin_user), db: AsyncSession = Depends(get_db)) -> BadgesResponseWrapped:
    return BadgesResponseWrapped(data=await admin_pilot.badges(db, datetime.now(UTC)))


@router.post("/badges/quality-seen", status_code=204)
async def post_quality_seen(_: bool = Depends(get_admin_user), db: AsyncSession = Depends(get_db)) -> Response:
    await admin_pilot.mark_quality_seen(db, datetime.now(UTC))
    return Response(status_code=204)


@router.get("/colleges", response_model=AdminCollegesResponseWrapped)
async def get_colleges(
    _: bool = Depends(get_admin_user), db: AsyncSession = Depends(get_db)
) -> AdminCollegesResponseWrapped:
    return AdminCollegesResponseWrapped(data=await admin_pilot.list_colleges(db))
```

Dans `app/api/v1/admin/__init__.py` : importer `pilot` et `router.include_router(pilot.router)`. Vérifier qu'aucun chemin ne se recoupe : `GET /colleges` n'existe pas encore dans `colleges.py` (seulement `POST /colleges` et `/colleges/{id}/…`), donc pas de conflit.

- [ ] **Step 6: Vérifier**

Run: `.venv/bin/python -m pytest tests/api/test_admin_pilot_pg.py tests/api/test_admin_config_pg.py tests/api/test_admin_college_cards.py tests/api/test_admin_users_create.py -q` → PASS (corriger les égalités strictes des anciens tests en ajoutant les nouvelles clés).
Run: `.venv/bin/mypy app/core app/services` → 0 erreur ; `.venv/bin/ruff check . && .venv/bin/ruff format --check .`.

- [ ] **Step 7: Commit**

```bash
git add collega_backend/app collega_backend/tests
git commit -m "feat(console): accueil de pilotage, pastilles, liste des collèges, réglages"
```

---

### Task 5: Fiche testeuse enrichie

**Files:**
- Modify: `collega_backend/app/services/admin_pilot.py` (ajout `user_detail`), `collega_backend/app/schemas/admin.py` (`UserDetailData` et nouveaux sous-modèles), `collega_backend/app/api/v1/admin/users.py` (`get_user_detail` délègue au service)
- Create: `collega_backend/tests/api/test_admin_user_detail_pg.py`
- Delete: `collega_backend/tests/api/test_admin_user_detail.py` (tests par faux `db` incompatibles avec les nouvelles requêtes ; leurs cas 401/404/contenu sont repris en Postgres)

**Interfaces:**
- Consumes: `tester_rows`, `tester_status`, `pilot_settings`, `_progress` (Task 4), `college_name` (Task 3).
- Produces: `async admin_pilot.user_detail(db, user_id: UUID, now: datetime) -> UserDetailData` (lève `not_found("USER_NOT_FOUND", …)`). Réponse `GET /v1/admin/users/{id}` : champs existants **plus** `first_name`, `last_seen_at`, `status`, `streak`, `cards_30d`, `sessions_30d`, `daily: [{day, cards_reviewed, session_completed}]` (30 entrées, du plus ancien à aujourd'hui), `feedback: [{card_id, college_name, item_number, recto, feedback, at}]` (10 plus récents) ; chaque collège gagne `college_name`, `card_count`, `progress`.

- [ ] **Step 1: Tests qui échouent**

`tests/api/test_admin_user_detail_pg.py` :

```python
"""GET /v1/admin/users/{id} — fiche testeuse de la console de pilotage."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta

import pytest
from httpx import AsyncClient

from app.models.activity_day import ActivityDay
from tests.api_pg import ADMIN_AUTH
from tests.factories import make_card, make_college, make_item, make_job, make_user

pytestmark = pytest.mark.pg


async def test_401_et_404(pg_client: AsyncClient):
    assert (await pg_client.get(f"/v1/admin/users/{uuid.uuid4()}")).status_code == 401
    resp = await pg_client.get(f"/v1/admin/users/{uuid.uuid4()}", auth=ADMIN_AUTH)
    assert resp.status_code == 404
    assert resp.json()["detail"]["code"] == "USER_NOT_FOUND"


async def test_detail_sans_activite(pg_client: AsyncClient, pg_factory):
    async with pg_factory() as db:
        user = await make_user(db)
        await db.commit()
    data = (await pg_client.get(f"/v1/admin/users/{user.id}", auth=ADMIN_AUTH)).json()["data"]
    assert data["status"] == "never_seen"
    assert data["streak"] == 0 and data["cards_30d"] == 0 and data["sessions_30d"] == 0
    assert len(data["daily"]) == 30
    assert all(d["cards_reviewed"] == 0 for d in data["daily"])
    assert data["colleges"] == [] and data["feedback"] == [] and data["jobs"] == []


async def test_detail_complet(pg_client: AsyncClient, pg_factory):
    today = datetime.now(UTC).date()
    async with pg_factory() as db:
        user = await make_user(db)
        user.first_name, user.last_seen_at = "Camille", datetime.now(UTC)
        college = await make_college(db, user, ref_id=4, status="generation_complete")
        await make_job(db, college, status="generation_complete")
        item = await make_item(db, college)
        await make_card(db, item, recto="Signes de gravité ?", user_feedback="negative")
        db.add_all(
            [
                ActivityDay(user_id=user.id, day=today, cards_reviewed=25, session_completed=True, streak=6),
                ActivityDay(user_id=user.id, day=today - timedelta(days=2), cards_reviewed=10, session_completed=False, streak=4),
                ActivityDay(user_id=user.id, day=today - timedelta(days=45), cards_reviewed=99, session_completed=True, streak=1),
            ]
        )
        await db.commit()

    data = (await pg_client.get(f"/v1/admin/users/{user.id}", auth=ADMIN_AUTH)).json()["data"]
    assert data["first_name"] == "Camille" and data["status"] == "active"
    assert data["streak"] == 6 and data["cards_30d"] == 35 and data["sessions_30d"] == 1
    assert data["daily"][-1] == {"day": today.isoformat(), "cards_reviewed": 25, "session_completed": True}
    assert data["daily"][0]["day"] == (today - timedelta(days=29)).isoformat()
    assert data["colleges"][0]["college_name"] == "Cardiologie"
    assert data["colleges"][0]["card_count"] == 1
    assert data["feedback"][0]["feedback"] == "negative"
    assert data["feedback"][0]["recto"] == "Signes de gravité ?"
    assert data["feedback"][0]["college_name"] == "Cardiologie"
    assert len(data["jobs"]) == 1
```

Run: `.venv/bin/python -m pytest tests/api/test_admin_user_detail_pg.py -q` → FAIL.

- [ ] **Step 2: Schémas**

Dans `app/schemas/admin.py`, remplacer `UserCollegeSummary` et `UserDetailData` par :

```python
class UserCollegeSummary(BaseModel):
    college_id: str
    college_ref_id: int
    college_name: str
    status: str
    reload_count: int
    reload_count_max: int
    card_count: int
    progress: float


class DailyActivityData(BaseModel):
    day: str
    cards_reviewed: int
    session_completed: bool


class UserFeedbackData(BaseModel):
    card_id: str
    college_name: str
    item_number: int | None
    recto: str
    feedback: str
    at: str


class UserDetailData(BaseModel):
    user_id: str
    email: str
    first_name: str | None
    is_beta: bool
    is_subscribed: bool
    monthly_reloads: int
    monthly_reloads_max: int
    monthly_reloads_reset_at: str | None
    created_at: str | None
    last_seen_at: str | None
    status: str
    streak: int
    cards_30d: int
    sessions_30d: int
    daily: list[DailyActivityData]
    colleges: list[UserCollegeSummary]
    jobs: list[UserJobSummary]
    feedback: list[UserFeedbackData]
```

- [ ] **Step 3: Service**

Ajouter à `app/services/admin_pilot.py` (imports : `from app.core.errors import not_found`, `from app.models.item import Item`, `from app.schemas.admin import DailyActivityData, UserCollegeSummary, UserDetailData, UserFeedbackData, UserJobSummary`) :

```python
DAILY_WINDOW = 30
FEEDBACK_LIMIT = 10


async def user_detail(db: AsyncSession, user_id: uuid.UUID, now: datetime) -> UserDetailData:
    user = await db.get(User, user_id)
    if user is None:
        raise not_found("USER_NOT_FOUND", f"User {user_id} not found")
    today = now.date()
    start = today - timedelta(days=DAILY_WINDOW - 1)
    inactivity_days, _ = await pilot_settings(db)
    reload_count_max, monthly_reloads_max = await app_settings.anti_spam_limits(db)

    days = (
        await db.execute(select(ActivityDay).where(ActivityDay.user_id == user_id).order_by(ActivityDay.day))
    ).scalars().all()
    by_day = {d.day: d for d in days if d.day >= start}
    daily = [
        DailyActivityData(
            day=(start + timedelta(days=i)).isoformat(),
            cards_reviewed=by_day[start + timedelta(days=i)].cards_reviewed if start + timedelta(days=i) in by_day else 0,
            session_completed=bool(by_day.get(start + timedelta(days=i)) and by_day[start + timedelta(days=i)].session_completed),
        )
        for i in range(DAILY_WINDOW)
    ]

    card_counts = dict(
        (
            await db.execute(
                select(FlashCard.college_id, func.count()).where(FlashCard.user_id == user_id).group_by(FlashCard.college_id)
            )
        ).all()
    )
    colleges = (
        await db.execute(select(College).where(College.user_id == user_id).order_by(College.created_at.desc()))
    ).scalars().all()
    jobs = (
        await db.execute(
            select(GenerationJob).where(GenerationJob.user_id == user_id).order_by(GenerationJob.created_at.desc())
        )
    ).scalars().all()
    feedback_rows = (
        await db.execute(
            select(FlashCard, Item.item_number, College.college_ref_id)
            .join(Item, Item.id == FlashCard.item_id)
            .join(College, College.id == FlashCard.college_id)
            .where(FlashCard.user_id == user_id, FlashCard.user_feedback.is_not(None))
            .order_by(FlashCard.updated_at.desc())
            .limit(FEEDBACK_LIMIT)
        )
    ).all()

    return UserDetailData(
        user_id=str(user.id),
        email=user.email,
        first_name=user.first_name,
        is_beta=user.is_beta,
        is_subscribed=user.is_subscribed,
        monthly_reloads=user.monthly_reloads,
        monthly_reloads_max=monthly_reloads_max,
        monthly_reloads_reset_at=user.monthly_reloads_reset_at.isoformat() if user.monthly_reloads_reset_at else None,
        created_at=user.created_at.isoformat() if user.created_at else None,
        last_seen_at=user.last_seen_at.isoformat() if user.last_seen_at else None,
        status=tester_status(user.last_seen_at, now, inactivity_days),
        streak=days[-1].streak if days else 0,
        cards_30d=sum(d.cards_reviewed for d in by_day.values()),
        sessions_30d=sum(1 for d in by_day.values() if d.session_completed),
        daily=daily,
        colleges=[
            UserCollegeSummary(
                college_id=str(c.id),
                college_ref_id=c.college_ref_id,
                college_name=college_name(c.college_ref_id),
                status=c.status,
                reload_count=c.reload_count,
                reload_count_max=reload_count_max,
                card_count=card_counts.get(c.id, 0),
                progress=_progress(c),
            )
            for c in colleges
        ],
        jobs=[
            UserJobSummary(
                job_id=str(j.id),
                college_id=str(j.college_id),
                status=j.status,
                card_count=j.card_count,
                error_message=j.error_message,
                created_at=j.created_at.isoformat() if j.created_at else None,
            )
            for j in jobs
        ],
        feedback=[
            UserFeedbackData(
                card_id=str(card.id),
                college_name=college_name(ref),
                item_number=item_number,
                recto=card.recto,
                feedback=card.user_feedback or "",
                at=card.updated_at.isoformat(),
            )
            for card, item_number, ref in feedback_rows
        ],
    )
```

Simplifier la construction de `daily` si elle gêne la lecture (variable locale `d = start + timedelta(days=i)` dans une boucle `for`), le comportement attendu est celui du test.

Attention à l'import circulaire : `app/schemas/admin.py` ne doit rien importer de `app/services`. Le service importe les schémas, pas l'inverse.

- [ ] **Step 4: Route**

Dans `app/api/v1/admin/users.py`, remplacer le corps de `get_user_detail` par :

```python
    return UserDetailResponseWrapped(data=await admin_pilot.user_detail(db, user_id, datetime.now(UTC)))
```

(imports : `from datetime import UTC, datetime` et `from app.services import admin_pilot, app_settings` — `app_settings` reste utilisé par les autres routes du fichier ; retirer les imports devenus inutiles, ruff le signale).

- [ ] **Step 5: Vérifier**

Run: `git rm collega_backend/tests/api/test_admin_user_detail.py` puis `.venv/bin/python -m pytest tests/api/test_admin_user_detail_pg.py tests/api -q -k admin` → PASS.
Run: `.venv/bin/mypy app/core app/services` → 0 erreur.

- [ ] **Step 6: Commit**

```bash
git add -A collega_backend/app collega_backend/tests/api
git commit -m "feat(console): fiche testeuse (activité 30 j, collèges, avis)"
```

---

### Task 6: Alerte Telegram sur import en échec

**Files:**
- Create: `collega_backend/scripts/import_alerts.py`
- Modify: `collega_backend/ops/nas/collega-health.sh`, `collega_backend/docs/deployment.md`
- Test: `collega_backend/tests/scripts/test_import_alerts_pg.py`

**Interfaces:**
- Consumes: `college_name` (Task 3), `app_settings.get_setting/set_setting`.
- Produces: `scripts.import_alerts.KEY = "import_alerts_since"`, `async collect(db: AsyncSession, now: datetime) -> list[str]` (commite le point de reprise), `main() -> int` (imprime une ligne par échec, rien sinon, code 0).

- [ ] **Step 1: Tests qui échouent**

`tests/scripts/test_import_alerts_pg.py` :

```python
"""scripts/import_alerts.py : imports passés en échec depuis le dernier passage."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import update

from app.models.generation_job import GenerationJob
from app.services import app_settings
from scripts.import_alerts import KEY, collect
from tests.factories import make_college, make_job, make_user

pytestmark = pytest.mark.pg


async def _failed_job(db, ref_id: int, at: datetime, message: str | None = "OCR illisible"):
    user = await make_user(db)
    job = await make_job(db, await make_college(db, user, ref_id=ref_id), status="failed")
    await db.execute(update(GenerationJob).where(GenerationJob.id == job.id).values(updated_at=at, error_message=message))
    return user


async def test_premier_passage_silencieux(pg_session):
    now = datetime.now(UTC)
    await _failed_job(pg_session, 4, now - timedelta(hours=1))
    assert await collect(pg_session, now) == []
    app_settings.clear_cache()
    assert await app_settings.get_setting(pg_session, KEY, None) == now.isoformat()


async def test_nouveaux_echecs_puis_rien(pg_session):
    now = datetime.now(UTC)
    await app_settings.set_setting(pg_session, KEY, (now - timedelta(minutes=5)).isoformat())
    user = await _failed_job(pg_session, 4, now - timedelta(minutes=1))
    await _failed_job(pg_session, 999, now - timedelta(seconds=30), message=None)
    await _failed_job(pg_session, 5, now - timedelta(minutes=10))  # avant le point de reprise

    lines = await collect(pg_session, now)
    assert lines == [f"Cardiologie — {user.email} : OCR illisible", lines[1]]
    assert lines[1].startswith("Collège n°999 — ") and lines[1].endswith(": erreur inconnue")
    app_settings.clear_cache()
    assert await collect(pg_session, now + timedelta(minutes=1)) == []


async def test_message_long_tronque(pg_session):
    now = datetime.now(UTC)
    await app_settings.set_setting(pg_session, KEY, (now - timedelta(minutes=5)).isoformat())
    await _failed_job(pg_session, 4, now - timedelta(minutes=1), message="x" * 500)
    [line] = await collect(pg_session, now)
    assert len(line) < 260 and line.endswith("…")
```

Run: `.venv/bin/python -m pytest tests/scripts/test_import_alerts_pg.py -q` → FAIL.

- [ ] **Step 2: Commande**

`scripts/import_alerts.py` :

```python
"""Imports passés en échec depuis le dernier passage, une ligne par import (alerte Telegram).

Lancée chaque minute par le script de santé du NAS (ops/nas/collega-health.sh) :
  docker exec collega-api-1 python -m scripts.import_alerts
Le point de reprise vit dans app_settings (`import_alerts_since`). Au tout premier
passage il est posé à « maintenant » : pas de rafale sur l'historique."""

from __future__ import annotations

import asyncio
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.college_catalog import college_name
from app.models.college import College
from app.models.generation_job import GenerationJob
from app.models.user import User
from app.services import app_settings

KEY = "import_alerts_since"
MAX_MESSAGE = 200


def _short(message: str | None) -> str:
    text = " ".join((message or "erreur inconnue").split())
    return text if len(text) <= MAX_MESSAGE else text[: MAX_MESSAGE - 1] + "…"


async def collect(db: AsyncSession, now: datetime) -> list[str]:
    raw = await app_settings.get_setting(db, KEY, None)
    if raw is None:
        await app_settings.set_setting(db, KEY, now.isoformat())
        await db.commit()
        return []
    since = datetime.fromisoformat(raw)
    rows = (
        await db.execute(
            select(GenerationJob, College.college_ref_id, User.email)
            .join(College, College.id == GenerationJob.college_id)
            .outerjoin(User, User.id == GenerationJob.user_id)
            .where(GenerationJob.status == "failed", GenerationJob.updated_at > since)
            .order_by(GenerationJob.updated_at)
        )
    ).all()
    if not rows:
        return []
    lines = [f"{college_name(ref)} — {email or 'compte supprimé'} : {_short(job.error_message)}" for job, ref, email in rows]
    await app_settings.set_setting(db, KEY, max(job.updated_at for job, _, _ in rows).isoformat())
    await db.commit()
    return lines


async def _run() -> list[str]:
    from app.core.database import async_session_factory

    async with async_session_factory() as db:
        return await collect(db, datetime.now(UTC))


def main() -> int:
    for line in asyncio.run(_run()):
        print(line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

Le test `test_nouveaux_echecs_puis_rien` fixe l'ordre par `updated_at` : Cardiologie (−1 min) avant le collège 999 (−30 s). Aucun emoji dans les lignes.

- [ ] **Step 3: Vérifier**

Run: `.venv/bin/python -m pytest tests/scripts/test_import_alerts_pg.py -q` → PASS.

- [ ] **Step 4: Script de santé**

Dans `ops/nas/collega-health.sh`, juste avant `exit 0` :

```bash
# Imports passés en échec depuis la minute précédente (point de reprise en base).
# Une panne de la commande ne doit jamais gêner la sonde de santé ci-dessus.
alerts=$(docker exec collega-api-1 python -m scripts.import_alerts 2>/dev/null) || alerts=""
[ -n "$alerts" ] && notify "Collega : import en échec" "$alerts" "alert"
```

Vérifier la syntaxe : `bash -n collega_backend/ops/nas/collega-health.sh`. Ne **pas** copier le script sur le NAS (déploiement fait avec l'utilisateur).

Dans `docs/deployment.md`, section supervision (chercher `collega-health`), ajouter un paragraphe : la sonde lance aussi `scripts.import_alerts` et envoie « Collega : import en échec » en niveau `alert` ; point de reprise `import_alerts_since` dans `app_settings` ; pour rejouer : supprimer la ligne `app_settings` (le passage suivant repart de « maintenant »).

- [ ] **Step 5: Commit**

```bash
git add collega_backend/scripts/import_alerts.py collega_backend/tests/scripts/test_import_alerts_pg.py collega_backend/ops/nas/collega-health.sh collega_backend/docs/deployment.md
git commit -m "feat(supervision): alerte Telegram sur import en échec"
```

---

### Task 7: Console — socle (coquille, styles, API, routeur, connexion)

**Files:**
- Replace: `collega_backend/app/static/admin/index.html`
- Create: `collega_backend/app/static/admin/css/tokens.css`, `css/ui.css`, `fonts/InstrumentSans-{Regular,Medium,SemiBold,Bold}.ttf`, `fonts/OFL.txt`, `js/main.js`, `js/api.js`, `js/router.js`, `js/ui.js`, `js/views/login.js`, et un module provisoire par écran (remplacés en Tasks 8-9)
- Test: `collega_backend/tests/api/test_admin_front_assets.py`

**Interfaces:**
- Consumes: `js/icons.js` (Task 3), routes admin existantes et nouvelles.
- Produces (utilisées par toutes les vues) :
  - `api.js` : `api(path, {method, body, silent401}) -> Promise<json|null>` (préfixe `/v1/admin`), `ApiError {status, code, message}`, `setCredentials(user, pass)`, `hasCredentials()`, `clearCredentials()`, `checkCredentials() -> Promise<void>` (appelle `/badges`).
  - `router.js` : `route(pattern, loader)`, `resolve(path) -> {loader, params} | null`, `currentPath()`, `go(path)`.
  - `ui.js` : `h(tag, attrs?, ...children)`, `icon(name, size=16)`, `kpi({label, value, previous, format, invert})`, `tag(text, tone)`, `bars(values, {labels, format})`, `block(title, aside, ...children)`, `row(left, right, onClick?)`, `empty(text)`, `banner(error, onRetry?)`, `toast(text)`, `panel(title, content) -> {close}`, `fmtAgo(iso)`, `fmtDate(iso)`, `fmtDateTime(iso)`, `fmtEuro(n)`, `fmtInt(n)`, `STATUS_LABEL`, `JOB_STATUS_LABEL`.
  - Contrat d'une vue : `export async function render(root, params) -> (() => void) | void` ; `root` est vidé avant l'appel ; la fonction renvoyée (facultative) est appelée en quittant l'écran (arrêt d'un rafraîchissement).

- [ ] **Step 1: Test qui échoue**

`tests/api/test_admin_front_assets.py` :

```python
"""Console admin statique : chaque fichier référencé existe, pas d'innerHTML hors icônes, pas d'emoji."""

from __future__ import annotations

import re
from pathlib import Path

import pytest
from httpx import AsyncClient

ADMIN = Path(__file__).resolve().parents[2] / "app/static/admin"
EMOJI = re.compile("[\U0001f300-\U0001faff☀-➿]")


def _js_files() -> list[Path]:
    return sorted((ADMIN / "js").rglob("*.js"))


def test_references_de_index_existent():
    html = (ADMIN / "index.html").read_text(encoding="utf-8")
    refs = re.findall(r'(?:href|src)="/admin/([^"]+)"', html)
    assert refs, "index.html doit référencer ses assets en /admin/…"
    for ref in refs:
        assert (ADMIN / ref).is_file(), ref


def test_imports_des_modules_existent():
    for path in _js_files():
        for ref in re.findall(r"""(?:from|import)\s*\(?\s*['"](\.{1,2}/[^'"]+)['"]""", path.read_text(encoding="utf-8")):
            assert (path.parent / ref).resolve().is_file(), f"{path.name} → {ref}"


def test_polices_de_tokens_css_existent():
    css = (ADMIN / "css/tokens.css").read_text(encoding="utf-8")
    for ref in re.findall(r"url\('?\.\./([^')]+)'?\)", css):
        assert (ADMIN / ref).is_file(), ref


def test_admin_front_n_utilise_pas_innerhtml_hors_icones():
    for path in _js_files():
        if path.name == "icons.js":
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            if "innerHTML" in line:
                assert "ICONS[" in line, f"{path.name} : innerHTML hors icônes → {line.strip()}"


def test_aucun_emoji():
    for path in [*_js_files(), ADMIN / "index.html", *(ADMIN / "css").glob("*.css")]:
        assert not EMOJI.search(path.read_text(encoding="utf-8")), path.name


@pytest.mark.parametrize("path", ["/admin/", "/admin/js/main.js", "/admin/css/ui.css"])
async def test_servi_par_fastapi(client: AsyncClient, path: str):
    assert (await client.get(path)).status_code == 200
```

Run: `.venv/bin/python -m pytest tests/api/test_admin_front_assets.py -q` → FAIL.

- [ ] **Step 2: Polices**

```bash
mkdir -p collega_backend/app/static/admin/fonts
cp collega_app/assets/fonts/InstrumentSans-{Regular,Medium,SemiBold,Bold}.ttf collega_app/assets/fonts/OFL.txt collega_backend/app/static/admin/fonts/
```

- [ ] **Step 3: `index.html`**

```html
<!doctype html>
<html lang="fr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="robots" content="noindex">
  <title>Collega admin</title>
  <link rel="icon" href="/admin/logo.svg">
  <link rel="stylesheet" href="/admin/css/tokens.css">
  <link rel="stylesheet" href="/admin/css/ui.css">
</head>
<body>
  <div id="app"></div>
  <script type="module" src="/admin/js/main.js"></script>
</body>
</html>
```

- [ ] **Step 4: `css/tokens.css`** (valeurs de `cg_colors.dart`, `cg_space.dart`, `cg_radius.dart`)

```css
@font-face { font-family: "Instrument Sans"; src: url('../fonts/InstrumentSans-Regular.ttf') format("truetype"); font-weight: 400; font-display: swap; }
@font-face { font-family: "Instrument Sans"; src: url('../fonts/InstrumentSans-Medium.ttf') format("truetype"); font-weight: 500; font-display: swap; }
@font-face { font-family: "Instrument Sans"; src: url('../fonts/InstrumentSans-SemiBold.ttf') format("truetype"); font-weight: 600; font-display: swap; }
@font-face { font-family: "Instrument Sans"; src: url('../fonts/InstrumentSans-Bold.ttf') format("truetype"); font-weight: 700; font-display: swap; }

:root {
  --ground: #ECEAE3; --surface: #F7F6F2; --soft: #E2E0D8;
  --ink: #17201F; --ink2: #454D4C; --ink3: #60645E; --line: #D9D6CC;
  --accent: #0E5E63; --accent-soft: #D5E6E4; --accent-ink: #F2F5F3;
  --rank-a: #0E5E63; --rank-b: #4C696D; --rank-b-soft: #DDE3E3; --rank-c: #64635B;
  --good: #6FA8A2; --review: #D9822B; --review-ink: #9A5A16; --review-soft: #F3E3CF;
  --danger: #B8352B; --danger-soft: #F2D9D6; --scrim: rgba(23, 32, 31, .4);
  --s1: 4px; --s2: 8px; --s3: 12px; --s4: 16px; --s5: 20px; --s6: 24px; --s8: 32px;
  --r-s: 10px; --r-m: 14px; --r-l: 20px; --r-badge: 6px; --r-pill: 999px;
  --font: "Instrument Sans", system-ui, -apple-system, sans-serif;
}
```

(Vérifier `cg_radius.dart` : `s = 10`, `l = 20`, `button = 14`, `badge = 6` ; ajuster `--r-m` si une valeur `m` existe.)

- [ ] **Step 5: `css/ui.css`**

```css
* { box-sizing: border-box; }
html, body { margin: 0; }
body { font-family: var(--font); background: var(--ground); color: var(--ink); font-size: 14px; line-height: 1.45; -webkit-font-smoothing: antialiased; }
button, input, select, textarea { font: inherit; color: inherit; }
a { color: inherit; }

.shell { display: flex; min-height: 100vh; }
.side { width: 232px; flex: none; background: var(--surface); border-right: 1px solid var(--line); padding: var(--s5) var(--s3); display: flex; flex-direction: column; gap: var(--s1); position: sticky; top: 0; height: 100vh; }
.brand { display: flex; align-items: center; gap: var(--s2); font-weight: 700; font-size: 16px; padding: 0 var(--s2) var(--s5); }
.brand img { width: 26px; height: 26px; }
.nav-link { display: flex; align-items: center; gap: var(--s3); padding: 9px var(--s3); border-radius: var(--r-s); color: var(--ink2); text-decoration: none; font-weight: 500; }
.nav-link:hover { background: var(--soft); }
.nav-link.on { background: var(--accent-soft); color: var(--accent); font-weight: 600; }
.nav-link .pill { margin-left: auto; }
.side-foot { margin-top: auto; }
.pill { min-width: 20px; height: 20px; padding: 0 6px; border-radius: var(--r-pill); background: var(--review-soft); color: var(--review-ink); font-size: 11px; font-weight: 700; display: inline-flex; align-items: center; justify-content: center; line-height: 1; }
.main { flex: 1; min-width: 0; padding: var(--s8) var(--s8) 64px; max-width: 1180px; }
.topbar { display: none; }

h1 { font-size: 28px; font-weight: 700; margin: 0; letter-spacing: -.01em; }
.page-head { display: flex; align-items: flex-end; gap: var(--s4); margin-bottom: var(--s6); flex-wrap: wrap; }
.page-head .sub { color: var(--ink3); margin-top: var(--s1); }
.page-head .actions { margin-left: auto; display: flex; gap: var(--s2); flex-wrap: wrap; }
.crumb { color: var(--ink3); font-size: 13px; text-decoration: none; display: inline-flex; align-items: center; gap: 2px; margin-bottom: var(--s2); }

.grid { display: grid; gap: var(--s3); }
.kpis { grid-template-columns: repeat(4, minmax(0, 1fr)); margin-bottom: var(--s4); }
.cols { grid-template-columns: minmax(0, 1.2fr) minmax(0, 1fr); align-items: start; }
.cols-even { grid-template-columns: repeat(2, minmax(0, 1fr)); align-items: start; }
.kpi, .block { background: var(--surface); border: 1px solid var(--line); border-radius: var(--r-m); }
.kpi { padding: var(--s4); }
.kpi .value { font-size: 26px; font-weight: 700; letter-spacing: -.01em; }
.kpi .label { color: var(--ink3); font-size: 13px; }
.kpi .delta { font-size: 12px; font-weight: 600; margin-top: var(--s1); color: var(--ink3); }
.kpi .delta.up { color: var(--accent); } .kpi .delta.down { color: var(--review-ink); }
.block { padding: var(--s4) var(--s5); margin-bottom: var(--s3); }
.block-head { display: flex; align-items: baseline; justify-content: space-between; margin-bottom: var(--s2); }
.block-head h2 { font-size: 16px; font-weight: 600; margin: 0; }
.block-head .aside { color: var(--ink3); font-size: 13px; display: inline-flex; align-items: center; gap: var(--s1); }
.row { display: flex; align-items: center; justify-content: space-between; gap: var(--s3); padding: 10px 0; border-top: 1px solid var(--line); }
.row:first-of-type { border-top: 0; }
.row.link { cursor: pointer; } .row.link:hover { background: linear-gradient(90deg, transparent, var(--ground) 8%, var(--ground) 92%, transparent); }
.row .left { display: flex; align-items: center; gap: var(--s2); min-width: 0; }
.row .left .t { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.muted { color: var(--ink3); }
.empty { color: var(--ink3); padding: var(--s4) 0; text-align: center; }

.tag { display: inline-flex; align-items: center; gap: 4px; font-size: 11.5px; font-weight: 600; border-radius: var(--r-pill); padding: 2px 9px; white-space: nowrap; background: var(--soft); color: var(--ink2); }
.tag.ok { background: var(--accent-soft); color: var(--accent); }
.tag.warn { background: var(--review-soft); color: var(--review-ink); }
.tag.err { background: var(--danger-soft); color: var(--danger); }

.btn { border: 1px solid var(--line); background: var(--surface); border-radius: var(--r-pill); padding: 8px 16px; font-weight: 600; color: var(--ink2); cursor: pointer; display: inline-flex; align-items: center; gap: var(--s2); white-space: nowrap; }
.btn:hover { background: var(--soft); }
.btn.primary { background: var(--accent); border-color: var(--accent); color: var(--accent-ink); }
.btn.primary:hover { filter: brightness(1.08); }
.btn.danger { color: var(--danger); }
.btn:disabled { opacity: .5; cursor: default; }

.seg { display: inline-flex; background: var(--soft); border-radius: var(--r-pill); padding: 3px; }
.seg button { border: 0; background: transparent; padding: 6px 14px; border-radius: var(--r-pill); color: var(--ink2); cursor: pointer; }
.seg button.on { background: var(--surface); color: var(--ink); font-weight: 600; box-shadow: 0 1px 2px rgba(0,0,0,.08); }
.field { display: flex; flex-direction: column; gap: var(--s1); margin-bottom: var(--s4); }
.field label { font-weight: 600; font-size: 13px; }
.field .help { color: var(--ink3); font-size: 12.5px; }
.input, select.input { border: 1px solid var(--line); background: var(--surface); border-radius: var(--r-s); padding: 10px 12px; width: 100%; }
.input:focus { outline: 2px solid var(--accent-soft); border-color: var(--accent); }
.toolbar { display: flex; flex-wrap: wrap; gap: var(--s3); align-items: center; margin-bottom: var(--s4); }
.stats { display: flex; gap: var(--s5); color: var(--ink2); margin-left: auto; flex-wrap: wrap; }
.stats b { color: var(--ink); }

table.table { width: 100%; border-collapse: collapse; }
.table th { text-align: left; font-size: 12px; font-weight: 600; color: var(--ink3); padding: 8px 10px; border-bottom: 1px solid var(--line); }
.table td { padding: 10px; border-bottom: 1px solid var(--line); vertical-align: middle; }
.table tr.link { cursor: pointer; } .table tr.link:hover td { background: var(--ground); }

.chart svg { display: block; width: 100%; height: 120px; }
.chart .axis { display: flex; justify-content: space-between; color: var(--ink3); font-size: 11px; margin-top: var(--s1); }
.progress { width: 96px; height: 6px; background: var(--soft); border-radius: var(--r-pill); overflow: hidden; }
.progress i { display: block; height: 100%; background: var(--good); }

.avatar { width: 48px; height: 48px; border-radius: 50%; background: var(--accent-soft); color: var(--accent); display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 17px; flex: none; }
.cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: var(--s3); }
.fc { background: var(--surface); border: 1px solid var(--line); border-radius: var(--r-m); overflow: hidden; display: flex; flex-direction: column; }
.fc.neg { border-color: #E3B5AF; }
.fc .top { display: flex; align-items: center; gap: var(--s2); padding: var(--s3) var(--s3) 0; }
.fc .item { color: var(--ink3); font-size: 12px; }
.fc .fb { margin-left: auto; display: inline-flex; }
.fc .recto { padding: var(--s2) var(--s3) var(--s3); font-weight: 600; }
.fc .verso { padding: var(--s3); background: var(--ground); border-top: 1px dashed var(--line); color: var(--ink2); font-size: 13px; flex: 1; white-space: pre-wrap; }
.fc .foot { padding: var(--s2) var(--s3); display: flex; gap: var(--s2); border-top: 1px solid var(--line); flex-wrap: wrap; }
.rank { width: 20px; height: 20px; border-radius: var(--r-badge); display: inline-flex; align-items: center; justify-content: center; font-weight: 700; font-size: 11px; }
.rank.A { background: var(--rank-a); color: var(--accent-ink); } .rank.B { background: var(--rank-b-soft); color: var(--rank-b); } .rank.C { background: var(--soft); color: var(--rank-c); }
.fb-pos { color: var(--accent); } .fb-neg { color: var(--danger); }

.timeline { list-style: none; margin: 0; padding: 0; }
.timeline li { display: grid; grid-template-columns: 120px 1fr; gap: var(--s3); padding: 8px 0; border-top: 1px solid var(--line); }
.timeline li:first-child { border-top: 0; }

.banner { display: flex; align-items: center; gap: var(--s3); background: var(--danger-soft); color: var(--danger); border-radius: var(--r-s); padding: var(--s3) var(--s4); margin-bottom: var(--s4); font-weight: 500; }
.banner .btn { margin-left: auto; }
.toast { position: fixed; bottom: 24px; left: 50%; transform: translateX(-50%); background: var(--ink); color: var(--surface); padding: 10px 18px; border-radius: var(--r-pill); font-weight: 500; z-index: 50; }
.scrim { position: fixed; inset: 0; background: var(--scrim); z-index: 40; }
.panel { position: fixed; top: 0; right: 0; bottom: 0; width: min(440px, 100vw); background: var(--surface); z-index: 41; padding: var(--s6); overflow-y: auto; box-shadow: -8px 0 24px rgba(0,0,0,.12); }
.panel-head { display: flex; align-items: center; justify-content: space-between; margin-bottom: var(--s5); }
.panel-head h2 { margin: 0; font-size: 20px; }
.icon-btn { border: 0; background: transparent; cursor: pointer; padding: 6px; border-radius: var(--r-s); display: inline-flex; color: var(--ink2); }
.icon-btn:hover { background: var(--soft); }
pre.invite { background: var(--ground); border: 1px solid var(--line); border-radius: var(--r-s); padding: var(--s3); white-space: pre-wrap; font: inherit; }

.login { min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: var(--s4); }
.login-card { width: min(380px, 100%); background: var(--surface); border: 1px solid var(--line); border-radius: var(--r-l); padding: var(--s8) var(--s6); }
.login-card img { width: 48px; height: 48px; display: block; margin-bottom: var(--s4); }
.login-card h1 { font-size: 24px; margin-bottom: var(--s1); }
.login-card .sub { color: var(--ink3); margin-bottom: var(--s6); }
.login-card .btn { width: 100%; justify-content: center; padding: 12px; }

@media (max-width: 760px) {
  .shell { display: block; }
  .side { position: fixed; left: 0; top: 0; z-index: 41; transform: translateX(-100%); transition: transform .2s ease; }
  .shell.drawer-open .side { transform: none; }
  .topbar { display: flex; align-items: center; gap: var(--s2); padding: var(--s3) var(--s4); background: var(--surface); border-bottom: 1px solid var(--line); position: sticky; top: 0; z-index: 30; font-weight: 700; }
  .main { padding: var(--s5) var(--s4) 48px; }
  h1 { font-size: 24px; }
  .kpis, .cols, .cols-even { grid-template-columns: 1fr 1fr; }
  .cols, .cols-even { grid-template-columns: 1fr; }
  .table thead { display: none; }
  .table tr { display: block; padding: 10px 0; border-bottom: 1px solid var(--line); }
  .table td { display: block; border: 0; padding: 2px 0; }
  .timeline li { grid-template-columns: 1fr; }
}
```

- [ ] **Step 6: `js/api.js`**

```js
// Client de l'API admin : Basic Auth, format d'erreur {"detail": {"code", "message"}}.
const KEY = 'collega-admin-auth';
let memory = null;

const MESSAGES = {
  NETWORK: 'Serveur injoignable.',
  RATE_LIMITED: 'Trop de tentatives, réessaie dans une minute.',
  USER_NOT_FOUND: 'Compte introuvable.',
  EMAIL_ALREADY_EXISTS: 'Un compte existe déjà avec cet e-mail.',
  COLLEGE_NOT_FOUND: 'Collège introuvable.',
  JOB_NOT_FOUND: 'Import introuvable.',
  VALIDATION_ERROR: 'Valeur refusée par le serveur.',
};

export class ApiError extends Error {
  constructor(status, code, message) {
    super(message);
    this.status = status;
    this.code = code;
  }
}

function token() {
  if (memory) return memory;
  try { return sessionStorage.getItem(KEY); } catch { return null; }
}

export function setCredentials(user, pass) {
  memory = btoa(unescape(encodeURIComponent(`${user}:${pass}`)));
  try { sessionStorage.setItem(KEY, memory); } catch { /* navigation privée : reste en mémoire */ }
}

export function hasCredentials() { return Boolean(token()); }

export function clearCredentials() {
  memory = null;
  try { sessionStorage.removeItem(KEY); } catch { /* rien à effacer */ }
}

export async function api(path, { method = 'GET', body, silent401 = false } = {}) {
  const headers = { Authorization: `Basic ${token()}` };
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  let res;
  try {
    res = await fetch(`/v1/admin${path}`, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) });
  } catch {
    throw new ApiError(0, 'NETWORK', MESSAGES.NETWORK);
  }
  if (res.status === 204) return null;
  const json = await res.json().catch(() => null);
  if (res.ok) return json;
  const detail = json && typeof json.detail === 'object' && json.detail ? json.detail : null;
  const code = detail?.code ?? `HTTP_${res.status}`;
  if (res.status === 401 && !silent401) {
    clearCredentials();
    window.dispatchEvent(new Event('admin:logout'));
  }
  throw new ApiError(res.status, code, MESSAGES[code] ?? detail?.message ?? `Erreur ${res.status}.`);
}

// Écran de connexion : un 401 y est une réponse attendue, pas une déconnexion.
export async function checkCredentials() {
  await api('/badges', { silent401: true });
}
```

- [ ] **Step 7: `js/router.js`**

```js
// Routes en hash : #/pilotage, #/testeuses/<id>… (Retour du navigateur, favoris).
const routes = [];

export function route(pattern, loader) {
  const re = new RegExp(`^${pattern.replace(/:(\w+)/g, '(?<$1>[^/]+)')}$`);
  routes.push({ re, loader });
}

export function currentPath() {
  return location.hash.replace(/^#/, '') || '/pilotage';
}

export function resolve(path) {
  for (const r of routes) {
    const m = path.match(r.re);
    if (m) return { loader: r.loader, params: m.groups ?? {} };
  }
  return null;
}

export function go(path) {
  location.hash = path;
}
```

- [ ] **Step 8: `js/ui.js`**

```js
// Fabriques DOM partagées. Tout texte passe par textContent (jamais innerHTML) ;
// seuls les SVG de icons.js, générés depuis le dépôt, sont injectés en innerHTML.
import { ICONS } from './icons.js';

export function h(tag, attrs = {}, ...children) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs ?? {})) {
    if (v === undefined || v === null || v === false) continue;
    if (k === 'class') el.className = v;
    else if (k.startsWith('on')) el.addEventListener(k.slice(2).toLowerCase(), v);
    else el.setAttribute(k, v === true ? '' : v);
  }
  for (const c of children.flat()) {
    if (c === null || c === undefined || c === false) continue;
    el.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return el;
}

export function icon(name, size = 16, cls = '') {
  const span = h('span', { class: `icon ${cls}`, 'aria-hidden': 'true', style: `display:inline-flex;width:${size}px;height:${size}px` });
  span.innerHTML = ICONS[name] ?? ICONS.more;
  const svg = span.firstElementChild;
  if (svg) { svg.setAttribute('width', size); svg.setAttribute('height', size); }
  return span;
}

const nf = new Intl.NumberFormat('fr-FR');
const euro = new Intl.NumberFormat('fr-FR', { style: 'currency', currency: 'EUR', maximumFractionDigits: 2 });
export const fmtInt = (n) => nf.format(Math.round(n ?? 0));
export const fmtEuro = (n) => euro.format(n ?? 0);
export const fmtDate = (iso) => (iso ? new Date(iso).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short', year: 'numeric' }) : '—');
export const fmtDateTime = (iso) => (iso ? new Date(iso).toLocaleString('fr-FR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : '—');

export function fmtAgo(iso) {
  if (!iso) return 'jamais';
  const d = new Date(iso);
  const days = Math.floor((startOfDay(new Date()) - startOfDay(d)) / 86400000);
  if (days <= 0) return `aujourd'hui, ${d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}`;
  if (days === 1) return 'hier';
  return `il y a ${days} j`;
}
const startOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());

export const STATUS_LABEL = { active: ['active', 'ok'], inactive: ['inactive', 'warn'], never_seen: ['jamais connectée', 'warn'] };
export const JOB_STATUS_LABEL = {
  pending: ['en attente', ''], processing: ['en cours', 'ok'], ocr_complete: ['génération', 'ok'],
  generation_complete: ['terminé', 'ok'], failed: ['échec', 'err'], stalled: ['bloqué', 'warn'],
};

export function tag(text, tone = '') {
  return h('span', { class: `tag ${tone}` }, text);
}

export function kpi({ label, value, previous, format = fmtInt, invert = false }) {
  const node = h('div', { class: 'kpi' }, h('div', { class: 'value' }, format(value)), h('div', { class: 'label' }, label));
  if (previous !== undefined && previous !== null) {
    const diff = value - previous;
    const better = invert ? diff < 0 : diff > 0;
    const text = diff === 0 ? 'stable vs période précédente' : `${diff > 0 ? '+' : '−'}${format(Math.abs(diff))} vs période précédente`;
    node.append(h('div', { class: `delta ${diff === 0 ? '' : better ? 'up' : 'down'}` }, text));
  }
  return node;
}

export function block(title, aside, ...children) {
  return h('section', { class: 'block' }, h('div', { class: 'block-head' }, h('h2', {}, title), aside ? h('span', { class: 'aside' }, aside) : null), ...children);
}

export function row(left, right, onClick) {
  return h('div', { class: `row${onClick ? ' link' : ''}`, onclick: onClick }, h('div', { class: 'left' }, left), right);
}

export function empty(text) {
  return h('div', { class: 'empty' }, text);
}

export function banner(error, onRetry) {
  return h('div', { class: 'banner', role: 'alert' }, icon('warning', 18), h('span', {}, error?.message ?? String(error)),
    onRetry ? h('button', { class: 'btn', onclick: onRetry }, icon('refresh', 16), 'Réessayer') : null);
}

export function toast(text) {
  const node = h('div', { class: 'toast', role: 'status' }, text);
  document.body.append(node);
  setTimeout(() => node.remove(), 2600);
}

export function panel(title, content) {
  const scrim = h('div', { class: 'scrim' });
  const node = h('aside', { class: 'panel', role: 'dialog', 'aria-label': title });
  const close = () => { scrim.remove(); node.remove(); document.removeEventListener('keydown', onKey); };
  const onKey = (e) => { if (e.key === 'Escape') close(); };
  scrim.addEventListener('click', close);
  document.addEventListener('keydown', onKey);
  node.append(h('div', { class: 'panel-head' }, h('h2', {}, title), h('button', { class: 'icon-btn', 'aria-label': 'Fermer', onclick: close }, icon('close', 20))), content);
  document.body.append(scrim, node);
  return { close, node };
}

// Barres en SVG : une valeur par jour, jours à 0 en trait gris.
export function bars(values, { labels = [], format = fmtInt } = {}) {
  const ns = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(ns, 'svg');
  const w = 600, hgt = 120, gap = 3, n = Math.max(values.length, 1);
  const bw = (w - gap * (n - 1)) / n;
  const max = Math.max(1, ...values);
  svg.setAttribute('viewBox', `0 0 ${w} ${hgt}`);
  svg.setAttribute('preserveAspectRatio', 'none');
  values.forEach((v, i) => {
    const rect = document.createElementNS(ns, 'rect');
    const bh = v > 0 ? Math.max(3, (v / max) * (hgt - 4)) : 3;
    rect.setAttribute('x', i * (bw + gap));
    rect.setAttribute('y', hgt - bh);
    rect.setAttribute('width', bw);
    rect.setAttribute('height', bh);
    rect.setAttribute('rx', 2);
    rect.setAttribute('fill', v > 0 ? 'var(--accent)' : 'var(--soft)');
    const title = document.createElementNS(ns, 'title');
    title.textContent = `${labels[i] ?? ''} : ${format(v)}`;
    rect.append(title);
    svg.append(rect);
  });
  const axis = labels.length ? h('div', { class: 'axis' }, h('span', {}, labels[0]), h('span', {}, labels[Math.floor(labels.length / 2)]), h('span', {}, labels[labels.length - 1])) : null;
  return h('div', { class: 'chart' }, svg, axis);
}

export function initials(nameOrEmail) {
  const base = (nameOrEmail || '?').split('@')[0];
  const parts = base.split(/[\s._-]+/).filter(Boolean);
  return ((parts[0]?.[0] ?? '?') + (parts[1]?.[0] ?? '')).toUpperCase();
}

export function displayName(t) {
  return t.first_name || t.email;
}
```

- [ ] **Step 9: `js/main.js`**

```js
import { api, clearCredentials, hasCredentials } from './api.js';
import { currentPath, resolve, route } from './router.js';
import { h, icon } from './ui.js';

const NAV = [
  { path: '/pilotage', label: 'Pilotage', icon: 'progress' },
  { path: '/testeuses', label: 'Testeuses', icon: 'profile', badge: 'testers' },
  { path: '/imports', label: 'Imports', icon: 'upload', badge: 'imports' },
  { path: '/qualite', label: 'Qualité des fiches', icon: 'document', badge: 'quality' },
  { path: '/couts', label: 'Coûts', icon: 'euro' },
  { path: '/reglages', label: 'Réglages', icon: 'settings' },
];

route('/pilotage', () => import('./views/pilotage.js'));
route('/testeuses', () => import('./views/testeuses.js'));
route('/testeuses/:id', () => import('./views/testeuse.js'));
route('/imports', () => import('./views/imports.js'));
route('/imports/:id', () => import('./views/import.js'));
route('/qualite', () => import('./views/qualite.js'));
route('/qualite/:id', () => import('./views/qualite.js'));
route('/couts', () => import('./views/couts.js'));
route('/reglages', () => import('./views/reglages.js'));

const app = document.getElementById('app');
let shell = null;
let cleanup = null;

function buildShell() {
  const links = NAV.map((n) => {
    const pill = n.badge ? h('span', { class: 'pill', hidden: true, 'data-badge': n.badge }) : null;
    return h('a', { class: 'nav-link', href: `#${n.path}`, 'data-path': n.path }, icon(n.icon, 18), n.label, pill);
  });
  const side = h('nav', { class: 'side' },
    h('div', { class: 'brand' }, h('img', { src: '/admin/logo.svg', alt: '' }), 'Collega admin'),
    ...links,
    h('div', { class: 'side-foot' }, h('a', { class: 'nav-link', href: '#', onclick: (e) => { e.preventDefault(); logout(); } }, icon('logout', 18), 'Se déconnecter')));
  const content = h('main', { class: 'main' });
  const root = h('div', { class: 'shell' },
    h('div', { class: 'topbar' }, h('button', { class: 'icon-btn', 'aria-label': 'Menu', onclick: () => root.classList.toggle('drawer-open') }, icon('more', 20)), 'Collega admin'),
    side, content);
  side.addEventListener('click', (e) => { if (e.target.closest('a')) root.classList.remove('drawer-open'); });
  return { root, content, links };
}

async function refreshBadges() {
  try {
    const { data } = await api('/badges');
    for (const el of shell.root.querySelectorAll('[data-badge]')) {
      const n = data[el.dataset.badge] ?? 0;
      el.textContent = String(n);
      el.hidden = n === 0;
    }
  } catch { /* les pastilles ne bloquent jamais l'écran */ }
}

async function render() {
  if (!hasCredentials()) return showLogin();
  if (!shell) { shell = buildShell(); app.replaceChildren(shell.root); }
  cleanup?.();
  cleanup = null;
  const path = currentPath();
  for (const a of shell.links) a.classList.toggle('on', path === a.dataset.path || path.startsWith(`${a.dataset.path}/`));
  const found = resolve(path) ?? resolve('/pilotage');
  shell.content.replaceChildren();
  window.scrollTo(0, 0);
  const view = await found.loader();
  cleanup = (await view.render(shell.content, found.params)) ?? null;
  refreshBadges();
}

async function showLogin() {
  shell = null;
  const { render: renderLogin } = await import('./views/login.js');
  app.replaceChildren();
  renderLogin(app, () => render());
}

function logout() {
  clearCredentials();
  cleanup?.();
  cleanup = null;
  showLogin();
}

window.addEventListener('hashchange', render);
window.addEventListener('admin:logout', () => { cleanup?.(); cleanup = null; showLogin(); });
window.addEventListener('admin:badges', refreshBadges);
render();
```

- [ ] **Step 10: `js/views/login.js`**

```js
import { ApiError, checkCredentials, clearCredentials, setCredentials } from '../api.js';
import { banner, h } from '../ui.js';

export function render(root, onSuccess) {
  const user = h('input', { class: 'input', id: 'u', autocomplete: 'username', required: true });
  const pass = h('input', { class: 'input', id: 'p', type: 'password', autocomplete: 'current-password', required: true });
  const error = h('div');
  const submit = h('button', { class: 'btn primary', type: 'submit' }, 'Se connecter');
  const form = h('form', { class: 'login-card', onsubmit: async (e) => {
    e.preventDefault();
    submit.disabled = true;
    error.replaceChildren();
    setCredentials(user.value.trim(), pass.value);
    try {
      await checkCredentials();
      onSuccess();
    } catch (err) {
      clearCredentials();
      const e2 = err instanceof ApiError && err.status === 401 ? new Error('Identifiant ou mot de passe incorrect.') : err;
      error.replaceChildren(banner(e2));
      submit.disabled = false;
    }
  } },
    h('img', { src: '/admin/logo.svg', alt: '' }),
    h('h1', {}, 'Collega admin'),
    h('div', { class: 'sub' }, 'Pilotage de la beta'),
    error,
    h('div', { class: 'field' }, h('label', { for: 'u' }, 'Identifiant'), user),
    h('div', { class: 'field' }, h('label', { for: 'p' }, 'Mot de passe'), pass),
    submit);
  root.append(h('div', { class: 'login' }, form));
  user.focus();
}
```

`checkCredentials()` passe `silent401: true` : un mauvais mot de passe affiche le bandeau sans émettre `admin:logout` (qui remplacerait l'écran).

- [ ] **Step 11: Vues provisoires**

Pour que les imports de `main.js` résolvent (test `test_imports_des_modules_existent` ne vérifie que les imports statiques, mais la navigation doit marcher), créer `pilotage.js`, `testeuses.js`, `testeuse.js`, `imports.js`, `import.js`, `qualite.js`, `couts.js`, `reglages.js` dans `js/views/` avec :

```js
import { h } from '../ui.js';

export async function render(root) {
  root.append(h('h1', {}, 'En construction'));
}
```

(remplacées en Tasks 8 et 9).

- [ ] **Step 12: Vérifier**

Run: `.venv/bin/python -m pytest tests/api/test_admin_front_assets.py -q` → PASS.
Vérification manuelle : lancer l'API en local contre la base de test migrée (lire `CLAUDE.md`/`docs` pour la commande exacte, typiquement `.venv/bin/uvicorn app.main:app --port 8000` avec les variables de `.env.test` ou équivalent ; `ADMIN_USERNAME`/`ADMIN_PASSWORD` de test), ouvrir `http://localhost:8000/admin/`, se connecter : mauvais mot de passe → bandeau ; bon → coquille avec menu et icônes ; largeur 390 px → menu en tiroir. Si possible, prendre des captures avec un navigateur sans tête (Playwright via `npx playwright screenshot` si disponible) ; sinon le noter pour l'utilisateur.

- [ ] **Step 13: Commit**

```bash
git add -A collega_backend/app/static/admin collega_backend/tests/api/test_admin_front_assets.py
git commit -m "feat(console): socle — coquille, styles de l'app, client API, routeur, connexion"
```

---

### Task 8: Console — Pilotage, Testeuses, fiche testeuse

**Files:**
- Replace: `collega_backend/app/static/admin/js/views/pilotage.js`, `testeuses.js`, `testeuse.js`

**Interfaces:**
- Consumes: `GET /v1/admin/pilot`, `GET /v1/admin/users/{id}`, `POST /v1/admin/users`, `PATCH /v1/admin/users/{id}/beta`, `POST /v1/admin/users/{id}/reset-password`, `POST /v1/admin/users/{id}/reset-quota`, `GET /v1/admin/config` (URL TestFlight) ; `ui.js`, `api.js`, `router.js` (Task 7).

- [ ] **Step 1: `views/pilotage.js`**

```js
import { api } from '../api.js';
import { go } from '../router.js';
import { JOB_STATUS_LABEL, STATUS_LABEL, banner, block, displayName, empty, fmtAgo, fmtEuro, h, icon, kpi, row, tag } from '../ui.js';

export async function render(root) {
  let data;
  try {
    ({ data } = await api('/pilot'));
  } catch (err) {
    root.append(banner(err, () => { root.replaceChildren(); render(root); }));
    return;
  }
  const today = new Date().toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long' });
  root.append(
    h('div', { class: 'page-head' }, h('div', {}, h('h1', {}, 'Pilotage de la beta'),
      h('div', { class: 'sub' }, `${today} · ${data.testers_total} testeuse${data.testers_total > 1 ? 's' : ''}`))),
    h('div', { class: 'grid kpis' },
      kpi({ label: 'ont révisé sur 7 jours', value: data.active_7d.value, previous: data.active_7d.previous }),
      kpi({ label: 'fiches révisées sur 7 jours', value: data.cards_7d.value, previous: data.cards_7d.previous }),
      kpi({ label: 'imports en échec sur 7 jours', value: data.failed_imports_7d.value, previous: data.failed_imports_7d.previous, invert: true }),
      kpi({ label: 'coût Claude sur 30 jours', value: data.cost_30d_eur.value, previous: data.cost_30d_eur.previous, format: fmtEuro, invert: true })),
    h('div', { class: 'grid cols' }, testersBlock(data.testers), watchBlock(data)),
  );
}

function testersBlock(testers) {
  const order = { never_seen: 0, inactive: 1, active: 2 };
  const sorted = [...testers].sort((a, b) => order[a.status] - order[b.status] || (b.last_seen_at ?? '').localeCompare(a.last_seen_at ?? ''));
  const rows = sorted.map((t) => {
    const [label, tone] = STATUS_LABEL[t.status];
    const right = t.status === 'active' ? tag(fmtAgo(t.last_seen_at), 'ok') : tag(label, tone);
    const left = [h('span', { class: 't' }, displayName(t)), t.streak >= 2 ? h('span', { class: 'muted' }, `· série ${t.streak} j`) : null];
    return row(left, right, () => go(`/testeuses/${t.user_id}`));
  });
  return block('Testeuses', h('a', { href: '#/testeuses', class: 'muted' }, 'Tout voir'), rows.length ? rows : empty('Aucune testeuse pour l\'instant.'));
}

function watchBlock(data) {
  const rows = [
    ...data.watch_jobs.map((j) => row(
      [icon('warning', 16, j.kind === 'failed' ? 'fb-neg' : ''), h('span', { class: 't' }, `Import ${j.college_name}`), h('span', { class: 'muted' }, j.user_email ? `· ${j.user_email}` : '')],
      tag(j.kind === 'failed' ? 'échec' : 'bloqué', j.kind === 'failed' ? 'err' : 'warn'),
      () => go(`/imports/${j.job_id}`))),
    ...data.watch_feedback.map((f) => row(
      [icon('thumbDown', 16, 'fb-neg'), h('span', { class: 't' }, f.college_name)],
      tag(`${f.negative_count} avis négatif${f.negative_count > 1 ? 's' : ''}`, 'warn'),
      () => go(`/qualite/${f.college_id}`))),
    ...data.running_jobs.map((j) => row(
      [icon('upload', 16), h('span', { class: 't' }, `Import ${j.college_name}`)],
      tag(`${JOB_STATUS_LABEL[j.status]?.[0] ?? j.status} ${Math.round(j.progress * 100)} %`, 'ok'),
      () => go(`/imports/${j.job_id}`))),
  ];
  return block('À surveiller', null, rows.length ? rows : empty('Rien à signaler.'));
}
```

- [ ] **Step 2: `views/testeuses.js`**

```js
import { api } from '../api.js';
import { go } from '../router.js';
import { STATUS_LABEL, banner, displayName, empty, fmtAgo, fmtDate, h, icon, panel, tag, toast } from '../ui.js';

const FILTERS = [['all', 'Toutes'], ['active', 'Actives'], ['inactive', 'Inactives'], ['never_seen', 'Jamais connectées']];

export async function render(root) {
  let pilot;
  let config;
  try {
    [{ data: pilot }, { data: config }] = await Promise.all([api('/pilot'), api('/config')]);
  } catch (err) {
    root.append(banner(err, () => { root.replaceChildren(); render(root); }));
    return;
  }
  let filter = 'all';
  const list = h('div');
  const seg = h('div', { class: 'seg', role: 'tablist' }, ...FILTERS.map(([key, label]) =>
    h('button', { class: key === filter ? 'on' : '', onclick: (e) => { filter = key; for (const b of seg.children) b.classList.toggle('on', b === e.currentTarget); draw(); } }, label)));

  function draw() {
    const rows = pilot.testers.filter((t) => filter === 'all' || t.status === filter);
    if (!rows.length) { list.replaceChildren(empty('Aucune testeuse dans ce filtre.')); return; }
    list.replaceChildren(h('table', { class: 'table' },
      h('thead', {}, h('tr', {}, ...['Testeuse', 'Créée le', 'Dernière activité', 'Série', 'Fiches 7 j', 'Collèges'].map((c) => h('th', {}, c)))),
      h('tbody', {}, ...rows.map((t) => {
        const [label, tone] = STATUS_LABEL[t.status];
        return h('tr', { class: 'link', onclick: () => go(`/testeuses/${t.user_id}`) },
          h('td', {}, h('div', {}, displayName(t)), t.first_name ? h('div', { class: 'muted' }, t.email) : null),
          h('td', {}, fmtDate(t.created_at)),
          h('td', {}, t.status === 'active' ? fmtAgo(t.last_seen_at) : tag(label, tone)),
          h('td', {}, t.streak ? `${t.streak} j` : '—'),
          h('td', {}, String(t.cards_7d)),
          h('td', {}, String(t.college_count)));
      }))));
  }

  root.append(
    h('div', { class: 'page-head' }, h('div', {}, h('h1', {}, 'Testeuses'), h('div', { class: 'sub' }, `${pilot.testers.length} compte${pilot.testers.length > 1 ? 's' : ''} beta`)),
      h('div', { class: 'actions' }, h('button', { class: 'btn primary', onclick: () => openCreate(config.testflight_url) }, icon('plus', 16), 'Nouvelle testeuse'))),
    h('div', { class: 'toolbar' }, seg),
    list);
  draw();
}

function randomPassword() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join('');
}

export function invitation({ firstName, email, password, testflightUrl }) {
  return [
    `Bonjour${firstName ? ` ${firstName}` : ''},`,
    '',
    'Merci de tester Collega. Pour installer la beta :',
    testflightUrl ? `1. Ouvre ce lien sur ton iPhone : ${testflightUrl}` : '1. Installe TestFlight depuis l\'App Store, puis ouvre l\'invitation reçue par e-mail.',
    '2. Installe Collega depuis TestFlight, puis connecte-toi avec :',
    `   Identifiant : ${email}`,
    `   Mot de passe : ${password}`,
    '',
    'Tes retours sont précieux : réponds simplement à ce message.',
  ].join('\n');
}

function openCreate(testflightUrl) {
  const email = h('input', { class: 'input', id: 'n-email', type: 'email', required: true, autocomplete: 'off' });
  const firstName = h('input', { class: 'input', id: 'n-first', autocomplete: 'off', maxlength: '100' });
  const error = h('div');
  const submit = h('button', { class: 'btn primary', type: 'submit' }, 'Créer le compte');
  const form = h('form', { onsubmit: async (e) => {
    e.preventDefault();
    submit.disabled = true;
    error.replaceChildren();
    const password = randomPassword();
    try {
      const { data } = await api('/users', { method: 'POST', body: { email: email.value.trim(), password, is_beta: true, first_name: firstName.value.trim() || null } });
      const text = invitation({ firstName: firstName.value.trim(), email: data.email, password, testflightUrl });
      form.replaceChildren(
        h('p', {}, 'Compte créé. Le mot de passe n\'est affiché qu\'une fois : copie le message maintenant.'),
        h('pre', { class: 'invite' }, text),
        h('div', { class: 'toolbar' },
          h('button', { class: 'btn primary', type: 'button', onclick: async () => { await navigator.clipboard.writeText(text); toast('Message copié'); } }, 'Copier le message d\'invitation'),
          h('button', { class: 'btn', type: 'button', onclick: () => { p.close(); go(`/testeuses/${data.user_id}`); } }, 'Voir la fiche')));
      window.dispatchEvent(new Event('admin:badges'));
    } catch (err) {
      error.replaceChildren(banner(err));
      submit.disabled = false;
    }
  } },
    error,
    h('div', { class: 'field' }, h('label', { for: 'n-email' }, 'E-mail'), email),
    h('div', { class: 'field' }, h('label', { for: 'n-first' }, 'Prénom'), firstName, h('div', { class: 'help' }, 'Facultatif, utilisé dans le message d\'invitation.')),
    h('div', { class: 'field' }, h('div', { class: 'help' }, 'Un mot de passe provisoire est généré ; le compte a l\'accès beta.')),
    submit);
  const p = panel('Nouvelle testeuse', form);
  email.focus();
}
```

`navigator.clipboard` exige un contexte sûr (HTTPS ou localhost) : c'est le cas en prod (Cloudflare) et en local.

- [ ] **Step 3: `views/testeuse.js`**

```js
import { api } from '../api.js';
import { go } from '../router.js';
import { JOB_STATUS_LABEL, STATUS_LABEL, banner, bars, block, displayName, empty, fmtAgo, fmtDate, fmtInt, h, icon, initials, kpi, panel, row, tag, toast } from '../ui.js';
import { invitation } from './testeuses.js';

export async function render(root, { id }) {
  let d;
  let config;
  try {
    [{ data: d }, { data: config }] = await Promise.all([api(`/users/${id}`), api('/config')]);
  } catch (err) {
    root.append(h('a', { class: 'crumb', href: '#/testeuses' }, icon('chevronLeft', 14), 'Testeuses'), banner(err, () => { root.replaceChildren(); render(root, { id }); }));
    return;
  }
  const [statusLabel, statusTone] = STATUS_LABEL[d.status];
  const reload = () => { root.replaceChildren(); render(root, { id }); };

  const actions = h('div', { class: 'actions' },
    h('button', { class: 'btn', onclick: () => resetPassword(d, config.testflight_url) }, 'Réinitialiser le mot de passe'),
    h('button', { class: 'btn', onclick: async () => {
      if (!confirm('Remettre à zéro le quota de réimports du mois ?')) return;
      await run(() => api(`/users/${id}/reset-quota`, { method: 'POST' }), 'Quota réinitialisé', reload);
    } }, 'Réinitialiser le quota'),
    h('button', { class: `btn ${d.is_beta ? 'danger' : ''}`, onclick: async () => {
      if (d.is_beta && !confirm('Retirer l\'accès beta à ce compte ?')) return;
      await run(() => api(`/users/${id}/beta`, { method: 'PATCH', body: { is_beta: !d.is_beta } }), d.is_beta ? 'Accès beta retiré' : 'Accès beta donné', reload);
    } }, d.is_beta ? 'Retirer la beta' : 'Donner la beta'));

  const labels = d.daily.map((x) => new Date(`${x.day}T12:00:00`).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' }));
  root.append(
    h('a', { class: 'crumb', href: '#/testeuses' }, icon('chevronLeft', 14), 'Testeuses'),
    h('div', { class: 'page-head' },
      h('div', { class: 'avatar' }, initials(displayName(d))),
      h('div', {}, h('h1', {}, displayName(d)),
        h('div', { class: 'sub' }, `${d.email} · compte créé le ${fmtDate(d.created_at)} `, d.is_beta ? tag('beta', 'ok') : tag('hors beta'))),
      actions),
    h('div', { class: 'grid kpis' },
      h('div', { class: 'kpi' }, h('div', { class: 'value' }, d.status === 'never_seen' ? '—' : fmtAgo(d.last_seen_at)), h('div', { class: 'label' }, 'dernière activité'), h('div', { class: 'delta' }, tag(statusLabel, statusTone))),
      kpi({ label: 'jours de série', value: d.streak }),
      kpi({ label: 'fiches révisées sur 30 jours', value: d.cards_30d }),
      kpi({ label: 'séances terminées sur 30 jours', value: d.sessions_30d })),
    block('Fiches révisées par jour', '30 derniers jours', bars(d.daily.map((x) => x.cards_reviewed), { labels })),
    h('div', { class: 'grid cols-even' },
      block('Collèges', String(d.colleges.length), d.colleges.length ? d.colleges.map(collegeRow) : empty('Aucun collège importé.')),
      block('Ses avis', feedbackAside(d.feedback), d.feedback.length ? d.feedback.map(feedbackRow) : empty('Aucun avis pour l\'instant.'))),
    block('Imports', String(d.jobs.length), d.jobs.length ? d.jobs.map((j) => row(
      [h('span', { class: 't' }, fmtDate(j.created_at)), h('span', { class: 'muted' }, `· ${fmtInt(j.card_count)} fiches`)],
      tag(...(JOB_STATUS_LABEL[j.status] ?? [j.status, ''])), () => go(`/imports/${j.job_id}`))) : empty('Aucun import.')),
  );
}

function collegeRow(c) {
  const done = c.status === 'generation_complete';
  const right = done ? tag(`${fmtInt(c.card_count)} fiches`, 'ok')
    : c.status === 'failed' ? tag('échec', 'err')
    : h('span', { class: 'left' }, h('span', { class: 'progress' }, h('i', { style: `width:${Math.round(c.progress * 100)}%` })), h('span', { class: 'muted' }, `${Math.round(c.progress * 100)} %`));
  return row(h('span', { class: 't' }, c.college_name), right, () => go(`/qualite/${c.college_id}`));
}

function feedbackAside(list) {
  const pos = list.filter((f) => f.feedback === 'positive').length;
  return [icon('thumbUp', 14), ` ${pos}   `, icon('thumbDown', 14), ` ${list.length - pos}`];
}

function feedbackRow(f) {
  const positive = f.feedback === 'positive';
  return row([icon(positive ? 'thumbUp' : 'thumbDown', 16, positive ? 'fb-pos' : 'fb-neg'), h('span', { class: 't' }, `${f.college_name} · item ${f.item_number ?? '?'} · ${f.recto}`)],
    h('span', { class: 'muted' }, fmtAgo(f.at)));
}

async function run(action, message, after) {
  try {
    await action();
    toast(message);
    window.dispatchEvent(new Event('admin:badges'));
    after();
  } catch (err) {
    toast(err.message);
  }
}

async function resetPassword(d, testflightUrl) {
  if (!confirm('Générer un nouveau mot de passe ? Tous ses appareils seront déconnectés.')) return;
  try {
    const { data } = await api(`/users/${d.user_id}/reset-password`, { method: 'POST' });
    const text = invitation({ firstName: d.first_name, email: d.email, password: data.temporary_password, testflightUrl });
    panel('Nouveau mot de passe', h('div', {},
      h('p', {}, 'Affiché une seule fois. Copie le message et envoie-le.'),
      h('pre', { class: 'invite' }, text),
      h('button', { class: 'btn primary', onclick: async () => { await navigator.clipboard.writeText(text); toast('Message copié'); } }, 'Copier le message')));
  } catch (err) {
    toast(err.message);
  }
}
```

`feedbackAside` renvoie un tableau : `block()` le passe à `h('span', …, aside)` qui aplatit ses enfants (`children.flat()`).

- [ ] **Step 4: Vérifier**

Run: `.venv/bin/python -m pytest tests/api/test_admin_front_assets.py -q` → PASS.
Vérification manuelle (API locale sur base de test) : créer 2 comptes via la console (panneau, message copié), injecter de l'activité (`psql` ou un petit script : lignes `activity_days` sur plusieurs jours), puis vérifier Pilotage (chiffres, tri, lien vers la fiche), Testeuses (filtres), fiche (graphique, actions : reset mot de passe → panneau ; retirer la beta → tag « hors beta »). Tester un prénom `<img src=x onerror=alert(1)>` : il doit s'afficher en texte.

- [ ] **Step 5: Commit**

```bash
git add collega_backend/app/static/admin/js/views
git commit -m "feat(console): écrans Pilotage, Testeuses et fiche testeuse"
```

---

### Task 9: Console — Imports, détail d'import, Qualité, Coûts, Réglages

**Files:**
- Replace: `collega_backend/app/static/admin/js/views/imports.js`, `import.js`, `qualite.js`, `couts.js`, `reglages.js`
- Modify: `collega_backend/app/services/admin_pilot.py` (`usage_breakdown`), `collega_backend/app/schemas/admin.py` (`UsageData`), `collega_backend/app/api/v1/admin/usage.py`
- Test: `collega_backend/tests/api/test_admin_usage_breakdown_pg.py`
- Delete: plus rien de l'ancienne console ne doit rester (vérifier `git grep -n "goOverview\|basicHeader" collega_backend/app/static` → vide).

**Interfaces:**
- Consumes: `GET /v1/admin/queue`, `GET /v1/admin/jobs/{id}`, `POST /v1/admin/jobs/{id}/stop`, `DELETE /v1/admin/colleges/{id}`, `GET /v1/admin/colleges`, `GET /v1/admin/colleges/{id}/stats`, `GET /v1/admin/colleges/{id}/cards`, `POST /v1/admin/badges/quality-seen`, `GET /v1/admin/usage`, `GET/PATCH /v1/admin/config`, `GET /v1/admin/pilot` (noms de collèges des imports en cours). Lire l'ancienne `index.html` (via `git show main:collega_backend/app/static/admin/index.html`) pour les champs exacts affichés par le détail d'import (timeline, confiance OCR, découpage `segmentation_report`) et reprendre **toutes** ses informations.

- [ ] **Step 1: `views/imports.js`**

```js
import { api } from '../api.js';
import { go } from '../router.js';
import { JOB_STATUS_LABEL, banner, empty, fmtInt, h, tag } from '../ui.js';

const FILTERS = [['all', 'Tous'], ['running', 'En cours'], ['failed', 'En échec'], ['done', 'Terminés']];
const RUNNING = new Set(['pending', 'processing', 'ocr_complete']);

export async function render(root) {
  let filter = 'all';
  let jobs = [];
  let names = {};
  const list = h('div');
  const error = h('div');
  const seg = h('div', { class: 'seg' }, ...FILTERS.map(([key, label]) =>
    h('button', { class: key === filter ? 'on' : '', onclick: (e) => { filter = key; for (const b of seg.children) b.classList.toggle('on', b === e.currentTarget); draw(); } }, label)));

  async function load() {
    try {
      const [{ data }, { data: colleges }] = await Promise.all([api('/queue'), api('/colleges')]);
      jobs = data;
      names = Object.fromEntries(colleges.map((c) => [c.college_id, c]));
      error.replaceChildren();
      draw();
    } catch (err) {
      error.replaceChildren(banner(err, load));
    }
  }

  function draw() {
    const rows = jobs.filter((j) => filter === 'all' || (filter === 'running' && RUNNING.has(j.status)) || (filter === 'failed' && j.status === 'failed') || (filter === 'done' && j.status === 'generation_complete'));
    if (!rows.length) { list.replaceChildren(empty('Aucun import dans ce filtre.')); return; }
    list.replaceChildren(h('table', { class: 'table' },
      h('thead', {}, h('tr', {}, ...['Collège', 'Testeuse', 'Statut', 'OCR', 'Fiches', 'Durée'].map((c) => h('th', {}, c)))),
      h('tbody', {}, ...rows.map((j) => {
        const c = names[j.college_id];
        return h('tr', { class: 'link', onclick: () => go(`/imports/${j.job_id}`) },
          h('td', {}, c?.college_name ?? 'Collège supprimé'),
          h('td', {}, c?.user_email ?? '—'),
          h('td', {}, tag(...(JOB_STATUS_LABEL[j.status] ?? [j.status, '']))),
          h('td', {}, j.college_total_pages ? `${j.college_ocr_page_progress}/${j.college_total_pages}` : '—'),
          h('td', {}, fmtInt(j.card_count)),
          h('td', {}, `${Math.round(j.elapsed_seconds / 60)} min`));
      }))));
  }

  root.append(h('div', { class: 'page-head' }, h('div', {}, h('h1', {}, 'Imports'), h('div', { class: 'sub' }, '50 derniers imports, rafraîchis toutes les 5 secondes.'))),
    error, h('div', { class: 'toolbar' }, seg), list);
  await load();
  const timer = setInterval(load, 5000);
  return () => clearInterval(timer);
}
```

- [ ] **Step 2: `views/import.js`**

Reprendre les informations de l'ancien détail (lire l'ancien fichier pour la mise en forme du `segmentation_report` et des événements) :

```js
import { api } from '../api.js';
import { go } from '../router.js';
import { JOB_STATUS_LABEL, banner, block, empty, fmtDateTime, fmtInt, h, icon, row, tag, toast } from '../ui.js';

const RUNNING = new Set(['pending', 'processing', 'ocr_complete']);

export async function render(root, { id }) {
  const content = h('div');
  root.append(h('a', { class: 'crumb', href: '#/imports' }, icon('chevronLeft', 14), 'Imports'), content);

  async function load() {
    let d;
    let college;
    try {
      ({ data: d } = await api(`/jobs/${id}`));
      college = (await api('/colleges')).data.find((c) => c.college_id === d.college_id);
    } catch (err) {
      content.replaceChildren(banner(err, load));
      return;
    }
    const actions = h('div', { class: 'actions' },
      RUNNING.has(d.status) ? h('button', { class: 'btn', onclick: async () => {
        if (!confirm('Arrêter cet import ?')) return;
        try { await api(`/jobs/${id}/stop`, { method: 'POST' }); toast('Import arrêté'); load(); } catch (err) { toast(err.message); }
      } }, 'Arrêter') : null,
      h('button', { class: 'btn danger', onclick: async () => {
        if (!confirm('Supprimer ce collège, ses fiches et ses fichiers ? Action définitive.')) return;
        try { await api(`/colleges/${d.college_id}`, { method: 'DELETE' }); toast('Collège supprimé'); go('/imports'); } catch (err) { toast(err.message); }
      } }, icon('trash', 16), 'Supprimer le collège'));
    const pages = d.total_pages ? `${d.ocr_page_progress}/${d.total_pages} pages` : 'pages inconnues';
    content.replaceChildren(
      h('div', { class: 'page-head' }, h('div', {}, h('h1', {}, `Import ${college?.college_name ?? ''}`.trim()),
        h('div', { class: 'sub' }, `${college?.user_email ?? 'compte supprimé'} · lancé ${fmtDateTime(d.created_at)} `, tag(...(JOB_STATUS_LABEL[d.status] ?? [d.status, ''])))), actions),
      d.error_message ? h('div', { class: 'banner' }, icon('warning', 18), h('span', {}, d.error_message)) : null,
      h('div', { class: 'grid kpis' },
        h('div', { class: 'kpi' }, h('div', { class: 'value' }, pages), h('div', { class: 'label' }, 'OCR')),
        h('div', { class: 'kpi' }, h('div', { class: 'value' }, fmtInt(d.card_count)), h('div', { class: 'label' }, 'fiches générées')),
        h('div', { class: 'kpi' }, h('div', { class: 'value' }, String(d.items.length)), h('div', { class: 'label' }, 'items détectés')),
        h('div', { class: 'kpi' }, h('div', { class: 'value' }, d.hash_shared ? 'oui' : 'non'), h('div', { class: 'label' }, 'PDF déjà connu (cache)'))),
      h('div', { class: 'grid cols' },
        block('Déroulé', `${d.timeline.length} événements`, d.timeline.length
          ? h('ul', { class: 'timeline' }, ...d.timeline.map((e) => h('li', {}, h('span', { class: 'muted' }, fmtDateTime(e.created_at)),
            h('span', {}, h('b', {}, e.event_type), e.page != null ? ` · page ${e.page}/${e.total ?? '?'}` : '', e.message ? h('div', { class: 'muted' }, e.message) : null))))
          : empty('Aucun événement.')),
        block('Confiance OCR par item', null, d.items.length ? d.items.map((it) => row(h('span', {}, `Item ${it.item_number}`),
          tag(`${Math.round(it.ocr_confidence_score * 100)} %`, it.low_confidence ? 'warn' : 'ok'))) : empty('Aucun item.'))),
      segmentation(d));
    if (RUNNING.has(d.status)) timer = setTimeout(load, 5000);
  }

  let timer = null;
  await load();
  return () => clearTimeout(timer);
}

// Rapport de découpage (JobDetailData.segmentation = segmentation_overview(...)) :
// items → pages, sections hors item, pages blanches, avertissements. Même contenu
// que l'ancienne console (renderSegmentation), replié dans un <details>.
function segmentation(d) {
  const seg = d.segmentation;
  if (!seg) return null;
  const items = seg.items || [];
  const sections = seg.sections || [];
  const warnings = seg.warnings || [];
  const cell = (v) => h('td', {}, v === null || v === undefined ? '—' : String(v));
  const rows = [
    ...items.map((it) => h('tr', {}, cell(`Item ${it.item_number}`), cell(it.pages), cell(it.rang || '—'), cell(`${it.objectives_a ?? '—'} / ${it.objectives_b ?? '—'}`))),
    ...sections.map((sct) => h('tr', {}, h('td', { class: 'muted' }, String(sct.label)), cell(sct.pages), cell('—'), cell('—'))),
    seg.blank_pages ? h('tr', {}, h('td', { class: 'muted' }, 'pages blanches'), cell(seg.blank_pages), cell('—'), cell('—')) : null,
  ];
  return h('details', { class: 'block' },
    h('summary', {}, h('b', {}, `Découpage : ${items.length} items, ${sections.length} sections, ${warnings.length} avertissements`)),
    h('table', { class: 'table' }, h('thead', {}, h('tr', {}, ...['Item / section', 'Pages', 'Rang', 'Objectifs A / B'].map((c) => h('th', {}, c)))), h('tbody', {}, ...rows)),
    warnings.length ? h('ul', { class: 'muted' }, ...warnings.map((w) => h('li', {}, String(w)))) : null);
}
```

- [ ] **Step 3: `views/qualite.js`**

```js
import { api } from '../api.js';
import { go } from '../router.js';
import { banner, empty, fmtInt, h, icon, tag } from '../ui.js';

const FILTERS = [['all', 'Toutes'], ['negative', 'Avis négatifs'], ['low', 'Confiance OCR faible']];

export async function render(root, { id } = {}) {
  let colleges;
  try {
    ({ data: colleges } = await api('/colleges'));
    await api('/badges/quality-seen', { method: 'POST' });
    window.dispatchEvent(new Event('admin:badges'));
  } catch (err) {
    root.append(banner(err, () => { root.replaceChildren(); render(root, { id }); }));
    return;
  }
  root.append(h('div', { class: 'page-head' }, h('div', {}, h('h1', {}, 'Qualité des fiches'))));
  if (!colleges.length) { root.append(empty('Aucun collège importé pour l\'instant.')); return; }

  const current = colleges.find((c) => c.college_id === id) ?? colleges.find((c) => c.negative_count > 0) ?? colleges[0];
  const select = h('select', { class: 'input', style: 'width:auto', onchange: (e) => go(`/qualite/${e.target.value}`) },
    ...colleges.map((c) => h('option', { value: c.college_id, selected: c.college_id === current.college_id }, `${c.college_name} — ${c.user_email ?? 'compte supprimé'}${c.negative_count ? ` (${c.negative_count} négatifs)` : ''}`)));
  let filter = current.negative_count ? 'negative' : 'all';
  const stats = h('div', { class: 'stats' });
  const grid = h('div', { class: 'cards' });
  const seg = h('div', { class: 'seg' }, ...FILTERS.map(([key, label]) =>
    h('button', { class: key === filter ? 'on' : '', onclick: (e) => { filter = key; for (const b of seg.children) b.classList.toggle('on', b === e.currentTarget); draw(); } }, label)));
  root.append(h('div', { class: 'toolbar' }, select, seg, stats), grid);

  let cards;
  try {
    const [{ data: s }, { data: c }] = await Promise.all([api(`/colleges/${current.college_id}/stats`), api(`/colleges/${current.college_id}/cards`)]);
    cards = c;
    const rated = cards.filter((x) => x.user_feedback);
    const positive = rated.filter((x) => x.user_feedback === 'positive').length;
    stats.replaceChildren(
      h('span', {}, h('b', {}, fmtInt(cards.length)), ' fiches'),
      h('span', {}, h('b', {}, fmtInt(s.items_ocr_confidence.length)), ' items'),
      h('span', {}, h('b', {}, rated.length ? `${Math.round((positive / rated.length) * 100)} %` : '—'), ' avis positifs'),
      h('span', {}, h('b', {}, fmtInt(cards.filter((x) => x.low_confidence).length)), ' OCR faible'));
  } catch (err) {
    grid.replaceChildren(banner(err));
    return;
  }

  function draw() {
    const shown = cards.filter((c) => filter === 'all' || (filter === 'negative' && c.user_feedback === 'negative') || (filter === 'low' && c.low_confidence));
    grid.replaceChildren(...(shown.length ? shown.map(card) : [empty('Aucune fiche dans ce filtre.')]));
  }
  draw();
}

function card(c) {
  const fb = c.user_feedback === 'negative' ? icon('thumbDown', 16, 'fb-neg') : c.user_feedback === 'positive' ? icon('thumbUp', 16, 'fb-pos') : null;
  return h('article', { class: `fc${c.user_feedback === 'negative' ? ' neg' : ''}` },
    h('div', { class: 'top' }, h('span', { class: `rank ${c.rang}` }, c.rang), h('span', { class: 'item' }, `Item ${c.item_number ?? '?'}`), h('span', { class: 'fb' }, fb)),
    h('div', { class: 'recto' }, c.recto),
    h('div', { class: 'verso' }, c.verso),
    h('div', { class: 'foot' }, tag(c.card_type.replace('_', ' ')), c.low_confidence ? tag(`OCR ${c.ocr_confidence_score.toFixed(2)}`, 'warn') : null));
}
```

- [ ] **Step 4: Coûts — ventilation par jour et par collège (backend, TDD)**

`/v1/admin/usage` donne totaux, 30 j, par type, par modèle, par utilisatrice, mais ni série par jour, ni coût par collège, ni coût moyen d'un import (spec § 3.2, écran 7). Ajouter trois champs à `UsageData`.

Test d'abord, `tests/api/test_admin_usage_breakdown_pg.py` :

```python
"""GET /v1/admin/usage : coût par jour (30 j), par collège (30 j), coût moyen d'un import."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest
from httpx import AsyncClient

from app.models.claude_usage import ClaudeUsage
from tests.api_pg import ADMIN_AUTH
from tests.factories import make_college, make_job, make_user

pytestmark = pytest.mark.pg


async def test_ventilation(pg_client: AsyncClient, pg_factory):
    now = datetime.now(UTC)
    async with pg_factory() as db:
        user = await make_user(db)
        college = await make_college(db, user, ref_id=4)
        done = await make_job(db, college, status="generation_complete")
        failed = await make_job(db, college, status="failed")

        def usage(job, days_ago, tokens, kind="generation"):
            return ClaudeUsage(
                created_at=now - timedelta(days=days_ago), user_id=user.id, college_id=college.id, job_id=job.id,
                kind=kind, model="claude-sonnet-4-6", input_tokens=tokens, output_tokens=0,
            )

        db.add_all([usage(done, 0, 1_000_000), usage(done, 2, 1_000_000), usage(failed, 1, 5_000_000), usage(done, 45, 1_000_000)])
        await db.commit()

    data = (await pg_client.get("/v1/admin/usage", auth=ADMIN_AUTH)).json()["data"]
    assert len(data["daily"]) == 30
    assert data["daily"][-1]["day"] == now.date().isoformat()
    assert data["daily"][-1]["cost_eur"] > 0 and data["daily"][-4]["cost_eur"] == 0
    assert [c["college_name"] for c in data["by_college"]] == ["Cardiologie"]
    # Seul le job terminé compte : 3 M tokens d'entrée sur un job, jours confondus.
    per_million = data["daily"][-1]["cost_eur"]
    assert data["avg_import_cost_eur"] == pytest.approx(3 * per_million, rel=1e-3)


async def test_base_vide(pg_client: AsyncClient):
    data = (await pg_client.get("/v1/admin/usage", auth=ADMIN_AUTH)).json()["data"]
    assert len(data["daily"]) == 30 and all(d["cost_eur"] == 0 for d in data["daily"])
    assert data["by_college"] == [] and data["avg_import_cost_eur"] == 0
```

(Si `ClaudeUsage` n'a pas de valeur par défaut pour `id`, ajouter `id=uuid.uuid4()` ; lire `app/models/claude_usage.py`.)

Schémas, dans `app/schemas/admin.py` avant `UsageData` :

```python
class DailyCostData(BaseModel):
    day: str
    cost_eur: float


class CollegeCostData(BaseModel):
    college_id: str | None
    college_name: str
    cost_eur: float
```

et dans `UsageData` : `daily: list[DailyCostData] = []`, `by_college: list[CollegeCostData] = []`, `avg_import_cost_eur: float = 0.0`.

Service, dans `app/services/admin_pilot.py` (imports : `from datetime import UTC, time`, `from app.schemas.admin import CollegeCostData, DailyCostData`) :

```python
COST_WINDOW_DAYS = 30


async def usage_breakdown(
    db: AsyncSession, now: datetime
) -> tuple[list[DailyCostData], list[CollegeCostData], float]:
    """Coût par jour et par collège sur 30 jours ; coût moyen de génération d'un import terminé."""
    first_day = now.date() - timedelta(days=COST_WINDOW_DAYS - 1)
    start = datetime.combine(first_day, time.min, tzinfo=UTC)
    sums = (func.sum(ClaudeUsage.input_tokens), func.sum(ClaudeUsage.output_tokens))

    day_col = func.date(ClaudeUsage.created_at)
    per_day: dict[date, UsageTotals] = defaultdict(UsageTotals)
    for day, model, u_in, u_out in (
        await db.execute(
            select(day_col, ClaudeUsage.model, *sums).where(ClaudeUsage.created_at >= start).group_by(day_col, ClaudeUsage.model)
        )
    ).all():
        per_day[day].add(model, u_in or 0, u_out or 0)
    daily = []
    for i in range(COST_WINDOW_DAYS):
        day = first_day + timedelta(days=i)
        daily.append(DailyCostData(day=day.isoformat(), cost_eur=per_day[day].cost_eur if day in per_day else 0.0))

    per_college: dict[tuple[uuid.UUID | None, int | None], UsageTotals] = defaultdict(UsageTotals)
    for college_id, ref_id, model, u_in, u_out in (
        await db.execute(
            select(ClaudeUsage.college_id, College.college_ref_id, ClaudeUsage.model, *sums)
            .outerjoin(College, College.id == ClaudeUsage.college_id)
            .where(ClaudeUsage.created_at >= now - timedelta(days=COST_WINDOW_DAYS))
            .group_by(ClaudeUsage.college_id, College.college_ref_id, ClaudeUsage.model)
        )
    ).all():
        per_college[(college_id, ref_id)].add(model, u_in or 0, u_out or 0)
    by_college = sorted(
        (
            CollegeCostData(
                college_id=str(cid) if cid else None,
                college_name=college_name(ref) if ref is not None else "Collège supprimé",
                cost_eur=t.cost_eur,
            )
            for (cid, ref), t in per_college.items()
        ),
        key=lambda c: c.cost_eur,
        reverse=True,
    )

    per_job: dict[uuid.UUID, UsageTotals] = defaultdict(UsageTotals)
    for job_id, model, u_in, u_out in (
        await db.execute(
            select(ClaudeUsage.job_id, ClaudeUsage.model, *sums)
            .join(GenerationJob, GenerationJob.id == ClaudeUsage.job_id)
            .where(ClaudeUsage.kind == "generation", GenerationJob.status == "generation_complete")
            .group_by(ClaudeUsage.job_id, ClaudeUsage.model)
        )
    ).all():
        per_job[job_id].add(model, u_in or 0, u_out or 0)
    avg = round(sum(t.cost_eur for t in per_job.values()) / len(per_job), 4) if per_job else 0.0
    return daily, by_college, avg
```

`func.date(timestamptz)` suit le fuseau de la session Postgres (UTC dans le conteneur et dans la base de test) ; si le test échoue sur le jour limite, remplacer par `func.date(func.timezone("UTC", ClaudeUsage.created_at))`.

Route : dans `get_usage` (`app/api/v1/admin/usage.py`), avant le `return`, `daily, by_college, avg_import = await admin_pilot.usage_breakdown(db, datetime.now(UTC))` et passer `daily=daily, by_college=by_college, avg_import_cost_eur=avg_import` à `UsageData(...)` (import `from app.services import admin_pilot`).

Run: `.venv/bin/python -m pytest tests/api/test_admin_usage_breakdown_pg.py tests/api/test_admin_usage.py -q` → PASS ; `.venv/bin/mypy app/core app/services` → 0 erreur.

- [ ] **Step 5: `views/couts.js`**

```js
import { api } from '../api.js';
import { banner, bars, block, empty, fmtEuro, fmtInt, h, kpi, row } from '../ui.js';

const KIND = { generation: 'Génération des fiches', regeneration: 'Régénérations', evaluation: 'Évaluations pendant le drill' };

export async function render(root) {
  let u;
  try {
    ({ data: u } = await api('/usage'));
  } catch (err) {
    root.append(banner(err, () => { root.replaceChildren(); render(root); }));
    return;
  }
  const labels = u.daily.map((d) => new Date(`${d.day}T12:00:00`).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' }));
  const money = (value) => h('b', {}, fmtEuro(value));
  root.append(
    h('div', { class: 'page-head' }, h('div', {}, h('h1', {}, 'Coûts'), h('div', { class: 'sub' }, 'Consommation Claude, au tarif de chaque modèle.'))),
    h('div', { class: 'grid kpis' },
      kpi({ label: 'coût sur 30 jours', value: u.last_30_days.cost_eur, format: fmtEuro }),
      kpi({ label: 'coût total', value: u.cost_eur, format: fmtEuro }),
      kpi({ label: 'coût moyen d\'un import', value: u.avg_import_cost_eur, format: fmtEuro }),
      kpi({ label: 'tokens sur 30 jours', value: u.last_30_days.input_tokens + u.last_30_days.output_tokens })),
    block('Coût par jour', '30 derniers jours', bars(u.daily.map((d) => d.cost_eur), { labels, format: fmtEuro })),
    h('div', { class: 'grid cols-even' },
      block('Par testeuse', '30 jours', u.by_user.length ? u.by_user.map((x) => row(h('span', { class: 't' }, x.email ?? 'compte supprimé'), money(x.last_30_days.cost_eur))) : empty('Aucune consommation.')),
      block('Par collège', '30 jours', u.by_college.length ? u.by_college.map((c) => row(h('span', { class: 't' }, c.college_name), money(c.cost_eur))) : empty('Aucune consommation.'))),
    block('Par usage', 'depuis le début', Object.entries(u.by_kind).map(([k, t]) => row(h('span', {}, KIND[k] ?? k),
      h('span', {}, money(t.cost_eur), h('span', { class: 'muted' }, ` · ${fmtInt(t.input_tokens + t.output_tokens)} tokens`))))),
  );
}
```

- [ ] **Step 6: `views/reglages.js`**

```js
import { api } from '../api.js';
import { banner, block, h, toast } from '../ui.js';

const FIELDS = [
  ['inactivity_days', 'Seuil d\'inactivité (jours)', 'Au-delà, une testeuse est signalée « inactive » dans la pastille et sur l\'accueil.', 'number', { min: 1, max: 60 }],
  ['testflight_url', 'Lien public TestFlight', 'Inséré dans le message d\'invitation. Laisser vide si les invitations passent par e-mail Apple.', 'url', { placeholder: 'https://testflight.apple.com/join/…' }],
  ['reload_count_max', 'Réimports par collège', 'Nombre de réimports autorisés pour un même collège.', 'number', { min: 0 }],
  ['monthly_reloads_max', 'Réimports par mois', 'Plafond mensuel de réimports par compte.', 'number', { min: 0 }],
];

export async function render(root) {
  let config;
  try {
    ({ data: config } = await api('/config'));
  } catch (err) {
    root.append(banner(err, () => { root.replaceChildren(); render(root); }));
    return;
  }
  const error = h('div');
  const inputs = {};
  const form = h('form', { onsubmit: async (e) => {
    e.preventDefault();
    const body = {};
    for (const [key, , , type] of FIELDS) {
      const v = inputs[key].value.trim();
      body[key] = type === 'number' ? Number(v) : v;
    }
    try {
      ({ data: config } = await api('/config', { method: 'PATCH', body }));
      error.replaceChildren();
      toast('Réglages enregistrés');
      window.dispatchEvent(new Event('admin:badges'));
    } catch (err) {
      error.replaceChildren(banner(err));
    }
  } }, error,
    ...FIELDS.map(([key, label, help, type, attrs]) => {
      inputs[key] = h('input', { class: 'input', id: key, type, value: String(config[key] ?? ''), ...attrs });
      return h('div', { class: 'field' }, h('label', { for: key }, label), inputs[key], h('div', { class: 'help' }, help));
    }),
    h('button', { class: 'btn primary', type: 'submit' }, 'Enregistrer'));
  root.append(h('div', { class: 'page-head' }, h('div', {}, h('h1', {}, 'Réglages'), h('div', { class: 'sub' }, 'Appliqués en 30 secondes au plus, sans redémarrage.'))), block('Beta et anti-spam', null, form));
}
```

- [ ] **Step 7: Vérifier**

Run: `.venv/bin/python -m pytest tests/api/test_admin_front_assets.py tests/api/test_admin_usage.py tests/api/test_admin_usage_breakdown_pg.py -q` → PASS.
Vérification manuelle sur l'API locale : chaque écran du menu, liens Pilotage → import / qualité, filtres, rafraîchissement des imports (quitter l'écran arrête les requêtes : onglet Réseau), réglage d'une URL `javascript:` refusé (bandeau), largeur 390 px. Aucune erreur dans la console du navigateur.

- [ ] **Step 8: Commit**

```bash
git add -A collega_backend/app collega_backend/tests
git commit -m "feat(console): écrans Imports, Qualité, Coûts et Réglages"
```

---

### Task 10: App — envoi du résumé d'activité + confidentialité

**Files:**
- Create: `collega_app/lib/features/today/data/activity_reporter.dart`
- Modify: `collega_app/lib/features/drill/drill_providers.dart`, `collega_app/lib/app.dart`, `collega_app/assets/legal/privacy.md`, `collega_backend/app/static/legal/privacy.md`
- Test: `collega_app/test/features/today/activity_reporter_test.dart`

**Interfaces:**
- Consumes: `DailySessionRepository.weekCounts`, `completedDays`, `quietDays` ; `streakLength` (`lib/features/today/domain/streak.dart`) ; `planningProvider` (`postponedDays`) ; `apiClientProvider` (`.dio`) ; `databaseProvider` ; `epochDayOf` / `dateOfEpochDay` (`lib/core/utils/epoch_day.dart`).
- Produces:
  - `class ActivitySummary { final int day; final int cardsReviewed; final bool sessionCompleted; final int streak; Map<String, Object> toJson(); }`
  - `class ActivityReporter { ActivityReporter({required Dio dio, required DailySessionRepository repo, required Future<Set<int>> Function() postponedDays, Duration debounce = const Duration(seconds: 30)}); Future<ActivitySummary> summarize(int day); Future<void> report(int day); void schedule(int day); Future<void> reportRecent({required int today, int days = 7}); void dispose(); }`
  - `final activityReporterProvider = Provider<ActivityReporter>(...)`.

- [ ] **Step 1: Tests qui échouent**

`test/features/today/activity_reporter_test.dart` (s'inspirer de `daily_session_repository_test.dart` pour amorcer la base drift en mémoire, et de `test/core/network/*` pour un `Dio` scripté ; si le dépôt a déjà un faux adaptateur Dio, le réutiliser) :

```dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/features/today/data/activity_reporter.dart';
import 'package:collega_app/features/today/data/daily_session_repository.dart';

class _Recorder implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool fail = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? body, Future<void>? cancel) async {
    requests.add(options);
    if (fail) throw DioException.connectionError(requestOptions: options, reason: 'hors ligne');
    return ResponseBody.fromString(jsonEncode({'data': options.data}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase db;
  late DailySessionRepository repo;
  late _Recorder http;
  late ActivityReporter reporter;
  const day = 20722; // 2026-09-26 en jours epoch

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = DailySessionRepository(db);
    http = _Recorder();
    reporter = ActivityReporter(
      dio: Dio()..httpClientAdapter = http,
      repo: repo,
      postponedDays: () async => <int>{},
    );
  });
  tearDown(() async {
    reporter.dispose();
    await db.close();
  });

  Future<void> verdict(int d, String card) => repo.recordVerdict(
        day: d, cardId: card, collegeId: 'c1', rang: 'A', drillLevel: 'bien', daily: true);

  test('summarize : fiches distinctes, séance terminée, série', () async {
    await verdict(day - 1, 'a');
    await repo.getOrBuild(day: day - 1, budget: 5);
    await repo.complete(day - 1);
    await verdict(day, 'a');
    await verdict(day, 'a');
    await verdict(day, 'b');
    final s = await reporter.summarize(day);
    expect(s.cardsReviewed, 2);
    expect(s.sessionCompleted, isFalse);
    expect(s.streak, 1);
  });

  test('report : PUT /v1/activity/<date> avec les compteurs', () async {
    await verdict(day, 'a');
    await reporter.report(day);
    expect(http.requests.single.method, 'PUT');
    expect(http.requests.single.path, '/v1/activity/2026-09-26');
    expect(http.requests.single.data, {'cards_reviewed': 1, 'session_completed': false, 'streak': 0});
  });

  test('hors ligne : aucune exception', () async {
    http.fail = true;
    await reporter.report(day);
    expect(http.requests, hasLength(1));
  });

  test('schedule : un seul envoi après l\'anti-rebond', () {
    fakeAsync((clock) {
      reporter.schedule(day);
      reporter.schedule(day);
      clock.elapse(const Duration(seconds: 29));
      expect(http.requests, isEmpty);
      clock.elapse(const Duration(seconds: 2));
      clock.flushMicrotasks();
      expect(http.requests, hasLength(1));
    });
  });

  test('reportRecent : seulement les jours avec de l\'activité, sur 7 jours', () async {
    await verdict(day - 2, 'a');
    await verdict(day - 9, 'b');
    await reporter.reportRecent(today: day);
    expect(http.requests.map((r) => r.path), ['/v1/activity/2026-09-24']);
  });
}
```

Adapter au code réel : signature exacte de `recordVerdict`, de `getOrBuild` (s'il faut des fiches en base pour construire une session, créer la session autrement — lire `daily_session_repository_test.dart`), présence de `fake_async` dans `dev_dependencies` (sinon utiliser un `debounce` court, par ex. `Duration(milliseconds: 50)`, et `await Future.delayed`). Jour 20722 = 2026-09-26 (`(date(2026, 9, 26) - date(1970, 1, 1)).days`).

Run: `cd collega_app && flutter test test/features/today/activity_reporter_test.dart` → FAIL.

- [ ] **Step 2: Implémentation**

`lib/features/today/data/activity_reporter.dart` :

```dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/utils/epoch_day.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/planning/planning_providers.dart';
import 'package:collega_app/features/today/data/daily_session_repository.dart';
import 'package:collega_app/features/today/domain/streak.dart';

/// Résumé d'un jour envoyé au backend pour la console de pilotage de la beta.
/// Uniquement des compteurs, jamais le contenu des fiches.
class ActivitySummary {
  const ActivitySummary({required this.day, required this.cardsReviewed, required this.sessionCompleted, required this.streak});

  final int day;
  final int cardsReviewed;
  final bool sessionCompleted;
  final int streak;

  Map<String, Object> toJson() =>
      {'cards_reviewed': cardsReviewed, 'session_completed': sessionCompleted, 'streak': streak};
}

/// Envoie `PUT /v1/activity/{date}` : remplacement idempotent côté serveur, donc
/// renvoyer un jour déjà envoyé ne compte rien en double. Hors ligne : échec
/// silencieux, le jour repart au prochain lancement (`reportRecent`).
class ActivityReporter {
  ActivityReporter({
    required Dio dio,
    required DailySessionRepository repo,
    required Future<Set<int>> Function() postponedDays,
    this.debounce = const Duration(seconds: 30),
  })  : _dio = dio,
        _repo = repo,
        _postponedDays = postponedDays;

  final Dio _dio;
  final DailySessionRepository _repo;
  final Future<Set<int>> Function() _postponedDays;
  final Duration debounce;
  final _timers = <int, Timer>{};

  Future<ActivitySummary> summarize(int day) async {
    final cards = (await _repo.weekCounts(from: day, to: day))[day] ?? 0;
    final completed = await _repo.completedDays(from: 0, to: day);
    final streak = streakLength(
      today: day,
      completed: completed,
      excused: {...await _repo.quietDays(from: 0, to: day), ...await _postponedDays()},
    );
    return ActivitySummary(day: day, cardsReviewed: cards, sessionCompleted: completed.contains(day), streak: streak);
  }

  Future<void> report(int day) async {
    try {
      final summary = await summarize(day);
      await _dio.put<void>('/v1/activity/${_isoDate(day)}', data: summary.toJson());
    } catch (e) {
      AppLogger.error('activité : envoi impossible', tag: 'Activity', error: e);
    }
  }

  /// Anti-rebond : un seul envoi par jour après [debounce] sans nouvel appel.
  void schedule(int day) {
    _timers.remove(day)?.cancel();
    _timers[day] = Timer(debounce, () {
      _timers.remove(day);
      unawaited(report(day));
    });
  }

  /// Au lancement : renvoie les [days] derniers jours qui ont de l'activité locale.
  Future<void> reportRecent({required int today, int days = 7}) async {
    final counts = await _repo.weekCounts(from: today - days + 1, to: today);
    final completed = await _repo.completedDays(from: today - days + 1, to: today);
    for (final day in {...counts.keys, ...completed}.toList()..sort()) {
      await report(day);
    }
  }

  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }

  static String _isoDate(int day) {
    final d = dateOfEpochDay(day);
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

final activityReporterProvider = Provider<ActivityReporter>((ref) {
  final reporter = ActivityReporter(
    dio: ref.read(apiClientProvider).dio,
    repo: DailySessionRepository(ref.read(databaseProvider)),
    postponedDays: () async => (await ref.read(planningProvider.future)).postponedDays,
  );
  ref.onDispose(reporter.dispose);
  return reporter;
});
```

Vérifier les chemins d'import réels (`databaseProvider`, `apiClientProvider`, `AppLogger`, `planningProvider`) avec ceux de `drill_providers.dart` et `today_providers.dart`, et le nom du paquet (`collega_app`). La base URL de Dio est celle de l'app (`backendBaseUrl`), le chemin commence donc par `/v1/`.

- [ ] **Step 3: Branchements**

Dans `lib/features/drill/drill_providers.dart` :
- après l'appel `unawaited(_daily.recordVerdict(...))` : `ref.read(activityReporterProvider).schedule(arg.dailySessionDay ?? epochDayOf(DateTime.now()));`
- dans `_persistDaily`, après `if (s.isComplete) await _daily.complete(day);` : `if (s.isComplete) ref.read(activityReporterProvider).schedule(day);`

Dans `lib/app.dart`, dans la branche `if (isAuth) { … }` du `ref.listen(authProvider, …)` :

```dart
        unawaited(ref.read(activityReporterProvider).reportRecent(today: epochDayOf(DateTime.now())));
```

(imports : `dart:async` pour `unawaited`, `activity_reporter.dart`, `epoch_day.dart`).

Les tests existants de `drill` qui construisent un `ProviderContainer` sans surcharger `apiClientProvider` risquent d'appeler le réseau : s'ils échouent, surcharger `activityReporterProvider` dans ces tests par un faux (`ActivityReporter` avec un `Dio` à adaptateur enregistreur) plutôt que de rendre le code tolérant.

- [ ] **Step 4: Confidentialité**

Dans `collega_app/assets/legal/privacy.md` **et** `collega_backend/app/static/legal/privacy.md` (les deux doivent rester identiques sur ce point ; comparer avec `diff` avant et après), dans la section qui décrit les données collectées, ajouter :

```markdown
- **Suivi de la révision (pendant la beta)** : chaque jour où l'Application est utilisée, elle transmet trois compteurs — le nombre de fiches révisées, si la séance du jour a été terminée, et la série de jours consécutifs. Aucun contenu de fiche n'est transmis. Ces compteurs servent à suivre la beta et à améliorer le service ; ils sont supprimés avec le compte.
```

Si la page publique `/legal/privacy` est générée à partir de `app/static/legal/privacy.md` par `app/services/legal_pages.py`, vérifier `curl`/test existant (`tests/api/test_legal*.py`) : Run `.venv/bin/python -m pytest tests -q -k legal`.

- [ ] **Step 5: Vérifier**

Run (depuis `collega_app/`) : `flutter test test/features/today`, puis `flutter test test/features/drill`, puis `flutter test test/core`, puis chaque autre dossier touché indirectement (`test/features/auth` si `app.dart` y est testé). `flutter analyze` sans nouvel avertissement.

- [ ] **Step 6: Commit**

```bash
git add collega_app collega_backend/app/static/legal/privacy.md
git commit -m "feat(app): envoi quotidien des compteurs de révision (pilotage beta)"
```

---

### Task 11: Vérification finale, documentation, mémoire

**Files:**
- Modify: `collega_backend/docs/deployment.md` (section console admin : nouvelles routes, réglages `inactivity_days` / `testflight_url`, génération des assets)
- Create: `_bmad-output/planning-artifacts/console-pilotage-livraison.md` (compte rendu pour l'utilisateur)

- [ ] **Step 1: Suite complète backend**

Depuis `collega_backend/` :

```bash
docker compose -f docker-compose.test.yml up -d
.venv/bin/ruff check . && .venv/bin/ruff format --check .
.venv/bin/mypy app/core app/services
.venv/bin/python -m pytest -q
.venv/bin/python -m scripts.gen_admin_assets --check
.venv/bin/alembic upgrade head && .venv/bin/alembic check
```

Tout doit être vert. Un échec préexistant (sans rapport) : le noter dans le compte rendu avec la sortie, ne pas le masquer.

- [ ] **Step 2: App**

Depuis `collega_app/` : `flutter analyze`, puis `flutter test` dossier par dossier (`test/core`, puis chaque `test/features/<dossier>`).

- [ ] **Step 3: Tour complet de la console en local**

API locale sur base de test peuplée (2-3 comptes, un collège par compte avec fiches et avis, un import en échec, des lignes `activity_days` sur 30 jours, des `claude_usage`). Parcourir les 8 écrans en largeur 1280 px et 390 px ; vérifier : pastilles centrées et justes, aucune erreur console, aucun emoji, textes hostiles rendus en texte, retour navigateur, déconnexion. Captures d'écran dans `_bmad-output/planning-artifacts/console-pilotage-captures/` si un navigateur sans tête est disponible.

- [ ] **Step 4: Documentation**

Dans `docs/deployment.md` (section « Console admin ») : la console est découpée en modules (`app/static/admin/js/views/*`), les assets partagés se régénèrent par `python -m scripts.gen_admin_assets` (test de fraîcheur en CI), les réglages `inactivity_days` et `testflight_url` se changent dans l'écran Réglages, l'alerte d'import passe par `collega-health.sh`.

- [ ] **Step 5: Compte rendu pour l'utilisateur**

`_bmad-output/planning-artifacts/console-pilotage-livraison.md` : ce qui est fait (par tâche, avec commits), les écarts à la spec et pourquoi, les vérifications faites (commandes et résultats), ce qui reste à faire **avec** l'utilisateur :
1. Relire la branche et merger dans `main`.
2. Déployer par `collega_backend/scripts/deploy.sh <sha>` (migration 022, dump avant).
3. Copier `ops/nas/collega-health.sh` sur le NAS (`/boot/config/plugins/user.scripts/scripts/collega-health/script`) et faire l'essai d'alerte avec un import volontairement en échec.
4. Renseigner le lien TestFlight dans Réglages.
5. Construire et envoyer un build TestFlight (nouveau domaine + envoi d'activité).

- [ ] **Step 6: Mémoire et contrôle**

- `kage_learn` : (a) console = modules ES sans build, assets générés depuis l'app (commande et test) ; (b) activité des testeuses = `activity_days` alimentée par l'app, idempotente, 7 derniers jours renvoyés au lancement ; (c) alerte d'import = `scripts.import_alerts` + point de reprise `import_alerts_since`.
- `kage_refresh`, puis `kage_pr_check` ; traiter les rapprochements de mémoire signalés (packets liés à `auth.py`, `users.py`, `collega-health.sh`, `index.html`).

- [ ] **Step 7: Commit final**

```bash
git add -A collega_backend/docs _bmad-output/planning-artifacts .agent_memory/packets
git commit -m "docs(console): livraison de la console de pilotage"
```

Ne pas pousser, ne pas merger : l'utilisateur relit la branche.

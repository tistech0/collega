# Chantier 5 — Refactorisation et nettoyage admin/testeur : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** supprimer le testeur web, mettre les réglages anti-spam en base, un seul pool ARQ, un service d'import partagé, des modules d'API découpés et un format d'erreur unique — sans changement de comportement visible pour l'app.

**Architecture:** refactorisation incrémentale ; chaque tâche garde la suite verte. Les tests existants ne changent pas d'assertions (seulement imports, cibles de monkeypatch et injection du faux pool ARQ), sauf ceux du testeur (supprimés) et de `/v1/admin/config` (comportement changé par R4 : réécrits en Postgres).

**Tech Stack:** FastAPI, SQLAlchemy async, Alembic, ARQ, pytest (SQLite + Postgres de test), ruff/mypy (CI du chantier 3).

**Spec:** `_bmad-output/planning-artifacts/chantier-5-refacto-spec.md`

## Global Constraints

- Branche `feat/refonte-back-infra` ; commits fréquents ; `ruff check .`, `ruff format --check .`, `mypy app/core app/services` à 0 et `pytest -q` vert (avec `docker compose -f docker-compose.test.yml up -d`) à la fin de **chaque** tâche.
- Format d'erreur : `{"detail": {"code": "...", "message": "...", ...extra}}` — identique à l'existant (l'app lit `detail.code`).
- Migration du chantier : **019** (`019_app_settings_drop_tester_feedbacks.py`), `down_revision = "018"` (vérifier l'identifiant réel de la 018).
- Mêmes chemins et méthodes d'API, moins `/v1/tester/*` ; référence : `_bmad-output/implementation-artifacts/chantier-5/openapi-routes-before.txt`.
- Aucun secret ni contenu de fiche dans les logs.
- Commandes : depuis `collega_backend/`, `.venv/bin/python -m pytest -q`, `.venv/bin/ruff …`, `.venv/bin/mypy …`.

---

### Task 1: Suppression du testeur web (R1, R2, R3, § 5)

**Files:**
- Delete: `app/api/v1/tester.py`, `app/schemas/tester.py`, `app/models/tester_feedback.py`, `app/static/index.html`, `tests/api/test_tester_*.py`
- Modify: `app/models/__init__.py`, `app/deps.py` (retirer `get_tester_user`, `_http_basic_tester`, entrée `__all__`), `app/core/config.py` (retirer `tester_username`/`tester_password` et leurs contrôles dans `_validate_production_secrets` ; vérifier `extra="ignore"`), `app/main.py` (routeur et montage `/tester` retirés ; `logo.svg` est déjà dans `static/admin/`), `app/api/v1/admin.py` (stats et feedback), `app/schemas/admin.py`, `app/static/admin/index.html`, `tests/conftest.py` (variables `TESTER_*` retirées), `tests/api/test_admin_college_feedback.py`, `tests/api/test_admin_college_stats.py`, `.env.example`, `.env.nas.example`, `docs/deployment.md`
- Create: `scripts/export_tester_feedbacks.py`, `alembic/versions/019_app_settings_drop_tester_feedbacks.py` (partie DROP ; la table `app_settings` est ajoutée à la même migration en tâche 2)

**Feedback admin depuis `flash_cards.user_feedback`** (valeurs `positive` / `negative`) :
- `GET /v1/admin/colleges/{id}/feedback` : une ligne par fiche du collège dont `user_feedback IS NOT NULL`, triée par numéro d'item. `AdminFeedbackData` devient : `flash_card_id: str`, `item_number: int`, `user_email: str` (propriétaire du collège), `feedback: Literal["positive","negative"]`, `is_pertinent: bool` (= `feedback == "positive"`), `recto`, `verso`, `card_type`, `rang`. `feedback_id`, `tester_id`, `created_at` disparaissent.
- `GET /v1/admin/colleges/{id}/stats` : `pertinence_stats` calculé depuis `FlashCard.user_feedback` groupé par `FlashCard.rang` (pertinent = positive, not_pertinent = negative) ; `None` s'il n'y a aucun avis.
- `admin/index.html` : colonne « Testeur » → « Utilisatrice » (`f.user_email`), plus aucune mention du testeur.
- Les tests `test_admin_college_feedback.py` / `test_admin_college_stats.py` qui construisaient des `TesterFeedback` sont adaptés pour poser `user_feedback` sur des fiches (R3 change la source ; mêmes cas couverts : collège inconnu 404, vide, positif/négatif, tri, ventilation par rang).

**Export** `scripts/export_tester_feedbacks.py` : lecture SQL brute (`SELECT tf.*, fc.recto, fc.verso, fc.rang FROM tester_feedbacks tf LEFT JOIN flash_cards fc …`) via `DATABASE_URL`, écrit `tester_feedbacks_<AAAAMMJJ>.csv` dans le dossier courant (ou `--out`), affiche le nombre de lignes ; si la table n'existe plus : message et code 0. Exécuté sur le NAS avant la migration : `docker exec collega-api-1 python scripts/export_tester_feedbacks.py --out /tmp/collega_pdfs` puis rapatriement.

**Migration 019 (partie 1)** : `op.drop_table("tester_feedbacks")` ; `downgrade` recrée la table telle qu'en migration 005 (colonnes, FK, index).

- [ ] Test : `GET /tester/` → 404 et `/v1/tester/colleges` → 404 (nouveau test dans `tests/core/test_app_setup.py`).
- [ ] Tests feedback/stats adaptés → échouent ; implémentation → passent.
- [ ] Suite verte, ruff/mypy ; commit `refactor(backend): suppression du testeur web, avis lus dans flash_cards.user_feedback`.

### Task 2: Réglages anti-spam en base (R4, § 6)

**Files:**
- Create: `app/models/app_setting.py` (`AppSetting` : `key` Text PK, `value` JSONB — `JSON().with_variant(JSONB, "postgresql")` pour SQLite —, `updated_at` timestamptz `server_default=now()`, `onupdate`), `app/services/app_settings.py`, `tests/services/test_app_settings.py`, `tests/api/test_admin_config_pg.py`
- Modify: migration 019 (création de `app_settings`), `app/models/__init__.py`, `app/api/v1/admin.py` (config), `app/api/v1/colleges.py` (limites, quota, `reload-limits`), `app/api/v1/auth.py:121` (`/me` : `monthly_reloads_max`), `app/api/v1/admin.py` (users : `monthly_reloads_max`, `reload_count_max` affichés), `tests/api/test_admin_config.py` (supprimé : remplacé par le test pg)

```python
# app/services/app_settings.py
RELOAD_COUNT_MAX = "reload_count_max"
MONTHLY_RELOADS_MAX = "monthly_reloads_max"
CACHE_TTL_S = 30.0
_cache: dict[str, tuple[float, Any]] = {}   # clé → (expiration monotonic, valeur)

async def get_setting(db: AsyncSession, key: str, default: Any) -> Any: ...
async def set_setting(db: AsyncSession, key: str, value: Any) -> None:  # upsert, flush, invalide le cache local ; ne commit pas
async def anti_spam_limits(db: AsyncSession) -> tuple[int, int]:  # (reload_count_max, monthly_reloads_max), défauts = settings.*
def clear_cache() -> None:  # tests
```
- Upsert : `insert(AppSetting).values(...).on_conflict_do_update(...)` en Postgres ; en SQLite, `db.merge`. Plus simple et portable : `row = await db.get(AppSetting, key)` puis création ou mise à jour.
- `PATCH /v1/admin/config` : valide entiers ≥ 0 (`ConfigUpdateRequest` avec `Field(ge=0)`), écrit, commit, renvoie les valeurs relues via `anti_spam_limits`.
- Tous les lecteurs de `settings.reload_count_max` / `settings.monthly_reloads_max` passent par `anti_spam_limits(db)` (une lecture par requête ; les fonctions `_college_reload_limit`, `_monthly_reload_limit`, `_apply_reimport_quota`, `_assert_import_allowed` reçoivent les limites en paramètre).
- Fixture autouse dans `tests/conftest.py` : `app_settings.clear_cache()` avant chaque test.
- Tests pg (`tests/api/test_admin_config_pg.py`, marqueur `pg`) : GET sans ligne → défauts `.env` ; PATCH puis GET → nouvelles valeurs ; valeur négative → 422 ; autre processus simulé : `set_setting` directement en base puis `clear_cache()` → `get_setting` voit la valeur ; le cache sert l'ancienne valeur tant qu'il n'a pas expiré (monkeypatch de `time.monotonic`) ; le quota de réimport applique la valeur en base (réimport refusé à la limite modifiée).
- [ ] TDD, suite verte ; commit `feat(backend): réglages anti-spam en base (app_settings, cache 30 s)`.

### Task 3: Pool ARQ unique (§ 3)

**Files:** `app/main.py` (lifespan : `app.state.arq = await create_pool(redis_settings)` ; fermeture `await app.state.arq.aclose()` — vérifier le nom exact de la méthode de fermeture dans arq 0.28 : `close()` est déprécié au profit de `aclose()` côté redis-py), `app/deps.py` (`async def get_arq(request: Request) -> ArqRedis: return request.app.state.arq`), `app/api/v1/colleges.py` (`_create_job_and_enqueue`, `get_upload_store`), `app/api/v1/admin.py` (`process_college`, `stop_job`), `app/services/jobs/arq_control.py` (`abort_arq_job(pool, arq_job_id, timeout=5.0)` : reçoit le pool), tests.
- Démarrage : si Redis est injoignable au démarrage, l'API démarre quand même (`app.state.arq = None`, warning) et `get_arq` lève `AppError(503, "QUEUE_UNAVAILABLE")` ; une tentative de reconnexion paresseuse est faite dans `get_arq` si `None`.
- Tests : `tests/conftest.py` fournit un `fake_arq` (MagicMock avec `enqueue_job = AsyncMock(return_value=MagicMock(job_id="arq-test"))`) injecté par `app.dependency_overrides[get_arq]` dans les fixtures `client` et `pg_client` ; les tests qui patchaient `arq.create_pool` configurent ce faux pool (même assertions). Les tests de lifespan (`test_lifespan_apns.py`) patchent `create_pool` dans `app.main`.
- [ ] Suite verte ; `grep -rn "create_pool" app` ne renvoie que `app/main.py` ; commit `refactor(backend): un seul pool ARQ (lifespan, dépendance get_arq)`.

### Task 4: Service d'import partagé (§ 2)

**Files:** Create `app/services/imports.py`, `tests/services/test_imports.py` ; Modify `app/api/v1/colleges.py`, `app/api/v1/admin.py`.

Fonctions (logique aujourd'hui dans `colleges.py` et `admin.process_college`) :
```python
PDF_MAGIC = b"%PDF-"
MAX_PDF_SIZE = 500 * 1024 * 1024
ACTIVE_JOB_STATUSES = ("pending", "processing", "ocr_complete")

def validate_ref_id(ref_id: int) -> None                      # 422 INVALID_REF_ID
async def get_or_create_college(db, user, ref_id) -> College
async def assert_no_active_job(db, college) -> None            # 409 JOB_IN_PROGRESS
async def apply_reimport_quota(db, user, college, limits) -> None
async def assert_import_allowed(db, user, ref_id, limits) -> College | None
async def save_upload(upload: UploadFile, dest: Path, *, max_size: int | None) -> None   # magic + taille, supprime le fichier sur erreur
async def create_job_and_enqueue(db, arq, *, college, user_id, job_id, pdf_path) -> GenerationJob  # 409/503, supprime le PDF sur erreur
async def start_import_from_file(db, arq, user, ref_id, pdf_path, limits) -> ImportCollegeResponseData
```
- Messages d'erreur : ceux de la route utilisatrice (français). L'import admin garde ses propres gardes métier (collège par id, pas de quota) mais utilise `assert_no_active_job`, `save_upload(max_size=None)`, `create_job_and_enqueue`.
- Les routes ne gardent que la lecture de la requête et la réponse.
- Tests unitaires ciblés (SQLite/mocks) sur `save_upload` (magic invalide, taille dépassée → fichier supprimé) et `create_job_and_enqueue` (échec d'enqueue → job supprimé, PDF supprimé, 503) ; les tests d'API existants restent inchangés.
- [ ] Suite verte ; commit `refactor(backend): service d'import partagé (utilisatrice + admin)`.

### Task 5: Découpage en paquets (§ 2)

- `app/api/v1/colleges/` : `__init__.py` (`router = APIRouter(tags=["colleges"])` + `include_router` des sous-routeurs, dans l'ordre d'origine des routes), `catalog.py` (liste, `reload-limits`), `imports.py` (import simple, `init`, statut d'upload, `parts`, `complete`, `get_upload_store`), `status.py` (statut, SSE, `_poll_state`), `cards.py` (items, fiches).
- `app/api/v1/admin/` : `__init__.py`, `colleges.py` (création, process, statut, stats, suppression, fiches, feedback), `jobs.py` (queue, détail, stop), `users.py`, `usage.py` (overview, usage), `config.py`.
- Ordre des routes : attention aux conflits de chemins (`/colleges/import/{upload_id}` doit rester déclaré avant `/colleges/{college_id}/…` s'ils se recoupent — vérifier avec la liste OpenAPI de référence).
- Tests : cibles de monkeypatch mises à jour (`app.api.v1.admin.abort_arq_job` → module réel, `colleges_module.get_upload_store` → `app.api.v1.colleges.imports.get_upload_store`, `colleges_module.settings`/`Path` → module qui les utilise, `tests/api_pg.py` : `async_session_factory` patché dans chaque module qui l'importe). Aucune assertion modifiée.
- [ ] Liste OpenAPI identique à la référence (moins `/v1/tester/*`) ; suite verte ; commit `refactor(backend): api/v1/colleges et api/v1/admin en paquets par domaine`.

### Task 6: Erreurs uniformes (§ 4)

**Files:** Create `app/core/errors.py`, `tests/core/test_errors.py` ; Modify `app/main.py` (gestionnaires), toutes les routes et `deps.py`, `services/ocr/pdf_check.py`.

```python
class AppError(Exception):
    def __init__(self, status_code: int, code: str, message: str, extra: dict[str, Any] | None = None,
                 headers: dict[str, str] | None = None) -> None
def not_found(code: str, message: str) -> AppError        # 404
def conflict(code: str, message: str, **extra) -> AppError  # 409
def unprocessable(code: str, message: str, **extra) -> AppError  # 422
def unauthorized(code: str, message: str) -> AppError     # 401
def forbidden(code: str, message: str) -> AppError        # 403
def install_error_handlers(app: FastAPI) -> None
```
- Réponse : `{"detail": {"code": code, "message": message, **extra}}` (extra à plat, comme aujourd'hui `reload_count`, `missing`…).
- 422 `RequestValidationError` → `{"detail": {"code": "VALIDATION_ERROR", "message": "Requête invalide", "errors": [{"loc": [...], "msg": "...", "type": "..."}]}}`.
- 429 `RateLimitExceeded` → `{"detail": {"code": "RATE_LIMITED", "message": "Trop de requêtes, réessayez plus tard"}}` + `Retry-After` (secondes, depuis `exc.limit.limit.get_expiry()` ; 60 à défaut).
- 500 `Exception` → `{"detail": {"code": "INTERNAL_ERROR", "message": "Erreur interne"}}`, `logger.exception`.
- `HTTPException` restantes (Starlette 404/405 de routage) inchangées.
- Remplacer les `HTTPException(status_code, detail={"code"…})` par `AppError`/fabriques (Basic Auth admin : garder l'en-tête `WWW-Authenticate` via `headers`).
- Tests : un test par gestionnaire (AppError avec extra, 422, 429 avec `Retry-After`, 500 sans fuite du message d'exception, via une app FastAPI de test) ; suite existante inchangée et verte.
- App : vérifier que `collega_app/lib/core/network/` lit `detail.code` pour 422/429 et qu'aucun écran n'affiche un `detail` brut ; corriger si besoin (test Flutter du dossier concerné).
- [ ] `grep -rn "HTTPException(" app` : seules les exceptions de routage/sécurité justifiées restent ; commit `refactor(backend): AppError et gestionnaires d'erreurs uniformes (422, 429, 500)`.

### Task 7: Divers (§ 7) et documentation

- Imports différés remontés en tête de module quand il n'y a pas de cycle (`claude_client` → `app.schemas.college`, imports locaux restants dans les routes) ; vérifier par `python -c "import app.main"`.
- Code mort : `pipx run vulture app --min-confidence 80` ; chaque résultat confirmé par `grep` puis supprimé.
- `CLAUDE.md` (section « Conventions du dépôt pour les agents ») : structure `api/v1/<domaine>/`, `AppError` et fabriques, pool ARQ du lifespan (`get_arq`), service d'import partagé, réglages en base (`app_settings`).
- `privacy.md` / `docs/` : retirer toute mention du testeur web s'il y en a.
- [ ] Suite complète verte ; commit.

### Task 8: Vérification, revue, déploiement

- [ ] Liste OpenAPI après = avant moins `/v1/tester/*` (diff commité dans `_bmad-output/implementation-artifacts/chantier-5/`).
- [ ] Revue de code indépendante ; corrections.
- [ ] Déploiement : export CSV sur le NAS **avant** (`docker exec collega-api-1 python scripts/export_tester_feedbacks.py --out /tmp/collega_pdfs`), rapatrié dans `_bmad-output/implementation-artifacts/exports/` (git-ignoré : contient du texte de fiches) ; `deploy.sh` (migration 019).
- [ ] Contrôles prod : `/tester/` → 404 ; `/v1/admin/config` PATCH puis redémarrage API → valeur conservée (puis remise à la valeur d'origine) ; console admin (fiches, feedback, usage) ; `/health`.

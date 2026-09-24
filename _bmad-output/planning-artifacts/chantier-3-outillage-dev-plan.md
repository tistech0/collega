# Chantier 3 — Outillage de développement : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** CI GitHub Actions, déploiement par `deploy.sh` à image étiquetée par commit, ruff/mypy à 0 erreur, image multi-stage non root, Redis de prod protégé par mot de passe, docs et ménage.

**Architecture:** outillage autour du code existant, sans changement de comportement applicatif. Le `.env` du NAS n'est jamais réécrit : seule `REDIS_PASSWORD` est ajoutée, et `REDIS_URL` est surchargée dans le compose par `environment:` (interpolation de `REDIS_PASSWORD`).

**Tech Stack:** Python 3.11, Poetry (lock), ruff, mypy, GitHub Actions, Docker (buildx amd64, OrbStack), Flutter 3.27.1.

**Spec:** `_bmad-output/planning-artifacts/chantier-3-outillage-dev-spec.md`

## Global Constraints

- Python 3.11 partout (`python = ">=3.11,<3.12"`, `.python-version` = 3.11).
- ruff : `select = ["E","F","W","I","B","UP","SIM","C90"]`, `ignore = ["B008","E501"]`, `line-length = 120`, `target-version = "py311"`.
- mypy bloquant sur `app/core` et `app/services` (`disallow_untyped_defs = true`, `strict = false`), 0 erreur.
- Image `tistech0/collega-backend:<sha>` (plus de `latest`), taille < 400 Mo, uid 1000 `collega`.
- Jamais écraser le `.env` du NAS ; jamais afficher un secret de prod.
- Tests Flutter lancés par dossier.

## Constats préalables (2026-09-24)

- `gh` local est connecté au compte `CrazyGrower`, qui ne voit pas le dépôt privé `tistech0/collega` (push SSH en `tistech0`). `deploy.sh` ne peut donc pas lire la CI depuis cette machine tant que l'utilisateur n'a pas fait `gh auth login` en `tistech0` : le script refuse alors (message explicite) sauf `--force`. La CI est validée localement avec `act` (même image ubuntu) pendant la session.
- `aiosqlite` est utilisé par les tests mais absent du `pyproject` : ajouté au groupe dev.
- Bornes des dépendances : versions de l'image de prod `0e76425` (anthropic 1.8.0, fastapi 0.141.1…).
- 309 erreurs ruff (dont 131 F811 dues aux imports de fixtures `tests.pg`/`tests.api_pg`), 38 erreurs mypy.

---

### Task 1: Environnement Python 3.11 et dépendances verrouillées

**Files:** Create `collega_backend/.python-version`, `collega_backend/poetry.lock` ; Modify `collega_backend/pyproject.toml`.

- [x] venv recréé en 3.11 (`python3.11 -m venv .venv`, `poetry install --no-root`).
- [x] `pyproject` : `python = ">=3.11,<3.12"`, `^` sur les dépendances (versions de prod), `redis` explicite, dev : `pytest-cov`, `aiosqlite`, `ruff`, `mypy` ; description « Collega backend ».
- [ ] `.python-version` = `3.11`.
- [ ] Suite complète verte : `.venv/bin/python -m pytest -q` → 552 passed.
- [ ] Commit `chore(backend): Python 3.11, dépendances bornées et poetry.lock`.

### Task 2: ruff à 0 erreur

**Files:** `tests/conftest.py` (`pytest_plugins = ["tests.pg", "tests.api_pg"]`), tous les fichiers signalés.

- [ ] `ruff check --fix` + `ruff format` (commit séparé « style: ruff format » pour garder les diffs lisibles).
- [ ] F811 : fixtures `pg_engine`, `pg_factory`, `pg_session`, `pg_client` déclarées une fois via `pytest_plugins` dans `tests/conftest.py` ; les imports `from tests.pg import pg_engine…  # noqa: F401` retirés (les noms non-fixtures comme `alembic_config`, `login_as`, `ADMIN_AUTH` restent importés).
- [ ] B904 : `raise … from exc` (ou `from None` quand l'exception d'origine n'apporte rien au client).
- [ ] C901 : `[tool.ruff.lint.mccabe] max-complexity = 15` (fonctions de route et de pipeline longues mais linéaires ; le chantier 5 découpe les modules) ; les fonctions au-delà de 15 sont découpées en fonctions privées.
- [ ] E402 / B905 / SIM restants corrigés à la main.
- [ ] `ruff check .` → 0, `ruff format --check .` → 0 ; tests verts ; commit.

### Task 3: mypy à 0 erreur sur `app/core` et `app/services`

- [ ] `[tool.mypy]` : `python_version = "3.11"`, `strict = false`, `disallow_untyped_defs = true`, `ignore_missing_imports = true`, plugin pydantic.
- [ ] Annotations manquantes ajoutées ; aucune `# type: ignore` sans code d'erreur précis.
- [ ] `mypy app/core app/services` → `Success` ; tests verts ; commit.

### Task 4: pre-commit optionnel

- [ ] `.pre-commit-config.yaml` à la racine : hooks `ruff` (args `--fix`) et `ruff-format` limités à `collega_backend/`, version alignée sur le lock. Documenté dans `collega_backend/README.md` (« optionnel : `pipx install pre-commit && pre-commit install` »).

### Task 5: Image Docker multi-stage non root

**Files:** `collega_backend/Dockerfile`, `.dockerignore`.

- Étape `builder` (`python:3.11-slim`) : `pip install poetry poetry-plugin-export`, `poetry export --only main -f requirements.txt`, `python -m venv /opt/venv && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt`.
- Étape finale `python:3.11-slim` : tesseract-ocr, tesseract-ocr-fra, poppler-utils ; `COPY --from=builder /opt/venv /opt/venv` ; `ENV PATH=/opt/venv/bin:$PATH PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1` ; `useradd -u 1000 collega` ; `mkdir -p /tmp/collega_pdfs && chown collega` ; `COPY --chown=collega app alembic alembic.ini scripts ./` ; `USER collega`.
- [ ] Build amd64 local, contrôles : `docker run … python -c "import app.main"`, `tesseract --version`, `id -u` = 1000, taille < 400 Mo (sinon retirer les caches/`__pycache__`, `tesseract-ocr-eng` si non utilisé).
- [ ] Commit.

### Task 6: Compose (prod, dev, test) et Redis protégé

- `docker-compose.prod.yml` : `image: tistech0/collega-backend:${IMAGE_TAG:?IMAGE_TAG manquant}` (migrate, api, worker) ; `environment: REDIS_URL: redis://:${REDIS_PASSWORD}@redis:6379/0` sur migrate/api/worker (surcharge l'`env_file`) ; redis : `command: redis-server --requirepass ${REDIS_PASSWORD:?} --appendonly yes`, `environment: REDISCLI_AUTH: ${REDIS_PASSWORD}` (le healthcheck `redis-cli ping` et les `docker exec … redis-cli` du runbook s'authentifient sans exposer le secret en argument).
- `docker-compose.yml` (dev) : service `caddy` et volumes caddy retirés ; ports DB/Redis `127.0.0.1:5432:5432`, `127.0.0.1:6379:6379`.
- `docker-compose.test.yml` : service `redis-test` (`redis:7-alpine`, `127.0.0.1:56379:6379`) pour le chantier 2.
- [ ] `docker compose -f docker-compose.prod.yml config -q` avec un `.env` factice ; commit.

### Task 7: `scripts/deploy.sh`

Comportement (spec § 5) — `./scripts/deploy.sh [--force] [<sha>]` :
1. `git status --porcelain` vide, sinon refus ; sha résolu (`git rev-parse --short=7`) ; `git branch -r --contains <sha>` non vide, sinon refus (« pousser d'abord »).
2. CI : `gh run list --repo tistech0/collega --commit <sha-long> --workflow ci.yml --json conclusion,status -L 1` ; refus si pas `success` ou si `gh` ne voit pas le dépôt, sauf `--force` (avertissement).
3. Build : `docker build --platform linux/amd64 -t tistech0/collega-backend:<sha> collega_backend` depuis un `git worktree` temporaire du sha (le build ne dépend jamais de l'arbre de travail courant) ; contrôle `python -c "import app.main"` ; `docker push`.
4. NAS (`ssh nas`, dossier `/mnt/user/appdata/compose-stacks/collega`) : attente « aucun import en cours » (clés `arq:in-progress:*`, `zcard arq:queue`, jobs `status in ('pending','processing')` en base) toutes les 30 s, 30 min max puis abandon ; dump `pg_dumpall | gzip` vers `/mnt/user/appdata/collega/backups/collega_pre_<sha>_<date>.sql.gz` (taille > 0 vérifiée) ; `IMAGE_TAG` du `.env` mis à jour **par remplacement de cette seule ligne** (`sed -i` si présente, ajout sinon ; sauvegarde `.env.bak-<date>` avant) ; le compose versionné est copié sur le NAS (sauvegarde de l'ancien) ; `docker compose config -q` ; `docker compose pull -q migrate api worker && docker compose up -d`.
5. Attente `healthy` api et worker (3 min max) ; affiche `docker logs collega-migrate-1 | tail`, `/health` ; échec → message avec la commande de retour arrière (`deploy.sh <sha précédent>`, lu dans le `.env` avant changement) et le chemin du dump.
- [ ] `bash -n`, `shellcheck` si disponible ; essai à blanc des refus (arbre sale, sha non poussé) ; commit.

### Task 8: CI GitHub Actions

**Files:** `.github/workflows/ci.yml`, `collega_app/dart_test.yaml`, `collega_app/test/support/cg_golden.dart`, `README.md` (badge).

- Job `backend` : ubuntu-latest, `actions/setup-python` 3.11, `pipx install poetry`, cache `~/.cache/pypoetry` par hash du lock ; services postgres (55432) et redis (56379) avec healthchecks ; `poetry install --no-root` ; `ruff check .`, `ruff format --check .`, `mypy app/core app/services`, `pytest -q --cov=app` (`TEST_PG_URL` vers le service), `alembic upgrade head` puis `alembic check` sur une base dédiée, `pip-audit` (continue-on-error).
- Job `app` : `subosito/flutter-action` 3.27.1 avec cache ; `flutter pub get`, `flutter analyze`, `flutter test` par dossier (une étape par `test/core`, `test/features/<dossier>`, et fichiers racine).
- Goldens : tag `golden` sur les tests de `cgGoldenMatrix` et les autres `matchesGoldenFile` ; `dart_test.yaml` déclare le tag. Premier run (act) : si écarts Linux/macOS → la CI passe `--exclude-tags golden`, documenté dans `collega_backend/docs/testing.md` (goldens locaux sur macOS).
- [ ] `act push -j backend` et `act push -j app` verts ; commit ; push.

### Task 9: Documentation et ménage

- Supprimés : `install.md`, `collega_backend/Caddyfile`, `Caddyfile.prod`, `seed_dev.py`, `app/services/billing/`, `test.db` s'il réapparaît (ignoré).
- `README.md` racine, `collega_backend/README.md` (installation 3.11/poetry, tests, conventions, `deploy.sh`, restauration), `CLAUDE.md` (section « Conventions du dépôt pour les agents »), `docs/deployment.md` (validateur `SECRET_KEY` réel, port 430 retiré, `deploy.sh`, IMAGE_TAG, Redis protégé, uid 1000), `docs/testing.md` (Redis de test, CI, goldens).
- [ ] Commit.

### Task 10: Déploiement réel et retour arrière

- [ ] Sur le NAS : `REDIS_PASSWORD` ajouté au `.env` (`openssl rand -hex 32`, jamais affiché) ; `chown -R 1000:1000 /mnt/user/appdata/collega/pdfs`.
- [ ] `deploy.sh` (avec `--force` tant que `gh` n'a pas accès, CI validée par act) : dump présent, image `<sha>`, api/worker healthy, `/health` ok, `redis-cli ping` sans mot de passe refusé (`NOAUTH`), worker healthy.
- [ ] Retour arrière testé : `deploy.sh <sha précédent>` puis `deploy.sh <sha courant>` (aucune migration entre les deux).
- [ ] `collega-health` : aucun message d'alerte.

### Task 11: Revue indépendante, mémoire

- [ ] Agent de revue sur le diff du chantier ; corrections.
- [ ] Kage : runbook de déploiement remplacé (supersede), learnings (gh/CrazyGrower, REDISCLI_AUTH, IMAGE_TAG) ; `kage_refresh`, `kage_propose_from_diff`, `kage_pr_check` ; audit « chantier 3 fait » ; mémoire auto.

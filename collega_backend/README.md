# Collega backend

API FastAPI + worker ARQ (OCR des PDF, génération des fiches avec Claude), PostgreSQL 16, Redis 7.

## Installation

- Python **3.11** (`.python-version`) et [poetry](https://python-poetry.org/) : `python3.11 -m venv .venv && poetry install --no-root`.
- Les dépendances sont verrouillées dans `poetry.lock` ; l'image Docker s'installe depuis ce lock.
- `.env` local : copier `.env.example`.
- Hook pre-commit **optionnel** (ruff + ruff format) : `pipx install pre-commit && pre-commit install` à la racine du dépôt.

## Tests

- `docker compose -f docker-compose.test.yml up -d` (Postgres `127.0.0.1:55432`, Redis `127.0.0.1:56379`), puis `.venv/bin/python -m pytest -q`.
- Détails (tests `pg`, marqueurs) : [`docs/testing.md`](docs/testing.md).
- Qualité : `ruff check .`, `ruff format --check .`, `mypy app/core app/services` (bloquant sur ces deux dossiers). La CI lance le tout, plus `alembic check` et `pip-audit` (informatif).

## Conventions

- Couches : `app/api/v1` (HTTP seulement), `app/services` (logique métier), `app/workers` (tâches ARQ), `app/models` / `app/schemas`.
- Réponses : `{"data": …}` ; erreurs : `{"detail": {"code": "CODE", "message": "…"}}` (l'app lit `detail.code`).
- Migrations Alembic numérotées (`alembic/versions/NNN_…`), jamais d'autogénération sans relecture ; `alembic check` doit rester vide.
- Logs : jamais de secret, de terme de recherche ni de contenu de fiche.

## Déploiement

`./scripts/deploy.sh [--force] [<sha>]` depuis le Mac : image `tistech0/collega-backend:<sha>`, dump de la base avant migration, `IMAGE_TAG` dans le `.env` du NAS, attente `healthy`. Retour arrière = `deploy.sh <sha précédent>`. Détails : [`docs/deployment.md`](docs/deployment.md) ; restauration : [`docs/restore.md`](docs/restore.md).

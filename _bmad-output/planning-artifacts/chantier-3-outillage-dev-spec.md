# Chantier 3 — Outillage de développement : spécification

Date : 2026-09-24 · Statut : validée avec l'utilisateur · Branche : `feat/refonte-back-infra` (commune aux chantiers 2 à 5)
Contexte : `audit-back-infra-2026-09-23.md` (« Développement », « Exploitation »). Déjà fait au chantier 1 : tests indépendants du Redis local (limiteur en mémoire), Postgres de test (`docker-compose.test.yml`), `alembic/__init__.py` retiré, `test.db` retiré. Déjà fait au chantier 0 : compose de prod versionné = NAS, healthchecks, logs, supervision.

## 1. Décisions

| # | Décision |
|---|---|
| O1 | **CI GitHub Actions** pour les vérifications ; **déploiement par script local** `deploy.sh` (aucune clé du NAS chez GitHub). |
| O2 | mypy progressif : bloquant sur `app/core` et `app/services`, informatif ailleurs. |
| O3 | Image de prod **étiquetée par commit** (plus `latest` dans le compose) ; retour arrière = `deploy.sh <sha précédent>`. |
| O4 | Pas de protection de branche GitHub (développeur seul). |

## 2. Dépendances et environnement

- `poetry.lock` généré et commité ; le Dockerfile installe depuis le lock (`poetry install --only main --no-root`), l'image est reproductible.
- Python **3.11** partout : `.python-version` (3.11), venv local recréé en 3.11 (`python3.11 -m venv .venv` puis `poetry install`), `pyproject` `python = ">=3.11,<3.12"`.
- `pytest-cov`, `ruff`, `mypy` dans le groupe dev ; `pip-audit` lancé en CI (informatif, ne bloque pas).
- Dépendances majeures bornées (ex. `anthropic`, `fastapi`, `sqlalchemy`) : `^` au lieu de `>=`.

## 3. Qualité du code

- ruff : `select = ["E", "F", "W", "I", "B", "UP", "SIM", "C90"]`, `ignore = ["B008", "E501"]` (B008 idiomatique FastAPI ; longueur gérée par `ruff format`), `line-length = 120`, `target-version = "py311"`. Corrections automatiques appliquées (`ruff check --fix`, `ruff format`) puis corrections manuelles jusqu'à 0 erreur (dont `raise … from` B904, imports inutilisés F401, redéfinitions F811 dans les tests).
- mypy : `app/core` et `app/services` en `strict = false` + `disallow_untyped_defs = true` ; 0 erreur exigé sur ces deux dossiers.
- Hook pre-commit **local optionnel** (`.pre-commit-config.yaml` : ruff + ruff-format) documenté, non imposé.

## 4. CI (`.github/workflows/ci.yml`)

Déclenchée sur push et pull request, 2 jobs parallèles :
- **backend** (ubuntu, Python 3.11, cache poetry) : services `postgres:16-alpine` (port 55432) et `redis:7-alpine` (port 56379, requis par le chantier 2) ; `ruff check`, `ruff format --check`, `mypy app/core app/services`, `pytest -q --cov=app` (tests pg compris, `TEST_PG_URL` pointant le service), `alembic check` sur une base migrée, `pip-audit` (continue-on-error).
- **app** (ubuntu, Flutter 3.27.1 figé, cache pub) : `flutter analyze` puis `flutter test` **par dossiers** (convention du projet : `test/core`, `test/features/<chaque dossier>` en étapes séparées). Goldens : exécutés (police embarquée) — si des écarts de rendu Linux/macOS apparaissent, les goldens sont exclus de la CI par tag `golden` et restent locaux (décision à prendre dans la session d'implémentation selon le résultat du premier run, documentée dans `docs/testing.md`).
- Badge CI dans le README.

## 5. Déploiement (`collega_backend/scripts/deploy.sh`)

`./scripts/deploy.sh [<sha>]` (défaut : HEAD) :
1. refuse si `git status` n'est pas propre ou si le commit n'est pas poussé ;
2. refuse si la CI n'est pas verte sur ce commit (`gh run list --commit <sha> --workflow ci.yml --json conclusion`) — contournable par `--force` explicite (message d'avertissement) ;
3. `docker build --platform linux/amd64 -t tistech0/collega-backend:<sha>` + contrôle d'un symbole + `docker push` (plus de `latest`) ;
4. NAS (`ssh nas`) : vérifie qu'aucun import n'est en cours (`arq:in-progress:*`, `arq:queue`, jobs actifs en base) — sinon attend (max 30 min) ou abandonne ; dump `pg_dumpall` dans `/mnt/user/appdata/collega/backups/collega_pre_<sha>_<date>.sql.gz` ; écrit `IMAGE_TAG=<sha>` dans le `.env` du NAS ; `docker compose pull && up -d` ;
5. attend `healthy` sur api et worker (max 3 min), affiche `docker logs collega-migrate-1` et `/health` ; en cas d'échec : message clair avec la commande de retour arrière (`deploy.sh <sha précédent>` + restauration du dump si la migration a changé le schéma).
- `docker-compose.prod.yml` : `image: tistech0/collega-backend:${IMAGE_TAG}` pour migrate, api, worker.
- Les runbooks (`docs/deployment.md`, mémoire Kage) sont réécrits autour du script.

## 6. Image Docker

- Multi-stage : étape `builder` (poetry, export/installation dans un venv `/opt/venv`), étape finale `python:3.11-slim` + dépendances système (tesseract, poppler) + `/opt/venv` ; sans poetry.
- Utilisateur non root `collega` (uid 1000) ; le volume `/tmp/collega_pdfs` doit être inscriptible : `chown` du dossier bind sur le NAS (`/mnt/user/appdata/collega/pdfs`) à l'uid choisi, étape documentée et faite au déploiement.
- Taille cible < 400 Mo (actuel 523 Mo).

## 7. Redis de prod

- `redis-server --requirepass ${REDIS_PASSWORD} --appendonly yes` ; `REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379/0` dans le `.env` du NAS (ajout d'une variable ; ne jamais écraser le `.env`). Healthcheck `redis-cli -a` adapté.
- Contrôle : `collega-health` et les workers fonctionnent après le changement.

## 8. Documentation et ménage

- `README.md` racine : présentation, arborescence (app / backend / widgetbook / _bmad-output), démarrage rapide, liens.
- `collega_backend/README.md` : installation (Python 3.11, poetry), tests (unitaires, pg, CI), conventions (format d'erreur, `{"data": …}`, couches api/services/workers), déploiement (`deploy.sh`), restauration (`docs/restore.md`).
- `CLAUDE.md` : ajouter une section « Conventions du dépôt pour les agents » (commandes de test, tests Flutter par dossier, format d'erreur, ne jamais écraser le `.env` du NAS, déploiement par script).
- Supprimés : `install.md`, `Caddyfile`, `Caddyfile.prod`, service `caddy` du compose de dev, `seed_dev.py` (non maintenu), `app/services/billing/` (vide). Compose de dev : ports DB/Redis liés à `127.0.0.1`.
- `docs/deployment.md` corrigé (validateur `SECRET_KEY` par égalité stricte, port 430 retiré, script).
- `pyproject` : description « Collega backend » (plus « AppMédecine »).

## 9. Vérification

- CI verte sur la branche (les deux jobs) ; `deploy.sh` exécuté pour de vrai sur le NAS (dump créé, image étiquetée, healthy) ; retour arrière testé une fois (redéploiement du sha précédent puis du courant, sans migration entre les deux).

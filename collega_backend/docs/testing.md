# Tests backend

- Unitaires et API : `.venv/bin/python -m pytest -q` (SQLite en mémoire et mocks ; les limites de débit sont en mémoire, plus besoin de Redis).
- Tests `pg` (pipeline d'import, schéma, purges) : Postgres réel.
  `docker compose -f docker-compose.test.yml up -d` (Postgres `127.0.0.1:55432`, Redis `127.0.0.1:56379`) puis `pytest -q`. Sans lui, ces tests échouent avec « Postgres de test injoignable ».
- Uniquement les tests pg : `pytest -m pg -q` ; les autres : `pytest -m "not pg" -q`.
- Chaque test pg repart d'un schéma vide migré par `alembic upgrade head` (vraies contraintes, index partiels, cascades).

## CI (`.github/workflows/ci.yml`)

- Job `backend` : services Postgres 16 (55432) et Redis 7 (56379), `ruff check`, `ruff format --check`, `mypy app/core app/services`, `pytest --cov=app`, `alembic upgrade head` + `alembic check` sur une base dédiée, `pip-audit` (informatif).
- Job `app` : Flutter 3.27.1, `flutter analyze`, puis `flutter test` lancé **dossier par dossier** (`test/core`, chaque `test/features/<dossier>`, fichiers racine) ; la liste des dossiers est découverte automatiquement.
- Rejouer la CI en local (même image ubuntu) : `act push -j backend -P ubuntu-latest=catthehacker/ubuntu:act-latest --container-architecture linux/amd64`.

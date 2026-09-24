# Tests backend

- Unitaires et API : `.venv/bin/python -m pytest -q` (SQLite en mémoire et mocks ; les limites de débit sont en mémoire, plus besoin de Redis).
- Tests `pg` (pipeline d'import, schéma, purges) : Postgres réel.
  `docker compose -f docker-compose.test.yml up -d` puis `pytest -q`. Sans lui, ces tests échouent avec « Postgres de test injoignable ».
- Uniquement les tests pg : `pytest -m pg -q` ; les autres : `pytest -m "not pg" -q`.
- Chaque test pg repart d'un schéma vide migré par `alembic upgrade head` (vraies contraintes, index partiels, cascades).

# Collega

[![CI](https://github.com/tistech0/collega/actions/workflows/ci.yml/badge.svg)](https://github.com/tistech0/collega/actions/workflows/ci.yml)

Application de révision pour les étudiants en médecine (EDN) : l'étudiante importe le PDF d'un collège, le backend en extrait les items (OCR) et génère des flashcards avec Claude ; l'app iOS les fait réviser en répétition espacée.

## Arborescence

| Dossier | Contenu |
|---|---|
| `collega_app/` | App Flutter (iOS) — `lib/core/ui` = Collega UI, `lib/features/<domaine>` |
| `collega_app/widgetbook/` | Catalogue des composants Collega UI |
| `collega_backend/` | API FastAPI + worker ARQ (OCR, génération), PostgreSQL, Redis — voir [`collega_backend/README.md`](collega_backend/README.md) |
| `_bmad-output/` | Specs, plans, audits et suivi des stories |
| `.agent_memory/` | Mémoire des agents (Kage) |

## Démarrage rapide

```sh
# Backend (Python 3.11 + poetry)
cd collega_backend
python3.11 -m venv .venv && poetry install --no-root
docker compose -f docker-compose.test.yml up -d   # Postgres + Redis de test
.venv/bin/python -m pytest -q

# App
cd ../collega_app
flutter pub get
flutter test test/core                            # tests lancés par dossier
tool/run_device.sh --release -d <id>              # build sur l'iPhone (service token Cloudflare dans .env.local)
```

La CI (`.github/workflows/ci.yml`) vérifie le backend (ruff, mypy, pytest, alembic check) et l'app (analyze, tests). Le déploiement se fait depuis le Mac avec `collega_backend/scripts/deploy.sh` (voir [`collega_backend/docs/deployment.md`](collega_backend/docs/deployment.md)).

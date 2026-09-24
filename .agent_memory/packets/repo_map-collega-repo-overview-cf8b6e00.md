---
type: "Repo Map"
title: "collega repo overview"
description: "README excerpt: Collega ! CI https://github.com/tistech0/collega/actions/workflows/ci.yml/badge.svg https://github.com/tistech0/collega/actions/workflows/ci.yml Application de révision pour les étudiants en médecine EDN "
resource: "README.md"
tags: ["repo", "overview"]
timestamp: "2026-09-24"
x-kage-id: "repo:git-github-com-tistech0-collega:repo_map:collega-repo-overview-auto-overview"
x-kage-type: "repo_map"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "verified"
x-kage-paths: ["README.md"]
---

# collega repo overview

> README excerpt: Collega ! CI https://github.com/tistech0/collega/actions/workflows/ci.yml/badge.svg https://github.co…

README excerpt:
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
docker

## Why

Agents need fast repo orientation before deeper recall or code graph queries, but generated overview memory should stay separate from human rationale.

## Trigger

Recall when an agent needs first-pass repo purpose, scripts, stack, or README context.

## Action

Use this as orientation only, then inspect source-backed memory and code graph facts for implementation decisions.

## Verification

Generated from package.json and README.md when present.

## Risk if forgotten

Agents may waste context rediscovering basic repo purpose or treat generated overview text as deeper semantic memory.

## Stale when

package.json or README.md changes enough that the generated overview no longer matches the repo.

# Citations

[1] file README.md

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:repo_map:collega-repo-overview-auto-overview","title":"collega repo overview","summary":"README excerpt: Collega ! CI https://github.com/tistech0/collega/actions/workflows/ci.yml/badge.svg https://github.com/tistech0/collega/actions/workflows/ci.yml Application de révision pour les étudiants en médecine EDN ","body":"README excerpt:\n# Collega\n\n[![CI](https://github.com/tistech0/collega/actions/workflows/ci.yml/badge.svg)](https://github.com/tistech0/collega/actions/workflows/ci.yml)\n\nApplication de révision pour les étudiants en médecine (EDN) : l'étudiante importe le PDF d'un collège, le backend en extrait les items (OCR) et génère des flashcards avec Claude ; l'app iOS les fait réviser en répétition espacée.\n\n## Arborescence\n\n| Dossier | Contenu |\n|---|---|\n| `collega_app/` | App Flutter (iOS) — `lib/core/ui` = Collega UI, `lib/features/<domaine>` |\n| `collega_app/widgetbook/` | Catalogue des composants Collega UI |\n| `collega_backend/` | API FastAPI + worker ARQ (OCR, génération), PostgreSQL, Redis — voir [`collega_backend/README.md`](collega_backend/README.md) |\n| `_bmad-output/` | Specs, plans, audits et suivi des stories |\n| `.agent_memory/` | Mémoire des agents (Kage) |\n\n## Démarrage rapide\n\n```sh\n# Backend (Python 3.11 + poetry)\ncd collega_backend\npython3.11 -m venv .venv && poetry install --no-root\ndocker","type":"repo_map","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.75,"tags":["repo","overview"],"paths":["README.md"],"stack":[],"source_refs":[{"kind":"file","path":"README.md"}],"context":{"fact":"Generated repo overview summarizes package metadata and the README as a navigation aid for agent startup.","why":"Agents need fast repo orientation before deeper recall or code graph queries, but generated overview memory should stay separate from human rationale.","trigger":"Recall when an agent needs first-pass repo purpose, scripts, stack, or README context.","action":"Use this as orientation only, then inspect source-backed memory and code graph facts for implementation decisions.","verification":"Generated from package.json and README.md when present.","risk_if_forgotten":"Agents may waste context rediscovering basic repo purpose or treat generated overview text as deeper semantic memory.","stale_when":"package.json or README.md changes enough that the generated overview no longer matches the repo."},"freshness":{"ttl_days":90,"last_verified_at":"2026-09-24","verification":"source_seen"},"edges":[],"quality":{"reviewer":"kage-indexer","votes_up":0,"votes_down":0,"uses_30d":4,"reports_stale":0,"total_uses":9,"last_accessed_at":"2026-09-24T18:10:26.606Z"},"created_at":"2026-07-04T13:28:22.032Z","updated_at":"2026-09-24T17:45:57.753Z"}
```


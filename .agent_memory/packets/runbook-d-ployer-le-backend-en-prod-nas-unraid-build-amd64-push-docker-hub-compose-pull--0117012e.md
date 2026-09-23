---
type: "Runbook"
title: "Déployer le backend en prod (NAS Unraid) : build amd64 → push Docker Hub → compose pull/up"
description: "Procédure vérifiée le 2026 09 20 : 1 depuis collega backend/ : docker build platform linux/amd64 t tistech0/collega backend:latest t tistech0/collega backend:<sha . OrbStack doit tourner : orb start ; vérifier le contenu"
resource: "collega_backend/Dockerfile"
tags: ["session-learning", "deploy", "prod", "nas", "docker", "compose", "unraid"]
timestamp: "2026-09-23T09:15:50.985Z"
x-kage-id: "repo:git-github-com-tistech0-collega:runbook:d-ployer-le-backend-en-prod-nas-unraid-build-amd64-push-docker-hub-compose-pull-"
x-kage-type: "runbook"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "verified"
x-kage-paths: ["collega_backend/Dockerfile", "collega_backend/docker-compose.prod.yml", "install.md"]
---

# Déployer le backend en prod (NAS Unraid) : build amd64 → push Docker Hub → compose pull/up

> Procédure vérifiée le 2026 09 20 : 1 depuis collega backend/ : docker build platform linux/amd64 t tistech0/collega b…

Procédure vérifiée le 2026-09-20 : (1) depuis collega_backend/ : `docker build --platform linux/amd64 -t tistech0/collega-backend:latest -t tistech0/collega-backend:<sha> .` (OrbStack doit tourner : `orb start`) ; vérifier le contenu de l'image avec `docker run --rm --platform linux/amd64 tistech0/collega-backend:latest grep -c <symbole> <fichier>` ; (2) `docker push` des deux tags ; (3) sur le NAS (alias ssh `nas`), le stack vit dans /mnt/user/appdata/compose-stacks/collega/ (docker-compose.yml + .env, PAS le docker-compose.prod.yml du repo) : `docker compose pull api worker migrate && docker compose up -d` — migrate (alembic upgrade head) tourne avant api, puis api et worker redémarrent (~10 s d'indisponibilité). Contrôle : `docker ps | grep collega`, `docker logs collega-migrate-1`, `docker logs collega-api-1`, et pour le SSE `curl -sN --resolve … /v1/colleges/{id}/stream` doit montrer `: keep-alive` toutes les 15 s. Le worker de prod ne loggue pas le logging Python applicatif sur stdout (seulement les lignes arq) : pour du détail, s'appuyer sur la DB (generation_jobs, generation_job_events) plutôt que sur docker logs.
Evidence: Déploiement effectué : commit 48e50f9, image digest sha256:20fc98b1…, containers api/worker Up, heartbeat observé à 15,2 s et 30,3 s via Cloudflare.
Verified by: ssh nas docker compose pull/up + curl -sN stream

## Verification

Déploiement effectué : commit 48e50f9, image digest sha256:20fc98b1…, containers api/worker Up, heartbeat observé à 15,2 s et 30,3 s via Cloudflare.

# Citations

[1] explicit_capture (2026-09-20T20:48:02.676Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:runbook:d-ployer-le-backend-en-prod-nas-unraid-build-amd64-push-docker-hub-compose-pull-","title":"Déployer le backend en prod (NAS Unraid) : build amd64 → push Docker Hub → compose pull/up","summary":"Procédure vérifiée le 2026 09 20 : 1 depuis collega backend/ : docker build platform linux/amd64 t tistech0/collega backend:latest t tistech0/collega backend:<sha . OrbStack doit tourner : orb start ; vérifier le contenu","body":"Procédure vérifiée le 2026-09-20 : (1) depuis collega_backend/ : `docker build --platform linux/amd64 -t tistech0/collega-backend:latest -t tistech0/collega-backend:<sha> .` (OrbStack doit tourner : `orb start`) ; vérifier le contenu de l'image avec `docker run --rm --platform linux/amd64 tistech0/collega-backend:latest grep -c <symbole> <fichier>` ; (2) `docker push` des deux tags ; (3) sur le NAS (alias ssh `nas`), le stack vit dans /mnt/user/appdata/compose-stacks/collega/ (docker-compose.yml + .env, PAS le docker-compose.prod.yml du repo) : `docker compose pull api worker migrate && docker compose up -d` — migrate (alembic upgrade head) tourne avant api, puis api et worker redémarrent (~10 s d'indisponibilité). Contrôle : `docker ps | grep collega`, `docker logs collega-migrate-1`, `docker logs collega-api-1`, et pour le SSE `curl -sN --resolve … /v1/colleges/{id}/stream` doit montrer `: keep-alive` toutes les 15 s. Le worker de prod ne loggue pas le logging Python applicatif sur stdout (seulement les lignes arq) : pour du détail, s'appuyer sur la DB (generation_jobs, generation_job_events) plutôt que sur docker logs.\nEvidence: Déploiement effectué : commit 48e50f9, image digest sha256:20fc98b1…, containers api/worker Up, heartbeat observé à 15,2 s et 30,3 s via Cloudflare.\nVerified by: ssh nas docker compose pull/up + curl -sN stream","type":"runbook","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","deploy","prod","nas","docker","compose","unraid"],"paths":["collega_backend/Dockerfile","collega_backend/docker-compose.prod.yml","install.md"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-20T20:48:02.676Z"}],"context":{"fact":"Procédure vérifiée le 2026-09-20 : (1) depuis collega_backend/ : `docker build --platform linux/amd64 -t tistech0/collega-backend:latest -t tistech0/collega-backend:<sha> .` (OrbStack doit tourner : `orb start`) ; vérifier le contenu de l'image avec `docker run --rm --platform linux/amd64 tistech0/collega-backend:latest grep -c <symbole> <fichier>` ; (2) `docker push` des deux tags ; (3) sur le NAS (alias ssh `nas`), le stack vit dans /mnt/user/appdata/compose-stacks/collega/ (docker-compose.yml + .env, PAS le docker-compose.prod.yml du repo) : `docker compose pull api worker migrate && docker compose up -d` — migrate (alembic upgrade head) tourne avant api, puis api et worker redémarrent (~10 s d'indisponibilité). Contrôle : `docker ps | grep collega`, `docker logs collega-migrate-1`, `docker logs collega-api-1`, et pour le SSE `curl -sN --resolve … /v1/colleges/{id}/stream` doit montrer `: keep-alive` toutes les 15 s. Le worker de prod ne loggue pas le logging Python applicatif sur stdout (seulement les lignes arq) : pour du détail, s'appuyer sur la DB (generation_jobs, generation_job_events) plutôt que sur docker logs.\nEvidence: Déploiement effectué : commit 48e50f9, image digest sha256:20fc98b1…, containers api/worker Up, heartbeat observé à 15,2 s et 30,3 s via Cloudflare.\nVerified by: ssh nas docker compose pull/up + curl -sN stream","verification":"Déploiement effectué : commit 48e50f9, image digest sha256:20fc98b1…, containers api/worker Up, heartbeat observé à 15,2 s et 30,3 s via Cloudflare."},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-23T09:15:50.985Z","path_fingerprints":[{"path":"collega_backend/Dockerfile","sha256":"6016f38ea9a3d1b4419f2f56e090336647c2231171ea8037f4080cebd46a4d6e","size":483},{"path":"collega_backend/docker-compose.prod.yml","sha256":"95fb17c7b60fff181d746c0a100814a8a427ede2dc4c3759820c01d0b594aca7","size":2249},{"path":"install.md","sha256":"2be4aa6daf4221245857918cbaa20a3f6c20f35807f5606895a1bae8345863fe","size":5270}],"path_fingerprint_policy":"source_hash_staleness","verification":"evidence_reverification"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":20,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":2000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":340,"total_uses":26,"last_accessed_at":"2026-09-21T15:18:13.507Z","reverified_at":"2026-09-23T09:15:50.985Z"},"created_at":"2026-09-20T20:48:02.676Z","updated_at":"2026-09-23T09:15:50.985Z","author_branch":"main"}
```


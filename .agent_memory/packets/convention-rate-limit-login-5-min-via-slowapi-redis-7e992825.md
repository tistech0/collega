---
type: "Convention"
title: "Rate limit login 5/min via slowapi + Redis"
description: "Le rate limiting du backend collega utilise slowapi avec un stockage Redis. Le Limiter partagé est défini dans collega backend/app/core/limiter.py:14 Limiter key func=get client ip, storage uri=settings.redis url et bran"
resource: "collega_backend/app/core/limiter.py"
tags: ["session-learning", "security", "rate-limit", "auth", "login", "audit-2026-09-23"]
timestamp: "2026-09-23T15:53:33.831Z"
x-kage-id: "repo:git-github-com-tistech0-collega:convention:rate-limit-login-5-min-via-slowapi-redis-1790178813831"
x-kage-type: "convention"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: ["collega_backend/app/core/limiter.py", "collega_backend/app/main.py", "collega_backend/app/api/v1/auth.py"]
---

# Rate limit login 5/min via slowapi + Redis

> Le rate limiting du backend collega utilise slowapi avec un stockage Redis. Le Limiter partagé est défini dans colleg…

Le rate limiting du backend collega utilise slowapi avec un stockage Redis. Le Limiter partagé est défini dans collega_backend/app/core/limiter.py:14 (`Limiter(key_func=get_client_ip, storage_uri=settings.redis_url)`) et branché dans collega_backend/app/main.py:88-89 (`app.state.limiter = limiter` + handler `RateLimitExceeded`). La route de connexion `POST /v1/auth/login` est limitée à 5 requêtes/minute via `@limiter.limit("5/minute")` dans collega_backend/app/api/v1/auth.py:36 (clé = IP client, X-Forwarded-For en priorité). Autres limites en place : delete account 3/min (auth.py:151), search 30/min par user (search.py:35), notifications 10/min (notifications.py:51 et 64), flash_cards 10/hour (flash_cards.py:66).
Evidence: grep + lecture du code : auth.py:36 `@limiter.limit("5/minute")` sur `POST /login` ; limiter.py:14 storage_uri=settings.redis_url ; main.py:88 app.state.limiter = limiter.
Verified by: Lecture directe des fichiers source le 2026-07-04 ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)

## Verification

grep + lecture du code : auth.py:36 `@limiter.limit("5/minute")` sur `POST /login` ; limiter.py:14 storage_uri=settings.redis_url ; main.py:88 app.state.limiter = limiter.

# Citations

[1] explicit_capture (2026-09-23T15:53:33.831Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:convention:rate-limit-login-5-min-via-slowapi-redis-1790178813831","title":"Rate limit login 5/min via slowapi + Redis","summary":"Le rate limiting du backend collega utilise slowapi avec un stockage Redis. Le Limiter partagé est défini dans collega backend/app/core/limiter.py:14 Limiter key func=get client ip, storage uri=settings.redis url et bran","body":"Le rate limiting du backend collega utilise slowapi avec un stockage Redis. Le Limiter partagé est défini dans collega_backend/app/core/limiter.py:14 (`Limiter(key_func=get_client_ip, storage_uri=settings.redis_url)`) et branché dans collega_backend/app/main.py:88-89 (`app.state.limiter = limiter` + handler `RateLimitExceeded`). La route de connexion `POST /v1/auth/login` est limitée à 5 requêtes/minute via `@limiter.limit(\"5/minute\")` dans collega_backend/app/api/v1/auth.py:36 (clé = IP client, X-Forwarded-For en priorité). Autres limites en place : delete account 3/min (auth.py:151), search 30/min par user (search.py:35), notifications 10/min (notifications.py:51 et 64), flash_cards 10/hour (flash_cards.py:66).\nEvidence: grep + lecture du code : auth.py:36 `@limiter.limit(\"5/minute\")` sur `POST /login` ; limiter.py:14 storage_uri=settings.redis_url ; main.py:88 app.state.limiter = limiter.\nVerified by: Lecture directe des fichiers source le 2026-07-04 ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)","type":"convention","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","security","rate-limit","auth","login","audit-2026-09-23"],"paths":["collega_backend/app/core/limiter.py","collega_backend/app/main.py","collega_backend/app/api/v1/auth.py"],"stack":[],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-09-23T15:53:33.831Z"}],"context":{"fact":"Le rate limiting du backend collega utilise slowapi avec un stockage Redis. Le Limiter partagé est défini dans collega_backend/app/core/limiter.py:14 (`Limiter(key_func=get_client_ip, storage_uri=settings.redis_url)`) et branché dans collega_backend/app/main.py:88-89 (`app.state.limiter = limiter` + handler `RateLimitExceeded`). La route de connexion `POST /v1/auth/login` est limitée à 5 requêtes/minute via `@limiter.limit(\"5/minute\")` dans collega_backend/app/api/v1/auth.py:36 (clé = IP client, X-Forwarded-For en priorité). Autres limites en place : delete account 3/min (auth.py:151), search 30/min par user (search.py:35), notifications 10/min (notifications.py:51 et 64), flash_cards 10/hour (flash_cards.py:66).\nEvidence: grep + lecture du code : auth.py:36 `@limiter.limit(\"5/minute\")` sur `POST /login` ; limiter.py:14 storage_uri=settings.redis_url ; main.py:88 app.state.limiter = limiter.\nVerified by: Lecture directe des fichiers source le 2026-07-04 ; Audit mémoire 2026-09-23 contre main 560e503 (lecture du code + tests ciblés verts)","verification":"grep + lecture du code : auth.py:36 `@limiter.limit(\"5/minute\")` sur `POST /login` ; limiter.py:14 storage_uri=settings.redis_url ; main.py:88 app.state.limiter = limiter."},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-23T15:53:33.831Z","path_fingerprints":[{"path":"collega_backend/app/core/limiter.py","sha256":"8f521e65d02d642ccbd6f63d1c1e88d64b646aba822a156f0af3685dbde942cc","size":412},{"path":"collega_backend/app/main.py","sha256":"72f91bde01e4388bf75be096c8bffb9f124cb655b79ce25677f14d97786fae3a","size":4305},{"path":"collega_backend/app/api/v1/auth.py","sha256":"13c19d4ed3a63dcd4368f8e4cc959df76589c87c6823f426e9c82769e71bb275","size":6166}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[{"relation":"supersedes","to":"repo:git-github-com-tistech0-collega:convention:rate-limit-login-5-min-via-slowapi-redis-1783173314858","evidence":"Revérifié contre main 560e503 (audit 2026-09-23) : passages périmés corrigés","created_at":"2026-09-23T15:53:34.218Z"}],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":0,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":2000,"discovery_tokens_estimated":true,"score":86,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":["possible duplicate memory"],"duplicate_candidates":[{"id":"repo:git-github-com-tistech0-collega:convention:rate-limit-login-5-min-via-slowapi-redis-1783173314858","title":"Rate limit login 5/min via slowapi + Redis","score":0.82,"status":"approved"}],"estimated_tokens_saved":264,"total_uses":0},"created_at":"2026-09-23T15:53:33.831Z","updated_at":"2026-09-23T15:53:34.218Z","author_branch":"main"}
```


---
type: "Convention"
title: "Rate limit login 5/min via slowapi + Redis"
description: "Le rate limiting du backend collega utilise slowapi avec un stockage Redis. Le Limiter partagé est défini dans collega backend/app/core/limiter.py:14 Limiter key func=get client ip, storage uri=settings.redis url et bran"
resource: "collega_backend/app/core/limiter.py"
tags: ["session-learning", "security", "rate-limit", "auth", "login"]
timestamp: "2026-07-04T13:55:14.858Z"
x-kage-id: "repo:git-github-com-tistech0-collega:convention:rate-limit-login-5-min-via-slowapi-redis-1783173314858"
x-kage-type: "convention"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: ["collega_backend/app/core/limiter.py", "collega_backend/app/main.py", "collega_backend/app/api/v1/auth.py"]
x-kage-stack: ["FastAPI", "slowapi", "Redis"]
---

# Rate limit login 5/min via slowapi + Redis

> Le rate limiting du backend collega utilise slowapi avec un stockage Redis. Le Limiter partagé est défini dans colleg…

Le rate limiting du backend collega utilise slowapi avec un stockage Redis. Le Limiter partagé est défini dans collega_backend/app/core/limiter.py:14 (`Limiter(key_func=get_client_ip, storage_uri=settings.redis_url)`) et branché dans collega_backend/app/main.py:88-89 (`app.state.limiter = limiter` + handler `RateLimitExceeded`). La route de connexion `POST /v1/auth/login` est limitée à 5 requêtes/minute via `@limiter.limit("5/minute")` dans collega_backend/app/api/v1/auth.py:34 (clé = IP client). Autres limites en place : delete account 3/min (auth.py:139), search 30/min par user, notifications 10/min, flash_cards 10/hour.
Evidence: grep + lecture du code : auth.py:34 `@limiter.limit("5/minute")` sur `POST /login` ; limiter.py:14 storage_uri=settings.redis_url ; main.py:88 app.state.limiter = limiter.
Verified by: Lecture directe des fichiers source le 2026-07-04

## Verification

grep + lecture du code : auth.py:34 `@limiter.limit("5/minute")` sur `POST /login` ; limiter.py:14 storage_uri=settings.redis_url ; main.py:88 app.state.limiter = limiter.

# Citations

[1] explicit_capture (2026-07-04T13:55:14.858Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:convention:rate-limit-login-5-min-via-slowapi-redis-1783173314858","title":"Rate limit login 5/min via slowapi + Redis","summary":"Le rate limiting du backend collega utilise slowapi avec un stockage Redis. Le Limiter partagé est défini dans collega backend/app/core/limiter.py:14 Limiter key func=get client ip, storage uri=settings.redis url et bran","body":"Le rate limiting du backend collega utilise slowapi avec un stockage Redis. Le Limiter partagé est défini dans collega_backend/app/core/limiter.py:14 (`Limiter(key_func=get_client_ip, storage_uri=settings.redis_url)`) et branché dans collega_backend/app/main.py:88-89 (`app.state.limiter = limiter` + handler `RateLimitExceeded`). La route de connexion `POST /v1/auth/login` est limitée à 5 requêtes/minute via `@limiter.limit(\"5/minute\")` dans collega_backend/app/api/v1/auth.py:34 (clé = IP client). Autres limites en place : delete account 3/min (auth.py:139), search 30/min par user, notifications 10/min, flash_cards 10/hour.\nEvidence: grep + lecture du code : auth.py:34 `@limiter.limit(\"5/minute\")` sur `POST /login` ; limiter.py:14 storage_uri=settings.redis_url ; main.py:88 app.state.limiter = limiter.\nVerified by: Lecture directe des fichiers source le 2026-07-04","type":"convention","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","security","rate-limit","auth","login"],"paths":["collega_backend/app/core/limiter.py","collega_backend/app/main.py","collega_backend/app/api/v1/auth.py"],"stack":["FastAPI","slowapi","Redis"],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-07-04T13:55:14.858Z"}],"context":{"fact":"Le rate limiting du backend collega utilise slowapi avec un stockage Redis. Le Limiter partagé est défini dans collega_backend/app/core/limiter.py:14 (`Limiter(key_func=get_client_ip, storage_uri=settings.redis_url)`) et branché dans collega_backend/app/main.py:88-89 (`app.state.limiter = limiter` + handler `RateLimitExceeded`). La route de connexion `POST /v1/auth/login` est limitée à 5 requêtes/minute via `@limiter.limit(\"5/minute\")` dans collega_backend/app/api/v1/auth.py:34 (clé = IP client). Autres limites en place : delete account 3/min (auth.py:139), search 30/min par user, notifications 10/min, flash_cards 10/hour.\nEvidence: grep + lecture du code : auth.py:34 `@limiter.limit(\"5/minute\")` sur `POST /login` ; limiter.py:14 storage_uri=settings.redis_url ; main.py:88 app.state.limiter = limiter.\nVerified by: Lecture directe des fichiers source le 2026-07-04","verification":"grep + lecture du code : auth.py:34 `@limiter.limit(\"5/minute\")` sur `POST /login` ; limiter.py:14 storage_uri=settings.redis_url ; main.py:88 app.state.limiter = limiter."},"freshness":{"ttl_days":365,"last_verified_at":"2026-07-04T13:55:14.858Z","path_fingerprints":[{"path":"collega_backend/app/core/limiter.py","sha256":"8f521e65d02d642ccbd6f63d1c1e88d64b646aba822a156f0af3685dbde942cc","size":412},{"path":"collega_backend/app/main.py","sha256":"6d7102758a9de0abb1058c63b1c84bafd49912e05b3f53ad77341327c855471c","size":4310},{"path":"collega_backend/app/api/v1/auth.py","sha256":"448df64a37bb0e99ad446bb828698c115cd18bf09b7750f9bef25c53d93a8a36","size":5539}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":6,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":2000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":219,"total_uses":7,"last_accessed_at":"2026-09-21T14:02:15.524Z"},"created_at":"2026-07-04T13:55:14.858Z","updated_at":"2026-07-04T13:55:14.858Z","author_branch":"main"}
```


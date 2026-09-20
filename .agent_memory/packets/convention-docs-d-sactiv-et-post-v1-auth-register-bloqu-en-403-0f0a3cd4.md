---
type: "Convention"
title: "/docs désactivé et POST /v1/auth/register bloqué en 403"
description: "Durcissement sécurité du backend collega : 1 la documentation OpenAPI est désactivée en configurant l'app FastAPI avec docs url=None et redoc url=None dans collega backend/app/main.py:84 85 — pas de Swagger ni ReDoc expo"
resource: "collega_backend/app/main.py"
tags: ["session-learning", "security", "hardening", "docs", "register", "auth"]
timestamp: "2026-07-04T13:55:19.217Z"
x-kage-id: "repo:git-github-com-tistech0-collega:convention:docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-1783173319217"
x-kage-type: "convention"
x-kage-status: "approved"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "unverified"
x-kage-paths: ["collega_backend/app/main.py", "collega_backend/app/api/v1/auth.py", "collega_backend/app/api/v1/admin.py"]
x-kage-stack: ["FastAPI"]
---

# /docs désactivé et POST /v1/auth/register bloqué en 403

> Durcissement sécurité du backend collega : 1 la documentation OpenAPI est désactivée en configurant l'app FastAPI ave…

Durcissement sécurité du backend collega : (1) la documentation OpenAPI est désactivée en configurant l'app FastAPI avec `docs_url=None` et `redoc_url=None` dans collega_backend/app/main.py:84-85 — pas de Swagger ni ReDoc exposés. (2) L'inscription publique est fermée : `POST /v1/auth/register` lève systématiquement une HTTPException 403 avec `{"code": "REGISTRATION_DISABLED"}` dans collega_backend/app/api/v1/auth.py:25-30. Le seul point d'entrée d'onboarding est la création d'utilisateur via la console admin (Basic Auth), qui ne réactive jamais le register public (cf. admin.py:458-460).
Evidence: main.py:84-85 docs_url=None/redoc_url=None ; auth.py:27-30 raise HTTPException 403 REGISTRATION_DISABLED ; admin.py:458-460 confirme onboarding via console admin uniquement.
Verified by: Lecture directe des fichiers source le 2026-07-04

## Verification

main.py:84-85 docs_url=None/redoc_url=None ; auth.py:27-30 raise HTTPException 403 REGISTRATION_DISABLED ; admin.py:458-460 confirme onboarding via console admin uniquement.

# Citations

[1] explicit_capture (2026-07-04T13:55:19.217Z)

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:convention:docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-1783173319217","title":"/docs désactivé et POST /v1/auth/register bloqué en 403","summary":"Durcissement sécurité du backend collega : 1 la documentation OpenAPI est désactivée en configurant l'app FastAPI avec docs url=None et redoc url=None dans collega backend/app/main.py:84 85 — pas de Swagger ni ReDoc expo","body":"Durcissement sécurité du backend collega : (1) la documentation OpenAPI est désactivée en configurant l'app FastAPI avec `docs_url=None` et `redoc_url=None` dans collega_backend/app/main.py:84-85 — pas de Swagger ni ReDoc exposés. (2) L'inscription publique est fermée : `POST /v1/auth/register` lève systématiquement une HTTPException 403 avec `{\"code\": \"REGISTRATION_DISABLED\"}` dans collega_backend/app/api/v1/auth.py:25-30. Le seul point d'entrée d'onboarding est la création d'utilisateur via la console admin (Basic Auth), qui ne réactive jamais le register public (cf. admin.py:458-460).\nEvidence: main.py:84-85 docs_url=None/redoc_url=None ; auth.py:27-30 raise HTTPException 403 REGISTRATION_DISABLED ; admin.py:458-460 confirme onboarding via console admin uniquement.\nVerified by: Lecture directe des fichiers source le 2026-07-04","type":"convention","scope":"repo","visibility":"team","sensitivity":"internal","status":"approved","confidence":0.7,"tags":["session-learning","security","hardening","docs","register","auth"],"paths":["collega_backend/app/main.py","collega_backend/app/api/v1/auth.py","collega_backend/app/api/v1/admin.py"],"stack":["FastAPI"],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-07-04T13:55:19.217Z"}],"context":{"fact":"Durcissement sécurité du backend collega : (1) la documentation OpenAPI est désactivée en configurant l'app FastAPI avec `docs_url=None` et `redoc_url=None` dans collega_backend/app/main.py:84-85 — pas de Swagger ni ReDoc exposés. (2) L'inscription publique est fermée : `POST /v1/auth/register` lève systématiquement une HTTPException 403 avec `{\"code\": \"REGISTRATION_DISABLED\"}` dans collega_backend/app/api/v1/auth.py:25-30. Le seul point d'entrée d'onboarding est la création d'utilisateur via la console admin (Basic Auth), qui ne réactive jamais le register public (cf. admin.py:458-460).\nEvidence: main.py:84-85 docs_url=None/redoc_url=None ; auth.py:27-30 raise HTTPException 403 REGISTRATION_DISABLED ; admin.py:458-460 confirme onboarding via console admin uniquement.\nVerified by: Lecture directe des fichiers source le 2026-07-04","verification":"main.py:84-85 docs_url=None/redoc_url=None ; auth.py:27-30 raise HTTPException 403 REGISTRATION_DISABLED ; admin.py:458-460 confirme onboarding via console admin uniquement."},"freshness":{"ttl_days":365,"last_verified_at":"2026-07-04T13:55:19.217Z","path_fingerprints":[{"path":"collega_backend/app/main.py","sha256":"6d7102758a9de0abb1058c63b1c84bafd49912e05b3f53ad77341327c855471c","size":4310},{"path":"collega_backend/app/api/v1/auth.py","sha256":"448df64a37bb0e99ad446bb828698c115cd18bf09b7750f9bef25c53d93a8a36","size":5539},{"path":"collega_backend/app/api/v1/admin.py","sha256":"6e950ec42522fe51f1093e8fd0d996e30168e9475af09effd099c974b9ffec4c","size":36071}],"path_fingerprint_policy":"source_hash_staleness","verification":"repo_local_agent_capture"},"edges":[],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":5,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":2000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":211,"total_uses":6,"last_accessed_at":"2026-09-20T20:20:54.672Z"},"created_at":"2026-07-04T13:55:19.217Z","updated_at":"2026-07-04T13:55:19.217Z","author_branch":"main"}
```


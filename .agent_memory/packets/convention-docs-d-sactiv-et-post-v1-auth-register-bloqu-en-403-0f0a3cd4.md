---
type: "Convention"
title: "/docs désactivé et POST /v1/auth/register bloqué en 403"
description: "Durcissement sécurité du backend collega : 1 la documentation OpenAPI est désactivée en configurant l'app FastAPI avec docs url=None et redoc url=None dans collega backend/app/main.py:84 85 — pas de Swagger ni ReDoc expo"
resource: "collega_backend/app/main.py"
tags: ["session-learning", "security", "hardening", "docs", "register", "auth"]
timestamp: "2026-09-23T15:39:40.921Z"
x-kage-id: "repo:git-github-com-tistech0-collega:convention:docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-1783173319217"
x-kage-type: "convention"
x-kage-status: "superseded"
x-kage-scope: "repo"
x-kage-visibility: "team"
x-kage-verified: "superseded"
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
[2] reverification
[3] reverification

## Kage state

Machine state for lossless round-trip; OKF consumers can ignore it.

```json kage-state
{"schema_version":2,"id":"repo:git-github-com-tistech0-collega:convention:docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-1783173319217","title":"/docs désactivé et POST /v1/auth/register bloqué en 403","summary":"Durcissement sécurité du backend collega : 1 la documentation OpenAPI est désactivée en configurant l'app FastAPI avec docs url=None et redoc url=None dans collega backend/app/main.py:84 85 — pas de Swagger ni ReDoc expo","body":"Durcissement sécurité du backend collega : (1) la documentation OpenAPI est désactivée en configurant l'app FastAPI avec `docs_url=None` et `redoc_url=None` dans collega_backend/app/main.py:84-85 — pas de Swagger ni ReDoc exposés. (2) L'inscription publique est fermée : `POST /v1/auth/register` lève systématiquement une HTTPException 403 avec `{\"code\": \"REGISTRATION_DISABLED\"}` dans collega_backend/app/api/v1/auth.py:25-30. Le seul point d'entrée d'onboarding est la création d'utilisateur via la console admin (Basic Auth), qui ne réactive jamais le register public (cf. admin.py:458-460).\nEvidence: main.py:84-85 docs_url=None/redoc_url=None ; auth.py:27-30 raise HTTPException 403 REGISTRATION_DISABLED ; admin.py:458-460 confirme onboarding via console admin uniquement.\nVerified by: Lecture directe des fichiers source le 2026-07-04","type":"convention","scope":"repo","visibility":"team","sensitivity":"internal","status":"superseded","confidence":0.7,"tags":["session-learning","security","hardening","docs","register","auth"],"paths":["collega_backend/app/main.py","collega_backend/app/api/v1/auth.py","collega_backend/app/api/v1/admin.py"],"stack":["FastAPI"],"source_refs":[{"kind":"explicit_capture","captured_at":"2026-07-04T13:55:19.217Z"},{"kind":"reverification","at":"2026-09-23T10:42:38.714Z","evidence":"auth.py only gained /me fields (quota, reminder); register still 403 REGISTRATION_DISABLED, test_inscription_fermee_beta_privee green","changed_paths":[{"path":"collega_backend/app/api/v1/auth.py","prior_sha256":"448df64a37bb0e99ad446bb828698c115cd18bf09b7750f9bef25c53d93a8a36","sha256":"13c19d4ed3a63dcd4368f8e4cc959df76589c87c6823f426e9c82769e71bb275"}]},{"kind":"reverification","at":"2026-09-23T15:39:40.921Z","evidence":"main.py : seul le titre de l'API renommé Collega ; docs_url=None et register 403 inchangés ; backend 480 verts","changed_paths":[{"path":"collega_backend/app/main.py","prior_sha256":"6d7102758a9de0abb1058c63b1c84bafd49912e05b3f53ad77341327c855471c","sha256":"72f91bde01e4388bf75be096c8bffb9f124cb655b79ce25677f14d97786fae3a"}]}],"context":{"fact":"Durcissement sécurité du backend collega : (1) la documentation OpenAPI est désactivée en configurant l'app FastAPI avec `docs_url=None` et `redoc_url=None` dans collega_backend/app/main.py:84-85 — pas de Swagger ni ReDoc exposés. (2) L'inscription publique est fermée : `POST /v1/auth/register` lève systématiquement une HTTPException 403 avec `{\"code\": \"REGISTRATION_DISABLED\"}` dans collega_backend/app/api/v1/auth.py:25-30. Le seul point d'entrée d'onboarding est la création d'utilisateur via la console admin (Basic Auth), qui ne réactive jamais le register public (cf. admin.py:458-460).\nEvidence: main.py:84-85 docs_url=None/redoc_url=None ; auth.py:27-30 raise HTTPException 403 REGISTRATION_DISABLED ; admin.py:458-460 confirme onboarding via console admin uniquement.\nVerified by: Lecture directe des fichiers source le 2026-07-04","verification":"main.py:84-85 docs_url=None/redoc_url=None ; auth.py:27-30 raise HTTPException 403 REGISTRATION_DISABLED ; admin.py:458-460 confirme onboarding via console admin uniquement."},"freshness":{"ttl_days":365,"last_verified_at":"2026-09-23T15:39:40.921Z","path_fingerprints":[{"path":"collega_backend/app/main.py","sha256":"72f91bde01e4388bf75be096c8bffb9f124cb655b79ce25677f14d97786fae3a","size":4305},{"path":"collega_backend/app/api/v1/auth.py","sha256":"13c19d4ed3a63dcd4368f8e4cc959df76589c87c6823f426e9c82769e71bb275","size":6166},{"path":"collega_backend/app/api/v1/admin.py","sha256":"6e950ec42522fe51f1093e8fd0d996e30168e9475af09effd099c974b9ffec4c","size":36071}],"path_fingerprint_policy":"source_hash_staleness","verification":"evidence_reverification","superseded_at":"2026-09-23T15:53:31.876Z","superseded_by":"repo:git-github-com-tistech0-collega:convention:docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-1790178811463","superseded_reason":"Revérifié contre main 560e503 (audit 2026-09-23) : passages périmés corrigés"},"edges":[{"relation":"superseded_by","to":"repo:git-github-com-tistech0-collega:convention:docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-1790178811463","evidence":"Revérifié contre main 560e503 (audit 2026-09-23) : passages périmés corrigés","created_at":"2026-09-23T15:53:31.876Z"}],"quality":{"reviewer":"repo-local-agent","votes_up":0,"votes_down":0,"uses_30d":8,"reports_stale":0,"review_boundary":"git_or_pr","promotion_requires_review":true,"discovery_tokens":2000,"discovery_tokens_estimated":true,"score":100,"reasons":["high-value memory type","has source evidence","grounded to repo paths","tagged","concise but substantive","actionable rationale or verification"],"risks":[],"duplicate_candidates":[],"estimated_tokens_saved":211,"total_uses":9,"last_accessed_at":"2026-09-23T10:46:47.582Z","reverified_at":"2026-09-23T15:39:40.921Z","superseded_by":"repo:git-github-com-tistech0-collega:convention:docs-d-sactiv-et-post-v1-auth-register-bloqu-en-403-1790178811463","superseded_reason":"Revérifié contre main 560e503 (audit 2026-09-23) : passages périmés corrigés","stale":true,"stale_reasons":["packet status is superseded"],"suggested_action":"mark_stale"},"created_at":"2026-07-04T13:55:19.217Z","updated_at":"2026-09-23T15:53:31.876Z","author_branch":"main"}
```


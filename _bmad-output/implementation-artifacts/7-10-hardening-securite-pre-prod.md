# Story 7.10 : Hardening sécurité & résilience pré-prod

Status: ready-for-dev

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **Project Lead / responsable déploiement**,
je veux corriger les trois faiblesses sécurité/résilience backend identifiées par les revues de code (dépendance JWT vulnérable, rate-limiter qui tombe en panne si Redis est indisponible, absence de révocation de token au logout),
afin que le backend soit **déployable en prod/beta sans surface d'attaque ni point de défaillance unique connu**.

## Contexte & périmètre (à lire avant de coder)

Story issue de la **short-list « avant-prod »** filtrée depuis `deferred-work.md` (revues 1.1 → 7.8), suite logique de l'épic 7 (hardening). Elle ne traite QUE les items réellement non résolus.

**⚠️ DÉJÀ FAIT — NE PAS REFAIRE (vérifié dans le code le 2026-06-19) :**

| Item initial | État réel | Preuve |
|--------------|-----------|--------|
| Démarrage qui crashe si `REVENUECAT_WEBHOOK_SECRET` absent | **Géré (Story 7.3)** : `config.py:_require_webhook_secret` + `_validate_production_secrets` rejettent en prod ; tests fournissent la var via `conftest.py:15` | `config.py:66-70,83-146` |
| Mots de passe par défaut faibles / entropie `secret_key` non validée | **Géré (Story 7.3)** : `secret_key ≥ 32` + placeholders admin/tester/webhook rejetés (fail-closed prod) | `config.py:110-137` |
| Ports DB/Redis exposés sur l'hôte | **Géré** : `docker-compose.prod.yml` n'a **aucun** `ports:` sur `db`/`redis` (commentaires explicites « NE PAS ajouter ports ») ; seul `api` expose `430:8000` (attendu) | `docker-compose.prod.yml:49-50,68-69` |

**→ Le périmètre de CETTE story = uniquement les 3 ACs ci-dessous (items 2, 3, 4).**

**Hors périmètre (NE PAS faire ici) :**
- Pas de refonte de l'auth admin/tester (Basic Auth) — c'est la Story 7.9 (différée post-beta).
- Pas de changement des durées de token (`ACCESS_TOKEN_EXPIRE_MINUTES=30`, `REFRESH_TOKEN_EXPIRE_DAYS=30`) sauf si AC3 l'impose.
- Pas de migration de `passlib`/`bcrypt` (contrainte `bcrypt<4.0.0` à conserver, cf. mémoire projet).
- Pas de monitoring/alerting (Sentry/Crashlytics) — story dédiée séparée.

## Acceptance Criteria

### AC1 — Remplacer `python-jose` (CVE) par `PyJWT`

**Étant donné** que le backend signe/vérifie les JWT via `python-jose` (`from jose import JWTError, jwt`), affecté par **CVE-2024-33663** (algorithm confusion) et **CVE-2024-33664** (DoS JWE)
**Quand** un access/refresh token est créé puis décodé
**Alors** `python-jose` est **remplacé par `PyJWT`** (`import jwt`) dans `app/core/security.py` et retiré de `pyproject.toml`
**Et** l'algorithme reste **HS256**, le claim `type` (`access`/`refresh`) et l'expiration (`exp`) sont **préservés à l'identique** (mêmes payloads, mêmes durées)
**Et** `app/core/security.py` continue d'exporter un symbole **`JWTError`** compatible avec les appelants existants (`app/deps.py:10` et `app/api/v1/auth.py:8` font `from app.core.security import ... JWTError`) → mappé sur la hiérarchie d'exceptions PyJWT pour que les `except JWTError` existants catchent toujours un token **expiré** ou **invalide**
**Et** les tests existants `tests/test_auth.py` (login/refresh/get_me/delete_account) restent verts, **sans modification de leur logique** (au plus l'import)
**Et** un token expiré ou de signature invalide renvoie toujours `401` (pas de 500 non catché)

### AC2 — Rate-limiter fail-open si Redis indisponible

**Étant donné** que `app/core/limiter.py` instancie `Limiter(key_func=get_client_ip, storage_uri=settings.redis_url)` — dépendance dure à Redis
**Quand** Redis est **injoignable** (down, réseau coupé)
**Alors** les endpoints rate-limités (`POST /v1/login` `5/minute`, `DELETE /v1/account` `3/minute`, `/v1/search`) **ne renvoient plus `500`** : le limiter **fail-open** (laisse passer la requête) au lieu de fail-closed
**Et** une erreur du backend de stockage du limiter est **loggée** (observabilité — ne pas avaler en silence total)
**Et** les ~16 tests « rouges pré-existants » qui échouent en local par `ConnectionRefusedError` Redis (`test_auth`/`test_flash_cards`/`test_reminder`/`test_search`) **passent au vert** (effet de bord attendu et souhaité de ce fix)
**Et** quand Redis EST disponible, le rate-limiting fonctionne **exactement comme avant** (login bloqué au 6ᵉ essai/min — non-régression)

### AC3 — Révocation JWT server-side au logout (scope minimal beta)

**Étant donné** qu'un JWT est stateless : un token reste valide jusqu'à son `exp` (access 30 min, refresh 30 jours) **même après déconnexion** — un token volé reste exploitable
**Quand** un utilisateur se déconnecte
**Alors** un endpoint **`POST /v1/auth/logout`** (authentifié) **révoque le refresh token** via une **blocklist Redis** keyée sur le claim `jti` du token, avec **TTL = durée de vie résiduelle** du token (auto-nettoyage)
**Et** les tokens portent désormais un claim **`jti`** (identifiant unique, `uuid4`)
**Et** `POST /v1/auth/refresh` **rejette `401`** un refresh token blocklisté (vérification de la blocklist avant émission d'un nouvel access token)
**Et** la révocation **dégrade proprement si Redis est down** (cohérent avec AC2 : log + comportement défini — voir Décision PL ci-dessous), sans crasher le logout
**Et** l'access token court (30 min) expire naturellement → pas de blocklist d'access token requise pour la beta

> **✅ DÉCISION PL TRANCHÉE (2026-06-19) — Option A retenue : blocklist refresh-token `jti` via Redis.**
> Révocation effective au logout ; l'access résiduel (≤30 min) expire seul. `POST /logout` + claim `jti` + helper Redis + check au `/refresh`. **Dépend de Redis** → fail-open cohérent avec AC2 : si Redis down au refresh, on **laisse passer** (risque résiduel accepté pour la beta, loggé). Implémenter AC3 tel quel (T3 ci-dessous).

## Tasks / Subtasks

- [ ] **T1 — Migration `python-jose` → `PyJWT`** (AC1)
  - [ ] T1.1 — `pyproject.toml` : retirer `python-jose = {...}`, ajouter `pyjwt = ">=2.8.0"` (HS256 = HMAC, **pas besoin** de l'extra `[crypto]`). Lancer `poetry lock` / mettre à jour le `.venv` local.
  - [ ] T1.2 — `app/core/security.py` : `from jose import JWTError, jwt` → `import jwt`. `jwt.encode(payload, key, algorithm="HS256")` (PyJWT ≥2 renvoie déjà un `str`). `jwt.decode(token, key, algorithms=["HS256"])` (inchangé). `exp` en `datetime` reste supporté par PyJWT.
  - [ ] T1.3 — Préserver le contrat `JWTError` : ré-exporter `JWTError = jwt.PyJWTError` (classe de base PyJWT, parent de `ExpiredSignatureError`/`InvalidTokenError`) dans `__all__`, pour que `except JWTError` dans `deps.py:89` et `auth.py:63` catche expiré **et** invalide.
  - [ ] T1.4 — Vérifier qu'aucun autre fichier n'importe `jose` (`grep -rn "jose" app/` → seul `security.py`).
- [ ] **T2 — Rate-limiter fail-open** (AC2)
  - [ ] T2.1 — `app/core/limiter.py` : ajouter `swallow_errors=True` au `Limiter(...)` → slowapi avale les erreurs du backend de stockage (Redis down) et fail-open au lieu de lever (500). Conserver `key_func=get_client_ip`, `storage_uri=settings.redis_url`.
  - [ ] T2.2 — S'assurer qu'un warning est émis quand le backend échoue (slowapi logge déjà via son logger quand `swallow_errors` ; sinon ajouter un handler/log). Ne PAS masquer totalement.
  - [ ] T2.3 — Vérifier la non-régression Redis-up : le `@limiter.limit("5/minute")` bloque toujours au 6ᵉ login/min.
- [ ] **T3 — Révocation JWT au logout** (AC3, si Option A retenue)
  - [ ] T3.1 — `app/core/security.py` : ajouter `"jti": str(uuid.uuid4())` aux payloads de `create_access_token`/`create_refresh_token`. Exposer un helper pour relire `jti`/`exp` d'un token décodé.
  - [ ] T3.2 — Blocklist Redis : helper `revoke_token(jti, ttl_seconds)` + `is_revoked(jti)` (clé `revoked:jti:{jti}`, `SETEX` TTL = `exp - now`). Réutiliser une connexion Redis (cf. `redis_url`) — vérifier s'il existe déjà un client Redis partagé (ARQ/limiter) avant d'en créer un.
  - [ ] T3.3 — `app/api/v1/auth.py` : `POST /logout` (`Depends(get_current_user)`) qui lit le refresh token du body, le décode, blocklist son `jti` (TTL résiduel). Dégradation si Redis down : log + `200` quand même (le client jette ses tokens de toute façon).
  - [ ] T3.4 — `POST /refresh` : après décodage du refresh token, **rejeter `401`** si `is_revoked(jti)`. Fail-open si Redis down (log + continuer), cohérent avec AC2.
- [ ] **T4 — Tests** (AC1–AC3)
  - [ ] T4.1 — `tests/core/test_security.py` (ou étendre `test_auth.py`) : round-trip encode/decode PyJWT ; token expiré → `JWTError` ; signature invalide → `JWTError` ; claim `type` préservé.
  - [ ] T4.2 — `tests/core/test_limiter_failopen.py` : simuler un backend de stockage qui lève (monkeypatch) → l'endpoint rate-limité renvoie **non-500** (fail-open). Vérifier Redis-up → 429 au dépassement inchangé.
  - [ ] T4.3 — (Option A) `tests/api/test_logout_revocation.py` : logout blocklist le jti ; refresh d'un token révoqué → `401` ; Redis down → logout `200` gracieux + refresh fail-open.
  - [ ] T4.4 — Suite complète verte ; confirmer que les ~16 rouges Redis-local **disparaissent** grâce à T2.1.

## Dev Notes

### État réel du code (source de vérité — vérifié 2026-06-19)

- **`app/core/security.py`** (51 lignes) : `from jose import JWTError, jwt`. 4 sites jose : `jwt.encode` (×2, l.25/33), `jwt.decode` (l.40), import `JWTError` (l.3). `create_access_token`/`create_refresh_token` posent `{"sub", "type", "exp"}`. `decode_token` ne valide PAS le `type` (les appelants le font : `deps.py:87`, `auth.py:61`). `ACCESS_TOKEN_EXPIRE_MINUTES=30`, `REFRESH_TOKEN_EXPIRE_DAYS=30`.
- **`app/core/limiter.py`** (14 lignes) : `Limiter(key_func=get_client_ip, storage_uri=settings.redis_url)` — instancié au niveau module. `get_client_ip` lit `X-Forwarded-For` puis `request.client.host`. **Pas de `swallow_errors`** → toute erreur Redis remonte en 500.
- **`app/api/v1/auth.py`** : `@limiter.limit("5/minute")` sur `login` (l.34), `@limiter.limit("3/minute")` sur `delete_account` (l.139). **Aucun endpoint `/logout`** aujourd'hui (logout = client-side, jette les tokens). `register` renvoie `403` (fermé). `refresh` (l.57-95) décode, vérifie `type=="refresh"`, ré-émet un access (garde le même refresh).
- **`app/deps.py`** : `get_current_user` (l.67) décode le Bearer, vérifie `type=="access"`, peuple `request.state.user_id` (utilisé par les limiters per-route Story 7.2). Importe `JWTError` depuis security.
- **`conftest.py`** : pose `REDIS_URL`, `SECRET_KEY`, `REVENUECAT_WEBHOOK_SECRET` via `os.environ.setdefault` AVANT le `Settings()` module-level (l.8-15). `environment` défaut `development` → la validation prod de `config.py` ne fait que `logger.warning`. C'est pourquoi les tests bootent malgré un `SECRET_KEY` court.

### Détails PyJWT (migration AC1)

- Package `PyJWT` (import `jwt`). `jwt.encode(payload, key, algorithm="HS256")` renvoie un `str` (PyJWT ≥2.0). `jwt.decode(token, key, algorithms=["HS256"])` renvoie un `dict`.
- Exceptions : base `jwt.PyJWTError` ; `jwt.ExpiredSignatureError` (token expiré) et `jwt.InvalidTokenError` en héritent. → `JWTError = jwt.PyJWTError` couvre les deux cas catchés aujourd'hui.
- `exp` en `datetime` (aware UTC) est accepté tel quel par PyJWT (converti en timestamp). Pas de changement de payload nécessaire.
- HS256 est du HMAC pur → **pas besoin** du package `cryptography` ni de l'extra `pyjwt[crypto]` (réservé RS/ES/EdDSA).
- ⚠️ Le `.venv` local doit conserver `bcrypt>=3.2.0,<4.0.0` (passlib 1.7.4) — ne pas y toucher en mettant à jour les deps.

### slowapi fail-open (AC2)

- `slowapi.Limiter` accepte `swallow_errors: bool`. À `True`, les erreurs levées par le backend de stockage (Redis injoignable via `limits`/`coredis`) sont avalées et la requête **passe** (fail-open) au lieu de 500. C'est le levier idiomatique attendu.
- Effet de bord **souhaité** : les ~16 tests rouges locaux échouent aujourd'hui parce que slowapi tente `incr` sur Redis localhost:6379 (refusé) AVANT le handler. Avec `swallow_errors=True`, ces appels no-op → tests verts sans Redis. Mentionner ce gain dans les Completion Notes.
- Garder l'observabilité : ne pas masquer l'incident en silence — vérifier que slowapi logge, sinon wrapper.

### Révocation JWT (AC3, Option A)

- Schéma minimal beta : claim `jti` (uuid4) sur chaque token + blocklist Redis `revoked:jti:{jti}` posée au logout avec `SETEX ttl=(exp-now)`. `refresh` consulte la blocklist avant ré-émission.
- Cohérence fail-open : la blocklist dépend de Redis ; si Redis est down au refresh, on **laisse passer** (log) — même politique que AC2. On accepte ce risque résiduel pour la beta (documenté). Un fail-closed ici recréerait le point de défaillance que AC2 supprime.
- Vérifier l'existence d'un client Redis partagé avant d'en ouvrir un nouveau (ARQ utilise `redis_url` ; le limiter aussi via `limits`). Réutiliser/centraliser si possible.
- L'access token (30 min) n'est PAS blocklisté (coût/bénéfice défavorable en beta) — sa courte durée borne la fenêtre d'exploitation.

### Réutilisation — ne PAS réinventer

- **NE PAS** retoucher `config.py` (validation secrets déjà complète, Story 7.3) ni `docker-compose.prod.yml` (ports déjà fermés).
- **NE PAS** changer la signature de `create_access_token`/`create_refresh_token` (prennent `user_id: str`) au-delà de l'ajout interne du `jti`.
- Conventions : wrapper `{ "data": ... }` sur les réponses ; `HTTPException(detail={"code","message"})` ; `logger` jamais `print()` ; imports au niveau module.
- Tests : pytest + `asyncio_mode="auto"` (pas de décorateur) ; fixtures globales `client`/`mock_db` dans `conftest.py` (NE PAS recréer) ; ne pas dépendre d'un vrai Redis/Anthropic.

### Pattern de tests (rappels, vérifiés)

- `tests/conftest.py` fournit `client` (httpx `AsyncClient` + `ASGITransport`, override `get_db`) et `mock_db` (`AsyncMock`).
- Pour AC2 : monkeypatcher le storage du limiter pour lever, ou pointer `storage_uri` sur un Redis injoignable et asserter non-500.
- Pour AC3 : mocker le client Redis blocklist (`AsyncMock`), vérifier `SETEX` appelé au logout et la consultation au refresh ; simuler Redis down (exception) pour la dégradation.

### Project Structure Notes

**Fichiers à modifier (UPDATE) :**
| Fichier | Modification |
|---------|-------------|
| `pyproject.toml` | `-python-jose`, `+pyjwt>=2.8.0` |
| `app/core/security.py` | jose→PyJWT ; `JWTError=jwt.PyJWTError` ; claim `jti` ; helper blocklist (AC3) |
| `app/core/limiter.py` | `+swallow_errors=True` |
| `app/api/v1/auth.py` | `+POST /logout` ; check blocklist dans `/refresh` (AC3) |

**Fichiers à créer (NEW) :**
```
collega_backend/tests/core/test_security.py            ← round-trip PyJWT, expiré/invalide
collega_backend/tests/core/test_limiter_failopen.py    ← fail-open Redis down
collega_backend/tests/api/test_logout_revocation.py    ← AC3 (si Option A)
```
(+ éventuel `app/core/redis_blocklist.py` si un module helper est plus propre que d'alourdir `security.py`.)

### Library / Framework

- **PyJWT** `>=2.8.0` (latest 2.x). Remplace `python-jose` (CVE-2024-33663/33664). HS256, API `jwt.encode`/`jwt.decode` quasi identique.
- **slowapi** `>=0.1.9` (déjà présent) — `swallow_errors=True`.
- **redis** : client Redis async (vérifier la version déjà tirée par ARQ/`arq`) pour la blocklist AC3.
- Aucune autre nouvelle dépendance. `bcrypt<4.0.0` inchangé.

### Git Intelligence

Dernier commit : `ce7522c feat(story-7.8): dashboard admin thème C (qualité & coût) + review-fix`. Épic 7 suit `feat(story-7.x): … + review-fix`. Cette story = hardening additif backend, à committer seule.

### References

- Source des items : `_bmad-output/implementation-artifacts/deferred-work.md` (revues 1.1, 1.5 W1, 2.3, 3.3, 5.1 W1).
- CVE python-jose : CVE-2024-33663 (algorithm confusion), CVE-2024-33664 (JWE DoS).
- Fichiers : `app/core/security.py`, `app/core/limiter.py`, `app/api/v1/auth.py`, `app/deps.py`, `app/core/config.py` (réf. non-régression), `docker-compose.prod.yml` (réf. ports), `tests/conftest.py`.

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

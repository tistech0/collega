# Chantier 2 — Sécurité : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** PyJWT avec `jti`/`tv`, rotation des refresh tokens avec détection de réutilisation, logout serveur, reset de mot de passe admin, IP client fiable, nouvelles limites, webhook authentifié avant parsing et ordonné, `ENVIRONMENT` obligatoire, journaux sans données sensibles ; app : stockage du nouveau refresh et logout serveur.

**Architecture:** révocation dans Redis (clés `revoked:jti:*`, `refresh:grace:*`) via un petit module `app/core/token_store.py` tolérant aux pannes (fail-open journalisé) ; `users.token_version` pour couper toutes les sessions d'un compte. S'appuie sur le chantier 5 (`AppError` et fabriques dans `app/core/errors.py`, paquets `app/api/v1/admin/`, `app/api/v1/colleges/`).

**Tech Stack:** FastAPI, PyJWT, redis.asyncio, slowapi/limits, SQLAlchemy/Alembic, Flutter (Dio, flutter_secure_storage).

**Spec:** `_bmad-output/planning-artifacts/chantier-2-securite-spec.md`

## Global Constraints

- Migration du chantier : **020** (`020_token_version_subscription_event_at.py`, `down_revision` = identifiant réel de la 019) : `users.token_version INT NOT NULL DEFAULT 0`, `users.subscription_event_at TIMESTAMPTZ NULL`.
- HS256 inchangé ; access 30 min, refresh 30 jours ; `security.JWTError` reste exporté (= `jwt.PyJWTError`).
- Grâce de rotation : 120 s (portée de 60 à 120 s par la revue finale, I4). Mot de passe provisoire : 16 caractères via `secrets.token_urlsafe` (tronqué à 16), jamais journalisé.
- Limites : login 5/min/IP (inchangé) ; `/v1/auth/refresh` 30/min/IP ; échecs d'auth admin 10/min/IP ; `/v1/drill/evaluate-semantic` 30/min/utilisatrice ; régénération de fiche 10/h/utilisatrice. `max_length=2000` sur `user_answer` et `user_note`.
- Redis indisponible : vérification de révocation → on laisse passer + warning ; révocation (logout/rotation) → warning, la réponse n'échoue pas ; limiteur `swallow_errors=True`.
- `ENVIRONMENT` ∈ {`development`, `production`, `test`}, obligatoire.
- Erreurs au format `{"detail": {"code", "message"}}` via `AppError`.
- Tests : unitaires (SQLite/mocks) + Postgres + **Redis réel** (`redis-test`, `127.0.0.1:56379`, URL surchargeable par `TEST_REDIS_URL`).

---

### Task 1: PyJWT, `jti`/`tv`, `token_version` (§ 2 « Jetons », migration 020)

**Files:** `pyproject.toml`/`poetry.lock` (retirer `python-jose`, ajouter `pyjwt = "^2.10"`), `app/core/security.py`, `app/models/user.py`, `alembic/versions/020_…py`, `app/deps.py` (`get_current_user`, `get_current_user_short_session`), tests `tests/core/test_security.py`, `tests/api/test_auth.py`.

```python
# app/core/security.py
from jwt import PyJWTError as JWTError
def create_access_token(user_id: str, token_version: int = 0) -> str   # claims: sub, type="access", exp, jti=uuid4().hex, tv
def create_refresh_token(user_id: str, token_version: int = 0) -> str  # claims: sub, type="refresh", exp, jti, tv
def decode_token(token: str) -> dict                                   # jwt.decode(..., algorithms=["HS256"]) ; lève JWTError
def token_version_ok(payload: dict, current_version: int) -> bool      # "tv" absent → current_version == 0 ; sinon payload["tv"] >= current_version
```
- `get_current_user` : après lecture du user, `if not token_version_ok(payload, user.token_version)` → 401 `TOKEN_REVOKED`.
- Login et refresh émettent avec `user.token_version`.
- Tests : jeton créé → `jti` (32 hex) et `tv` présents ; expiré → `JWTError` ; signature invalide → `JWTError` ; `token_version_ok` (sans tv + version 0 → vrai ; sans tv + version 1 → faux ; tv 1 < version 2 → faux) ; route protégée avec `tv` périmé → 401 `TOKEN_REVOKED`.
- [ ] TDD ; suite verte ; `pip-audit` ne signale plus `ecdsa` ; commit.

### Task 2: Rotation du refresh, logout, reset-password admin (§ 2, § 3)

**Files:** Create `app/core/token_store.py`, `tests/core/test_token_store.py` (Redis réel), `tests/api/test_auth_rotation_pg.py` ; Modify `app/api/v1/auth.py`, `app/schemas/auth.py` (`LogoutRequest {refresh_token: str | None}`), `app/api/v1/admin/users.py`, `app/schemas/admin.py`, `app/static/admin/index.html`, `tests/conftest.py`.

```python
# app/core/token_store.py — client redis.asyncio paresseux (settings.redis_url), remplaçable en test
GRACE_S = 120
async def revoke_refresh(jti: str, ttl_s: int) -> None        # SET revoked:jti:{jti} 1 EX ttl ; SET refresh:grace:{jti} 1 EX 120 (rotation seulement, jamais au logout) ; erreur Redis → warning
async def refresh_state(jti: str) -> Literal["active", "grace", "reused"]  # erreur Redis → warning + "active"
def set_client_for_tests(client) -> None
```
- `POST /v1/auth/refresh` (algorithme exact de la spec § 2) : décode, `type == "refresh"`, `tv` ok sinon 401 `TOKEN_REVOKED` ; si le jeton porte un `jti` : `reused` → `UPDATE users SET token_version = token_version + 1`, commit, 401 `TOKEN_REUSED`, warning (sans jeton) ; `active` → `revoke_refresh(jti, ttl = exp - now)` ; `grace` → pas de nouvelle révocation ; puis nouveau couple access + refresh. Jeton ancien sans `jti` : `jti` dérivé de l'empreinte de sa partie signée (revue finale, I2), même rotation / grâce / révocation.
- `POST /v1/auth/logout` (access token requis, 204, idempotent) : si `refresh_token` fourni, décodé et `sub == user.id` → `revoke_refresh` ; `user.apns_token = None` ; commit.
- `POST /v1/admin/users/{id}/reset-password` → `{"data": {"temporary_password": "..."}}` ; hache, `token_version += 1`, commit ; 404 `USER_NOT_FOUND`. Console : bouton « Réinitialiser le mot de passe » sur la fiche utilisatrice (confirmation), boîte avec le mot de passe et bouton Copier.
- Login à temps constant : `_DUMMY_HASH = hash_password(secrets.token_urlsafe(16))` calculé une fois ; e-mail inconnu → `verify_password(body.password, _DUMMY_HASH)` avant le 401.
- Tests pg + Redis réel : rotation → nouveau couple, ancien refresh accepté dans les 120 s (grace), refusé ensuite (supprimer la clé grace pour simuler l'expiration) avec `token_version` incrémentée et 401 `TOKEN_REUSED`, puis l'access token émis avant → 401 `TOKEN_REVOKED` ; jeton sans `tv` accepté tant que version 0 ; logout : refresh révoqué (refresh ensuite → `TOKEN_REUSED` hors grâce), `apns_token` effacé, 2e appel 204 ; Redis coupé (client pointant sur un port fermé) : refresh et login passent, warning dans `caplog` ; reset-password : le mot de passe provisoire permet le login, l'ancien refresh → 401.
- [ ] TDD ; suite verte ; commit.

### Task 3: IP client, limites, tailles (§ 4)

**Files:** `app/core/limiter.py`, `app/core/config.py` (`trusted_proxy_ips: list[str] = ["172.16.0.0/12"]`, lu depuis une variable `TRUSTED_PROXY_IPS` séparée par des virgules), `app/deps.py` (`get_admin_user`), `app/api/v1/auth.py` (refresh), `app/api/v1/drill.py`, `app/api/v1/flash_cards.py`, `app/schemas/*` (`max_length`), `tests/core/test_client_ip.py`, tests API.

- `get_client_ip(request)` exactement selon la spec § 4 (`ipaddress.ip_address(request.client.host) in ip_network(...)` ; `CF-Connecting-IP` si proxy de confiance ; sinon **dernier** élément de `X-Forwarded-For` si proxy de confiance ; sinon `request.client.host` ; jamais le premier élément).
- `limiter = Limiter(key_func=get_client_ip, storage_uri=…, swallow_errors=True)` ; warning journalisé sur erreur de stockage si slowapi le permet (sinon documenté).
- Admin : seuls les **échecs** d'authentification comptent (10/min/IP) — `limits` `MovingWindowRateLimiter`/`FixedWindow` sur le stockage du limiteur : `limiter.limiter.hit(parse("10/minute"), "admin-auth", ip)` à chaque échec ; si le compteur est déjà épuisé → 429 `RATE_LIMITED` avant même de comparer les identifiants. 401 inchangé sinon (en-tête `WWW-Authenticate: Basic`).
- `/v1/auth/refresh` : `@limiter.limit("30/minute")` (clé IP). `/v1/drill/evaluate-semantic` : `30/minute` avec `key_func` = id utilisatrice (même approche que `search._user_id_key`). Régénération : `10/hour` par utilisatrice.
- `max_length=2000` : `SemanticEvalRequest.user_answer`, `RegenerateRequest.user_note` (noms réels à vérifier) → 422 `VALIDATION_ERROR` au-delà.
- Tests : tous les cas d'en-têtes/proxies de `get_client_ip` ; 11e échec admin → 429 ; admin authentifié 20 fois de suite → jamais 429 ; limites refresh/drill/régénération (dépassement → 429 `RATE_LIMITED`, clé par utilisatrice : une autre utilisatrice n'est pas bloquée) ; `max_length`.
- [ ] TDD ; suite verte ; commit.

### Task 4: Webhook RevenueCat, `ENVIRONMENT`, journaux (§ 5, § 6)

**Files:** `app/api/v1/billing.py`, `app/schemas/billing.py` (`event_timestamp_ms: int | None = None` dans l'événement), `app/models/user.py` (`subscription_event_at`), `app/core/config.py`, `.env.example`, `tests/conftest.py` (`ENVIRONMENT=test`), `app/api/v1/search.py`, logs d'upload (`app/api/v1/colleges/imports.py`, `app/services/upload/chunked_upload.py`, workers de nettoyage), `tests/api/test_billing_webhook.py`, `tests/core/test_config_validators.py`.

- Webhook : la route prend `request: Request` ; vérifie `Authorization` d'abord (401 `INVALID_SIGNATURE`), puis `RevenueCatWebhookPayload.model_validate_json(await request.body())` → erreur → 422 `VALIDATION_ERROR`. Ordre : si `event_timestamp_ms` présent et `user.subscription_event_at` non nul et événement antérieur → `{"data": {"status": "stale"}}` sans modification ; sinon appliqué et `subscription_event_at` = horodatage de l'événement. Sans horodatage : appliqué, `subscription_event_at` inchangé.
- `environment: Literal["development", "production", "test"]` sans valeur par défaut : absent ou hors liste → `ValidationError` au démarrage (le warning « Unknown ENVIRONMENT » disparaît). Vérifier le `.env` local de développement (ajout de `ENVIRONMENT=development` seulement s'il manque, sans afficher le fichier).
- Journaux : `search.py` ne logue plus `q` (garde l'id utilisatrice et le nombre de résultats) ; `upload_id` remplacé par `upload_ref(upload_id) = sha256(upload_id)[:8]` dans tous les logs.
- Tests : 401 sans secret même avec un corps invalide ; secret + corps invalide → 422 `VALIDATION_ERROR` ; événement ancien → `stale` et abonnement inchangé ; événement récent appliqué ; sans horodatage appliqué ; config sans `ENVIRONMENT` → erreur ; `ENVIRONMENT=prod` → erreur ; aucun log ne contient le terme cherché ni l'`upload_id` en clair (`caplog`).
- [ ] TDD ; suite verte ; commit.

### Task 5: App — rotation et logout (§ 8)

**Files:** `collega_app/lib/core/network/api_client.dart`, `collega_app/lib/features/auth/data/auth_repository.dart`, tests `collega_app/test/core/network/…`, `collega_app/test/features/auth/auth_repository_test.dart`.

- `_tryRefresh` : écrit aussi `refresh_token` de la réponse s'il est présent et non vide.
- `logout()` : appelle `POST /v1/auth/logout` avec `{"refresh_token": <stocké>}` (timeout court, toute erreur ignorée et journalisée), puis efface le stockage **dans tous les cas** (l'effacement reste la dernière étape, même si l'appel échoue ou lève).
- Tests : refresh réussi → les deux jetons stockés ; logout avec API OK → appel fait + stockage vidé ; API en erreur/timeout → stockage vidé quand même.
- `flutter analyze` propre ; `flutter test test/core` et `flutter test test/features/auth` verts.
- [ ] Commit.

### Task 6: Documents (§ 9) et Cloudflare (§ 7)

- `collega_app/assets/legal/privacy.md` : jeton APNs supprimé à la déconnexion (vrai désormais), limites de débit (connexion, renouvellement), conservation des journaux = rotation Docker 3 × 50 Mo (quelques jours à quelques semaines) ; `**Version : 2026-09-25**` (date du jour de l'implémentation).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` : 7.10 → `done` (absorbée par le chantier 2), 7.9 → `abandoned` (remplacée par Cloudflare Access).
- `collega_backend/docs/deployment.md` : section « Console admin : Cloudflare Access » avec les étapes guidées de la spec § 7 (application `collega-admin`, destinations `/admin` et `/v1/admin`, policy Allow e-mail `contact@matthislesur.com`, One-time PIN) et la vérification `curl --resolve`.
- [ ] Commit.

### Task 7: Revue, déploiement conjoint, vérifications (§ 11)

- [ ] Revue indépendante ; corrections.
- [ ] `deploy.sh` (migration 020) ; build iPhone si l'appareil est branché (`flutter devices` → `00008110-000115D43499801E`, puis `collega_app/tool/run_device.sh --release -d 00008110-000115D43499801E`).
- [ ] Vérifications prod : login, refresh (rotation : un refresh réutilisé hors grâce → 401 `TOKEN_REUSED`, sur un compte de test créé par l'admin puis supprimé), logout 204, `/admin` depuis l'extérieur (reste 302 Access tant que l'utilisatrice n'a pas créé l'application — normal), webhook RevenueCat de test avec le secret lu **sur le NAS** (jamais affiché) : corps sans horodatage pour un compte de test → 200.

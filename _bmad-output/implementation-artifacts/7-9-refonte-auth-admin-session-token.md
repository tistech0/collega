# Story 7.9 : Refonte Auth Console Admin — Session-Token (cookie httpOnly)

Status: backlog

<!-- DIFFÉRÉ post-beta — décision PL 2026-06-17. Risque accepté en l'état (cf. origine ci-dessous). Story contextée, prête à être prise en dernier. -->

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **Project Lead / admin**,
je veux que la console admin web s'authentifie via un **session-token en cookie httpOnly** (plutôt que de garder les identifiants HTTP Basic en mémoire JavaScript),
afin qu'un éventuel futur XSS ne puisse plus exfiltrer les identifiants admin, et que la session expire proprement.

## Origine & contexte (à lire avant de coder)

Story issue de l'**item 6 de la code review de la Story 7.6** (2026-06-17). Lors de la livraison de la console admin (7.6), l'auth réutilise le pattern HTTP Basic de l'interface testeur : la console garde `creds = {username, password}` en variable JS et renvoie le header `Authorization: Basic …` à chaque requête (`app/static/admin/index.html`). 

**Risque identifié (accepté pour la beta) :** les identifiants admin résident en clair en mémoire navigateur et sont exfiltrables par un XSS. Le vecteur XSS concret a été **fermé** en review 7.6 (échappement de l'email + helper `escapeHtml`), donc le risque résiduel est modéré : outil **admin-only**, **un seul compte** statique, HTTPS en prod. C'est pourquoi cette refonte a été **différée post-beta** (décision PL 2026-06-17) plutôt que faite dans 7.6.

**Bénéfice de la refonte :** cookie **httpOnly** illisible même par un futur XSS + **expiration de session** + **logout serveur** réel.

**Découverte d'architecture (vérifiée) :** l'app a déjà une **infra JWT** réutilisable :
- `app/core/security.py` : `create_access_token(user_id)` / `decode_token(token)` (HS256, signé via `settings.secret_key`, `exp` géré). Pattern token `{"sub": ..., "type": "access"|"refresh", "exp": ...}`.
- `app/deps.py` : `get_admin_user` (Basic, `secrets.compare_digest` timing-safe) protège **toutes** les routes `/v1/admin/*`. Credentials statiques `settings.admin_username` / `settings.admin_password` (`app/core/config.py`).
- Le pattern Bearer existe déjà côté users (`get_current_user`).

## Acceptance Criteria

### AC1 — Login admin émet un session-token en cookie httpOnly

**Étant donné** un admin qui poste ses identifiants valides sur `POST /v1/admin/login`,
**Alors** le serveur vérifie les creds (réutilise la comparaison timing-safe existante), émet un token de session signé (réutilise l'infra `security.py`, type dédié ex. `"admin_session"`, expiration courte type 8 h),
**Et** le pose en cookie **`HttpOnly` + `Secure` + `SameSite=Strict`** (chemin `/v1/admin` ou `/`),
**Et** ne renvoie jamais le token dans le corps de réponse JSON.
**Et** des identifiants invalides → 401 sans cookie.

### AC2 — Les routes admin acceptent le cookie de session

**Étant donné** une requête vers une route `/v1/admin/*` portant un cookie de session valide,
**Alors** une nouvelle dépendance `get_admin_session` valide le token du cookie (signature + `exp` + `type`) et autorise l'accès.
**Et** un cookie absent/expiré/invalide → 401.
**Décision à acter (T0) :** soit `get_admin_session` **remplace** `get_admin_user` partout, soit on **conserve Basic en parallèle** pour l'accès API/curl. Recommandation par défaut : conserver Basic pour l'usage machine + cookie pour la console (les deux dépendances acceptées). Documenter le choix.

### AC3 — Logout invalide la session

**Étant donné** `POST /v1/admin/logout`,
**Alors** le cookie de session est purgé (Set-Cookie expiré),
**Et** les requêtes suivantes sans nouveau login → 401.
(Invalidation côté serveur : si stateless JWT, l'expiration courte suffit pour la beta ; une denylist est hors périmètre sauf besoin explicite.)

### AC4 — Protection CSRF

**Étant donné** que l'auth passe désormais par cookie (envoyé automatiquement par le navigateur),
**Alors** une protection CSRF est en place : **`SameSite=Strict`** sur le cookie de session (mitigation principale),
**Et** pour les mutations (`POST`/`PATCH`), soit on s'appuie sur `SameSite=Strict` documenté comme suffisant pour cet outil interne, soit on ajoute un **token CSRF** (double-submit) si le contexte l'exige. Acter le niveau retenu en T0.

### AC5 — Console web migrée vers le cookie

**Étant donné** la console `app/static/admin/index.html`,
**Alors** `creds` / `basicHeader()` sont **supprimés** ; le login poste sur `/v1/admin/login` (avec `credentials: "same-origin"`), et `apiFetch` n'envoie plus de header `Authorization` (le cookie est automatique),
**Et** `handleUnauthorized()` (déjà présent) redirige vers le login sur 401,
**Et** le bouton logout appelle `/v1/admin/logout`,
**Et** aucun identifiant ni token n'est stocké en variable JS / localStorage / sessionStorage.

### AC6 — Tests & non-régression

**Étant donné** la suite de tests admin,
**Alors** sont ajoutés : login OK (cookie posé) / login KO (401) / accès route avec cookie valide / accès refusé sans cookie / cookie expiré / logout puis accès refusé,
**Et** les tests admin existants sont adaptés au mécanisme retenu (cookie, et/ou Basic si conservé),
**Et** `POST /v1/auth/register` reste **403** (non-régression sécurité), et la suite passe (hors échecs environnementaux Redis connus).

## Tasks / Subtasks

- [ ] **T0 — Décisions d'architecture (à acter avant de coder)** (AC: #2, #4)
  - [ ] Cookie vs Basic : remplacer `get_admin_user` OU cohabiter (recommandé : cohabiter). Documenter.
  - [ ] Niveau CSRF : `SameSite=Strict` seul vs + token double-submit. Documenter.
  - [ ] Durée d'expiration session admin (défaut proposé : 8 h).
- [ ] **T1 — Token de session admin** `app/core/security.py` (AC: #1)
  - [ ] Helper `create_admin_session_token()` (type `"admin_session"`, `exp` courte) réutilisant `jwt.encode` + `settings.secret_key`.
  - [ ] Validation via `decode_token` + check `type == "admin_session"`.
- [ ] **T2 — Endpoints login/logout** `app/api/v1/admin.py` (AC: #1, #3)
  - [ ] `POST /v1/admin/login` : vérifie creds (extraire la comparaison timing-safe de `get_admin_user` dans un helper partagé), pose le cookie httpOnly+Secure+SameSite=Strict, 401 si KO.
  - [ ] `POST /v1/admin/logout` : Set-Cookie expiré.
- [ ] **T3 — Dépendance `get_admin_session`** `app/deps.py` (AC: #2)
  - [ ] Lit le cookie de session, valide signature/exp/type → 401 sinon.
  - [ ] Appliquer aux routes `/v1/admin/*` selon décision T0 (remplacement ou ajout).
- [ ] **T4 — CSRF** (AC: #4)
  - [ ] Implémenter le niveau retenu en T0 (SameSite=Strict documenté, ou token double-submit + vérif côté endpoints mutateurs).
- [ ] **T5 — Migration console web** `app/static/admin/index.html` (AC: #5)
  - [ ] Supprimer `creds`/`basicHeader` ; login → `POST /v1/admin/login` (`credentials:"same-origin"`).
  - [ ] `apiFetch` sans header `Authorization` ; conserver le `try/catch` + sentinelle 401 déjà en place.
  - [ ] Logout → `POST /v1/admin/logout`.
- [ ] **T6 — Tests** `tests/api/` (AC: #6)
  - [ ] Login OK/KO, accès avec/sans cookie, cookie expiré, logout→401.
  - [ ] Adapter `test_admin_*` au mécanisme retenu (httpx supporte les cookies via le client).
  - [ ] Conserver le test de non-régression `register` 403.

## Dev Notes

### État actuel des fichiers à modifier (à préserver)

- `app/deps.py` — `get_admin_user` (Basic, `secrets.compare_digest`) protège tout `/v1/admin/*`. **NE PAS casser** `get_tester_user` (interface testeur en Basic, hors périmètre) ni `get_current_user` (Bearer users).
- `app/core/security.py` — `create_access_token`/`create_refresh_token`/`decode_token` (HS256, `settings.secret_key`). Réutiliser ce module, ne pas réinventer la signature JWT.
- `app/core/config.py` — `admin_username`/`admin_password` (+ validation placeholder). `secret_key` déjà présent et validé.
- `app/static/admin/index.html` — la review 7.6 a déjà ajouté : `apiFetch` robuste (catch réseau, sentinelle 401, `readJson`), `escapeHtml` sur l'email, `handleUnauthorized()`. **Réutiliser** ces helpers, retirer uniquement la partie creds/Basic.
- `app/api/v1/admin.py` — 4 routes 7.6 + routes 1.4. Ajouter login/logout sans toucher la logique métier existante.

### Sécurité / pièges

- Cookie : `HttpOnly` (anti-XSS), `Secure` (HTTPS prod), `SameSite=Strict` (anti-CSRF). En dev local sans HTTPS, prévoir un flag conditionnel pour `Secure` (ne pas bloquer le dev).
- Ne **jamais** réactiver le register public (reste 403 par design — cf. mémoire sécurité projet).
- `secrets.compare_digest` pour la comparaison des creds (déjà le cas, à conserver dans le helper partagé).
- Garder `WWW-Authenticate: Basic` **uniquement** si Basic est conservé pour l'API ; la console ne doit pas déclencher la popup native du navigateur (cf. note `get_tester_user`).

### Testing

- Pattern de tests existant : `ADMIN_AUTH = ("admin", "testpass")`, fixtures `client`/`mock_db`, `AsyncMock`/`MagicMock`. Le `AsyncClient` httpx gère les cookies → tester le flux login→appel→logout sur le même client.
- Échecs environnementaux connus (Redis non lancé en local + tests `register` attendant 422 vs 403-par-design) : ne pas les confondre avec des régressions.

### Project Structure Notes

- Backend FastAPI + HTML statique (Basic Auth aujourd'hui) — cf. `architecture.md:110`. Cette story fait évoluer l'auth de la console admin uniquement ; l'interface testeur (`/tester`) reste en Basic (hors périmètre).

### References

- [Source: code review Story 7.6, item 6 — `_bmad-output/implementation-artifacts/7-6-dashboard-admin-onboarding-users.md#Review-Findings`]
- [Source: `collega_backend/app/deps.py` — `get_admin_user`, `get_current_user`]
- [Source: `collega_backend/app/core/security.py` — infra JWT HS256]
- [Source: `collega_backend/app/static/admin/index.html` — `apiFetch`/`handleUnauthorized`/`escapeHtml` (post-review 7.6)]
- [Source: mémoire projet — register 403 par design ; `/docs` désactivé]

## Dev Agent Record

### Agent Model Used

### Debug Log References

### Completion Notes List

### File List

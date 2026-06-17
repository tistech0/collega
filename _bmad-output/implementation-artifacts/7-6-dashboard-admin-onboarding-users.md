# Story 7.6 : Dashboard Admin — Onboarding & Gestion Users (Thème A)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **Project Lead / admin**,
je veux créer et gérer les comptes utilisateurs depuis une console admin web avec un overview KPI d'entrée,
afin d'onboarder une testeuse sur une base prod wipée (où `register` = 403) et d'avoir un point d'entrée unique sans toucher à `psql`.

## Contexte & périmètre (à lire avant de coder)

Story 7.6 est le **socle (Thème A)** du Dashboard Admin acté le 2026-06-16 (`correct-course`, source brainstorm `brainstorming-session-2026-06-16-2242.md`). Elle est le **hard-blocker de l'onboarding** : sans `create-user` admin, impossible d'inviter la testeuse car `POST /v1/auth/register` renvoie 403 par design.

**Thèmes B (7.7 — suivi/contrôle imports) et C (7.8 — qualité/coût) sont HORS périmètre de cette story.** Ne PAS implémenter ici : timeline persistée, stop/delete job, détail brut job, conso tokens, inspection fiches, vue feedback. Cette story se limite strictement à : **create-user, toggle beta (existe déjà), liste users (existe déjà), détail user (NEW), reset quota (NEW), overview KPI (NEW) + la vue web admin** qui pilote ces actions.

**Découverte critique d'architecture :** l'epic référence « réutilise le pattern de l'interface admin web Phase 0, Story 1.4 ». **Cette vue web admin n'existe pas.** La Story 1.4 a livré **uniquement des endpoints JSON** (cf. note explicite 1.4 : « Pas de route HTML/template : Story 1.4 = uniquement endpoints JSON »). Le **seul précédent web du repo** est l'**interface testeur** (Story 1.5) : `app/static/index.html`, HTML + JS vanilla + CSS inline, montée via `StaticFiles` à `/tester`, qui s'authentifie en HTTP Basic via un formulaire de login JS. **C'est ce pattern qu'on réutilise**, et il est conforme à l'architecture (`architecture.md:110` : « Admin interface → FastAPI + HTML statique (Basic Auth) »).

## Acceptance Criteria

### AC1 — Create-user admin (hard-blocker onboarding)

**Étant donné** une base prod wipée où `POST /v1/auth/register` renvoie 403 par design
**Quand** l'admin (authentifié HTTP Basic) appelle `POST /v1/admin/users` avec `{ "email", "password", "is_beta"? }` depuis la vue web
**Alors** un compte est créé en base : `email` normalisé, `hashed_password` calculé via `hash_password()` (bcrypt), `is_beta` = valeur fournie (défaut `false`), `is_subscribed=false`, `monthly_reloads=0`
**Et** la réponse (201) wrappée `{ "data": {...} }` contient `user_id`, `email`, `is_beta`, `is_subscribed`, `monthly_reloads`
**Et** si l'email existe déjà → 409 `{ "code": "EMAIL_ALREADY_EXISTS", ... }` (pas de 500 sur violation d'unicité)
**Et** sans credentials Basic valides → 401
**Et** `POST /v1/auth/register` continue de renvoyer 403 (aucune régression — `create-user` est une route admin distincte, jamais une réactivation de l'inscription publique)

### AC2 — Toggle beta (existe, à préserver) + reset quota (NEW)

**Étant donné** un user existant
**Quand** l'admin appelle `PATCH /v1/admin/users/{user_id}/beta` avec `{ "is_beta": true|false }`
**Alors** le flag est mis à jour (comportement existant Story 1.4 — **NE PAS le casser**, ré-exposer dans la vue web)

**Étant donné** un user ayant atteint son quota mensuel (`monthly_reloads` ≥ `monthly_reloads_max`)
**Quand** l'admin appelle `POST /v1/admin/users/{user_id}/reset-quota`
**Alors** `monthly_reloads` est remis à `0` **et** `monthly_reloads_reset_at` est remis à `None` (de sorte que le prochain réimport ré-initialise proprement la fenêtre via la logique lazy existante de `colleges.py`)
**Et** la réponse (200) wrappée contient le user à jour avec `monthly_reloads=0`
**Et** 404 `{ "code": "USER_NOT_FOUND", ... }` si le user n'existe pas
**Et** 401 sans credentials Basic valides
**Et** un test d'intégration vérifie qu'après reset, le user peut à nouveau lancer ses réimports (au moins : `monthly_reloads` est bien à 0 et `monthly_reloads_reset_at` à `None`)

### AC3 — Détail user (NEW)

**Étant donné** un user existant
**Quand** l'admin appelle `GET /v1/admin/users/{user_id}`
**Alors** la réponse (200) wrappée contient :
- les champs user : `user_id`, `email`, `is_beta`, `is_subscribed`, `monthly_reloads`, `monthly_reloads_max` (depuis `settings`), `monthly_reloads_reset_at` (ISO 8601 ou `null`), `created_at` (ISO 8601)
- la liste de ses **collèges** : `college_id`, `college_ref_id`, `status`, `reload_count`, `reload_count_max` (depuis `settings`)
- la liste de ses **generation_jobs** : `job_id`, `college_id`, `status`, `card_count`, `error_message`, `created_at` (ISO 8601) — triés `created_at` décroissant
**Et** 404 `{ "code": "USER_NOT_FOUND", ... }` si le user n'existe pas
**Et** 401 sans credentials Basic valides

### AC4 — Overview KPI (point d'entrée console)

**Étant donné** l'écran d'accueil de la console
**Quand** l'admin appelle `GET /v1/admin/overview`
**Alors** la réponse (200) wrappée contient :
- `users_total` : nombre total d'utilisateurs
- `jobs_by_status` : dict `{ "pending": n, "processing": n, "ocr_complete": n, "generation_complete": n, "failed": n }` (toujours les 5 clés, valeur 0 si aucune)
- `jobs_failed` : nombre de jobs `status == "failed"` (= `jobs_by_status["failed"]`, exposé à part pour la mise en avant UI)
**Et** 401 sans credentials Basic valides

### AC5 — Vue web admin (console)

**Étant donné** la console servie en statique à `/admin`
**Quand** l'admin ouvre l'URL et saisit ses credentials Basic dans le formulaire de login
**Alors** les credentials sont validés contre `GET /v1/admin/overview` (401 → message « Identifiants incorrects », sinon → écran d'accueil)
**Et** l'**écran d'accueil** affiche l'overview KPI (users_total, jobs par statut, jobs failed mis en avant)
**Et** un **écran liste users** affiche tous les users (email, is_beta, is_subscribed, monthly_reloads) avec : bouton **Créer un user** (formulaire email/password/is_beta), toggle **beta**, bouton **reset quota**, lien **détail**
**Et** un **écran détail user** affiche les champs user + ses collèges + ses jobs (cf. AC3)
**Et** toutes les requêtes envoient le header `Authorization: Basic ...` ; un 401 en cours de session renvoie au login
**Et** toutes les réponses sont lues via le wrapper `{ "data": ... }`

## Tasks / Subtasks

- [x] **T1 — Schémas Pydantic** `app/schemas/admin.py` (AC: #1, #2, #3, #4)
  - [x] 1.1 `CreateUserRequest` — `email: EmailStr`, `password: str = Field(..., min_length=8)`, `is_beta: bool = False` (importer `EmailStr` comme dans `app/schemas/auth.py`)
  - [x] 1.2 `CreateUserResponseWrapped` — `data: UserBetaData` (réutiliser `UserBetaData` existant)
  - [x] 1.3 `ResetQuotaResponseWrapped` — `data: UserBetaData`
  - [x] 1.4 Sous-modèles détail : `UserCollegeSummary` (`college_id: str`, `college_ref_id: int`, `status: str`, `reload_count: int`, `reload_count_max: int`), `UserJobSummary` (`job_id: str`, `college_id: str`, `status: str`, `card_count: int`, `error_message: str | None`, `created_at: str`)
  - [x] 1.5 `UserDetailData` — champs user (`user_id`, `email`, `is_beta`, `is_subscribed`, `monthly_reloads`, `monthly_reloads_max: int`, `monthly_reloads_reset_at: str | None`, `created_at: str`) + `colleges: list[UserCollegeSummary]` + `jobs: list[UserJobSummary]`
  - [x] 1.6 `UserDetailResponseWrapped` — `data: UserDetailData`
  - [x] 1.7 `OverviewData` (`users_total: int`, `jobs_by_status: dict[str, int]`, `jobs_failed: int`) + `OverviewResponseWrapped` — `data: OverviewData`

- [x] **T2 — Routes backend create-user / reset-quota** `app/api/v1/admin.py` (AC: #1, #2)
  - [x] 2.1 `POST /users` (status 201, `response_model=CreateUserResponseWrapped`) : `_: bool = Depends(get_admin_user)`, `db: AsyncSession = Depends(get_db)`. Normaliser l'email (`.strip().lower()`), créer `User(email=..., hashed_password=hash_password(body.password), is_beta=body.is_beta)`, `db.add` + `db.commit` + `db.refresh`. Envelopper le commit dans un `try/except IntegrityError` (déjà importé dans `admin.py`) → `db.rollback()` + 409 `EMAIL_ALREADY_EXISTS`. Importer `hash_password` depuis `app.core.security`.
  - [x] 2.2 `POST /users/{user_id}/reset-quota` (status 200, `response_model=ResetQuotaResponseWrapped`) : `db.get(User, user_id)` → 404 si `None`, sinon `user.monthly_reloads = 0`, `user.monthly_reloads_reset_at = None`, `db.commit()`, retourner `UserBetaData`. Pattern identique à `update_user_beta` existant (admin.py:392).

- [x] **T3 — Routes backend détail user / overview** `app/api/v1/admin.py` (AC: #3, #4)
  - [x] 3.1 `GET /users/{user_id}` (`response_model=UserDetailResponseWrapped`) : `db.get(User, user_id)` → 404 si absent. Charger collèges (`select(College).where(College.user_id == user_id)`) et jobs (`select(GenerationJob).where(GenerationJob.user_id == user_id).order_by(GenerationJob.created_at.desc())`). Sérialiser les dates en ISO 8601 (cf. note datetime tz dans Dev Notes). `monthly_reloads_max`/`reload_count_max` depuis `settings`.
  - [x] 3.2 `GET /overview` (`response_model=OverviewResponseWrapped`) : `users_total` via `select(func.count()).select_from(User)` ; `jobs_by_status` via `select(GenerationJob.status, func.count()).group_by(GenerationJob.status)` puis combler les 5 statuts à 0 par défaut ; `jobs_failed = jobs_by_status["failed"]`. `func` déjà importé dans `admin.py`.
  - [x] 3.3 **Placement des routes** : déclarer `GET /users/{user_id}`, `POST /users/{user_id}/reset-quota`, `GET /overview` de façon à ne PAS masquer la route statique `GET /users` existante (admin.py:371). Les routes avec segment fixe distinct (`/overview`) ou avec `{user_id}` ne créent pas de collision avec `/users`. Vérifier qu'aucune route `/users/{user_id}` GET ne préexiste (elle n'existe pas).

- [x] **T4 — Vue web admin (HTML statique)** (AC: #5)
  - [x] 4.1 Créer `app/static/admin/index.html` — HTML + JS vanilla + CSS inline, en calquant **exactement** le pattern de `app/static/index.html` (interface testeur) : helpers `basicHeader()` / `apiFetch()`, navigation `showSection()`, `login()` / `logout()`, gestion 401, lecture du wrapper `.data`. Réutiliser la palette CSS testeur (vert `#1b6b3a`, etc.) pour cohérence visuelle.
  - [x] 4.2 Sections : `login-section`, `overview-section` (KPI accueil), `users-section` (liste + bouton créer + toggle beta + reset quota + lien détail), `user-detail-section` (champs user + collèges + jobs). Login validé via `GET /v1/admin/overview`.
  - [x] 4.3 Actions JS : `createUser()` (POST /users, formulaire), `toggleBeta(userId, value)` (PATCH /users/{id}/beta), `resetQuota(userId)` (POST /users/{id}/reset-quota), `openUserDetail(userId)` (GET /users/{id}), `loadOverview()`, `loadUsers()`. Toasts/erreurs simples (réutiliser pattern `.error-msg` testeur).
  - [x] 4.4 Monter la console dans `app/main.py` : `app.mount("/admin", StaticFiles(directory=str(Path(__file__).parent / "static" / "admin"), html=True), name="admin-static")` — à placer à côté du mount `/tester` existant (ligne 102, après tous les routers API). Conserver le mount `/tester` intact.

- [x] **T5 — Tests backend** `tests/api/` (AC: #1, #2, #3, #4)
  - [x] 5.1 `tests/api/test_admin_users_create.py` — create-user : 201 + payload, `is_beta=true` honoré, 409 sur email dupliqué (simuler `IntegrityError` sur commit), 401 sans creds. **+ test de non-régression : `POST /v1/auth/register` renvoie toujours 403.**
  - [x] 5.2 `tests/api/test_admin_users_quota.py` — reset-quota : 200 + `monthly_reloads==0` + `monthly_reloads_reset_at` mis à `None`, 404 user inconnu, 401 sans creds.
  - [x] 5.3 `tests/api/test_admin_user_detail.py` — détail : 200 avec collèges + jobs + quota, 404 user inconnu, 401 sans creds.
  - [x] 5.4 `tests/api/test_admin_overview.py` — overview : agrégation correcte (`users_total`, `jobs_by_status` 5 clés, `jobs_failed`), 401 sans creds.
  - [x] 5.5 Suivre le pattern de tests existant : `ADMIN_AUTH = ("admin", "testpass")`, `client`/`mock_db` fixtures (NE PAS recréer de conftest), `types.SimpleNamespace` pour les modèles, `AsyncMock`/`MagicMock` pour `db.execute`/`db.get`/`db.commit`. Lancer `pytest` et viser 0 régression.

### Review Findings (code review 2026-06-17)

**Decision needed (résolues 2026-06-17) :**

- [x] [Review][Decision→Dismiss] Catalogue collèges réécrit (40→39) + remap `refId` — **DÉCISION PL : conservé dans le commit 7.6** (volet scope accepté). Risque migration `refId` neutralisé : base prod wipée + aucun install device en pré-beta. Caveat conservé pour mémoire : si des installs device portent d'anciens `refId`, un backfill serait nécessaire.
- [x] [Review][Decision→Patch] reset-quota — read-modify-write non atomique → **DÉCISION PL : à patcher** (UPDATE atomique aligné sur le pattern story 7.2 + test de l'effet aval `reset_at = None`). Voir section Patch ci-dessous.
- [x] [Review][Decision→Dismiss] Incohérence sprint-status `7-5` `ready-for-dev` vs blockers `backlog` — **DÉCISION PL : intentionnel**, laissé tel quel.

**Patch (appliqués 2026-06-17) :**

- [x] [Review][Patch] reset-quota : `UPDATE` atomique (pattern story 7.2), réponse construite à partir des valeurs connues post-reset + test de l'effet réel (params de l'UPDATE : `monthly_reloads=0`, `monthly_reloads_reset_at=None`) [collega_backend/app/api/v1/admin.py:487-505 ; tests/api/test_admin_users_quota.py]
- [x] [Review][Patch] `created_at` typé `str | None` dans `UserJobSummary` et `UserDetailData` [collega_backend/app/schemas/admin.py:173,184]
- [x] [Review][Patch] XSS : email échappé via `escapeHtml(u.email)` dans la liste users [collega_backend/app/static/admin/index.html]
- [x] [Review][Patch] `apiFetch` interrompt le flux appelant sur 401 (throw sentinelle `code=unauthorized`) ; tous les callers wrappés en `try/catch` [collega_backend/app/static/admin/index.html]
- [x] [Review][Patch] Robustesse : `apiFetch` catch les erreurs réseau (`code=network`), helper `readJson` pour réponses non-JSON, tous les callers en `try/catch` [collega_backend/app/static/admin/index.html]
- [x] [Review][Patch] `fmtDate` : `Number.isNaN(d.getTime())` + `escapeHtml(iso)` sur le fallback [collega_backend/app/static/admin/index.html:495]

**Deferred → tous traités 2026-06-17 (demande PL : tout régler avant commit) :**

- [x] [Review][Defer→Fix] Normalisation email au login : `auth.py` applique désormais `.strip().lower()` avant le lookup (cohérent avec la création) → connexion insensible à la casse
- [x] [Review][Defer→Fix] `create_user` : `id` généré explicitement + réponse construite depuis les invariants compte-neuf, `db.refresh` supprimé → plus de 500 possible si refresh échoue [admin.py]
- [x] [Review][Defer→Fix] Test create-user : `_fake_refresh_factory` supprimé ; le test vérifie le vrai contrat (invariants compte-neuf + objet `add`é) [test_admin_users_create.py]
- [x] [Review][Defer→Fix] Test overview : mock indépendant de l'ordre des `db.execute` (résultat répondant à `scalar_one()` ET `all()`) [test_admin_overview.py]
- [x] [Review][Defer→Verified] `is_beta` vs quota : **vérifié correct** — `deps.py:119` `is_subscribed OR is_beta` bypasse le paywall ; le quota mensuel s'applique uniformément (contrôle coût). Scénario onboarding testeuse conforme. Aucun changement.
- [x] [Review][Defer→Accepted] Identifiants Basic Auth en mémoire JS : **architectural** — inhérent à HTTP Basic Auth (creds re-envoyés à chaque requête). La vraie mitigation (vol via XSS) est close par le patch XSS. Un passage à session-token serait un redesign — risque accepté en l'état, console admin-only.
- [x] [Review][Defer→Fix] `monthly_reloads_max` ajouté à `UserBetaData` (peuplé via `settings` aux 4 sites) + affiché `x / max` dans la liste users [schemas/admin.py, admin.py, index.html]

## Dev Notes

### Vue d'ensemble — Ce que 7.6 ajoute

```
[EXISTANT — Story 1.4, à PRÉSERVER]
GET   /v1/admin/users                 → liste users (admin.py:371)
PATCH /v1/admin/users/{id}/beta       → toggle is_beta (admin.py:392)
GET   /v1/admin/config                → config anti-spam
GET   /v1/admin/queue, /colleges/{id}/stats, ...

[NOUVEAU — Story 7.6]
POST  /v1/admin/users                 → create-user (hard-blocker onboarding)
POST  /v1/admin/users/{id}/reset-quota→ reset monthly_reloads
GET   /v1/admin/users/{id}            → détail user (collèges + jobs + quota)
GET   /v1/admin/overview              → KPI (users, jobs par statut, failed)
+ app/static/admin/index.html         → console web (NEW), montée à /admin
```

### Authentification admin — pattern à respecter impérativement

- **TOUTES les routes admin** : `_: bool = Depends(get_admin_user)` (HTTP Basic Auth, `app/deps.py:18`). Comparaison timing-safe via `secrets.compare_digest`. **Ne JAMAIS oublier ce Depends sur les nouvelles routes** (sinon faille d'accès).
- Credentials = `settings.admin_username` / `settings.admin_password` (`app/core/config.py`). En tests : `ADMIN_USERNAME=admin`, `ADMIN_PASSWORD=testpass` (cf. `conftest.py`).
- L'admin n'utilise **pas** JWT (réservé aux users via `get_current_user`). La console web envoie le header Basic comme le fait l'interface testeur.

### État actuel des fichiers MODIFIED — à préserver

**`app/api/v1/admin.py`** (449 lignes, à étendre) :
- `router = APIRouter(tags=["admin"])` (ligne 51) — **CONSERVER, ne pas recréer**. Monté `prefix="/v1/admin"` dans `main.py`.
- Imports déjà présents et réutilisables : `APIRouter, Depends, HTTPException, UploadFile`, `func, select`, `IntegrityError`, `AsyncSession`, `settings`, `get_db`, `get_admin_user`, modèles `College, FlashCard, GenerationJob, Item, TesterFeedback, User`.
- **À ajouter en import** : `hash_password` depuis `app.core.security`, et les nouveaux schémas.
- Pattern d'erreur uniforme : `HTTPException(status_code=..., detail={"code": "...", "message": "..."})` — **CONSERVER**.
- Routes users existantes (`GET /users` ligne 371, `PATCH /users/{id}/beta` ligne 392) : ne pas modifier leur comportement.

**`app/schemas/admin.py`** (136 lignes, à étendre) :
- Réutiliser `UserBetaData` (lignes 102-107 : `user_id, email, is_beta, is_subscribed, monthly_reloads`) pour create-user et reset-quota.
- Suivre le pattern wrapper `XxxResponseWrapped(data=...)` de tout le fichier.

**`app/main.py`** (mount statique) :
- Ligne 101-102 : commentaire « StaticFiles doit être monté EN DERNIER pour ne pas masquer les routes API » + `app.mount("/tester", StaticFiles(directory=.../"static", html=True), name="tester-static")`.
- Ajouter le mount `/admin` à côté. **Caveat connu :** le mount `/tester` pointe sur le dossier `static/` racine, donc `app/static/admin/` sera aussi joignable via `/tester/admin/` (sans danger : HTML non secret, API protégée par Basic Auth). Restructurer l'interface testeur dans son propre sous-dossier est **hors périmètre** (deferred, noter si gênant).

### Modèles réels (source de vérité)

**`User`** (`app/models/user.py`) : `id: UUID`, `email: str(255) unique`, `hashed_password: str`, `is_beta: bool=False`, `is_subscribed: bool=False`, `first_name/year_group/faculty: str|None`, `monthly_reloads: int=0`, `monthly_reloads_reset_at: datetime(tz)|None`, `apns_token`, `reminder_hour_utc`, `created_at: datetime(tz)`. Relations : `colleges`, `generation_jobs`, `flash_cards` (cascade delete).

**`College`** (`app/models/college.py`) : `id: UUID`, `user_id: UUID (FK)`, `college_ref_id: int`, `status: str` (`pending|processing|ocr_complete|generation_complete|failed`), `reload_count: int=0`, `ocr_page_progress: int`, `total_pages: int|None`, `created_at`, `updated_at`.

**`GenerationJob`** (`app/models/generation_job.py`) : `id: UUID`, `college_id: UUID (FK)`, `user_id: UUID (FK)`, `status: str` (CheckConstraint sur les 5 mêmes valeurs), `arq_job_id: str|None`, `card_count: int=0`, `hash_shared: bool=False`, `pdf_hash: str|None`, `error_message: str|None`, `page_texts_json: str|None`, `created_at`, `updated_at`.

### Création d'un User — pattern

- Hashing : `from app.core.security import hash_password` → bcrypt via passlib (`app/core/security.py`). **Jamais** stocker un mot de passe en clair (le seed utilise `'seed'` en placeholder, ne PAS copier ça).
- Construction ORM (préférer l'ORM à du SQL `text()` brut comme le seed) :
  ```python
  user = User(email=body.email.strip().lower(), hashed_password=hash_password(body.password), is_beta=body.is_beta)
  db.add(user)
  try:
      await db.commit()
  except IntegrityError:
      await db.rollback()
      raise HTTPException(status_code=409, detail={"code": "EMAIL_ALREADY_EXISTS", "message": "Un compte avec cet email existe déjà."})
  await db.refresh(user)
  ```
- `EmailStr` (Pydantic) valide le format ; `email-validator>=2.0.0` est déjà une dépendance (`pyproject.toml:20`).

### Reset quota — sémantique exacte

La logique lazy de réinitialisation mensuelle vit dans `app/api/v1/colleges.py` (≈ lignes 179-237) :
```python
is_month_reset = current_user.monthly_reloads_reset_at is None or now >= current_user.monthly_reloads_reset_at
```
Donc **reset quota = `monthly_reloads = 0` + `monthly_reloads_reset_at = None`**. Au prochain réimport, la condition `... is None` déclenche la ré-init de la fenêtre et fixe un nouveau `monthly_reloads_reset_at`. Ne PAS recopier la logique `_next_month_reset` dans l'admin : un simple reset à `None` suffit et reste cohérent.

### Note datetime / tz (tests SQLite vs prod PostgreSQL)

En PostgreSQL `created_at`/`monthly_reloads_reset_at` sont `TIMESTAMPTZ` (tz-aware). En SQLite (tests) ils peuvent être naïfs. Pour sérialiser en ISO 8601 : `dt.isoformat() if dt else None`. Si besoin de calcul de delta, normaliser avec `.replace(tzinfo=timezone.utc)` quand `tzinfo is None` (pattern documenté dans la story 1.4, admin.py:275). Pour 7.6, on ne fait que sérialiser — `isoformat()` suffit.

### Pattern de tests (rappels 1.4 / 1.5, vérifiés)

- pytest + pytest-asyncio en `asyncio_mode = "auto"` (`pyproject.toml`) — pas de décorateur `@pytest.mark.asyncio` nécessaire, juste `async def test_...`.
- Fixtures globales dans `tests/conftest.py` : `client` (httpx `AsyncClient` + `ASGITransport`, override `get_db`), `mock_db` (`AsyncMock`). **NE PAS recréer de conftest dans `tests/api/`.**
- Auth : passer `auth=("admin", "testpass")` directement à `client.post/get` (httpx encode le Basic). Constante de fichier : `ADMIN_AUTH = ("admin", "testpass")`.
- Modèles simulés : `types.SimpleNamespace(...)` (jamais `Model.__new__`). Ex. :
  ```python
  def make_user(**kw):
      return types.SimpleNamespace(id=kw.get("id", uuid.uuid4()), email="u@test.com",
          is_beta=False, is_subscribed=False, monthly_reloads=0,
          monthly_reloads_reset_at=None, created_at=datetime.now(timezone.utc), **kw)
  ```
- `db.get` → `AsyncMock(return_value=...)` ; `db.execute` → `AsyncMock(return_value=MagicMock(scalars=..., all=..., scalar_one_or_none=...))` selon l'appel ; `db.commit/refresh` → `AsyncMock`.
- Pour create-user 409 : `mock_db.commit = AsyncMock(side_effect=IntegrityError("", "", Exception()))`.
- Pour 401 : appeler sans `auth=` → le `Depends(get_admin_user)` lève 401.
- Lancer : `pytest` (ou `pytest tests/api/test_admin_*.py -v`). Viser **0 régression** (1.4 = 106 tests, 7.x ont ajouté davantage).

### Frontend — pattern testeur à calquer (`app/static/index.html`)

Helpers de référence (lignes 156-166) :
```javascript
function basicHeader() { return "Basic " + btoa(creds.username + ":" + creds.password); }
async function apiFetch(path, options = {}) {
  return fetch(path, { ...options,
    headers: { "Authorization": basicHeader(), "Content-Type": "application/json", ...(options.headers||{}) } });
}
function showSection(id) {
  document.querySelectorAll("section").forEach(s => s.classList.remove("active"));
  document.getElementById(id).classList.add("active");
}
```
Login validé contre un endpoint admin (ici `GET /v1/admin/overview`), gestion `res.status === 401` → message d'erreur. Lecture systématique de `(await res.json()).data`.

### Project Structure Notes

**Fichiers à créer (NEW) :**
```
collega_backend/
├── app/static/admin/index.html              ← console web admin (NEW)
└── tests/api/
    ├── test_admin_users_create.py           ← NEW (+ régression register 403)
    ├── test_admin_users_quota.py            ← NEW
    ├── test_admin_user_detail.py            ← NEW
    └── test_admin_overview.py               ← NEW
```

**Fichiers à modifier (UPDATE) :**
| Fichier | Modification |
|---------|-------------|
| `app/schemas/admin.py` | + `CreateUserRequest`, `CreateUserResponseWrapped`, `ResetQuotaResponseWrapped`, `UserCollegeSummary`, `UserJobSummary`, `UserDetailData`, `UserDetailResponseWrapped`, `OverviewData`, `OverviewResponseWrapped` |
| `app/api/v1/admin.py` | + 4 routes (`POST /users`, `POST /users/{id}/reset-quota`, `GET /users/{id}`, `GET /overview`) + import `hash_password` |
| `app/main.py` | + mount `/admin` StaticFiles (à côté de `/tester`) |

**Conventions à respecter :** wrapper `{ "data": ... }` sur toutes les réponses ; `HTTPException(detail={"code","message"})` ; snake_case ; `logger` jamais `print()` ; ISO 8601 UTC pour les dates ; imports SQLAlchemy au niveau module.

### Library / Framework

- Backend : FastAPI, SQLAlchemy async (`AsyncSession`), Pydantic v2 (`BaseModel`, `EmailStr`, `Field`), passlib[bcrypt], pytest + pytest-asyncio, httpx (tests). Aucune nouvelle dépendance requise — `email-validator` déjà présent.
- Frontend : aucun framework, aucun build step — HTML/CSS/JS vanilla servi par `StaticFiles`. Pas de Jinja2.

### Previous Story Intelligence (1.4 + 7.x)

- **1.4** a posé tout l'échafaudage admin JSON (auth Basic, schémas wrappés, routes users/queue/stats/config) et a explicitement décidé « pas de HTML » → la vue web était implicitement reportée ; 7.6 la livre enfin.
- **1.4 — défauts déjà documentés (Phase 0, ne pas “re-fixer” ici)** : `GET /users` sans pagination (volume faible OK), config in-memory non persistée. Restent acceptables pour 7.6.
- **7.2** a durci l'atomicité des quotas (`UPDATE ... RETURNING`) côté réimport — le reset admin de 7.6 doit rester cohérent avec cette logique (d'où reset `monthly_reloads_reset_at=None`, pas de bricolage de compteur).
- Apprentissages tests réaffirmés à chaque story : `SimpleNamespace`, mock à l'import, wrapper `data`, 0 régression.

### Git Intelligence

Commits récents (epic 7) confirment le découpage par zone et le pattern « feat(story-7.x): … + review-fix » :
- `72da25a feat(story-7.4)` chronomètre + APNs singleton + CGU
- `3ba3efa feat(story-7.3)` hardening RGPD + config Pydantic
- `0672cb9 feat(story-7.2)` atomicité quota & idempotence
- `8b2c131 feat(story-7.1)` UX FlashCard & Router

Le statut git montre des fichiers déjà modifiés sur `colleges.py`, `college_import_table.dart`, tests imports — non liés à 7.6 ; ne pas les emporter dans le commit 7.6.

### References

- [Source: `_bmad-output/planning-artifacts/epics-v1.1.md#Story-7.6`] — AC socle, Thème A, hard-blocker onboarding
- [Source: `_bmad-output/brainstorming/brainstorming-session-2026-06-16-2242.md`] — périmètre Thème A (foundation), exclusions B/C
- [Source: `_bmad-output/planning-artifacts/architecture.md:110,195`] — « Admin interface → FastAPI + HTML statique (Basic Auth) »
- [Source: `collega_backend/app/api/v1/admin.py:371,392`] — `list_users`, `update_user_beta` (à préserver/étendre)
- [Source: `collega_backend/app/schemas/admin.py:102`] — `UserBetaData` réutilisable + pattern wrapper
- [Source: `collega_backend/app/deps.py:18`] — `get_admin_user` (HTTP Basic, timing-safe)
- [Source: `collega_backend/app/api/v1/auth.py:25`] — `register` → 403 (régression à garder)
- [Source: `collega_backend/app/core/security.py:12`] — `hash_password` (bcrypt)
- [Source: `collega_backend/app/models/user.py`] — champs User + `monthly_reloads_reset_at`
- [Source: `collega_backend/app/api/v1/colleges.py:179`] — logique lazy reset quota (sémantique du reset admin)
- [Source: `collega_backend/app/static/index.html:156`] — pattern frontend (Basic header, fetch, sections)
- [Source: `collega_backend/app/main.py:101`] — mount `StaticFiles` `/tester` (modèle pour `/admin`)
- [Source: `collega_backend/tests/conftest.py` + `tests/api/test_admin_*.py`] — fixtures `client`/`mock_db`, `ADMIN_AUTH`, `SimpleNamespace`
- [Source: `collega_backend/seed_dev.py:100`] — schéma colonnes users/colleges/jobs (ne pas copier le hashing placeholder)

## Décisions Project Lead (actées 2026-06-16)

1. **✅ Vue web admin = HTML statique calqué sur l'interface testeur.** `app/static/admin/index.html` (HTML+JS vanilla+CSS inline) servi via `StaticFiles` à `/admin`, Basic Auth par formulaire. Aligné architecture + seul précédent web du repo. Pas de SPA, pas d'extension Flutter.
2. **✅ `create-user` = route sécurisée réservée à l'admin.** `POST /v1/admin/users` est protégée par `Depends(get_admin_user)` (HTTP Basic Auth, credentials admin de `settings`) → **seul l'admin peut créer des comptes**. `POST /v1/auth/register` **reste 403** (inscription publique fermée, test de non-régression exigé). Aucune réouverture de l'inscription ; l'onboarding testeuse passe exclusivement par cette route admin. Conforme à la sécurité actée (« /register bloqué 403 »).
3. **✅ Caveat mount statique accepté, restructuration en deferred.** `app/static/admin/` sera aussi accessible via `/tester/admin/` (sans risque : HTML non secret, endpoints toujours Basic-auth). Déplacer l'interface testeur dans un sous-dossier dédié reste un nettoyage optionnel post-7.6 — **ne PAS le faire dans 7.6**.
4. **✅ Périmètre strict Thème A confirmé.** 7.6 = create-user, toggle beta, liste/détail user, reset quota, overview KPI + vue web. **Exclus (→ 7.7/7.8) :** timeline persistée, stop/delete, détail brut job, conso tokens/coût, inspection fiches, vue feedback. Séquencement A→B→C respecté.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (create-story) ; claude-opus-4-8 (dev-story)

### Debug Log References

- **Découverte env (non-bloquant story) :** `hash_password` (passlib 1.7.4) crashait sur le `.venv` local car **bcrypt 5.0.0** y était installé, hors de la contrainte `pyproject.toml` (`bcrypt >=3.2.0,<4.0.0`). passlib 1.7.4 est incompatible avec bcrypt ≥ 4.1 (le self-test backend hashe un mot de passe > 72 octets → `ValueError`). Ce n'est PAS un défaut de code 7.6 ni de prod (pyproject épingle déjà < 4.0.0) — seul le venv local avait dérivé. **Correctif appliqué :** réalignement du venv via `pip install 'bcrypt>=3.2.0,<4.0.0'`. `hash_password` + `verify_password` revérifiés OK ensuite. ⚠️ Le reviewer / la CI doit s'assurer que l'environnement résout bien bcrypt < 4.0.0 (idéalement geler un `poetry.lock`, absent du repo).
- Non-régression vérifiée par stash ciblé : les 16 échecs de la suite (`test_auth` register périmés + `test_search`/`test_reminder`/`test_flash_cards`/`test_login` nécessitant Redis local sur `localhost:6379`) sont **pré-existants** et identiques avec/sans les changements 7.6.

### Completion Notes List

- ✅ **AC1 — create-user admin** : `POST /v1/admin/users` (201, wrapper `data`), email normalisé `.strip().lower()`, hash bcrypt via `hash_password`, `is_beta` honoré, 409 `EMAIL_ALREADY_EXISTS` sur `IntegrityError` (rollback), 401 sans Basic. **`POST /v1/auth/register` reste 403** (test de non-régression vert).
- ✅ **AC2 — toggle beta préservé + reset quota** : `PATCH /users/{id}/beta` inchangé ; `POST /users/{id}/reset-quota` met `monthly_reloads=0` **et** `monthly_reloads_reset_at=None` (cohérent avec la logique lazy de `colleges.py` + hardening quota 7.2), 404/401 gérés, test vérifiant l'état post-reset.
- ✅ **AC3 — détail user** : `GET /users/{id}` renvoie champs user + `monthly_reloads_max`/`reload_count_max` depuis `settings`, dates ISO 8601, collèges + generation_jobs (triés `created_at` desc), 404/401.
- ✅ **AC4 — overview KPI** : `GET /overview` → `users_total` (count), `jobs_by_status` (toujours les 5 clés, 0 par défaut), `jobs_failed`, 401.
- ✅ **AC5 — console web** : `app/static/admin/index.html` (HTML+JS vanilla+CSS inline calqués sur l'interface testeur), montée à `/admin`. Écrans login (validé contre `/v1/admin/overview`) / accueil KPI / liste users (créer + toggle beta + reset quota + détail) / détail user. Header Basic systématique, gestion 401 → retour login, lecture du wrapper `.data`.
- **Placement routes** : `/overview` (segment fixe) et `/users/{user_id}` (param) ne masquent pas le `GET /users` existant — vérifié par l'enregistrement des routes + 56 tests admin verts.
- **Caveat mount accepté (décision PL #3)** : `app/static/admin/` reste joignable via `/tester/admin/` — sans risque (HTML non secret, API Basic-auth). Restructuration testeur → deferred, non faite.
- **Tests** : 17 nouveaux tests (4 fichiers) + 56 tests admin au total passent. Suite globale : 274 passed, 16 failed pré-existants (Redis/stale), 1 skipped.

### File List

**Nouveaux fichiers :**
- `collega_backend/app/static/admin/index.html` — console web admin (HTML/JS/CSS vanilla)
- `collega_backend/tests/api/test_admin_users_create.py` — tests create-user + non-régression register 403
- `collega_backend/tests/api/test_admin_users_quota.py` — tests reset-quota
- `collega_backend/tests/api/test_admin_user_detail.py` — tests détail user
- `collega_backend/tests/api/test_admin_overview.py` — tests overview KPI

**Fichiers modifiés :**
- `collega_backend/app/schemas/admin.py` — + `CreateUserRequest`, `CreateUserResponseWrapped`, `ResetQuotaResponseWrapped`, `UserCollegeSummary`, `UserJobSummary`, `UserDetailData`, `UserDetailResponseWrapped`, `OverviewData`, `OverviewResponseWrapped` (+ import `EmailStr`)
- `collega_backend/app/api/v1/admin.py` — + 4 routes (`POST /users`, `POST /users/{id}/reset-quota`, `GET /users/{id}`, `GET /overview`) + import `hash_password` + imports schémas 7.6
- `collega_backend/app/main.py` — + mount `/admin` StaticFiles (à côté de `/tester`)

## Change Log

| Date | Version | Description |
|------|---------|-------------|
| 2026-06-17 | 0.1 | Implémentation Story 7.6 — console admin (create-user/reset-quota/détail user/overview KPI) + vue web `/admin`. 17 tests ajoutés, 0 régression. Découverte env : réalignement bcrypt < 4.0.0 dans le venv local (cf. Debug Log). |

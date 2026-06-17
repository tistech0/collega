# Story 7.7 : Dashboard Admin — Suivi & Contrôle des Imports (Thème B)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **Project Lead / admin**,
je veux suivre l'avancement réel d'un import (timeline persistée + détail brut + confiance OCR) et pouvoir l'arrêter ou le supprimer depuis la console web,
afin de détecter et débloquer une testeuse coincée sans fouiller les logs NAS / Redis / psql.

## Contexte & périmètre (à lire avant de coder)

Story 7.7 est le **Thème B** du Dashboard Admin (acté le 2026-06-16 via `correct-course`, source brainstorm `brainstorming-session-2026-06-16-2242.md`). Elle s'appuie sur le **socle livré par 7.6** (Story 7.6 = `done`) : auth Basic admin, schémas wrappés `{ "data": ... }`, console web statique `app/static/admin/index.html` montée à `/admin`, helpers JS (`apiFetch`, `readJson`, `escapeHtml`, `fmtDate`, `statusBadge`, `showSection`, `toast`).

**Objectif métier :** te rendre « voyant » pendant le test — voir où en est un import, distinguer un mauvais OCR d'un mauvais prompt, et reprendre la main (stop/delete) sur un import planté.

**Ce que 7.7 AJOUTE vs ce qui existe déjà :**

```
[EXISTANT — Story 1.4/7.6, à PRÉSERVER]
GET   /v1/admin/queue                  → liste 50 derniers jobs (status, progress, elapsed, error)   admin.py:255
GET   /v1/admin/colleges/{id}/status   → statut OCR + ocr_page_progress/total_pages                  admin.py:217
GET   /v1/admin/colleges/{id}/stats    → cartes par rang + items_ocr_confidence + pertinence         admin.py:291
+ console web /admin (overview/users/user-detail)                                                     static/admin/index.html

[NOUVEAU — Story 7.7]
NEW DB  table generation_job_events    → timeline persistée des étapes par job (migration 013)
GET     /v1/admin/jobs/{job_id}        → détail brut job + timeline + confiance OCR par item
POST    /v1/admin/jobs/{job_id}/stop   → annule le job ARQ en cours + force le statut
DELETE  /v1/admin/colleges/{college_id}→ supprime l'import (college) + fiches/items/jobs en cascade + PDF disque
+ instrumentation pipeline (ocr_worker / generation_worker / card_generator) → écrit les events timeline
+ WORKER_SETTINGS: allow_abort_jobs=True (sinon l'abort ARQ est ignoré par le worker)
+ console web /admin : écran liste imports + écran détail import (timeline, détail brut, OCR/item, stop/delete, indicateur blocage)
```

**Thème C (7.8 — qualité/coût) reste HORS périmètre.** Ne PAS implémenter ici : persistance `response.usage` tokens, inspection détaillée recto/verso des fiches, vue feedback testeuse, agrégation coût €. 7.7 expose la **confiance OCR par item** (pour distinguer mauvais OCR vs mauvais prompt) mais PAS l'inspection qualité des fiches générées (= 7.8).

**Décision d'architecture clé (lire attentivement) :** « supprimer l'import et les fiches associées » ne peut se faire **qu'au niveau College**, pas au niveau GenerationJob. Les `FlashCard`/`Item` ont une FK vers `college_id`/`item_id`, **jamais vers `generation_job_id`**. Un `GenerationJob` n'a donc aucune relation cascade vers les fiches. → **Delete = `DELETE College`** (la cascade ORM+DB emporte items, jobs, flashcards, tester_feedbacks). Voir Dev Notes § Cascade delete.

## Acceptance Criteria

### AC1 — Timeline d'événements persistée (NEW DB + instrumentation pipeline)

**Étant donné** un import en cours ou terminé
**Quand** l'admin appelle `GET /v1/admin/jobs/{job_id}`
**Alors** la réponse (200, wrappée `{ "data": ... }`) contient une **`timeline`** : liste ordonnée (par `created_at` croissant) d'événements persistés, chacun avec `event_type`, `message` (str|None), `page` (int|None), `total` (int|None), `created_at` (ISO 8601)
**Et** les `event_type` écrits par le pipeline couvrent au minimum : `ocr_started`, `ocr_progress` (avec `page`/`total`), `items_detected`, `ocr_complete`, `generation_started`, `generation_complete`, `failed`, `cancelled`
**Et** la timeline est **lisible au refresh** (pas de live SSE — un simple re-GET reflète l'état courant)
**Et** l'écriture d'un événement ne peut **jamais** faire échouer le pipeline (écriture défensive — cf. Dev Notes)

### AC2 — Détail brut du job + confiance OCR par item (debug sans Redis/psql)

**Étant donné** un import (job) existant
**Quand** l'admin appelle `GET /v1/admin/jobs/{job_id}`
**Alors** la réponse contient le **détail brut** du job : `job_id`, `college_id`, `user_id`, `status`, `arq_job_id` (str|None), `pdf_hash` (str|None), `hash_shared` (bool), `card_count` (int), `error_message` (str|None), `created_at`/`updated_at` (ISO 8601)
**Et** la progression OCR du college : `ocr_page_progress` (int), `total_pages` (int|None), `college_status` (str)
**Et** la **confiance OCR par item** : liste `items` de `{ item_number, ocr_confidence_score, low_confidence }` (réutiliser le schéma `ItemOcrData` existant), triée par `item_number`
**Et** 404 `{ "code": "JOB_NOT_FOUND", ... }` si le job n'existe pas
**Et** 401 sans credentials Basic valides

### AC3 — Stop (annuler le job ARQ en cours)

**Étant donné** un import dont le job est actif (`status ∈ {pending, processing, ocr_complete}`)
**Quand** l'admin appelle `POST /v1/admin/jobs/{job_id}/stop`
**Alors** le job ARQ identifié par `arq_job_id` est annulé en best-effort via l'abort ARQ (timeout court, non bloquant sur la durée réelle du job)
**Et** le job DB est forcé à `status="failed"` avec `error_message="Annulé par l'admin"` **indépendamment** du succès de l'abort (le worker ne catche pas `CancelledError`, donc l'endpoint est seul garant du statut DB)
**Et** un événement timeline `cancelled` est écrit
**Et** comme le job quitte l'ensemble actif (`pending/processing/ocr_complete`), l'index UNIQUE partiel `idx_one_active_job_per_college` (migration 012) est libéré → un réimport redevient possible
**Et** la réponse (200, wrappée) contient le job à jour (`job_id`, `status`, `error_message`)
**Et** 409 `{ "code": "JOB_NOT_ACTIVE", ... }` si le job est déjà `generation_complete` ou `failed` (rien à annuler)
**Et** 404 `{ "code": "JOB_NOT_FOUND", ... }` si le job n'existe pas ; 401 sans creds

### AC4 — Delete (supprimer l'import + fiches associées)

**Étant donné** un import (college) existant
**Quand** l'admin appelle `DELETE /v1/admin/colleges/{college_id}`
**Alors** le `College` est supprimé et la cascade (ORM `all, delete-orphan` + FK `ondelete=CASCADE`) emporte ses `Item`, `GenerationJob` (+ leurs `generation_job_events`), `FlashCard` et `TesterFeedback`
**Et** les fichiers PDF du college sur disque (`{settings.pdf_storage_path}/{college_id}_*.pdf`) sont supprimés en best-effort (`unlink(missing_ok=True)`)
**Et** la réponse est `204 No Content`
**Et** 404 `{ "code": "COLLEGE_NOT_FOUND", ... }` si le college n'existe pas ; 401 sans creds
**Et** un test vérifie le happy path (college + descendants supprimés, PDF unlink appelé) et le 404/401

### AC5 — Indicateur de blocage (dérivé, pas un écran séparé)

**Étant donné** la liste des imports dans la console
**Quand** l'admin la consulte
**Alors** un import est signalé **bloqué** si : `status == "failed"` **OU** (`status ∈ {pending, processing}` **ET** `elapsed_seconds` > seuil de stagnation, défaut 3600s / 1h)
**Et** le signal est affiché **dans** la liste des imports (badge/ligne mise en avant), pas dans un écran dédié
**Et** le blocage par quota mensuel atteint reste visible via l'écran users/détail user (Story 7.6) — un renvoi visuel/textuel suffit (pas de recalcul backend ici)

> Calcul **côté console web** à partir des champs déjà renvoyés par `GET /v1/admin/queue` (`status`, `elapsed_seconds`) — **aucune modification du endpoint `/queue` n'est requise** (zéro risque de régression sur les tests 1.4).

### AC6 — Vue web admin (écrans imports)

**Étant donné** la console `/admin` (Story 7.6)
**Quand** l'admin navigue
**Alors** un **écran liste imports** affiche les jobs (via `GET /v1/admin/queue`) : college_id, statut (badge), progression OCR (`x/y`), card_count, âge (`elapsed_seconds` formaté), `error_message`, **indicateur de blocage** (AC5), lien **Détail**
**Et** un **écran détail import** (via `GET /v1/admin/jobs/{job_id}`) affiche : le **détail brut** (AC2), la **timeline** (AC1, lisible et ordonnée), la **confiance OCR par item** (badge « ⚠ faible » si `low_confidence`), et les boutons **Stop** (visible si job actif) et **Delete** (avec confirmation)
**Et** **Stop** appelle `POST /v1/admin/jobs/{job_id}/stop` puis rafraîchit le détail
**Et** **Delete** demande confirmation (`confirm(...)`) puis appelle `DELETE /v1/admin/colleges/{college_id}` et revient à la liste
**Et** la navigation s'intègre aux onglets existants (overview / users) — ajouter un onglet **Imports**
**Et** toutes les requêtes passent par `apiFetch`/`readJson` (header Basic, gestion 401 → login, lecture du wrapper `.data`), email/texte échappés via `escapeHtml`

## Tasks / Subtasks

- [x] **T1 — Modèle + migration : table `generation_job_events`** (AC: #1)
  - [x] 1.1 Créer `app/models/generation_job_event.py` : classe `GenerationJobEvent(Base)`, `__tablename__ = "generation_job_events"`. Colonnes : `id: UUID PK` (default `uuid.uuid4`), `generation_job_id: UUID` FK `generation_jobs.id` `ondelete="CASCADE"` indexé NOT NULL, `event_type: String(50)` NOT NULL, `message: Text|None`, `page: Integer|None`, `total: Integer|None`, `created_at: DateTime(timezone=True)` NOT NULL default `datetime.now(timezone.utc)`. Relationship `job` back_populates `events`. **Calquer le style des modèles existants** (`app/models/generation_job.py`).
  - [x] 1.2 Ajouter sur `GenerationJob` (`app/models/generation_job.py`) la relationship inverse : `events: Mapped[list["GenerationJobEvent"]] = relationship("GenerationJobEvent", back_populates="job", cascade="all, delete-orphan")` (mirror du pattern `College.generation_jobs`). Import sous `TYPE_CHECKING` si besoin pour éviter l'import circulaire.
  - [x] 1.3 Exporter `GenerationJobEvent` dans `app/models/__init__.py` (sinon Alembic `env.py` ne voit pas la table — il fait `import app.models`).
  - [x] 1.4 Migration `alembic/versions/013_add_generation_job_events.py` : `revision = "013"`, `down_revision = "012"`. `upgrade()` = `op.create_table("generation_job_events", ...)` en calquant le pattern des migrations 002/004/005 (`UUID(as_uuid=True)` + `server_default=sa.text("gen_random_uuid()")`, FK `ondelete="CASCADE"`, `created_at` `server_default=sa.text("NOW()")`) + `op.create_index("ix_generation_job_events_generation_job_id", ...)`. `downgrade()` = drop index + drop table.

- [x] **T2 — Helper d'écriture d'événements + isolation ARQ** (AC: #1, #3)
  - [x] 2.1 Créer `app/services/jobs/job_events.py` (nouveau package `app/services/jobs/` + `__init__.py`) avec `async def record_job_event(db, generation_job_id, event_type, *, message=None, page=None, total=None) -> None` qui fait `db.add(GenerationJobEvent(...))` **sans commit** (le commit est porté par le flux appelant) et **n'élève jamais** (try/except large → `logger.warning`, jamais `raise` — un échec de timeline ne doit pas casser le pipeline).
  - [x] 2.2 Créer `app/services/jobs/arq_control.py` avec `async def abort_arq_job(arq_job_id: str, *, timeout: float = 5.0) -> bool` qui : `create_pool(redis_settings)`, construit `arq.jobs.Job(job_id=arq_job_id, redis=pool)`, appelle `await job.abort(timeout=timeout)`, ferme le pool (`finally`), retourne le booléen (catch `Exception` → `logger.warning` + `return False`). **Isoler ainsi l'interaction ARQ rend le endpoint Stop mockable** dans les tests.

- [x] **T3 — Instrumentation du pipeline (écriture des events)** (AC: #1)
  - [x] 3.1 `app/workers/ocr_worker.py` — **lire le fichier en entier d'abord**. Ajouter `record_job_event` aux points : après `job.status="processing"` (ligne ~107) → `ocr_started` (`total=total_pages`) ; dans la boucle page (avant le `await db.commit()` ligne ~137) → `ocr_progress` **throttlé** (n'écrire que toutes les `max(1, total_pages // 20)` pages + dernière page, pour borner à ~20 events quel que soit le volume) avec `page=page_num+1, total=total_pages` ; après dedup (ligne ~180) → `items_detected` (`message=f"{len(final_items)} items"`) ; après `job.status="ocr_complete"` (ligne ~208) → `ocr_complete` (`message=f"{len(final_items)} items"`) ; dans le `except` top-level (ligne ~64) → `failed` (`message=str(exc)`). Le PDF vide (ligne ~98) → `failed` aussi.
  - [x] 3.2 **GOTCHA CRITIQUE — persister l'`arq_job_id` de la phase génération.** Aujourd'hui `job.arq_job_id` ne contient que l'id ARQ de la phase **OCR** ; la phase génération est enqueuée dans `ocr_worker.py` (ligne ~215) avec un **nouvel** id ARQ **jamais persisté** → Stop ne pourrait pas annuler pendant la génération. Modifier l'enqueue pour capturer le retour et faire `job.arq_job_id = gen_job.job_id` puis `await db.commit()` (best-effort, ne pas casser si l'enqueue échoue). Ainsi `arq_job_id` pointe **toujours** sur le job ARQ actif → Stop fiable sur les deux phases.
  - [x] 3.3 `app/workers/generation_worker.py` + `app/services/generation/card_generator.py` — **lire les deux fichiers d'abord**. Écrire `generation_started` à l'entrée de `generate_for_college` (après chargement des items, `message=f"{n} items"`), `generation_complete` juste avant/après le commit `job.status="generation_complete"` (`message=f"{card_count} cards"`), et `failed` dans le `except` de `generate_college_cards` (worker, ligne ~71, après re-get du job, avant commit).

- [x] **T4 — Activer l'abort ARQ côté worker** (AC: #3)
  - [x] 4.1 `app/workers/settings.py` — ajouter `"allow_abort_jobs": True` à `WORKER_SETTINGS` (sans ce flag, `Job.abort()` est ignoré par le worker et le job continue). Vérifier que le worker démarre toujours (pas de test auto requis, mais ne pas casser le boot).

- [x] **T5 — Schémas Pydantic** `app/schemas/admin.py` (AC: #1, #2, #3)
  - [x] 5.1 `JobEventData` : `event_type: str`, `message: str | None`, `page: int | None`, `total: int | None`, `created_at: str | None`.
  - [x] 5.2 `JobDetailData` : champs bruts du job (`job_id, college_id, user_id, status, arq_job_id: str|None, pdf_hash: str|None, hash_shared: bool, card_count: int, error_message: str|None, created_at: str|None, updated_at: str|None`) + progression (`ocr_page_progress: int, total_pages: int|None, college_status: str`) + `items: list[ItemOcrData]` (réutiliser `ItemOcrData` existant) + `timeline: list[JobEventData]`.
  - [x] 5.3 `JobDetailResponseWrapped(data: JobDetailData)`.
  - [x] 5.4 `StopJobData` (`job_id: str, status: str, error_message: str | None`) + `StopJobResponseWrapped(data: StopJobData)`.
  - [x] 5.5 Respecter le pattern wrapper du fichier ; suivre le style Pydantic v2 déjà en place.

- [x] **T6 — Routes backend** `app/api/v1/admin.py` (AC: #2, #3, #4)
  - [x] 6.1 `GET /jobs/{job_id}` (`response_model=JobDetailResponseWrapped`, `_: bool = Depends(get_admin_user)`, `db=Depends(get_db)`) : `db.get(GenerationJob, job_id)` → 404 `JOB_NOT_FOUND`. Charger le college (`db.get(College, job.college_id)`) pour progression/status. Charger les events (`select(GenerationJobEvent).where(...).order_by(GenerationJobEvent.created_at.asc())`). Charger les items du college (`select(Item).where(Item.college_id == job.college_id).order_by(Item.item_number)`) pour `ItemOcrData`. Sérialiser les dates `dt.isoformat() if dt else None`.
  - [x] 6.2 `POST /jobs/{job_id}/stop` (`response_model=StopJobResponseWrapped`) : `db.get(GenerationJob, job_id)` → 404 ; si `status` ∉ `{pending, processing, ocr_complete}` → 409 `JOB_NOT_ACTIVE`. Sinon : `if job.arq_job_id: await abort_arq_job(job.arq_job_id)` (best-effort, ignorer le retour), puis **forcer** `job.status="failed"`, `job.error_message="Annulé par l'admin"`, `await record_job_event(db, job.id, "cancelled", message="Annulé par l'admin")`, `await db.commit()`. Retourner `StopJobData`.
  - [x] 6.3 `DELETE /colleges/{college_id}` (status_code=204, `_: bool = Depends(get_admin_user)`, `db=Depends(get_db)`) : `db.get(College, college_id)` → 404 `COLLEGE_NOT_FOUND`. `await db.delete(college)` (la cascade ORM `all, delete-orphan` emporte items/jobs/flashcards) + `await db.commit()`. Puis best-effort PDF cleanup : `for p in Path(settings.pdf_storage_path).glob(f"{college_id}_*.pdf"): p.unlink(missing_ok=True)` dans un try/except (ne pas faire échouer la suppression DB si le disque pose problème). Retourner `None`/`Response(status_code=204)`.
  - [x] 6.4 Imports à ajouter en tête de `admin.py` : `GenerationJobEvent`, `record_job_event`, `abort_arq_job`, nouveaux schémas, `Response` FastAPI si nécessaire. **Ne pas toucher** au router ni aux routes existantes.
  - [x] 6.5 **Placement des routes** : `/jobs/{job_id}`, `/jobs/{job_id}/stop` n'entrent en collision avec aucune route existante (`/queue`, `/colleges/...`, `/users/...`). `DELETE /colleges/{college_id}` est un nouveau verbe sur un segment existant — vérifier qu'aucun `DELETE /colleges/{id}` ne préexiste (il n'existe pas).

- [x] **T7 — Vue web admin (HTML statique)** `app/static/admin/index.html` (AC: #5, #6)
  - [x] 7.1 Ajouter un onglet **Imports** dans la barre de navigation existante (`nav-tabs`) à côté d'overview/users, + `goImports()` (calqué sur `goOverview`/`goUsers`).
  - [x] 7.2 Section `imports-section` : charge `GET /v1/admin/queue`, rend un tableau (college_id, statut via `statusBadge`, `ocr_page_progress/total_pages`, card_count, âge formaté depuis `elapsed_seconds`, error_message tronqué/échappé, badge **Bloqué** selon AC5, bouton **Détail** → `openJobDetail(job_id, college_id)`). Réutiliser le pattern loader/empty/table de `loadUsers`.
  - [x] 7.3 Section `job-detail-section` : charge `GET /v1/admin/jobs/{job_id}`, rend le détail brut (table clé/valeur comme `openUserDetail`), la **timeline** (liste ordonnée `event_type` + `message` + `page/total` + `fmtDate(created_at)`), les **items** avec badge OCR faible (`low_confidence` → badge rouge « ⚠ OCR faible », réutiliser palette). Boutons **Stop** (affiché si `status ∈ actifs`) → `stopJob(job_id)` ; **Delete** → `confirm(...)` puis `deleteImport(college_id)`. Bouton **← Retour** vers `imports-section`.
  - [x] 7.4 Actions JS : `stopJob(jobId)` (POST stop, toast, re-`openJobDetail`), `deleteImport(collegeId)` (DELETE, toast, `goImports`). Gérer 409 (`JOB_NOT_ACTIVE`) et 404 proprement (toast d'erreur). Tout via `apiFetch`/`readJson`, catch `unauthorized` early.
  - [x] 7.5 **Ne pas régresser** les écrans 7.6 (overview/users/user-detail) ni les helpers partagés.

- [x] **T8 — Tests backend** `tests/api/` (AC: #1, #2, #3, #4)
  - [x] 8.1 `tests/api/test_admin_job_detail.py` — `GET /jobs/{id}` : 200 avec détail brut + `timeline` ordonnée + `items` (ItemOcrData) ; 404 job inconnu ; 401 sans creds. Mock `db.get` (job, college) + `db.execute` (events asc, items) avec `SimpleNamespace`.
  - [x] 8.2 `tests/api/test_admin_job_stop.py` — `POST /jobs/{id}/stop` : monkeypatch `app.api.v1.admin.abort_arq_job` (AsyncMock) ; assert `status` forcé à `"failed"`, `error_message=="Annulé par l'admin"`, event `cancelled` ajouté (vérifier `db.add` appelé), `abort_arq_job` appelé avec `arq_job_id` ; 409 si job déjà `generation_complete`/`failed` ; 404 ; 401. **Aussi** : cas `arq_job_id is None` → pas d'appel abort mais statut quand même forcé.
  - [x] 8.3 `tests/api/test_admin_import_delete.py` — `DELETE /colleges/{id}` : 204, `db.delete(college)` + `db.commit()` appelés, PDF cleanup monkeypatché (`Path.glob`/`unlink`) → assert tenté ; 404 college inconnu ; 401.
  - [x] 8.4 `tests/services/test_job_events.py` — `record_job_event` : ajoute bien un `GenerationJobEvent` à la session (mock `db.add`), et **n'élève pas** si `db.add` lève (assert pas d'exception propagée).
  - [x] 8.5 Suivre **exactement** le pattern de tests 7.6 : `ADMIN_AUTH = ("admin", "testpass")`, fixtures `client`/`mock_db` de `tests/conftest.py` (NE PAS recréer de conftest), `types.SimpleNamespace` pour les modèles, `AsyncMock`/`MagicMock` pour `db.get`/`db.execute`/`db.commit`/`db.delete`. Lancer `pytest`, viser **0 régression** (cf. note Redis/stale ci-dessous).

## Dev Notes

### Authentification admin — pattern non négociable

- **TOUTES** les nouvelles routes : `_: bool = Depends(get_admin_user)` (HTTP Basic Auth, `app/deps.py:18`, timing-safe via `secrets.compare_digest`). Oublier ce `Depends` = faille d'accès.
- Credentials = `settings.admin_username`/`settings.admin_password`. En tests : `("admin", "testpass")`. 401 testé en n'envoyant pas `auth=`.
- Erreurs : `HTTPException(status_code=..., detail={"code": "...", "message": "..."})` — pattern uniforme du fichier, à conserver.

### Modèles réels (source de vérité — vérifiés)

- **`GenerationJob`** (`app/models/generation_job.py`) : `id: UUID`, `college_id: UUID FK(colleges) ondelete=CASCADE`, `user_id: UUID FK(users) ondelete=CASCADE`, `status: String(50)` avec **CheckConstraint** sur exactement `{pending, processing, ocr_complete, generation_complete, failed}`, `arq_job_id: String(255)|None`, `card_count: int=0`, `hash_shared: bool=False`, `pdf_hash: String(64)|None`, `error_message: Text|None`, `page_texts_json: Text|None`, `created_at`/`updated_at: DateTime(tz)`. Relations `college`, `user`.
- **`College`** (`app/models/college.py`) : relations `items`, `generation_jobs`, `flash_cards` toutes en `cascade="all, delete-orphan"`. `status`, `reload_count`, `ocr_page_progress`, `total_pages`.
- **`Item`** (`app/models/item.py`) : `college_id FK ondelete=CASCADE`, `item_number`, `rang`, `ocr_text`, **`ocr_confidence_score: float=0.0`**, **`low_confidence: bool=False`**, `start_page`/`end_page`. Relation `flash_cards` cascade. UniqueConstraint `(college_id, item_number)`.
- **`FlashCard`** : FK `item_id`/`college_id`/`user_id` toutes `ondelete=CASCADE`. **Aucune FK vers `generation_job_id`** → c'est pourquoi Delete doit être au niveau College.
- **`TesterFeedback`** : FK `flash_card_id`/`college_id` `ondelete=CASCADE`.

### ⚠️ CheckConstraint status — pourquoi Stop réutilise `failed` (et non un nouveau `cancelled`)

`generation_jobs.status` (et `colleges.status`) sont bornés par une **CheckConstraint** aux 5 valeurs ci-dessus. Introduire `cancelled` imposerait d'**altérer ces CheckConstraints** (sur 2 tables) **ET** d'ajuster l'index UNIQUE partiel `idx_one_active_job_per_college` (migration 012, `WHERE status IN ('pending','processing','ocr_complete')`). C'est lourd et touche du code 7.2.
→ **Décision PL actée (2026-06-17) :** Stop met `status="failed"` + `error_message="Annulé par l'admin"`, et la **sémantique d'annulation** est portée par l'événement timeline `cancelled` (lisible dans le détail). Avantages : aucun changement de constraint, le job quitte l'ensemble actif (l'index partiel se libère → réimport possible), zéro régression sur 7.2.

### Annulation ARQ — comment ça marche réellement

- ARQ ≥ 0.25 (`pyproject.toml`). `arq.jobs.Job(job_id, redis).abort(timeout=...)` ajoute le job à l'`abort set` Redis et attend le résultat. **Mais** le worker n'honore l'abort que si `WORKER_SETTINGS["allow_abort_jobs"] = True` (T4) — actuellement **absent** (`app/workers/settings.py:70-85`).
- Quand un job actif est aborté, ARQ lève `asyncio.CancelledError` **dans** la coroutine worker. Or `process_college_ocr` / `generate_college_cards` ne catchent que `except Exception` — et `CancelledError` hérite de `BaseException` (pas `Exception`) en Python 3.8+. Donc **le worker ne réécrit pas le statut** sur abort : c'est **l'endpoint** qui doit forcer `status="failed"`. Le `async with async_session_factory()` du worker rollback les écritures non commitées à l'annulation → pas de commit partiel. C'est le comportement voulu.
- `abort()` étant potentiellement bloquant jusqu'au `timeout`, utiliser un **timeout court** (≈5s) ; le résultat est best-effort (un job déjà terminé ou un timeout renvoie `False`/lève — on l'ignore). C'est pourquoi l'abort est isolé dans `abort_arq_job` (T2.2) et l'endpoint **force toujours** le statut DB ensuite.
- **GOTCHA `arq_job_id` (T3.2) :** `job.arq_job_id` ne stocke aujourd'hui que l'id ARQ de la phase **OCR**. La phase génération est ré-enqueuée dans `ocr_worker.py:215` avec un nouvel id **non persisté**. Sans le fix T3.2, Stop ne peut annuler que pendant l'OCR. Le fix (réécrire `job.arq_job_id` avec l'id du job de génération) rend Stop fiable sur les deux phases.

### Cascade delete — vérifié

`await db.delete(college)` déclenche : ORM `College.items`/`generation_jobs`/`flash_cards` (`all, delete-orphan`) → DELETE des items/jobs/flashcards ; les FK `ondelete=CASCADE` couvrent le niveau DB ; `generation_job_events` (nouvelle table) part via sa FK `ondelete=CASCADE` + la relationship cascade `GenerationJob.events` ; `TesterFeedback` part via FK `flash_card_id`/`college_id` CASCADE. **Tout l'arbre est supprimé atomiquement** par un seul `db.delete(college)` + `commit`.
PDF disque : nommage `{settings.pdf_storage_path}/{college_id}_{job_id}.pdf` (`admin.py:152`, `colleges.py:258`). Plusieurs jobs (réimports) ⇒ plusieurs PDFs par college → supprimer via `glob(f"{college_id}_*.pdf")`. `settings.pdf_storage_path` défaut `/tmp/collega_pdfs` (`config.py:52`).

### Instrumentation pipeline — écriture défensive

`record_job_event` fait **uniquement** `db.add(...)` (pas de commit) : les events sont persistés par les `await db.commit()` **déjà présents** dans le pipeline (boucle OCR, transitions de statut). Le helper enveloppe tout dans try/except → un échec d'écriture d'event ne casse jamais l'OCR/génération (exigence AC1). Dans les `except` du worker (chemin d'échec), ajouter l'event **avant** le `commit` existant (pour ocr_worker : la session commit directement sans rollback préalable, cf. `ocr_worker.py:62-68` — conserver ce pattern ; pour generation_worker : après le `db.rollback()` + re-get du job, cf. `generation_worker.py:67-71`).
Throttle `ocr_progress` : sur un PDF de 380 pages, 1 event/page = 380 lignes de bruit. Écrire seulement toutes les `max(1, total_pages // 20)` pages (+ la dernière) → ~20 events max. La progression **exacte** reste lisible via `college.ocr_page_progress/total_pages` (déjà commité à chaque page).

### Réutilisation — ne PAS réinventer

- `ItemOcrData` (schéma `app/schemas/admin.py:66-69`) existe déjà (`item_number, ocr_confidence_score, low_confidence`) → réutiliser pour AC2. La confiance OCR par item est même **déjà** exposée par `GET /colleges/{id}/stats` (`items_ocr_confidence`) — la logique de requête Items est à reprendre de `get_college_stats` (`admin.py:291`).
- `GET /queue` (`admin.py:255`) renvoie déjà `status`, `college_ocr_page_progress`, `college_total_pages`, `card_count`, `elapsed_seconds`, `error_message` → suffisant pour la **liste imports** + l'**indicateur de blocage** côté front (AC5). **Ne pas modifier `/queue`** (tests 1.4 dépendent du contrat).
- Console web : tous les helpers JS (`apiFetch`, `readJson`, `escapeHtml`, `fmtDate`, `statusBadge`, `showSection`, `toast`, `handleUnauthorized`) existent dans `app/static/admin/index.html` (559 lignes). `statusBadge(status)` mappe déjà `failed`→rouge, `generation_complete`→vert, reste→gris. Réutiliser tel quel.

### Frontend — patterns à calquer (admin/index.html, Story 7.6)

- Navigation : `showSection(id)` + onglets `nav-tabs` ; un `<section id="...">` par écran, `.active` pour l'affichage.
- Chargement : loader visible → `apiFetch(path)` → `readJson(res)` → `{ data }` → rendu → masquer loader. **Catch `e.code === "unauthorized"` et `return`** (UI déjà basculée sur login).
- Tableaux : `<tr>` via `innerHTML` pour les cellules simples (toujours `escapeHtml` sur le texte user), boutons d'action appendés dynamiquement sur la dernière `<td>` (cf. `loadUsers`).
- Détail : table clé/valeur (cf. `openUserDetail`/`renderDetailJobs`).
- Palette : vert `#1b6b3a`, badges `.badge-green`/`.badge-red`/`.badge-grey`, boutons `.btn-primary`/`.btn-sm`/`.btn-link`, `.toast`/`.toast.error`.

### Pattern de tests (rappels 7.6, vérifiés)

- pytest + pytest-asyncio `asyncio_mode = "auto"` → juste `async def test_...`, pas de décorateur.
- Fixtures **globales** `tests/conftest.py` : `client` (httpx `AsyncClient` + `ASGITransport`, override `get_db`), `mock_db` (`AsyncMock`). NE PAS recréer de conftest.
- Auth : `auth=("admin", "testpass")` sur `client.get/post/delete`. 401 = appel sans `auth=`.
- Modèles simulés : `types.SimpleNamespace(...)`. `db.get` → `AsyncMock(return_value=...)`. `db.execute` → `AsyncMock(return_value=MagicMock(...))` exposant `scalars().all()`/`scalar_one_or_none()`/`all()` selon l'appel. `db.commit`/`db.delete`/`db.add` → `AsyncMock`/`MagicMock`.
- Mock ARQ : monkeypatch `app.api.v1.admin.abort_arq_job` (importé dans `admin.py`) en `AsyncMock` — **ne jamais** toucher un vrai Redis dans les tests.
- Mock PDF cleanup : monkeypatch `pathlib.Path.glob`/`unlink` ou injecter via le module — vérifier l'intention, pas le FS réel.
- **0 régression.** Échecs **pré-existants connus** (cf. Debug Log 7.6) : ~16 tests rouges nécessitant Redis local (`test_search`/`test_reminder`/`test_flash_cards`/`test_login`) ou `test_auth` register stale — identiques avec/sans les changements. Ne pas les « réparer » ici.

### Piège environnement (mémoire projet)

Le `.venv` local doit résoudre **`bcrypt >=3.2.0,<4.0.0`** (passlib 1.7.4 crashe sinon). `pyproject.toml` épingle déjà la contrainte ; vérifier le venv si `hash_password` plante (non concerné directement par 7.7 mais la suite de tests admin importe `app.core.security`).

### Project Structure Notes

**Fichiers à créer (NEW) :**
```
collega_backend/
├── app/models/generation_job_event.py        ← modèle timeline (NEW)
├── app/services/jobs/__init__.py              ← NEW package
├── app/services/jobs/job_events.py            ← record_job_event (NEW)
├── app/services/jobs/arq_control.py           ← abort_arq_job (NEW)
├── alembic/versions/013_add_generation_job_events.py  ← migration (NEW)
└── tests/
    ├── api/test_admin_job_detail.py           ← NEW
    ├── api/test_admin_job_stop.py             ← NEW
    ├── api/test_admin_import_delete.py        ← NEW
    └── services/test_job_events.py            ← NEW
```

**Fichiers à modifier (UPDATE) :**
| Fichier | Modification |
|---------|-------------|
| `app/models/generation_job.py` | + relationship `events` (cascade all, delete-orphan) |
| `app/models/__init__.py` | + export `GenerationJobEvent` |
| `app/schemas/admin.py` | + `JobEventData`, `JobDetailData`, `JobDetailResponseWrapped`, `StopJobData`, `StopJobResponseWrapped` |
| `app/api/v1/admin.py` | + 3 routes (`GET /jobs/{id}`, `POST /jobs/{id}/stop`, `DELETE /colleges/{id}`) + imports |
| `app/workers/ocr_worker.py` | + events timeline + fix persistance `arq_job_id` génération (T3.2) |
| `app/workers/generation_worker.py` | + event `failed` |
| `app/services/generation/card_generator.py` | + events `generation_started`/`generation_complete` |
| `app/workers/settings.py` | + `allow_abort_jobs: True` |
| `app/static/admin/index.html` | + onglet/écrans Imports & détail import (stop/delete/timeline/OCR) |

**Conventions :** wrapper `{ "data": ... }` ; `HTTPException(detail={"code","message"})` ; snake_case ; `logger` jamais `print()` ; ISO 8601 UTC ; imports SQLAlchemy au niveau module ; frontend vanilla (pas de build).

### Library / Framework

- Backend : FastAPI, SQLAlchemy 2.0 async, Pydantic v2, Alembic, ARQ ≥0.25 (`arq.jobs.Job.abort`, `create_pool`), pytest/pytest-asyncio, httpx (tests). **Aucune nouvelle dépendance.**
- Frontend : HTML/CSS/JS vanilla servi par `StaticFiles` (pas de framework, pas de build).

### Previous Story Intelligence (7.6 + 7.2 + 1.4/1.5)

- **7.6** a livré le socle console (auth, schémas wrappés, helpers JS robustes : `apiFetch` à sentinelle 401, `readJson`, `escapeHtml`, `fmtDate`, `statusBadge`). 17 tests admin, 0 régression. Caveat connu : `app/static/admin/` joignable aussi via `/tester/admin/` (sans risque). Auth Basic en mémoire JS = risque accepté (Story 7.9 différée post-beta).
- **7.2** a posé l'atomicité quota (`UPDATE ... RETURNING`) et l'**index UNIQUE partiel** `idx_one_active_job_per_college` (migration **012**, statuts actifs `pending/processing/ocr_complete`). Stop doit laisser le job **sortir** de cet ensemble (→ `failed`) pour réautoriser un import. ⚠️ L'epic mentionne « migration 010 » : **faux** — la numérotation réelle va jusqu'à **012** ; chaîner depuis `012`.
- **1.4** a posé l'échafaudage admin JSON (queue/stats/config/users). `GET /queue` (50 jobs) et `GET /colleges/{id}/stats` (items_ocr_confidence) sont directement réutilisables. Défauts 1.4 acceptés (pas de pagination, config in-memory) — ne pas re-fixer.

### Git Intelligence

Epic 7 suit le pattern `feat(story-7.x): … + review-fix`. Derniers commits : `871cb31 feat(story-7.6) dashboard admin thème A + fixes`, `72da25a feat(story-7.4)`, `3ba3efa feat(story-7.3)`, `0672cb9 feat(story-7.2)`. 7.7 = thème B, additif, à committer seul. Ne pas emporter de fichiers Flutter/`colleges.py` non liés s'ils traînent dans le working tree.

### References

- [Source: `_bmad-output/planning-artifacts/epics-v1.1.md#Story-7.7`] — AC Thème B, NEW DB timeline, stop/delete, OCR confidence, détecteur blocage
- [Source: `_bmad-output/implementation-artifacts/7-6-dashboard-admin-onboarding-users.md`] — socle console, patterns tests/frontend, exclusions B/C
- [Source: `_bmad-output/brainstorming/brainstorming-session-2026-06-16-2242.md`] — périmètre Thème B (observabilité + contrôle imports)
- [Source: `collega_backend/app/api/v1/admin.py:94-214`] — `process_college` (création job + enqueue ARQ + nommage PDF)
- [Source: `collega_backend/app/api/v1/admin.py:217-250`] — `get_college_status` (progression OCR)
- [Source: `collega_backend/app/api/v1/admin.py:255-286`] — `get_queue` (liste imports réutilisable + `elapsed_seconds`)
- [Source: `collega_backend/app/api/v1/admin.py:291`] — `get_college_stats` (requête items OCR confidence à reprendre)
- [Source: `collega_backend/app/models/generation_job.py`] — colonnes + CheckConstraint status + `arq_job_id`
- [Source: `collega_backend/app/models/college.py`] — relationships cascade `all, delete-orphan`
- [Source: `collega_backend/app/models/item.py`] — `ocr_confidence_score`, `low_confidence`
- [Source: `collega_backend/app/workers/ocr_worker.py:34-230`] — pipeline OCR (points d'instrumentation + enqueue génération ligne 215)
- [Source: `collega_backend/app/workers/generation_worker.py:14-76`] — pipeline génération + except failed
- [Source: `collega_backend/app/services/generation/card_generator.py`] — création flashcards + statut generation_complete
- [Source: `collega_backend/app/workers/settings.py:70-85`] — `WORKER_SETTINGS` (ajout `allow_abort_jobs`)
- [Source: `collega_backend/alembic/versions/012_atomic_quota_and_unique_processing.py`] — dernière migration (chaîner `013` depuis `012`) + index partiel actif
- [Source: `collega_backend/app/deps.py:18`] — `get_admin_user` (Basic Auth timing-safe)
- [Source: `collega_backend/app/core/config.py:52`] — `pdf_storage_path`
- [Source: `collega_backend/app/static/admin/index.html`] — helpers JS + sections (calquer les écrans Imports)
- [Source: `collega_backend/tests/conftest.py` + `tests/api/test_admin_*.py`] — fixtures `client`/`mock_db`, `ADMIN_AUTH`, `SimpleNamespace`

## Décisions Project Lead (actées 2026-06-17)

Les 4 décisions ci-dessous sont **tranchées** (recommandations validées par le PL). L'agent dev les implémente telles quelles — elles ne sont plus ouvertes.

1. **✅ Statut d'un job annulé (Stop) = `failed`.** Stop met `status="failed"` + `error_message="Annulé par l'admin"` + event timeline `cancelled`. Zéro migration de CheckConstraint, libère l'index partiel 012, zéro régression 7.2. (Pas de nouvelle valeur `cancelled` dans les CheckConstraints.)
2. **✅ Granularité timeline = jalons + `ocr_progress` throttlé.** Events de jalons (`ocr_started`/`items_detected`/`ocr_complete`/`generation_started`/`generation_complete`/`failed`/`cancelled`) + `ocr_progress` throttlé à ~20 max (`max(1, total_pages // 20)` pages + dernière). Progression exacte via `college.ocr_page_progress`. (Pas de 1 event/page.)
3. **✅ Delete = niveau College.** Supprime tout le college (tous ses réimports + fiches/items/jobs + PDF). Imposé par le modèle (FlashCard/Item sans FK vers le job) — c'est le comportement attendu.
4. **✅ Indicateur de blocage = client-side** depuis `/queue`, seuil de stagnation **1h** (`pending`/`processing` + `elapsed_seconds > 3600`) **OU** `status == "failed"`. Pas de calcul backend.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (create-story) ; claude-opus-4-8[1m] (dev-story)

### Debug Log References

- Suite complète : **290 passed, 1 skipped, 16 failed** — les 16 rouges sont les échecs **pré-existants documentés** (Dev Notes § Pattern de tests) : `test_auth` (register stale 403 + login Redis), `test_search`, `test_reminder`, `test_flash_cards` (Redis local requis). Identiques avec/sans les changements 7.7 — non liés (aucun fichier auth/search/reminder/flashcards touché).
- 16 nouveaux tests 7.7 : tous verts. Baseline admin+workers re-vérifiée verte après instrumentation.
- Migration : chaîne 013→012 vérifiée, head unique (aucune autre migration ne descend de 012).

### Completion Notes List

- **T1** Table `generation_job_events` (modèle + migration 013, FK `ondelete=CASCADE` + index, relationship `events` cascade `all, delete-orphan` sur `GenerationJob`, export `__init__`).
- **T2** `record_job_event` (db.add sans commit, défensif — n'élève jamais) + `abort_arq_job` (isolé/mockable, best-effort, ferme le pool en `finally`).
- **T3** Instrumentation pipeline : `ocr_started`/`ocr_progress` (throttlé `max(1, total_pages//20)` + dernière page)/`items_detected`/`ocr_complete`/`failed` (ocr_worker, dont PDF vide + except top-level) ; `generation_started`/`generation_complete` (card_generator, normal + hash-sharing) ; `failed` (generation_worker). **Fix GOTCHA arq_job_id** : repointage sur le job ARQ de la phase génération à l'enqueue → Stop fiable sur les deux phases.
- **T4** `allow_abort_jobs: True` ajouté à `WORKER_SETTINGS`.
- **T5** Schémas `JobEventData`, `JobDetailData`, `JobDetailResponseWrapped`, `StopJobData`, `StopJobResponseWrapped` (réutilisent `ItemOcrData`, pattern wrapper).
- **T6** 3 routes : `GET /jobs/{id}` (détail brut + timeline asc + items OCR ; college absent géré sans 500), `POST /jobs/{id}/stop` (abort best-effort + force `failed` + event `cancelled`, 409 si non actif — décision PL : pas de nouvelle valeur `cancelled` dans la CheckConstraint), `DELETE /colleges/{id}` (cascade College + cleanup PDF best-effort en try/except). Toutes sous `get_admin_user`. Aucune route existante modifiée.
- **T7** Console : onglet **Imports** + écran liste (`/queue`, indicateur **Bloqué** client-side : `failed` OU actif > 3600s) + écran détail (timeline ordonnée, items OCR badge ⚠ faible, boutons Stop si actif / Delete avec `confirm`). Helpers 7.6 réutilisés (`apiFetch`/`readJson`/`escapeHtml`/`fmtDate`/`statusBadge`/`toast`). Écrans 7.6 non régressés.
- **T8** 16 tests (détail/stop/delete/job_events) suivant le pattern 7.6 (`ADMIN_AUTH`, `SimpleNamespace`, `AsyncMock`/`MagicMock`, monkeypatch `abort_arq_job` + `Path.glob`/`unlink`). Ajustement d'1 assertion existante (`test_card_generator` : comptage filtré par type `FlashCard` car les events timeline passent aussi par `db.add`).

### File List

**Nouveaux (NEW) :**
- `collega_backend/app/models/generation_job_event.py`
- `collega_backend/app/services/jobs/__init__.py`
- `collega_backend/app/services/jobs/job_events.py`
- `collega_backend/app/services/jobs/arq_control.py`
- `collega_backend/alembic/versions/013_add_generation_job_events.py`
- `collega_backend/tests/api/test_admin_job_detail.py`
- `collega_backend/tests/api/test_admin_job_stop.py`
- `collega_backend/tests/api/test_admin_import_delete.py`
- `collega_backend/tests/services/test_job_events.py`

**Modifiés (UPDATE) :**
- `collega_backend/app/models/generation_job.py` (relationship `events`)
- `collega_backend/app/models/__init__.py` (export `GenerationJobEvent`)
- `collega_backend/app/schemas/admin.py` (5 schémas 7.7)
- `collega_backend/app/api/v1/admin.py` (3 routes + imports)
- `collega_backend/app/workers/ocr_worker.py` (events + fix arq_job_id génération)
- `collega_backend/app/workers/generation_worker.py` (event `failed`)
- `collega_backend/app/services/generation/card_generator.py` (events `generation_started`/`generation_complete`)
- `collega_backend/app/workers/settings.py` (`allow_abort_jobs: True`)
- `collega_backend/app/static/admin/index.html` (onglet + écrans Imports/détail)
- `collega_backend/tests/services/test_card_generator.py` (assertion filtrée par type)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (statut 7.7)

## Change Log

| Date | Version | Description |
|------|---------|-------------|
| 2026-06-17 | 1.0 | Implémentation Story 7.7 (dev-story) : table `generation_job_events` (migration 013) + timeline persistée, `GET /jobs/{id}`, `POST /jobs/{id}/stop` (abort ARQ + `allow_abort_jobs` + fix persistance arq_job_id génération), `DELETE /colleges/{id}` (cascade + PDF), instrumentation pipeline, indicateur blocage client-side, écrans web Imports/détail. 16 nouveaux tests verts, 0 régression nouvelle (16 rouges = pré-existants Redis/register stale). Statut → review. |
| 2026-06-17 | 0.1 | Création Story 7.7 — Dashboard admin Thème B : timeline persistée (NEW table generation_job_events, migration 013), détail brut job + confiance OCR/item, Stop (abort ARQ + allow_abort_jobs + persistance arq_job_id génération), Delete (cascade College + PDF), indicateur blocage, écrans web imports. Story contextée ready-for-dev. |

## Review Findings (code review 2026-06-17)

Source : revue adversariale 3 couches (Blind Hunter / Edge Case Hunter / Acceptance Auditor) + vérification manuelle dans le code. Bilan : **3 decision-needed (tranchées « fix now » → corrigées), 1 patch (corrigé), 1 defer, ~15 dismissed** (faux positifs vérifiés / convention projet). Suite de tests post-fix : **271 passed** (api+workers+services), 16 rouges = pré-existants Redis/register stale documentés (aucun lié à 7.7). 5 nouveaux tests ajoutés pour les fixes.

### Decision-needed (tranchées 2026-06-17 → toutes « fix now », corrigées)

- [x] [Review][Decision→Fix] **Race Stop ↔ worker en cours** — `stop_job` force `status="failed"` mais si l'abort ARQ n'atterrit pas (fenêtre `timeout=5s`, Redis indisponible, ou `allow_abort_jobs` non déployé), le worker continuait et re-commitait un statut succès **par-dessus** le `failed`, générant des fiches pour un job « annulé ». **✅ Corrigé** : garde anti-race lisant `GenerationJob.status` en base avant chaque itération coûteuse — `ocr_worker._run_ocr` (haut de la boucle pages) et `card_generator.generate_for_college` (haut de la boucle items, avant l'appel Claude) ; si `status=="failed"`, arrêt immédiat sans écraser le statut (transaction non commitée → rollback à la fermeture de session). Tests : `test_ocr_worker::test_stops_when_job_cancelled_externally`, `test_card_generator::test_stops_generation_when_job_cancelled`. [ocr_worker.py / card_generator.py]
- [x] [Review][Decision→Fix] **Résultat de `abort_arq_job` ignoré → Stop silencieusement inefficace** — l'endpoint ignorait le booléen et le front affichait toujours « Import arrêté ✓ ». **✅ Corrigé** : `stop_job` capture le résultat et le remonte via `StopJobData.aborted` ; le front nuance le toast (« annulation non confirmée » si `aborted=False`). Statut DB toujours forcé. Tests : `test_admin_job_stop::test_aborted_false_when_abort_not_confirmed` + assertions `aborted` sur les cas existants. [admin.py / schemas/admin.py / static/admin/index.html]
- [x] [Review][Decision→Fix] **DELETE college pendant un job actif** — `delete_college` n'avait aucun garde-fou. **✅ Corrigé** : refus `409 JOB_ACTIVE` si un `GenerationJob` est dans `_ACTIVE_JOB_STATUSES` pour ce college (symétrique au verrou de `process_college`) ; le front gère le 409. Test : `test_admin_import_delete::test_409_when_active_job_exists`. [admin.py / static/admin/index.html]

### Patch (correctif non ambigu)

- [x] [Review][Patch] **Event `generation_started` absent sur le chemin hash-sharing** — **✅ Corrigé** : `generation_started` déplacé à l'entrée de `generate_for_college` (après chargement du job, avant le check hash-sharing) → couvre désormais tous les chemins (hash-sharing inclus). [card_generator.py]

### Defer (réel mais pré-existant / hors périmètre)

- [x] [Review][Defer] **Garantie « écriture défensive » de la timeline plus faible qu'annoncée** — `record_job_event` enveloppe `db.add(...)` (opération mémoire qui n'échoue quasi jamais) et non le flush/commit appelant ; un INSERT d'event défaillant remonterait au `commit()` de l'appelant et annulerait la transaction de transition légitime. Risque pratique quasi nul (`event_type` hardcodés < 50 chars, `message` Text, FK valide) ; `generation_worker` fait `rollback()` avant son commit. Le commit-sans-rollback de l'`except` d'`ocr_worker` est un pattern **pré-existant** explicitement conservé par la story. — deferred, pré-existant. [job_events.py:35 / ocr_worker.py:63-70]

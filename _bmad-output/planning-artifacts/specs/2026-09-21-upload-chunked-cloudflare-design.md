# Upload de PDF par morceaux via le tunnel Cloudflare — design (Story 7.11)

Date : 2026-09-21 · Statut : validé par le PL en brainstorming (sections A/B/C), en attente de relecture de cette spec avant plan d'implémentation.

## 1. Problème

Hors LAN, l'app atteint le backend par Cloudflare Tunnel + Cloudflare Access. Cloudflare rejette en `413 Payload Too Large` (page HTML signée `cloudflare`, avant le NAS, 0,2 s après lecture du `Content-Length`) toute requête dont le body dépasse **100 MB** (plan Free/Pro). Vérifié le 2026-09-21 : PNEUMO 67 MB traverse (422 `INVALID_REF_ID` renvoyé par l'API), ANAPATH 153 MB est coupé. Les PDF de collège font 67 à 411 MB. NPM (`client_max_body_size 2000m`) et le backend (`_MAX_PDF_SIZE` 500 MB) ne limitent pas.

Décisions PL : upload **par morceaux de 25 MB**, **reprise après coupure**, **transfert en arrière-plan** (connexions lentes → uploads longs). Option retenue : A du tableau de la story 7.11.

## 2. Vue d'ensemble

```
app (file > 90 MB)
  POST /import/init ──────────────► Redis upload:{id} (TTL 24 h)
  PUT  /import/{id}/parts/{n} ×N ─► volume pdf_storage/uploads/{id}/part_{n}
  GET  /import/{id}          ◄───── reprise : morceaux reçus
  POST /import/{id}/complete ─────► concat → {college.id}_{job_id}.pdf
                                     → chemin existant : College, quota, GenerationJob, enqueue OCR
                                     → 202 (payload identique à POST /import)
```

`POST /v1/colleges/{ref_id}/import` (mono-requête) reste inchangé pour les fichiers ≤ 90 MB. Le worker OCR ne change pas : il reçoit un chemin de PDF sur le volume partagé.

## 3. Backend

### 3.1 Routes (toutes sous `/v1/colleges`, router `colleges.py`)

| Route | Auth | Rôle |
|---|---|---|
| `POST /{ref_id}/import/init` — body `{"size_bytes": int}` | JWT + `require_subscription` | Gardes **sans consommer le quota** : `ref_id` 1..39, job actif → 409 `JOB_IN_PROGRESS`, limites reimport → 409 `COLLEGE_RELOAD_LIMIT` / `MONTHLY_RELOAD_LIMIT` (lecture seule, mêmes messages), `size_bytes` ≤ 500 MB sinon 413 `FILE_TOO_LARGE`, `size_bytes` ≤ 0 → 422. Réponse `201` : `{"data": {"upload_id", "part_size": 26214400, "parts_total", "expires_at"}}` |
| `PUT /import/{upload_id}/parts/{n}` — body binaire brut (`application/octet-stream`) | **`upload_id` seul** (cf. 3.4) | Écrit en streaming (`request.stream()`, 1 MB) dans `uploads/{upload_id}/part_{n}.tmp` puis `rename` atomique en `part_{n}`. Taille attendue = `part_size` sauf dernier morceau = reste ; sinon 422 `INVALID_PART`. `n` hors `[0, parts_total)` → 422 `INVALID_PART`. Idempotent (ré-écriture). Marque `n` reçu dans Redis. `204` |
| `GET /import/{upload_id}` | `upload_id` seul | `{"data": {"received": [0, 1, 4], "parts_total", "part_size", "size_bytes", "expires_at"}}` |
| `POST /import/{upload_id}/complete` | JWT + `require_subscription`, et `upload.user_id == current_user.id` sinon 404 | Voir 3.3 |

Statut inconnu/expiré (`upload_id` absent de Redis) → 404 `UPLOAD_NOT_FOUND` sur les trois routes `/import/{upload_id}*`.

### 3.2 État et stockage

- **Redis** (client `ArqRedis` obtenu via `arq.create_pool(redis_settings)`, comme `app/services/jobs/arq_control.py`) : hash `upload:{upload_id}` = `{user_id, ref_id, size_bytes, part_size, parts_total, created_at}` + set `upload:{upload_id}:parts` (indices reçus). `EXPIRE` 24 h sur les deux clés, posé à `init`.
- **Disque** : `{settings.pdf_storage_path}/uploads/{upload_id}/part_{n}` — sur le volume `pdf_storage` partagé api/worker (2 workers uvicorn → pas d'affinité). `upload_id` = UUID4.
- **Module** : `app/services/upload/chunked_upload.py` — `ChunkedUploadStore` (Redis + disque : `create`, `get`, `mark_part`, `received`, `assemble`, `purge`). Testable avec un fake Redis en mémoire.

### 3.3 `complete` — réutilisation du chemin existant

1. Charger l'état ; `received` ≠ tous → 409 `UPLOAD_INCOMPLETE` avec `detail.missing: [n…]`.
2. Lire les 5 premiers octets de `part_0` : pas `%PDF-` → 422 `INVALID_FILE_TYPE` + purge complète.
3. **Prise de possession atomique** : `DEL upload:{upload_id}` (une seule requête `complete` obtient `1`). Le perdant → 409 `JOB_IN_PROGRESS`.
4. Concaténer les morceaux dans `{college.id}_{job_id}.pdf` (le `college` est obtenu/créé à l'étape suivante ; on concatène d'abord dans `uploads/{upload_id}/assembled.pdf` puis `rename` vers le nom définitif une fois `college.id` et `job_id` connus).
5. Appeler la logique commune extraite de `import_college_pdf` (cf. 3.5) : get/create `College`, re-vérification job actif, **incrément atomique** des quotas reimport (UPDATE … RETURNING, décision 7.2), `GenerationJob`, enqueue `process_college_ocr`. Réponse `202` identique à `POST /import`.
6. Échec enqueue → 503 `QUEUE_UNAVAILABLE` : PDF assemblé supprimé, **morceaux et clé Redis restaurés** (re-`HSET` + `EXPIRE`) pour permettre un nouveau `complete` sans re-upload.
7. Succès → purge du dossier `uploads/{upload_id}`.

### 3.4 Sécurité

- Les `PUT parts` / `GET status` sont authentifiés par l'`upload_id` (UUID4, 122 bits, lié à `user_id`, TTL 24 h). Justification : en arrière-plan l'app ne peut pas rafraîchir l'access token (30 min) et un upload lent dure plus. Les morceaux sont inertes : seul `complete` (JWT) crée quelque chose, et il vérifie `upload.user_id`.
- `part_size` et `parts_total` sont fixés par le serveur à `init` ; le client ne choisit pas la taille.
- Cloudflare Access reste devant (service token), les routes ne sont pas exposées sans lui.

### 3.5 Refacto de `import_college_pdf` (`app/api/v1/colleges.py`)

Extraire, sans changer le comportement :
- `_assert_import_allowed(db, user, ref_id) -> College | None` : `ref_id`, job actif, **prévisualisation** des limites reimport (sans UPDATE) → lève les mêmes `HTTPException`.
- `_start_import_from_file(db, user, ref_id, pdf_file_path, total_size) -> ImportCollegeResponseData` : get/create `College`, job actif, quotas atomiques, `GenerationJob`, enqueue, nettoyage sur erreur — le code actuel des lignes ~148-338, inchangé.
`import_college_pdf` = validation type + écriture streamée + `_start_import_from_file`. Tests `test_colleges_import.py` / `test_colleges_reimport.py` doivent rester verts sans modification.

### 3.6 Purge

`app/workers/cleanup_worker.py` : nouvelle fonction cron `cleanup_stale_uploads` (horaire, enregistrée dans `app/workers/settings.py`) — supprime tout dossier `uploads/{id}` dont la clé Redis n'existe plus **ou** plus vieux que 24 h (mtime). Pic disque accepté : morceaux + assemblé ≈ 2 × taille du PDF.

## 4. App (Flutter)

### 4.1 Aiguillage (`CollegeImportNotifier.startImport`)

- `length > 500 MB` → `ImportError('file_too_large')`, rien n'est envoyé.
- `length > 90 MB` → chemin morceaux (4.2).
- sinon → `importPdf` actuel. Le 413 HTML Cloudflare, s'il survient malgré tout, est mappé sur `file_too_large` (ne pas supposer `e.response?.data` est une `Map`).
- Un `pending_uploads` déjà présent → `ImportError('upload_in_progress')`.

### 4.2 `ChunkedUploadService` (`lib/core/upload/`)

Responsabilité unique : mener un fichier de `init` à `complete`. Dépendances injectées :
- `UploadApi` (Dio, JWT + headers CF) : `init(refId, sizeBytes)`, `status(uploadId)`, `complete(uploadId)`.
- `PartTransport` : `enqueue(uploadId, partIndex, filePath, offset, length)`, `Stream<PartEvent> events` (progress / done / failed). Implémentations : `BackgroundPartTransport` (prod, 4.3) et `InMemoryPartTransport` (tests).

Flux : `init` → écrire `pending_uploads` → enqueue de tous les morceaux → progression agrégée (`ImportUploading(progress)`) → tous `done` → `complete` → suppression `pending_uploads` → flux existant (`collegeImports` Drift, `ImportStreaming`, SSE avec resync).

### 4.3 Transport arrière-plan

`background_downloader` **9.5.5** (compatible Flutter 3.27.1 / Dart 3.6 ; les 9.6.x exigent Flutter ≥ 3.47). Un `UploadTask` binaire par morceau : `PUT`, headers `Content-Type: application/octet-stream` + CF Access, `group: 'college-import'`, `retries: 3`, `TransferHint.largeFile` (pause/reprise réseau, cycles Android 9 min), `metaData` = `{uploadId, part}`. Les morceaux sont **découpés dans le cache de l'app** (`part_{n}` de 25 MB) avant enqueue : simple, indépendant des primitives d'offset du package, supprimés après `done`. Le fichier source choisi via `file_picker` est copié dans le répertoire de l'app (chemin temporaire non garanti après relance).

`FileDownloader().start()` est appelé au démarrage (`main.dart`) pour réconcilier les tâches interrompues.

### 4.4 Persistance et reprise

Table Drift `pending_uploads` : `upload_id (PK), ref_id, file_path, size_bytes, part_size, parts_total, created_at`. Une seule ligne à la fois.

`PendingUploadResumer` (déclenché au démarrage et au retour en premier plan) : lit la ligne → `GET status` → ré-enqueue uniquement les morceaux absents de `received` et non déjà en file dans le package → à complétion, `complete`. 404 → ligne supprimée + `ImportError('upload_expired')`. L'écran d'import affiche « Import en cours en arrière-plan — X % » tant qu'une ligne existe.

`complete` passe par `ensureFreshAccessToken()` ; session morte → `session_expired`, la ligne reste et `complete` est retenté après reconnexion.

### 4.5 Erreurs (mapping `detail.code` → `ImportError.message`)

`FILE_TOO_LARGE` → `file_too_large` · `UPLOAD_NOT_FOUND` → `upload_expired` · `UPLOAD_INCOMPLETE` → renvoi des `missing` (pas d'erreur utilisateur) · `INVALID_PART` → renvoi du morceau · `JOB_IN_PROGRESS` / limites / `SUBSCRIPTION_REQUIRED` / `QUEUE_UNAVAILABLE` → messages existants · échec réseau persistant d'un morceau (après retries du package) → `network_error`, morceaux reçus conservés.

## 5. Tests

- **Backend** (pytest, mocks DB existants + fake Redis en mémoire) : `init` (gardes, quota non consommé, tailles), `parts` (idempotence, bornes, taille, streaming), `status`, `complete` (incomplet → `missing`, magic, prise de possession atomique / double `complete`, réutilisation du chemin commun, enqueue KO → état restauré, purge), cron `cleanup_stale_uploads`. Non-régression : `test_colleges_import.py`, `test_colleges_reimport.py` inchangés et verts.
- **App** (`flutter test`) : `ChunkedUploadService` avec `InMemoryPartTransport` (découpage, progression, reprise depuis un `status` partiel, `upload_expired`), aiguillage 90 / 500 MB, mapping 413 HTML, `PendingUploadResumer`, tests existants du notifier verts.
- **Réel** : CANCERO 411 MB via `curl --resolve` + service token (script de morceaux), puis iPhone en 4G avec passage en arrière-plan ; logs NAS (`collega-api-1`, `collega-worker-1`, NPM host 53).

## 6. Hors périmètre v1

Uploads simultanés multiples ; notification push « upload terminé » ; compression du PDF ; changement du worker OCR ; reprise partielle d'un morceau (un morceau se renvoie en entier).

## 7. Références

- Story : `_bmad-output/implementation-artifacts/7-11-upload-pdf-100mb-tunnel-cloudflare.md`
- Chemin existant : `collega_backend/app/api/v1/colleges.py` (`import_college_pdf`), `collega_app/lib/features/colleges/colleges_import_providers.dart`, `collega_app/lib/features/colleges/data/college_import_repository.dart`
- Redis via arq : `collega_backend/app/services/jobs/arq_control.py`, `app/core/redis.py`
- Cron : `collega_backend/app/workers/settings.py`, `app/workers/cleanup_worker.py`
- Mémoire repo Kage : packets `decision-acc-s-backend-via-tunnel-cloudflare-…`, `bug_fix-import-timeout-…`

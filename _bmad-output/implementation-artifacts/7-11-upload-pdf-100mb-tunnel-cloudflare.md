# Story 7.11 : Upload de PDF > 100 MB via le tunnel Cloudflare

Status: review

<!-- OUVERTE le 2026-09-20 suite à la repro upload (session debug). 2026-09-21 : AC1 ACTÉ par le PL — option A (morceaux de 25 MB) + reprise + transfert en arrière-plan (background_downloader 9.5.5). Design validé : _bmad-output/planning-artifacts/specs/2026-09-21-upload-chunked-cloudflare-design.md — prochaine étape : plan d'implémentation. -->

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant qu'**utilisateur hors du réseau local** (4G, Wi-Fi tiers, iCloud Private Relay),
je veux pouvoir **importer n'importe quel PDF de collège, y compris ceux de 150-400 MB**,
afin que l'import ne soit pas silencieusement rejeté avant même d'atteindre le backend.

## Origine & contexte (à lire avant de coder)

Découvert le **2026-09-20** pendant la repro du bug « upload timeout / collège vide » (cf. commits `48e50f9`, `61a2d5c`). Hors LAN, l'app atteint le backend via **Cloudflare Tunnel** (`collegatest.matthislesur.com` → cloudflared → Nginx Proxy Manager host 53 → `collega-api-1:8000`), désormais authentifié par **service token Cloudflare Access** (story livrée dans `61a2d5c`).

**Le blocage :** Cloudflare impose une **limite de body HTTP de 100 MB par requête** sur les plans Free/Pro (200 MB Business, 500 MB Enterprise). Toute requête plus grosse reçoit un **413 émis par Cloudflare** — elle n'atteint jamais le NAS, donc **aucune trace dans les logs API/NPM**, d'où le diagnostic difficile.

**Ce qui est vérifié (2026-09-20) :**
- Upload **PNEUMO 8e (67 MB)** via le tunnel : `202` en 21 s (≈3,3 MB/s), pipeline OCR + génération OK.
- PDF de collège réels à la racine du repo : `ANAPATH 4e` = **153 MB**, `CANCERO 4e` = **411 MB** → impossibles via le tunnel en l'état.
- Backend : `POST /v1/colleges/{ref_id}/import` accepte jusqu'à `_MAX_PDF_SIZE = 500 MB`, lit le `UploadFile` par `_CHUNK_SIZE = 1 MB` et écrit dans `settings.pdf_storage_path` (`/tmp/collega_pdfs`, volume `pdf_storage` partagé api/worker) — `collega_backend/app/api/v1/colleges.py:47-48, 246-277`.
- NPM : `client_max_body_size 2000m` (`/etc/nginx/nginx.conf:39` du container) → **pas** le facteur limitant. Sur le LAN (DNS local → NPM direct), les gros PDF passent.
- App : `CollegeImportRepository.importPdf` envoie un `FormData` multipart en une seule requête Dio (`sendTimeout`/`receiveTimeout` 20 min) — `collega_app/lib/features/colleges/data/college_import_repository.dart`. Sélection via `file_picker ^8.1.6`.

**Symptôme côté app aujourd'hui :** `DioException` 413 avec une page HTML Cloudflare (pas de JSON `detail.code`) → tombe dans le `rethrow` générique → `ImportError(message: 'network_error')`. L'utilisateur ne sait pas que c'est une question de taille.

## Options d'approche (DÉCISION PL au kick-off — AC1)

| Option | Principe | Pour | Contre |
|---|---|---|---|
| **A. Upload par morceaux (recommandée)** | `POST /import/init` → N × `PUT /import/{upload_id}/part/{n}` (≤ 50 MB chacun) → `POST /import/{upload_id}/complete` qui assemble et enchaîne sur le pipeline existant | Aucune dépendance externe ; chaque requête < 100 MB ; reprise possible après coupure réseau mobile ; garde le stockage local + volume partagé | Nouveaux endpoints + état d'upload (Redis ou table) ; nettoyage des uploads orphelins (cron `cleanup_worker`) ; logique app plus complexe |
| B. Compression PDF côté app | Ré-encoder les images du PDF avant envoi | Zéro changement backend | Qualité OCR dégradée (les collèges sont majoritairement des scans) ; CPU/batterie ; 411 MB → 100 MB non garanti |
| C. Contourner Cloudflare pour l'upload | Hostname dédié non proxifié (port-forward) ou Tailscale | Simple | Expose l'IP du NAS ou impose Tailscale aux testeurs ; contredit le choix Access |
| D. Upload direct vers Cloudflare R2 (URL présignée) puis fetch par le worker | Pas de limite 100 MB sur R2 (multipart S3) | Scalable | Nouveau service, credentials, coût egress nul mais complexité ; le worker doit télécharger avant OCR |
| E. Montée de plan Cloudflare | Business = 200 MB | Aucun code | Ne couvre pas 411 MB ; coût mensuel |

**Recommandation :** **A**, avec une taille de part de 50 MB, `upload_id` UUID stocké en Redis (TTL 24 h) et assemblage en append dans `pdf_storage_path`. Complément **quelle que soit l'option** : message d'erreur explicite côté app quand la taille dépasse la limite connue (AC4).

## Acceptance Criteria

### AC1 — Décision d'approche actée et documentée

**ACTÉ 2026-09-21** : option **A** (morceaux de **25 MB**), **reprise automatique** après coupure, **transfert en arrière-plan** via `background_downloader` 9.5.5. Design complet (routes, état Redis, refacto, app, erreurs, tests) : `_bmad-output/planning-artifacts/specs/2026-09-21-upload-chunked-cloudflare-design.md`. Preuve du blocage : ANAPATH 153 MB → `413` signé cloudflare en 0,2 s ; PNEUMO 67 MB → traverse.

### AC2 — Un PDF de 411 MB s'importe via le tunnel Cloudflare

**Étant donné** l'app hors LAN (test : `curl --resolve` sur l'IP Cloudflare + service token, ou iPhone en 4G),
**Quand** l'utilisateur importe `CANCERO 4e college.pdf` (411 MB),
**Alors** le backend crée le `GenerationJob` et enchaîne OCR → génération comme aujourd'hui (`202` puis `generation_complete`),
**Et** aucune requête individuelle ne dépasse 100 MB.

### AC3 — Reprise après coupure (si option A)

**Étant donné** une coupure réseau entre deux parts,
**Alors** l'app reprend à la part suivante sans renvoyer le début (état d'upload côté serveur, TTL 24 h),
**Et** un upload jamais complété est purgé par `cleanup_worker` (fichiers partiels + clé Redis).

### AC4 — Erreur de taille explicite côté app

**Étant donné** un PDF dépassant la limite effective (backend 500 MB, ou par-requête 100 MB si option non-A),
**Alors** l'app affiche un message dédié (`ImportError(message: 'file_too_large')`) **avant** d'envoyer, sur la base de `File.length()`,
**Et** un 413 reçu malgré tout (HTML Cloudflare, pas de `detail.code`) est mappé sur la même erreur au lieu de `network_error`.

### AC5 — Tests & non-régression

- Backend : tests des nouveaux endpoints (init/part/complete, part hors ordre, upload inconnu → 404, complete incomplet → 409, quota reimport appliqué **une seule fois** à `complete` et non à `init`).
- App : `CollegeImportNotifier` — découpage, reprise, mapping 413 ; tests existants `college_import_notifier_test.dart` / `college_reimport_test.dart` verts.
- Le chemin `POST /import` mono-requête reste fonctionnel (LAN, petits PDF, tests existants `test_colleges_import.py`).

## Tasks / Subtasks

- [x] T0 — Kick-off : acter l'option (AC1)
- [x] T1 — Backend (option A) : endpoints init/part/complete + état Redis + assemblage ; réutiliser les gardes existantes (`require_subscription`, `JOB_IN_PROGRESS`, quotas reimport — déplacer la vérification atomique de quota dans `complete`) (AC2, AC3)
- [x] T2 — Backend : purge des uploads orphelins dans `app/workers/cleanup_worker.py` (AC3)
- [x] T3 — App : `CollegeImportRepository.importPdf` → découpage en parts, reprise, mapping 413/`file_too_large` ; UI progression d'upload par part (AC2, AC3, AC4)
- [x] T4 — Tests backend + app (AC5)
- [ ] T5 — Vérif prod via le tunnel avec CANCERO 411 MB (AC2) — `deployment.md` mis à jour, script `scripts/chunked_upload.py` prêt ; **déploiement + test réel restent à faire** (voir Completion Notes)

## Dev Notes

### État actuel des fichiers à modifier (à préserver)

- `collega_backend/app/api/v1/colleges.py` — `import_college_pdf` : validation `ref_id` 1..39, création `College`, garde job actif, quotas reimport **atomiques** (UPDATE…RETURNING, décision 7.2), validation magic `%PDF-`, écriture streamée 1 MB, création `GenerationJob` puis `enqueue_job("process_college_ocr", college_id, job_id, pdf_path)`. Tout ce qui suit l'écriture du fichier doit être **réutilisé tel quel** par `complete` (extraire une fonction interne plutôt que dupliquer).
- `collega_backend/app/workers/ocr_worker.py` — lit le PDF depuis `pdf_path` sur le volume partagé : inchangé.
- `collega_app/lib/features/colleges/data/college_import_repository.dart` — mapping des erreurs `detail.code` (403/409/503) : conserver ; ajouter 413.
- `collega_app/lib/features/colleges/colleges_import_providers.dart` — `startImport` écrit dans Drift `collegeImports` puis `_connectSse` (avec resync automatique depuis `61a2d5c`) : le flux post-upload ne change pas.

### Pièges

- Le **413 Cloudflare** est une page HTML : ne pas supposer `e.response?.data` est une `Map` (cf. cast `(e.response?.data as Map?)` dans le repository).
- Ne pas incrémenter `reload_count` / `monthly_reloads` à `init` : un upload abandonné consommerait le quota.
- `pdf_storage_path` est un volume Docker partagé api/worker (`pdf_storage` dans `docker-compose.prod.yml`) : les parts doivent y être écrites aussi, pas dans un `/tmp` local au container api (2 workers uvicorn → même volume, OK).
- Cloudflare : 100 s d'inactivité coupent aussi une requête d'upload lente ; 50 MB à ~3 MB/s ≈ 17 s, marge confortable ; ne pas monter à 90+ MB par part.
- Le chemin Cloudflare se teste depuis le LAN avec `curl --resolve collegatest.matthislesur.com:443:<IP Cloudflare>` + headers `CF-Access-Client-Id/Secret` (valeurs dans `collega_app/.env.local`, jamais committées).

### Testing

- Backend : `.venv/bin/python -m pytest tests/api/test_colleges_import.py tests/api/test_colleges_reimport.py -q` + nouveaux tests ; 16 rouges pré-existants hors périmètre (Redis local, `/register` 403, APNs).
- App : `flutter test test/features/colleges`.

### References

- Repro et mesures : mémoire repo Kage `decision-acc-s-backend-via-tunnel-cloudflare-…` et `bug_fix-import-timeout-…` (`.agent_memory/packets/`).
- Limites Cloudflare (upload size par plan) : documentation Cloudflare « Limits » — à re-vérifier au kick-off, les valeurs évoluent.
- `collega_backend/docs/deployment.md`, `install.md` (stack NAS).

## Dev Agent Record

### Agent Model Used

Claude Opus 5 (1M context) — 2026-09-21, branche `feat/story-7.11-upload-chunked`, plan `_bmad-output/planning-artifacts/plans/2026-09-21-upload-chunked-cloudflare.md` exécuté tâche par tâche (TDD, 1 commit par tâche).

### Debug Log References

- Backend : `.venv/bin/python -m pytest -q` → 349 passed / 16 failed (les 16 rouges pré-existants : Redis local absent, `/register` 403 by design, APNs 422) — 0 nouveau rouge. Nouveaux : `tests/services/test_chunked_upload_store.py` (12), `tests/api/test_colleges_chunked_upload.py` (19), `tests/workers/test_cleanup_uploads.py` (2).
- App : `flutter analyze` → 0 nouvelle issue (5 infos/warnings pré-existants) ; nouveaux tests `test/core/upload/*` (21), `test/core/database/pending_uploads_test.dart` (1), +9 cas dans `college_import_notifier_test.dart`.
- Piège rencontré : `AsyncNotifier.build()` est async → dans les tests, `startImport` doit être précédé de `await container.read(collegeImportProvider.future)` sinon `ImportIdle` écrase `ImportUploading(progress)` pendant les `await` (en prod l'écran watch le provider avant le pick, pas de problème).

### Completion Notes List

- **Écart vs plan (T1)** : le plan appelait `_assert_import_allowed` **puis** `_start_import_from_file` dans `POST /import`, ce qui doublait les SELECT et cassait les tests existants qui chaînent `db.execute.side_effect` (le plan exigeait pourtant qu'ils restent verts sans modification). Décomposition en helpers (`_get_or_create_college`, `_assert_no_active_job`, `_apply_reimport_quota`, `_create_job_and_enqueue`) : `POST /import` garde exactement sa séquence DB → **0 test existant modifié** (le patch `os.replace` prévu par le plan est devenu inutile). `_assert_import_allowed` (lecture seule) ne sert qu'à `init` ; `_start_import_from_file` (get/create + garde + quotas + renommage `{college.id}_{job_id}.pdf` + job + enqueue) ne sert qu'à `complete`.
- **`complete`** : `UPLOAD_INCOMPLETE` (409 + `missing`) avant le claim ; magic bytes vérifiés sur `part_0` avant le claim (422 + purge) ; claim atomique (DEL) → perdant = 409 `JOB_IN_PROGRESS` (état déjà disparu = 404) ; 503 `QUEUE_UNAVAILABLE` restaure l'état Redis + garde les morceaux (nouveau `complete` sans re-upload) ; toute autre `HTTPException` purge.
- **`background_downloader` 9.5.5** : `allowPause` est incompatible avec `post: 'binary'` (assert du package) → retiré de `buildTask`. Le package normalise `directory` sans `/` initial avec `BaseDirectory.root`.
- **Reprise** : `CollegesScreen` appelle `resumePendingUpload()` au montage et à chaque `onResume` ; `reset()` du notifier ne coupe plus un `ImportUploading(progress != null)` (l'écran d'import réaffiche la progression). Nouveau cas géré hors plan : copie locale du PDF disparue (`UploadSourceMissing` → toast « Fichier introuvable »).
- **Non fait / à faire (T5)** : build + push image backend, `docker compose up -d` sur le NAS, test réel CANCERO 411 MB via `scripts/chunked_upload.py --cloudflare-ip … --env-file …` (init 201 → 17 × 204 → complete 202, puis test `--resume` après Ctrl-C), test iPhone 4G avec passage en arrière-plan. Le schéma Drift passe en v6 (migration `createTable(pendingUploads)`).

### File List

Backend (`collega_backend/`)
- `app/api/v1/colleges.py` — refacto helpers d'import + 4 routes (`POST /colleges/{ref_id}/import/init`, `GET /colleges/import/{upload_id}`, `PUT /colleges/import/{upload_id}/parts/{n}`, `POST /colleges/import/{upload_id}/complete`) + `get_upload_store`
- `app/services/upload/__init__.py`, `app/services/upload/chunked_upload.py` — `ChunkedUploadStore`, `UploadState`, constantes
- `app/schemas/college.py` — `UploadInitRequest/Data`, `UploadStatusData` + wrappers
- `app/workers/cleanup_worker.py`, `app/workers/settings.py` — cron `cleanup_stale_uploads` (xx:30)
- `scripts/chunked_upload.py` — client curl de vérification réelle (`--cloudflare-ip`, `--env-file`, `--resume`)
- `docs/deployment.md` — section « Upload par morceaux »
- `tests/fakes/__init__.py`, `tests/fakes/fake_redis.py`, `tests/services/test_chunked_upload_store.py`, `tests/api/test_colleges_chunked_upload.py`, `tests/workers/test_cleanup_uploads.py`

App (`collega_app/`)
- `pubspec.yaml`, `pubspec.lock` — `background_downloader: 9.5.5`
- `lib/main.dart` — `FileDownloader().start(autoCleanDatabase: true)`
- `lib/core/database/tables/pending_uploads_table.dart`, `lib/core/database/app_database.dart` (+ `.g.dart`) — schéma v6
- `lib/core/upload/upload_models.dart` (modèles + exceptions d'import déplacées ici), `upload_api.dart` (`mapImportDioError`, `DioUploadApi`), `part_splitter.dart`, `part_transport.dart` (+ `InMemoryPartTransport`), `chunked_upload_service.dart`, `background_part_transport.dart`, `upload_providers.dart`
- `lib/features/colleges/domain/import_models.dart` — `ImportUploading.progress`
- `lib/features/colleges/data/college_import_repository.dart` — exceptions ré-exportées, `mapImportDioError`
- `lib/features/colleges/colleges_import_providers.dart` — aiguillage 90/500 MB, `_afterUploadAccepted`, `resumePendingUpload`, `reset()` protégé
- `lib/features/colleges/presentation/college_import_screen.dart` — barre de progression déterminée + 5 toasts
- `lib/features/colleges/presentation/colleges_screen.dart` — reprise au montage / onResume
- `test/core/upload/*.dart` (5 fichiers), `test/core/database/pending_uploads_test.dart`, `test/features/colleges/college_import_notifier_test.dart`, `test/features/colleges/colleges_screen_test.dart`

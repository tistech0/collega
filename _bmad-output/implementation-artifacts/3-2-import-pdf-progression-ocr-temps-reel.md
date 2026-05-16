# Story 3.2 : Import PDF & Progression OCR en Temps Réel

Status: done

## Story

En tant qu'**étudiant abonné**,
je veux importer un PDF depuis mon stockage local et suivre l'avancement du traitement en temps réel,
afin de savoir où en est mon collège sans bloquer l'app ni rester sur un écran d'attente.

## Acceptance Criteria

1. **Sélection PDF et upload (FR8)**
   - Étant donné que je tape sur "Charger ce collège"
   - Quand le file picker s'ouvre via `file_picker`
   - Alors je peux sélectionner un fichier PDF depuis mon stockage iOS
   - Et le PDF est envoyé au backend via `POST /v1/colleges/{ref_id}/import`
   - Et un job de génération est créé côté backend avec statut `pending`

2. **Écran "Import en cours" (UX-DR11)**
   - Étant donné un PDF sélectionné et uploadé avec succès
   - Quand l'upload se termine
   - Alors l'écran `ImportProgressScreen` s'affiche
   - Et le `ProgressStepper` à 4 étapes est visible : PDF reçu · OCR · Génération Claude · Classement
   - Et le banner "Vous pouvez fermer l'app, vous serez notifié" est visible et visuellement prioritaire
   - Et le bouton "Fermer et continuer" (outlined) est visible en bas d'écran

3. **Progression SSE temps réel (FR9, FR13)**
   - Étant donné l'écran "Import en cours" visible
   - Quand le backend envoie des events SSE `ocr_progress` via `GET /v1/colleges/{college_id}/stream`
   - Alors la barre de progression de l'étape OCR se met à jour en temps réel (page X / total Y)
   - Et l'estimation de temps restant est affichée uniquement sur l'étape active
   - Et les étapes précédentes affichent le check ✅ (primary-container)
   - Et les étapes futures affichent l'état "en attente" (outline-variant grisé)

4. **Fermeture sans interruption**
   - Étant donné l'écran "Import en cours"
   - Quand je tape "Fermer et continuer"
   - Alors je reviens à l'écran précédent (liste des collèges ou détail)
   - Et le traitement OCR continue sur le backend sans interruption

5. **Retour foreground et reconnexion SSE (FR9)**
   - Étant donné que je ferme l'app (background) pendant l'OCR
   - Quand je reviens en foreground
   - Alors l'app interroge `GET /v1/colleges/{college_id}/status`
   - Et si le job est encore actif (status = `pending` ou `processing`), elle se reconnecte au stream SSE
   - Et l'état affiché reflète le vrai statut backend (pas en cache périmé)

6. **Reprise OCR après interruption (FR10)**
   - Étant donné un job OCR interrompu (crash app ou redémarrage worker)
   - Quand le worker ARQ redémarre
   - Alors le job reprend depuis `ocr_page_progress` (déjà implémenté backend Story 1.2)
   - Et l'app affiche le bon état de progression au retour foreground

7. **Contrainte abonnement sur l'import**
   - Étant donné un utilisateur sans abonnement actif
   - Quand il appelle `POST /v1/colleges/{ref_id}/import`
   - Alors le backend retourne 403 avec `{"error": {"code": "SUBSCRIPTION_REQUIRED", ...}}`
   - Et l'app Flutter redirige vers le paywall

8. **Un seul import actif par collège**
   - Étant donné un job en cours (`pending` ou `processing`) pour un collège
   - Quand l'utilisateur tente de re-lancer un import du même collège
   - Alors le backend retourne 409 avec `{"error": {"code": "JOB_IN_PROGRESS", ...}}`
   - Et l'app affiche un `ShadToast` non bloquant

9. **Contrainte unicité backend (déferred Story 1.1)**
   - Étant donné la migration Alembic
   - Quand elle est appliquée
   - Alors un `UniqueConstraint("user_id", "college_ref_id")` existe sur la table `colleges`

## Tasks / Subtasks

- [x] **T1 — Backend : migration Alembic UniqueConstraint** (AC: #9)
  - [x] Créer une nouvelle migration Alembic dans `collega_backend/alembic/versions/` : `add_unique_constraint_colleges_user_ref`
  - [x] Ajouter `UniqueConstraint("user_id", "college_ref_id", name="uq_colleges_user_ref_id")` à la table `colleges`

- [x] **T2 — Backend : schémas import** (AC: #1, #5, #6, #7, #8)
  - [x] Ajouter à `collega_backend/app/schemas/college.py` :
    - `ImportCollegeResponseData(college_id: str, job_id: str, status: str)`
    - `ImportCollegeResponseWrapped(data: ImportCollegeResponseData)`
    - `CollegeStatusData(college_id: str, ref_id: int, status: str, ocr_page_progress: int, total_pages: int | None, job_id: str | None)`
    - `CollegeStatusResponseWrapped(data: CollegeStatusData)`

- [x] **T3 — Backend : `POST /v1/colleges/{ref_id}/import`** (AC: #1, #7, #8)
  - [x] Ajouter l'endpoint dans `collega_backend/app/api/v1/colleges.py`
  - [x] Protéger par `require_subscription`
  - [x] `ref_id: int` (path param) — valider que 1 ≤ ref_id ≤ 40 (sinon 422)
  - [x] Chercher si un `College` existe déjà pour `(user_id=current_user.id, college_ref_id=ref_id)`
  - [x] Si aucun → créer `College(user_id=..., college_ref_id=ref_id, status="pending")`
  - [x] Si existant et job actif (`pending` ou `processing`) → 409 JOB_IN_PROGRESS
  - [x] Valider le fichier : content-type ou extension `.pdf` + magic bytes `%PDF-`
  - [x] Sauvegarder le PDF dans `settings.pdf_storage_path / f"{college.id}_{job_id}.pdf"` (chunks de 1MB)
  - [x] Créer `GenerationJob(id=job_id, college_id=..., user_id=..., status="pending")`
  - [x] Enqueuer `process_college_ocr` via ARQ pool (pattern identique à `admin.process_college`)
  - [x] Si enqueue échoue → rollback DB + supprimer PDF → 503 QUEUE_UNAVAILABLE
  - [x] Retourner 202 `ImportCollegeResponseWrapped`

- [x] **T4 — Backend : `GET /v1/colleges/{college_id}/status`** (AC: #5)
  - [x] Ajouter l'endpoint dans `collega_backend/app/api/v1/colleges.py`
  - [x] Protéger par `get_current_user` (pas `require_subscription`)
  - [x] Valider ownership : `college.user_id == current_user.id` (sinon 404)
  - [x] Récupérer le dernier `GenerationJob` pour ce collège (order by `created_at` DESC)
  - [x] Retourner `CollegeStatusResponseWrapped` avec status, progress, total_pages, job_id, ref_id

- [x] **T5 — Backend : `GET /v1/colleges/{college_id}/stream` (SSE)** (AC: #3, #5)
  - [x] Ajouter l'endpoint dans `collega_backend/app/api/v1/colleges.py`
  - [x] Protéger par `get_current_user` (ownership check)
  - [x] Retourner `StreamingResponse(event_generator(), media_type="text/event-stream", headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})`
  - [x] `event_generator()` : boucle async qui poll DB toutes les 1.5s
  - [x] Timeout max 3h (NFR2) — break si dépassé
  - [x] Gérer `asyncio.CancelledError` (client déconnecté) proprement sans log d'erreur

- [x] **T6 — Backend : tests** (AC: tous)
  - [x] Créer `collega_backend/tests/api/test_colleges_import.py` avec 8 tests (401, 403, 422×2, 202, 409, 404 ownership, 200 status)

- [x] **T7 — Flutter : initialisation Drift** (AC: #5)
  - [x] Créer `collega_app/lib/core/database/tables/college_import_table.dart`
  - [x] Mettre à jour `collega_app/lib/core/database/app_database.dart` avec `@DriftDatabase`, `part`, constructeur `forTesting`
  - [x] Exécuter `flutter pub run build_runner build` → `app_database.g.dart` généré
  - [x] `databaseProvider` inclus dans `app_database.dart`

- [x] **T8 — Flutter : SseClient implémentation** (AC: #3, #5)
  - [x] Remplacer le stub dans `collega_app/lib/core/network/sse_client.dart`
  - [x] Constructeur avec `tokenProvider`, `connect()` avec Dio stream, `disconnect()` avec CancelToken

- [x] **T9 — Flutter : modèles domaine import** (AC: #1, #3, #5)
  - [x] Créer `collega_app/lib/features/colleges/domain/import_models.dart` avec sealed class `CollegeImportState` et modèles `fromJson`

- [x] **T10 — Flutter : CollegeImportRepository** (AC: #1, #5, #7)
  - [x] Créer `collega_app/lib/features/colleges/data/college_import_repository.dart`
  - [x] `importPdf` + `getStatus` + exceptions typées

- [x] **T11 — Flutter : CollegeImportNotifier** (AC: #1, #3, #4, #5, #7, #8)
  - [x] Créer `collega_app/lib/features/colleges/colleges_import_providers.dart`
  - [x] `startImport`, `_connectSse`, `_handleSseEvent`, `reconnectIfActive`, `ref.onDispose`
  - [x] Persistance Drift à chaque update SSE

- [x] **T12 — Flutter : CollegeImportScreen** (AC: #1)
  - [x] Créer `collega_app/lib/features/colleges/presentation/college_import_screen.dart`
  - [x] FilePicker, navigation vers ImportProgressScreen, gestion erreurs 403/409

- [x] **T13 — Flutter : ImportProgressScreen** (AC: #2, #3, #4, #5)
  - [x] Créer `collega_app/lib/features/colleges/presentation/import_progress_screen.dart`
  - [x] ProgressStepper 4 étapes, banner prioritaire, bouton "Fermer et continuer", AppLifecycleListener

- [x] **T14 — Flutter : mise à jour du router** (AC: #1, #2)
  - [x] Remplacer `_CollegeImportStub` par `CollegeImportScreen`
  - [x] Ajouter route `/colleges/:ref_id/import/progress` → `ImportProgressScreen`

- [x] **T15 — Flutter : tests** (AC: tous)
  - [x] `collega_app/test/features/colleges/college_import_notifier_test.dart` : 3 tests
  - [x] `collega_app/test/features/colleges/college_import_screen_test.dart` : 2 tests widget

- [x] **T16 — Validation finale** (AC: tous)
  - [x] `flutter analyze` → 0 erreur
  - [x] `flutter test` → tous les tests passent (0 régression)
  - [x] `pytest collega_backend/tests/api/test_colleges_import.py` → 8/8 verts
  - [x] Migration Alembic 006 créée (à appliquer avec `alembic upgrade head`)

## Dev Notes

### État du codebase au début de cette story

**DÉJÀ IMPLÉMENTÉ — NE PAS RECRÉER :**

| Composant | État | Emplacement |
|---|---|---|
| `require_subscription` dependency | ✅ Existe | `collega_backend/app/deps.py` |
| `get_current_user` dependency | ✅ Existe | `collega_backend/app/deps.py` |
| `College` model SQLAlchemy | ✅ Existe avec `ocr_page_progress`, `total_pages`, `status` | `collega_backend/app/models/college.py` |
| `GenerationJob` model SQLAlchemy | ✅ Existe avec `status`, `arq_job_id`, `page_texts_json` | `collega_backend/app/models/generation_job.py` |
| `process_college_ocr` ARQ worker | ✅ Implémenté avec reprise (NFR11) | `collega_backend/app/workers/ocr_worker.py` |
| Pattern PDF upload (admin) | ✅ Existe — copier le pattern | `collega_backend/app/api/v1/admin.py:82-192` |
| Pattern status endpoint (admin) | ✅ Existe — adapter pour user | `collega_backend/app/api/v1/admin.py:195-228` |
| `SseClient` stub | ✅ Existe, **À IMPLÉMENTER** | `collega_app/lib/core/network/sse_client.dart` |
| `ApiClient` + `apiClientProvider` | ✅ Existe avec intercepteur JWT | `collega_app/lib/core/network/api_client.dart` |
| `AppDatabase` (skeleton) | ✅ Existe sans tables | `collega_app/lib/core/database/app_database.dart` |
| Route `/colleges/:ref_id/import` stub | ✅ Existe, **À REMPLACER** | `collega_app/lib/core/router/app_router.dart:50` |
| `file_picker` package | ✅ Dans pubspec.yaml | version ^8.1.6 |
| `drift` + `drift_dev` packages | ✅ Dans pubspec.yaml | drift ^2.21.0, drift_dev ^2.21.0 |
| `CollegesNotifier` + `collegesProvider` | ✅ Existe — invalider après import OK | `collega_app/lib/features/colleges/colleges_providers.dart` |
| `CollegeCatalogEntry` + `kCollegeCatalog` | ✅ Existe — 40 entrées | `collega_app/lib/features/colleges/domain/college_catalog.dart` |
| `AppColors`, `AppSpacing`, `AppTypography` | ✅ Existe | `collega_app/lib/core/theme/app_theme.dart` |
| `AppLogger` | ✅ Existe | `collega_app/lib/core/utils/logger.dart` |
| `ShadToast`, `ShadButton`, `ShadCard` | ✅ Dans `shadcn_ui` ^0.19.0 | — |

**FICHIERS À CRÉER :**

```
collega_backend/alembic/versions/XXXX_add_unique_constraint_colleges_user_ref.py

collega_app/lib/core/database/tables/college_import_table.dart
collega_app/lib/core/database/database_provider.dart
collega_app/lib/core/network/sse_providers.dart          ← nouveau
collega_app/lib/features/colleges/domain/import_models.dart
collega_app/lib/features/colleges/data/college_import_repository.dart
collega_app/lib/features/colleges/colleges_import_providers.dart
collega_app/lib/features/colleges/presentation/college_import_screen.dart
collega_app/lib/features/colleges/presentation/import_progress_screen.dart

collega_backend/tests/api/test_colleges_import.py
collega_app/test/features/colleges/college_import_notifier_test.dart
collega_app/test/features/colleges/college_import_screen_test.dart
```

**FICHIERS À MODIFIER :**

| Fichier | Ce que Story 3.2 change |
|---|---|
| `collega_backend/app/schemas/college.py` | Ajouter `ImportCollegeResponseData`, `ImportCollegeResponseWrapped`, `CollegeStatusData`, `CollegeStatusResponseWrapped` |
| `collega_backend/app/api/v1/colleges.py` | Ajouter 3 endpoints : import, status, stream SSE |
| `collega_app/lib/core/database/app_database.dart` | Ajouter annotation `@DriftDatabase`, import table, `part` directive |
| `collega_app/lib/core/network/sse_client.dart` | Implémenter `connect()` et `disconnect()` (remplacer le stub) |
| `collega_app/lib/core/router/app_router.dart` | Remplacer `_CollegeImportStub`, ajouter `/import/progress` route |

---

### Backend : Endpoint `POST /v1/colleges/{ref_id}/import`

**Différence clé avec l'admin** : l'admin reçoit un `college_id` UUID existant ; ici on reçoit un `ref_id` int du catalogue et on crée le `College` si nécessaire.

```python
@router.post(
    "/colleges/{ref_id}/import",
    response_model=ImportCollegeResponseWrapped,
    status_code=202,
)
async def import_college_pdf(
    ref_id: int,
    pdf: UploadFile,
    current_user: User = Depends(require_subscription),
    db: AsyncSession = Depends(get_db),
) -> ImportCollegeResponseWrapped:
    # Valider ref_id entre 1 et 40
    if not (1 <= ref_id <= 40):
        raise HTTPException(
            status_code=422,
            detail={"code": "INVALID_REF_ID", "message": "ref_id must be between 1 and 40"},
        )
    
    # Chercher ou créer le College
    result = await db.execute(
        select(College)
        .where(College.user_id == current_user.id)
        .where(College.college_ref_id == ref_id)
    )
    college = result.scalar_one_or_none()
    
    if college is None:
        college = College(user_id=current_user.id, college_ref_id=ref_id)
        db.add(college)
        await db.flush()  # obtenir l'ID sans commit
    
    # Vérifier qu'aucun job actif n'existe
    existing = await db.execute(
        select(GenerationJob)
        .where(GenerationJob.college_id == college.id)
        .where(GenerationJob.status.in_(["pending", "processing"]))
    )
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=409,
            detail={"code": "JOB_IN_PROGRESS", "message": "Un import est déjà en cours pour ce collège"},
        )
    
    # Valider PDF (content-type + magic bytes — même pattern que admin)
    is_pdf = (pdf.content_type == "application/pdf") or (pdf.filename or "").lower().endswith(".pdf")
    if not is_pdf:
        raise HTTPException(422, detail={"code": "INVALID_FILE_TYPE", ...})
    
    first_chunk = await pdf.read(1024 * 1024)
    if not first_chunk.startswith(b"%PDF-"):
        raise HTTPException(422, detail={"code": "INVALID_FILE_TYPE", ...})
    
    # Sauvegarder le PDF
    job_id = uuid.uuid4()
    pdf_path = Path(settings.pdf_storage_path) / f"{college.id}_{job_id}.pdf"
    Path(settings.pdf_storage_path).mkdir(parents=True, exist_ok=True)
    with open(pdf_path, "wb") as f:
        f.write(first_chunk)
        while chunk := await pdf.read(1024 * 1024):
            f.write(chunk)
    
    # Créer le job et enqueuer
    job = GenerationJob(id=job_id, college_id=college.id, user_id=current_user.id, status="pending")
    db.add(job)
    await db.commit()
    
    # Enqueue ARQ (pattern admin.py — même gestion d'erreur + rollback)
    # ... (voir admin.py lignes 160-188 pour le pattern exact)
    
    return ImportCollegeResponseWrapped(
        data=ImportCollegeResponseData(
            college_id=str(college.id),
            job_id=str(job_id),
            status="pending",
        )
    )
```

---

### Backend : Endpoint SSE `GET /v1/colleges/{college_id}/stream`

**Approche DB polling** (pas de Redis Pub/Sub — conforme à la contrainte "solo dev / simplicité") :

```python
import asyncio, json
from fastapi.responses import StreamingResponse

@router.get("/colleges/{college_id}/stream")
async def stream_college_progress(
    college_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Ownership check initial
    college = await db.get(College, college_id)
    if college is None or college.user_id != current_user.id:
        raise HTTPException(404, detail={"code": "COLLEGE_NOT_FOUND", ...})

    async def event_generator():
        last_progress = -1
        last_status = None
        ocr_complete_emitted = False
        start_time = asyncio.get_event_loop().time()
        MAX_DURATION = 3 * 3600  # NFR2: max 2h, garde 3h

        try:
            while True:
                if asyncio.get_event_loop().time() - start_time > MAX_DURATION:
                    break

                async with async_session_factory() as session:
                    c = await session.get(College, college_id)

                if c is None:
                    break

                if c.ocr_page_progress != last_progress and c.total_pages:
                    last_progress = c.ocr_page_progress
                    event = {"event": "ocr_progress", "data": {"page": last_progress, "total": c.total_pages}}
                    yield f"data: {json.dumps(event)}\n\n"

                if c.status == "ocr_complete" and not ocr_complete_emitted:
                    ocr_complete_emitted = True
                    event = {"event": "card_generation_started", "data": {"college_id": str(college_id)}}
                    yield f"data: {json.dumps(event)}\n\n"

                if c.status == "generation_complete":
                    event = {"event": "generation_complete", "data": {"college_id": str(college_id)}}
                    yield f"data: {json.dumps(event)}\n\n"
                    break

                if c.status == "failed":
                    event = {"event": "generation_failed", "data": {"college_id": str(college_id)}}
                    yield f"data: {json.dumps(event)}\n\n"
                    break

                await asyncio.sleep(1.5)

        except asyncio.CancelledError:
            pass  # Client disconnected — normal, ne pas logger comme erreur

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",  # désactive buffering Nginx/Caddy
            "Connection": "keep-alive",
        },
    )
```

**IMPORTANT** : Le endpoint SSE ne peut pas utiliser `db: AsyncSession = Depends(get_db)` pour la boucle (session fermée après la requête). Il faut utiliser `async_session_factory()` dans la boucle — comme montré ci-dessus.

---

### Flutter : SseClient implémentation

```dart
import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

class SseClient {
  SseClient(this._baseUrl, {required this._tokenProvider});

  final String _baseUrl;
  final String Function() _tokenProvider;
  CancelToken? _cancelToken;

  Stream<Map<String, dynamic>> connect(String path) async* {
    _cancelToken?.cancel('reconnect');
    _cancelToken = CancelToken();

    final dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(hours: 3),
      headers: {
        'Authorization': 'Bearer ${_tokenProvider()}',
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache',
      },
    ));

    try {
      final response = await dio.get<ResponseBody>(
        path,
        options: Options(responseType: ResponseType.stream),
        cancelToken: _cancelToken,
      );

      String buffer = '';
      await for (final chunk in response.data!.stream) {
        buffer += utf8.decode(chunk);
        final parts = buffer.split('\n\n');
        buffer = parts.removeLast();

        for (final part in parts) {
          String? dataLine;
          for (final line in part.split('\n')) {
            if (line.startsWith('data:')) {
              dataLine = line.substring(5).trim();
            }
          }
          if (dataLine != null && dataLine.isNotEmpty) {
            try {
              final json = jsonDecode(dataLine) as Map<String, dynamic>;
              yield json;
            } catch (_) {
              AppLogger.warning('SSE: invalid JSON in data line', tag: 'SseClient');
            }
          }
        }
      }
    } on DioException catch (e) {
      if (!CancelToken.isCancel(e)) {
        AppLogger.error('SSE connection error', tag: 'SseClient', error: e);
        rethrow;
      }
    }
  }

  void disconnect() {
    _cancelToken?.cancel('disconnect');
    _cancelToken = null;
  }
}
```

**Provider SSE** (`sse_providers.dart`) :

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/network/sse_client.dart';
import 'package:collega_app/env.dart';

final sseClientProvider = Provider<SseClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return SseClient(
    backendBaseUrl,
    tokenProvider: () {
      // Synchronous read — token is always in memory after login
      // SseClient lit le token au moment de connect(), pas à la construction
      String token = '';
      storage.read(key: 'access_token').then((v) => token = v ?? '');
      return token;
    },
  );
});
```

**NOTE** : La lecture du token est asynchrone mais `tokenProvider` est synchrone. Une meilleure approche : passer le token directement depuis le Notifier qui a déjà accès au storage. Implémenter comme suit dans `CollegeImportNotifier` :

```dart
// Dans _connectSse :
final token = await ref.read(secureStorageProvider).read(key: 'access_token') ?? '';
final sseClient = SseClient(backendBaseUrl, tokenProvider: () => token);
```

Cela évite le race condition du `tokenProvider` synchrone.

---

### Flutter : Drift database — initialisation

Le fichier `app_database.dart` doit passer d'un skeleton à une vraie base Drift :

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/college_import_table.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [CollegeImports])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static LazyDatabase _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'collega.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());
```

**ATTENTION** : Supprimer l'ancienne implémentation singleton de `AppDatabase._()` — elle est incompatible avec Drift généré. La nouvelle classe hérite de `_$AppDatabase` (généré).

Après avoir modifié `app_database.dart`, exécuter **obligatoirement** :
```bash
cd collega_app
flutter pub run build_runner build --delete-conflicting-outputs
```
Cela génère `app_database.g.dart`. Sans ce fichier, le code ne compile pas.

---

### Flutter : Drift CollegeImports table

```dart
// collega_app/lib/core/database/tables/college_import_table.dart
import 'package:drift/drift.dart';

class CollegeImports extends Table {
  TextColumn get id => text()();           // UUID backend du College
  IntColumn get refId => integer()();      // ref 1-40 du catalogue
  TextColumn get jobId => text()();        // UUID du GenerationJob
  TextColumn get status => text()();       // 'pending'|'processing'|'ocr_complete'|'generation_complete'|'failed'
  IntColumn get ocrProgress => integer().withDefault(const Constant(0))();
  IntColumn get totalPages => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

---

### Flutter : CollegeImportNotifier — pattern complet

```dart
class CollegeImportNotifier extends AsyncNotifier<CollegeImportState> {
  StreamSubscription<Map<String, dynamic>>? _sseSubscription;
  SseClient? _sseClient;

  @override
  Future<CollegeImportState> build() async => const ImportIdle();

  Future<void> startImport(int refId, File file) async {
    state = const AsyncValue.data(ImportUploading());
    try {
      final repo = ref.read(collegeImportRepositoryProvider);
      final response = await repo.importPdf(refId, file);
      
      // Persister dans Drift
      final db = ref.read(databaseProvider);
      await db.into(db.collegeImports).insertOnConflictUpdate(
        CollegeImportsCompanion.insert(
          id: response.collegeId,
          refId: refId,
          jobId: response.jobId,
          status: response.status,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      
      state = AsyncValue.data(ImportStreaming(
        collegeId: response.collegeId,
        jobId: response.jobId,
        ocrProgress: 0,
        totalPages: null,
        status: 'pending',
      ));
      
      await _connectSse(response.collegeId);
    } on SubscriptionRequiredException {
      state = const AsyncValue.data(ImportError(message: 'subscription_required'));
    } on JobInProgressException {
      state = const AsyncValue.data(ImportError(message: 'job_in_progress'));
    } on DioException catch (e) {
      state = AsyncValue.data(ImportError(message: e.message ?? 'network_error'));
    }
  }

  Future<void> _connectSse(String collegeId) async {
    await _sseSubscription?.cancel();
    final token = await ref.read(secureStorageProvider).read(key: 'access_token') ?? '';
    _sseClient = SseClient(backendBaseUrl, tokenProvider: () => token);
    
    _sseSubscription = _sseClient!
        .connect('/v1/colleges/$collegeId/stream')
        .listen(
          (event) => _handleSseEvent(event, collegeId),
          onError: (e) => AppLogger.error('SSE error', tag: 'ImportNotifier', error: e),
        );
  }

  void _handleSseEvent(Map<String, dynamic> event, String collegeId) {
    final eventType = event['event'] as String?;
    final data = event['data'] as Map<String, dynamic>? ?? {};
    
    final current = state.valueOrNull;
    if (current is! ImportStreaming) return;
    
    switch (eventType) {
      case 'ocr_progress':
        final page = data['page'] as int? ?? 0;
        final total = data['total'] as int?;
        state = AsyncValue.data(current.copyWith(
          ocrProgress: page,
          totalPages: total,
          status: 'processing',
        ));
        // Persister dans Drift
        _updateDriftProgress(collegeId, page, total, 'processing');
      case 'card_generation_started':
        state = AsyncValue.data(current.copyWith(status: 'ocr_complete'));
      case 'generation_complete':
        state = const AsyncValue.data(ImportComplete(collegeId: ''));  // collegeId from current
        ref.invalidate(collegesProvider);  // rafraîchir la liste des collèges
      case 'generation_failed':
        state = const AsyncValue.data(ImportError(message: 'generation_failed'));
    }
  }

  Future<void> reconnectIfActive(String collegeId) async {
    final repo = ref.read(collegeImportRepositoryProvider);
    try {
      final status = await repo.getStatus(collegeId);
      if (status.status == 'pending' || status.status == 'processing') {
        state = AsyncValue.data(ImportStreaming(
          collegeId: collegeId,
          jobId: status.jobId ?? '',
          ocrProgress: status.ocrProgress,
          totalPages: status.totalPages,
          status: status.status,
        ));
        await _connectSse(collegeId);
      } else if (status.status == 'generation_complete') {
        state = AsyncValue.data(ImportComplete(collegeId: collegeId));
        ref.invalidate(collegesProvider);
      }
    } catch (e) {
      AppLogger.warning('reconnectIfActive failed: $e', tag: 'ImportNotifier');
    }
  }

  @override
  void dispose() {
    _sseSubscription?.cancel();
    _sseClient?.disconnect();
    super.dispose();
  }
}
```

---

### Flutter : ProgressStepper — logique des états

| Status backend | Étape 1 (PDF reçu) | Étape 2 (OCR) | Étape 3 (Claude) | Étape 4 (Classement) |
|---|---|---|---|---|
| `pending` | ✅ done | 🔄 active (sans chiffre) | ⏳ pending | ⏳ pending |
| `processing` | ✅ done | 🔄 active (page X/Y) | ⏳ pending | ⏳ pending |
| `ocr_complete` | ✅ done | ✅ done | 🔄 active | ⏳ pending |
| `generation_complete` | ✅ done | ✅ done | ✅ done | ✅ done |

L'estimation de temps : uniquement sur l'étape active. Calcul simple : si `ocrProgress > 0` et `totalPages > 0`, `remaining = ((totalPages - ocrProgress) / max(ocrProgress, 1)) * elapsed_seconds`. Afficher en minutes arrondies.

---

### Flutter : CollegeImportRepository — gestion des erreurs

```dart
class SubscriptionRequiredException implements Exception {}
class JobInProgressException implements Exception {}
class QueueUnavailableException implements Exception {}

class CollegeImportRepository {
  const CollegeImportRepository({required this.dio});
  final Dio dio;

  Future<ImportStartResponse> importPdf(int refId, File pdfFile) async {
    try {
      final formData = FormData.fromMap({
        'pdf': await MultipartFile.fromFile(
          pdfFile.path,
          filename: pdfFile.path.split('/').last,
          contentType: DioMediaType('application', 'pdf'),
        ),
      });
      final response = await dio.post<Map<String, dynamic>>(
        '/v1/colleges/$refId/import',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(minutes: 5),  // PDF peut être lourd
        ),
      );
      return ImportStartResponse.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final code = (e.response?.data as Map?)?.['error']?['code'];
      if (status == 403 && code == 'SUBSCRIPTION_REQUIRED') throw SubscriptionRequiredException();
      if (status == 409 && code == 'JOB_IN_PROGRESS') throw JobInProgressException();
      if (status == 503) throw QueueUnavailableException();
      AppLogger.error('importPdf failed', tag: 'CollegeImportRepository', error: e);
      rethrow;
    }
  }

  Future<CollegeStatusResponse> getStatus(String collegeId) async {
    try {
      final response = await dio.get<Map<String, dynamic>>('/v1/colleges/$collegeId/status');
      return CollegeStatusResponse.fromJson(response.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      AppLogger.error('getStatus failed', tag: 'CollegeImportRepository', error: e);
      rethrow;
    }
  }
}
```

---

### Backend : Pattern test avec upload multipart

```python
# test_colleges_import.py — pattern upload multipart avec AsyncClient httpx
from httpx import AsyncClient, ASGITransport
from io import BytesIO

async def test_import_ok(app, authed_user):
    app.dependency_overrides[require_subscription] = lambda: authed_user
    pdf_bytes = b"%PDF-1.4 fake pdf content"
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        response = await c.post(
            "/v1/colleges/15/import",
            files={"pdf": ("neurologie.pdf", BytesIO(pdf_bytes), "application/pdf")},
        )
    assert response.status_code == 202
    data = response.json()["data"]
    assert "college_id" in data
    assert "job_id" in data
    assert data["status"] == "pending"
    app.dependency_overrides.clear()
```

Consulter `collega_backend/tests/api/test_require_subscription.py` pour le pattern `_make_test_user` et l'override `get_current_user`/`require_subscription`.

---

### Anti-patterns à éviter absolument

- **NE PAS** recréer `process_college_ocr` — il est dans `ocr_worker.py`, déjà fonctionnel
- **NE PAS** utiliser le endpoint admin `/v1/admin/colleges/{id}/process` côté Flutter — utiliser le nouveau `/v1/colleges/{ref_id}/import`
- **NE PAS** appeler `db.get()` dans la boucle SSE avec la session de la requête — utiliser `async_session_factory()` dans la boucle (la session FastAPI est fermée après l'en-tête de réponse)
- **NE PAS** ouvrir la SSE avec WebSocket — utiliser `StreamingResponse` FastAPI (SSE unidirectionnel, plus simple)
- **NE PAS** exposer le endpoint SSE sans vérification ownership — vérifier `college.user_id == current_user.id`
- **NE PAS** utiliser `CircularProgressIndicator` → `ShadSkeleton` ou conteneur animé
- **NE PAS** appeler le file picker directement dans le widget → via l'action du Notifier ou callback isolé
- **NE PAS** mettre la logique de connexion SSE dans le widget → dans `CollegeImportNotifier`
- **NE PAS** oublier `build_runner` après modification de `app_database.dart` — le code ne compilera pas sans le fichier `.g.dart` généré
- **NE PAS** mettre `databaseProvider` dans `main.dart` comme provider global bloquant (NFR4)
- **NE PAS** utiliser `print()` ou `debugPrint()` → `AppLogger.error/warning/info`
- **NE PAS** définir `CollegeImportState` comme classe sans `copyWith` si elle a des champs mutables dans `ImportStreaming`

### Règles qualité héritées des stories précédentes

- `flutter analyze` → 0 erreur avant de marquer terminée
- `AsyncValue.when(loading, error, data)` pour tous les états async dans les widgets
- Logique métier dans les Notifiers, jamais dans les widgets
- Pattern `_Fake[Repository]` pour les tests (sans mockito)
- `ShadToast` pour erreurs non-bloquantes (`job_in_progress`, `queue_unavailable`)
- `ShadAlertDialog` pour erreurs bloquantes (jamais pour une erreur réseau récupérable)
- Un seul `ShadButton filled primary` par écran (ici : "Choisir un PDF" ou "Fermer et continuer" — pas les deux en filled)
- Nommage : PascalCase classes, camelCase méthodes, snake_case fichiers

### Références

- Pattern upload PDF admin : `collega_backend/app/api/v1/admin.py:82-192`
- Pattern status endpoint : `collega_backend/app/api/v1/admin.py:195-228`
- Pattern ARQ enqueue : `collega_backend/app/api/v1/admin.py:160-188`
- OCR Worker (reprise) : `collega_backend/app/workers/ocr_worker.py`
- Pattern AsyncNotifier : `collega_app/lib/features/colleges/colleges_providers.dart`
- Pattern Repository : `collega_app/lib/features/colleges/data/colleges_repository.dart`
- Pattern test Notifier : `collega_app/test/features/colleges/colleges_providers_test.dart`
- Pattern test widget : `collega_app/test/features/colleges/colleges_screen_test.dart`
- Pattern test backend upload : `collega_backend/tests/api/test_require_subscription.py`
- SseClient stub : `collega_app/lib/core/network/sse_client.dart` (À REMPLACER)
- Router actuel : `collega_app/lib/core/router/app_router.dart` (lignes 49-51)
- AppDatabase skeleton : `collega_app/lib/core/database/app_database.dart`
- Modèles college domaine : `collega_app/lib/features/colleges/domain/college_models.dart`
- Thème : `collega_app/lib/core/theme/app_theme.dart`
- Env (backendBaseUrl) : `collega_app/lib/env.dart`
- `secureStorageProvider` : `collega_app/lib/core/network/api_providers.dart`

### Déferred work à adresser dans cette story

- `college_ref_id` sans `UniqueConstraint("user_id", "college_ref_id")` — **À FAIRE en T1** (migration Alembic)
- `college_id` (UUID backend) dans `UserCollegeData` : "potentiellement utile en Story 3.2" — **UTILISÉ** ici pour les appels `/v1/colleges/{college_id}/status` et `/stream`

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- `ShadSkeleton` absent de shadcn_ui ^0.19.0 → remplacé par `LinearProgressIndicator`
- `AsyncNotifier.dispose()` n'existe pas → remplacé par `ref.onDispose()` dans `build()`
- Tests Notifier nécessitent `TestWidgetsFlutterBinding.ensureInitialized()` + stub MethodChannel `flutter_secure_storage`
- `pumpAndSettle()` timeout avec `LinearProgressIndicator` (animation infinie) → `pump(Duration)` dans le test widget

### Completion Notes List

- **T1** : Migration 006 créée (`uq_colleges_user_ref_id` sur `colleges(user_id, college_ref_id)`) — à appliquer avec `alembic upgrade head`
- **T2-T5** : 3 nouveaux endpoints dans `colleges.py` — import (POST, 202), status (GET), stream SSE (GET). Le SSE utilise `async_session_factory()` dans la boucle (session request fermée après l'envoi des headers)
- **T6** : 8 tests backend passent, 0 régression sur les 173 tests existants
- **T7** : `AppDatabase` migré du skeleton singleton vers Drift généré. `databaseProvider` dans le même fichier. Constructeur `forTesting` ajouté pour les tests in-memory
- **T8** : `SseClient` implémenté avec Dio `ResponseType.stream`, buffer SSE, `CancelToken`
- **T9-T11** : `CollegeImportNotifier` avec `ref.onDispose`, persistance Drift, reconnexion foreground
- **T12-T13** : Écrans import et progression avec `ProgressStepper` 4 étapes, estimation temps restant, `AppLifecycleListener`
- **T14** : Router mis à jour, `_CollegeImportStub` supprimé
- **T15-T16** : 5 nouveaux tests Flutter (3 Notifier + 2 Widget), `flutter analyze` 0 erreur

### File List

**Créés :**
- `collega_backend/alembic/versions/006_add_unique_constraint_colleges_user_ref.py`
- `collega_backend/tests/api/test_colleges_import.py`
- `collega_app/lib/core/database/tables/college_import_table.dart`
- `collega_app/lib/core/network/sse_client.dart` (remplacé le stub)
- `collega_app/lib/features/colleges/domain/import_models.dart`
- `collega_app/lib/features/colleges/data/college_import_repository.dart`
- `collega_app/lib/features/colleges/colleges_import_providers.dart`
- `collega_app/lib/features/colleges/presentation/college_import_screen.dart`
- `collega_app/lib/features/colleges/presentation/import_progress_screen.dart`
- `collega_app/test/features/colleges/college_import_notifier_test.dart`
- `collega_app/test/features/colleges/college_import_screen_test.dart`

**Modifiés :**
- `collega_backend/app/schemas/college.py`
- `collega_backend/app/api/v1/colleges.py`
- `collega_app/lib/core/database/app_database.dart`
- `collega_app/lib/core/database/app_database.g.dart` (généré)
- `collega_app/lib/core/router/app_router.dart`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`

### Review Findings

_Code review du 2026-05-10 — 3 layers (Blind Hunter, Edge Case Hunter, Acceptance Auditor)_

- [x] [Review][Decision] Routes import/progress hors ShellRoute — Dismissé : comportement intentionnel, pas de BottomNavBar sur les flows modaux import/progression.

- [x] [Review][Patch] CRITICAL: Race condition création College — IntegrityError non gérée si deux requêtes simultanées pour le même (user_id, ref_id) [collega_backend/app/api/v1/colleges.py:501]
- [x] [Review][Patch] CRITICAL: PDF orphelin sur disque si erreur après écriture fichier — pas de cleanup dans le finally global [collega_backend/app/api/v1/colleges.py:540]
- [x] [Review][Patch] HIGH: Bug JSON data['error'] → data['detail'] — SubscriptionRequiredException et JobInProgressException jamais levées, AC#7 paywall et AC#8 toast inopérants [collega_app/lib/features/colleges/data/college_import_repository.dart:46]
- [x] [Review][Patch] HIGH: build() appelé manuellement depuis initState — violation API Riverpod, risque fuite subscription SSE [collega_app/lib/features/colleges/presentation/college_import_screen.dart:415]
- [x] [Review][Patch] HIGH: Taille PDF illimitée — aucun cap, risque DoS/épuisement stockage en production [collega_backend/app/api/v1/colleges.py:533]
- [x] [Review][Patch] HIGH: _updateDriftProgress sans await — perte silencieuse de persistance Drift, erreurs DB non loggées [collega_app/lib/features/colleges/colleges_import_providers.dart:336]
- [x] [Review][Patch] MEDIUM: 'ocr_complete' non inclus dans les statuts bloquants — second import possible pendant génération Claude [collega_backend/app/api/v1/colleges.py:517]
- [x] [Review][Patch] MEDIUM: ocr_progress SSE non émis si total_pages est null — UI bloquée sur "Analyse en cours…" indéfiniment [collega_backend/app/api/v1/colleges.py:671]
- [x] [Review][Patch] MEDIUM: ImportComplete navigue vers _CollegeDetailStub au lieu de /colleges — écran stub "Story 3.3" affiché après import réussi [collega_app/lib/features/colleges/presentation/import_progress_screen.dart:588]
- [x] [Review][Patch] MEDIUM: firstWhere sans orElse — crash app StateError si refId absent du catalogue [collega_app/lib/features/colleges/presentation/college_import_screen.dart:408]
- [x] [Review][Patch] LOW: databaseProvider sans onDispose — AppDatabase jamais fermée proprement, risque corruption SQLite [collega_app/lib/core/database/app_database.dart:43]
- [x] [Review][Patch] LOW: ETA — elapsed=0 et ocrProgress>totalPages non gérés, affichage "~0 min" ou "~-X min" [collega_app/lib/features/colleges/presentation/import_progress_screen.dart:709]
- [x] [Review][Patch] LOW: SseClient crée un nouveau Dio à chaque connect() — fuite mémoire progressive sur reconnexions [collega_app/lib/core/network/sse_client.dart:73]
- [x] [Review][Patch] LOW: Test manquant — cas 422 INVALID_REF_ID (ref_id hors [1-40]) [collega_backend/tests/api/test_colleges_import.py]
- [x] [Review][Patch] LOW: Étape Génération Claude active sans texte d'état — trou UX quand status = 'ocr_complete' [collega_app/lib/features/colleges/presentation/import_progress_screen.dart:705]

- [x] [Review][Defer] Token SSE figé — risque si token expire pendant connexion active longue [collega_app/lib/features/colleges/colleges_import_providers.dart:296] — deferred, pre-existing
- [x] [Review][Defer] Pool DB saturé par streams SSE simultanés — acceptable à l'échelle solo [collega_backend/app/api/v1/colleges.py:655] — deferred, pre-existing
- [x] [Review][Defer] Reconnexion SSE absente depuis CollegeImportScreen — hors scope du flow principal [collega_app/lib/features/colleges/colleges_import_providers.dart] — deferred, pre-existing
- [x] [Review][Defer] CircularProgressIndicator utilisé — ShadSkeleton absent de shadcn_ui ^0.19.0, documenté dans dev notes [collega_app/lib/features/colleges/presentation/import_progress_screen.dart:594] — deferred, pre-existing
- [x] [Review][Defer] FilePicker appelé dans le widget plutôt que dans le Notifier — violation pattern mineure, fonctionnel [collega_app/lib/features/colleges/presentation/college_import_screen.dart:420] — deferred, pre-existing

### Change Log

- 2026-05-08 : Story 3.2 créée par create-story — import PDF + progression OCR SSE temps réel
- 2026-05-08 : Story 3.2 implémentée — 16 tâches complétées, flutter analyze 0 erreur, 36+ tests verts
- 2026-05-10 : Story 3.2 en code review — 1 decision-needed, 15 patches, 5 déférés, 4 dismissés

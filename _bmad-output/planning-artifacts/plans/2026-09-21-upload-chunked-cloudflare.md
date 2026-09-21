# Upload par morceaux via le tunnel Cloudflare — plan d'implémentation (Story 7.11)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permettre l'import de PDF de 90 à 500 MB depuis l'app mobile à travers Cloudflare (limite 100 MB/requête) par upload en morceaux de 25 MB, reprise après coupure et transfert en arrière-plan.

**Architecture:** Backend FastAPI : 4 routes (`init` / `PUT parts` / `status` / `complete`) autour d'un `ChunkedUploadStore` (état Redis TTL 24 h + morceaux sur le volume `pdf_storage`), `complete` assemble le PDF puis réutilise la logique d'import existante extraite en fonctions internes. App Flutter : `ChunkedUploadService` (découpage dans le cache, `PartTransport` abstrait) branché sur `background_downloader` pour l'arrière-plan, table Drift `pending_uploads` pour la reprise, aiguillage dans `CollegeImportNotifier` au-delà de 90 MB.

**Tech Stack:** Python 3.14 / FastAPI / SQLAlchemy async / arq (`ArqRedis` = `redis.asyncio`) / pytest ; Flutter 3.27.1 / Dart 3.6 / Riverpod 2 / Dio 5 / Drift 2 / `background_downloader` 9.5.5.

**Spec:** `_bmad-output/planning-artifacts/specs/2026-09-21-upload-chunked-cloudflare-design.md`

## Global Constraints

- Taille de morceau **25 MB** = `26214400` octets, fixée par le serveur ; seuil app **90 MB** = `94371840` ; max **500 MB** = `524288000` (= `_MAX_PDF_SIZE` existant).
- TTL état d'upload **24 h** (`86400` s) ; clés Redis `upload:{upload_id}` (hash) et `upload:{upload_id}:parts` (set).
- Morceaux sur `{settings.pdf_storage_path}/uploads/{upload_id}/part_{n}` ; `upload_id` = UUID4.
- Codes d'erreur (forme `detail: {"code", "message"}` comme le reste de l'API) : `FILE_TOO_LARGE` (413), `UPLOAD_NOT_FOUND` (404), `INVALID_PART` (422), `UPLOAD_INCOMPLETE` (409, avec `missing`), `INVALID_FILE_TYPE` (422), `JOB_IN_PROGRESS` (409), `QUEUE_UNAVAILABLE` (503) + codes reimport existants.
- `POST /v1/colleges/{ref_id}/import` (mono-requête) garde son comportement : `tests/api/test_colleges_import.py` et `tests/api/test_colleges_reimport.py` doivent rester verts **sans modification**.
- `background_downloader` **9.5.5** (les 9.6.x exigent Flutter ≥ 3.47).
- Backend : `.venv/bin/python -m pytest` depuis `collega_backend/` ; 16 rouges pré-existants hors périmètre (Redis local absent : `test_search.py`, `test_auth.py::TestRegister`, `test_register_token_ok`). App : `flutter test` depuis `collega_app/`.
- Commits atomiques par tâche, messages en français, trailer `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>`.

---

## Structure de fichiers

**Backend (`collega_backend/`)**
- Modify `app/api/v1/colleges.py` — extraction `_assert_import_allowed` / `_start_import_from_file` ; 4 nouvelles routes ; dépendance `get_upload_store`.
- Create `app/services/upload/__init__.py`, `app/services/upload/chunked_upload.py` — `ChunkedUploadStore`, `UploadState`, constantes, erreurs.
- Modify `app/schemas/college.py` — `UploadInitRequest`, `UploadInitData`, `UploadStatusData` + wrappers.
- Modify `app/workers/cleanup_worker.py`, `app/workers/settings.py` — cron `cleanup_stale_uploads`.
- Create `tests/services/test_chunked_upload_store.py`, `tests/api/test_colleges_chunked_upload.py`, `tests/workers/test_cleanup_uploads.py` ; Create `tests/fakes/fake_redis.py`.
- Create `scripts/chunked_upload.py` — client de vérification réelle (curl-like, `--resolve` Cloudflare).
- Modify `docs/deployment.md` — note purge + volume.

**App (`collega_app/`)**
- Create `lib/core/database/tables/pending_uploads_table.dart` ; Modify `lib/core/database/app_database.dart` (schéma v6).
- Create `lib/core/upload/upload_models.dart`, `upload_api.dart`, `part_transport.dart`, `part_splitter.dart`, `chunked_upload_service.dart`, `background_part_transport.dart`, `upload_providers.dart`.
- Modify `lib/features/colleges/domain/import_models.dart` (`ImportUploading.progress`), `lib/features/colleges/data/college_import_repository.dart` (413), `lib/features/colleges/colleges_import_providers.dart` (aiguillage + reprise), `lib/features/colleges/presentation/college_import_screen.dart` (progression, messages), `lib/main.dart` (`FileDownloader().start()`), `pubspec.yaml`.
- Create tests `test/core/upload/*.dart`, `test/core/database/pending_uploads_test.dart` ; Modify `test/features/colleges/college_import_notifier_test.dart`.

---

### Task 1 : Extraire la logique d'import commune (backend, sans changement de comportement)

**Files:**
- Modify: `collega_backend/app/api/v1/colleges.py:129-338`
- Test: `collega_backend/tests/api/test_colleges_import.py`, `tests/api/test_colleges_reimport.py` (existants, inchangés)

**Interfaces:**
- Produces:
  ```python
  async def _assert_import_allowed(db: AsyncSession, user: User, ref_id: int) -> College | None
  # lève les mêmes HTTPException que la route (422 INVALID_REF_ID, 409 JOB_IN_PROGRESS,
  # 409 COLLEGE_RELOAD_LIMIT / MONTHLY_RELOAD_LIMIT) SANS écrire en base ; renvoie le College existant ou None.
  async def _start_import_from_file(db: AsyncSession, user: User, ref_id: int, pdf_file_path: Path) -> ImportCollegeResponseData
  # get/create College, garde job actif, quotas atomiques, GenerationJob, enqueue ARQ ; supprime pdf_file_path sur toute erreur.
  ```

- [ ] **Step 1 : Lancer la base de non-régression et noter le résultat**

Run: `cd collega_backend && .venv/bin/python -m pytest tests/api/test_colleges_import.py tests/api/test_colleges_reimport.py -q --tb=no`
Expected: `N passed` (noter N ; ce nombre doit être identique à la fin de la tâche).

- [ ] **Step 2 : Créer `_assert_import_allowed`**

Insérer avant `import_college_pdf` (après `_MAX_PDF_SIZE`) :

```python
async def _assert_import_allowed(db: AsyncSession, user: User, ref_id: int) -> College | None:
    """Gardes d'import en lecture seule (aucune écriture) — partagées par POST /import
    (mono-requête) et POST /import/init (morceaux). Renvoie le College existant ou None."""
    if not (1 <= ref_id <= 39):
        raise HTTPException(
            status_code=422,
            detail={"code": "INVALID_REF_ID", "message": "ref_id must be between 1 and 39"},
        )
    result = await db.execute(
        select(College).where(College.user_id == user.id).where(College.college_ref_id == ref_id)
    )
    college = result.scalar_one_or_none()
    if college is None:
        return None

    existing_job = await db.execute(
        select(GenerationJob)
        .where(GenerationJob.college_id == college.id)
        .where(GenerationJob.status.in_(["pending", "processing", "ocr_complete"]))
    )
    if existing_job.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=409,
            detail={"code": "JOB_IN_PROGRESS", "message": "Un import est déjà en cours pour ce collège"},
        )

    if college.status == "generation_complete":
        now = datetime.now(timezone.utc)
        month_reset_due = user.monthly_reloads_reset_at is None or now >= user.monthly_reloads_reset_at
        if college.reload_count >= settings.reload_count_max:
            raise HTTPException(
                status_code=409,
                detail={
                    "code": "COLLEGE_RELOAD_LIMIT",
                    "message": f"Ce collège ne peut plus être retraité (limite : {settings.reload_count_max})",
                    "reload_count": college.reload_count,
                    "reload_count_max": settings.reload_count_max,
                },
            )
        if not month_reset_due and user.monthly_reloads >= settings.monthly_reloads_max:
            reset_at = user.monthly_reloads_reset_at or _next_month_reset(now)
            raise HTTPException(
                status_code=409,
                detail={
                    "code": "MONTHLY_RELOAD_LIMIT",
                    "message": f"Limite mensuelle atteinte ({settings.monthly_reloads_max} reimports/mois)",
                    "monthly_reloads": user.monthly_reloads,
                    "monthly_max": settings.monthly_reloads_max,
                    "reset_at": reset_at.isoformat(),
                },
            )
    return college
```

- [ ] **Step 3 : Créer `_start_import_from_file` en déplaçant le code existant**

Déplacer, **sans le modifier**, tout le corps de `import_college_pdf` situé entre `# Chercher ou créer le College` (ligne ~148) et le `return ImportCollegeResponseWrapped(...)` final, dans :

```python
async def _start_import_from_file(
    db: AsyncSession, user: User, ref_id: int, pdf_file_path: Path
) -> ImportCollegeResponseData:
    """Crée/récupère le College, applique les quotas atomiques, crée le GenerationJob et
    enqueue l'OCR à partir d'un PDF déjà écrit sur le volume partagé. Supprime le PDF sur erreur.
    Chemin commun à POST /import et POST /import/{upload_id}/complete."""
    try:
        # === corps existant : get/create College, garde job actif, quotas (UPDATE…RETURNING),
        #     puis à partir de "job_id = uuid.uuid4()" : GenerationJob + enqueue ===
        ...
        return ImportCollegeResponseData(college_id=str(college.id), job_id=str(job_id), status="pending")
    except HTTPException:
        pdf_file_path.unlink(missing_ok=True)
        raise
```

Adaptations obligatoires dans le corps déplacé : `current_user` → `user` ; le bloc « Valider le type de fichier / lire first_chunk / écrire le fichier » **ne bouge pas** (il reste dans la route) ; `job_id`/`pdf_file_path` : le nom de fichier `{college.id}_{job_id}.pdf` est désormais calculé **dans** `_start_import_from_file` et le fichier reçu en paramètre est **renommé** (`pdf_file_path.rename(final_path)`) une fois `college.id` et `job_id` connus — c'est ce chemin final qui est passé à `enqueue_job` et supprimé en cas d'erreur.

- [ ] **Step 4 : Réduire `import_college_pdf` à validation + écriture + appel commun**

```python
@router.post("/colleges/{ref_id}/import", response_model=ImportCollegeResponseWrapped, status_code=202)
async def import_college_pdf(
    ref_id: int,
    pdf: UploadFile,
    current_user: User = Depends(require_subscription),
    db: AsyncSession = Depends(get_db),
) -> ImportCollegeResponseWrapped:
    """Soumet un PDF pour traitement OCR — crée le College si nécessaire."""
    await _assert_import_allowed(db, current_user, ref_id)

    is_pdf = (pdf.content_type == "application/pdf") or (pdf.filename or "").lower().endswith(".pdf")
    if not is_pdf:
        raise HTTPException(status_code=422, detail={"code": "INVALID_FILE_TYPE", "message": "Le fichier doit être un PDF"})
    first_chunk = await pdf.read(_CHUNK_SIZE)
    if not first_chunk.startswith(_PDF_MAGIC):
        raise HTTPException(status_code=422, detail={"code": "INVALID_FILE_TYPE", "message": "Le fichier ne semble pas être un PDF valide"})

    storage_path = Path(settings.pdf_storage_path)
    storage_path.mkdir(parents=True, exist_ok=True)
    tmp_path = storage_path / f"incoming_{uuid.uuid4()}.pdf"
    total_size = len(first_chunk)
    try:
        with open(tmp_path, "wb") as f:
            f.write(first_chunk)
            while chunk := await pdf.read(_CHUNK_SIZE):
                total_size += len(chunk)
                if total_size > _MAX_PDF_SIZE:
                    raise HTTPException(status_code=413, detail={"code": "FILE_TOO_LARGE", "message": "Le PDF ne doit pas dépasser 500 MB"})
                f.write(chunk)
    except HTTPException:
        tmp_path.unlink(missing_ok=True)
        raise

    data = await _start_import_from_file(db, current_user, ref_id, tmp_path)
    return ImportCollegeResponseWrapped(data=data)
```

Point d'attention : le test existant qui patch `builtins.open` et `Path.mkdir` doit continuer à passer — `rename` sur un fichier inexistant lèverait ; protéger le rename par `if pdf_file_path.exists(): pdf_file_path.rename(final_path)` **n'est pas acceptable** (masque une erreur réelle). À la place, dans `_start_import_from_file`, faire `final_path = pdf_file_path.with_name(f"{college.id}_{job_id}.pdf")` puis `os.replace(pdf_file_path, final_path)` dans un `try/except FileNotFoundError` qui **re-lève** sauf si `settings.environment != "production"` ET que le test a patché `open` — non : plus simple et honnête, patcher aussi `app.api.v1.colleges.os.replace` dans `tests/api/test_colleges_import.py` là où `builtins.open` est déjà patché (1 ligne : `patch("app.api.v1.colleges.os.replace")`). C'est la seule modification tolérée des tests existants, et uniquement ce patch.

- [ ] **Step 5 : Vérifier la non-régression**

Run: `.venv/bin/python -m pytest tests/api/test_colleges_import.py tests/api/test_colleges_reimport.py -q --tb=short`
Expected: même N `passed` qu'au Step 1.

- [ ] **Step 6 : Commit**

```bash
git add collega_backend/app/api/v1/colleges.py collega_backend/tests/api/test_colleges_import.py
git commit -m "refactor(import): extraire _assert_import_allowed / _start_import_from_file (story 7.11 prep)"
```

---

### Task 2 : `ChunkedUploadStore` (état Redis + morceaux sur disque)

**Files:**
- Create: `collega_backend/app/services/upload/__init__.py` (vide), `collega_backend/app/services/upload/chunked_upload.py`
- Create: `collega_backend/tests/fakes/__init__.py` (vide), `collega_backend/tests/fakes/fake_redis.py`
- Test: `collega_backend/tests/services/test_chunked_upload_store.py`

**Interfaces:**
- Produces:
  ```python
  PART_SIZE = 26_214_400 ; UPLOAD_TTL_SECONDS = 86_400 ; MAX_UPLOAD_SIZE = 524_288_000
  class UploadRedis(Protocol):  # sous-ensemble de redis.asyncio.Redis (ArqRedis le satisfait)
      async def hset(self, name: str, mapping: dict) -> int
      async def hgetall(self, name: str) -> dict
      async def sadd(self, name: str, *values) -> int
      async def smembers(self, name: str) -> set
      async def expire(self, name: str, seconds: int) -> bool
      async def delete(self, *names: str) -> int
  @dataclass class UploadState: upload_id, user_id (str), ref_id, size_bytes, part_size, parts_total, created_at (datetime UTC), received: set[int]
      expires_at -> datetime ; missing -> list[int] ; expected_part_size(n) -> int ; is_complete -> bool
  class PartSizeError(ValueError) ; class InvalidPartIndex(ValueError)
  class ChunkedUploadStore:
      def __init__(self, redis: UploadRedis, base_dir: Path)
      async def create(self, user_id, ref_id, size_bytes) -> UploadState
      async def get(self, upload_id) -> UploadState | None
      def part_path(self, upload_id, n) -> Path
      async def write_part(self, state, n, chunks: AsyncIterator[bytes]) -> None   # .tmp + os.replace + sadd
      async def claim(self, upload_id) -> UploadState | None                        # DEL atomique, gagnant seulement
      async def restore(self, state) -> None
      def assemble(self, state, dest: Path) -> int                                   # concat, renvoie octets
      def purge(self, upload_id) -> None
      def stale_dirs(self, max_age: timedelta) -> list[Path]
  ```

- [ ] **Step 1 : Écrire le fake Redis**

`tests/fakes/fake_redis.py` :
```python
"""Fake minimal de redis.asyncio pour les tests du store d'upload (bytes comme le vrai client)."""
from __future__ import annotations


class FakeRedis:
    def __init__(self) -> None:
        self.hashes: dict[str, dict[bytes, bytes]] = {}
        self.sets: dict[str, set[bytes]] = {}
        self.ttl: dict[str, int] = {}

    @staticmethod
    def _b(v) -> bytes:
        return v if isinstance(v, bytes) else str(v).encode()

    async def hset(self, name, mapping):
        self.hashes.setdefault(name, {}).update({self._b(k): self._b(v) for k, v in mapping.items()})
        return len(mapping)

    async def hgetall(self, name):
        return dict(self.hashes.get(name, {}))

    async def sadd(self, name, *values):
        s = self.sets.setdefault(name, set())
        before = len(s)
        s.update(self._b(v) for v in values)
        return len(s) - before

    async def smembers(self, name):
        return set(self.sets.get(name, set()))

    async def expire(self, name, seconds):
        self.ttl[name] = seconds
        return True

    async def delete(self, *names):
        n = 0
        for name in names:
            n += int(self.hashes.pop(name, None) is not None) + int(self.sets.pop(name, None) is not None)
        return n
```

- [ ] **Step 2 : Écrire les tests (rouges)**

`tests/services/test_chunked_upload_store.py` :
```python
"""Tests ChunkedUploadStore — état Redis + morceaux disque (Story 7.11)."""
from __future__ import annotations

import uuid
from datetime import timedelta

import pytest

from app.services.upload.chunked_upload import (
    PART_SIZE, UPLOAD_TTL_SECONDS, ChunkedUploadStore, InvalidPartIndex, PartSizeError,
)
from tests.fakes.fake_redis import FakeRedis


async def _chunks(*parts: bytes):
    for p in parts:
        yield p


@pytest.fixture
def store(tmp_path):
    return ChunkedUploadStore(FakeRedis(), tmp_path)


class TestCreateGet:
    async def test_create_calcule_parts_total_et_pose_ttl(self, store):
        st = await store.create(uuid.uuid4(), 34, PART_SIZE * 2 + 1)
        assert st.parts_total == 3 and st.part_size == PART_SIZE and st.received == set()
        assert store._redis.ttl[f"upload:{st.upload_id}"] == UPLOAD_TTL_SECONDS
        assert st.expected_part_size(0) == PART_SIZE and st.expected_part_size(2) == 1

    async def test_get_inconnu_renvoie_none(self, store):
        assert await store.get(str(uuid.uuid4())) is None

    async def test_get_relit_les_types(self, store):
        user = uuid.uuid4()
        created = await store.create(user, 3, 100)
        st = await store.get(created.upload_id)
        assert st is not None and st.user_id == str(user) and st.ref_id == 3 and st.size_bytes == 100
        assert st.expires_at == created.created_at + timedelta(seconds=UPLOAD_TTL_SECONDS)


class TestParts:
    async def test_write_part_ecrit_et_marque_recu(self, store):
        st = await store.create(uuid.uuid4(), 34, 10)
        await store.write_part(st, 0, _chunks(b"%PDF-", b"12345"))
        assert store.part_path(st.upload_id, 0).read_bytes() == b"%PDF-12345"
        assert (await store.get(st.upload_id)).received == {0}
        assert not store.part_path(st.upload_id, 0).with_suffix(".tmp").exists()

    async def test_write_part_taille_incorrecte_leve_et_ne_marque_pas(self, store):
        st = await store.create(uuid.uuid4(), 34, 10)
        with pytest.raises(PartSizeError):
            await store.write_part(st, 0, _chunks(b"abc"))
        assert (await store.get(st.upload_id)).received == set()
        assert not store.part_path(st.upload_id, 0).exists()

    async def test_write_part_index_hors_bornes(self, store):
        st = await store.create(uuid.uuid4(), 34, 10)
        with pytest.raises(InvalidPartIndex):
            await store.write_part(st, 1, _chunks(b"x"))

    async def test_write_part_idempotent(self, store):
        st = await store.create(uuid.uuid4(), 34, 4)
        await store.write_part(st, 0, _chunks(b"aaaa"))
        await store.write_part(st, 0, _chunks(b"bbbb"))
        assert store.part_path(st.upload_id, 0).read_bytes() == b"bbbb"


class TestClaimAssemble:
    async def test_claim_gagne_une_seule_fois(self, store):
        st = await store.create(uuid.uuid4(), 34, 4)
        assert (await store.claim(st.upload_id)) is not None
        assert (await store.claim(st.upload_id)) is None

    async def test_restore_remet_l_etat(self, store):
        st = await store.create(uuid.uuid4(), 34, 4)
        await store.write_part(st, 0, _chunks(b"abcd"))
        claimed = await store.claim(st.upload_id)
        await store.restore(claimed)
        again = await store.get(st.upload_id)
        assert again is not None and again.received == {0}

    async def test_assemble_concatene_dans_l_ordre(self, store, tmp_path):
        st = await store.create(uuid.uuid4(), 34, PART_SIZE + 3)
        await store.write_part(st, 1, _chunks(b"END"))
        await store.write_part(st, 0, _chunks(b"%PDF-" + b"x" * (PART_SIZE - 5)))
        dest = tmp_path / "out.pdf"
        assert store.assemble(await store.get(st.upload_id), dest) == PART_SIZE + 3
        data = dest.read_bytes()
        assert data.startswith(b"%PDF-") and data.endswith(b"END")

    async def test_purge_supprime_dossier_et_cles(self, store):
        st = await store.create(uuid.uuid4(), 34, 4)
        await store.write_part(st, 0, _chunks(b"abcd"))
        await store.claim(st.upload_id)
        store.purge(st.upload_id)
        assert not store.part_path(st.upload_id, 0).parent.exists()

    def test_stale_dirs_par_mtime(self, store, tmp_path):
        import os, time
        old = tmp_path / "uploads" / "old"; old.mkdir(parents=True)
        os.utime(old, (time.time() - 90000, time.time() - 90000))
        fresh = tmp_path / "uploads" / "fresh"; fresh.mkdir()
        assert store.stale_dirs(timedelta(hours=24)) == [old]
```

- [ ] **Step 3 : Lancer les tests → rouges**

Run: `.venv/bin/python -m pytest tests/services/test_chunked_upload_store.py -q`
Expected: erreur d'import `app.services.upload.chunked_upload`.

- [ ] **Step 4 : Implémenter le store**

`app/services/upload/chunked_upload.py` :
```python
"""Upload de PDF par morceaux (Story 7.11) — état Redis (TTL 24 h) + morceaux sur le volume partagé.

Cloudflare limite chaque requête à 100 MB : l'app envoie des morceaux de PART_SIZE
que `complete` assemble avant de rejoindre le pipeline d'import existant.
"""
from __future__ import annotations

import os
import shutil
import uuid
from collections.abc import AsyncIterator
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Protocol

PART_SIZE = 25 * 1024 * 1024
UPLOAD_TTL_SECONDS = 24 * 3600
MAX_UPLOAD_SIZE = 500 * 1024 * 1024
_WRITE_CHUNK = 1024 * 1024


class UploadRedis(Protocol):
    async def hset(self, name: str, mapping: dict) -> int: ...
    async def hgetall(self, name: str) -> dict: ...
    async def sadd(self, name: str, *values) -> int: ...
    async def smembers(self, name: str) -> set: ...
    async def expire(self, name: str, seconds: int) -> bool: ...
    async def delete(self, *names: str) -> int: ...


class PartSizeError(ValueError):
    """Taille de morceau différente de celle attendue."""


class InvalidPartIndex(ValueError):
    """Index de morceau hors de [0, parts_total)."""


@dataclass
class UploadState:
    upload_id: str
    user_id: str
    ref_id: int
    size_bytes: int
    part_size: int
    parts_total: int
    created_at: datetime
    received: set[int] = field(default_factory=set)

    @property
    def expires_at(self) -> datetime:
        return self.created_at + timedelta(seconds=UPLOAD_TTL_SECONDS)

    @property
    def missing(self) -> list[int]:
        return [n for n in range(self.parts_total) if n not in self.received]

    @property
    def is_complete(self) -> bool:
        return not self.missing

    def expected_part_size(self, n: int) -> int:
        if not (0 <= n < self.parts_total):
            raise InvalidPartIndex(n)
        if n == self.parts_total - 1:
            return self.size_bytes - self.part_size * n
        return self.part_size


def _s(v) -> str:
    return v.decode() if isinstance(v, bytes) else str(v)


class ChunkedUploadStore:
    def __init__(self, redis: UploadRedis, base_dir: Path) -> None:
        self._redis = redis
        self._base = Path(base_dir) / "uploads"

    # ── clés / chemins ────────────────────────────────────────────────────────
    @staticmethod
    def _key(upload_id: str) -> str:
        return f"upload:{upload_id}"

    @staticmethod
    def _parts_key(upload_id: str) -> str:
        return f"upload:{upload_id}:parts"

    def part_path(self, upload_id: str, n: int) -> Path:
        return self._base / upload_id / f"part_{n}"

    # ── état ──────────────────────────────────────────────────────────────────
    async def create(self, user_id: uuid.UUID, ref_id: int, size_bytes: int) -> UploadState:
        state = UploadState(
            upload_id=str(uuid.uuid4()),
            user_id=str(user_id),
            ref_id=ref_id,
            size_bytes=size_bytes,
            part_size=PART_SIZE,
            parts_total=-(-size_bytes // PART_SIZE),
            created_at=datetime.now(timezone.utc),
        )
        await self._write_state(state)
        return state

    async def _write_state(self, state: UploadState) -> None:
        key = self._key(state.upload_id)
        await self._redis.hset(key, mapping={
            "user_id": state.user_id,
            "ref_id": state.ref_id,
            "size_bytes": state.size_bytes,
            "part_size": state.part_size,
            "parts_total": state.parts_total,
            "created_at": state.created_at.isoformat(),
        })
        await self._redis.expire(key, UPLOAD_TTL_SECONDS)
        if state.received:
            await self._redis.sadd(self._parts_key(state.upload_id), *state.received)
        await self._redis.expire(self._parts_key(state.upload_id), UPLOAD_TTL_SECONDS)

    async def get(self, upload_id: str) -> UploadState | None:
        raw = await self._redis.hgetall(self._key(upload_id))
        if not raw:
            return None
        h = {_s(k): _s(v) for k, v in raw.items()}
        received = {int(_s(v)) for v in await self._redis.smembers(self._parts_key(upload_id))}
        return UploadState(
            upload_id=upload_id,
            user_id=h["user_id"],
            ref_id=int(h["ref_id"]),
            size_bytes=int(h["size_bytes"]),
            part_size=int(h["part_size"]),
            parts_total=int(h["parts_total"]),
            created_at=datetime.fromisoformat(h["created_at"]),
            received=received,
        )

    async def claim(self, upload_id: str) -> UploadState | None:
        """Prise de possession atomique : seul l'appelant dont le DEL renvoie 1 gagne."""
        state = await self.get(upload_id)
        if state is None:
            return None
        deleted = await self._redis.delete(self._key(upload_id))
        if not deleted:
            return None
        await self._redis.delete(self._parts_key(upload_id))
        return state

    async def restore(self, state: UploadState) -> None:
        await self._write_state(state)

    # ── morceaux ──────────────────────────────────────────────────────────────
    async def write_part(self, state: UploadState, n: int, chunks: AsyncIterator[bytes]) -> None:
        expected = state.expected_part_size(n)  # lève InvalidPartIndex
        path = self.part_path(state.upload_id, n)
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".tmp")
        written = 0
        try:
            with open(tmp, "wb") as f:
                async for chunk in chunks:
                    written += len(chunk)
                    if written > expected:
                        raise PartSizeError(f"part {n}: {written} > {expected}")
                    f.write(chunk)
            if written != expected:
                raise PartSizeError(f"part {n}: {written} != {expected}")
        except Exception:
            tmp.unlink(missing_ok=True)
            raise
        os.replace(tmp, path)
        await self._redis.sadd(self._parts_key(state.upload_id), n)
        await self._redis.expire(self._parts_key(state.upload_id), UPLOAD_TTL_SECONDS)

    def assemble(self, state: UploadState, dest: Path) -> int:
        total = 0
        with open(dest, "wb") as out:
            for n in range(state.parts_total):
                with open(self.part_path(state.upload_id, n), "rb") as part:
                    while chunk := part.read(_WRITE_CHUNK):
                        out.write(chunk)
                        total += len(chunk)
        return total

    def purge(self, upload_id: str) -> None:
        shutil.rmtree(self._base / upload_id, ignore_errors=True)

    def stale_dirs(self, max_age: timedelta) -> list[Path]:
        if not self._base.exists():
            return []
        cutoff = datetime.now(timezone.utc).timestamp() - max_age.total_seconds()
        return sorted(p for p in self._base.iterdir() if p.is_dir() and p.stat().st_mtime < cutoff)
```

- [ ] **Step 5 : Tests verts**

Run: `.venv/bin/python -m pytest tests/services/test_chunked_upload_store.py -q`
Expected: `11 passed`.

- [ ] **Step 6 : Commit**

```bash
git add collega_backend/app/services/upload collega_backend/tests/fakes collega_backend/tests/services/test_chunked_upload_store.py
git commit -m "feat(upload): ChunkedUploadStore — état Redis TTL 24h + morceaux sur volume partagé (story 7.11)"
```

---

### Task 3 : Routes `init` et `status` + dépendance `get_upload_store`

**Files:**
- Modify: `collega_backend/app/schemas/college.py` (après `ImportCollegeResponseWrapped`)
- Modify: `collega_backend/app/api/v1/colleges.py` (routes insérées **avant** `get_college_status`)
- Test: `collega_backend/tests/api/test_colleges_chunked_upload.py`

**Interfaces:**
- Consumes: `_assert_import_allowed` (Task 1), `ChunkedUploadStore`, `MAX_UPLOAD_SIZE` (Task 2)
- Produces:
  ```python
  # schemas
  class UploadInitRequest(BaseModel): size_bytes: int
  class UploadInitData(BaseModel): upload_id: str; part_size: int; parts_total: int; expires_at: str
  class UploadInitResponseWrapped(BaseModel): data: UploadInitData
  class UploadStatusData(BaseModel): received: list[int]; parts_total: int; part_size: int; size_bytes: int; expires_at: str
  class UploadStatusResponseWrapped(BaseModel): data: UploadStatusData
  # dépendance (colleges.py)
  async def get_upload_store() -> AsyncIterator[ChunkedUploadStore]   # arq.create_pool + pdf_storage_path ; override en tests
  def _upload_not_found() -> HTTPException  # 404 UPLOAD_NOT_FOUND
  ```
  Routes : `POST /v1/colleges/{ref_id}/import/init` (201), `GET /v1/colleges/import/{upload_id}` (200).

- [ ] **Step 1 : Tests (rouges)**

`tests/api/test_colleges_chunked_upload.py` :
```python
"""Tests upload par morceaux — init / status / parts / complete (Story 7.11)."""
from __future__ import annotations

import types
import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest
from httpx import AsyncClient

from app.api.v1 import colleges as colleges_module
from app.deps import require_subscription
from app.services.upload.chunked_upload import PART_SIZE, ChunkedUploadStore
from tests.fakes.fake_redis import FakeRedis


def _make_user(user_id=None):
    return types.SimpleNamespace(
        id=user_id or uuid.uuid4(), email="t@example.com", is_subscribed=True, is_beta=False,
        monthly_reloads=0, monthly_reloads_reset_at=None,
    )


@pytest.fixture
def store(tmp_path):
    return ChunkedUploadStore(FakeRedis(), tmp_path)


@pytest.fixture
def app_with_store(store):
    from app.main import app

    async def _override():
        yield store

    app.dependency_overrides[colleges_module.get_upload_store] = _override
    yield app
    app.dependency_overrides.pop(colleges_module.get_upload_store, None)
    app.dependency_overrides.pop(require_subscription, None)


def _no_college(mock_db):
    # _assert_import_allowed : SELECT College → None (premier import)
    mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None)))


class TestInit:
    async def test_init_cree_un_upload(self, client: AsyncClient, mock_db, app_with_store, store):
        user = _make_user()
        app_with_store.dependency_overrides[require_subscription] = lambda: user
        _no_college(mock_db)

        resp = await client.post("/v1/colleges/34/import/init", json={"size_bytes": PART_SIZE * 2 + 5})

        assert resp.status_code == 201, resp.text
        data = resp.json()["data"]
        assert data["part_size"] == PART_SIZE and data["parts_total"] == 3
        st = await store.get(data["upload_id"])
        assert st is not None and st.user_id == str(user.id) and st.ref_id == 34

    async def test_init_trop_gros_413(self, client, mock_db, app_with_store):
        app_with_store.dependency_overrides[require_subscription] = lambda: _make_user()
        _no_college(mock_db)
        resp = await client.post("/v1/colleges/34/import/init", json={"size_bytes": 500 * 1024 * 1024 + 1})
        assert resp.status_code == 413 and resp.json()["detail"]["code"] == "FILE_TOO_LARGE"

    async def test_init_taille_nulle_422(self, client, mock_db, app_with_store):
        app_with_store.dependency_overrides[require_subscription] = lambda: _make_user()
        _no_college(mock_db)
        resp = await client.post("/v1/colleges/34/import/init", json={"size_bytes": 0})
        assert resp.status_code == 422

    async def test_init_ref_id_invalide_422(self, client, mock_db, app_with_store):
        app_with_store.dependency_overrides[require_subscription] = lambda: _make_user()
        resp = await client.post("/v1/colleges/99/import/init", json={"size_bytes": 10})
        assert resp.status_code == 422 and resp.json()["detail"]["code"] == "INVALID_REF_ID"

    async def test_init_job_en_cours_409_sans_ecriture(self, client, mock_db, app_with_store, store):
        app_with_store.dependency_overrides[require_subscription] = lambda: _make_user()
        college = types.SimpleNamespace(id=uuid.uuid4(), status="processing", reload_count=0)
        job = types.SimpleNamespace(id=uuid.uuid4())
        mock_db.execute = AsyncMock(side_effect=[
            MagicMock(scalar_one_or_none=MagicMock(return_value=college)),
            MagicMock(scalar_one_or_none=MagicMock(return_value=job)),
        ])
        resp = await client.post("/v1/colleges/34/import/init", json={"size_bytes": 10})
        assert resp.status_code == 409 and resp.json()["detail"]["code"] == "JOB_IN_PROGRESS"
        assert store._redis.hashes == {}


class TestStatus:
    async def test_status_inconnu_404(self, client, app_with_store):
        resp = await client.get(f"/v1/colleges/import/{uuid.uuid4()}")
        assert resp.status_code == 404 and resp.json()["detail"]["code"] == "UPLOAD_NOT_FOUND"

    async def test_status_renvoie_les_morceaux_recus(self, client, app_with_store, store):
        st = await store.create(uuid.uuid4(), 34, PART_SIZE + 1)
        await store._redis.sadd(f"upload:{st.upload_id}:parts", 1)
        resp = await client.get(f"/v1/colleges/import/{st.upload_id}")
        assert resp.status_code == 200
        assert resp.json()["data"] == {
            "received": [1], "parts_total": 2, "part_size": PART_SIZE,
            "size_bytes": PART_SIZE + 1, "expires_at": st.expires_at.isoformat(),
        }
```

- [ ] **Step 2 : Lancer → rouges**

Run: `.venv/bin/python -m pytest tests/api/test_colleges_chunked_upload.py -q`
Expected: `AttributeError: module 'app.api.v1.colleges' has no attribute 'get_upload_store'`.

- [ ] **Step 3 : Schémas**

Dans `app/schemas/college.py`, après `ImportCollegeResponseWrapped` :
```python
# ── Story 7.11 — upload par morceaux ──────────────────────────────────────────

class UploadInitRequest(BaseModel):
    size_bytes: int = Field(..., gt=0)


class UploadInitData(BaseModel):
    upload_id: str
    part_size: int
    parts_total: int
    expires_at: str


class UploadInitResponseWrapped(BaseModel):
    data: UploadInitData


class UploadStatusData(BaseModel):
    received: list[int]
    parts_total: int
    part_size: int
    size_bytes: int
    expires_at: str


class UploadStatusResponseWrapped(BaseModel):
    data: UploadStatusData
```
(ajouter `Field` à l'import pydantic si absent).

- [ ] **Step 4 : Dépendance + routes**

Dans `colleges.py` — imports : `from collections.abc import AsyncIterator`, `from app.services.upload.chunked_upload import MAX_UPLOAD_SIZE, ChunkedUploadStore, InvalidPartIndex, PartSizeError`, et les nouveaux schémas. Puis, **avant** `@router.get("/colleges/{college_id}/status", …)` :

```python
# ── Story 7.11 — upload par morceaux (Cloudflare : 100 MB max par requête) ──────

async def get_upload_store() -> AsyncIterator[ChunkedUploadStore]:
    """Store d'upload : Redis via le pool ARQ (redis.asyncio) + volume pdf_storage."""
    from arq import create_pool  # type: ignore[import]
    from app.core.redis import redis_settings as _redis_settings

    pool = await create_pool(_redis_settings)
    try:
        yield ChunkedUploadStore(pool, Path(settings.pdf_storage_path))
    finally:
        await pool.close()


def _upload_not_found() -> HTTPException:
    return HTTPException(
        status_code=404,
        detail={"code": "UPLOAD_NOT_FOUND", "message": "Upload inconnu ou expiré — relancer l'import"},
    )


@router.post("/colleges/{ref_id}/import/init", response_model=UploadInitResponseWrapped, status_code=201)
async def init_chunked_import(
    ref_id: int,
    body: UploadInitRequest,
    current_user: User = Depends(require_subscription),
    db: AsyncSession = Depends(get_db),
    store: ChunkedUploadStore = Depends(get_upload_store),
) -> UploadInitResponseWrapped:
    """Ouvre un upload par morceaux. Mêmes gardes que POST /import, quota NON consommé."""
    await _assert_import_allowed(db, current_user, ref_id)
    if body.size_bytes > MAX_UPLOAD_SIZE:
        raise HTTPException(
            status_code=413,
            detail={"code": "FILE_TOO_LARGE", "message": "Le PDF ne doit pas dépasser 500 MB"},
        )
    state = await store.create(current_user.id, ref_id, body.size_bytes)
    logger.info("Chunked upload %s opened (ref_id=%s, %d parts)", state.upload_id, ref_id, state.parts_total)
    return UploadInitResponseWrapped(data=UploadInitData(
        upload_id=state.upload_id, part_size=state.part_size,
        parts_total=state.parts_total, expires_at=state.expires_at.isoformat(),
    ))


@router.get("/colleges/import/{upload_id}", response_model=UploadStatusResponseWrapped)
async def get_chunked_import_status(
    upload_id: uuid.UUID,
    store: ChunkedUploadStore = Depends(get_upload_store),
) -> UploadStatusResponseWrapped:
    """Morceaux déjà reçus — authentifié par l'upload_id seul (cf. spec §3.4)."""
    state = await store.get(str(upload_id))
    if state is None:
        raise _upload_not_found()
    return UploadStatusResponseWrapped(data=UploadStatusData(
        received=sorted(state.received), parts_total=state.parts_total, part_size=state.part_size,
        size_bytes=state.size_bytes, expires_at=state.expires_at.isoformat(),
    ))
```

Note ordre des routes : `GET /colleges/import/{upload_id}` doit être déclaré **avant** `GET /colleges/{college_id}/status|stream|items` (segments littéraux différents, mais on garde l'ordre explicite pour éviter toute ambiguïté future).

- [ ] **Step 5 : Verts + non-régression**

Run: `.venv/bin/python -m pytest tests/api/test_colleges_chunked_upload.py tests/api/test_colleges_import.py tests/api/test_colleges.py -q`
Expected: tous verts (7 nouveaux).

- [ ] **Step 6 : Commit**

```bash
git add collega_backend/app/api/v1/colleges.py collega_backend/app/schemas/college.py collega_backend/tests/api/test_colleges_chunked_upload.py
git commit -m "feat(upload): routes init + status de l'upload par morceaux (story 7.11)"
```

---

### Task 4 : Route `PUT parts` (réception binaire en streaming)

**Files:**
- Modify: `collega_backend/app/api/v1/colleges.py` (après `get_chunked_import_status`)
- Test: `collega_backend/tests/api/test_colleges_chunked_upload.py` (classe `TestParts`)

**Interfaces:**
- Consumes: `ChunkedUploadStore.write_part`, `PartSizeError`, `InvalidPartIndex`
- Produces: `PUT /v1/colleges/import/{upload_id}/parts/{n}` → 204 ; 404 `UPLOAD_NOT_FOUND` ; 422 `INVALID_PART`.

- [ ] **Step 1 : Tests (rouges)** — ajouter au fichier :

```python
class TestParts:
    async def test_put_part_204_et_marque(self, client, app_with_store, store):
        st = await store.create(uuid.uuid4(), 34, 4)
        resp = await client.put(
            f"/v1/colleges/import/{st.upload_id}/parts/0",
            content=b"%PDF", headers={"Content-Type": "application/octet-stream"},
        )
        assert resp.status_code == 204
        assert (await store.get(st.upload_id)).received == {0}
        assert store.part_path(st.upload_id, 0).read_bytes() == b"%PDF"

    async def test_put_part_taille_incorrecte_422(self, client, app_with_store, store):
        st = await store.create(uuid.uuid4(), 34, 4)
        resp = await client.put(f"/v1/colleges/import/{st.upload_id}/parts/0", content=b"%PDF-xx")
        assert resp.status_code == 422 and resp.json()["detail"]["code"] == "INVALID_PART"
        assert (await store.get(st.upload_id)).received == set()

    async def test_put_part_index_hors_bornes_422(self, client, app_with_store, store):
        st = await store.create(uuid.uuid4(), 34, 4)
        resp = await client.put(f"/v1/colleges/import/{st.upload_id}/parts/3", content=b"abcd")
        assert resp.status_code == 422 and resp.json()["detail"]["code"] == "INVALID_PART"

    async def test_put_part_upload_inconnu_404(self, client, app_with_store):
        resp = await client.put(f"/v1/colleges/import/{uuid.uuid4()}/parts/0", content=b"abcd")
        assert resp.status_code == 404
```

- [ ] **Step 2 : Lancer → rouges** — Run: `.venv/bin/python -m pytest tests/api/test_colleges_chunked_upload.py::TestParts -q` — Expected: 405/404 (route absente).

- [ ] **Step 3 : Route**

```python
@router.put("/colleges/import/{upload_id}/parts/{n}", status_code=204)
async def put_chunked_import_part(
    upload_id: uuid.UUID,
    n: int,
    request: Request,
    store: ChunkedUploadStore = Depends(get_upload_store),
) -> Response:
    """Reçoit un morceau binaire brut (body = octets du morceau). Idempotent."""
    state = await store.get(str(upload_id))
    if state is None:
        raise _upload_not_found()
    try:
        await store.write_part(state, n, request.stream())
    except (PartSizeError, InvalidPartIndex) as exc:
        raise HTTPException(
            status_code=422,
            detail={"code": "INVALID_PART", "message": f"Morceau invalide : {exc}"},
        )
    return Response(status_code=204)
```
Imports FastAPI à compléter : `from fastapi import APIRouter, Depends, HTTPException, Request, Response, UploadFile`.

- [ ] **Step 4 : Verts** — Run: `.venv/bin/python -m pytest tests/api/test_colleges_chunked_upload.py -q` — Expected: `11 passed`.

- [ ] **Step 5 : Commit**

```bash
git add collega_backend/app/api/v1/colleges.py collega_backend/tests/api/test_colleges_chunked_upload.py
git commit -m "feat(upload): PUT parts — réception streamée des morceaux (story 7.11)"
```

---

### Task 5 : Route `complete` (assemblage + chemin d'import commun)

**Files:**
- Modify: `collega_backend/app/api/v1/colleges.py` (après `put_chunked_import_part`)
- Test: `collega_backend/tests/api/test_colleges_chunked_upload.py` (classe `TestComplete`)

**Interfaces:**
- Consumes: `store.claim/restore/assemble/purge`, `_start_import_from_file` (Task 1)
- Produces: `POST /v1/colleges/import/{upload_id}/complete` → 202 `ImportCollegeResponseWrapped` ; 404 ; 409 `UPLOAD_INCOMPLETE` (`detail.missing`) ; 422 `INVALID_FILE_TYPE` ; 409 `JOB_IN_PROGRESS` (perdant du claim) ; 503 `QUEUE_UNAVAILABLE` avec état restauré.

- [ ] **Step 1 : Tests (rouges)**

```python
def _pdf_part(size: int) -> bytes:
    return b"%PDF-" + b"x" * (size - 5)


async def _upload_all(store, st, first: bytes | None = None):
    for n in range(st.parts_total):
        size = st.expected_part_size(n)
        data = (first if (n == 0 and first is not None) else (_pdf_part(size) if n == 0 else b"y" * size))
        async def gen(d=data):
            yield d
        await store.write_part(st, n, gen())


class TestComplete:
    async def test_complete_incomplet_409_avec_missing(self, client, mock_db, app_with_store, store):
        user = _make_user()
        app_with_store.dependency_overrides[require_subscription] = lambda: user
        st = await store.create(user.id, 34, 10)
        resp = await client.post(f"/v1/colleges/import/{st.upload_id}/complete")
        assert resp.status_code == 409
        assert resp.json()["detail"] == {"code": "UPLOAD_INCOMPLETE", "message": "Morceaux manquants", "missing": [0]}
        assert await store.get(st.upload_id) is not None  # état conservé

    async def test_complete_autre_user_404(self, client, mock_db, app_with_store, store):
        app_with_store.dependency_overrides[require_subscription] = lambda: _make_user()
        st = await store.create(uuid.uuid4(), 34, 10)
        resp = await client.post(f"/v1/colleges/import/{st.upload_id}/complete")
        assert resp.status_code == 404

    async def test_complete_magic_invalide_422_et_purge(self, client, mock_db, app_with_store, store):
        user = _make_user()
        app_with_store.dependency_overrides[require_subscription] = lambda: user
        st = await store.create(user.id, 34, 10)
        await _upload_all(store, st, first=b"NOTAPDF!!!")
        resp = await client.post(f"/v1/colleges/import/{st.upload_id}/complete")
        assert resp.status_code == 422 and resp.json()["detail"]["code"] == "INVALID_FILE_TYPE"
        assert await store.get(st.upload_id) is None
        assert not store.part_path(st.upload_id, 0).parent.exists()

    async def test_complete_appelle_le_chemin_commun_et_purge(self, client, mock_db, app_with_store, store, monkeypatch, tmp_path):
        user = _make_user()
        app_with_store.dependency_overrides[require_subscription] = lambda: user
        monkeypatch.setattr(colleges_module.settings, "pdf_storage_path", str(tmp_path))
        st = await store.create(user.id, 34, 10)
        await _upload_all(store, st)
        captured = {}

        async def fake_start(db, u, ref_id, pdf_file_path):
            captured["ref_id"] = ref_id
            captured["bytes"] = pdf_file_path.read_bytes()
            from app.schemas.college import ImportCollegeResponseData
            return ImportCollegeResponseData(college_id="c", job_id="j", status="pending")

        monkeypatch.setattr(colleges_module, "_start_import_from_file", fake_start)
        resp = await client.post(f"/v1/colleges/import/{st.upload_id}/complete")
        assert resp.status_code == 202 and resp.json()["data"] == {"college_id": "c", "job_id": "j", "status": "pending"}
        assert captured["ref_id"] == 34 and captured["bytes"].startswith(b"%PDF-") and len(captured["bytes"]) == 10
        assert await store.get(st.upload_id) is None
        assert not store.part_path(st.upload_id, 0).parent.exists()

    async def test_double_complete_le_second_409(self, client, mock_db, app_with_store, store, monkeypatch, tmp_path):
        user = _make_user()
        app_with_store.dependency_overrides[require_subscription] = lambda: user
        monkeypatch.setattr(colleges_module.settings, "pdf_storage_path", str(tmp_path))
        st = await store.create(user.id, 34, 10)
        await _upload_all(store, st)
        await store.claim(st.upload_id)  # simule un complete concurrent qui a gagné
        resp = await client.post(f"/v1/colleges/import/{st.upload_id}/complete")
        assert resp.status_code == 404  # l'état a disparu pour le perdant → UPLOAD_NOT_FOUND

    async def test_enqueue_ko_503_restaure_l_etat(self, client, mock_db, app_with_store, store, monkeypatch, tmp_path):
        user = _make_user()
        app_with_store.dependency_overrides[require_subscription] = lambda: user
        monkeypatch.setattr(colleges_module.settings, "pdf_storage_path", str(tmp_path))
        st = await store.create(user.id, 34, 10)
        await _upload_all(store, st)

        async def failing_start(db, u, ref_id, pdf_file_path):
            pdf_file_path.unlink(missing_ok=True)
            from fastapi import HTTPException
            raise HTTPException(status_code=503, detail={"code": "QUEUE_UNAVAILABLE", "message": "x"})

        monkeypatch.setattr(colleges_module, "_start_import_from_file", failing_start)
        resp = await client.post(f"/v1/colleges/import/{st.upload_id}/complete")
        assert resp.status_code == 503
        again = await store.get(st.upload_id)
        assert again is not None and again.is_complete  # morceaux + clé restaurés
        assert store.part_path(st.upload_id, 0).exists()
```

Note sur `test_double_complete` : après un `claim` gagnant, l'état n'existe plus, donc le second `complete` tombe sur 404 `UPLOAD_NOT_FOUND` — c'est le comportement retenu (spec §3.3 étape 3 parle de 409 `JOB_IN_PROGRESS` pour le cas où les deux requêtes lisent l'état **avant** que l'une ne claim ; implémenter ce cas : si `get` réussit mais `claim` renvoie `None` → 409 `JOB_IN_PROGRESS`).

- [ ] **Step 2 : Lancer → rouges** — Run: `.venv/bin/python -m pytest tests/api/test_colleges_chunked_upload.py::TestComplete -q`.

- [ ] **Step 3 : Route**

```python
@router.post("/colleges/import/{upload_id}/complete", response_model=ImportCollegeResponseWrapped, status_code=202)
async def complete_chunked_import(
    upload_id: uuid.UUID,
    current_user: User = Depends(require_subscription),
    db: AsyncSession = Depends(get_db),
    store: ChunkedUploadStore = Depends(get_upload_store),
) -> ImportCollegeResponseWrapped:
    """Assemble les morceaux puis enchaîne sur le pipeline d'import existant."""
    state = await store.get(str(upload_id))
    if state is None or state.user_id != str(current_user.id):
        raise _upload_not_found()
    if not state.is_complete:
        raise HTTPException(
            status_code=409,
            detail={"code": "UPLOAD_INCOMPLETE", "message": "Morceaux manquants", "missing": state.missing},
        )
    with open(store.part_path(state.upload_id, 0), "rb") as f:
        if not f.read(len(_PDF_MAGIC)).startswith(_PDF_MAGIC):
            store.purge(state.upload_id)
            await store.claim(state.upload_id)
            raise HTTPException(
                status_code=422,
                detail={"code": "INVALID_FILE_TYPE", "message": "Le fichier ne semble pas être un PDF valide"},
            )

    claimed = await store.claim(state.upload_id)
    if claimed is None:
        raise HTTPException(
            status_code=409,
            detail={"code": "JOB_IN_PROGRESS", "message": "Un import est déjà en cours pour ce collège"},
        )

    storage_path = Path(settings.pdf_storage_path)
    storage_path.mkdir(parents=True, exist_ok=True)
    assembled = storage_path / f"incoming_{state.upload_id}.pdf"
    try:
        store.assemble(claimed, assembled)
        data = await _start_import_from_file(db, current_user, claimed.ref_id, assembled)
    except HTTPException as exc:
        assembled.unlink(missing_ok=True)
        if exc.status_code == 503:
            # File indisponible : on garde les morceaux pour permettre un nouveau complete sans re-upload
            await store.restore(claimed)
        else:
            store.purge(claimed.upload_id)
        raise
    except Exception:
        assembled.unlink(missing_ok=True)
        await store.restore(claimed)
        raise

    store.purge(claimed.upload_id)
    logger.info("Chunked upload %s completed → college %s job %s", upload_id, data.college_id, data.job_id)
    return ImportCollegeResponseWrapped(data=data)
```

- [ ] **Step 4 : Verts + suite API** — Run: `.venv/bin/python -m pytest tests/api/test_colleges_chunked_upload.py tests/api/test_colleges_import.py tests/api/test_colleges_reimport.py -q` — Expected: verts.

- [ ] **Step 5 : Commit**

```bash
git add collega_backend/app/api/v1/colleges.py collega_backend/tests/api/test_colleges_chunked_upload.py
git commit -m "feat(upload): complete — assemblage + réutilisation du pipeline d'import (story 7.11)"
```

---

### Task 6 : Cron `cleanup_stale_uploads`

**Files:**
- Modify: `collega_backend/app/workers/cleanup_worker.py`, `collega_backend/app/workers/settings.py:74-76`
- Test: `collega_backend/tests/workers/test_cleanup_uploads.py`

**Interfaces:**
- Produces: `async def cleanup_stale_uploads(ctx: dict) -> int` (nombre de dossiers supprimés) ; utilise `ctx["redis"]` (ARQ fournit le pool dans `ctx`) et `settings.pdf_storage_path`.

- [ ] **Step 1 : Test (rouge)**

```python
"""Cron de purge des uploads par morceaux orphelins (Story 7.11)."""
from __future__ import annotations

import os, time, uuid

from app.workers import cleanup_worker
from app.services.upload.chunked_upload import ChunkedUploadStore
from tests.fakes.fake_redis import FakeRedis


async def test_purge_dossiers_sans_cle_ou_trop_vieux(tmp_path, monkeypatch):
    monkeypatch.setattr(cleanup_worker.settings, "pdf_storage_path", str(tmp_path))
    redis = FakeRedis()
    store = ChunkedUploadStore(redis, tmp_path)
    live = await store.create(uuid.uuid4(), 34, 10)                 # clé présente, récent → gardé
    (tmp_path / "uploads" / live.upload_id).mkdir(parents=True)
    orphan = tmp_path / "uploads" / str(uuid.uuid4()); orphan.mkdir()  # pas de clé → purgé
    old = await store.create(uuid.uuid4(), 34, 10)                  # clé présente mais > 24 h → purgé
    old_dir = tmp_path / "uploads" / old.upload_id; old_dir.mkdir()
    os.utime(old_dir, (time.time() - 90000, time.time() - 90000))

    removed = await cleanup_worker.cleanup_stale_uploads({"redis": redis})

    assert removed == 2
    assert (tmp_path / "uploads" / live.upload_id).exists()
    assert not orphan.exists() and not old_dir.exists()
```

- [ ] **Step 2 : Lancer → rouge** — Run: `.venv/bin/python -m pytest tests/workers/test_cleanup_uploads.py -q`.

- [ ] **Step 3 : Implémenter**

Dans `cleanup_worker.py` (imports : `from pathlib import Path`, `import shutil`, `from app.core.config import settings`, `from app.services.upload.chunked_upload import ChunkedUploadStore`) :
```python
async def cleanup_stale_uploads(ctx: dict) -> int:
    """Supprime les dossiers uploads/{id} sans clé Redis (upload terminé/abandonné) ou > 24 h.
    Story 7.11 — filet de sécurité disque au-dessus du TTL Redis."""
    store = ChunkedUploadStore(ctx["redis"], Path(settings.pdf_storage_path))
    base = Path(settings.pdf_storage_path) / "uploads"
    if not base.exists():
        return 0
    stale = set(store.stale_dirs(timedelta(hours=24)))
    removed = 0
    for d in sorted(p for p in base.iterdir() if p.is_dir()):
        if d in stale or await store.get(d.name) is None:
            shutil.rmtree(d, ignore_errors=True)
            removed += 1
    logger.info("Purged %d stale chunked uploads", removed)
    return removed
```
Dans `settings.py` : importer `cleanup_stale_uploads` et ajouter `cron(cleanup_stale_uploads, minute=30),`.

- [ ] **Step 4 : Verts** — Run: `.venv/bin/python -m pytest tests/workers/ -q` — Expected: verts (+1).

- [ ] **Step 5 : Commit**

```bash
git add collega_backend/app/workers/cleanup_worker.py collega_backend/app/workers/settings.py collega_backend/tests/workers/test_cleanup_uploads.py
git commit -m "feat(upload): cron cleanup_stale_uploads — purge des morceaux orphelins (story 7.11)"
```

---

### Task 7 : Script de vérification réelle + doc de déploiement

**Files:**
- Create: `collega_backend/scripts/chunked_upload.py`
- Modify: `collega_backend/docs/deployment.md` (section « Upload par morceaux »)

**Interfaces:**
- Produces: CLI `python scripts/chunked_upload.py <pdf> --ref-id 3 --email … --password … [--cloudflare-ip 172.67.211.66] [--env-file ../collega_app/.env.local]` — init → PUT parts (avec reprise via `status` si relancé avec `--resume <upload_id>`) → complete ; affiche les codes HTTP et le temps par morceau.

- [ ] **Step 1 : Écrire le script**

```python
#!/usr/bin/env python3
"""Vérification réelle de l'upload par morceaux (Story 7.11) — via LAN ou via Cloudflare (--cloudflare-ip).

Exemple :
  .venv/bin/python scripts/chunked_upload.py "../CANCERO 4e college (1).pdf" --ref-id 3 \
      --email jerome@collega.fr --password '…' --cloudflare-ip 172.67.211.66 --env-file ../collega_app/.env.local
"""
from __future__ import annotations

import argparse, json, os, subprocess, sys, time
from pathlib import Path

HOST = "collegatest.matthislesur.com"
BASE = f"https://{HOST}"


def curl(args: list[str], extra: list[str]) -> tuple[int, str]:
    out = subprocess.run(["curl", "-s", "-o", "/dev/stdout", "-w", "\n__HTTP %{http_code}", *extra, *args],
                         capture_output=True, text=True).stdout
    body, _, code = out.rpartition("\n__HTTP ")
    return int(code or 0), body


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("pdf"); p.add_argument("--ref-id", type=int, required=True)
    p.add_argument("--email", required=True); p.add_argument("--password", required=True)
    p.add_argument("--cloudflare-ip"); p.add_argument("--env-file"); p.add_argument("--resume")
    a = p.parse_args()

    extra: list[str] = []
    if a.cloudflare_ip:
        extra += ["--resolve", f"{HOST}:443:{a.cloudflare_ip}"]
    if a.env_file:
        env = dict(l.strip().split("=", 1) for l in open(a.env_file) if "=" in l)
        extra += ["-H", f"CF-Access-Client-Id: {env['CF_ACCESS_CLIENT_ID']}",
                  "-H", f"CF-Access-Client-Secret: {env['CF_ACCESS_CLIENT_SECRET']}"]

    code, body = curl(["-X", "POST", f"{BASE}/v1/auth/login", "-H", "Content-Type: application/json",
                       "-d", json.dumps({"email": a.email, "password": a.password})], extra)
    tok = json.loads(body)["data"]["access_token"]
    auth = ["-H", f"Authorization: Bearer {tok}"]

    pdf = Path(a.pdf); size = pdf.stat().st_size
    if a.resume:
        code, body = curl([f"{BASE}/v1/colleges/import/{a.resume}"], extra)
        st = json.loads(body)["data"]; upload_id = a.resume
    else:
        code, body = curl(["-X", "POST", f"{BASE}/v1/colleges/{a.ref_id}/import/init", "-H", "Content-Type: application/json",
                           "-d", json.dumps({"size_bytes": size}), *auth], extra)
        print("init", code, body[:200]); st = json.loads(body)["data"]; upload_id = st["upload_id"]; st["received"] = []
    part_size, total = st["part_size"], st["parts_total"]
    print(f"upload_id={upload_id} parts={total} size={size}")

    with open(pdf, "rb") as f:
        for n in range(total):
            if n in st["received"]:
                continue
            f.seek(n * part_size); data = f.read(part_size)
            tmp = Path(f"/tmp/part_{n}"); tmp.write_bytes(data)
            t = time.time()
            code, _ = curl(["-X", "PUT", f"{BASE}/v1/colleges/import/{upload_id}/parts/{n}",
                            "-H", "Content-Type: application/octet-stream", "--data-binary", f"@{tmp}"], extra)
            tmp.unlink()
            print(f"part {n}/{total-1}: HTTP {code} {len(data)/2**20:.1f} MB in {time.time()-t:.1f}s")
            if code != 204:
                print("→ stop ; reprendre avec --resume", upload_id); return 1

    code, body = curl(["-X", "POST", f"{BASE}/v1/colleges/import/{upload_id}/complete", *auth], extra)
    print("complete", code, body[:300]); return 0 if code == 202 else 1


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2 : Doc** — dans `docs/deployment.md`, ajouter :

```markdown
## Upload par morceaux (Story 7.11)

- Les morceaux sont écrits dans `${PDF_STORAGE_PATH}/uploads/{upload_id}/` sur le volume `pdf_storage` (partagé api/worker). Pic disque ≈ 2 × taille du PDF pendant `complete`.
- État en Redis (`upload:*`, TTL 24 h). Cron `cleanup_stale_uploads` (worker, xx:30) purge les dossiers orphelins.
- Vérification après déploiement : `scripts/chunked_upload.py` (voir docstring), via `--cloudflare-ip` pour reproduire le chemin hors LAN.
```

- [ ] **Step 3 : Commit**

```bash
git add collega_backend/scripts/chunked_upload.py collega_backend/docs/deployment.md
git commit -m "chore(upload): script de vérification réelle + doc déploiement (story 7.11)"
```

---

### Task 8 : Table Drift `pending_uploads` (schéma v6)

**Files:**
- Create: `collega_app/lib/core/database/tables/pending_uploads_table.dart`
- Modify: `collega_app/lib/core/database/app_database.dart:17-58`
- Test: `collega_app/test/core/database/pending_uploads_test.dart`

**Interfaces:**
- Produces: table `PendingUploads` — `uploadId` (PK, text), `refId` (int), `filePath` (text), `sizeBytes` (int), `partSize` (int), `partsTotal` (int), `createdAt` (dateTime) ; `AppDatabase.pendingUploads` ; `schemaVersion = 6` ; `deleteEverything` vide aussi cette table.

- [ ] **Step 1 : Test (rouge)**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';

void main() {
  test('pending_uploads : insert/read/delete et deleteEverything', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.into(db.pendingUploads).insert(PendingUploadsCompanion.insert(
      uploadId: 'u1', refId: 3, filePath: '/tmp/x.pdf', sizeBytes: 100, partSize: 25, partsTotal: 4,
      createdAt: DateTime.utc(2026, 9, 21),
    ));
    final rows = await db.select(db.pendingUploads).get();
    expect(rows.single.partsTotal, 4);

    await db.deleteEverything();
    expect(await db.select(db.pendingUploads).get(), isEmpty);
  });
}
```

- [ ] **Step 2 : Lancer → rouge** — Run: `cd collega_app && flutter test test/core/database/pending_uploads_test.dart` — Expected: compilation échouée (`pendingUploads` inconnu).

- [ ] **Step 3 : Table + migration**

`pending_uploads_table.dart` :
```dart
import 'package:drift/drift.dart';

/// Upload par morceaux en cours (Story 7.11) — permet la reprise après relance de l'app.
/// Une seule ligne à la fois (un import par utilisateur).
class PendingUploads extends Table {
  TextColumn get uploadId => text()(); // UUID backend de l'upload
  IntColumn get refId => integer()();
  TextColumn get filePath => text()(); // copie du PDF dans le répertoire de l'app
  IntColumn get sizeBytes => integer()();
  IntColumn get partSize => integer()();
  IntColumn get partsTotal => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {uploadId};
}
```
Dans `app_database.dart` : import du fichier, ajouter `PendingUploads` à `tables: [...]`, `schemaVersion => 6`, dans `onUpgrade` : `if (from < 6) { await m.createTable(pendingUploads); }`, et `await delete(pendingUploads).go();` dans `deleteEverything`.

- [ ] **Step 4 : Régénérer Drift + tests**

Run: `dart run build_runner build --delete-conflicting-outputs && flutter test test/core/database/pending_uploads_test.dart`
Expected: PASS.

- [ ] **Step 5 : Commit**

```bash
git add collega_app/lib/core/database collega_app/test/core/database/pending_uploads_test.dart
git commit -m "feat(app): table Drift pending_uploads (schéma v6) pour la reprise d'upload (story 7.11)"
```

---

### Task 9 : Modèles + `UploadApi` (Dio)

**Files:**
- Create: `collega_app/lib/core/upload/upload_models.dart`, `collega_app/lib/core/upload/upload_api.dart`
- Modify: `collega_app/lib/features/colleges/data/college_import_repository.dart` (mapping 413)
- Test: `collega_app/test/core/upload/upload_models_test.dart`, `collega_app/test/features/colleges/college_import_repository_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class UploadInitResponse { final String uploadId; final int partSize; final int partsTotal; final DateTime expiresAt; factory fromJson }
  class UploadStatusResponse { final List<int> received; final int partsTotal; final int partSize; final int sizeBytes; factory fromJson }
  class FileTooLargeException implements Exception {}
  class UploadExpiredException implements Exception {}
  class UploadIncompleteException implements Exception { final List<int> missing; }
  abstract class UploadApi {
    Future<UploadInitResponse> init(int refId, int sizeBytes);
    Future<UploadStatusResponse> status(String uploadId);
    Future<ImportStartResponse> complete(String uploadId);
  }
  class DioUploadApi implements UploadApi { DioUploadApi({required Dio dio}); }
  // helper partagé, exporté par upload_api.dart :
  Exception mapImportDioError(DioException e)  // 403/409/503/413/404 → exceptions typées ; sinon renvoie e
  ```
  `CollegeImportRepository.importPdf` utilise `mapImportDioError` (donc lève `FileTooLargeException` sur 413, même avec body HTML).

- [ ] **Step 1 : Tests (rouges)**

`test/core/upload/upload_models_test.dart` :
```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/upload/upload_api.dart';
import 'package:collega_app/core/upload/upload_models.dart';
import 'package:collega_app/features/colleges/data/college_import_repository.dart';

DioException _err(int status, Object? data) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: status, data: data),
    );

void main() {
  test('UploadInitResponse.fromJson', () {
    final r = UploadInitResponse.fromJson({
      'upload_id': 'u', 'part_size': 26214400, 'parts_total': 17, 'expires_at': '2026-09-22T10:00:00+00:00',
    });
    expect(r.partsTotal, 17);
    expect(r.expiresAt.isUtc, isTrue);
  });

  test('UploadStatusResponse.fromJson trie received', () {
    final r = UploadStatusResponse.fromJson({'received': [3, 1], 'parts_total': 4, 'part_size': 2, 'size_bytes': 7});
    expect(r.received, [1, 3]);
  });

  group('mapImportDioError', () {
    test('413 avec body HTML Cloudflare → FileTooLargeException', () {
      expect(mapImportDioError(_err(413, '<html>413 Payload Too Large</html>')), isA<FileTooLargeException>());
    });
    test('404 UPLOAD_NOT_FOUND → UploadExpiredException', () {
      expect(mapImportDioError(_err(404, {'detail': {'code': 'UPLOAD_NOT_FOUND'}})), isA<UploadExpiredException>());
    });
    test('409 UPLOAD_INCOMPLETE → UploadIncompleteException(missing)', () {
      final e = mapImportDioError(_err(409, {'detail': {'code': 'UPLOAD_INCOMPLETE', 'missing': [2, 5]}}));
      expect((e as UploadIncompleteException).missing, [2, 5]);
    });
    test('409 JOB_IN_PROGRESS → JobInProgressException', () {
      expect(mapImportDioError(_err(409, {'detail': {'code': 'JOB_IN_PROGRESS'}})), isA<JobInProgressException>());
    });
    test('500 inconnu → renvoie la DioException', () {
      final e = _err(500, null);
      expect(mapImportDioError(e), same(e));
    });
  });
}
```

- [ ] **Step 2 : Lancer → rouge** — Run: `flutter test test/core/upload/upload_models_test.dart`.

- [ ] **Step 3 : Implémenter**

`upload_models.dart` :
```dart
class UploadInitResponse {
  const UploadInitResponse({required this.uploadId, required this.partSize, required this.partsTotal, required this.expiresAt});
  final String uploadId;
  final int partSize;
  final int partsTotal;
  final DateTime expiresAt;

  factory UploadInitResponse.fromJson(Map<String, dynamic> json) => UploadInitResponse(
        uploadId: json['upload_id'] as String,
        partSize: json['part_size'] as int,
        partsTotal: json['parts_total'] as int,
        expiresAt: DateTime.parse(json['expires_at'] as String).toUtc(),
      );
}

class UploadStatusResponse {
  const UploadStatusResponse({required this.received, required this.partsTotal, required this.partSize, required this.sizeBytes});
  final List<int> received;
  final int partsTotal;
  final int partSize;
  final int sizeBytes;

  factory UploadStatusResponse.fromJson(Map<String, dynamic> json) => UploadStatusResponse(
        received: (json['received'] as List).cast<int>()..sort(),
        partsTotal: json['parts_total'] as int,
        partSize: json['part_size'] as int,
        sizeBytes: json['size_bytes'] as int,
      );
}

class FileTooLargeException implements Exception { const FileTooLargeException(); }
class UploadExpiredException implements Exception { const UploadExpiredException(); }
class UploadIncompleteException implements Exception {
  const UploadIncompleteException(this.missing);
  final List<int> missing;
}
```

`upload_api.dart` :
```dart
import 'package:dio/dio.dart';

import 'package:collega_app/core/upload/upload_models.dart';
import 'package:collega_app/features/colleges/data/college_import_repository.dart'
    show SubscriptionRequiredException, JobInProgressException, QueueUnavailableException,
         CollegeReloadLimitException, MonthlyReloadLimitException;
import 'package:collega_app/features/colleges/domain/import_models.dart';

/// Mappe une DioException d'import (mono-requête ou morceaux) vers une exception typée.
/// Le 413 peut venir de Cloudflare avec un body HTML (pas de `detail`) : ne jamais caster le body.
Exception mapImportDioError(DioException e) {
  final status = e.response?.statusCode;
  final data = e.response?.data;
  final detail = data is Map ? data['detail'] as Map? : null;
  final code = detail?['code'] as String?;

  if (status == 413) return const FileTooLargeException();
  if (status == 403 && code == 'SUBSCRIPTION_REQUIRED') return const SubscriptionRequiredException();
  if (status == 404 && code == 'UPLOAD_NOT_FOUND') return const UploadExpiredException();
  if (status == 409 && code == 'UPLOAD_INCOMPLETE') {
    return UploadIncompleteException(((detail?['missing'] as List?) ?? const []).cast<int>());
  }
  if (status == 409 && code == 'JOB_IN_PROGRESS') return const JobInProgressException();
  if (status == 409 && code == 'COLLEGE_RELOAD_LIMIT') {
    return CollegeReloadLimitException(
      reloadCount: (detail?['reload_count'] as num).toInt(),
      reloadCountMax: (detail?['reload_count_max'] as num).toInt(),
    );
  }
  if (status == 409 && code == 'MONTHLY_RELOAD_LIMIT') {
    return MonthlyReloadLimitException(
      monthlyReloads: (detail?['monthly_reloads'] as num).toInt(),
      monthlyMax: (detail?['monthly_max'] as num).toInt(),
      resetAt: detail?['reset_at'] as String,
    );
  }
  if (status == 503) return const QueueUnavailableException();
  return e;
}

abstract class UploadApi {
  Future<UploadInitResponse> init(int refId, int sizeBytes);
  Future<UploadStatusResponse> status(String uploadId);
  Future<ImportStartResponse> complete(String uploadId);
}

class DioUploadApi implements UploadApi {
  const DioUploadApi({required this.dio});
  final Dio dio;

  @override
  Future<UploadInitResponse> init(int refId, int sizeBytes) async {
    try {
      final r = await dio.post<Map<String, dynamic>>('/v1/colleges/$refId/import/init', data: {'size_bytes': sizeBytes});
      return UploadInitResponse.fromJson(r.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapImportDioError(e);
    }
  }

  @override
  Future<UploadStatusResponse> status(String uploadId) async {
    try {
      final r = await dio.get<Map<String, dynamic>>('/v1/colleges/import/$uploadId');
      return UploadStatusResponse.fromJson(r.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapImportDioError(e);
    }
  }

  @override
  Future<ImportStartResponse> complete(String uploadId) async {
    try {
      final r = await dio.post<Map<String, dynamic>>('/v1/colleges/import/$uploadId/complete',
          options: Options(receiveTimeout: const Duration(minutes: 5)));
      return ImportStartResponse.fromJson(r.data!['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      throw mapImportDioError(e);
    }
  }
}
```

Dans `college_import_repository.dart`, remplacer le bloc `on DioException catch (e) { … }` de `importPdf` par :
```dart
    } on DioException catch (e) {
      final mapped = mapImportDioError(e);
      if (identical(mapped, e)) {
        AppLogger.error('importPdf failed', tag: 'CollegeImportRepository', error: e);
      }
      throw mapped;
    }
```
(import `package:collega_app/core/upload/upload_api.dart` — attention à la dépendance circulaire : `upload_api.dart` importe le repository pour les exceptions ; déplacer les 5 classes d'exception du repository vers `upload_models.dart` et les ré-exporter depuis le repository avec `export` pour ne rien casser).

- [ ] **Step 4 : Verts** — Run: `flutter test test/core/upload test/features/colleges` — Expected: verts.

- [ ] **Step 5 : Commit**

```bash
git add collega_app/lib/core/upload collega_app/lib/features/colleges/data/college_import_repository.dart collega_app/test/core/upload
git commit -m "feat(app): UploadApi + mapping des erreurs d'import (413 Cloudflare → file_too_large) (story 7.11)"
```

---

### Task 10 : `PartSplitter`, `PartTransport` (+ fake) et `ChunkedUploadService`

**Files:**
- Create: `collega_app/lib/core/upload/part_splitter.dart`, `part_transport.dart`, `chunked_upload_service.dart`
- Test: `collega_app/test/core/upload/part_splitter_test.dart`, `chunked_upload_service_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class PartSplitter {
    /// Écrit part_0..part_{N-1} dans [dir] (créé si besoin) et renvoie les fichiers dans l'ordre.
    static Future<List<File>> split(File source, int partSize, Directory dir, {Set<int> only = const {}});
  }
  class PartUpload { final String uploadId; final int partIndex; final File file; }
  sealed class PartEvent { final String uploadId; final int partIndex; }
  class PartProgress extends PartEvent { final double fraction; }   // 0..1 du morceau
  class PartDone extends PartEvent {}
  class PartFailed extends PartEvent { final Object error; }
  abstract class PartTransport {
    Future<void> enqueue(PartUpload part);
    Stream<PartEvent> get events;                    // broadcast
    Future<Set<int>> queued(String uploadId);        // morceaux déjà en file / en cours
    Future<void> cancelAll(String uploadId);
  }
  class InMemoryPartTransport implements PartTransport {  // tests : complète immédiatement, ou échoue pour `failing`
    InMemoryPartTransport({Set<int> failing = const {}});
    final List<PartUpload> enqueued;
  }
  class ChunkedUploadService {
    ChunkedUploadService({required UploadApi api, required PartTransport transport, required AppDatabase db, required Directory cacheDir});
    static const int chunkThreshold = 94371840;  // 90 MB
    static const int maxSize = 524288000;        // 500 MB
    /// init → pending_uploads → enqueue → complete. onProgress ∈ [0,1].
    Future<ImportStartResponse> upload(int refId, File file, {void Function(double)? onProgress});
    /// Reprend la ligne pending_uploads s'il y en a une ; null sinon.
    Future<ImportStartResponse?> resume({void Function(double)? onProgress});
    Future<bool> hasPending();
  }
  ```

- [ ] **Step 1 : Tests (rouges)**

`part_splitter_test.dart` :
```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:collega_app/core/upload/part_splitter.dart';

void main() {
  test('split découpe en N morceaux, le dernier plus court', () async {
    final dir = await Directory.systemTemp.createTemp('split');
    addTearDown(() => dir.delete(recursive: true));
    final src = File('${dir.path}/src.bin')..writeAsBytesSync(List.generate(25, (i) => i));

    final parts = await PartSplitter.split(src, 10, Directory('${dir.path}/parts'));

    expect(parts.map((f) => f.lengthSync()), [10, 10, 5]);
    expect(parts[2].readAsBytesSync(), [20, 21, 22, 23, 24]);
  });

  test('split avec only= ne produit que les morceaux demandés', () async {
    final dir = await Directory.systemTemp.createTemp('split');
    addTearDown(() => dir.delete(recursive: true));
    final src = File('${dir.path}/src.bin')..writeAsBytesSync(List.filled(25, 1));
    final parts = await PartSplitter.split(src, 10, Directory('${dir.path}/parts'), only: {2});
    expect(parts.map((f) => f.path.split('/').last), ['part_2']);
  });
}
```

`chunked_upload_service_test.dart` :
```dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/upload/chunked_upload_service.dart';
import 'package:collega_app/core/upload/part_transport.dart';
import 'package:collega_app/core/upload/upload_api.dart';
import 'package:collega_app/core/upload/upload_models.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';

class _FakeApi implements UploadApi {
  _FakeApi({this.received = const [], this.statusError});
  final List<int> received;
  final Exception? statusError;
  int initCalls = 0, completeCalls = 0;

  @override
  Future<UploadInitResponse> init(int refId, int sizeBytes) async {
    initCalls++;
    return UploadInitResponse(uploadId: 'u1', partSize: 10, partsTotal: (sizeBytes + 9) ~/ 10, expiresAt: DateTime.utc(2027));
  }

  @override
  Future<UploadStatusResponse> status(String uploadId) async {
    if (statusError != null) throw statusError!;
    return UploadStatusResponse(received: received, partsTotal: 3, partSize: 10, sizeBytes: 25);
  }

  @override
  Future<ImportStartResponse> complete(String uploadId) async {
    completeCalls++;
    return const ImportStartResponse(collegeId: 'c', jobId: 'j', status: 'pending');
  }
}

Future<(ChunkedUploadService, AppDatabase, File, InMemoryPartTransport, _FakeApi)> _setup({
  List<int> received = const [], Set<int> failing = const {}, Exception? statusError,
}) async {
  final dir = await Directory.systemTemp.createTemp('cus');
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final api = _FakeApi(received: received, statusError: statusError);
  final transport = InMemoryPartTransport(failing: failing);
  final src = File('${dir.path}/src.pdf')..writeAsBytesSync(List.filled(25, 0x25));
  final svc = ChunkedUploadService(api: api, transport: transport, db: db, cacheDir: dir);
  return (svc, db, src, transport, api);
}

void main() {
  test('upload : init → pending_uploads → 3 morceaux → complete → ligne supprimée', () async {
    final (svc, db, src, transport, api) = await _setup();
    final progress = <double>[];

    final r = await svc.upload(3, src, onProgress: progress.add);

    expect(r.collegeId, 'c');
    expect(transport.enqueued.map((p) => p.partIndex), [0, 1, 2]);
    expect(api.completeCalls, 1);
    expect(progress.last, 1.0);
    expect(await db.select(db.pendingUploads).get(), isEmpty);
  });

  test('upload : un morceau en échec → exception, ligne pending conservée', () async {
    final (svc, db, src, _, api) = await _setup(failing: {1});
    await expectLater(svc.upload(3, src), throwsA(isA<PartUploadFailed>()));
    expect(api.completeCalls, 0);
    expect((await db.select(db.pendingUploads).get()).single.uploadId, 'u1');
  });

  test('resume : ne renvoie que les morceaux manquants puis complete', () async {
    final (svc, db, src, transport, api) = await _setup(received: [0, 2]);
    await db.into(db.pendingUploads).insert(PendingUploadsCompanion.insert(
      uploadId: 'u1', refId: 3, filePath: src.path, sizeBytes: 25, partSize: 10, partsTotal: 3, createdAt: DateTime.now(),
    ));

    final r = await svc.resume();

    expect(r?.jobId, 'j');
    expect(transport.enqueued.map((p) => p.partIndex), [1]);
    expect(api.initCalls, 0);
    expect(await db.select(db.pendingUploads).get(), isEmpty);
  });

  test('resume : upload expiré → UploadExpiredException et ligne supprimée', () async {
    final (svc, db, src, _, _) = await _setup(statusError: const UploadExpiredException());
    await db.into(db.pendingUploads).insert(PendingUploadsCompanion.insert(
      uploadId: 'u1', refId: 3, filePath: src.path, sizeBytes: 25, partSize: 10, partsTotal: 3, createdAt: DateTime.now(),
    ));
    await expectLater(svc.resume(), throwsA(isA<UploadExpiredException>()));
    expect(await db.select(db.pendingUploads).get(), isEmpty);
  });

  test('resume sans ligne → null', () async {
    final (svc, _, _, _, _) = await _setup();
    expect(await svc.resume(), isNull);
  });
}
```

- [ ] **Step 2 : Lancer → rouges** — Run: `flutter test test/core/upload`.

- [ ] **Step 3 : Implémenter**

`part_splitter.dart` :
```dart
import 'dart:io';

class PartSplitter {
  static Future<List<File>> split(File source, int partSize, Directory dir, {Set<int> only = const {}}) async {
    await dir.create(recursive: true);
    final length = await source.length();
    final total = (length + partSize - 1) ~/ partSize;
    final raf = await source.open();
    final out = <File>[];
    try {
      for (var n = 0; n < total; n++) {
        if (only.isNotEmpty && !only.contains(n)) continue;
        final start = n * partSize;
        final size = (n == total - 1) ? length - start : partSize;
        await raf.setPosition(start);
        final bytes = await raf.read(size);
        final f = File('${dir.path}/part_$n');
        await f.writeAsBytes(bytes, flush: true);
        out.add(f);
      }
    } finally {
      await raf.close();
    }
    return out;
  }
}
```

`part_transport.dart` :
```dart
import 'dart:async';
import 'dart:io';

class PartUpload {
  const PartUpload({required this.uploadId, required this.partIndex, required this.file});
  final String uploadId;
  final int partIndex;
  final File file;
}

sealed class PartEvent {
  const PartEvent(this.uploadId, this.partIndex);
  final String uploadId;
  final int partIndex;
}

class PartProgress extends PartEvent {
  const PartProgress(super.uploadId, super.partIndex, this.fraction);
  final double fraction;
}

class PartDone extends PartEvent {
  const PartDone(super.uploadId, super.partIndex);
}

class PartFailed extends PartEvent {
  const PartFailed(super.uploadId, super.partIndex, this.error);
  final Object error;
}

abstract class PartTransport {
  Future<void> enqueue(PartUpload part);
  Stream<PartEvent> get events;
  Future<Set<int>> queued(String uploadId);
  Future<void> cancelAll(String uploadId);
}

/// Transport de test : chaque morceau est "envoyé" immédiatement (ou échoue s'il est dans [failing]).
class InMemoryPartTransport implements PartTransport {
  InMemoryPartTransport({this.failing = const {}});
  final Set<int> failing;
  final List<PartUpload> enqueued = [];
  final _controller = StreamController<PartEvent>.broadcast();

  @override
  Stream<PartEvent> get events => _controller.stream;

  @override
  Future<void> enqueue(PartUpload part) async {
    enqueued.add(part);
    scheduleMicrotask(() {
      _controller.add(PartProgress(part.uploadId, part.partIndex, 1));
      _controller.add(failing.contains(part.partIndex)
          ? PartFailed(part.uploadId, part.partIndex, StateError('fail'))
          : PartDone(part.uploadId, part.partIndex));
    });
  }

  @override
  Future<Set<int>> queued(String uploadId) async => {};

  @override
  Future<void> cancelAll(String uploadId) async {}
}
```

`chunked_upload_service.dart` :
```dart
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/upload/part_splitter.dart';
import 'package:collega_app/core/upload/part_transport.dart';
import 'package:collega_app/core/upload/upload_api.dart';
import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/colleges/domain/import_models.dart';

class PartUploadFailed implements Exception {
  const PartUploadFailed(this.partIndex, this.error);
  final int partIndex;
  final Object error;
}

/// Mène un PDF de `init` à `complete` par morceaux, avec reprise via `pending_uploads`.
class ChunkedUploadService {
  ChunkedUploadService({required this.api, required this.transport, required this.db, required this.cacheDir});

  final UploadApi api;
  final PartTransport transport;
  final AppDatabase db;
  final Directory cacheDir;

  static const int chunkThreshold = 90 * 1024 * 1024;
  static const int maxSize = 500 * 1024 * 1024;

  Future<bool> hasPending() async => (await db.select(db.pendingUploads).get()).isNotEmpty;

  Future<ImportStartResponse> upload(int refId, File file, {void Function(double)? onProgress}) async {
    final size = await file.length();
    final init = await api.init(refId, size);
    await db.into(db.pendingUploads).insertOnConflictUpdate(PendingUploadsCompanion.insert(
      uploadId: init.uploadId, refId: refId, filePath: file.path, sizeBytes: size,
      partSize: init.partSize, partsTotal: init.partsTotal, createdAt: DateTime.now().toUtc(),
    ));
    return _send(init.uploadId, file, init.partSize, init.partsTotal, {}, onProgress);
  }

  Future<ImportStartResponse?> resume({void Function(double)? onProgress}) async {
    final rows = await db.select(db.pendingUploads).get();
    if (rows.isEmpty) return null;
    final row = rows.first;
    late final Set<int> received;
    try {
      received = (await api.status(row.uploadId)).received.toSet();
    } on UploadExpiredException {
      await _forget(row.uploadId);
      rethrow;
    }
    return _send(row.uploadId, File(row.filePath), row.partSize, row.partsTotal, received, onProgress);
  }

  Future<ImportStartResponse> _send(String uploadId, File file, int partSize, int partsTotal,
      Set<int> received, void Function(double)? onProgress) async {
    final missing = {for (var n = 0; n < partsTotal; n++) if (!received.contains(n)) n};
    final alreadyQueued = await transport.queued(uploadId);
    final toSend = missing.difference(alreadyQueued);
    final fractions = <int, double>{for (final n in received) n: 1.0};
    void report() => onProgress?.call(fractions.values.fold(0.0, (a, b) => a + b) / partsTotal);
    report();

    final pending = Set<int>.from(missing);
    final done = Completer<void>();
    final sub = transport.events.where((e) => e.uploadId == uploadId).listen((e) {
      switch (e) {
        case PartProgress(:final partIndex, :final fraction):
          fractions[partIndex] = fraction;
          report();
        case PartDone(:final partIndex):
          fractions[partIndex] = 1.0;
          pending.remove(partIndex);
          report();
          if (pending.isEmpty && !done.isCompleted) done.complete();
        case PartFailed(:final partIndex, :final error):
          if (!done.isCompleted) done.completeError(PartUploadFailed(partIndex, error));
      }
    });
    try {
      final parts = await PartSplitter.split(file, partSize, Directory('${cacheDir.path}/parts_$uploadId'), only: toSend);
      for (final f in parts) {
        final n = int.parse(f.path.split('_').last);
        await transport.enqueue(PartUpload(uploadId: uploadId, partIndex: n, file: f));
      }
      if (pending.isNotEmpty) await done.future;
    } finally {
      await sub.cancel();
    }

    final result = await api.complete(uploadId);
    await _forget(uploadId);
    onProgress?.call(1.0);
    return result;
  }

  Future<void> _forget(String uploadId) async {
    await (db.delete(db.pendingUploads)..where((t) => t.uploadId.equals(uploadId))).go();
    final dir = Directory('${cacheDir.path}/parts_$uploadId');
    if (await dir.exists()) {
      await dir.delete(recursive: true).catchError((Object e) {
        AppLogger.warning('parts cleanup failed: $e', tag: 'ChunkedUploadService');
        return dir;
      });
    }
  }
}
```
(`Value` importé pour un futur `update` — le retirer si l'analyzer le signale inutilisé.)

- [ ] **Step 4 : Verts** — Run: `flutter test test/core/upload && flutter analyze lib/core/upload` — Expected: verts, 0 issue.

- [ ] **Step 5 : Commit**

```bash
git add collega_app/lib/core/upload collega_app/test/core/upload
git commit -m "feat(app): ChunkedUploadService — découpage, transport abstrait, reprise via pending_uploads (story 7.11)"
```

---

### Task 11 : `BackgroundPartTransport` (background_downloader) + providers + démarrage

**Files:**
- Modify: `collega_app/pubspec.yaml` (`background_downloader: 9.5.5`)
- Create: `collega_app/lib/core/upload/background_part_transport.dart`, `collega_app/lib/core/upload/upload_providers.dart`
- Modify: `collega_app/lib/main.dart:8-11`
- Test: `collega_app/test/core/upload/background_part_transport_test.dart` (construction de la tâche uniquement)

**Interfaces:**
- Consumes: `PartTransport`, `cloudflareAccessHeaders`, `backendBaseUrl`, `cfAccessClientId/Secret`
- Produces:
  ```dart
  class BackgroundPartTransport implements PartTransport { BackgroundPartTransport({FileDownloader? downloader}); static UploadTask buildTask(PartUpload part) }
  final chunkedUploadServiceProvider = Provider<ChunkedUploadService>
  ```

- [ ] **Step 1 : Dépendance** — dans `pubspec.yaml` sous `# HTTP client` : `background_downloader: 9.5.5` puis `flutter pub get`.

- [ ] **Step 2 : Test (rouge)**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:collega_app/core/upload/background_part_transport.dart';
import 'package:collega_app/core/upload/part_transport.dart';
import 'package:collega_app/env.dart';

void main() {
  test('buildTask : PUT binaire vers /parts/{n}, group college-import, metaData uploadId|n', () {
    final task = BackgroundPartTransport.buildTask(
      PartUpload(uploadId: 'u1', partIndex: 4, file: File('/tmp/parts_u1/part_4')),
    );
    expect(task.url, '$backendBaseUrl/v1/colleges/import/u1/parts/4');
    expect(task.httpRequestMethod, 'PUT');
    expect(task.post, 'binary');
    expect(task.group, 'college-import');
    expect(task.metaData, 'u1|4');
    expect(task.retries, 3);
    expect(task.headers['Content-Type'], 'application/octet-stream');
  });
}
```

- [ ] **Step 3 : Lancer → rouge** — Run: `flutter test test/core/upload/background_part_transport_test.dart`.

- [ ] **Step 4 : Implémenter**

`background_part_transport.dart` :
```dart
import 'dart:async';

import 'package:background_downloader/background_downloader.dart';

import 'package:collega_app/core/network/cloudflare_access.dart';
import 'package:collega_app/core/upload/part_transport.dart';
import 'package:collega_app/env.dart';

/// Envoi des morceaux en arrière-plan (URLSession background / WorkManager) via background_downloader.
/// Les PUT parts n'ont pas besoin de JWT (upload_id = jeton, cf. spec §3.4) : seuls les headers Cloudflare sont joints.
class BackgroundPartTransport implements PartTransport {
  BackgroundPartTransport({FileDownloader? downloader}) : _dl = downloader ?? FileDownloader() {
    _dl.registerCallbacks(
      group: group,
      taskStatusCallback: _onStatus,
      taskProgressCallback: _onProgress,
    );
  }

  static const group = 'college-import';
  final FileDownloader _dl;
  final _events = StreamController<PartEvent>.broadcast();

  static UploadTask buildTask(PartUpload part) {
    final dir = part.file.parent.path;
    final name = part.file.uri.pathSegments.last;
    return UploadTask(
      taskId: '${part.uploadId}|${part.partIndex}',
      url: '$backendBaseUrl/v1/colleges/import/${part.uploadId}/parts/${part.partIndex}',
      httpRequestMethod: 'PUT',
      post: 'binary',
      baseDirectory: BaseDirectory.root,
      directory: dir,
      filename: name,
      headers: {
        'Content-Type': 'application/octet-stream',
        ...cloudflareAccessHeaders(clientId: cfAccessClientId, clientSecret: cfAccessClientSecret),
      },
      group: group,
      retries: 3,
      allowPause: true,
      updates: Updates.statusAndProgress,
      metaData: '${part.uploadId}|${part.partIndex}',
    );
  }

  static (String, int) _parse(Task t) {
    final parts = t.metaData.split('|');
    return (parts[0], int.parse(parts[1]));
  }

  void _onStatus(TaskStatusUpdate u) {
    final (uploadId, n) = _parse(u.task);
    switch (u.status) {
      case TaskStatus.complete:
        _events.add(PartDone(uploadId, n));
      case TaskStatus.failed || TaskStatus.notFound || TaskStatus.canceled:
        _events.add(PartFailed(uploadId, n, u.exception ?? u.status));
      default:
        break;
    }
  }

  void _onProgress(TaskProgressUpdate u) {
    if (u.progress < 0) return; // valeurs négatives = états spéciaux du package
    final (uploadId, n) = _parse(u.task);
    _events.add(PartProgress(uploadId, n, u.progress));
  }

  @override
  Stream<PartEvent> get events => _events.stream;

  @override
  Future<void> enqueue(PartUpload part) async {
    final ok = await _dl.enqueue(buildTask(part));
    if (!ok) _events.add(PartFailed(part.uploadId, part.partIndex, StateError('enqueue refused')));
  }

  @override
  Future<Set<int>> queued(String uploadId) async {
    final records = await _dl.database.allRecords(group: group);
    return {
      for (final r in records)
        if (r.task.metaData.startsWith('$uploadId|') && (r.status == TaskStatus.enqueued || r.status == TaskStatus.running || r.status == TaskStatus.paused || r.status == TaskStatus.waitingToRetry))
          int.parse(r.task.metaData.split('|')[1]),
    };
  }

  @override
  Future<void> cancelAll(String uploadId) async {
    final records = await _dl.database.allRecords(group: group);
    final ids = [for (final r in records) if (r.task.metaData.startsWith('$uploadId|')) r.taskId];
    if (ids.isNotEmpty) await _dl.cancelTasksWithIds(ids);
  }
}
```
Si un nom d'API du package diffère en 9.5.5 (`allRecords(group:)`, `cancelTasksWithIds`, `TaskStatus.waitingToRetry`), adapter en consultant `~/.pub-cache/hosted/pub.dev/background_downloader-9.5.5/lib/` — **ne pas** changer les interfaces `PartTransport`.

`upload_providers.dart` :
```dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/network/api_providers.dart';
import 'package:collega_app/core/upload/background_part_transport.dart';
import 'package:collega_app/core/upload/chunked_upload_service.dart';
import 'package:collega_app/core/upload/part_transport.dart';
import 'package:collega_app/core/upload/upload_api.dart';

final uploadApiProvider = Provider<UploadApi>((ref) => DioUploadApi(dio: ref.read(apiClientProvider).dio));
final partTransportProvider = Provider<PartTransport>((_) => BackgroundPartTransport());
final uploadCacheDirProvider = FutureProvider<Directory>((_) async => getTemporaryDirectory());

final chunkedUploadServiceProvider = FutureProvider<ChunkedUploadService>((ref) async => ChunkedUploadService(
      api: ref.read(uploadApiProvider),
      transport: ref.read(partTransportProvider),
      db: ref.read(databaseProvider),
      cacheDir: await ref.watch(uploadCacheDirProvider.future),
    ));
```

`main.dart` : après `WidgetsFlutterBinding.ensureInitialized();` ajouter `await FileDownloader().start(autoCleanDatabase: true);` (import `package:background_downloader/background_downloader.dart`). iOS : aucun entitlement supplémentaire ; vérifier dans `ios/Runner/Info.plist` qu'il n'y a pas de restriction cellulaire.

- [ ] **Step 5 : Verts + analyse** — Run: `flutter test test/core/upload && flutter analyze lib/core/upload lib/main.dart` — Expected: verts, 0 issue.

- [ ] **Step 6 : Commit**

```bash
git add collega_app/pubspec.yaml collega_app/pubspec.lock collega_app/lib/core/upload collega_app/lib/main.dart collega_app/test/core/upload
git commit -m "feat(app): transport arrière-plan des morceaux via background_downloader 9.5.5 (story 7.11)"
```

---

### Task 12 : Intégration dans `CollegeImportNotifier` + UI + reprise au démarrage

**Files:**
- Modify: `collega_app/lib/features/colleges/domain/import_models.dart` (`ImportUploading`)
- Modify: `collega_app/lib/features/colleges/colleges_import_providers.dart` (`startImport`, `resumePendingUpload`)
- Modify: `collega_app/lib/features/colleges/presentation/college_import_screen.dart` (progression, messages)
- Modify: `collega_app/lib/features/colleges/presentation/colleges_screen.dart` (déclencher la reprise à l'affichage — ou l'écran racine où `reconnectIfActive` est déjà appelé au retour premier plan : suivre le même point d'accroche)
- Test: `collega_app/test/features/colleges/college_import_notifier_test.dart`

**Interfaces:**
- Consumes: `chunkedUploadServiceProvider` (Task 11), `FileTooLargeException` (Task 9)
- Produces:
  ```dart
  class ImportUploading extends CollegeImportState { const ImportUploading({this.progress}); final double? progress; }  // null = mono-requête
  // CollegeImportNotifier
  Future<void> startImport(int refId, File file)          // aiguillage 90/500 MB + upload_in_progress
  Future<void> resumePendingUpload()                       // appelé au démarrage / retour premier plan
  ```
  Nouveaux messages `ImportError` : `file_too_large`, `upload_in_progress`, `upload_expired`, `upload_failed`.

- [ ] **Step 1 : Tests (rouges)** — ajouter dans `college_import_notifier_test.dart` (compléter `_makeContainer` avec un override `chunkedUploadServiceProvider.overrideWith((ref) async => fakeService)` ; `_FakeChunkedUploadService extends ChunkedUploadService` avec `api: _FakeApi`, `transport: InMemoryPartTransport`, `db` en mémoire, `cacheDir` temp) :

```dart
    test('startImport > 500 MB → ImportError file_too_large sans appel réseau', () async {
      final repo = _FakeCollegeImportRepository();
      final container = _makeContainer(repo, apiClient: _FakeApiClient());
      addTearDown(container.dispose);
      final big = _SizedFile('${Directory.systemTemp.path}/big.pdf', 500 * 1024 * 1024 + 1);

      await container.read(collegeImportProvider.notifier).startImport(15, big);

      final state = container.read(collegeImportProvider).valueOrNull;
      expect(state, isA<ImportError>());
      expect((state as ImportError).message, 'file_too_large');
    });

    test('startImport > 90 MB → passe par ChunkedUploadService puis ImportStreaming', () async {
      final repo = _FakeCollegeImportRepository();
      final fakeSvc = await _makeFakeChunkedService();
      final container = _makeContainer(repo, apiClient: _FakeApiClient(), chunked: fakeSvc);
      addTearDown(container.dispose);
      final big = _SizedFile('${Directory.systemTemp.path}/mid.pdf', 90 * 1024 * 1024 + 1);
      final states = <CollegeImportState>[];
      container.listen<AsyncValue<CollegeImportState>>(collegeImportProvider, (_, n) { if (n.valueOrNull != null) states.add(n.value!); });

      await container.read(collegeImportProvider.notifier).startImport(15, big);

      expect(states.whereType<ImportUploading>().any((s) => s.progress != null), isTrue);
      expect(states.last, isA<ImportStreaming>());
      expect(fakeSvc.uploadCalls, 1);
    });

    test('startImport avec pending_uploads existant → upload_in_progress', () async {
      final repo = _FakeCollegeImportRepository();
      final fakeSvc = await _makeFakeChunkedService(pending: true);
      final container = _makeContainer(repo, apiClient: _FakeApiClient(), chunked: fakeSvc);
      addTearDown(container.dispose);
      final big = _SizedFile('${Directory.systemTemp.path}/mid2.pdf', 90 * 1024 * 1024 + 1);

      await container.read(collegeImportProvider.notifier).startImport(15, big);

      expect((container.read(collegeImportProvider).valueOrNull as ImportError).message, 'upload_in_progress');
    });

    test('resumePendingUpload : reprise → ImportStreaming', () async {
      final repo = _FakeCollegeImportRepository();
      final fakeSvc = await _makeFakeChunkedService(pending: true);
      final container = _makeContainer(repo, apiClient: _FakeApiClient(), chunked: fakeSvc);
      addTearDown(container.dispose);

      await container.read(collegeImportProvider.notifier).resumePendingUpload();

      expect(container.read(collegeImportProvider).valueOrNull, isA<ImportStreaming>());
      expect(fakeSvc.resumeCalls, 1);
    });
```
`_SizedFile` : sous-classe minimale de `File` (via `implements File` + `noSuchMethod`) dont `length()` renvoie la taille voulue sans écrire le fichier ; `_FakeChunkedUploadService` : override `upload`/`resume`/`hasPending` pour compter les appels et renvoyer `ImportStartResponse(collegeId:'c', jobId:'j', status:'pending')` en appelant `onProgress(0.5)` puis `onProgress(1)`.

- [ ] **Step 2 : Lancer → rouges** — Run: `flutter test test/features/colleges/college_import_notifier_test.dart`.

- [ ] **Step 3 : Implémenter**

`import_models.dart` :
```dart
class ImportUploading extends CollegeImportState {
  const ImportUploading({this.progress});
  /// Progression 0..1 de l'upload par morceaux ; null pour l'upload mono-requête.
  final double? progress;
}
```

`colleges_import_providers.dart` — remplacer le début de `startImport` :
```dart
  Future<void> startImport(int refId, File file) async {
    state = const AsyncValue.data(ImportUploading());
    try {
      final size = await file.length();
      if (size > ChunkedUploadService.maxSize) {
        state = const AsyncValue.data(ImportError(message: 'file_too_large'));
        return;
      }
      final ImportStartResponse response;
      if (size > ChunkedUploadService.chunkThreshold) {
        final chunked = await ref.read(chunkedUploadServiceProvider.future);
        if (await chunked.hasPending()) {
          state = const AsyncValue.data(ImportError(message: 'upload_in_progress'));
          return;
        }
        response = await chunked.upload(refId, file, onProgress: _onUploadProgress);
      } else {
        final repo = ref.read(collegeImportRepositoryProvider);
        response = await repo.importPdf(refId, file);
      }
      await _afterUploadAccepted(refId, response);
    } on FileTooLargeException {
      state = const AsyncValue.data(ImportError(message: 'file_too_large'));
    } on UploadExpiredException {
      state = const AsyncValue.data(ImportError(message: 'upload_expired'));
    } on PartUploadFailed catch (e) {
      AppLogger.error('part upload failed', tag: 'CollegeImportNotifier', error: e.error);
      state = const AsyncValue.data(ImportError(message: 'upload_failed'));
    } on SubscriptionRequiredException {
      // … (les catch existants restent inchangés)
```
et extraire le bloc existant « insert Drift `collegeImports` + `ImportStreaming` + `_connectSse` » dans :
```dart
  Future<void> _afterUploadAccepted(int refId, ImportStartResponse response) async {
    final db = ref.read(databaseProvider);
    await db.into(db.collegeImports).insertOnConflictUpdate(CollegeImportsCompanion.insert(
      id: response.collegeId, refId: refId, jobId: response.jobId, status: response.status, updatedAt: DateTime.now().toUtc(),
    ));
    state = AsyncValue.data(ImportStreaming(collegeId: response.collegeId, jobId: response.jobId, ocrProgress: 0, totalPages: null, status: 'pending'));
    await _connectSse(response.collegeId);
  }

  void _onUploadProgress(double p) {
    if (_disposed) return;
    if (state.valueOrNull is ImportUploading) state = AsyncValue.data(ImportUploading(progress: p));
  }

  /// Reprise d'un upload par morceaux interrompu (démarrage / retour premier plan).
  Future<void> resumePendingUpload() async {
    final chunked = await ref.read(chunkedUploadServiceProvider.future);
    if (!await chunked.hasPending() || _disposed) return;
    state = const AsyncValue.data(ImportUploading(progress: 0));
    try {
      final rows = await ref.read(databaseProvider).select(ref.read(databaseProvider).pendingUploads).get();
      final refId = rows.first.refId;
      final response = await chunked.resume(onProgress: _onUploadProgress);
      if (response != null) await _afterUploadAccepted(refId, response);
    } on UploadExpiredException {
      state = const AsyncValue.data(ImportError(message: 'upload_expired'));
    } on PartUploadFailed {
      state = const AsyncValue.data(ImportError(message: 'upload_failed'));
    } catch (e) {
      AppLogger.warning('resumePendingUpload failed: $e', tag: 'CollegeImportNotifier');
      state = const AsyncValue.data(ImportError(message: 'network_error'));
    }
  }
```
Imports à ajouter : `chunked_upload_service.dart`, `upload_models.dart`, `upload_providers.dart`.

`college_import_screen.dart` — bloc `isUploading` :
```dart
            if (importAsync.valueOrNull case ImportUploading(:final progress))
              Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: Center(child: LinearProgressIndicator(value: progress, color: AppColors.primary)),
                  ),
                  const SizedBox(height: AppSpacing.baseUnit),
                  Text(
                    progress == null
                        ? 'Upload en cours…'
                        : 'Upload en cours (${(progress * 100).round()} %) — continue en arrière-plan',
                    style: AppTypography.bodyMedium(),
                  ),
                ],
              )
            else
```
et dans `_handleError`, avant `default:` :
```dart
      case 'file_too_large':
        ShadToaster.of(context).show(const ShadToast.destructive(title: Text('PDF trop volumineux (max 500 Mo)')));
      case 'upload_in_progress':
        ShadToaster.of(context).show(const ShadToast(title: Text('Un upload est déjà en cours — patientez')));
      case 'upload_expired':
        ShadToaster.of(context).show(const ShadToast.destructive(title: Text('Upload expiré — relancez l\'import')));
      case 'upload_failed':
        ShadToaster.of(context).show(const ShadToast.destructive(title: Text('Envoi interrompu — l\'import reprendra automatiquement')));
```
Reprise : à l'endroit où l'app appelle déjà `reconnectIfActive` au retour premier plan (chercher `reconnectIfActive(` dans `lib/` — écran de progression / `AppLifecycleListener`), appeler aussi `ref.read(collegeImportProvider.notifier).resumePendingUpload()` ; et une fois au démarrage dans l'écran des collèges (`initState` → `Future.microtask`).

- [ ] **Step 4 : Verts + suite app complète** — Run: `flutter test && flutter analyze` — Expected: tous verts, 0 nouveau warning.

- [ ] **Step 5 : Commit**

```bash
git add collega_app/lib collega_app/test
git commit -m "feat(app): import par morceaux — aiguillage 90 MB, progression, reprise au démarrage (story 7.11)"
```

---

### Task 13 : Vérification réelle et clôture

**Files:**
- Modify: `_bmad-output/implementation-artifacts/7-11-upload-pdf-100mb-tunnel-cloudflare.md` (Dev Agent Record, File List), `_bmad-output/implementation-artifacts/sprint-status.yaml`

- [ ] **Step 1 : Déployer le backend** — suivre le runbook Kage « Déployer le backend en prod » : `docker build --platform linux/amd64 -t tistech0/collega-backend:latest .` → `docker push` → `ssh nas 'cd /mnt/user/appdata/compose-stacks/collega && docker compose pull api worker migrate && docker compose up -d'` ; vérifier `docker logs collega-api-1 | tail`.

- [ ] **Step 2 : Test CANCERO 411 MB via Cloudflare (curl)**

Run: `cd collega_backend && .venv/bin/python scripts/chunked_upload.py "../CANCERO 4e college (1).pdf" --ref-id 3 --email jerome@collega.fr --password '<mdp>' --cloudflare-ip 172.67.211.66 --env-file ../collega_app/.env.local`
Expected: `init 201`, 17 × `HTTP 204`, `complete 202`. Puis `ssh nas 'docker logs --since 5m collega-worker-1 | grep -v cron'` montre `process_college_ocr` démarré. Couper le script après 5 morceaux (Ctrl-C) et relancer avec `--resume <upload_id>` : seuls les morceaux manquants sont envoyés.

- [ ] **Step 3 : Test iPhone en 4G** — `collega_app/tool/run_device.sh --release -d <udid>` ; Wi-Fi coupé ; importer CANCERO ; passer l'app en arrière-plan 2 min pendant l'upload ; revenir : la progression continue puis l'écran de progression OCR s'ouvre. Noter les temps.

- [ ] **Step 4 : Story + sprint-status** — remplir `Dev Agent Record` (fichiers, tests, temps mesurés), passer `7-11-…: review` dans `sprint-status.yaml` avec un commentaire d'une ligne.

- [ ] **Step 5 : Commit + push**

```bash
git add _bmad-output/implementation-artifacts/7-11-upload-pdf-100mb-tunnel-cloudflare.md _bmad-output/implementation-artifacts/sprint-status.yaml
git commit -m "docs(story-7.11): vérification réelle 411 MB via Cloudflare + passage en review"
git push
```

---

## Auto-revue du plan

**Couverture spec → tâches** : §3.1 routes (T3, T4, T5) ; §3.2 état/stockage (T2) ; §3.3 complete + claim + restore (T5) ; §3.4 sécurité (T3/T4 : pas de JWT sur parts/status, complete vérifie user_id) ; §3.5 refacto (T1) ; §3.6 purge (T6) ; §4.1 aiguillage (T12) ; §4.2 service (T10) ; §4.3 background (T11) ; §4.4 persistance/reprise (T8, T10, T12) ; §4.5 erreurs (T9, T12) ; §5 tests (chaque tâche) + réel (T7, T13).

**Écart assumé** : la spec §3.3 prévoit `UPLOAD_INCOMPLETE` avant `claim` — respecté ; le cas « double complete » est traité en deux variantes (404 si l'état a déjà disparu, 409 si `claim` perd) — documenté dans T5.

**Cohérence des noms** : `ChunkedUploadStore.{create,get,write_part,claim,restore,assemble,purge,stale_dirs}` (T2) utilisés à l'identique en T3/T4/T5/T6 ; `mapImportDioError`, `FileTooLargeException`, `UploadExpiredException`, `UploadIncompleteException` (T9) utilisés en T10/T12 ; `PartTransport.{enqueue,events,queued,cancelAll}` (T10) implémentés en T11 ; `ChunkedUploadService.{upload,resume,hasPending,chunkThreshold,maxSize}` (T10) consommés en T12 ; `PartUploadFailed` défini en T10, attrapé en T12.

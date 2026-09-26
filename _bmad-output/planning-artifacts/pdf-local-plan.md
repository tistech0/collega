# Partie B — Le PDF sur le téléphone : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Relire le PDF importé depuis la vue collège (tout le PDF) et depuis un item (à la page de l'item), hors connexion, avec retéléchargement depuis le serveur quand la copie locale manque.

**Architecture:** Le serveur expose la version (id du dernier job publié) et la taille du PDF courant dans la liste des collèges, les pages de chaque item, et une route de téléchargement réservée au propriétaire. L'app garde une copie `<collegeId>_<jobId>.pdf` dans `Application Support/pdfs/` (exclue de la sauvegarde iCloud) : copiée à l'import, sinon téléchargée par `background_downloader`. Un lecteur `pdfrx` ouvre tout le PDF à la page demandée.

**Tech Stack:** FastAPI + SQLAlchemy async (Starlette 1.7 : `FileResponse` gère `Range`), pytest ; Flutter 3.27.1 / Dart 3.6, Riverpod 2, drift, go_router, `background_downloader` 9.5.5, `pdfrx` 1.0.103.

**Spec:** `_bmad-output/planning-artifacts/recherche-pdf-avis-drill-accueil-spec.md`, partie B (lire la partie B en entier avant de commencer).

## Global Constraints

- Livrée **après** la partie D (Accueil), qui prend la migration drift 8 → 9 (`quiet_days`). Cette partie prend **9 → 10**. Si D n'est pas encore mergée, s'arrêter et le signaler : ne pas prendre la 9.
- Aucune migration serveur (Alembic) : `alembic check` doit rester propre.
- Backend : routes HTTP seulement (`app/api/v1/colleges/`), logique dans `app/services/imports.py` ; erreurs uniquement via `AppError` et les fabriques de `app/core/errors.py` (jamais `HTTPException`) ; succès `{"data": …}`, erreurs `{"detail": {"code": "CODE", "message": "…"}}`.
- Backend qualité : `docker compose -f docker-compose.test.yml up -d` puis `.venv/bin/python -m pytest -q`, `.venv/bin/ruff check .`, `.venv/bin/ruff format --check .`, `.venv/bin/mypy app/core app/services` à **0 erreur**. Image Python 3.11 : pas de syntaxe > 3.11.
- App : `flutter test` **par dossier** (`test/core`, puis chaque `test/features/<dossier>` touché), jamais toute la suite d'un coup.
- Pages : `items.start_page` / `end_page` sont en **base 0** (index de page de `item_detector`) ; l'app affiche et navigue en **base 1** (`start_page + 1`). `pdfrx` numérote les pages à partir de 1.
- Version du PDF = **id du dernier job `generation_complete`** du collège (`pdf_version`), pas `pdf_hash` (voir « Écarts avec la spec »).
- Copie locale : `Application Support/pdfs/<collegeId>_<jobId>.pdf`, exclue de la sauvegarde iCloud ; supprimée quand la synchro retire le collège et quand **un autre compte** se connecte (la simple déconnexion ne supprime rien).
- Textes app en français, tutoiement, apostrophe typographique `’`. Libellés exacts : « Mon PDF du collège », « sur ce téléphone », « à télécharger · N Mo », « Lire dans le PDF · p. X–Y », « Vérifier dans le PDF », « Ton PDF n’est pas sur ce téléphone », « Télécharger (N Mo) », « Une nouvelle version de ton PDF est disponible », « ↑ Début », « p. N / T ».
- Déploiement serveur uniquement via `collega_backend/scripts/deploy.sh <sha>` (CI verte). Jamais `latest`.
- Commits : messages en français, préfixes `feat(pdf)`, `test(pdf)`, `chore(pdf)`, terminés par `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

## Écarts avec la spec (décidés ici, à valider en revue)

1. **Version = id de job, pas `pdf_hash`.** `generation_jobs.pdf_hash` est nullable (imports anciens) et l'app ne connaît pas l'empreinte de sa copie sans relire 400 Mo. L'id du job publié est toujours présent, et l'app le reçoit déjà à l'import (`ImportStartResponse.jobId`). Le nom de fichier local reprend la convention serveur `{college_id}_{job_id}.pdf`.
2. **Avertissement « données mobiles » toujours affiché** (« Le Wi-Fi est conseillé ») au lieu d'être conditionnel : l'app n'a pas de paquet de détection du réseau (`connectivity_plus` absent) ; on n'en ajoute pas pour une phrase.
3. **`pdfrx` épinglé à 1.0.103** : dernière version compatible Flutter 3.27 / Dart 3.6 (toutes les 1.1.x+ exigent Flutter ≥ 3.29). Vérifié sur pub.dev le 2026-09-26.
4. **Pas d'`ETag` = empreinte** : `FileResponse` pose déjà un `ETag` (taille + date) et gère `Range`/206 ; la version passe par `pdf_version`.

## Review Focus

1. **PDF de 400 Mo via le tunnel Cloudflare en 4G** : le téléchargement doit aboutir (ou échouer proprement avec « Réessayer ») sans bloquer l'app ; un échec ne laisse jamais de fichier partiel pris pour une copie valide. → Task 8 teste « échec = pas de fichier final, état `failed` ».
2. **Réimport en cours** : la nouvelle copie (job non publié) ne doit ni remplacer ni faire supprimer l'ancienne tant que le serveur n'a pas publié ; les numéros de page doivent correspondre au PDF affiché. → Task 6 teste « copie plus récente non publiée conservée, ancienne toujours `upToDate` ».
3. **Le PDF d'un autre compte** : jamais servi, et l'existence du collège ne fuit pas (404 identique). → Task 4.
4. **Item sans page connue** (import ancien, `start_page` NULL) : aucun lien, aucun crash dans l'item ni dans la feuille OCR. → Task 10.
5. **Changement de compte sur le même iPhone** : aucun PDF du compte précédent ne reste lisible. → Task 7.

---

## File Structure

Backend — créés :
- `collega_backend/app/api/v1/colleges/pdf.py` — `GET /v1/colleges/{college_id}/pdf`.
- `collega_backend/tests/services/test_current_pdfs.py`, `collega_backend/tests/api/test_college_pdf.py`.

Backend — modifiés :
- `app/services/imports.py` — `CurrentPdf`, `current_pdfs()`.
- `app/api/v1/colleges/__init__.py` (routeur), `catalog.py` (`pdf_version`, `pdf_size`), `cards.py` (`start_page`, `end_page`).
- `app/schemas/college.py` — `UserCollegeData`, `ItemSummaryData`.
- `tests/api/test_colleges.py` (`_make_item`, listes `side_effect`), `tests/api/test_college_cards.py`.

App — créés (nouveau dossier de fonctionnalité `features/pdf/`) :
- `lib/features/pdf/data/local_pdf_store.dart` — copie locale, statut, dernière page lue.
- `lib/features/pdf/data/backup_excluder.dart` — canal natif « exclure de la sauvegarde ».
- `lib/features/pdf/data/pdf_downloader.dart` — interface + implémentation `background_downloader`.
- `lib/features/pdf/domain/pdf_labels.dart` — libellés de pages et de tailles.
- `lib/features/pdf/pdf_providers.dart` — providers, `PdfDownloadNotifier`.
- `lib/features/pdf/presentation/pdf_reader_screen.dart` — écran (statut → lecteur ou téléchargement).
- `lib/features/pdf/presentation/pdf_missing_view.dart` — « Ton PDF n’est pas sur ce téléphone ».
- `lib/features/pdf/presentation/pdf_document_view.dart` — enveloppe de `pdfrx` (remplaçable en test).
- Tests : `test/core/database/migration_v10_test.dart`, `test/features/pdf/*.dart`.

App — modifiés :
- `pubspec.yaml` (`pdfrx: 1.0.103`), `ios/Runner/AppDelegate.swift` (canal `collega/backup`).
- `lib/core/database/app_database.dart`, `tables/items_table.dart`, `tables/user_colleges_table.dart`.
- `lib/features/colleges/domain/college_detail_models.dart` (`ItemModel`), `domain/college_models.dart` (`UserCollegeStatus`).
- `lib/features/colleges/data/college_cards_sync.dart`, `data/college_detail_repository.dart`, `colleges_providers.dart`, `colleges_detail_providers.dart` (`itemInfoProvider`), `colleges_import_providers.dart`.
- `lib/features/auth/data/local_data_owner.dart`, `lib/features/auth/auth_providers.dart`.
- `lib/core/router/app_router.dart` (route du lecteur).
- `lib/features/colleges/presentation/college_detail_screen.dart`, `item_detail_screen.dart`.
- Tests existants : `test/features/colleges/*`, `test/features/auth/local_data_owner_test.dart`.

---

### Task 1: `pdfrx` 1.0.103 s'installe et compile pour iOS

**Files:**
- Modify: `collega_app/pubspec.yaml`, `collega_app/pubspec.lock`, `collega_app/ios/Podfile.lock`

**Interfaces:**
- Produces: dépendance `pdfrx` (API utilisée plus tard : `PdfViewer.file(String path, {PdfViewerController? controller, PdfViewerParams params, int initialPageNumber = 1})`, `PdfViewerParams(onViewerReady: (document, controller) {…}, onPageChanged: (int? pageNumber) {…})`, `PdfViewerController.goToPage({required int pageNumber})`, `controller.pageCount`).

- [ ] **Step 1: Ajouter la dépendance épinglée**

Dans `collega_app/pubspec.yaml`, sous `# File picker (import PDF)` :

```yaml
  # Lecteur PDF (partie B) — 1.0.103 : dernière version compatible Flutter 3.27 / Dart 3.6
  # (les 1.1.x+ exigent Flutter >= 3.29).
  pdfrx: 1.0.103
```

- [ ] **Step 2: Résoudre**

Run (depuis `collega_app/`) : `flutter pub get`
Expected : `Got dependencies!` sans conflit. En cas de conflit de version (`collection`, `rxdart`, `web`, `http`), le noter et **arrêter** : repli ci-dessous.

- [ ] **Step 3: Compiler iOS**

Run : `cd ios && pod install && cd .. && flutter build ios --no-codesign --debug`
Expected : `Built build/ios/iphoneos/Runner.app`. Le podspec de pdfrx télécharge `pdfium.xcframework` au premier `pod install` (réseau requis).

- [ ] **Step 4: Repli documenté (seulement si Step 2 ou 3 échoue)**

Ne pas bricoler : retirer `pdfrx`, revenir au commit précédent, et remonter à l'humain la sortie d'erreur exacte avec ce choix : (a) PDFKit natif via une `UiKitView` (`PDFView` + canal pour `goToPage` / page courante), ou (b) montée de Flutter ≥ 3.29 (hors périmètre de cette partie). Les tâches 9 et 10 ne dépendent que de `PdfDocumentView` (Task 9), donc seul ce fichier changerait.

- [ ] **Step 5: Vérifier que rien d'autre ne casse**

Run : `flutter analyze` puis `flutter test test/core`
Expected : aucune nouvelle erreur, tests verts.

- [ ] **Step 6: Commit**

```bash
git add collega_app/pubspec.yaml collega_app/pubspec.lock collega_app/ios/Podfile.lock
git commit -m "chore(pdf): pdfrx 1.0.103 (compatible Flutter 3.27)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Service `current_pdfs` — le PDF en service de chaque collège

**Files:**
- Modify: `collega_backend/app/services/imports.py`
- Test: `collega_backend/tests/services/test_current_pdfs.py`

**Interfaces:**
- Consumes: `pdf_path_for(college_id, job_id) -> Path` (déjà dans `app/services/imports.py`), `GenerationJob` (`app/models/generation_job.py`).
- Produces:
  - `@dataclass(frozen=True) class CurrentPdf: job_id: uuid.UUID; path: Path; size: int`
  - `async def current_pdfs(db: AsyncSession, college_ids: Sequence[uuid.UUID]) -> dict[uuid.UUID, CurrentPdf]` — pour chaque collège, le dernier job `generation_complete` (par `created_at` décroissant) **dont le fichier existe** ; collège absent du dict sinon.

- [ ] **Step 1: Écrire les tests qui échouent**

`collega_backend/tests/services/test_current_pdfs.py` :

```python
"""Partie B — PDF en service d'un collège : dernier import publié dont le fichier existe."""

import uuid
from unittest.mock import AsyncMock, MagicMock

from app.core.config import settings
from app.services import imports as import_service


def _rows(rows):
    return MagicMock(all=MagicMock(return_value=rows))


async def test_liste_vide_ne_touche_pas_la_base():
    db = MagicMock(execute=AsyncMock())
    assert await import_service.current_pdfs(db, []) == {}
    db.execute.assert_not_called()


async def test_retourne_le_pdf_du_dernier_job_publie(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "pdf_storage_path", str(tmp_path))
    college_id, job_id = uuid.uuid4(), uuid.uuid4()
    (tmp_path / f"{college_id}_{job_id}.pdf").write_bytes(b"%PDF-1.7 abc")
    db = MagicMock(execute=AsyncMock(return_value=_rows([(college_id, job_id)])))

    found = await import_service.current_pdfs(db, [college_id])

    assert found[college_id].job_id == job_id
    assert found[college_id].size == len(b"%PDF-1.7 abc")
    assert found[college_id].path == tmp_path / f"{college_id}_{job_id}.pdf"


async def test_fichier_absent_collège_ignore(tmp_path, monkeypatch):
    monkeypatch.setattr(settings, "pdf_storage_path", str(tmp_path))
    college_id, job_id = uuid.uuid4(), uuid.uuid4()
    db = MagicMock(execute=AsyncMock(return_value=_rows([(college_id, job_id)])))

    assert await import_service.current_pdfs(db, [college_id]) == {}
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run (depuis `collega_backend/`) : `.venv/bin/python -m pytest -q tests/services/test_current_pdfs.py`
Expected : FAIL — `AttributeError: module 'app.services.imports' has no attribute 'current_pdfs'`.

- [ ] **Step 3: Implémenter**

Dans `app/services/imports.py`, section `# ── PDF ──`, après `pdf_path_for` (ajouter les imports manquants en tête : `from collections.abc import Sequence`, `from dataclasses import dataclass`, `from app.models.generation_job import GenerationJob` s'ils n'y sont pas déjà) :

```python
@dataclass(frozen=True)
class CurrentPdf:
    """PDF en service d'un collège (partie B) : celui du dernier import publié."""

    job_id: uuid.UUID
    path: Path
    size: int


async def current_pdfs(db: AsyncSession, college_ids: Sequence[uuid.UUID]) -> dict[uuid.UUID, CurrentPdf]:
    """Dernier job `generation_complete` de chaque collège dont le fichier existe encore.

    Pendant un réimport, le nouveau PDF est déjà sur le disque mais son job n'est pas publié :
    c'est l'ancien qui reste en service (ses numéros de page sont ceux des items en base)."""
    if not college_ids:
        return {}
    rows = (
        await db.execute(
            select(GenerationJob.college_id, GenerationJob.id)
            .where(
                GenerationJob.college_id.in_(list(college_ids)),
                GenerationJob.status == "generation_complete",
            )
            .order_by(GenerationJob.college_id, GenerationJob.created_at.desc())
            .distinct(GenerationJob.college_id)
        )
    ).all()
    found: dict[uuid.UUID, CurrentPdf] = {}
    for college_id, job_id in rows:
        path = pdf_path_for(college_id, job_id)
        try:
            size = path.stat().st_size
        except OSError:
            continue
        found[college_id] = CurrentPdf(job_id=job_id, path=path, size=size)
    return found
```

- [ ] **Step 4: Lancer, vérifier le succès**

Run : `.venv/bin/python -m pytest -q tests/services/test_current_pdfs.py` → PASS (3 tests).
Run : `.venv/bin/mypy app/core app/services` → `Success: no issues found`.

- [ ] **Step 5: Commit**

```bash
git add collega_backend/app/services/imports.py collega_backend/tests/services/test_current_pdfs.py
git commit -m "feat(pdf): service current_pdfs (PDF en service de chaque collège)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: API — pages des items et version du PDF dans la liste des collèges

**Files:**
- Modify: `collega_backend/app/schemas/college.py`, `app/api/v1/colleges/cards.py`, `app/api/v1/colleges/catalog.py`
- Test: `collega_backend/tests/api/test_college_cards.py`, `collega_backend/tests/api/test_colleges.py`

**Interfaces:**
- Consumes: `current_pdfs` (Task 2).
- Produces (JSON) :
  - `GET /v1/colleges/{id}/items` → chaque item gagne `start_page: int | null`, `end_page: int | null` (base 0).
  - `GET /v1/colleges` → chaque collège gagne `pdf_version: str | null` (id du job publié), `pdf_size: int | null` (octets).

- [ ] **Step 1: Adapter les fabriques de test**

Dans `tests/api/test_colleges.py`, `_make_item` gagne les pages (les tests existants restent valides) :

```python
def _make_item(college_id, item_id=None, item_number=232, rang="A", start_page=None, end_page=None):
    return types.SimpleNamespace(
        id=item_id or uuid.uuid4(),
        college_id=college_id,
        item_number=item_number,
        rang=rang,
        chapter_title="Insuffisance Cardiaque",
        ocr_confidence_score=0.9,
        low_confidence=False,
        start_page=start_page,
        end_page=end_page,
    )
```

- [ ] **Step 2: Écrire les tests qui échouent**

Ajouter à `tests/api/test_college_cards.py` (même fichier que les tests `/cards`, imports existants réutilisés) :

```python
class TestListCollegeItemsPages:
    async def test_items_exposent_leurs_pages(self, client: AsyncClient, mock_db):
        from app.main import app

        user = _make_user()
        college = _make_college(college_ref_id=3, user_id=user.id)
        item = _make_item(college.id, item_number=340, start_page=111, end_page=117)
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(
            side_effect=[_scalars([item]), MagicMock(all=MagicMock(return_value=[(item.id, "A", 4)]))]
        )
        try:
            resp = await client.get(f"/v1/colleges/{college.id}/items")
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 200
        entry = resp.json()["data"][0]
        assert entry["start_page"] == 111
        assert entry["end_page"] == 117

    async def test_item_sans_pages_renvoie_null(self, client: AsyncClient, mock_db):
        from app.main import app

        user = _make_user()
        college = _make_college(college_ref_id=3, user_id=user.id)
        item = _make_item(college.id)
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.get = AsyncMock(return_value=college)
        mock_db.execute = AsyncMock(side_effect=[_scalars([item]), MagicMock(all=MagicMock(return_value=[]))])
        try:
            resp = await client.get(f"/v1/colleges/{college.id}/items")
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        entry = resp.json()["data"][0]
        assert entry["start_page"] is None and entry["end_page"] is None
```

Dans `tests/api/test_colleges.py`, classe `TestListUserColleges`, ajouter :

```python
    async def test_expose_version_et_taille_du_pdf(self, client: AsyncClient, mock_db, monkeypatch):
        from pathlib import Path

        from app.api.v1.colleges import catalog as catalog_module
        from app.main import app
        from app.services.imports import CurrentPdf

        user = _make_user()
        with_pdf = _make_college(college_ref_id=15, user_id=user.id)
        without_pdf = _make_college(college_ref_id=16, user_id=user.id)
        job_id = uuid.uuid4()
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.execute = AsyncMock(
            side_effect=[
                MagicMock(scalars=MagicMock(return_value=MagicMock(all=MagicMock(return_value=[with_pdf, without_pdf])))),
                MagicMock(all=MagicMock(return_value=[])),
            ]
        )

        async def fake_current_pdfs(db, ids):
            return {with_pdf.id: CurrentPdf(job_id=job_id, path=Path("/x.pdf"), size=398_458_880)}

        monkeypatch.setattr(catalog_module.import_service, "current_pdfs", fake_current_pdfs)
        try:
            resp = await client.get("/v1/colleges")
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        by_ref = {e["college_ref_id"]: e for e in resp.json()["data"]}
        assert by_ref[15]["pdf_version"] == str(job_id)
        assert by_ref[15]["pdf_size"] == 398_458_880
        assert by_ref[16]["pdf_version"] is None and by_ref[16]["pdf_size"] is None
```

- [ ] **Step 3: Lancer, vérifier l'échec**

Run : `.venv/bin/python -m pytest -q tests/api/test_college_cards.py tests/api/test_colleges.py`
Expected : FAIL — `KeyError: 'start_page'`, et `AttributeError: … has no attribute 'import_service'`.

- [ ] **Step 4: Implémenter les schémas**

`app/schemas/college.py` :

```python
class UserCollegeData(BaseModel):
    college_ref_id: int
    college_id: str
    status: str
    card_count_a: int = 0
    card_count_b: int = 0
    card_count_c: int = 0
    # Partie B : PDF en service (id du dernier job publié) et sa taille ; null si aucun.
    pdf_version: str | None = None
    pdf_size: int | None = None
```

```python
class ItemSummaryData(BaseModel):
    id: str
    item_number: int
    rang: str
    chapter_title: str | None
    ocr_confidence_score: float
    low_confidence: bool
    card_count_a: int
    card_count_b: int
    card_count_c: int
    # Partie B : pages de l'item dans le PDF, base 0 (index de page de l'import).
    start_page: int | None = None
    end_page: int | None = None
```

- [ ] **Step 5: Implémenter les routes**

`app/api/v1/colleges/cards.py`, dans `list_college_items`, compléter `ItemSummaryData(...)` :

```python
            card_count_c=counts.get(item.id, {}).get("C", 0),
            start_page=item.start_page,
            end_page=item.end_page,
```

`app/api/v1/colleges/catalog.py` : importer `from app.services import imports as import_service`, puis dans `list_user_colleges`, après le calcul de `counts_by_college` :

```python
    pdfs = await import_service.current_pdfs(db, college_ids)
```

et dans `UserCollegeData(...)` :

```python
            card_count_c=counts_by_college.get(college.id, {}).get("C", 0),
            pdf_version=str(pdfs[college.id].job_id) if college.id in pdfs else None,
            pdf_size=pdfs[college.id].size if college.id in pdfs else None,
```

- [ ] **Step 6: Réparer les tests existants de la liste**

`current_pdfs` fait un troisième `db.execute`. Les tests de `TestListUserColleges` qui passent une liste `side_effect` de deux réponses échouent (`StopAsyncIteration`). Pour chacun (grep : `rg -n "side_effect=\[" tests/api/test_colleges.py`), ajouter en fin de liste :

```python
                MagicMock(all=MagicMock(return_value=[])),  # current_pdfs : aucun PDF
```

- [ ] **Step 7: Lancer, vérifier le succès**

Run : `.venv/bin/python -m pytest -q tests/api` → PASS.
Run : `.venv/bin/ruff check . && .venv/bin/ruff format --check . && .venv/bin/mypy app/core app/services` → propre.

- [ ] **Step 8: Commit**

```bash
git add collega_backend/app/schemas/college.py collega_backend/app/api/v1/colleges/cards.py collega_backend/app/api/v1/colleges/catalog.py collega_backend/tests/api/test_college_cards.py collega_backend/tests/api/test_colleges.py
git commit -m "feat(pdf): pages des items et version du PDF dans l'API

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Route `GET /v1/colleges/{college_id}/pdf`

**Files:**
- Create: `collega_backend/app/api/v1/colleges/pdf.py`
- Modify: `collega_backend/app/api/v1/colleges/__init__.py`
- Test: `collega_backend/tests/api/test_college_pdf.py`

**Interfaces:**
- Consumes: `current_pdfs` (Task 2), `not_found` (`app/core/errors.py`).
- Produces: `GET /v1/colleges/{college_id}/pdf` → 200 `application/pdf` (ou 206 avec `Range`), `Accept-Ranges: bytes` ; 404 `COLLEGE_NOT_FOUND` (inconnu **ou** autre propriétaire) ; 404 `PDF_NOT_FOUND` (aucun PDF en service) ; 401 sans jeton.

- [ ] **Step 1: Écrire les tests qui échouent**

`collega_backend/tests/api/test_college_pdf.py` :

```python
"""Partie B — GET /v1/colleges/{id}/pdf : le PDF de SON collège, reprise par Range."""

import uuid
from unittest.mock import AsyncMock

from httpx import AsyncClient

from app.deps import get_current_user
from app.services.imports import CurrentPdf
from tests.api.test_colleges import _make_college, _make_user

PDF = b"%PDF-1.7\n" + b"x" * 1000


def _install(monkeypatch, found):
    from app.api.v1.colleges import pdf as pdf_module

    async def fake_current_pdfs(db, ids):
        return found

    monkeypatch.setattr(pdf_module.import_service, "current_pdfs", fake_current_pdfs)


class TestCollegePdf:
    async def test_sans_jeton_401(self, client: AsyncClient):
        resp = await client.get(f"/v1/colleges/{uuid.uuid4()}/pdf")
        assert resp.status_code == 401

    async def test_proprietaire_recoit_le_pdf(self, client: AsyncClient, mock_db, monkeypatch, tmp_path):
        from app.main import app

        user = _make_user()
        college = _make_college(college_ref_id=26, user_id=user.id)
        path = tmp_path / "c.pdf"
        path.write_bytes(PDF)
        _install(monkeypatch, {college.id: CurrentPdf(job_id=uuid.uuid4(), path=path, size=len(PDF))})
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.get = AsyncMock(return_value=college)
        try:
            resp = await client.get(f"/v1/colleges/{college.id}/pdf")
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 200
        assert resp.headers["content-type"] == "application/pdf"
        assert resp.headers["accept-ranges"] == "bytes"
        assert resp.content == PDF

    async def test_reprise_par_range_206(self, client: AsyncClient, mock_db, monkeypatch, tmp_path):
        from app.main import app

        user = _make_user()
        college = _make_college(college_ref_id=26, user_id=user.id)
        path = tmp_path / "c.pdf"
        path.write_bytes(PDF)
        _install(monkeypatch, {college.id: CurrentPdf(job_id=uuid.uuid4(), path=path, size=len(PDF))})
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.get = AsyncMock(return_value=college)
        try:
            resp = await client.get(f"/v1/colleges/{college.id}/pdf", headers={"Range": "bytes=0-3"})
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 206
        assert resp.content == b"%PDF"

    async def test_college_d_un_autre_compte_404_sans_fuite(self, client: AsyncClient, mock_db, monkeypatch):
        from app.main import app

        user = _make_user()
        other = _make_college(college_ref_id=26)  # autre propriétaire
        _install(monkeypatch, {})
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.get = AsyncMock(return_value=other)
        try:
            resp = await client.get(f"/v1/colleges/{other.id}/pdf")
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "COLLEGE_NOT_FOUND"

    async def test_college_inconnu_404(self, client: AsyncClient, mock_db, monkeypatch):
        from app.main import app

        user = _make_user()
        _install(monkeypatch, {})
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.get = AsyncMock(return_value=None)
        try:
            resp = await client.get(f"/v1/colleges/{uuid.uuid4()}/pdf")
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        assert resp.json()["detail"]["code"] == "COLLEGE_NOT_FOUND"

    async def test_aucun_pdf_en_service_404_pdf_not_found(self, client: AsyncClient, mock_db, monkeypatch):
        from app.main import app

        user = _make_user()
        college = _make_college(college_ref_id=26, user_id=user.id)
        _install(monkeypatch, {})
        app.dependency_overrides[get_current_user] = lambda: user
        mock_db.get = AsyncMock(return_value=college)
        try:
            resp = await client.get(f"/v1/colleges/{college.id}/pdf")
        finally:
            app.dependency_overrides.pop(get_current_user, None)

        assert resp.status_code == 404
        assert resp.json()["detail"]["code"] == "PDF_NOT_FOUND"
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run : `.venv/bin/python -m pytest -q tests/api/test_college_pdf.py`
Expected : FAIL — `ModuleNotFoundError: No module named 'app.api.v1.colleges.pdf'`.

- [ ] **Step 3: Implémenter la route**

`app/api/v1/colleges/pdf.py` :

```python
"""Routes collèges utilisateur — le PDF importé, relu dans l'app (partie B).

Réservé au propriétaire ; `FileResponse` gère `Range` (206) pour reprendre un
téléchargement interrompu."""

from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.errors import not_found
from app.deps import get_current_user
from app.models.college import College
from app.models.user import User
from app.services import imports as import_service

router = APIRouter()


@router.get("/colleges/{college_id}/pdf", response_class=FileResponse)
async def download_college_pdf(
    college_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> FileResponse:
    """Le PDF en service du collège (dernier import publié)."""
    college = await db.get(College, college_id)
    if college is None or college.user_id != current_user.id:
        raise not_found("COLLEGE_NOT_FOUND", "College not found")
    pdf = (await import_service.current_pdfs(db, [college.id])).get(college.id)
    if pdf is None:
        raise not_found("PDF_NOT_FOUND", "PDF not found")
    return FileResponse(pdf.path, media_type="application/pdf")
```

`app/api/v1/colleges/__init__.py` : importer `pdf` et l'ajouter en dernier :

```python
from app.api.v1.colleges import cards, catalog, imports, pdf, status
...
router.include_router(cards.router)
router.include_router(pdf.router)
```

- [ ] **Step 4: Lancer, vérifier le succès**

Run : `.venv/bin/python -m pytest -q tests/api/test_college_pdf.py` → PASS (6 tests).
Run : suite backend complète `.venv/bin/python -m pytest -q`, puis `ruff check`, `ruff format --check`, `mypy app/core app/services`, `.venv/bin/alembic check` → tout propre.

- [ ] **Step 5: Commit**

```bash
git add collega_backend/app/api/v1/colleges/pdf.py collega_backend/app/api/v1/colleges/__init__.py collega_backend/tests/api/test_college_pdf.py
git commit -m "feat(pdf): GET /v1/colleges/{id}/pdf réservé au propriétaire, reprise par Range

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: App — pages des items et version du PDF, jusqu'à la base locale (migration 9 → 10)

**Files:**
- Modify: `lib/core/database/tables/items_table.dart`, `lib/core/database/tables/user_colleges_table.dart`, `lib/core/database/app_database.dart` (+ `app_database.g.dart` régénéré)
- Modify: `lib/features/colleges/domain/college_detail_models.dart`, `lib/features/colleges/domain/college_models.dart`, `lib/features/colleges/data/college_cards_sync.dart`, `lib/features/colleges/data/college_detail_repository.dart`, `lib/features/colleges/colleges_providers.dart`, `lib/features/colleges/colleges_detail_providers.dart`
- Test: `test/core/database/migration_v10_test.dart`, `test/features/colleges/college_models_pdf_test.dart`

**Interfaces:**
- Consumes: JSON de Task 3.
- Produces:
  - `ItemModel.startPage` / `endPage` (`int?`, base 0), lus de `start_page` / `end_page`, persistés dans drift `Items.startPage` / `endPage`, relus par `getItemsFromDrift` et `itemInfoProvider`.
  - `UserCollegeStatus.pdfVersion` (`String?`) / `pdfSize` (`int?`), lus de `pdf_version` / `pdf_size`, cachés dans drift `UserColleges.pdfVersion` / `pdfSize`.
  - `AppDatabase.schemaVersion == 10`.

- [ ] **Step 1: Test de migration qui échoue**

`test/core/database/migration_v10_test.dart` (même approche que `migration_v8_test.dart` : base v9 construite à la main) :

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/database/app_database.dart';

void main() {
  test('migration v9 → v10 : items gagnent leurs pages, user_colleges la version du PDF', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (raw) {
      raw.execute('CREATE TABLE items (id TEXT NOT NULL PRIMARY KEY, college_id TEXT NOT NULL, '
          'item_number INTEGER NOT NULL, rang TEXT NOT NULL, chapter_title TEXT NULL, '
          'ocr_confidence_score REAL NOT NULL DEFAULT 0.0, low_confidence INTEGER NOT NULL DEFAULT 0)');
      raw.execute("INSERT INTO items (id, college_id, item_number, rang) VALUES ('i1', 'c1', 340, 'A')");
      raw.execute('CREATE TABLE user_colleges (ref_id INTEGER NOT NULL PRIMARY KEY, college_id TEXT NOT NULL, '
          'status TEXT NOT NULL, card_count_a INTEGER NOT NULL, card_count_b INTEGER NOT NULL, '
          'card_count_c INTEGER NOT NULL)');
      raw.execute("INSERT INTO user_colleges VALUES (26, 'c1', 'generation_complete', 1, 0, 0)");
      raw.execute('PRAGMA user_version = 9');
    }));
    addTearDown(db.close);

    final item = await db.select(db.items).getSingle();
    expect(item.startPage, isNull);
    expect(item.endPage, isNull);
    final college = await db.select(db.userColleges).getSingle();
    expect(college.pdfVersion, isNull);
    expect(college.pdfSize, isNull);
  });
}
```

Note : à v9, la partie D a créé `quiet_days` ; ce test ne la crée pas car la migration 9 → 10 n'y touche pas (drift n'ouvre que les tables utilisées).

- [ ] **Step 2: Lancer, vérifier l'échec**

Run : `flutter test test/core/database/migration_v10_test.dart`
Expected : FAIL — `The getter 'startPage' isn't defined`.

- [ ] **Step 3: Tables et migration**

`lib/core/database/tables/items_table.dart`, avant `primaryKey` :

```dart
  /// Pages de l'item dans le PDF, base 0 (partie B) ; null pour un import ancien.
  IntColumn get startPage => integer().nullable()();
  IntColumn get endPage => integer().nullable()();
```

`lib/core/database/tables/user_colleges_table.dart`, avant `primaryKey` :

```dart
  /// PDF en service côté serveur (id du dernier job publié) et sa taille (partie B).
  TextColumn get pdfVersion => text().nullable()();
  IntColumn get pdfSize => integer().nullable()();
```

`lib/core/database/app_database.dart` : `int get schemaVersion => 10;` et, **après** le bloc `if (from < 9)` de la partie D :

```dart
          // Partie B : pages des items et version du PDF. `items` existe depuis la
          // v2 et `user_colleges` depuis la v7 : avant, createTable a déjà les colonnes.
          if (from >= 2 && from < 10) {
            await m.addColumn(items, items.startPage);
            await m.addColumn(items, items.endPage);
          }
          if (from >= 7 && from < 10) {
            await m.addColumn(userColleges, userColleges.pdfVersion);
            await m.addColumn(userColleges, userColleges.pdfSize);
          }
```

Run : `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 4: Lancer, vérifier le succès**

Run : `flutter test test/core/database` → PASS (v8 et v10).

- [ ] **Step 5: Test des modèles qui échoue**

`test/features/colleges/college_models_pdf_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';

void main() {
  test('ItemModel lit start_page / end_page (base 0), null si absents', () {
    final base = {'id': 'i1', 'item_number': 340, 'rang': 'A', 'low_confidence': false};
    final withPages = ItemModel.fromJson({...base, 'start_page': 111, 'end_page': 117});
    expect(withPages.startPage, 111);
    expect(withPages.endPage, 117);
    final without = ItemModel.fromJson(base);
    expect(without.startPage, isNull);
    expect(without.endPage, isNull);
  });

  test('UserCollegeStatus lit pdf_version / pdf_size', () {
    final s = UserCollegeStatus.fromJson({
      'college_ref_id': 26, 'college_id': 'c1', 'status': 'generation_complete',
      'pdf_version': 'job-1', 'pdf_size': 398458880,
    });
    expect(s.pdfVersion, 'job-1');
    expect(s.pdfSize, 398458880);
    final none = UserCollegeStatus.fromJson({'college_ref_id': 26, 'college_id': 'c1', 'status': 'pending'});
    expect(none.pdfVersion, isNull);
    expect(none.pdfSize, isNull);
  });
}
```

Run : `flutter test test/features/colleges/college_models_pdf_test.dart` → FAIL (`startPage` non défini).

- [ ] **Step 6: Modèles**

`lib/features/colleges/domain/college_detail_models.dart`, `ItemModel` : ajouter au constructeur `this.startPage, this.endPage,`, les champs

```dart
  /// Pages de l'item dans le PDF, base 0 ; null pour un import ancien (partie B).
  final int? startPage;
  final int? endPage;
```

et dans `fromJson` :

```dart
        startPage: json['start_page'] as int?,
        endPage: json['end_page'] as int?,
```

`lib/features/colleges/domain/college_models.dart`, `UserCollegeStatus` : ajouter au constructeur `this.pdfVersion, this.pdfSize,`, les champs

```dart
  /// PDF en service côté serveur (id du dernier import publié) et sa taille (partie B).
  final String? pdfVersion;
  final int? pdfSize;
```

et dans `fromJson` :

```dart
        pdfVersion: json['pdf_version'] as String?,
        pdfSize: json['pdf_size'] as int?,
```

- [ ] **Step 7: Persistance et relecture**

`lib/features/colleges/data/college_cards_sync.dart`, `syncItemsToDrift`, dans `ItemsCompanion.insert(...)` :

```dart
            startPage: Value(item.startPage),
            endPage: Value(item.endPage),
```

`lib/features/colleges/data/college_detail_repository.dart`, `getItemsFromDrift`, dans `ItemModel(...)` :

```dart
            startPage: r.startPage,
            endPage: r.endPage,
```

`lib/features/colleges/colleges_detail_providers.dart`, `itemInfoProvider`, dans `ItemModel(...)` :

```dart
    startPage: row.startPage,
    endPage: row.endPage,
```

`lib/features/colleges/colleges_providers.dart`, `_loadUserColleges` : dans `UserCollegesCompanion.insert(...)`

```dart
                  pdfVersion: Value(s.pdfVersion),
                  pdfSize: Value(s.pdfSize),
```

et dans la relecture hors ligne `UserCollegeStatus(...)`

```dart
            pdfVersion: r.pdfVersion,
            pdfSize: r.pdfSize,
```

- [ ] **Step 8: Test d'aller-retour drift**

Ajouter à `test/features/colleges/college_models_pdf_test.dart` :

```dart
  test('les pages survivent à la synchro drift et à la relecture', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await syncItemsToDrift(db, 'c1', [
      const ItemModel(
        id: 'i1', collegeId: 'c1', itemNumber: 340, rang: 'A', ocrConfidenceScore: 0.9, lowConfidence: false,
        cardCountA: 1, cardCountB: 0, cardCountC: 0, startPage: 111, endPage: 117,
      ),
    ]);
    final row = await db.select(db.items).getSingle();
    expect((row.startPage, row.endPage), (111, 117));
  });
```

(imports : `package:drift/native.dart`, `package:collega_app/core/database/app_database.dart`, `package:collega_app/features/colleges/data/college_cards_sync.dart`.)

- [ ] **Step 9: Lancer, vérifier le succès**

Run : `flutter test test/core`, puis `flutter test test/features/colleges` → PASS.

- [ ] **Step 10: Commit**

```bash
git add collega_app/lib/core/database collega_app/lib/features/colleges collega_app/test/core/database/migration_v10_test.dart collega_app/test/features/colleges/college_models_pdf_test.dart
git commit -m "feat(pdf): pages des items et version du PDF en local (drift v10)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: `LocalPdfStore` — la copie locale et son statut, hors sauvegarde iCloud

**Files:**
- Create: `lib/features/pdf/data/local_pdf_store.dart`, `lib/features/pdf/data/backup_excluder.dart`
- Modify: `ios/Runner/AppDelegate.swift`
- Test: `test/features/pdf/local_pdf_store_test.dart`

**Interfaces:**
- Produces:
  - `enum LocalPdfStatus { absent, upToDate, outdated }`
  - `abstract interface class BackupExcluder { Future<void> exclude(String path); }` ; `class ChannelBackupExcluder implements BackupExcluder` (canal `collega/backup`, méthode `excludeFromBackup`, argument `{'path': path}`) ; `class NoopBackupExcluder` pour les tests.
  - `class LocalPdfStore` (constructeur `LocalPdfStore(Directory root, {BackupExcluder excluder = const NoopBackupExcluder()})`) :
    - `File fileFor(String collegeId, String version)` → `<root>/<collegeId>_<version>.pdf`
    - `Future<File?> readable(String collegeId, String? serverVersion)` — la copie à ouvrir, ou null.
    - `Future<LocalPdfStatus> status(String collegeId, String? serverVersion)`
    - `Future<void> keepCopy({required String collegeId, required String version, required File source})`
    - `Future<void> adopt({required String collegeId, required String version, required File downloaded})` — fichier téléchargé complet déplacé en place.
    - `Future<void> deleteExcept(Set<String> collegeIds)`, `Future<void> clear()`
    - `Future<int?> lastPage(String collegeId)`, `Future<void> saveLastPage(String collegeId, int page)` (base 1).

Règles de statut (voir Review Focus 2) :
- `serverVersion` non nul et fichier `<college>_<serverVersion>.pdf` présent → `upToDate` ; les fichiers du collège **plus anciens** (mtime) que lui sont supprimés (versions dépassées), les plus récents gardés (réimport pas encore publié).
- `serverVersion` non nul, fichier absent, mais un autre fichier du collège présent → `outdated`.
- `serverVersion` nul (pas de PDF côté serveur ou liste ancienne) et un fichier présent → `upToDate` sur le plus récent.
- sinon `absent`.

- [ ] **Step 1: Écrire les tests qui échouent**

`test/features/pdf/local_pdf_store_test.dart` :

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/pdf/data/backup_excluder.dart';
import 'package:collega_app/features/pdf/data/local_pdf_store.dart';

class _RecordingExcluder implements BackupExcluder {
  final paths = <String>[];
  @override
  Future<void> exclude(String path) async => paths.add(path);
}

void main() {
  late Directory tmp;
  late _RecordingExcluder excluder;
  late LocalPdfStore store;

  Future<File> source(String name, [String content = '%PDF-1.7']) async =>
      File('${tmp.path}/$name')..writeAsStringSync(content);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pdfstore');
    excluder = _RecordingExcluder();
    store = LocalPdfStore(Directory('${tmp.path}/pdfs'), excluder: excluder);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('rien sur le téléphone : absent', () async {
    expect(await store.status('c1', 'j1'), LocalPdfStatus.absent);
    expect(await store.readable('c1', 'j1'), isNull);
  });

  test('copie gardée à l’import : à jour, exclue de la sauvegarde, source intacte', () async {
    final src = await source('picked.pdf');
    await store.keepCopy(collegeId: 'c1', version: 'j1', source: src);
    expect(await store.status('c1', 'j1'), LocalPdfStatus.upToDate);
    expect((await store.readable('c1', 'j1'))!.path, store.fileFor('c1', 'j1').path);
    expect(excluder.paths, [store.fileFor('c1', 'j1').path]);
    expect(src.existsSync(), isTrue);
  });

  test('le serveur a une autre version : périmé, l’ancienne copie reste lisible', () async {
    await store.keepCopy(collegeId: 'c1', version: 'j1', source: await source('a.pdf'));
    expect(await store.status('c1', 'j2'), LocalPdfStatus.outdated);
  });

  test('réimport non publié : la nouvelle copie est gardée, l’ancienne reste en service', () async {
    await store.keepCopy(collegeId: 'c1', version: 'j1', source: await source('a.pdf'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await store.keepCopy(collegeId: 'c1', version: 'j2', source: await source('b.pdf'));
    // Le serveur publie encore j1.
    expect(await store.status('c1', 'j1'), LocalPdfStatus.upToDate);
    expect(store.fileFor('c1', 'j2').existsSync(), isTrue);
    // Publication de j2 : j1 (plus ancienne) part.
    expect(await store.status('c1', 'j2'), LocalPdfStatus.upToDate);
    expect(store.fileFor('c1', 'j1').existsSync(), isFalse);
  });

  test('pas de version serveur (hors ligne) : la copie la plus récente est lue', () async {
    await store.keepCopy(collegeId: 'c1', version: 'j1', source: await source('a.pdf'));
    expect(await store.status('c1', null), LocalPdfStatus.upToDate);
  });

  test('adopt : le téléchargement complet devient la copie', () async {
    final part = await source('c1_j3.pdf.part');
    await store.adopt(collegeId: 'c1', version: 'j3', downloaded: part);
    expect(await store.status('c1', 'j3'), LocalPdfStatus.upToDate);
    expect(part.existsSync(), isFalse);
  });

  test('deleteExcept et clear, dernière page lue', () async {
    await store.keepCopy(collegeId: 'c1', version: 'j1', source: await source('a.pdf'));
    await store.keepCopy(collegeId: 'c2', version: 'j9', source: await source('b.pdf'));
    await store.saveLastPage('c2', 42);
    expect(await store.lastPage('c2'), 42);
    await store.deleteExcept({'c1'});
    expect(await store.status('c2', 'j9'), LocalPdfStatus.absent);
    expect(await store.lastPage('c2'), isNull);
    await store.clear();
    expect(await store.status('c1', 'j1'), LocalPdfStatus.absent);
  });
}
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run : `flutter test test/features/pdf/local_pdf_store_test.dart`
Expected : FAIL — `Target of URI doesn't exist: 'package:collega_app/features/pdf/data/local_pdf_store.dart'`.

- [ ] **Step 3: Implémenter l'exclusion de sauvegarde**

`lib/features/pdf/data/backup_excluder.dart` :

```dart
import 'package:flutter/services.dart';

/// Retire un fichier de la sauvegarde iCloud (partie B) : un PDF de 400 Mo se
/// retélécharge, il ne doit pas remplir la sauvegarde de l'iPhone.
abstract interface class BackupExcluder {
  Future<void> exclude(String path);
}

class ChannelBackupExcluder implements BackupExcluder {
  const ChannelBackupExcluder();

  static const _channel = MethodChannel('collega/backup');

  @override
  Future<void> exclude(String path) => _channel.invokeMethod<void>('excludeFromBackup', {'path': path});
}

class NoopBackupExcluder implements BackupExcluder {
  const NoopBackupExcluder();

  @override
  Future<void> exclude(String path) async {}
}
```

`ios/Runner/AppDelegate.swift` :

```swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      // Partie B : les PDF gardés sur le téléphone ne partent pas dans la sauvegarde iCloud.
      FlutterMethodChannel(name: "collega/backup", binaryMessenger: controller.binaryMessenger)
        .setMethodCallHandler { call, result in
          guard call.method == "excludeFromBackup",
                let args = call.arguments as? [String: Any],
                let path = args["path"] as? String else {
            result(FlutterMethodNotImplemented)
            return
          }
          var url = URL(fileURLWithPath: path)
          var values = URLResourceValues()
          values.isExcludedFromBackup = true
          do {
            try url.setResourceValues(values)
            result(nil)
          } catch {
            result(FlutterError(code: "BACKUP_EXCLUDE_FAILED", message: error.localizedDescription, details: nil))
          }
        }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

- [ ] **Step 4: Implémenter le store**

`lib/features/pdf/data/local_pdf_store.dart` :

```dart
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/pdf/data/backup_excluder.dart';

enum LocalPdfStatus { absent, upToDate, outdated }

/// Copies locales des PDF importés (partie B) : `<collegeId>_<version>.pdf`, où
/// la version est l'id du job d'import (convention du serveur). Plusieurs
/// versions d'un même collège peuvent coexister le temps d'un réimport.
class LocalPdfStore {
  LocalPdfStore(this.root, {this.excluder = const NoopBackupExcluder()});

  final Directory root;
  final BackupExcluder excluder;

  File fileFor(String collegeId, String version) => File(p.join(root.path, '${collegeId}_$version.pdf'));

  File _lastPageFile(String collegeId) => File(p.join(root.path, '$collegeId.page'));

  Future<List<File>> _copies(String collegeId) async {
    if (!await root.exists()) return const [];
    final files = <File>[];
    await for (final e in root.list()) {
      final name = p.basename(e.path);
      if (e is File && name.startsWith('${collegeId}_') && name.endsWith('.pdf')) files.add(e);
    }
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync())); // plus récente d'abord
    return files;
  }

  /// La copie à ouvrir : celle de [serverVersion] si présente, sinon (version
  /// inconnue) la plus récente ; null si rien d'utilisable.
  Future<File?> readable(String collegeId, String? serverVersion) async {
    final copies = await _copies(collegeId);
    if (serverVersion == null) return copies.isEmpty ? null : copies.first;
    final wanted = fileFor(collegeId, serverVersion);
    if (!await wanted.exists()) return null;
    final wantedTime = wanted.lastModifiedSync();
    for (final f in copies) {
      // Versions dépassées : plus anciennes que la version en service. Les plus
      // récentes (réimport pas encore publié) restent.
      if (f.path != wanted.path && f.lastModifiedSync().isBefore(wantedTime)) await _delete(f);
    }
    return wanted;
  }

  Future<LocalPdfStatus> status(String collegeId, String? serverVersion) async {
    if (await readable(collegeId, serverVersion) != null) return LocalPdfStatus.upToDate;
    return (await _copies(collegeId)).isEmpty ? LocalPdfStatus.absent : LocalPdfStatus.outdated;
  }

  /// Copie du PDF choisi à l'import (la source reste intacte : l'envoi en a besoin).
  Future<void> keepCopy({required String collegeId, required String version, required File source}) async {
    await root.create(recursive: true);
    final dest = fileFor(collegeId, version);
    final tmp = File('${dest.path}.tmp');
    await source.copy(tmp.path);
    await tmp.rename(dest.path);
    await _exclude(dest);
  }

  /// Téléchargement complet déplacé en place.
  Future<void> adopt({required String collegeId, required String version, required File downloaded}) async {
    await root.create(recursive: true);
    final dest = fileFor(collegeId, version);
    await downloaded.rename(dest.path);
    await _exclude(dest);
  }

  Future<void> deleteExcept(Set<String> collegeIds) async {
    if (!await root.exists()) return;
    await for (final e in root.list()) {
      final name = p.basename(e.path);
      final collegeId = name.split(RegExp(r'[_.]')).first;
      if (e is File && !collegeIds.contains(collegeId)) await _delete(e);
    }
  }

  Future<void> clear() async {
    if (await root.exists()) await root.delete(recursive: true);
  }

  Future<int?> lastPage(String collegeId) async {
    final f = _lastPageFile(collegeId);
    if (!await f.exists()) return null;
    return int.tryParse((await f.readAsString()).trim());
  }

  Future<void> saveLastPage(String collegeId, int page) async {
    await root.create(recursive: true);
    await _lastPageFile(collegeId).writeAsString('$page');
  }

  Future<void> _exclude(File f) async {
    try {
      await excluder.exclude(f.path);
    } catch (e) {
      // Pas bloquant : au pire, le PDF part dans la sauvegarde iCloud.
      AppLogger.warning('exclusion de sauvegarde impossible : $e', tag: 'LocalPdfStore');
    }
  }

  Future<void> _delete(File f) async {
    try {
      await f.delete();
    } catch (e) {
      AppLogger.warning('suppression impossible : $e', tag: 'LocalPdfStore');
    }
  }
}
```

- [ ] **Step 5: Lancer, vérifier le succès**

Run : `flutter test test/features/pdf/local_pdf_store_test.dart` → PASS (7 tests).
Run : `flutter build ios --no-codesign --debug` → compile (AppDelegate).

- [ ] **Step 6: Commit**

```bash
git add collega_app/lib/features/pdf/data collega_app/ios/Runner/AppDelegate.swift collega_app/test/features/pdf/local_pdf_store_test.dart
git commit -m "feat(pdf): copie locale du PDF, statut de version, hors sauvegarde iCloud

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Copie à l'import, purge à la synchro et au changement de compte

**Files:**
- Create: `lib/features/pdf/pdf_providers.dart`
- Modify: `lib/features/colleges/colleges_import_providers.dart`, `lib/features/colleges/colleges_providers.dart`, `lib/features/auth/data/local_data_owner.dart`, `lib/features/auth/auth_providers.dart`
- Test: `test/features/pdf/pdf_import_copy_test.dart`, `test/features/auth/local_data_owner_test.dart`

**Interfaces:**
- Consumes: `LocalPdfStore` (Task 6), `ImportStartResponse.collegeId` / `.jobId`.
- Produces:
  - `final localPdfStoreProvider = FutureProvider<LocalPdfStore>(…)` (dans `pdf_providers.dart`) — racine `getApplicationSupportDirectory()/pdfs`, `ChannelBackupExcluder`.
  - `LocalDataOwner({required storage, required db, Future<void> Function()? clearPdfs})` : appelle `clearPdfs` quand un autre compte se connecte.

- [ ] **Step 1: Provider du store**

`lib/features/pdf/pdf_providers.dart` :

```dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:collega_app/features/pdf/data/backup_excluder.dart';
import 'package:collega_app/features/pdf/data/local_pdf_store.dart';

/// Copies locales des PDF (partie B), dans Application Support (jamais purgé par
/// iOS, contrairement aux caches), exclues de la sauvegarde iCloud.
final localPdfStoreProvider = FutureProvider<LocalPdfStore>((ref) async {
  final support = await getApplicationSupportDirectory();
  return LocalPdfStore(Directory(p.join(support.path, 'pdfs')), excluder: const ChannelBackupExcluder());
});
```

- [ ] **Step 2: Test de la copie à l'import (échoue)**

Lire `test/features/colleges/college_import_notifier_test.dart` pour réutiliser son harnais (overrides de `collegeImportRepositoryProvider`, `databaseProvider`, SSE). Créer `test/features/pdf/pdf_import_copy_test.dart` avec ce harnais et deux tests :

```dart
  test('import accepté : le PDF choisi est gardé sous <collegeId>_<jobId>.pdf', () async {
    final tmp = Directory.systemTemp.createTempSync('pdfimport');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final store = LocalPdfStore(Directory('${tmp.path}/pdfs'));
    final picked = File('${tmp.path}/picked.pdf')..writeAsStringSync('%PDF-1.7');
    final container = makeContainer(overrides: [
      localPdfStoreProvider.overrideWith((ref) async => store),
      // + overrides du harnais : dépôt d'import qui répond
      //   ImportStartResponse(collegeId: 'c26', jobId: 'j1', status: 'pending')
    ]);

    await container.read(collegeImportProvider.notifier).startImport(26, picked);

    expect(store.fileFor('c26', 'j1').existsSync(), isTrue);
    expect(picked.existsSync(), isTrue);
  });

  test('copie impossible : l’import continue quand même', () async {
    final container = makeContainer(overrides: [
      localPdfStoreProvider.overrideWith((ref) async => throw const FileSystemException('plein')),
    ]);
    await container.read(collegeImportProvider.notifier).startImport(26, pickedFile);
    expect(container.read(collegeImportProvider).valueOrNull, isA<ImportStreaming>());
  });
```

(`makeContainer`, `pickedFile` et le faux dépôt sont ceux du harnais existant ; les nommer comme dans ce fichier.)

Run : `flutter test test/features/pdf/pdf_import_copy_test.dart` → FAIL (aucune copie).

- [ ] **Step 3: Copier à l'import**

`lib/features/colleges/colleges_import_providers.dart` :

1. Importer `package:collega_app/features/pdf/pdf_providers.dart`.
2. `_afterUploadAccepted(int refId, ImportStartResponse response)` devient `_afterUploadAccepted(int refId, ImportStartResponse response, File source)`, et commence par :

```dart
    // Partie B : garder le PDF sur le téléphone (lecteur hors ligne). Jamais bloquant.
    try {
      final store = await ref.read(localPdfStoreProvider.future);
      await store.keepCopy(collegeId: response.collegeId, version: response.jobId, source: source);
    } catch (e) {
      AppLogger.warning('copie locale du PDF impossible : $e', tag: 'CollegeImportNotifier');
    }
```

3. `startImport` : `await _afterUploadAccepted(refId, response, file);`
4. `resumePendingUpload` : lire aussi le chemin avant l'envoi, et le passer :

```dart
    final int refId;
    final String sourcePath;
    ...
      final row = (await db.select(db.pendingUploads).get()).first;
      refId = row.refId;
      sourcePath = row.filePath;
    ...
      if (response != null) await _afterUploadAccepted(refId, response, File(sourcePath));
```

Run : `flutter test test/features/pdf/pdf_import_copy_test.dart test/features/colleges/college_import_notifier_test.dart` → PASS.

- [ ] **Step 4: Purge à la synchro**

`lib/features/colleges/colleges_providers.dart`, `_loadUserColleges`, juste après la transaction réussie (hors transaction, jamais sur l'échec réseau) :

```dart
      // Partie B : les PDF des collèges disparus quittent aussi le téléphone.
      try {
        final store = await ref.read(localPdfStoreProvider.future);
        await store.deleteExcept({for (final s in fresh) s.collegeId});
      } catch (e) {
        AppLogger.warning('purge des PDF locaux impossible : $e', tag: 'CollegesNotifier');
      }
```

(imports : `pdf_providers.dart`, `core/utils/logger.dart`.) Dans `test/features/colleges/colleges_providers_test.dart`, ajouter un test : store avec `c1` et `cGone`, liste serveur `[c1]` → `cGone` supprimé, `c1` gardé ; et un second : `DioException` → rien supprimé. Surcharger `localPdfStoreProvider` avec un store dans un dossier temporaire.

- [ ] **Step 5: Purge au changement de compte (test qui échoue)**

Dans `test/features/auth/local_data_owner_test.dart` :

```dart
  test('autre compte : les PDF du précédent quittent le téléphone', () async {
    var cleared = 0;
    final owner = LocalDataOwner(storage: storage, db: db, clearPdfs: () async => cleared++);
    await owner.claim('u1');
    await owner.claim('u1');
    expect(cleared, 0);
    await owner.claim('u2');
    expect(cleared, 1);
  });
```

Run : `flutter test test/features/auth/local_data_owner_test.dart` → FAIL (paramètre inconnu).

- [ ] **Step 6: Implémenter**

`lib/features/auth/data/local_data_owner.dart` :

```dart
  const LocalDataOwner({required this.storage, required this.db, this.clearPdfs});

  final FlutterSecureStorage storage;
  final AppDatabase db;

  /// Supprime les PDF gardés sur le téléphone (partie B).
  final Future<void> Function()? clearPdfs;
```

et dans `claim`, dans le bloc « autre compte », après la suppression des recherches récentes :

```dart
      await clearPdfs?.call();
```

`lib/features/auth/auth_providers.dart` (ligne ~104), passer :

```dart
      await LocalDataOwner(
        storage: ref.read(secureStorageProvider),
        db: ref.read(databaseProvider),
        clearPdfs: () async => (await ref.read(localPdfStoreProvider.future)).clear(),
      )
```

- [ ] **Step 7: Lancer, vérifier le succès**

Run : `flutter test test/features/auth`, `flutter test test/features/colleges`, `flutter test test/features/pdf` → PASS.

- [ ] **Step 8: Commit**

```bash
git add collega_app/lib/features/pdf/pdf_providers.dart collega_app/lib/features/colleges collega_app/lib/features/auth collega_app/test/features/pdf collega_app/test/features/auth collega_app/test/features/colleges
git commit -m "feat(pdf): PDF gardé à l'import, purgé avec le collège ou au changement de compte

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Téléchargement du PDF (`background_downloader`)

**Files:**
- Create: `lib/features/pdf/data/pdf_downloader.dart`
- Modify: `lib/features/pdf/pdf_providers.dart`
- Test: `test/features/pdf/pdf_download_notifier_test.dart`

**Interfaces:**
- Consumes: `LocalPdfStore.adopt` (Task 6), `ApiClient.ensureFreshAccessToken()`, `secureStorageProvider` (clé `access_token`), `cloudflareAccessHeaders`, `backendBaseUrl`, `cfAccessClientId`, `cfAccessClientSecret`.
- Produces:
  - `abstract interface class PdfDownloader { Future<File> download({required String collegeId, required String version, required Directory into, required void Function(double) onProgress}); }` — lève `PdfDownloadFailed` en cas d'échec ; retourne un fichier `.part` complet.
  - `class PdfDownloadFailed implements Exception`.
  - `sealed class PdfDownloadState` : `PdfDownloadIdle`, `PdfDownloading(double progress)`, `PdfDownloadFailedState`, `PdfDownloadDone`.
  - `final pdfDownloaderProvider = Provider<PdfDownloader>(…)`, `final pdfDownloadProvider = NotifierProvider.family<PdfDownloadNotifier, PdfDownloadState, String>(…)` (argument : `collegeId`) avec `Future<void> start(String version)`.

- [ ] **Step 1: Écrire les tests qui échouent**

`test/features/pdf/pdf_download_notifier_test.dart` :

```dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/pdf/data/local_pdf_store.dart';
import 'package:collega_app/features/pdf/data/pdf_downloader.dart';
import 'package:collega_app/features/pdf/pdf_providers.dart';

class _FakeDownloader implements PdfDownloader {
  _FakeDownloader({this.fail = false});
  final bool fail;
  @override
  Future<File> download({
    required String collegeId,
    required String version,
    required Directory into,
    required void Function(double) onProgress,
  }) async {
    onProgress(0.5);
    if (fail) throw const PdfDownloadFailed('réseau');
    await into.create(recursive: true);
    onProgress(1);
    return File('${into.path}/${collegeId}_$version.pdf.part')..writeAsStringSync('%PDF-1.7');
  }
}

void main() {
  late Directory tmp;
  late LocalPdfStore store;

  ProviderContainer make(PdfDownloader downloader) {
    final c = ProviderContainer(overrides: [
      localPdfStoreProvider.overrideWith((ref) async => store),
      pdfDownloaderProvider.overrideWithValue(downloader),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pdfdl');
    store = LocalPdfStore(Directory('${tmp.path}/pdfs'));
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('téléchargement réussi : progression puis copie à jour', () async {
    final c = make(_FakeDownloader());
    final seen = <PdfDownloadState>[];
    c.listen(pdfDownloadProvider('c26'), (_, s) => seen.add(s), fireImmediately: true);

    await c.read(pdfDownloadProvider('c26').notifier).start('j1');

    expect(seen.whereType<PdfDownloading>().map((s) => s.progress), contains(0.5));
    expect(c.read(pdfDownloadProvider('c26')), isA<PdfDownloadDone>());
    expect(await store.status('c26', 'j1'), LocalPdfStatus.upToDate);
  });

  test('échec : état failed, aucune copie prise pour valide', () async {
    final c = make(_FakeDownloader(fail: true));
    await c.read(pdfDownloadProvider('c26').notifier).start('j1');
    expect(c.read(pdfDownloadProvider('c26')), isA<PdfDownloadFailedState>());
    expect(await store.status('c26', 'j1'), LocalPdfStatus.absent);
  });

  test('deux appuis : un seul téléchargement', () async {
    var calls = 0;
    final c = make(_CountingDownloader(() => calls++));
    final n = c.read(pdfDownloadProvider('c26').notifier);
    await Future.wait([n.start('j1'), n.start('j1')]);
    expect(calls, 1);
  });
}

class _CountingDownloader extends _FakeDownloader {
  _CountingDownloader(this.onCall);
  final void Function() onCall;
  @override
  Future<File> download({
    required String collegeId,
    required String version,
    required Directory into,
    required void Function(double) onProgress,
  }) {
    onCall();
    return super.download(collegeId: collegeId, version: version, into: into, onProgress: onProgress);
  }
}
```

Run : `flutter test test/features/pdf/pdf_download_notifier_test.dart` → FAIL (fichier absent).

- [ ] **Step 2: Implémenter le téléchargeur**

`lib/features/pdf/data/pdf_downloader.dart` :

```dart
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';

import 'package:collega_app/core/network/cloudflare_access.dart';
import 'package:collega_app/env.dart';

class PdfDownloadFailed implements Exception {
  const PdfDownloadFailed(this.reason);
  final Object reason;

  @override
  String toString() => 'PdfDownloadFailed($reason)';
}

/// Télécharge le PDF en service d'un collège dans [into] (fichier `.part`).
abstract interface class PdfDownloader {
  Future<File> download({
    required String collegeId,
    required String version,
    required Directory into,
    required void Function(double) onProgress,
  });
}

/// URLSession d'arrière-plan (background_downloader, comme l'envoi) : le
/// téléchargement continue si on quitte l'écran ou l'app.
class BackgroundPdfDownloader implements PdfDownloader {
  BackgroundPdfDownloader({required this.accessToken, FileDownloader? downloader})
      : _dl = downloader ?? FileDownloader();

  /// Jeton d'accès frais (lu juste avant la requête).
  final Future<String> Function() accessToken;
  final FileDownloader _dl;

  static const group = 'college-pdf';

  @override
  Future<File> download({
    required String collegeId,
    required String version,
    required Directory into,
    required void Function(double) onProgress,
  }) async {
    await into.create(recursive: true);
    final filename = '${collegeId}_$version.pdf.part';
    final task = DownloadTask(
      taskId: '$collegeId|$version',
      url: '$backendBaseUrl/v1/colleges/$collegeId/pdf',
      baseDirectory: BaseDirectory.root,
      directory: into.path,
      filename: filename,
      headers: {
        'Authorization': 'Bearer ${await accessToken()}',
        ...cloudflareAccessHeaders(clientId: cfAccessClientId, clientSecret: cfAccessClientSecret),
      },
      group: group,
      retries: 3,
      allowPause: true,
      updates: Updates.statusAndProgress,
    );
    final result = await _dl.download(task, onProgress: (p) {
      if (p >= 0) onProgress(p);
    });
    final file = File('${into.path}/$filename');
    if (result.status != TaskStatus.complete || !await file.exists()) {
      if (await file.exists()) await file.delete();
      throw PdfDownloadFailed(result.exception ?? result.status);
    }
    return file;
  }
}
```

- [ ] **Step 3: Notifier et providers**

Ajouter à `lib/features/pdf/pdf_providers.dart` (imports : `api_providers.dart` pour `apiClientProvider` et `secureStorageProvider`, `pdf_downloader.dart`, `logger.dart`) :

```dart
final pdfDownloaderProvider = Provider<PdfDownloader>((ref) => BackgroundPdfDownloader(
      accessToken: () async {
        await ref.read(apiClientProvider).ensureFreshAccessToken();
        return await ref.read(secureStorageProvider).read(key: 'access_token') ?? '';
      },
    ));

sealed class PdfDownloadState {
  const PdfDownloadState();
}

class PdfDownloadIdle extends PdfDownloadState {
  const PdfDownloadIdle();
}

class PdfDownloading extends PdfDownloadState {
  const PdfDownloading(this.progress);
  final double progress;
}

class PdfDownloadFailedState extends PdfDownloadState {
  const PdfDownloadFailedState();
}

class PdfDownloadDone extends PdfDownloadState {
  const PdfDownloadDone();
}

/// Téléchargement du PDF d'un collège ; survit à la fermeture de l'écran
/// (provider non autoDispose, comme l'import).
class PdfDownloadNotifier extends FamilyNotifier<PdfDownloadState, String> {
  @override
  PdfDownloadState build(String collegeId) => const PdfDownloadIdle();

  Future<void> start(String version) async {
    if (state is PdfDownloading) return;
    state = const PdfDownloading(0);
    try {
      final store = await ref.read(localPdfStoreProvider.future);
      final part = await ref.read(pdfDownloaderProvider).download(
            collegeId: arg,
            version: version,
            into: store.root,
            onProgress: (p) => state = PdfDownloading(p),
          );
      await store.adopt(collegeId: arg, version: version, downloaded: part);
      state = const PdfDownloadDone();
    } catch (e) {
      AppLogger.warning('téléchargement du PDF échoué : $e', tag: 'PdfDownloadNotifier');
      state = const PdfDownloadFailedState();
    }
  }
}

final pdfDownloadProvider =
    NotifierProvider.family<PdfDownloadNotifier, PdfDownloadState, String>(PdfDownloadNotifier.new);
```

Note : le `.part` vit dans `store.root` mais ne finit pas par `.pdf` : `_copies` ne le prend jamais pour une copie (Review Focus 1).

- [ ] **Step 4: Lancer, vérifier le succès**

Run : `flutter test test/features/pdf` → PASS.

- [ ] **Step 5: Commit**

```bash
git add collega_app/lib/features/pdf collega_app/test/features/pdf/pdf_download_notifier_test.dart
git commit -m "feat(pdf): téléchargement du PDF en arrière-plan, sans copie partielle

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: Lecteur PDF et écran « PDF absent »

**Files:**
- Create: `lib/features/pdf/domain/pdf_labels.dart`, `lib/features/pdf/presentation/pdf_document_view.dart`, `lib/features/pdf/presentation/pdf_missing_view.dart`, `lib/features/pdf/presentation/pdf_reader_screen.dart`
- Modify: `lib/features/pdf/pdf_providers.dart`, `lib/core/router/app_router.dart`
- Test: `test/features/pdf/pdf_labels_test.dart`, `test/features/pdf/pdf_reader_screen_test.dart`

**Interfaces:**
- Consumes: `collegesProvider` (`UserCollegeStatus.collegeId`, `.pdfVersion`, `.pdfSize`), `itemInfoProvider(itemId)` (`startPage`, `endPage`, `itemNumber`), `localPdfStoreProvider`, `pdfDownloadProvider`.
- Produces:
  - `String pageRangeLabel(int start0, int? end0)` → `« p. 112–118 »` ou `« p. 112 »` (base 0 en entrée, base 1 en sortie, tiret demi-cadratin).
  - `String megabytesLabel(int bytes)` → `« 380 Mo »` (Mo = 1 048 576 octets, arrondi à l'entier, minimum 1).
  - `typedef PdfDocumentBuilder = Widget Function({required String path, required int initialPage, required void Function(int page, int pageCount) onPage, required void Function(Future<void> Function(int page) goTo) onReady});` et `final pdfDocumentBuilderProvider = Provider<PdfDocumentBuilder>((_) => pdfrxDocumentBuilder);`
  - `final collegePdfStatusProvider = FutureProvider.autoDispose.family<LocalPdfStatus, ({String collegeId, String? version})>(…)`.
  - Route plein écran `/colleges/:ref_id/pdf?page=<base 1>&item=<itemId>` → `PdfReaderScreen(refId, page, itemId)`.
  - Constante de navigation `String pdfReaderPath(int refId, {int? page, String? itemId})`.

- [ ] **Step 1: Libellés (test qui échoue)**

`test/features/pdf/pdf_labels_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/pdf/domain/pdf_labels.dart';

void main() {
  test('pageRangeLabel : base 0 → base 1, une ou plusieurs pages', () {
    expect(pageRangeLabel(111, 117), 'p. 112–118');
    expect(pageRangeLabel(111, 111), 'p. 112');
    expect(pageRangeLabel(111, null), 'p. 112');
  });

  test('megabytesLabel : Mo arrondis, jamais 0', () {
    expect(megabytesLabel(398458880), '380 Mo');
    expect(megabytesLabel(1000), '1 Mo');
  });

  test('pdfReaderPath', () {
    expect(pdfReaderPath(26), '/colleges/26/pdf');
    expect(pdfReaderPath(26, page: 112, itemId: 'i340'), '/colleges/26/pdf?page=112&item=i340');
  });
}
```

`lib/features/pdf/domain/pdf_labels.dart` :

```dart
/// « p. 112–118 » : pages de l'item (base 0 en base) affichées en base 1.
String pageRangeLabel(int start0, int? end0) {
  final start = start0 + 1;
  final end = (end0 ?? start0) + 1;
  return end > start ? 'p. $start–$end' : 'p. $start';
}

/// « 380 Mo » (1 Mo = 1 048 576 octets), jamais « 0 Mo ».
String megabytesLabel(int bytes) {
  final mb = (bytes / (1024 * 1024)).round();
  return '${mb < 1 ? 1 : mb} Mo';
}

/// Route du lecteur ; [page] en base 1.
String pdfReaderPath(int refId, {int? page, String? itemId}) {
  final query = [if (page != null) 'page=$page', if (itemId != null) 'item=$itemId'];
  return '/colleges/$refId/pdf${query.isEmpty ? '' : '?${query.join('&')}'}';
}
```

Run : `flutter test test/features/pdf/pdf_labels_test.dart` → PASS.

- [ ] **Step 2: Enveloppe `pdfrx`**

`lib/features/pdf/presentation/pdf_document_view.dart` :

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

/// Rendu du PDF ; remplacé en test (pdfium ne tourne pas sous `flutter test`).
typedef PdfDocumentBuilder = Widget Function({
  required String path,
  required int initialPage,
  required void Function(int page, int pageCount) onPage,
  required void Function(Future<void> Function(int page) goTo) onReady,
});

final pdfDocumentBuilderProvider = Provider<PdfDocumentBuilder>((_) => pdfrxDocumentBuilder);

Widget pdfrxDocumentBuilder({
  required String path,
  required int initialPage,
  required void Function(int page, int pageCount) onPage,
  required void Function(Future<void> Function(int page) goTo) onReady,
}) =>
    _PdfrxView(path: path, initialPage: initialPage, onPage: onPage, onReady: onReady);

class _PdfrxView extends StatefulWidget {
  const _PdfrxView({required this.path, required this.initialPage, required this.onPage, required this.onReady});

  final String path;
  final int initialPage;
  final void Function(int page, int pageCount) onPage;
  final void Function(Future<void> Function(int page) goTo) onReady;

  @override
  State<_PdfrxView> createState() => _PdfrxViewState();
}

class _PdfrxViewState extends State<_PdfrxView> {
  final _controller = PdfViewerController();

  @override
  Widget build(BuildContext context) => PdfViewer.file(
        widget.path,
        controller: _controller,
        initialPageNumber: widget.initialPage,
        params: PdfViewerParams(
          onViewerReady: (document, controller) {
            widget.onReady((page) => controller.goToPage(pageNumber: page));
            widget.onPage(controller.pageNumber ?? widget.initialPage, controller.pageCount);
          },
          onPageChanged: (page) {
            if (page != null) widget.onPage(page, _controller.pageCount);
          },
        ),
      );
}
```

- [ ] **Step 3: Provider de statut**

Ajouter à `lib/features/pdf/pdf_providers.dart` :

```dart
/// Statut de la copie locale face à la version serveur ; se relit après un
/// téléchargement (invalidé par l'écran).
final collegePdfStatusProvider =
    FutureProvider.autoDispose.family<LocalPdfStatus, ({String collegeId, String? version})>((ref, key) async {
  final store = await ref.watch(localPdfStoreProvider.future);
  return store.status(key.collegeId, key.version);
});
```

- [ ] **Step 4: Tests de l'écran (échouent)**

`test/features/pdf/pdf_reader_screen_test.dart`. Harnais : `ProviderScope` avec
- `collegesProvider.overrideWith(() => _Colleges(status))` (même classe `_Colleges` que `college_detail_screen_test.dart`, `UserCollegeStatus(refId: 26, collegeId: 'c26', status: 'generation_complete', cardCountA: 1, cardCountB: 0, cardCountC: 0, pdfVersion: 'j1', pdfSize: 398458880)`),
- `localPdfStoreProvider.overrideWith((ref) async => store)` (dossier temporaire),
- `itemInfoProvider.overrideWith((ref, id) async => ItemModel(id: 'i340', collegeId: 'c26', itemNumber: 340, rang: 'A', chapterTitle: 'Accident vasculaire cérébral', ocrConfidenceScore: 0.9, lowConfidence: false, cardCountA: 0, cardCountB: 0, cardCountC: 0, startPage: 111, endPage: 117))`,
- `pdfDocumentBuilderProvider.overrideWithValue(fakeBuilder)` où `fakeBuilder` rend `Text('PDF $path @ $initialPage')`, appelle `onPage(initialPage, 480)` dans un `addPostFrameCallback`, et `onReady((p) async => goTos.add(p))`,
- `pdfDownloaderProvider.overrideWithValue(_FakeDownloader())` (celui de Task 8, copié dans ce fichier),

et un `GoRouter` minimal avec `GoRoute(path: '/colleges/:ref_id/pdf', builder: …PdfReaderScreen(refId: …, page: int.tryParse(s.uri.queryParameters['page'] ?? ''), itemId: s.uri.queryParameters['item']))`.

Tests :

```dart
  testWidgets('copie à jour, depuis un item : s’ouvre p. 112, bandeau et « ↑ Début »', (tester) async {
    await store.keepCopy(collegeId: 'c26', version: 'j1', source: pdfSource);
    await tester.pumpWidget(app('/colleges/26/pdf?page=112&item=i340'));
    await tester.pumpAndSettle();
    expect(find.textContaining('@ 112'), findsOneWidget);
    expect(find.text('p. 112 / 480'), findsOneWidget);
    expect(find.text('Item 340 · p. 112–118'), findsOneWidget);
    await tester.tap(find.text('↑ Début'));
    expect(goTos, [112]);
  });

  testWidgets('depuis la vue collège : dernière page lue, sinon p. 1 ; pas de bandeau', (tester) async {
    await store.keepCopy(collegeId: 'c26', version: 'j1', source: pdfSource);
    await store.saveLastPage('c26', 57);
    await tester.pumpWidget(app('/colleges/26/pdf'));
    await tester.pumpAndSettle();
    expect(find.textContaining('@ 57'), findsOneWidget);
    expect(find.textContaining('↑ Début'), findsNothing);
  });

  testWidgets('PDF absent : taille, conseil Wi-Fi, téléchargement puis lecture', (tester) async {
    await tester.pumpWidget(app('/colleges/26/pdf?page=112&item=i340'));
    await tester.pumpAndSettle();
    expect(find.text('Ton PDF n’est pas sur ce téléphone'), findsOneWidget);
    expect(find.text('Télécharger (380 Mo)'), findsOneWidget);
    expect(find.textContaining('Wi-Fi'), findsOneWidget);
    await tester.tap(find.text('Télécharger (380 Mo)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('@ 112'), findsOneWidget);
  });

  testWidgets('copie périmée : « Une nouvelle version de ton PDF est disponible »', (tester) async {
    await store.keepCopy(collegeId: 'c26', version: 'j0', source: pdfSource);
    await tester.pumpWidget(app('/colleges/26/pdf'));
    await tester.pumpAndSettle();
    expect(find.text('Une nouvelle version de ton PDF est disponible'), findsOneWidget);
  });

  testWidgets('téléchargement échoué : message et « Réessayer »', (tester) async {
    // pdfDownloaderProvider surchargé avec _FakeDownloader(fail: true)
    await tester.pumpWidget(app('/colleges/26/pdf', failDownload: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Télécharger (380 Mo)'));
    await tester.pumpAndSettle();
    expect(find.text('Le téléchargement n’a pas abouti'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });
```

Run : `flutter test test/features/pdf/pdf_reader_screen_test.dart` → FAIL (écran absent).

- [ ] **Step 5: Vue « PDF absent »**

`lib/features/pdf/presentation/pdf_missing_view.dart` :

```dart
import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/pdf/domain/pdf_labels.dart';
import 'package:collega_app/features/pdf/pdf_providers.dart';

/// Copie absente ou périmée : proposer le téléchargement (maquette validée).
class PdfMissingView extends StatelessWidget {
  const PdfMissingView({
    super.key,
    required this.collegeName,
    required this.sizeBytes,
    required this.outdated,
    required this.download,
    required this.onDownload,
  });

  final String collegeName;
  final int? sizeBytes;
  final bool outdated;
  final PdfDownloadState download;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final size = sizeBytes == null ? null : megabytesLabel(sizeBytes!);
    final title = outdated ? 'Une nouvelle version de ton PDF est disponible' : 'Ton PDF n’est pas sur ce téléphone';
    final d = download;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CgSpace.s4),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: CgRowIcon(CgIcons.document)),
        const SizedBox(height: CgSpace.s4),
        Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: CgType.head.copyWith(color: c.ink))),
        const SizedBox(height: CgSpace.s2),
        Text(
          [collegeName, if (size != null) size].join(' · ') +
              '. Une fois téléchargé, il reste disponible hors connexion.',
          textAlign: TextAlign.center,
          style: CgType.bodyS.copyWith(color: c.ink2),
        ),
        const SizedBox(height: CgSpace.s4),
        switch (d) {
          PdfDownloading(:final progress) => Semantics(
              label: 'Téléchargement, ${(progress * 100).round()} %',
              child: _ProgressLine(value: progress),
            ),
          PdfDownloadFailedState() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Le téléchargement n’a pas abouti', textAlign: TextAlign.center, style: CgType.bodyS.copyWith(color: c.ink2)),
              const SizedBox(height: CgSpace.s2),
              CgButton(label: 'Réessayer', variant: CgButtonVariant.secondary, onPressed: onDownload),
            ]),
          _ => CgButton(label: size == null ? 'Télécharger' : 'Télécharger ($size)', onPressed: onDownload),
        },
        const SizedBox(height: CgSpace.s2),
        Text('Le Wi-Fi est conseillé. Tu peux quitter cet écran pendant le téléchargement.',
            textAlign: TextAlign.center, style: CgType.meta.copyWith(color: c.ink3)),
      ]),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return ClipRRect(
      borderRadius: CgRadius.pill,
      child: SizedBox(
        height: 6,
        child: Stack(children: [
          Positioned.fill(child: ColoredBox(color: c.line)),
          FractionallySizedBox(widthFactor: value.clamp(0, 1), child: ColoredBox(color: c.accent)),
        ]),
      ),
    );
  }
}
```

(Si `CgRadius.pill` n'est pas un `BorderRadius`, utiliser le rayon que `item_detail_screen.dart` utilise pour ses pastilles.)

- [ ] **Step 6: Écran du lecteur**

`lib/features/pdf/presentation/pdf_reader_screen.dart` :

```dart
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/colleges_detail_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/pdf/data/local_pdf_store.dart';
import 'package:collega_app/features/pdf/domain/pdf_labels.dart';
import 'package:collega_app/features/pdf/pdf_providers.dart';
import 'package:collega_app/features/pdf/presentation/pdf_document_view.dart';
import 'package:collega_app/features/pdf/presentation/pdf_missing_view.dart';

/// Lecteur plein écran (partie B, option A) : tout le PDF, ouvert à [page]
/// (base 1) ; depuis un item, bandeau « Item N · p. X–Y » et « ↑ Début ».
/// Sans [page] : dernière page lue du collège, sinon p. 1.
class PdfReaderScreen extends ConsumerStatefulWidget {
  const PdfReaderScreen({super.key, required this.refId, this.page, this.itemId});

  final int refId;
  final int? page;
  final String? itemId;

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  int? _page;
  int? _pageCount;
  Future<void> Function(int page)? _goTo;

  /// Page d'ouverture et copie à lire, calculées une fois par écran.
  Future<(int, File?)>? _open;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final name = collegeCatalogEntry(widget.refId)?.name ?? 'Collège';
    final status = ref.watch(collegesProvider).valueOrNull
        ?.where((e) => e.catalog.refId == widget.refId)
        .firstOrNull
        ?.userStatus;
    final item = widget.itemId == null ? null : ref.watch(itemInfoProvider(widget.itemId!)).valueOrNull;
    final backLabel = item == null ? name : 'Item ${item.itemNumber}';

    Widget body;
    if (status == null) {
      body = const Center(child: CgSkeletonList(rows: 3));
    } else {
      final key = (collegeId: status.collegeId, version: status.pdfVersion);
      final download = ref.watch(pdfDownloadProvider(status.collegeId));
      ref.listen(pdfDownloadProvider(status.collegeId), (_, next) {
        if (next is PdfDownloadDone) {
          _open = null;
          ref.invalidate(collegePdfStatusProvider(key));
        }
      });
      final local = ref.watch(collegePdfStatusProvider(key)).valueOrNull;
      body = switch (local) {
        null => const Center(child: CgSkeletonList(rows: 3)),
        LocalPdfStatus.upToDate => _document(status.collegeId, status.pdfVersion),
        _ => PdfMissingView(
            collegeName: name,
            sizeBytes: status.pdfSize,
            outdated: local == LocalPdfStatus.outdated,
            download: download,
            onDownload: () {
              final version = status.pdfVersion;
              if (version != null) ref.read(pdfDownloadProvider(status.collegeId).notifier).start(version);
            },
          ),
      };
    }

    return ColoredBox(
      color: c.ground,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _TopBar(
            backLabel: backLabel,
            pageLabel: _page == null || _pageCount == null ? null : 'p. $_page / $_pageCount',
            onBack: () => context.pop(),
          ),
          Expanded(child: body),
          if (item?.startPage != null && _goTo != null)
            _ItemBand(
              label: 'Item ${item!.itemNumber} · ${pageRangeLabel(item.startPage!, item.endPage)}',
              onTop: () => _goTo!(item.startPage! + 1),
            ),
        ]),
      ),
    );
  }

  Future<(int, File?)> _openFor(String collegeId, String? version) => _open ??= () async {
        final store = await ref.read(localPdfStoreProvider.future);
        final first = widget.page ?? await store.lastPage(collegeId) ?? 1;
        return (first, await store.readable(collegeId, version));
      }();

  Widget _document(String collegeId, String? version) => FutureBuilder<(int, File?)>(
        future: _openFor(collegeId, version),
        builder: (context, snap) {
          final (first, file) = snap.data ?? (1, null);
          if (file == null) return const Center(child: CgSkeletonList(rows: 3));
          return ref.read(pdfDocumentBuilderProvider)(
            path: file.path,
            initialPage: first,
            onPage: (page, count) {
              if (!mounted) return;
              setState(() {
                _page = page;
                _pageCount = count;
              });
              if (widget.itemId == null) {
                ref.read(localPdfStoreProvider.future).then((s) => s.saveLastPage(collegeId, page));
              }
            },
            onReady: (goTo) {
              if (mounted) setState(() => _goTo = goTo);
            },
          );
        },
      );
}
```

Barre du haut et bandeau (même fichier) :

```dart
class _TopBar extends StatelessWidget {
  const _TopBar({required this.backLabel, required this.pageLabel, required this.onBack});

  final String backLabel;
  final String? pageLabel;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CgSpace.s2),
      child: Row(children: [
        Semantics(
          button: true,
          label: 'Retour, $backLabel',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBack,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: CgSpace.tapTarget),
              child: Row(children: [
                CgIcon(CgIcons.chevronLeft, color: c.accent),
                Text(backLabel, style: CgType.body.copyWith(color: c.accent)),
              ]),
            ),
          ),
        ),
        const Spacer(),
        if (pageLabel != null) Text(pageLabel!, style: CgType.bodyS.copyWith(color: c.ink, fontWeight: FontWeight.w600)),
        const SizedBox(width: CgSpace.s2),
      ]),
    );
  }
}

class _ItemBand extends StatelessWidget {
  const _ItemBand({required this.label, required this.onTop});

  final String label;
  final VoidCallback onTop;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Container(
      margin: const EdgeInsets.all(CgSpace.s2),
      padding: const EdgeInsets.symmetric(horizontal: CgSpace.s3),
      decoration: BoxDecoration(color: c.accentSoft, borderRadius: CgRadius.sAll),
      child: Row(children: [
        Expanded(child: Text(label, style: CgType.bodyS.copyWith(color: c.accent, fontWeight: FontWeight.w600))),
        Semantics(
          button: true,
          label: 'Revenir au début de l’item',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTop,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: CgSpace.tapTarget, minWidth: CgSpace.tapTarget),
              child: Center(child: Text('↑ Début', style: CgType.bodyS.copyWith(color: c.accent, fontWeight: FontWeight.w600))),
            ),
          ),
        ),
      ]),
    );
  }
}
```

- [ ] **Step 7: Route**

`lib/core/router/app_router.dart`, à côté des routes `/colleges/:ref_id/import` (hors `ShellRoute` : plein écran, sans barre d'onglets) :

```dart
      // Lecteur PDF (partie B) : plein écran ; page en base 1.
      GoRoute(
        path: '/colleges/:ref_id/pdf',
        builder: (ctx, s) => PdfReaderScreen(
          refId: int.parse(s.pathParameters['ref_id']!),
          page: int.tryParse(s.uri.queryParameters['page'] ?? ''),
          itemId: s.uri.queryParameters['item'],
        ),
      ),
```

Ajouter un cas au test du routeur (`test/core/router/app_router_test.dart`) : `/colleges/26/pdf?page=112&item=i340` construit un `PdfReaderScreen` avec `page == 112` et `itemId == 'i340'` (suivre le style des cas existants de ce fichier).

- [ ] **Step 8: Lancer, vérifier le succès**

Run : `flutter test test/features/pdf`, puis `flutter test test/core` → PASS. `flutter analyze` → aucune erreur.

- [ ] **Step 9: Commit**

```bash
git add collega_app/lib/features/pdf collega_app/lib/core/router/app_router.dart collega_app/test/features/pdf collega_app/test/core/router
git commit -m "feat(pdf): lecteur plein écran (tout le PDF, bandeau d'item) et écran de téléchargement

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: Points d'accès — vue collège, item, feuille « Source à vérifier »

**Files:**
- Modify: `lib/features/colleges/presentation/college_detail_screen.dart`, `lib/features/colleges/presentation/item_detail_screen.dart`
- Test: `test/features/colleges/college_detail_screen_test.dart`, `test/features/colleges/item_detail_screen_test.dart`

**Interfaces:**
- Consumes: `pdfReaderPath` et `pageRangeLabel`, `megabytesLabel` (Task 9), `collegePdfStatusProvider` (Task 9), `UserCollegeStatus.pdfVersion` / `.pdfSize`, `ItemModel.startPage` / `.endPage`.
- Produces: ligne `key: Key('college-pdf-row')`, lien `key: Key('item-pdf-link')`, bouton « Vérifier dans le PDF » dans la feuille OCR.

- [ ] **Step 1: Tests de la vue collège (échouent)**

Dans `test/features/colleges/college_detail_screen_test.dart` : ajouter à `_app(...)` un paramètre `LocalPdfStatus pdf = LocalPdfStatus.upToDate` et l'override `collegePdfStatusProvider.overrideWith((ref, key) async => pdf)`, la route `GoRoute(path: '/colleges/:ref/pdf', builder: (_, s) { visit?.paths.add(s.uri.toString()); return const SizedBox(); })`, et donner à `_status(...)` `pdfVersion: 'j1', pdfSize: 398458880`. Tests :

```dart
    testWidgets('ligne « Mon PDF du collège » : sur ce téléphone → ouvre le lecteur', (tester) async {
      final visit = _Visit();
      await tester.pumpWidget(_app(visit: visit));
      await tester.pumpAndSettle();
      expect(find.text('Mon PDF du collège'), findsOneWidget);
      expect(find.textContaining('sur ce téléphone'), findsOneWidget);
      await tester.tap(find.byKey(const Key('college-pdf-row')));
      await tester.pumpAndSettle();
      expect(visit.paths.last, '/colleges/3/pdf');
    });

    testWidgets('PDF absent : « à télécharger · 380 Mo »', (tester) async {
      await tester.pumpWidget(_app(pdf: LocalPdfStatus.absent));
      await tester.pumpAndSettle();
      expect(find.textContaining('à télécharger · 380 Mo'), findsOneWidget);
    });

    testWidgets('aucun PDF côté serveur ni en local : pas de ligne', (tester) async {
      await tester.pumpWidget(_app(
        status: const UserCollegeStatus(refId: 3, collegeId: 'c3', status: 'generation_complete',
            cardCountA: 25, cardCountB: 5, cardCountC: 3),
        pdf: LocalPdfStatus.absent,
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('college-pdf-row')), findsNothing);
    });
```

Run : `flutter test test/features/colleges/college_detail_screen_test.dart` → FAIL.

- [ ] **Step 2: Ligne PDF de la vue collège**

`college_detail_screen.dart`, `_LoadedDetailState._loaded(...)`, dans la liste des enfants, juste après le premier `CgRankBar(... legend: true)` et son `SizedBox(height: CgSpace.s4)` :

```dart
        _PdfRow(status: widget.entry.userStatus!, onOpen: () => context.push(pdfReaderPath(_refId))),
```

et la classe (même fichier ; imports `pdf_providers.dart`, `local_pdf_store.dart`, `pdf_labels.dart`) :

```dart
/// « Mon PDF du collège » (partie B) : sur ce téléphone, ou à télécharger.
/// Rien si le PDF n'existe ni sur le serveur ni sur le téléphone.
class _PdfRow extends ConsumerWidget {
  const _PdfRow({required this.status, required this.onOpen});

  final UserCollegeStatus status;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = ref
        .watch(collegePdfStatusProvider((collegeId: status.collegeId, version: status.pdfVersion)))
        .valueOrNull;
    if (local == null) return const SizedBox.shrink();
    final String subtitle;
    if (local == LocalPdfStatus.upToDate) {
      subtitle = 'sur ce téléphone';
    } else if (status.pdfVersion != null) {
      subtitle = status.pdfSize == null ? 'à télécharger' : 'à télécharger · ${megabytesLabel(status.pdfSize!)}';
    } else {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: CgSpace.s4),
      child: CgListGroup(children: [
        CgListRow(
          key: const Key('college-pdf-row'),
          title: 'Mon PDF du collège',
          subtitle: subtitle,
          leading: const CgRowIcon(CgIcons.document),
          trailing: CgRowTrailing.chevron,
          onTap: onOpen,
        ),
      ]),
    );
  }
}
```

(Le nombre de pages de la maquette n'est pas connu sans ouvrir le PDF : le sous-titre ne l'affiche pas.)

Run : `flutter test test/features/colleges/college_detail_screen_test.dart` → PASS.

- [ ] **Step 3: Tests de l'item (échouent)**

Dans `test/features/colleges/item_detail_screen_test.dart`, faire renvoyer à `itemInfoProvider` un item avec `startPage: 111, endPage: 117` (paramètre du harnais, défaut null), ajouter la route `/colleges/:ref/pdf` qui enregistre `s.uri.toString()`. Tests :

```dart
    testWidgets('lien « Lire dans le PDF · p. 112–118 » → lecteur à la page de l’item', (tester) async {
      await tester.pumpWidget(app(startPage: 111, endPage: 117));
      await tester.pumpAndSettle();
      expect(find.text('Lire dans le PDF · p. 112–118'), findsOneWidget);
      await tester.tap(find.byKey(const Key('item-pdf-link')));
      await tester.pumpAndSettle();
      expect(visit.paths.last, '/colleges/3/pdf?page=112&item=i232');
    });

    testWidgets('item sans page connue : pas de lien, feuille OCR sans bouton PDF', (tester) async {
      await tester.pumpWidget(app(startPage: null));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('item-pdf-link')), findsNothing);
      // ouvrir une fiche à OCR faible, toucher le badge OCR
      expect(find.text('Vérifier dans le PDF'), findsNothing);
    });

    testWidgets('feuille « Source à vérifier » : « Vérifier dans le PDF » ouvre la page de l’item', (tester) async {
      await tester.pumpWidget(app(startPage: 111, endPage: 117, lowOcrCard: true));
      await tester.pumpAndSettle();
      // déplier la fiche, toucher le badge OCR (comme les tests OCR existants du fichier)
      await tester.tap(find.text('Vérifier dans le PDF'));
      await tester.pumpAndSettle();
      expect(visit.paths.last, '/colleges/3/pdf?page=112&item=i232');
    });
```

(Adapter les noms d'ids/réfs à ceux du harnais existant : ici `refId` 3 et item `i232` ; les étapes « déplier / badge OCR » reprennent le code des tests OCR déjà présents dans ce fichier.)

Run : `flutter test test/features/colleges/item_detail_screen_test.dart` → FAIL.

- [ ] **Step 4: Lien et bouton dans l'item**

`item_detail_screen.dart`, état de l'item : au début des enfants passés à `widget.page(...)` (avant `const SizedBox(height: CgSpace.s4)` et le `CgRankBar`) :

```dart
        if (item?.startPage != null)
          Align(
            alignment: Alignment.centerLeft,
            child: CgButton(
              key: const Key('item-pdf-link'),
              label: 'Lire dans le PDF · ${pageRangeLabel(item!.startPage!, item.endPage)}',
              variant: CgButtonVariant.quiet,
              size: CgButtonSize.compact,
              expand: false,
              onPressed: () => _openPdf(item),
            ),
          ),
```

méthode de l'état :

```dart
  void _openPdf(ItemModel item) =>
      context.push(pdfReaderPath(widget.refId, page: item.startPage! + 1, itemId: item.id));
```

(Si l'état n'a pas `refId`, le passer depuis `ItemDetailScreen` comme `collegeId` / `collegeName` le sont déjà.)

`_explainOcr()` : lire l'item et ajouter un bouton secondaire quand la page est connue :

```dart
  Future<void> _explainOcr() {
    final item = ref.read(itemInfoProvider(widget.itemId)).valueOrNull;
    return showCgSheet<void>(
      context,
      title: 'Source à vérifier',
      builder: (_) => const _NoteBody(
        message: 'Ce passage du PDF était difficile à lire : la fiche peut contenir une erreur. '
            'Vérifie-la avec ton cours, et signale-la si besoin.',
      ),
      primary: Builder(
        builder: (s) => CgButton(label: 'Compris', onPressed: () => Navigator.of(s, rootNavigator: true).pop()),
      ),
      secondary: item?.startPage == null
          ? null
          : Builder(
              builder: (s) => CgButton(
                label: 'Vérifier dans le PDF',
                variant: CgButtonVariant.quiet,
                onPressed: () {
                  Navigator.of(s, rootNavigator: true).pop();
                  _openPdf(item!);
                },
              ),
            ),
    );
  }
```

(Vérifier que `showCgSheet` accepte `secondary: null` ; sinon construire l'appel en deux branches.)

- [ ] **Step 5: Lancer, vérifier le succès**

Run : `flutter test test/features/colleges`, `flutter test test/features/pdf`, `flutter test test/features/search` (la recherche ouvre des items) → PASS. `flutter analyze` → aucune erreur.

- [ ] **Step 6: Commit**

```bash
git add collega_app/lib/features/colleges/presentation collega_app/test/features/colleges
git commit -m "feat(pdf): accès au PDF depuis le collège, l'item et la feuille « Source à vérifier »

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: Vérification finale, mémoire, déploiement

**Files:**
- Aucun code. Mémoire Kage (`.agent_memory/`).

- [ ] **Step 1: Backend complet**

Depuis `collega_backend/` : `docker compose -f docker-compose.test.yml up -d`, puis `.venv/bin/python -m pytest -q`, `.venv/bin/ruff check .`, `.venv/bin/ruff format --check .`, `.venv/bin/mypy app/core app/services`, `.venv/bin/alembic check`. Tout vert, 0 erreur mypy.

- [ ] **Step 2: App par dossier**

Depuis `collega_app/` : `flutter test test/core`, puis chaque dossier de `test/features/` un par un (`auth`, `colleges`, `demo`, `drill`, `legal`, `planning`, `profile`, `progress`, `search`, `shell`, `today`, `pdf`). `flutter analyze` sans erreur.

- [ ] **Step 3: Mémoire**

`kage_learn` : « Partie B PDF local : version = id du dernier job publié (`pdf_version`), copie `<collegeId>_<jobId>.pdf` dans Application Support/pdfs exclue d'iCloud (canal `collega/backup`), pages base 0 en base / base 1 à l'écran, pdfrx épinglé 1.0.103 tant que Flutter 3.27 ». Puis `kage_refresh` et `kage_pr_check`.

- [ ] **Step 4: Déploiement (humain)**

Serveur : `collega_backend/scripts/deploy.sh <sha>` une fois la CI verte (dump avant migration, image étiquetée par commit ; aucune migration Alembic ici). Ne jamais écraser le `.env` de prod.

- [ ] **Step 5: Validation sur iPhone (TestFlight)**

1. Importer un petit collège : la ligne « Mon PDF du collège » dit « sur ce téléphone » ; l'ouvrir en mode avion.
2. Depuis un item : « Lire dans le PDF » ouvre la bonne page ; « ↑ Début » y revient.
3. Collège importé avant cette version (ou app réinstallée) : « à télécharger · N Mo », télécharger en **Wi-Fi**, puis en **4G** par le chemin public (Cloudflare Access) avec un gros PDF ; quitter l'écran pendant le téléchargement.
4. Réglages iOS › iCloud › Sauvegarde : la taille de Collega n'inclut pas les PDF.
5. Se connecter avec un autre compte : plus aucun PDF lisible.

---

## Auto-revue (faite)

- **Couverture de la spec, partie B :** pages des items (T3, T5) ; route réservée, Range, `PDF_NOT_FOUND` (T4) ; logique dans les services (T2) ; version exposée (T3, écart 1) ; copie à l'import, remplacement au réimport, exclusion iCloud (T6, T7) ; suppression par synchro et changement de compte (T7) ; migration drift (T5, 9 → 10) ; écran de téléchargement, progression, arrière-plan, copie périmée (T8, T9) ; lecteur, « p. N / T », bandeau, « ↑ Début », dernière page lue (T9) ; trois points d'accès (T10) ; item sans page (T10) ; tests serveur et app (toutes) ; déploiement (T11). Avertissement données mobiles : écart 2.
- **Cohérence des noms :** `current_pdfs` / `CurrentPdf` (T2–T4) ; `pdfVersion` / `pdfSize`, `startPage` / `endPage` (T5–T10) ; `LocalPdfStore`, `LocalPdfStatus`, `localPdfStoreProvider`, `pdfDownloadProvider`, `pdfDownloaderProvider`, `collegePdfStatusProvider`, `pdfDocumentBuilderProvider`, `pdfReaderPath`, `pageRangeLabel`, `megabytesLabel` (T6–T10).
- **Hypothèses à vérifier en exécutant :** signature de `showCgSheet` (`secondary` nullable), type de `CgRadius.pill`, harnais exacts des tests d'import et d'item (T7, T10) — chaque tâche dit quoi faire si l'hypothèse tombe.

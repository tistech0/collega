# Story 1.2 : Pipeline OCR Backend

Status: done

## Story

En tant qu'**opérateur**,
je veux pouvoir soumettre un PDF de collège médical au pipeline OCR backend,
afin d'extraire automatiquement le texte par item avec un score de confiance, en préparation de la génération de fiches.

## Acceptance Criteria

1. **Job ARQ créé à la soumission**
   - Étant donné un PDF de collège médical soumis à l'endpoint admin, quand `POST /v1/admin/colleges/{college_id}/process` est appelé avec le PDF, alors un job ARQ est créé dans la queue Redis avec le statut `pending`
   - Et le job passe à `processing`, exécute l'OCR page par page, puis passe à `ocr_complete`
   - Et la table `items` est peuplée avec les items détectés, chacun ayant un `ocr_text`, un `ocr_confidence_score` (float 0.0–1.0) et le rang détecté (A/B/C)

2. **Gestion OCR basse qualité**
   - Étant donné un PDF de mauvaise qualité (scan dégradé), quand l'OCR est exécuté, alors les items avec un `ocr_confidence_score` < 0.7 sont marqués `low_confidence: true`
   - Et ces items sont quand même créés — le score dégradé n'empêche pas la suite du pipeline

3. **Reprise OCR après interruption**
   - Étant donné un job OCR interrompu (worker ARQ redémarré), quand le worker redémarre, alors le job reprend à partir de la dernière page enregistrée dans `ocr_page_progress` (pas de reprise depuis le début)

4. **Endpoint de statut**
   - Étant donné une liste de colleges dans la base, quand `GET /v1/admin/colleges/{college_id}/status` est appelé, alors la réponse inclut `{ "data": { "status": "ocr_complete"|"processing"|"pending", "ocr_page_progress": N, "total_pages": M } }`

5. **Conventions de nommage et qualité**
   - Étant donné les contraintes définies en architecture, quand le code est inspecté, alors toutes les tables sont en snake_case pluriel, toutes les routes en `/v1/` snake_case, aucun `print()` en production, toutes les dates en ISO 8601 UTC

## Tasks / Subtasks

- [x] Task 1 : Créer la migration 002 — tables `items` et `generation_jobs` (AC: #1, #2, #3)
  - [x] 1.1 Créer `alembic/versions/002_add_items_generation_jobs.py` avec les deux tables (voir schéma en Dev Notes)
  - [x] 1.2 Ajouter colonne `total_pages` sur la table `colleges` (nécessaire pour AC #4 — pas dans Story 1.1)
  - [x] 1.3 Corriger le trigger `updated_at` sur `colleges` via migration SQL (reporté depuis Story 1.1 — voir Dev Notes)
  - [x] 1.4 Vérifier que `alembic upgrade head` s'exécute sans erreur après la migration 001

- [x] Task 2 : Créer les modèles SQLAlchemy `Item` et `GenerationJob` (AC: #1, #2)
  - [x] 2.1 Créer `app/models/item.py` — colonnes conformes au schéma (voir Dev Notes)
  - [x] 2.2 Créer `app/models/generation_job.py` — colonnes conformes au schéma (voir Dev Notes)
  - [x] 2.3 Mettre à jour `app/models/__init__.py` — importer `Item` et `GenerationJob` dans `__all__` (OBLIGATOIRE pour autogenerate Alembic)
  - [x] 2.4 Mettre à jour `app/models/college.py` — ajouter colonne `total_pages: int` + relationships vers `items` et `generation_jobs`

- [x] Task 3 : Implémenter les services OCR (AC: #1, #2, #3)
  - [x] 3.1 Créer `app/services/ocr/ocr_processor.py` — classe `OcrProcessor` avec méthode `process_page(pdf_path, page_num) -> OcrPageResult` (voir Dev Notes pour la stratégie pdfplumber + pytesseract)
  - [x] 3.2 Créer `app/services/ocr/confidence_scorer.py` — classe `ConfidenceScorer` avec méthode `score(page_data) -> float` (voir Dev Notes pour l'algorithme)
  - [x] 3.3 Créer `app/services/ocr/item_detector.py` — classe `ItemDetector` avec méthode `detect_items(page_texts: list[str]) -> list[DetectedItem]` (regex pattern pour ECNi — voir Dev Notes)
  - [x] 3.4 Créer `app/services/ocr/__init__.py` — exposer les 3 classes

- [x] Task 4 : Implémenter le worker ARQ OCR (AC: #1, #2, #3)
  - [x] 4.1 Créer `app/workers/ocr_worker.py` — fonction `process_college_ocr(ctx, college_id, job_id, pdf_path)` avec logique complète (voir Dev Notes)
  - [x] 4.2 Corriger `app/workers/settings.py` — ajouter `max_retries: 3` (bug reporté depuis Story 1.1), enregistrer `process_college_ocr` dans `functions`
  - [x] 4.3 Implémenter la reprise OCR depuis `ocr_page_progress` (AC #3) — charger la valeur depuis `colleges` avant de démarrer la boucle de pages

- [x] Task 5 : Créer les schemas Pydantic pour l'admin OCR (AC: #1, #4)
  - [x] 5.1 Créer `app/schemas/admin.py` — `CollegeStatusResponse`, `ProcessCollegeRequest`, `CollegeStatusData`
  - [x] 5.2 Toutes les réponses utilisent le wrapper `{ "data": { ... } }` — AUCUNE exception

- [x] Task 6 : Implémenter les routes admin OCR (AC: #1, #4, #5)
  - [x] 6.1 Créer `app/api/v1/admin.py` — deux routes uniquement pour cette story :
    - `POST /v1/admin/colleges/{college_id}/process` (upload PDF, créer GenerationJob, enqueue ARQ)
    - `GET /v1/admin/colleges/{college_id}/status` (retourner statut + progression)
  - [x] 6.2 Protéger toutes les routes `/v1/admin/` par HTTP Basic Auth (dependency `get_admin_user` dans `deps.py`)
  - [x] 6.3 Ajouter `ADMIN_USERNAME` et `ADMIN_PASSWORD` dans `app/core/config.py` (déjà dans `.env.example` depuis Story 1.1)
  - [x] 6.4 Inclure le router admin dans `app/main.py` avec prefix `/v1/admin`
  - [x] 6.5 Stocker le PDF uploadé dans un répertoire temporaire sécurisé (ex : `/tmp/collega_pdfs/{college_id}/`) — jamais dans le code versionné

- [x] Task 7 : Créer les schemas Pydantic pour les items (AC: #1, #2)
  - [x] 7.1 Créer `app/schemas/item.py` — `ItemCreate`, `ItemRead` (rang en Literal["A", "B", "C"])

- [x] Task 8 : Tests backend (AC: #1–#5)
  - [x] 8.1 `tests/api/test_admin_ocr.py` — tester `POST /v1/admin/colleges/{college_id}/process` : job ARQ créé, statut `pending` → vérification via mock ARQ
  - [x] 8.2 `tests/api/test_admin_ocr.py` — tester `GET /v1/admin/colleges/{college_id}/status` : retour JSON conforme au format `{ "data": { ... } }`
  - [x] 8.3 `tests/api/test_admin_ocr.py` — tester Basic Auth : 401 sans credentials, 200 avec credentials valides
  - [x] 8.4 `tests/services/test_ocr_processor.py` — tester `OcrProcessor` sur un PDF de test (fixture PDF minimal incluse dans `tests/fixtures/`)
  - [x] 8.5 `tests/services/test_confidence_scorer.py` — tester la règle seuil 0.7 (`low_confidence: true` si score < 0.7)
  - [x] 8.6 `tests/services/test_item_detector.py` — tester `ItemDetector` avec un texte ECNi simulé (pattern Item N · Rang A/B/C)
  - [x] 8.7 `tests/workers/test_ocr_worker.py` — tester la reprise depuis `ocr_page_progress` (simuler un job interrompu à page 5/10)

### Senior Developer Review (AI) — 2026-04-27

**Outcome:** Changes Requested — 16 patches, 1 decision needed, 7 deferred, 7 dismissed

**Review Follow-ups (AI)**

**Decision needed (1)**

- [x] [Review][Decision] AC4 — `status` peut valoir `"failed"` (hors spec) et `job_id` surnuméraire dans `/status` — Décision : étendre le spec. `"failed"` est un état réel nécessaire à l'opérateur ; `job_id` est un superset bénin utile en pratique. Code correct, spec à mettre à jour.

**Patches — HIGH (8)**

- [x] [Review][Patch] OCR resume incomplet — `page_texts` ne contient pas les pages déjà traitées avant l'interruption [app/workers/ocr_worker.py:87–103]
- [x] [Review][Patch] Race condition — pas de contrainte DB sur `(college_id, status='processing')`, deux jobs concurrents passent le guard [app/api/v1/admin.py:57–66]
- [x] [Review][Patch] Worker retry duplique les `Item` rows — aucun delete avant re-insert au redémarrage [app/workers/ocr_worker.py:103–125]
- [x] [Review][Patch] Blocking sync I/O dans le worker async — `count_pages` et `process_page` bloquent l'event loop ARQ [app/workers/ocr_worker.py:73,92]
- [x] [Review][Patch] `ocr_page_progress` non remis à 0 lors d'un nouveau POST /process — nouveau job reprend depuis la progression du job précédent [app/api/v1/admin.py:88–96]
- [x] [Review][Patch] Enqueue Redis échoue silencieusement — HTTP 202 retourné même si le job n'est pas enqueue (viole AC1) [app/api/v1/admin.py:100–118]
- [x] [Review][Patch] PDF entier lu en mémoire via `pdf.read()` sans limite de taille — vecteur DoS [app/api/v1/admin.py:83]
- [x] [Review][Patch] Pas de `CheckConstraint` DB sur `generation_jobs.status` — valeurs arbitraires acceptées [alembic/versions/002_add_items_generation_jobs.py:85–90]

**Patches — MED/LOW (8)**

- [x] [Review][Patch] PDF vide (0 pages) → statut `ocr_complete` sans erreur ni avertissement [app/workers/ocr_worker.py:73–77]
- [x] [Review][Patch] `Content-Type: application/octet-stream` accepté sans vérification extension ni magic bytes `%PDF-` [app/api/v1/admin.py:69–74]
- [x] [Review][Patch] Pas de contrainte `UNIQUE(college_id, item_number)` sur la table `items` — doublons silencieux possibles [alembic/versions/002_add_items_generation_jobs.py:22–61]
- [x] [Review][Patch] Trigger `updated_at` absent sur `generation_jobs` — ORM `onupdate` ne fonctionne pas pour les UPDATE SQL directs [alembic/versions/002_add_items_generation_jobs.py:118–137]
- [x] [Review][Patch] Images PIL de `convert_from_path` jamais fermées explicitement — fuite mémoire/descripteurs de fichiers [app/services/ocr/ocr_processor.py:77–111]
- [x] [Review][Patch] Rang par défaut `"A"` appliqué silencieusement sans log quand l'extraction échoue [app/services/ocr/item_detector.py:74]
- [x] [Review][Patch] `pool.close()` non appelé si `enqueue_job` lève une exception — fuite de connexion Redis [app/api/v1/admin.py:104–114]
- [x] [Review][Patch] Classe `DataWrapper` morte dans les schemas — jamais utilisée [app/schemas/admin.py:21–24]

**Deferred (7)**

- [x] [Review][Defer] Mot de passe admin par défaut `"change-me"` sans validation au démarrage [app/core/config.py:14] — deferred, design Phase 0, à enforcer en Story 2.3
- [x] [Review][Defer] `_ITEM_PATTERN` matche les références inline (ex. "voir item 42") [app/services/ocr/item_detector.py:13] — deferred, limitation algorithmique, nécessite analyse de vrais PDFs ECNi
- [x] [Review][Defer] PDF ouvert N+1 fois dans `OcrProcessor` — optimisation perf [app/services/ocr/ocr_processor.py:55,131] — deferred, optimisation future
- [x] [Review][Defer] Cap score pdfplumber (max 0.95) vs pytesseract (jusqu'à 1.0) — incohérence scoring [app/services/ocr/ocr_processor.py:127,100] — deferred, raffinement scoring futur
- [x] [Review][Defer] `claude_api_key` défaut `""` — intentionnel Story 1.2 (clé utilisée en Story 1.3) [app/core/config.py:10] — deferred, intentionnel
- [x] [Review][Defer] Monkey-patch `conftest.py` sensible à l'ordre d'import [tests/conftest.py] — deferred, infrastructure test
- [x] [Review][Defer] Pas de scoping d'autorisation par opérateur — intentionnel Phase 0 [app/api/v1/admin.py] — deferred, design Phase 0

## Dev Notes

### Contexte — Ce que cette story construit

Story 1.2 est la **première couche fonctionnelle** du pipeline. Elle crée les fondations que Story 1.3 (génération Claude) utilisera directement. Aucun code Flutter n'est modifié — backend uniquement.

**Dépendance directe :** Story 1.3 suppose que les tables `items` et `generation_jobs` existent avec les colonnes exactes définies ici. Ne pas modifier le schéma sans le noter dans le changelog.

### Stack OCR — Décision Technique

L'architecture spécifie `app/services/ocr/ocr_processor.py` et `ocr/confidence_scorer.py` mais ne nomme pas la bibliothèque Python. Utiliser la stratégie suivante :

**Primaire (PDF natif texte) :** `pdfplumber` — extrait le texte directement sans perte. Donne accès aux caractères, mots et leur positionnement. Disponible via Poetry : `pdfplumber`.

**Fallback (page image / scan) :** `pytesseract` + `pdf2image` — quand pdfplumber ne retourne pas de texte sur une page (page image). `pytesseract.image_to_data()` retourne un DataFrame avec `conf` (confiance 0–100) par mot. Disponible via Poetry : `pytesseract`, `pdf2image`. Nécessite `tesseract-ocr` installé dans le conteneur Docker.

**Calcul du score de confiance (0.0–1.0) :**
```python
# Pour pdfplumber : ratio mots détectés / mots attendus (estimation)
# Pour pytesseract : moyenne des conf > 0 / 100.0
score = sum(c for c in word_confidences if c > 0) / (len(word_confidences) * 100.0)
# Seuil : score < 0.7 → low_confidence = True
```

**Dépendances Poetry à ajouter dans `pyproject.toml` :**
```toml
pdfplumber = "^0.11"
pytesseract = "^0.3"
pdf2image = "^1.17"
```

**Dockerfile — ajout requis :**
```dockerfile
RUN apt-get update && apt-get install -y tesseract-ocr tesseract-ocr-fra poppler-utils
```

### Détection Items ECNi — Pattern Regex

Les PDFs médicaux ECNi (collèges CNCEM/COFER etc.) suivent un format structuré. Pattern de détection :

```python
import re

# Pattern item (ex: "Item 330", "ITEM 124 -", "Item n°45")
ITEM_PATTERN = re.compile(r"item\s*n?°?\s*(\d{1,3})", re.IGNORECASE)

# Pattern rang (ex: "Rang A", "Rang B :", "rang C")
RANG_PATTERN = re.compile(r"rang\s+([ABC])", re.IGNORECASE)

# Pattern chapitre (ex: "Chapitre 5", "CHAPITRE I")
CHAPTER_PATTERN = re.compile(r"chapitre\s+(\w+)", re.IGNORECASE)
```

Structure `DetectedItem` :
```python
@dataclass
class DetectedItem:
    item_number: int          # 1–329 (CNCI 2024)
    rang: Literal["A", "B", "C"]
    chapter_title: str
    ocr_text: str             # texte brut complet de l'item
    start_page: int
    end_page: int
    ocr_confidence_score: float  # 0.0–1.0
```

### Schéma Base de Données — Nouvelles Tables

**Migration 002 — ajouter exactement ces tables et colonnes :**

```sql
-- Table: items
CREATE TABLE items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
    item_number INTEGER NOT NULL,
    rang VARCHAR(1) NOT NULL CHECK (rang IN ('A', 'B', 'C')),
    chapter_title VARCHAR(500),
    ocr_text TEXT,                        -- supprimé par cleanup_worker ≤ 24h (NFR9)
    ocr_confidence_score FLOAT NOT NULL DEFAULT 0.0,
    low_confidence BOOLEAN NOT NULL DEFAULT FALSE,
    start_page INTEGER,
    end_page INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index pour Story 1.3 (accès par college)
CREATE INDEX ix_items_college_id ON items(college_id);

-- Table: generation_jobs
CREATE TABLE generation_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    college_id UUID NOT NULL REFERENCES colleges(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    arq_job_id VARCHAR(255),              -- ID ARQ pour tracking
    card_count INTEGER DEFAULT 0,
    hash_shared BOOLEAN NOT NULL DEFAULT FALSE,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_generation_jobs_college_id ON generation_jobs(college_id);

-- Colonne total_pages sur colleges (absente en Story 1.1)
ALTER TABLE colleges ADD COLUMN total_pages INTEGER;

-- Trigger updated_at sur colleges (reporté depuis Story 1.1)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_colleges_updated_at
    BEFORE UPDATE ON colleges
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

**Statuts valides pour `generation_jobs.status` :** `pending`, `processing`, `ocr_complete`, `generation_complete`, `failed`

### Structure ARQ Worker OCR

```python
# app/workers/ocr_worker.py

async def process_college_ocr(ctx: dict, college_id: str, pdf_path: str) -> dict:
    """
    Traitement OCR page par page avec reprise depuis ocr_page_progress.
    Ne pas utiliser print() — utiliser le logger.
    """
    db: AsyncSession = ctx["db"]          # injecté via ARQ ctx
    
    # 1. Charger le college depuis la DB
    college = await db.get(College, college_id)
    
    # 2. Déterminer page de reprise (NFR11)
    start_page = college.ocr_page_progress  # 0 = début
    
    # 3. Compter le total de pages (pdfplumber)
    with pdfplumber.open(pdf_path) as pdf:
        total_pages = len(pdf.pages)
    
    # 4. Mettre à jour total_pages et status → processing
    college.total_pages = total_pages
    college.status = CollegeStatus.processing
    await db.commit()
    
    # 5. Boucle OCR page par page (reprend depuis start_page)
    page_texts = []
    for page_num in range(start_page, total_pages):
        result = await ocr_processor.process_page(pdf_path, page_num)
        page_texts.append(result.text)
        
        # Persister la progression AVANT de continuer (NFR11)
        college.ocr_page_progress = page_num + 1
        await db.commit()
    
    # 6. Détecter les items
    items = item_detector.detect_items(page_texts)
    
    # 7. Insérer les items en base
    for detected_item in items:
        db.add(Item(college_id=college_id, ...))
    
    # 8. Mettre à jour statut → ocr_complete
    college.status = CollegeStatus.ocr_complete
    await db.commit()
    
    return {"college_id": college_id, "item_count": len(items)}
```

**Enregistrement dans settings.py :**
```python
# app/workers/settings.py — CORRIGER le bug max_retries (reporté Story 1.1)
WORKER_SETTINGS = {
    "redis_settings": redis_settings,
    "max_jobs": 10,
    "job_timeout": 7200,
    "keep_result": 3600,
    "retry_jobs": True,
    "max_retries": 3,          # ← AJOUTER (bug Story 1.1)
}
```

### HTTP Basic Auth — Dependency FastAPI

```python
# app/deps.py — AJOUTER cette dépendance

from fastapi.security import HTTPBasic, HTTPBasicCredentials
from fastapi import Depends, HTTPException
import secrets

security = HTTPBasic()

async def get_admin_user(credentials: HTTPBasicCredentials = Depends(security)) -> bool:
    """Protège toutes les routes /v1/admin/."""
    settings = get_settings()
    correct_username = secrets.compare_digest(credentials.username, settings.admin_username)
    correct_password = secrets.compare_digest(credentials.password, settings.admin_password)
    if not (correct_username and correct_password):
        raise HTTPException(status_code=401, detail="Invalid credentials",
                            headers={"WWW-Authenticate": "Basic"})
    return True
```

**Utilisation dans les routes :**
```python
@router.post("/colleges/{college_id}/process")
async def process_college(
    college_id: uuid.UUID,
    pdf: UploadFile,
    _: bool = Depends(get_admin_user),  # Basic Auth obligatoire
    db: AsyncSession = Depends(get_db),
    ...
):
```

### Endpoint POST /v1/admin/colleges/{college_id}/process

**Comportement attendu :**
1. Valider que `college_id` existe en base
2. Sauvegarder le PDF dans `/tmp/collega_pdfs/{college_id}.pdf` (chemin configurable via settings)
3. Créer un `GenerationJob` en base avec statut `pending`
4. Enqueuer le job ARQ `process_college_ocr`
5. Retourner `{ "data": { "job_id": "...", "status": "pending" } }`

**Gestion des erreurs :**
- `college_id` inexistant → 404 `{"error": {"code": "COLLEGE_NOT_FOUND", "message": "..."}}`
- Fichier non-PDF → 422 `{"error": {"code": "INVALID_FILE_TYPE", "message": "..."}}`
- Job déjà `processing` → 409 `{"error": {"code": "JOB_IN_PROGRESS", "message": "..."}}`

### Endpoint GET /v1/admin/colleges/{college_id}/status

**Format réponse exact (AC #4) :**
```json
{
  "data": {
    "status": "processing",
    "ocr_page_progress": 47,
    "total_pages": 380,
    "job_id": "uuid-job-id"
  }
}
```

### Fichiers à Créer (NEW)

```
collega_backend/
├── app/
│   ├── models/
│   │   ├── item.py                           ← NEW
│   │   └── generation_job.py                 ← NEW
│   ├── schemas/
│   │   ├── admin.py                          ← NEW
│   │   └── item.py                           ← NEW
│   ├── api/v1/
│   │   └── admin.py                          ← NEW (routes OCR Phase 0 uniquement)
│   ├── services/ocr/
│   │   ├── __init__.py                       ← NEW
│   │   ├── ocr_processor.py                  ← NEW
│   │   ├── confidence_scorer.py              ← NEW
│   │   └── item_detector.py                  ← NEW
│   └── workers/
│       └── ocr_worker.py                     ← NEW
├── alembic/versions/
│   └── 002_add_items_generation_jobs.py      ← NEW
└── tests/
    ├── fixtures/
    │   └── sample_ecni.pdf                   ← NEW (PDF minimal pour tests)
    ├── api/
    │   └── test_admin_ocr.py                 ← NEW
    ├── services/
    │   ├── test_ocr_processor.py             ← NEW
    │   ├── test_confidence_scorer.py         ← NEW
    │   └── test_item_detector.py             ← NEW
    └── workers/
        └── test_ocr_worker.py                ← NEW
```

### Fichiers à Modifier (UPDATE)

| Fichier | Modification |
|---------|-------------|
| `app/models/__init__.py` | Ajouter `Item`, `GenerationJob` dans `__all__` |
| `app/models/college.py` | Ajouter `total_pages` + relationships |
| `app/workers/settings.py` | Ajouter `max_retries: 3`, enregistrer `process_college_ocr` |
| `app/deps.py` | Ajouter `get_admin_user` (Basic Auth dependency) |
| `app/core/config.py` | Ajouter `admin_username`, `admin_password`, `pdf_storage_path` |
| `app/main.py` | Inclure router admin avec prefix `/v1/admin` |
| `pyproject.toml` | Ajouter `pdfplumber`, `pytesseract`, `pdf2image` |
| `Dockerfile` | Ajouter `tesseract-ocr tesseract-ocr-fra poppler-utils` |

### Apprentissages Story 1.1 — À Appliquer

Depuis les review findings de Story 1.1 (deferred) :

1. **`updated_at` sans trigger DB** : résolu dans la migration 002 (trigger PostgreSQL ci-dessus). Le `onupdate` SQLAlchemy ne fonctionne qu'avec les UPDATE via ORM — pas les UPDATE SQL directs.

2. **`ARQ retry_jobs: True` sans `max_retries`** : jobs OCR bloqués indéfiniment en cas d'échec. Corriger dans `settings.py` avec `max_retries: 3`.

3. **`app/models/__init__.py` doit importer tous les modèles** : chaque nouveau modèle (`Item`, `GenerationJob`) DOIT être importé ici pour qu'Alembic autogenerate les détecte. Oublier cet import = migration vide générée silencieusement.

4. **`CollegeStatus` sans contrainte DB** : la contrainte `CHECK` est ajoutée via la migration 002 pour `generation_jobs.status`. Le champ `colleges.status` garde son type String(50) sans contrainte DB (décision maintenue — coût refactoring élevé, validation applicative suffisante).

### Patterns de Qualité — Rappels Impératifs

**Toujours :**
- `{ "data": { ... } }` sur toutes les réponses API — sans exception
- ISO 8601 UTC pour `created_at`, `updated_at` dans les schemas Pydantic
- `logger.info(...)` depuis `app/core/logger.py` — jamais `print()`
- `user_id` en scope sur toutes les requêtes DB (NFR8)
- `secrets.compare_digest()` pour comparer les credentials admin (timing-safe)

**Jamais :**
- `Base.metadata.create_all()` — uniquement Alembic pour les migrations
- Secrets dans le code ou fichiers versionnés — uniquement dans `.env`
- Logique métier dans les routes FastAPI — dans les services

### Concernant le PDF temporaire

Le PDF uploadé doit être stocké temporairement pour que le worker ARQ puisse y accéder de manière asynchrone (le worker s'exécute dans un process séparé). Chemin : `/tmp/collega_pdfs/{college_id}_{job_id}.pdf`. Configurable via `settings.pdf_storage_path`. Le nettoyage automatique n'est pas dans le scope Story 1.2 — le `cleanup_worker` de Story 1.3 s'en chargera.

### Project Structure Notes

- Story 1.2 est exclusivement **backend** — aucun fichier Flutter n'est modifié
- Les deux projets (`collega_backend/` et `collega_app/`) restent au même niveau dans le repo
- Les routes admin créées ici seront ÉTENDUES en Story 1.4 (monitoring queue, gestion beta, stats) — ne pas implémenter ces fonctionnalités maintenant
- L'endpoint `POST /v1/admin/colleges/{college_id}/process` est différent de `POST /v1/colleges/{college_id}/import` (Future Epic 3) qui sera initié par l'app Flutter utilisateur
- La table `items` créée ici sera utilisée directement par Story 1.3 (génération Claude) et Story 3.x (affichage fiches Flutter)

### References

- [Source: `_bmad-output/planning-artifacts/epics.md#Story-1.2`] — Acceptance Criteria complets
- [Source: `_bmad-output/planning-artifacts/architecture.md#Data-Architecture`] — Schéma général, hash-sharing, NFR9 cleanup
- [Source: `_bmad-output/planning-artifacts/architecture.md#Complete-Project-Directory-Structure`] — Structure `services/ocr/`, `workers/`, `api/v1/admin.py`
- [Source: `_bmad-output/planning-artifacts/architecture.md#Naming-Patterns`] — Conventions snake_case, wrapper `{ "data": ... }`
- [Source: `_bmad-output/planning-artifacts/architecture.md#Communication-Patterns`] — Format SSE (utilisé dès Story 3.2)
- [Source: `_bmad-output/implementation-artifacts/1-1-infrastructure-homelab-squelettes-projets.md#Review-Findings`] — Defer findings à corriger dans cette story (updated_at trigger, ARQ max_retries, models/__init__.py)
- [Source: `_bmad-output/planning-artifacts/epics.md#Additional-Requirements`] — ARQ queue, cleanup_worker, anti-spam configurables

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- `ModuleNotFoundError: No module named 'asyncpg'` lors de l'import de l'app en tests : résolu par patch de `create_async_engine` avant import + `DATABASE_URL=sqlite+aiosqlite:///./test.db` dans conftest.py
- `AttributeError: 'NoneType' object has no attribute 'set'` pour les modèles SQLAlchemy dans les workers tests : résolu en utilisant `types.SimpleNamespace` au lieu de `College.__new__(College)` — SQLAlchemy instrumentalise les attributs et `__new__()` contourne l'initialisation
- `@patch("app.api.v1.admin.create_pool")` échoue car import lazy dans le body de la route : résolu avec `@patch("arq.create_pool")`
- `ModuleNotFoundError: No module named 'pdfplumber'` dans `test_count_pages_uses_pdfplumber` : résolu avec `patch.dict(sys.modules, {"pdfplumber": mock_pdfplumber})` — injection du module sans installation réelle
- Bug dans `ocr_worker.py` : `_confidence_scorer.score(detected.__class__.__new__(...))` erroné ; simplifié en `item_score = detected.ocr_confidence_score`

### Completion Notes List

- **Migration 002** créée avec tables `items` et `generation_jobs`, colonne `total_pages` sur `colleges`, trigger PostgreSQL `update_updated_at_column()` pour `colleges.updated_at` (fix Story 1.1 deferred)
- **Modèles SQLAlchemy** `Item` et `GenerationJob` créés avec toutes colonnes conformes au schéma ; `College` mis à jour avec `total_pages` et relationships cascadées ; `__init__.py` mis à jour pour autogenerate Alembic
- **Services OCR** : `OcrProcessor` (pdfplumber primaire + pytesseract fallback, imports lazy pour éviter dépendances au test), `ConfidenceScorer` (seuil 0.7), `ItemDetector` (regex ECNi : Item N, Rang A/B/C, Chapitre)
- **Worker ARQ** : `process_college_ocr` avec reprise depuis `ocr_page_progress` (NFR11) — progression persistée après chaque page ; `ocr_worker.py` utilise `_run_ocr` interne pour faciliter les tests ; `settings.py` corrigé avec `max_retries: 3`
- **Routes admin** : `POST /v1/admin/colleges/{college_id}/process` (upload PDF, création job, enqueue ARQ) et `GET /v1/admin/colleges/{college_id}/status` ; HTTP Basic Auth via `secrets.compare_digest` timing-safe
- **Tests** : 47 tests passent (1 skipped), 0 régression — pdfplumber, pytesseract, asyncpg, Redis/ARQ tous mockés ; `types.SimpleNamespace` pour modèles SQLAlchemy dans workers tests ; SQLite + aiosqlite pour l'env de test

### File List

**Créés :**
- `collega_backend/alembic/versions/002_add_items_generation_jobs.py`
- `collega_backend/app/models/item.py`
- `collega_backend/app/models/generation_job.py`
- `collega_backend/app/services/ocr/__init__.py`
- `collega_backend/app/services/ocr/ocr_processor.py`
- `collega_backend/app/services/ocr/confidence_scorer.py`
- `collega_backend/app/services/ocr/item_detector.py`
- `collega_backend/app/workers/ocr_worker.py`
- `collega_backend/app/schemas/admin.py`
- `collega_backend/app/schemas/item.py`
- `collega_backend/app/api/v1/admin.py`
- `collega_backend/tests/api/test_admin_ocr.py`
- `collega_backend/tests/services/test_ocr_processor.py`
- `collega_backend/tests/services/test_confidence_scorer.py`
- `collega_backend/tests/services/test_item_detector.py`
- `collega_backend/tests/workers/test_ocr_worker.py`
- `collega_backend/tests/fixtures/sample_ecni.pdf`

**Modifiés :**
- `collega_backend/app/models/__init__.py`
- `collega_backend/app/models/college.py`
- `collega_backend/app/models/user.py`
- `collega_backend/app/workers/settings.py`
- `collega_backend/app/deps.py`
- `collega_backend/app/core/config.py`
- `collega_backend/app/main.py`
- `collega_backend/pyproject.toml`
- `collega_backend/Dockerfile`
- `collega_backend/tests/conftest.py`

**Ajoutés (code review — 2026-04-27) :**
- `collega_backend/alembic/versions/003_review_fixes.py`

## Change Log

| Date | Change |
|------|--------|
| 2026-04-27 | Story créée — analyse exhaustive des artefacts, story 1.1, architecture, code existant |
| 2026-04-27 | Implémentation complète — migration 002, modèles, services OCR, worker ARQ, routes admin, tests (47 passent) |
| 2026-04-27 | Code review — 16 patches appliqués : migration 003 (contraintes, triggers, index unique, page_texts_json), reprise OCR correcte via page_texts_json, blocking I/O → asyncio.to_thread, 503 si Redis down, chunked PDF upload, magic bytes check, items DELETE avant réinsertion (retry), PDF vide → failed, PIL images fermées, rang warning log, pool.close() finally, DataWrapper supprimé. 50 tests passent. |

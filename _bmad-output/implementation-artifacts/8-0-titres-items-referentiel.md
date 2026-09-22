# Story 8.0 : Tout item a un titre — référentiel auto-alimenté (backend + migration)

Status: done

## Story

En tant qu'**étudiant**,
je veux voir le nom de chaque item (« Tumeurs du testicule ») plutôt qu'un numéro (« Item 310 »),
afin de choisir quoi réviser sans ouvrir la fiche.

## Constats de l'analyse (prod NAS, 2026-09-22 — lecture seule)

Ces constats **corrigent** des prémisses de l'epic ; la story les intègre.

| # | Constat | Conséquence |
|---|---|---|
| C1 | 44 items en prod (CNEC `college_ref_id=3` : 23 items, CEP `34` : 21). Seuls 5 ont un `chapter_title`, **tous faux** : « d'un malade atteint de cancer », « Pr Michel Ducreux1, Pr Serge Evrard2… », « Les objectifs de rang B apparaissent en italique dans le texte », « de ces objectifs », « à l'hyperœstrogénie induite… ». `_CHAPTER_PATTERN` matche « partie »/« chapitre » **dans le corps du texte**. | Semer le référentiel « depuis les titres déjà en base » l'empoisonnerait. Les titres existants passent par le filtre de validité ; les rejetés sont remis à `NULL`. `_CHAPTER_PATTERN` est **supprimé** (l'epic disait « conserver en second recours » : la prod prouve qu'il ne produit que du bruit). |
| C2 | `items.ocr_text` est `NULL` partout : `cleanup_ocr_text` le purge 24 h après génération (NFR9). | La migration ne peut rien ré-extraire du texte en base. |
| C3 | Les 2 PDF sources sont encore sur le volume `/tmp/collega_pdfs/{college_id}_{uuid}.pdf` (worker et api). | Backfill réel = **script one-shot** qui relit les PDF (pdfplumber, texte seul, sans OCR ni Claude) dans le conteneur worker. |
| C4 | Formats d'en-tête réels. **CEP** (Pneumologie) : `Item 75\nAddiction au tabac.\nRang Rubrique Intitulé…` — titre sur la/les ligne(s) suivante(s), parfois sur 2 lignes (`Infections broncho-pulmonaires\ncommunautairesde l'adulte.`), un seul mot possible (`Pneumothorax`). **CNEC** (Cancérologie) : `Item 290` est un **en-tête courant répété sur chaque page** ; le titre est dans `OBJECTIFS: N° 304. Tumeurs du foie, primitives et secondaires` (variantes `OBJECTIFS : N° 291.`, `OBJECTIFS: N"o300.`, titre sur 1 à 3 lignes). | Deux extracteurs : ligne(s) d'en-tête + motif `OBJECTIFS N°`. |
| C5 | Recouvrement CNEC/CEP : **un seul numéro** (309). | « CNEC et CEP se complètent mutuellement » est marginal ; le référentiel vaut surtout pour les **futurs** imports. Les titres de prod viendront du script de relecture PDF. |
| C6 | **Bug de détection CNEC (régression qualité existante)** : l'en-tête courant fait de chaque page un « en-tête d'item » → spans d'une page → la dédup garde **une seule page par item** (`start_page` 290 = 20 alors que le chapitre commence p. 12). Les fiches CNEC ont été générées sur une page par item. | Fusionner les pages consécutives portant le même numéro en un seul span. |
| C7 | **Bug sommaire** : la page 3 (sommaire : `Chapitre 16 : … 271\nItem 306`) est prise pour l'en-tête de l'item 306 (`start_page=3`) → le span 306 contient la préface. Items 296 et 313 non détectés. | Ignorer les pages de sommaire (≥ 3 numéros d'item distincts en début de ligne, ou lignes à points de conduite). |

C6/C7 sont corrigés dans cette story (même fichier, même tests). Les fiches CNEC déjà générées restent celles d'avant : régénérer le CNEC exige un réimport (coût Claude) — hors story, signalé dans les notes de complétion.

## Critères d'acceptance

1. **Extraction en-tête** — Étant donné une page d'en-tête `Item 310 – Tumeurs du testicule` (séparateurs `–`, `-`, `:`, `.` sur la même ligne) **ou** `Item 75\nAddiction au tabac.` (ligne(s) suivante(s), jusqu'à 3, arrêt sur `Rang`, ligne vide, puce `•►➔-+`, numérotation `1.`/`I.`), quand l'OCR détecte l'item, alors `chapter_title` vaut le titre nettoyé (espaces normalisés, ponctuation finale `.,;:` retirée, casse d'origine, 200 caractères max coupés au mot).
2. **Extraction OBJECTIFS** — Étant donné `OBJECTIFS: N° 304. Tumeurs du foie, primitives et secondaires` n'importe où dans le document (variantes `OBJECTIFS :`, `N°`, `N"o`, `No`, titre sur 1 à 3 lignes), alors le titre de l'item 304 est extrait ; cette source **prime** sur la ligne d'en-tête (plus complète).
3. **Filtre de validité** (fonction pure partagée) — un titre est valide s'il : fait 5 à 200 caractères ; commence par une majuscule (accents compris) ; compte ≥ 2 mots **ou** un seul mot de ≥ 6 lettres (`Pneumothorax`) ; a ≥ 60 % de lettres parmi ses caractères non blancs ; ne contient ni points de conduite (`....`), ni puce, ni motif d'auteur (`Pr X`, `Dr X`), ni méta-texte (`objectif`, `rang A/B/C`). Les 5 titres de prod listés en C1 sont **rejetés** (test).
4. **Référentiel** — Étant donné un titre valide extrait, quand l'item est enregistré, alors `(item_number, label)` est enregistré dans la table globale `item_titles` (`source` `extracted`, `occurrences` +1, `updated_at`) ; un titre invalide n'y entre pas.
5. **Lecture du référentiel** — libellé retenu pour un numéro : `official` d'abord, puis `occurrences` décroissantes, puis le plus ancien (`created_at`, puis `id`).
6. **Cascade à la création** — en-tête/OBJECTIFS valide → sinon référentiel → sinon `chapter_title = NULL` (plus jamais `""`) **et** `logger.warning` nommant le collège et le numéro.
7. **Complétion rétroactive** — quand un titre valide entre au référentiel, tout item existant de ce numéro dont `chapter_title` est `NULL`/`""` le reçoit (tous collèges, tous utilisateurs).
8. **Détection** — les pages consécutives portant le même `Item N` forment **un seul** item (span continu, rang = meilleur rang trouvé sur le span, défaut `A`) ; les pages de sommaire ne créent pas d'item.
9. **Migration `015`** — crée `item_titles` ; remet à `NULL` les `chapter_title` existants qui échouent au filtre ; peuple le référentiel depuis les titres valides restants ; backfill des items `NULL`/`""` par numéro. Idempotente (rejouable sans doublon ni perte), `downgrade` supprime la table sans toucher aux items.
10. **Backfill prod** — `scripts/backfill_item_titles.py [--dry-run]` relit le PDF de chaque collège présent sur le volume (texte pdfplumber, sans OCR ni Claude), extrait les titres par numéro, alimente le référentiel, met à jour les items **sans modifier** pages, rangs ni fiches ; affiche un rapport (titrés / restants par collège).
11. **Prod** — après déploiement + script : CNEC et CEP ont un titre sur tous leurs items (trous restants comptés et listés s'il y en a).
12. **API** — `/v1/colleges/{id}/items` et la recherche renvoient `chapter_title` (inchangé côté schéma ; `null` et jamais `""`).
13. **App** — un seul helper d'affichage : titre si non vide, sinon `Item N` (et `debugPrint` du trou) ; utilisé dans Détail collège, Détail item (titre + barre de lancement) et résultats de recherche ; `""` traité comme nul. La colonne Drift reste nullable (le backend peut encore avoir des trous).

## Tâches

- [x] **T1 — Filtre + nettoyage** (AC 1, 3) : `app/services/ocr/item_titles.py` → `clean_title(raw) -> str`, `is_valid_title(title) -> bool`. Tests d'abord (`tests/services/test_item_titles.py`), dont les 5 déchets de prod et les titres réels CEP/CNEC.
- [x] **T2 — Extraction dans `item_detector.py`** (AC 1, 2, 8) : `_title_from_header(text, match)`, `_titles_from_objectifs(page_texts) -> dict[int, str]`, fusion des en-têtes consécutifs de même numéro, détection de sommaire ; suppression de `_CHAPTER_PATTERN` / `_extract_chapter`. Mettre à jour `test_chapter_extracted_from_page` (le motif « Chapitre … » n'est plus une source).
- [x] **T3 — Modèle + service référentiel** (AC 4, 5, 7) : `app/models/item_title.py` (`ItemTitle`), export dans `app/models/__init__.py` ; dans `item_titles.py` : `record_title(db, number, label)` (upsert + backfill des items vides), `lookup_title(db, number)`. Tests sur SQLite (aiosqlite) avec une vraie session.
- [x] **T4 — Cascade dans `ocr_worker.py`** (AC 6) : étape 6, avant `Item(...)`. `chapter_title=None` au lieu de `""`. Tests worker : titre valide enregistré, repli référentiel, `NULL` + warning.
- [x] **T5 — Non-régression** (AC 6) : test qui échoue si un item est créé avec un titre vide alors que le référentiel en contient un.
- [x] **T6 — Migration `015_add_item_titles.py`** (AC 9) : SQL portable Postgres ; le filtre est appliqué en Python dans la migration (import de `app.services.ocr.item_titles`, fonction pure). Test de la logique de migration sur SQLite.
- [x] **T7 — Script `scripts/backfill_item_titles.py`** (AC 10) : réutilise `ItemDetector` sur le texte pdfplumber de toutes les pages ; `--dry-run` ; test unitaire de la fonction pure de rapprochement (sans PDF).
- [x] **T8 — App** (AC 13) : `lib/features/colleges/domain/item_title.dart` (`itemDisplayTitle(int number, String? title)`), branché aux 3 écrans ; tests `test/features/colleges/item_title_test.dart` + ajustements des tests d'écran concernés.
- [x] **T9 — Déploiement prod** (AC 11) : build amd64, push, `compose pull api worker migrate && up -d`, puis `docker exec collega-worker-1 python -m scripts.backfill_item_titles --dry-run` puis sans (`-m` obligatoire, sinon `app` est introuvable). Vérification SQL : items titrés par collège.

## Dev Notes

### Fichiers — état actuel et changements

- `collega_backend/app/services/ocr/item_detector.py` — passe 1 : une page = un en-tête si `^item\s*n?°?\s*(\d{1,3})\b` (MULTILINE) ; `search` ne prend que la **première** occurrence de la page. Rang : tables pdfplumber → texte → `A` si `Item N` avant 400 caractères. Passe 2 : span = jusqu'à l'en-tête suivant − 1. **À préserver** : filtrage des références inline (> 400 car. sans rang), priorité de rang A > B > C, `DetectedItem` (champs inchangés), tests existants de rang/délimitation.
- `collega_backend/app/workers/ocr_worker.py` — étape 5 dédup par numéro (garder), étape 6 `Item(chapter_title=detected.chapter_title or "")` → cascade. Les tests worker simulent `db` en `AsyncMock` : la cascade doit passer par des fonctions patchables (`record_title`, `lookup_title` importées au niveau module) pour ne pas casser ces tests.
- `collega_backend/app/models/item.py` — `chapter_title String(500) nullable` : inchangé.
- `collega_backend/alembic/versions/014_…` → nouvelle `015`, `down_revision = "014"`.
- App : `lib/core/database/tables/items_table.dart` (nullable, inchangé), `college_detail_screen.dart:465-480`, `item_detail_screen.dart:70,87`, `search_result_tile.dart:62`. Ces écrans seront reconstruits en 8.6-8.11 : changement minimal, via le helper.

### Architecture et conventions

- Backend FastAPI + SQLAlchemy async, Alembic à numéros séquentiels (`revision = "015"`), tests pytest + SQLite (`tests/conftest.py`), mocks `AsyncMock` pour les workers. Logging `logger = logging.getLogger(__name__)`, messages en français.
- Unicité référentiel : `UNIQUE(item_number, label)` ; `source` `CHECK IN ('extracted','official')` ; une entrée `official` future remplace la priorité sans migration de schéma.
- Upsert portable SQLite/Postgres : `select` puis `update`/`insert` dans la session (volumes minuscules), pas de `ON CONFLICT` spécifique.
- Le filtre vit dans une fonction pure importée par la migration : si le filtre évolue plus tard, la migration 015 garde le comportement du moment (acceptable, elle ne s'exécute qu'une fois).

### Tests

- Ciblés uniquement : `pytest tests/services/test_item_detector.py tests/services/test_item_titles.py tests/workers/test_ocr_worker.py tests/test_migration_015.py tests/scripts` ; puis `pytest tests/api/test_colleges.py tests/api/test_search.py` en non-régression.
- App : `flutter test test/features/colleges test/features/search`.
- Venv backend : bcrypt < 4.0.0 obligatoire (mémoire projet), sinon les tests d'auth crashent — sans lien avec cette story.

### Déploiement

Packet Kage `runbook-d-ployer-le-backend-*` : `docker build --platform linux/amd64 -t tistech0/collega-backend:latest -t tistech0/collega-backend:<sha> .` (OrbStack : `orb start`), `docker push` ×2, `ssh nas` → `/mnt/user/appdata/compose-stacks/collega/` → `docker compose pull api worker migrate && docker compose up -d`. Ne jamais toucher au `.env` du NAS. Le script de backfill tourne dans `collega-worker-1` (volume PDF monté).

### Références

- Epic : `_bmad-output/planning-artifacts/epic-8-refonte-ux-ui.md` § Story 8.0
- Spec : `_bmad-output/planning-artifacts/ux-design-specification-v2.md` § Prérequis et dépendances
- Code : `collega_backend/app/services/ocr/item_detector.py`, `collega_backend/app/workers/ocr_worker.py`, `collega_backend/app/workers/cleanup_worker.py:25` (purge `ocr_text`)

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (1M context)

### Debug Log References

- Extraction essayée sur les 2 PDF de prod dans le conteneur worker (lecture seule) à chaque itération.
- Migration 015 validée sur Postgres 16 jetable (014 → données → 015 → downgrade → upgrade).
- `record_title` / `record_official_title` validés sur Postgres/asyncpg (repli IntegrityError).

### Completion Notes List

- **Prod (2026-09-22)** : sauvegarde `backups/collega_pre_015_20260922_2016.dump`, image `tistech0/collega-backend:3e75bdd`, migration 015 appliquée, script de rattrapage exécuté avec `--set 338="Œdème de Quincke et anaphylaxie"` (lettrine illisible dans le PDF CEP). Résultat : **44/44 items titrés** (CNEC 23/23, CEP 21/21), référentiel = 42 `extracted` + 1 `official`, 0 `""`.
- **Écarts assumés vs epic** : `_CHAPTER_PATTERN` supprimé (ne produisait que du bruit en prod) ; un seul mot accepté s'il fait ≥ 6 lettres (`Pneumothorax`) ; sommaire ajouté comme source (item 308 sans bloc OBJECTIFS lisible) ; titres en CAPITALES mis en casse de phrase ; troncature à 200 sans mot pendant.
- **Bugs corrigés en plus** (C6/C7 + revue) : en-têtes courants CNEC fusionnés (items = chapitre entier au lieu d'une page), sommaire ignoré (306 ne contient plus la préface), `. Item 313` détecté (le testicule n'est plus absorbé par le sein), puces `• Item N` = références, liste « items liés » ne fait plus passer une page pour un sommaire, en-tête de tableau `Rang Rubrique…` et intertitres (`Introduction`…) rejetés, sommaire « titre sous le numéro » ignoré (décalage), savepoint englobant tout `record_title`, `ensure_title` non incrémental pour le script rejouable, « Item 359 bis » non adjacent ne rend pas l'en-tête courant.
- **Sécurité** : l'image Docker Hub (publique) embarquait `.env` local, `collega_dump.sql` et `.venv` — vérifié : valeurs de dev uniquement (clé Claude vide, dump de seed), aucun secret de prod. `.dockerignore` ajouté ; les anciens tags (`0a7d3c5`, `48e50f9`) restent publics sur Docker Hub.
- **Reste hors story** : les fiches CNEC déjà générées l'ont été sur une page par item (bug C6) ; seul un réimport du CNEC (coût Claude) les régénère sur le chapitre entier.
- Tests : backend 215 verts sur les dossiers ciblés ; `tests/api/test_search.py` a 3 échecs pré-existants (Redis local absent, identiques sans la story). App : `test/features/colleges` + `test/features/search` 85 verts (dont 1 test `search_notifier` périmé réaligné sur le debounce).

### File List

- collega_backend/.dockerignore (new)
- collega_backend/alembic/versions/015_add_item_titles.py (new)
- collega_backend/app/models/item_title.py (new), app/models/__init__.py
- collega_backend/app/services/ocr/item_titles.py (new), app/services/ocr/item_detector.py
- collega_backend/app/workers/ocr_worker.py
- collega_backend/scripts/__init__.py (new), scripts/backfill_item_titles.py (new)
- collega_backend/tests/sqlite_db.py (new), tests/test_migration_015.py (new), tests/scripts/ (new), tests/services/test_item_titles.py (new), tests/services/test_item_detector.py, tests/workers/test_ocr_worker.py
- collega_app/lib/features/colleges/domain/item_title.dart (new), lib/features/colleges/presentation/college_detail_screen.dart, lib/features/colleges/presentation/item_detail_screen.dart, lib/features/search/widgets/search_result_tile.dart
- collega_app/test/features/colleges/item_title_test.dart (new), test/features/search/search_result_test.dart, test/features/search/search_notifier_test.dart

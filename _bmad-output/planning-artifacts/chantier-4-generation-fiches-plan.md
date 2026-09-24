# Chantier 4 — Génération des fiches (qualité et coûts Claude) : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** découpage des items juste (toutes les pages de l'item et seulement les siennes), texte extrait dans le bon sens, prompt `p2` sur Claude Sonnet 5 en sortie structurée (0-40 fiches, rang A d'abord, type `cas_clinique`), comptabilité complète des tokens, génération parallèle, vidage du contenu puis réimport.

**Architecture:** l'analyse préalable (`.superpowers/sdd/chantier-4-analyse/segmentation-report.md`, git-ignoré, lisible par les implémenteurs) fournit la vérité terrain des 3 collèges, les causes (fichier:ligne) et un prototype `proto_segmenter.py` qui atteint 65/65 items exacts : il est porté dans `item_detector.py` règle par règle (R0-R10). Les textes réels restent hors git (`collega_backend/tests/fixtures/private/college_{3,12,34}.json`, exportés de la prod le 2026-09-24) ; la vérité terrain (numéros, titres officiels, plages de pages) est committée.

**Tech Stack:** pdfplumber 0.11.10, anthropic 1.8 (Messages API, `output_config.format` json_schema, thinking adaptatif), SQLAlchemy/Alembic, asyncio, Flutter (Collega UI, Widgetbook).

**Spec:** `_bmad-output/planning-artifacts/chantier-4-couts-claude-spec.md`

## Global Constraints

- Migration du chantier : **021** (`021_generation_p2_claude_usage.py`, `down_revision` = identifiant réel de la 020).
- `GENERATION_MODEL = "claude-sonnet-5"`, `PROMPT_VERSION = "p2"`, `GENERATION_VERSION = "claude-sonnet-5:p2"`. Tarifs USD/MTok : `claude-sonnet-4-6` 3/15, `claude-sonnet-5` 2/10, `claude-haiku-4-5*` 1/5 (vérifiés le 2026-09-24).
- Sonnet 5 : `thinking={"type": "adaptive"}`, `output_config={"effort": ..., "format": {"type": "json_schema", "schema": ...}}`, **jamais** `temperature`/`top_p`/`top_k` ni préremplissage (400). `max_tokens=16000` (génération), `2000` (régénération). Le texte est cherché parmi `response.content` (bloc `type == "text"`), jamais `content[0]`.
- Fiches : types `classique` | `definition` | `cas_clinique` ; rang de fiche `A` | `B` ; au plus 40 par item (tronqué + warning) ; `insufficient_text: true` → 0 fiche, item listé dans le résumé.
- Modifier `clean_for_prompt` ou le prompt impose d'incrémenter `PROMPT_VERSION`. L'empreinte (`fingerprint.item_hash`) et `item_texts` restent calculés sur le texte brut.
- Contenu sous droits : aucun texte de page dans git ni dans les logs ; fixtures privées ignorées proprement (`pytest.skip`) si absentes (CI).
- Concurrence : `settings.generation_concurrency` (défaut 4).
- Tests : backend (`TEST_PG_URL` vers la base dédiée indiquée dans le brief), `flutter test` par dossier, goldens tagués `golden`.

---

### Task 1: Extraction du texte (texte pivoté, lettres doublées) — spec § 4 « Texte pivoté »

**Files:** `app/services/ocr/ocr_processor.py`, `tests/services/ocr/test_ocr_processor_rotated.py`, `pyproject.toml` (dev : `reportlab` pour générer un PDF de test).

- `_page_text(page)` : texte des caractères droits, puis caractères non droits extraits à part (`matrix[1] > 0` → `extract_text(line_dir_rotated="ltr", char_dir_rotated="btt")` ; `matrix[1] < 0` → `line_dir_rotated="rtl", char_dir_rotated="ttb"`), joints par `\n` (code du rapport § 5). `page.dedupe_chars()` avant extraction.
- `undouble(line)` (lettres doublées « TTuummeeuurrss » → « Tumeurs », ligne dont ≥ 80 % des paires sont identiques) appliqué ligne par ligne au texte extrait (fonction pure dans `app/services/ocr/text_normalize.py`, réutilisée par le découpage).
- Tests : PDF synthétique (reportlab) avec « Indications » tourné de 90° dans les deux sens → texte contient « Indications », jamais « snoitacidnI » ; `undouble` (cas doublé, cas normal inchangé, « Collège » inchangé) ; fixture réelle si le PDF `HEMATO 5e college.pdf` est présent à la racine du dépôt (sinon skip) : page 385 sans mot à l'envers.
- [ ] TDD ; commit.

### Task 2: Découpage des items R0-R10 et rapport — spec § 4

**Files:** `app/services/ocr/item_detector.py` (réécrit), `app/workers/ocr_worker.py` (`_detect_items`, `with_pages`, `dedupe_items` supprimé), `tests/services/ocr/test_segmentation_rules.py` (un test synthétique par règle), `tests/services/ocr/test_segmentation_fixtures.py` (fixtures privées), `tests/fixtures/segmentation/ground_truth_college_{3,12,34}.json` (copie de la vérité terrain de l'analyse), `scripts/segmentation_report.py`.

- Porter `proto_segmenter.py` (analyse) dans `ItemDetector.detect_items(page_texts, page_scores, page_tables)` qui renvoie désormais `SegmentationResult(items: list[DetectedItem], report: SegmentationReport)`. `DetectedItem` gagne `pages: list[int]` (pages de contenu de l'item, triées ; `start_page`/`end_page` = min/max) ; le texte d'un item = pages de `pages` jointes.
- Règles R0-R10 exactement comme dans le rapport § 4 (ordre de la machine à états inclus). Référentiel officiel des titres : utilisé par R4/R6 **s'il est fourni** (paramètre `known_titles: dict[int, str] | None`, rempli par `ocr_worker` depuis `item_titles` source `official`) — le découpage doit atteindre la vérité terrain sans lui.
- `dedupe_items` supprimé : R8 garantit un item par numéro ; une réouverture non consécutive concatène les pages (warning dans le rapport).
- Rang : par objectif, selon le rapport § 3 (tableau repéré par `rang\W*rubrique` sur la page d'ouverture et les 2 suivantes ; glyphes {A, A*, O, 0, G, ©, @} → A, {B, B*, Q, □, s} → B, autres → inconnu ; colonne rang des tableaux pdfplumber trouvée par ses valeurs, ≥ 60 % de A/B/C) ; rang d'item = A si ≥ 1 objectif A, sinon B si ≥ 1 B, sinon `A` avec warning « rang inconnu » dans le rapport. `DetectedItem.objectives_a: int`, `objectives_b: int`.
- Rapport (`SegmentationReport`) : par page `{page, kind: item|section|blank, item_number|label, signals}`, `warnings: list[str]` ; sérialisable en JSON. `ocr_worker` le journalise en fin d'OCR (résumé : nb d'items, sections, warnings — sans texte) et l'enregistre dans `generation_jobs.segmentation_report` (TEXT JSON, migration 021) ; `GET /v1/admin/jobs/{id}` l'expose (`segmentation` : items → pages, sections, warnings) et la console admin l'affiche dans le détail de job (tableau repliable).
- `scripts/segmentation_report.py <pdf|fixture.json>` : tableau item → pages, caractères, objectifs A/B, warnings ; pour un PDF, passe par `OcrProcessor` (texte seulement, sans Tesseract si la page a une couche texte).
- Tests : un test synthétique par règle (liste du rapport § 4, R0 à R10, plus rang/glyphes/colonne par valeurs) ; fixtures privées : égalité items (numéro, plage de pages) avec `ground_truth_college_*.json`, 0 page de contenu non rattachée, aucune page de section dans un item ; skip propre si la fixture manque.
- [ ] TDD ; suite verte ; commit.

### Task 3: Texte envoyé à Claude — spec § 5

**Files:** Create `app/services/generation/prompt_text.py`, `tests/services/generation/test_prompt_text.py`.

- `clean_for_prompt(text: str) -> str` pure : filigranes (motifs de la spec § 5, insensibles à la casse), `(cid:NNN)`, lignes d'un seul caractère/fragment (≤ 2 caractères non espace) et numéros de page seuls, en-têtes/pieds répétés (ligne normalisée présente sur ≥ 50 % des pages d'un item d'au moins 3 pages — la fonction reçoit donc `pages: list[str]` : signature `clean_for_prompt(pages: list[str]) -> str`), suites de lignes vides réduites à une.
- Tests : chaque règle ; texte propre inchangé ; invariance de `fingerprint.item_hash` (calculé sur le brut, jamais sur le nettoyé).
- [ ] TDD ; commit.

### Task 4: Client Claude p2 — spec § 2, § 3, C2-C4

**Files:** `app/services/generation/claude_client.py`, `app/schemas/college.py` (si `FlashCardData` y porte le type), `tests/services/generation/test_claude_client.py`.

- Constantes du Global Constraints ; `GENERATION_SYSTEM_PROMPT` = texte exact de la spec § 3 ; message utilisateur `Item {n} — {titre}\n<texte_item>\n{texte nettoyé}\n</texte_item>`.
- Schéma : `{"type":"object","properties":{"flashcards":{"type":"array","items":{"type":"object","properties":{"type":{"type":"string","enum":["classique","definition","cas_clinique"]},"rang":{"type":"string","enum":["A","B"]},"recto":{"type":"string"},"verso":{"type":"string"}},"required":["type","rang","recto","verso"],"additionalProperties":false}},"insufficient_text":{"type":"boolean"}},"required":["flashcards","insufficient_text"],"additionalProperties":false}`.
- `generate_cards(item_number, title, pages: list[str], *, effort="medium") -> CardGenResult` : `CardGenResult(cards, input_tokens, output_tokens, model, insufficient_text: bool, stop_reason: str)` ; `FlashCardData(card_type, rang, recto, verso)`. `refusal`/`max_tokens` → 0 fiche + warning (numéro d'item) ; JSON illisible → 0 fiche ; > 40 → tronqué + warning ; texte vide → aucun appel.
- `regenerate_single_card(card, item, source_text, user_note)` : même modèle/réglages, schéma d'une fiche (avec `rang`), `max_tokens=2000`, renvoie aussi l'usage (`RegenResult(card | None, input_tokens, output_tokens, model)`).
- `ask_json(prompt, schema) -> tuple[dict, Usage]` (Haiku `claude-haiku-4-5-20251001`, sortie structurée avec le schéma `{"result": enum correct|partial|incorrect, "feedback": string}` fourni par `drill.py`).
- Tests (client Anthropic simulé) : paramètres envoyés (modèle, `thinking`, `output_config`, pas de `temperature`) ; bloc de réflexion avant le texte ; `refusal` et `max_tokens` → 0 fiche + usage ; `insufficient_text` ; troncature à 40 ; `cas_clinique` et `rang` par fiche ; régénération ; `ask_json`.
- [ ] TDD ; commit.

### Task 5: Comptabilité des tokens `claude_usage` — spec § 6

**Files:** migration 021 (partie usage), `app/models/claude_usage.py`, `app/services/generation/usage.py` (`record_usage(session_factory, *, kind, model, input_tokens, output_tokens, user_id, college_id=None, job_id=None)` en session courte), `app/services/generation/token_cost.py` (tarifs par modèle, `compute_cost_eur(model, input, output)`, modèle inconnu → Sonnet 5 + warning), routes admin usage/détail de job/overview, `app/static/admin/index.html`, régénération (`app/api/v1/flash_cards.py`), `app/api/v1/drill.py`, `tests/...`.

- Table et index exactement comme la spec § 6 ; reprise de l'historique (une ligne `generation`/`claude-sonnet-4-6` par `generation_jobs` ayant des tokens, `created_at` = celui du job) puis suppression de `generation_jobs.input_tokens`/`output_tokens`.
- Une ligne par appel facturé, écrite juste après la réponse (avant parsing) — génération (Task 6 l'appelle), régénération, évaluation.
- Admin : `GET /v1/admin/usage` → total, par utilisatrice, ventilation `by_kind` et `by_model`, colonne `last_30_days` ; `GET /v1/admin/jobs/{id}` → coût du job depuis `claude_usage` ; console mise à jour.
- Tests Postgres : une ligne par appel (y compris job échoué) ; `kind` régénération/évaluation ; migration (historique repris, colonnes supprimées) ; totaux admin et 30 jours.
- [ ] TDD ; commit.

### Task 6: Pipeline p2 parallèle, rang par fiche, résumé — spec § 7, § 8 « Parallèle »

**Files:** `app/services/generation/pipeline.py`, `app/services/generation/publish.py`, `app/workers/generation_worker.py`, `app/core/config.py` (`generation_concurrency: int = 4`), migration 021 (contrainte `ck_flash_cards_card_type` avec `cas_clinique`), `tests/services/test_generation_pipeline.py`, `tests/services/test_publish.py`.

- Pipeline : `asyncio.Semaphore(settings.generation_concurrency)` ; une tâche par item avec session courte et commit par item (logique actuelle conservée : génération réutilisée par empreinte+version, item inchangé gardé) ; `record_usage` après chaque appel ; appels via `clean_for_prompt(pages)` (les pages d'un item sont relues depuis `item_texts` — stocker le texte d'item avec un séparateur de page stable pour pouvoir le redécouper, ou relire les `job_pages` ; choisir et documenter). Annulation (Stop) : tâches en vol annulées, items commités conservés. Erreur d'API après les réessais du SDK : le job échoue (chemin existant `fail_job`, quota remboursé), les autres tâches annulées.
- `item_generations.cards_json` contient `rang` par fiche ; `publish` écrit `flash_cards.rang` = rang de la fiche (défaut : rang de l'item) et accepte `cas_clinique`.
- `insufficient_text` : l'item est marqué (colonne `job_items.insufficient_text BOOL DEFAULT false`, migration 021) et le résumé d'import (`ImportSummary.insufficient_items: list[int]`, aussi pour un premier import) le liste.
- Tests : 10 items, concurrence 4 → au plus 4 appels simultanés, tous publiés ; annulation au milieu → items commités conservés ; erreur d'API → job en échec ; rang par fiche publié ; `cas_clinique` accepté par la base ; résumé avec items insuffisants.
- [ ] TDD ; commit.

### Task 7: App — `cas_clinique`, étiquettes, tri, rang de la fiche, résumé — spec § 7

**Files:** `collega_app/lib/core/ui/components/cg_card_type_tag.dart` (nouveau composant Collega UI), exports `collega_ui.dart`, carte du drill et liste des fiches (`features/drill`, `features/colleges`), tri, écran/résumé d'import (`import_summary`), Widgetbook (`collega_app/widgetbook/lib/use_cases/…`), tests widget + golden (tag `golden`).

- Étiquette « Cas clinique » / « Définition » (rien pour « classique »), couleurs de la palette existante (tokens Collega UI, aucune nouvelle couleur), accessible (Semantics).
- `cas_clinique` se révise comme une classique (retournement) ; tri de la liste : classique, cas clinique, définition ; rang affiché = rang de la fiche.
- Résumé d'import : « Pas assez de contenu : items 215, … » si `insufficient_items` non vide.
- Tests : widget (étiquette par type, tri, résumé), golden de l'étiquette ; `flutter analyze` propre ; dossiers concernés verts (goldens compris, en local).
- [ ] Commit.

### Task 8: Vidage `wipe_content.py` — spec § 8

**Files:** `scripts/wipe_content.py`, `tests/scripts/test_wipe_content.py` (Postgres).

- Exactement la liste de la spec § 8 (ce qui part, ce qui reste), affiche les comptes avant/après, refuse sans `--confirm`, supprime les PDF restants du volume (`settings.pdf_storage_path`, fichiers `*.pdf` et dossier `uploads/`), retire les titres non officiels d'`item_titles`, remet à zéro `monthly_reloads`/`monthly_reloads_reset_at` et `colleges.reload_count` (les collèges partent de toute façon).
- Tests : ce qui part, ce qui reste (comptes, abonnements, `claude_usage` avec `college_id`/`job_id` à NULL), refus sans `--confirm`.
- [ ] TDD ; commit.

### Task 9: Mesures et contrôle de fumée — spec § 5 (mesure), § 9

**Files:** `scripts/measure_prompt_tokens.py` (`count_tokens` sur `claude-sonnet-5`, avant/après `clean_for_prompt`, par collège, depuis les fixtures privées), `scripts/smoke_generation.py`.

- Smoke (hors CI, clé réelle) : 3 items réels (un par collège, dont un long), `effort` `low` puis `medium` : fiches, nb par rang et type, tokens entrée/sortie, coût, et vérification « chaque nombre du verso figure dans le texte source ». Garder le `effort` le moins cher qui couvre les objectifs A (décision consignée dans le code et la PR). 429 répétés → `generation_concurrency` par défaut à 2.
- Résultats (tableaux) dans `_bmad-output/implementation-artifacts/chantier-4/mesures.md` (sans texte de fiche au-delà de quelques exemples courts).
- [ ] Exécution ; commit.

### Task 10: Documents, revue, déploiement, vidage, suivi du réimport

- [ ] Audit (chantier 4 fait, mesures), Kage (règles de découpage, prompt p2, « modifier le nettoyage ou le prompt = incrémenter PROMPT_VERSION »), `CLAUDE.md` si besoin.
- [ ] Revue indépendante ; corrections.
- [ ] Déploiement : dump (deploy.sh), migration 021, puis `docker exec collega-api-1 python scripts/wipe_content.py --confirm` ; comptes affichés ; `/health`.
- [ ] Nouvelle build iPhone si l'appareil est branché.
- [ ] Surveillance des logs au réimport par l'utilisateur (découpage, `insufficient_text`, coût par collège) — ou, s'il n'a pas encore réimporté, le rapport final le lui demande.

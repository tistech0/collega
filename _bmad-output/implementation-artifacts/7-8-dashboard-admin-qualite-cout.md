# Story 7.8 : Dashboard Admin — Qualité & Coût (Thème C, pont vers 7.5)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **Project Lead / admin**,
je veux inspecter les fiches générées, le feedback testeuse « non pertinent » et le coût en tokens (€) par import / user / global depuis la console web,
afin de juger la **qualité** et le **coût** du nouveau prompt persona (Story 7.5) sur un re-import réel — sans psql ni calcul manuel.

## Contexte & périmètre (à lire avant de coder)

Story 7.8 est le **Thème C** (et dernier) du Dashboard Admin (acté le 2026-06-16 via `correct-course`, source brainstorm `brainstorming-session-2026-06-16-2242.md`). Elle s'appuie sur le **socle livré par 7.6** (auth Basic admin, schémas wrappés `{ "data": ... }`, console web statique `app/static/admin/index.html` montée à `/admin`, helpers JS) et sur l'**instrumentation pipeline livrée par 7.7** (events timeline, `GET /jobs/{id}`).

**Objectif métier — c'est le PONT vers 7.5 :** le re-test du prompt persona (Story 7.5) est *gated* sur 7.6 + 7.7 + **7.8 done**. 7.8 est l'outil qui permet de **juger** la sortie du nouveau prompt : (1) inspecter les fiches recto/verso générées, (2) voir le feedback « non pertinent » de la testeuse = signal qualité n°1, (3) mesurer le coût en tokens/€ du nouveau prompt sur un re-import réel.

**Ce que 7.8 AJOUTE vs ce qui existe déjà :**

```
[EXISTANT — Story 1.4/1.5/7.6/7.7, à PRÉSERVER tel quel — NE PAS modifier les contrats]
GET   /v1/admin/colleges/{id}/stats   → fiches/rang + items_ocr_confidence + pertinence_stats (agrégat)   admin.py:299
GET   /v1/admin/jobs/{job_id}         → détail brut job + timeline + confiance OCR par item               admin.py:622
GET   /v1/admin/users/{user_id}       → détail user + collèges + jobs                                      admin.py:525
GET   /v1/admin/overview              → KPI users/jobs                                                      admin.py:593
+ console web /admin (overview/users/user-detail/imports/job-detail)                                       static/admin/index.html

[NOUVEAU — Story 7.8]
NEW DB  colonnes input_tokens / output_tokens sur generation_jobs   → usage Anthropic persisté par job (migration 014)
+ capture usage dans le pipeline génération (claude_client → card_generator → job)
GET     /v1/admin/colleges/{college_id}/cards   → inspection fiches générées (recto/verso/type/rang/item/confiance OCR)
GET     /v1/admin/colleges/{college_id}/feedback→ TesterFeedback joints au contenu fiche (focus « non pertinent »)
GET     /v1/admin/usage                          → agrégat tokens + coût € global + par user
+ extension GET /jobs/{job_id} → expose input_tokens/output_tokens/cost_eur (coût par import) — additif, ne casse rien
+ console web /admin : onglet « Qualité » (fiches + feedback d'un collège) + onglet « Coût » (tableau usage global/user + coût par import)
```

**Hors périmètre (NE PAS faire ici) :**
- Pas de modification du prompt persona lui-même (= Story 7.5, gated sur 7.8 done). 7.8 fournit l'**instrument de mesure**, pas le prompt.
- Pas de capture d'usage pour `regenerate_single_card` (flux feedback user de la Story 3.5, **hors d'un `GenerationJob`** — aucun job où raccrocher l'usage) ni pour `ask_json` (haiku, non utilisé dans la génération de fiches). Voir Dev Notes § Capture usage — périmètre exact.
- Pas de live/SSE. Lecture à la demande (refresh), comme 7.7.
- Pas de pagination (convention 1.4/7.7 ; un collège = ≤ 39 items × ~5 fiches ≈ 200 fiches max, acceptable). Voir Décisions PL.

**Décision d'architecture clé :** l'usage tokens est **cumulé par `GenerationJob`** (2 colonnes `input_tokens` / `output_tokens`), pas une table par appel. Le coût € est **calculé à la lecture** (fonction pure `compute_cost_eur`), jamais stocké — ainsi un changement de tarif ou de taux €/$ n'invalide pas l'historique. Voir Dev Notes § Schéma usage + § Calcul coût.

## Acceptance Criteria

### AC1 — Persistance de l'usage tokens Anthropic par job (NEW DB + capture pipeline)

**Étant donné** un import qui déclenche une génération Claude réelle (pas hash-sharing)
**Quand** la génération se termine (`status="generation_complete"`)
**Alors** `generation_jobs.input_tokens` et `generation_jobs.output_tokens` contiennent la **somme cumulée** des `response.usage.input_tokens` / `output_tokens` de tous les appels `generate_cards_for_item` du job
**Et** un import servi par **hash-sharing** (Claude jamais appelé) a `input_tokens=0` et `output_tokens=0` (gratuit, explicite)
**Et** un job antérieur à la migration (sans capture) reste à `NULL` (= « non mesuré », distinct de 0)
**Et** l'usage est capturé **même si le parsing JSON de la réponse échoue** (l'appel API a consommé les tokens — voir Dev Notes § Point de capture exact)

### AC2 — Inspection des fiches générées d'un collège (juger la qualité du prompt 7.5)

**Étant donné** un collège lié à un user
**Quand** l'admin appelle `GET /v1/admin/colleges/{college_id}/cards`
**Alors** il reçoit la liste des `FlashCard` du collège avec `recto`, `verso`, `card_type` (`classique`/`definition`), `rang` (A/B/C), `item_number` (de l'Item parent) et `ocr_confidence_score` / `low_confidence`
**Et** 404 `COLLEGE_NOT_FOUND` si le collège n'existe pas
**Et** l'écran web « Qualité » affiche ces fiches (recto/verso lisibles) pour jugement qualitatif

### AC3 — Vue feedback testeuse « non pertinent » (signal qualité n°1)

**Étant donné** des `TesterFeedback` remontés par la testeuse sur un collège
**Quand** l'admin appelle `GET /v1/admin/colleges/{college_id}/feedback`
**Alors** il reçoit chaque feedback avec son `is_pertinent`, `tester_id`, `created_at` **joint au contenu de la fiche** (`recto`, `verso`, `card_type`, `rang`)
**Et** les feedbacks « non pertinents » (`is_pertinent=false`) sont identifiables (champ booléen exposé ; le tri/mise en avant côté front)
**Et** 404 `COLLEGE_NOT_FOUND` si le collège n'existe pas
**Et** l'écran web « Qualité » affiche la liste des feedbacks (badge pertinent/non-pertinent + fiche concernée)

### AC4 — Agrégation conso tokens + coût € (import / user / global)

**Étant donné** que `input_tokens` / `output_tokens` sont désormais persistés par job
**Quand** l'admin appelle `GET /v1/admin/usage`
**Alors** il reçoit le **total global** (`input_tokens`, `output_tokens`, `cost_eur`) **et** la ventilation **par user** (`user_id`, `email`, `input_tokens`, `output_tokens`, `cost_eur`)
**Et** le **coût par import** est exposé via `GET /jobs/{job_id}` étendu (`input_tokens`, `output_tokens`, `cost_eur`) — additif, sans casser le contrat 7.7
**Et** `cost_eur` est calculé via une fonction pure depuis les tarifs Sonnet 4.6 + taux €/$ configurable (voir Dev Notes § Calcul coût) ; les jobs `NULL` (non mesurés) comptent comme 0 dans les agrégats
**Et** l'écran web « Coût » affiche le tableau global + par user, et le coût par import dans le détail job

### AC5 — Authentification & non-régression

**Étant donné** les 3 nouvelles routes (`/colleges/{id}/cards`, `/colleges/{id}/feedback`, `/usage`)
**Quand** elles sont appelées sans credentials Basic valides
**Alors** elles renvoient `401` (toutes protégées par `Depends(get_admin_user)`)
**Et** `POST /v1/register` renvoie toujours `403` (non touché), `GET /queue` et `GET /colleges/{id}/stats` gardent leur contrat exact (tests 1.4/1.5/7.7 verts)
**Et** la capture d'usage n'altère **jamais** le résultat de la génération (un échec de capture ne casse pas la création de fiches)

### AC6 — Vue web admin (onglets Qualité & Coût)

**Étant donné** la console `/admin` (socle 7.6 + écrans 7.7)
**Quand** l'admin navigue
**Alors** un écran **« Qualité »** permet, pour un collège donné, d'inspecter les fiches (recto/verso/type/rang/confiance OCR) et de voir les feedbacks (pertinent/non-pertinent + fiche)
**Et** un écran **« Coût »** affiche le tableau d'usage (global + par user, tokens + €) ; le coût par import apparaît dans le détail job existant
**Et** les écrans réutilisent les helpers JS existants (`apiFetch`, `readJson`, `escapeHtml`, `fmtDate`, `statusBadge`, `showSection`, `toast`) sans en réinventer

## Tasks / Subtasks

- [x] **T1 — Backend (NEW DB) : persister l'usage tokens par job + capture pipeline** (AC1, AC5)
  - [x] T1.1 — `app/models/generation_job.py` : + colonnes `input_tokens: int | None` et `output_tokens: int | None` (nullable, défaut NULL). Pas de CheckConstraint.
  - [x] T1.2 — `alembic/versions/014_add_token_usage_to_generation_jobs.py` : `revision="014"`, `down_revision="013"` ; `op.add_column` ×2 (`sa.Integer(), nullable=True`) ; `downgrade` = `op.drop_column` ×2. Suivre le pattern de la migration 013.
  - [x] T1.3 — `app/services/generation/claude_client.py` : `generate_cards_for_item` doit **aussi remonter l'usage**. Capturer `response.usage.input_tokens` / `output_tokens` **juste après l'appel `messages.create` (ligne ~106), AVANT le bloc de parsing** (l'usage est consommé même si le JSON est invalide). Retourner `(cards, usage)` — p.ex. un petit dataclass `CardGenResult(cards: list[FlashCardData], input_tokens: int, output_tokens: int)`. Sur `anthropic.APIError` re-levé (pas de réponse) : aucun usage à compter. Voir Dev Notes § Point de capture exact.
  - [x] T1.4 — `app/services/generation/card_generator.py` : dans `generate_for_college`, accumuler `input_tokens`/`output_tokens` à chaque itération de la boucle items (juste après l'appel modifié), puis écrire `job.input_tokens` / `job.output_tokens` **avant le `await db.commit()` final** (ligne ~158). Branche hash-sharing : fixer `job.input_tokens = 0`, `job.output_tokens = 0` avant son commit (ligne ~84). Garde anti-race (D1 de 7.7) : la sortie anticipée sur `status=="failed"` ne commit pas → usage partiel rollback, ok.
- [x] **T2 — Backend : endpoints inspection fiches + feedback + agrégation usage** (AC2, AC3, AC4, AC5)
  - [x] T2.1 — `GET /v1/admin/colleges/{college_id}/cards` : 404 si collège absent ; `select(FlashCard, Item.item_number).join(Item, FlashCard.item_id == Item.id).where(FlashCard.college_id == college_id).order_by(Item.item_number)` ; retourne liste `AdminFlashCardData` (recto/verso/card_type/rang/item_number/ocr_confidence_score/low_confidence).
  - [x] T2.2 — `GET /v1/admin/colleges/{college_id}/feedback` : 404 si collège absent ; **réutiliser le pattern de jointure de `get_college_stats`** (`select(TesterFeedback, FlashCard.recto, FlashCard.verso, FlashCard.card_type, FlashCard.rang).join(FlashCard, TesterFeedback.flash_card_id == FlashCard.id).where(TesterFeedback.college_id == college_id)`) ; retourne liste `AdminFeedbackData` (is_pertinent/tester_id/created_at + recto/verso/card_type/rang).
  - [x] T2.3 — `GET /v1/admin/usage` : total global + par user. Global : `select(func.coalesce(func.sum(GenerationJob.input_tokens), 0), func.coalesce(func.sum(GenerationJob.output_tokens), 0))`. Par user : `select(User.id, User.email, func.coalesce(func.sum(...), 0), ...).join(GenerationJob, ...).group_by(User.id, User.email)` (ou agrégat en Python si plus simple/cohérent avec le reste du fichier). `cost_eur` calculé via `compute_cost_eur`.
  - [x] T2.4 — `app/services/generation/token_cost.py` (NEW) : `compute_cost_eur(input_tokens: int, output_tokens: int) -> float` — pure, tarifs Sonnet 4.6 ($3/MTok in, $15/MTok out) + taux €/$ depuis `settings`. Voir Dev Notes § Calcul coût.
  - [x] T2.5 — Étendre `GET /jobs/{job_id}` (`JobDetailData`) : + `input_tokens`, `output_tokens`, `cost_eur` (additif). Ne pas renommer/supprimer de champ existant.
  - [x] T2.6 — `app/schemas/admin.py` : + `AdminFlashCardData`, `AdminCardsResponseWrapped`, `AdminFeedbackData`, `AdminFeedbackResponseWrapped`, `UsageByUserData`, `UsageData`, `UsageResponseWrapped` ; + champs usage sur `JobDetailData`.
  - [x] T2.7 — `app/core/config.py` : + `usd_eur_rate: float` (défaut ~0.92, surchargeable .env). Voir Décisions PL #3.
- [x] **T3 — Vue web admin : onglets Qualité & Coût** (AC2, AC3, AC4, AC6)
  - [x] T3.1 — Écran « Qualité » : sélection collège → fiches (recto/verso/type/rang/confiance OCR) + feedbacks (badge pertinent/non-pertinent + fiche concernée). Calquer `loadUsers`/`openUserDetail`.
  - [x] T3.2 — Écran « Coût » : tableau usage global + par user (tokens in/out + €) ; afficher le coût par import dans le détail job existant (réutiliser `openJobDetail`).
  - [x] T3.3 — Onglets `nav-tabs` ajoutés à la barre de navigation existante ; `showSection` pour les nouveaux `<section>`.
- [x] **T4 — Tests backend** (AC1–AC5)
  - [x] T4.1 — `tests/services/test_token_usage_capture.py` : `generate_for_college` cumule l'usage et l'écrit sur le job (mock `ClaudeClient`) ; branche hash-sharing → 0/0 ; capture maintenue si parsing JSON échoue.
  - [x] T4.2 — `tests/services/test_token_cost.py` : `compute_cost_eur` (valeurs connues, 0/0 → 0, taux configurable).
  - [x] T4.3 — `tests/api/test_admin_college_cards.py` : 200 (liste + champs), 404, 401.
  - [x] T4.4 — `tests/api/test_admin_college_feedback.py` : 200 (jointure fiche, is_pertinent), 404, 401.
  - [x] T4.5 — `tests/api/test_admin_usage.py` : agrégat global + par user, jobs NULL comptés 0, cost_eur cohérent, 401.
  - [x] T4.6 — Étendre/ajouter assertion `input_tokens/output_tokens/cost_eur` sur `GET /jobs/{id}` (ne pas casser `test_admin_job_detail` existant).

## Dev Notes

### Authentification admin — pattern non négociable

- **TOUTES** les nouvelles routes : `_: bool = Depends(get_admin_user)` (HTTP Basic Auth, `app/deps.py:18`, timing-safe `secrets.compare_digest`). Oublier ce `Depends` = faille d'accès.
- Credentials = `settings.admin_username`/`settings.admin_password`. En tests : `("admin", "testpass")`. 401 testé en n'envoyant pas `auth=`.
- Erreurs : `HTTPException(status_code=404, detail={"code": "COLLEGE_NOT_FOUND", "message": f"College {college_id} not found"})` — pattern uniforme du fichier, à conserver.

### Modèles réels (source de vérité — vérifiés dans le code)

- **`GenerationJob`** (`app/models/generation_job.py`) : `id`, `college_id FK(colleges) CASCADE`, `user_id FK(users) CASCADE`, `status: String(50)` **CheckConstraint** sur exactement `{pending, processing, ocr_complete, generation_complete, failed}` (NE PAS y toucher), `arq_job_id`, `card_count: int=0`, `hash_shared: bool=False`, `pdf_hash`, `error_message`, `page_texts_json`, `created_at`/`updated_at`. Relations `college`, `user`, `events`. **AJOUT 7.8 :** `input_tokens: int|None`, `output_tokens: int|None`.
- **`FlashCard`** (`app/models/flash_card.py`) : FK `item_id`/`college_id`/`user_id` CASCADE. Champs : `card_type: String(20)` (`classique`/`definition`), `rang: String(1)` (A/B/C), `recto: Text`, `verso: Text`, `ocr_confidence_score: Float=0.0`, `low_confidence: bool=False`, `user_feedback: String(20)|None`. **Pas de FK vers `generation_job_id`** ni vers `item_number` → pour avoir `item_number` côté fiche, **jointure** `FlashCard.item_id == Item.id`.
- **`Item`** (`app/models/item.py`) : `college_id FK CASCADE`, `item_number: int`, `rang`, `ocr_text`, `ocr_confidence_score: Float=0.0`, `low_confidence: bool=False`. UniqueConstraint `(college_id, item_number)`.
- **`TesterFeedback`** (`app/models/tester_feedback.py`) : FK `flash_card_id`/`college_id` CASCADE, `tester_id: String(100)`, **`is_pertinent: bool`** (`False` = non pertinent = signal qualité n°1), `created_at`. **Aucune relationship ORM directe** → jointure explicite vers `FlashCard` (comme `get_college_stats` le fait déjà, `admin.py:347-351`). UniqueConstraint `(flash_card_id, tester_id)`.
- **`User`** (`app/models/user.py`) : `id`, `email`, relations `colleges`/`generation_jobs`/`flash_cards` cascade.

### Point de capture exact de `response.usage` (le cœur de T1)

Le pipeline appelle Claude **une fois par Item** dans `card_generator.generate_for_college` → `self._claude.generate_cards_for_item(item)` (`card_generator.py:129`). L'appel API réel est `claude_client.py:102-106` :

```python
response = await self._client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=2000,
    messages=[{"role": "user", "content": prompt}],
)
# ⬅️ CAPTURER ICI, AVANT le try/parse : usage consommé même si le JSON est invalide
# response.usage.input_tokens / response.usage.output_tokens
raw = response.content[0].text.strip()   # le parsing peut lever → mais l'usage est déjà compté
```

**Pièges à éviter :**
- **Ne PAS** capturer l'usage *après* `json.loads(raw)` : si la réponse est mal formée, `generate_cards_for_item` retourne `[]` (`claude_client.py:116-118`) mais les tokens **ont été facturés**. Capturer juste après `messages.create`, avant le bloc `try` de parsing, ou structurer le retour pour que l'usage survive au `except`.
- **`anthropic.APIError`** est re-levé (`claude_client.py:114-115`) → pas de `response`, donc aucun usage à compter pour cet item (le job partira en `failed` via le worker). C'est correct.
- **Contrat de `generate_cards_for_item` :** seul appelant **applicatif** = `card_generator.py:129`. ⚠️ **MAIS des tests existants en dépendent et casseront si tu changes la signature** — à mettre à jour dans le même commit (sinon régression) : `tests/services/test_claude_client.py` (8 appels `cards = await client.generate_cards_for_item(item)`, lignes ~40-118, qui asserts sur une `list`) et `tests/services/test_card_generator.py` (3 `patch.object(..., "generate_cards_for_item", new=AsyncMock(return_value=...))`, lignes ~87-148). Adapter ces tests au nouveau retour (cards + usage). `regenerate_single_card` (flux Story 3.5) garde sa signature **inchangée** (hors périmètre, pas de job).
- **Alternative moins intrusive** (si tu veux éviter de toucher 11 assertions de tests) : laisser `generate_cards_for_item` renvoyer la `list` comme aujourd'hui et exposer l'usage du **dernier appel** via un attribut/retour annexe — déconseillé (état partagé fragile). Préférer le retour explicite `(cards, usage)` + mise à jour des tests.
- **Accumulation :** somme dans une variable locale de la boucle (`card_generator.py:104-146`), écrite sur `job.input_tokens`/`job.output_tokens` juste avant le `commit` de fin (ligne ~148-158). La garde anti-race lit `GenerationJob.status` avant chaque item (D1 de 7.7) — si `failed`, sortie anticipée **sans commit** → l'usage partiel est rollback (acceptable, le job est annulé).

### Schéma usage — pourquoi 2 colonnes cumulées (et pas une table par appel)

Décision : `generation_jobs.input_tokens` + `output_tokens` (Integer nullable). Avantages : agrégation SQL triviale (`sum`), zéro nouvelle table, cohérent avec `card_count` déjà présent. Une table « usage par appel Claude » serait sur-dimensionnée pour le besoin (juger un prompt, pas auditer chaque appel). `NULL` = job non mesuré (antérieur migration / échec avant capture) ≠ `0` = mesuré et gratuit (hash-sharing). Voir Décision PL #1/#2.

### Calcul coût € — fonction pure, jamais stockée

`compute_cost_eur(input_tokens, output_tokens)` dans `app/services/generation/token_cost.py` :

```python
# Tarifs Anthropic claude-sonnet-4-6 (USD / 1M tokens) — vérifiés 2026-06-17
_SONNET_INPUT_USD_PER_MTOK = 3.00
_SONNET_OUTPUT_USD_PER_MTOK = 15.00

def compute_cost_eur(input_tokens: int | None, output_tokens: int | None) -> float:
    it = input_tokens or 0
    ot = output_tokens or 0
    usd = (it * _SONNET_INPUT_USD_PER_MTOK + ot * _SONNET_OUTPUT_USD_PER_MTOK) / 1_000_000
    return round(usd * settings.usd_eur_rate, 4)
```

- **Tout passe par `claude-sonnet-4-6`** : `generate_cards_for_item` et `regenerate_single_card` utilisent Sonnet 4.6 (`claude_client.py:103, 162`). `ask_json` (haiku, tarif différent) n'est PAS dans le flux de génération de fiches → un seul jeu de tarifs suffit pour 7.8.
- Coût **calculé à la lecture**, jamais persisté : un changement de tarif Anthropic ou de `usd_eur_rate` n'invalide pas l'historique des jobs.
- `usd_eur_rate` dans `settings` (défaut ~0.92, surchargeable `.env`). Voir Décision PL #3. ⚠️ La mémoire projet rappelle : **ne jamais écraser le `.env` prod** sur le NAS (`/mnt/user/appdata/compose-stacks/collega/.env`) — ajouter une **valeur par défaut** dans `config.py`, ne pas toucher au `.env`.

### Réutilisation — ne PAS réinventer

- **Jointure feedback** : `get_college_stats` (`admin.py:347-351`) fait déjà `select(TesterFeedback, FlashCard.rang).join(FlashCard, TesterFeedback.flash_card_id == FlashCard.id).where(TesterFeedback.college_id == college_id)`. Reprendre ce pattern pour T2.2 (en sélectionnant aussi recto/verso/card_type).
- **Confiance OCR par item** : `ItemOcrData` (`app/schemas/admin.py:66-69`) existe déjà ; les fiches portent `ocr_confidence_score`/`low_confidence` directement (copiés de l'Item à la génération, `card_generator.py:142-143`).
- **NE PAS modifier** `GET /queue`, `GET /colleges/{id}/stats`, `GET /users/{id}`, `GET /overview` (contrats couverts par tests 1.4/1.5/7.6/7.7). `pertinence_stats` (agrégat) reste dans `/stats` ; 7.8 ajoute la **liste détaillée** des feedbacks via une route séparée.
- Console web : helpers `apiFetch`, `readJson`, `escapeHtml`, `fmtDate`, `statusBadge`, `showSection`, `toast`, `handleUnauthorized` existent dans `app/static/admin/index.html`. Réutiliser tel quel.

### Frontend — patterns à calquer (admin/index.html, Story 7.6/7.7)

- Navigation : `showSection(id)` + onglets `nav-tabs` (un `<section id="...">` par écran, `.active` pour l'affichage). Ajouter les onglets « Qualité » et « Coût » à la barre.
- Chargement : loader visible → `apiFetch(path)` → `readJson(res)` → `{ data }` → rendu → masquer loader. **Catch `e.code === "unauthorized"` et `return`** (UI déjà basculée sur login).
- Tableaux : `<tr>` via `innerHTML`, **toujours `escapeHtml`** sur recto/verso/email/tester_id (texte user, risque XSS — cf. fix XSS email review 7.6).
- Coût : formater `€` côté front (`toFixed(4)` ou similaire) ; tokens en nombre brut.
- Palette : vert `#1b6b3a`, badges `.badge-green`/`.badge-red`/`.badge-grey`, boutons `.btn-primary`/`.btn-sm`/`.btn-link`, `.toast`/`.toast.error`.

### Pattern de tests (rappels 7.6/7.7, vérifiés)

- pytest + pytest-asyncio `asyncio_mode = "auto"` → juste `async def test_...`, pas de décorateur.
- Fixtures **globales** `tests/conftest.py` : `client` (httpx `AsyncClient` + `ASGITransport`, override `get_db`), `mock_db` (`AsyncMock`). NE PAS recréer de conftest.
- Auth : `auth=("admin", "testpass")`. 401 = appel sans `auth=`.
- Modèles simulés : `types.SimpleNamespace(...)`. `db.get` → `AsyncMock(return_value=...)`. `db.execute` → `AsyncMock(return_value=MagicMock(...))` exposant `scalars().all()`/`scalar_one_or_none()`/`all()`/`first()` selon l'appel ; pour des `db.execute` séquentiels, `side_effect=[r1, r2, ...]` (cf. `test_admin_user_detail._scalars_result`, `test_admin_college_stats.stats_side_effects`).
- Test capture usage (T4.1) : mocker `ClaudeClient.generate_cards_for_item` pour renvoyer `(cards, in_tok, out_tok)` et vérifier `job.input_tokens`/`output_tokens` après `generate_for_college` ; ne PAS toucher un vrai Redis/Anthropic.
- **0 régression.** Échecs **pré-existants connus** (~16 tests rouges) nécessitant Redis local (`test_search`/`test_reminder`/`test_flash_cards`/`test_login`) ou `test_auth` register stale — identiques avec/sans les changements. Ne pas les « réparer » ici.

### Piège environnement (mémoire projet)

Le `.venv` local doit résoudre **`bcrypt >=3.2.0,<4.0.0`** (passlib 1.7.4 crashe sinon) ; `pyproject.toml` épingle déjà la contrainte. Les tests admin importent `app.core.security` → vérifier le venv si `hash_password` plante.

### Project Structure Notes

**Fichiers à créer (NEW) :**
```
collega_backend/
├── app/services/generation/token_cost.py                      ← compute_cost_eur (NEW)
├── alembic/versions/014_add_token_usage_to_generation_jobs.py ← migration (NEW, down_revision=013)
└── tests/
    ├── services/test_token_usage_capture.py                   ← NEW
    ├── services/test_token_cost.py                            ← NEW
    ├── api/test_admin_college_cards.py                        ← NEW
    ├── api/test_admin_college_feedback.py                     ← NEW
    └── api/test_admin_usage.py                                ← NEW
```

**Fichiers à modifier (UPDATE) :**
| Fichier | Modification |
|---------|-------------|
| `app/models/generation_job.py` | + colonnes `input_tokens` / `output_tokens` (Integer, nullable) |
| `app/services/generation/claude_client.py` | `generate_cards_for_item` remonte l'usage (signature → cards + tokens) ; capture AVANT parsing |
| `app/services/generation/card_generator.py` | accumule l'usage dans la boucle + écrit `job.input_tokens/output_tokens` (génération + branche hash-sharing=0/0) |
| `app/api/v1/admin.py` | + 3 routes (`/colleges/{id}/cards`, `/colleges/{id}/feedback`, `/usage`) + champs usage sur `get_job_detail` |
| `app/schemas/admin.py` | + schémas cards/feedback/usage + champs usage sur `JobDetailData` |
| `app/core/config.py` | + `usd_eur_rate: float` (défaut ~0.92) |
| `app/static/admin/index.html` | + onglets/écrans « Qualité » & « Coût » + coût/import dans détail job |

**Conventions :** wrapper `{ "data": ... }` ; `HTTPException(detail={"code","message"})` ; snake_case DB/JSON ; `logger` jamais `print()` ; ISO 8601 UTC ; imports SQLAlchemy au niveau module ; frontend vanilla (pas de build).

### Library / Framework

- Backend : FastAPI, SQLAlchemy 2.0 async (`func.sum`, `func.coalesce`, `select(...).join(...).group_by(...)`), Pydantic v2, Alembic, pytest/pytest-asyncio, httpx (tests). **Aucune nouvelle dépendance.** SDK `anthropic` déjà présent (`response.usage.input_tokens`/`output_tokens` exposés par `messages.create`).
- Frontend : HTML/CSS/JS vanilla servi par `StaticFiles` (pas de framework, pas de build).
- Modèle de génération : `claude-sonnet-4-6` ($3/1M input, $15/1M output — tarifs vérifiés 2026-06-17). `response.usage` (`input_tokens`/`output_tokens`) est renseigné par le SDK sur chaque `messages.create`.

### Previous Story Intelligence (7.7 + 7.6 + 7.2 + 1.4/1.5)

- **7.7** (done) a livré l'instrumentation pipeline (events timeline via `record_job_event`, garde anti-race Stop↔worker lisant `GenerationJob.status` avant chaque item), `GET /jobs/{id}` (à étendre ici), et a déplacé `generation_started` à l'entrée de `generate_for_college` pour couvrir le hash-sharing. La migration **head réelle est 013** → chaîner depuis 013. Garde anti-race : la sortie anticipée `status=="failed"` **ne commit pas** → cohérent avec l'écriture d'usage avant commit.
- **7.6** (done) a posé le socle console (auth Basic, schémas wrappés, helpers JS robustes, fix XSS email escapé). Auth Basic en mémoire JS = risque accepté pour la beta (Story 7.9 différée post-beta).
- **7.2** a posé l'atomicité quota + l'index UNIQUE partiel (migration 012). Le hash-sharing **compense** le quota et n'appelle pas Claude → usage 0/0. Ne pas re-toucher la logique quota.
- **1.5** a posé `TesterFeedback` (`is_pertinent`) et son agrégat `pertinence_stats` dans `/stats`. 7.8 ajoute la **liste détaillée** (route séparée), sans modifier `/stats`.

### Git Intelligence

Epic 7 suit le pattern `feat(story-7.x): … + review-fix`. Dernier commit : `268c753 feat(story-7.7): dashboard admin thème B (suivi/contrôle imports) + review-fix`. 7.8 = thème C, additif, à committer seul. Ne pas emporter de fichiers Flutter/`colleges.py` non liés s'ils traînent dans le working tree.

### References

- Périmètre & ACs : `_bmad-output/planning-artifacts/epics-v1.1.md#story-78` (lignes 430-459) ; cadrage Dashboard Admin (lignes 355-359).
- Source de périmètre : `_bmad-output/brainstorming/brainstorming-session-2026-06-16-2242.md`.
- Pipeline génération : `collega_backend/app/services/generation/claude_client.py:88-130` (capture), `card_generator.py:27-165` (accumulation).
- Modèle job : `collega_backend/app/models/generation_job.py`. Migration de référence : `collega_backend/alembic/versions/013_add_generation_job_events.py`.
- Endpoints admin de référence : `collega_backend/app/api/v1/admin.py:299-385` (stats+jointure feedback), `:622-689` (job detail à étendre).
- Schémas : `collega_backend/app/schemas/admin.py`. Auth : `collega_backend/app/deps.py:18`. Config : `collega_backend/app/core/config.py`.
- Console web : `collega_backend/app/static/admin/index.html` (montée à `/admin`, `main.py:102`).
- Tarifs Anthropic Sonnet 4.6 : $3.00/1M input, $15.00/1M output (réf. claude-api, 2026-06-17).

## Décisions Project Lead (ACTÉES 2026-06-17 au kick-off)

> Les 4 décisions sont tranchées. À implémenter telles quelles — pas de zone d'ombre.

1. **Schéma de persistance usage → ✅ 2 colonnes cumulées.** `input_tokens`/`output_tokens` sur `generation_jobs` (migration 014). Pas de table par appel. Agrégation SQL via `SUM`.
2. **Sémantique hash-sharing / jobs anciens → ✅ 0 pour hash-sharing, NULL pour le legacy.** Hash-sharing (Claude non appelé) = `0/0` (gratuit explicite) ; jobs antérieurs à la migration = `NULL` (non mesuré). Les agrégats comptent `NULL` comme 0 (`func.coalesce(..., 0)`).
3. **Coût → ✅ € avec taux configurable.** `cost_eur` calculé à la lecture via tarifs Sonnet 4.6 ($3/$15 par MTok) × `settings.usd_eur_rate` (défaut ~0.92 **dans `config.py`** — ⚠️ ne PAS toucher le `.env` prod NAS). Pas d'affichage USD.
4. **Périmètre de capture → ✅ génération de fiches uniquement.** Capturer l'usage seulement sur `generate_cards_for_item` (Sonnet, dans un `GenerationJob`). `regenerate_single_card` (flux feedback Story 3.5, hors job) et `ask_json` (haiku) restent **non instrumentés** — signature de `regenerate_single_card` inchangée.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Claude Opus 4.8, 1M context) — via bmad-dev-story workflow, TDD red-green-refactor.

### Debug Log References

- Baseline pré-implémentation : `test_card_generator`/`test_claude_client`/`test_admin_job_detail` verts (14 passed).
- Suite complète post-implémentation : **313 passed, 1 skipped, 16 failed**. Les 16 rouges sont **pré-existants et infra-only** (`ConnectionRefusedError` Redis localhost:6379 via le middleware rate-limiter slowapi) : `test_auth` (register/login/get_current_user/delete_account), `test_flash_cards`, `test_reminder`, `test_search`. Identiques avec/sans les changements 7.8 — confirmé en inspectant la stacktrace (échec dans `limits/storage/redis.py:incr`, avant le handler). Aucune régression introduite.
- Migration : chaîne 012→013→**014** validée, `014` est le seul fichier chaînant depuis `013` (pas de branche). Alembic CLI/ruff non installés dans le `.venv` local → validation AST + grep de la chaîne à la place.

### Completion Notes List

**T1 — Persistance usage (NEW DB + capture pipeline)**
- `GenerationJob` : + `input_tokens` / `output_tokens` (`Integer`, nullable). NULL = non mesuré, 0 = mesuré gratuit (hash-sharing). Migration `014` additive (add_column ×2, downgrade drop ×2).
- `claude_client.generate_cards_for_item` : retourne désormais un `CardGenResult(cards, input_tokens, output_tokens)`. L'usage est capturé **juste après `messages.create`, AVANT le parsing** → il survit à un JSON invalide (`cards=[]` mais tokens comptés). `messages.create` sorti du `try` → `anthropic.APIError` se propage naturellement (aucun usage à compter, le worker marquera `failed`).
- `card_generator.generate_for_college` : accumule l'usage dans la boucle items (même si 0 fiche), écrit `job.input_tokens/output_tokens` avant le commit final ; branche hash-sharing fixée à `0/0` avant son commit.

**T2 — Endpoints**
- `GET /colleges/{id}/cards` (jointure `FlashCard`↔`Item` pour `item_number`), `GET /colleges/{id}/feedback` (pattern de jointure repris de `get_college_stats`), `GET /usage` (global via `func.coalesce(func.sum(...), 0)` + ventilation par user `group_by`). Coût € via `compute_cost_eur` (fonction **pure**, jamais persistée, tarifs Sonnet 4.6 $3/$15 × `settings.usd_eur_rate`).
- `GET /jobs/{id}` étendu (additif) : `input_tokens`/`output_tokens`/`cost_eur`. Toutes les routes sous `Depends(get_admin_user)` (401 testé). `usd_eur_rate=0.92` ajouté **dans `config.py`** (pas dans le `.env` prod NAS, cf. mémoire projet).

**T3 — Console web**
- Onglets « Qualité » & « Coût » ajoutés à toutes les barres `nav-tabs` + 2 nouvelles `<section>`. Qualité : saisie `college_id` → fiches (recto/verso/type/rang/confiance OCR) + feedbacks (badge pertinent/non-pertinent + fiche). Coût : KPI global (€/tokens) + tableau par user, et coût/import affiché dans le détail job existant. Helpers réutilisés (`apiFetch`/`readJson`/`escapeHtml`/`fmtDate`/`statusBadge`/`toast`/`showSection`) ; `escapeHtml` systématique sur recto/verso/email/tester_id (XSS). Catch `e.code === "unauthorized"` partout.

**Décisions PL respectées** : (1) 2 colonnes cumulées, (2) hash-sharing=0/0 vs legacy=NULL comptés 0 via coalesce, (3) € avec taux configurable côté `config.py`, (4) capture limitée à `generate_cards_for_item` (`regenerate_single_card`/`ask_json` non instrumentés, signatures inchangées).

### File List

**Créés (NEW)**
- `collega_backend/app/services/generation/token_cost.py`
- `collega_backend/alembic/versions/014_add_token_usage_to_generation_jobs.py`
- `collega_backend/tests/services/test_token_cost.py`
- `collega_backend/tests/services/test_token_usage_capture.py`
- `collega_backend/tests/api/test_admin_college_cards.py`
- `collega_backend/tests/api/test_admin_college_feedback.py`
- `collega_backend/tests/api/test_admin_usage.py`

**Modifiés (UPDATE)**
- `collega_backend/app/models/generation_job.py` (+ `input_tokens`/`output_tokens`)
- `collega_backend/app/services/generation/claude_client.py` (+ `CardGenResult`, capture usage avant parsing)
- `collega_backend/app/services/generation/card_generator.py` (accumulation + écriture usage, hash-sharing 0/0)
- `collega_backend/app/api/v1/admin.py` (+ 3 routes, + usage sur `get_job_detail`, imports)
- `collega_backend/app/schemas/admin.py` (+ schémas cards/feedback/usage, + champs usage `JobDetailData`)
- `collega_backend/app/core/config.py` (+ `usd_eur_rate: float = 0.92`)
- `collega_backend/app/static/admin/index.html` (onglets/écrans Qualité & Coût, coût/import dans détail job)
- `collega_backend/tests/services/test_claude_client.py` (adaptés au retour `CardGenResult` + assertions usage)
- `collega_backend/tests/services/test_card_generator.py` (adaptés au retour `CardGenResult` + assertions usage)
- `collega_backend/tests/api/test_admin_job_detail.py` (+ usage sur `make_job` + assertion coût)

## Change Log

| Date | Version | Description |
|------|---------|-------------|
| 2026-06-17 | 0.1 | Story 7.8 créée et passée ready-for-dev via bmad-create-story. Périmètre : NEW colonnes `input_tokens`/`output_tokens` sur `generation_jobs` (migration 014) + capture `response.usage` dans le pipeline génération (claude_client → card_generator → job), `GET /colleges/{id}/cards` (inspection fiches), `GET /colleges/{id}/feedback` (TesterFeedback joints au contenu), `GET /usage` (agrégat tokens+€ global/user), extension `GET /jobs/{id}` (coût/import), `compute_cost_eur` (tarifs Sonnet 4.6 + taux €/$ configurable), écrans web Qualité & Coût. 4 décisions PL à acter au kick-off. Pont d'évaluation du prompt persona (Story 7.5, gated sur 7.6+7.7+7.8 done). |
| 2026-06-18 | 1.0 | Implémentation complète via bmad-dev-story (TDD). T1–T4 livrés : migration 014 + capture usage pipeline (capture AVANT parsing, hash-sharing 0/0), 3 routes admin (`/cards`, `/feedback`, `/usage`) + extension `/jobs/{id}`, `compute_cost_eur` pure (taux dans `config.py`), onglets web Qualité & Coût. 33 nouveaux/adaptés tests verts. Suite : 313 passed / 16 rouges pré-existants (Redis local). Statut → review. |

## Review Findings

> Code review adversariale (bmad-code-review, 2026-06-18) : 3 couches (Blind Hunter / Edge Case Hunter / Acceptance Auditor). 1 decision-needed, 2 patch, 1 defer, ~14 dismissed (faux positifs neutralisés par invariants schéma : FK CASCADE non-null, garanties SDK non-streaming, décisions PL documentées).

- [x] [Review][Decision] `/usage` — ventilation par user sans les users 0-job (INNER JOIN). **Tranché PL 2026-06-18 : garder INNER JOIN (consommateurs seuls).** Comportement voulu pour un tableau de coût ; aucune divergence des totaux. → dismissed, pas de patch. [admin.py:910-920]
- [x] [Review][Patch] **APPLIQUÉ** — `generate_cards_for_item` : `AttributeError` ajouté au tuple `except` → un bloc non-texte (refus/thinking) dégrade en `cards=[]` avec usage préservé au lieu de crasher l'item. [claude_client.py:134]
- [x] [Review][Patch] **APPLIQUÉ** — Front `loadQuality` : les fiches sont rendues dès leur chargement ; un échec/404 sur `/feedback` n'efface plus les fiches et affiche un toast dédié (404 → « Collège introuvable — feedback indisponible »). [index.html:889-906]
- [x] [Review][Defer] `generate_cards_for_item` : `max_tokens=2000` sans vérif de `response.stop_reason` → une réponse tronquée produit un JSON invalide → `cards=[]` silencieux alors que les tokens sont facturés, sans signal admin. Pré-existant (le `max_tokens` précède la story 7.8), hors périmètre. [claude_client.py:118,127] — deferred, pre-existing

**Limitation connue acceptée (non bloquante, documentée Dev Notes §capture) :** un job annulé via `POST /jobs/{id}/stop` ne commit pas l'usage partiel des items déjà générés (rollback) → le job reste « non mesuré » alors que des tokens ont pu être facturés. Comportement voulu (« acceptable, le job est annulé »).

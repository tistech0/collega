# Chantier 1 — Fiabilité des imports : spécification

Date : 2026-09-23 · Statut : validée section par section avec l'utilisateur, en relecture · Branche : `feat/chantier-1-fiabilite-imports`
Contexte : `_bmad-output/planning-artifacts/audit-back-infra-2026-09-23.md` (constats 1, 2, 4, 6, 7 et « Fonctionnalités cassées »).

## 1. Problème

Aujourd'hui un réimport :
- supprime items et fiches à la fin de l'OCR (`ocr_worker.py:218`, cascade vers `flash_cards`) **avant** la génération : si elle échoue ou est stoppée, le contenu est perdu ;
- met le collège en `processing` : l'app le retire de la session du jour et affiche « Les fiches arrivent » alors que l'ancien contenu est sur le téléphone ;
- régénère toutes les fiches (nouveaux UUID) : la progression locale du collège repart de zéro ;
- repaie Claude intégralement à chaque relance ARQ ou redéploiement (une transaction pour toute la génération).

S'y ajoutent : jobs bloqués sans purge, session SSE gardée 3 h, PDF jamais supprimés (même à la suppression de compte), régénération impossible après 24 h (texte OCR purgé), hash-sharing qui copie l'état courant des fiches d'une autre utilisatrice, `alembic check` en échec, PDF endommagé signalé comme « vide ».

## 2. Décisions (validées)

| # | Décision |
|---|---|
| D1 | Un réimport ne régénère **que les items dont le contenu a changé** ; les items inchangés gardent fiches, identifiants et progression. |
| D2 | Le texte OCR est **conservé indéfiniment** avec le collège (le PDF l'est déjà) ; stockage **par page, adressé par empreinte** (pas de doublon). NFR9 (purge à 24 h) est abandonnée. |
| D3 | La décision « régénérer ou garder » se prend **par item**, sur une **empreinte normalisée** du texte de l'item (pas par page : les pages se décalent). |
| D4 | Partage entre utilisatrices **par item**, et uniquement de la **sortie d'origine de Claude** ; jamais les fiches régénérées, modifiées ou supprimées par quelqu'un. |
| D5 | Clé d'une génération = **(empreinte d'item, version de génération)** ; changer de modèle ou de prompt produit de nouvelles générations. |
| D6 | Architecture « brouillon puis bascule » : tables de contenu adressées par empreinte + brouillon par job + bascule en **une transaction** verrouillée et rejouable. |
| D7 | Statut du **collège** = son contenu ; statut de l'**import** = le job. Pendant un réimport le collège reste `generation_complete`. |
| D8 | Quota de réimport **rendu** si l'import n'a fait **aucun** appel à Claude. |
| D9 | Notifications : échec d'un réimport (« tes fiches actuelles sont intactes ») et résumé du succès (modifiés / nouveaux / supprimés / inchangés, ou « aucun changement, non décompté »). Codées comme si la clé APNs existait (elle sera ajoutée plus tard). |
| D10 | Petit changement app inclus : l'écran d'import affiche le résumé et le message d'échec d'un réimport. |
| D11 | PDF conservé tant que le collège existe (politique de confidentialité) ; ancien PDF supprimé à la bascule ; tout supprimé avec le collège ou le compte. |
| D12 | Les 3 collèges en prod sont **remplis** (pages, textes, empreintes) depuis leurs PDF conservés, sans Claude et sans toucher aux fiches. |

Mesure préalable (spike du 2026-09-23, PNEUMO 355 p. et CANCERO 436 p., 2 passes OCR chacun) : pages 100 % identiques entre passes, empreintes d'items 100 % identiques ; les textes d'items contiennent jusqu'à 23 lignes de numéros de page imprimés → normalisation indispensable ; 19 pages en double dans CANCERO.

## 3. Hors périmètre

Génération parallèle, Batch API, allègement du texte envoyé à Claude, choix du modèle (chantier 4) ; réparation automatique des PDF endommagés ; annulation d'un réimport ; saut de l'OCR des pages identiques (hash du contenu brut) ; refonte de `colleges.py`/`admin.py` (chantier 5).

## 4. Modèle de données

### Tables de contenu (adressées par empreinte, partagées)

**`ocr_pages`** — une page extraite
- `hash` CHAR(64) PK — SHA-256 du texte brut de la page
- `text` TEXT, `tables_json` TEXT (tableaux pdfplumber), `confidence` FLOAT, `method` VARCHAR(20)
- `created_at`

**`item_texts`** — le texte d'un item tel qu'envoyé à Claude
- `hash` CHAR(64) PK — SHA-256 du texte **normalisé** (§5)
- `text` TEXT (texte brut, non normalisé), `created_at`

**`item_generations`** — sortie d'origine de Claude
- `id` UUID PK
- `text_hash` CHAR(64) FK → `item_texts.hash`
- `generation_version` VARCHAR(100) — ex. `claude-sonnet-4-6:p1` (modèle + version du prompt, constante dans `claude_client.py`)
- `cards_json` TEXT — liste `{card_type, recto, verso}`
- `model` VARCHAR(100), `input_tokens` INT, `output_tokens` INT, `created_at`
- UNIQUE (`text_hash`, `generation_version`)
- Une réponse Claude non exploitable (0 fiche) n'est **pas** enregistrée : l'item sera retenté au prochain import. Ses tokens sont comptés sur le job.

### Tables liées à un import ou à un collège

**`job_pages`** — reprise de l'OCR (vidée en fin de job)
- (`job_id` FK cascade, `page_number`) PK, `page_hash` FK → `ocr_pages.hash`

**`job_items`** — brouillon de détection (vidé en fin de job)
- (`job_id` FK cascade, `item_number`) PK
- `rang`, `chapter_title`, `start_page`, `end_page`, `ocr_confidence_score`, `low_confidence`, `text_hash` FK → `item_texts.hash`
- `generation_id` FK → `item_generations.id` NULL (rempli par la génération)

**`college_pages`** — pages en service du collège (écrites à la bascule)
- (`college_id` FK cascade, `page_number`) PK, `page_hash` FK → `ocr_pages.hash`

### Tables modifiées

- **`items`** : + `text_hash` CHAR(64) NULL FK → `item_texts.hash` ; − `ocr_text`.
- **`flash_cards`** : + `generation_id` UUID NULL FK → `item_generations.id` (NULL = ancienne fiche ou fiche régénérée par l'utilisatrice).
- **`generation_jobs`** : − `page_texts_json` ; + `summary_json` TEXT NULL (résumé de la bascule, §6.5) ; `pdf_hash` conservé à titre informatif (toujours calculé, affiché par l'admin), n'est plus utilisé pour le partage ; `hash_shared` conservé et redéfini : `true` si le job n'a fait **aucun** appel Claude (tout réutilisé). La console admin (« Hash partagé ») n'a pas à changer.
- Code retiré : `services/generation/hash_sharing.py` (partage par PDF entier), `_copy_cards_for_hash_sharing`, champ `ocr_text` du schéma inutilisé `ItemCreate`, cron `cleanup_ocr_text`.

### Alignement modèles ↔ migrations

Les modèles SQLAlchemy déclarent tout ce qui n'existait que dans les migrations : index unique partiel « un job actif par collège » (`idx_one_active_job_per_college`), `uq_colleges_user_ref_id`, index GIN plein texte (`idx_flash_cards_fts`), unicité `users.email`, `card_count` non nul. L'index doublon `ix_generation_jobs_unique_active` est supprimé. Critère : `alembic check` ne détecte **aucune** opération sur une base à `head`.

## 5. Empreintes et normalisation

- Empreinte de page : SHA-256 du texte brut extrait.
- Empreinte d'item : SHA-256 du texte **normalisé** :
  1. espaces et tabulations consécutifs → un espace, lignes rognées ;
  2. suppression des lignes vides ;
  3. suppression des lignes qui ne sont qu'un numéro de page (`^\s*(page\s*)?\d+(\s*(/|sur)\s*\d+)?\s*$`, insensible à la casse).
- La normalisation n'altère jamais le texte stocké ni envoyé à Claude : elle ne sert qu'au calcul de l'empreinte.
- Test de non-régression : même PDF → mêmes empreintes ; lignes de numéro de page modifiées → même empreinte.

## 6. Pipeline

### 6.1 Réception (routes inchangées)

- Après écriture du PDF (import direct, ou assemblage pour l'upload par morceaux) et **avant** toute consommation de quota ou création de job : ouverture du PDF et lecture du nombre de pages (thread). Échec ou 0 page → **422 `PDF_DAMAGED`** (« Ce PDF est endommagé : il ne s'ouvre pas. Réessaie avec une autre copie. »), PDF supprimé.
- Le reste est inchangé (gardes, quota, création du job, enqueue).

### 6.2 OCR (`process_college_ocr`)

- Pages déjà présentes dans `job_pages` = faites (reprise). Pour chaque page restante : extraction, empreinte, `INSERT … ON CONFLICT DO NOTHING` dans `ocr_pages`, insertion `job_pages`, avancement (`ocr_page_progress`), commit par page. Événements de timeline inchangés.
- Vérification d'arrêt avant chaque page : job passé à `failed` (Stop) **ou supprimé** → sortie sans erreur.

### 6.3 Détection

- Détection sur les pages du job (textes, scores et tableaux relus depuis `ocr_pages`), dédoublonnage par numéro inchangé, résolution du titre inchangée (référentiel `item_titles`).
- Pour chaque item : empreinte normalisée, `item_texts` (ON CONFLICT DO NOTHING), ligne `job_items`.
- **Aucune écriture** dans `items` ni `flash_cards`. Le job passe à `ocr_complete`, la génération est mise en file (comme aujourd'hui).

### 6.4 Génération (`generate_college_cards`)

Pour chaque `job_items` sans `generation_id` :
1. vérification d'arrêt (Stop ou job supprimé) ;
2. génération existante pour (`text_hash`, version courante) ? → réutilisée (item inchangé, partagé, ou déjà fait lors d'une tentative précédente) ;
3. sinon appel Claude ; si des fiches sont obtenues : insertion `item_generations` (ON CONFLICT DO NOTHING puis relecture, en cas de course avec un autre import) ;
4. `job_items.generation_id` renseigné, **tokens ajoutés au job**, avancement publié, **commit par item**.

Aucune transaction n'est gardée ouverte pendant un appel Claude. Puis bascule (6.5) dans la même tâche.

### 6.5 Bascule (une transaction)

1. `SELECT … FOR UPDATE` sur le collège ; si le job n'est plus `ocr_complete` (déjà basculé, stoppé) → fin sans rien faire (rejouable).
2. Rapprochement `job_items` ↔ `items` du collège par `item_number` :
   - **inchangé** (même `text_hash`) : métadonnées mises à jour (pages, titre, rang, confiance) ; **fiches intactes** (y compris régénérées, pouces, supprimées) ;
   - **modifié** : item mis à jour **en gardant son `id`** ; ses fiches supprimées ; nouvelles fiches créées depuis la génération (`generation_id` renseigné, `user_id` = propriétaire du collège) ;
   - **nouveau** : item créé avec ses fiches ;
   - **disparu** : item supprimé (fiches en cascade) ;
   - un item sans génération (Claude n'a rien renvoyé) est publié sans fiche, comme aujourd'hui.
3. `college_pages` remplacées par les `job_pages` du job ; `job_pages` et `job_items` du job supprimés.
4. Quota : réimport et **0 appel Claude** → `reload_count` et `monthly_reloads` décrémentés (UPDATE conditionnels `> 0`, logique actuelle déplacée).
5. `summary_json` = `{changed, added, removed, unchanged, cards, claude_calls, quota_refunded}` ; job `generation_complete`, `card_count` = total des fiches du collège ; collège `generation_complete` ; événement `generation_complete` avec le résumé.
6. Après commit : suppression des **anciens** PDF du collège (tous les `{college_id}_*.pdf` sauf celui du job) ; notification push (§8).

## 7. Statuts et contrat d'API

- **`College.status`** (renvoyé par `GET /v1/colleges`) : `pending` → `processing`/`ocr_complete` pendant le **premier** import → `generation_complete`. Il ne change plus pendant un réimport. `failed` uniquement si le **premier** import échoue.
- **`GET /v1/colleges/{id}/status`** : même forme de réponse qu'aujourd'hui ; `status` est celui du **dernier job** (ou celui du collège s'il n'y a pas de job). Les champs d'avancement restent ceux du collège.
- **SSE `/stream`** : suit le statut du **dernier job** ; `generation_complete` porte `summary` ; `generation_failed` porte `message` et `reimport` (booléen). La session de la dépendance est rendue avant le début du flux (la vérification d'accès se fait dans une session courte).
- **`/items`, `/cards`, `/items/{id}/cards`** : servent le contenu publié dès que le collège est `generation_complete` — donc aussi pendant un réimport.

## 8. Notifications

- `send_generation_complete(token, ref_id, summary)` : texte adapté — « 3 items mis à jour, 1 nouveau, 20 inchangés » ; « Aucun changement dans ce PDF — ton réimport n'a pas été décompté » si rien n'a changé ; texte actuel pour un premier import.
- `send_import_failed(token, ref_id, reimport)` : réimport → « Le réimport de {nom} n'a pas abouti. Tes fiches actuelles sont intactes. » ; premier import → « L'import de {nom} n'a pas abouti. Relance-le depuis l'app. »
- Les erreurs APNs ne font jamais échouer un job (comme aujourd'hui). Sans clé APNs (`NullNotificationService`), rien ne part : comportement testé, activation à l'ajout de la clé.

## 9. Échecs, arrêts, jobs bloqués

- **Erreur** (exception : Claude en erreur, PDF illisible, base…) : les deux workers passent l'import en échec via `fail_job` (nouvelle session) : job `failed` + `error_message` + événement, `job_pages`/`job_items` du job supprimés, PDF du job supprimé, notification d'échec ; collège `failed` seulement s'il n'avait pas de contenu. L'exception est relancée pour ARQ.
- **Interruption** (`CancelledError` : redéploiement, arrêt du worker) : l'import reste **actif** ; ARQ (`retry_jobs=True`) le relance au redémarrage — reprise OCR depuis `job_pages`, générations réutilisées, bascule rejouable → **aucun appel Claude repayé et aucun quota reconsommé**. (Décision prise à l'implémentation : échouer sur interruption obligeait l'utilisatrice à relancer — et à consommer un réimport — à chaque redéploiement.)
- **Timeout ARQ** (2 h) ou job jamais repris : ARQ abandonne le job, qui reste actif en base → le cron `fail_stale_jobs` le passe en échec. `max_tries=3` inchangé.
- **Cron `fail_stale_jobs`** (toutes les 10 min) : job `pending`/`processing`/`ocr_complete` dont le dernier événement de timeline (ou `updated_at`) date de **plus de 30 min** et absent de `arq:in-progress:*` → même traitement qu'un échec, événement `failed` « import bloqué ».
- Stop admin : inchangé côté admin ; le contenu en service n'est plus touché.

## 10. Purges et conservation

- **PDF** : voir 6.5 (ancien PDF à la bascule) et §9 (PDF d'un import échoué). Suppression de collège (admin) et de **compte** : suppression immédiate des `{college_id}_*.pdf`. Cron quotidien : PDF sans collège ni job actif, `incoming_*` de plus de 24 h.
- **`purge_unreferenced_content`** (appelée à la suppression d'un compte et d'un collège, et chaque nuit) :
  - `ocr_pages` non référencées par `job_pages` ni `college_pages` ;
  - `item_generations` non référencées par `flash_cards` ni `job_items`, et dont le `text_hash` n'est plus référencé par aucun `items`/`job_items` ;
  - `item_texts` non référencés par `items`, `job_items` ni `item_generations`.
  Ce qui sert encore à une autre utilisatrice est conservé.
- Le cron `cleanup_ocr_text` (NFR9) est supprimé.

## 11. Régénération d'une fiche

`regenerate_single_card` lit le texte dans `item_texts` via `items.text_hash`. Item sans empreinte (ne devrait plus exister après le remplissage) → 409 `SOURCE_UNAVAILABLE` explicite au lieu d'un 503. Fiche régénérée : `generation_id` → NULL (plus d'origine, jamais partagée).

## 12. Remplissage des collèges existants (commande unique)

`python -m scripts.backfill_content_store [--dry-run] [--college <id>]`, lancée sur le NAS après la migration :
- PDF en service du collège = PDF de son dernier job `generation_complete` ;
- OCR de toutes les pages → `ocr_pages` + `college_pages` ; détection → `item_texts` ;
- pour chaque item détecté dont le `item_number` existe dans `items` : `items.text_hash` renseigné ;
- ne crée ni ne supprime aucun item ni aucune fiche, ne crée aucune `item_generations` ; affiche un rapport (items rapprochés, non rapprochés).
- Idempotente.

## 13. Changements côté app

- Écran de progression d'import : à `generation_complete`, afficher le résumé s'il est présent (« 3 items mis à jour · 1 nouveau · 20 inchangés », ou « Aucun changement dans ce PDF — réimport non décompté ») ; à `generation_failed` avec `reimport: true`, afficher « Le réimport n'a pas abouti. Tes fiches actuelles sont intactes. »
- Aucun autre changement : le collège restant `generation_complete` pendant un réimport, bibliothèque, détail et session du jour fonctionnent tels quels ; les fiches des items inchangés gardent leur identifiant, donc la synchro locale conserve leur progression.

## 14. Documentation

- `architecture.md` : NFR9 remplacée (« texte OCR conservé avec le collège, supprimé avec lui »), stockage par empreinte.
- `collega_app/assets/legal/privacy.md` : ligne « Texte extrait des PDF : conservé avec le collège, supprimé avec lui » ; suppression de compte inchangée (immédiate pour tout ce qui n'appartient qu'au compte).
- `collega_backend/docs/restore.md` : nouvelles tables à vérifier après restauration.

## 15. Tests

**Backend — Postgres réel** (conteneur local sur `127.0.0.1`, commande documentée ; les tests concernés échouent avec un message explicite si le serveur n'est pas lancé). Les limites de débit passent en stockage mémoire pendant les tests (plus de dépendance au Redis local).

Scénarios :
1. normalisation et stabilité des empreintes ;
2. OCR : stockage par page, pages en double stockées une fois, reprise après interruption ;
3. bascule : inchangé / modifié / nouveau / disparu ; fiches régénérées et supprimées conservées sur un item inchangé ; identifiants stables ; `college_pages` ;
4. réimport du même PDF : 0 appel Claude, quota rendu, résumé « aucun changement » ;
5. partage entre deux utilisatrices : seule la sortie d'origine est copiée ;
6. changement de `generation_version` : nouvelle génération ;
7. échecs : erreur Claude à mi-parcours puis relance sans repayer les items faits ; `CancelledError` ; Stop admin ; compte supprimé pendant l'import ; contenu en service intact dans tous les cas ; premier import échoué → collège `failed` ;
8. `fail_stale_jobs` ;
9. purges : contenu partagé conservé, orphelins supprimés, suppression de compte (base + fichiers PDF) ;
10. SSE : session rendue, statut du job, résumé, arrêt sur échec ;
11. PDF endommagé → 422 `PDF_DAMAGED`, aucun quota ni job (le vrai ANAPATH endommagé sert de cas réel en test manuel) ;
12. `/status` et `/items` pendant un réimport ;
13. régénération après remplissage ;
14. `alembic check` sans différence ; migration montante puis descendante ;
15. commande de remplissage (dry-run et réel) sur une base de test.

**App** : écran d'import (résumé, aucun changement, échec de réimport).

## 16. Déploiement

1. Suite backend et tests app verts ; image construite et vérifiée.
2. Aucun job en cours (runbook) ; **dump de la base** juste avant.
3. `compose pull` + `up -d` : migration, api et worker `healthy`, `/health` OK.
4. `backfill_content_store --dry-run`, puis réel ; vérification des empreintes renseignées sur les 3 collèges.
5. Validation sur l'iPhone : réimport de PNEUMO (même fichier) → « Aucun changement », 0 token dans la console admin, quota non décompté, progression PNEUMO intacte.
6. Retour arrière : `alembic downgrade` (la migration descendante recrée `ocr_text` et `page_texts_json` vides) ou restauration du dump de l'étape 2.

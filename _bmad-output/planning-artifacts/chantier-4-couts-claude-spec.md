# Chantier 4 — Génération des fiches (qualité et coûts Claude) : spécification

Date : 2026-09-24 · Statut : validée avec l'utilisateur · Branche : `feat/refonte-back-infra` (commune aux chantiers 2 à 5)
Contexte : `audit-back-infra-2026-09-23.md` (« Coûts Claude ») et **revue qualité des 504 fiches de prod du 2026-09-24** (§ 1 bis). S'appuie sur le chantier 1 (contenu par empreinte, `item_generations` UNIQUE(text_hash, generation_version), commits par item dans `pipeline.py`). Les `max_length` des saisies (`user_answer`, `user_note`) sont au chantier 2.

## 1. Décisions

| # | Décision |
|---|---|
| C1 | **Pas de Batch API** : génération interactive (SSE). |
| C2 | **Claude Sonnet 5** (`claude-sonnet-5`, 2 $ / 10 $ par MTok) pour la génération et la régénération, sans évaluation à l'aveugle ; contrôle de fumée (§ 9). Évaluation sémantique du drill : Haiku 4.5 inchangé. |
| C3 | **Nouveau prompt `p2`** (§ 3) : nombre de fiches **proportionnel au contenu (0 à 40)**, couverture de chaque objectif de rang A d'abord, puis B ; **aucune fiche de rang C** (non évalué aux EDN) ; rang par fiche. |
| C4 | **Nouveau type de fiche `cas_clinique`** (mini cas clinique → conduite/diagnostic), ~20 % max, seulement si le texte fournit les éléments. |
| C5 | **Correction du découpage des items** (§ 4) : c'est la première cause de mauvaises fiches. |
| C6 | **Base de contenu vidée au déploiement** (§ 8) : l'utilisateur est seul utilisateur et réimporte ses collèges de zéro. Son compte est conservé. Autorisation donnée le 2026-09-24. |
| C7 | Pas de cache de prompt (préfixe commun sous le minimum cachable). |

## 1 bis. Constat de la revue (66 items, 504 fiches, 3 collèges)

- Fidélité bonne (7,5 à 9/10) : les chiffres sont presque tous exacts.
- **Couverture du rang A : 3/10** partout :
  - 8 fiches par item quelle que soit la taille (1,5 k à 200 k caractères, médiane 38 k), soit 20 à 35 % des objectifs A couverts ;
  - le modèle privilégie des détails de rang B (pourcentages isolés, mécanismes d'action).
  - Besoin estimé : médiane ~18-20 fiches par item, de 8 à 40.
- **Découpage cassé** :
  - en-tête « Item 21 2 » lu comme item 21 (faux item, 212 réduit à 2 pages ; idem 315/« 31 ») ;
  - pages perdues (104, 117, 249-258, 277-283 en hématologie) ;
  - items qui débordent sur le suivant (298→299, col utérin sans fiche) ;
  - 329 avale les « Dossiers progressifs » et le corrigé de fin de livre ;
  - tableaux pivotés lus à l'envers (« snoitacidnI »).
- **Invention quand le texte est pauvre** : 215 (seulement sommaire + tableau) a 8 fiches hors texte ; 306 a des fiches sur le livre lui-même (« Combien d'items ? → 24 »).
- **Forme** :
  - ~30 listes de 6 éléments et plus ;
  - 16 questions doubles ;
  - « (Rang B) » écrit au recto ;
  - doublons classique/définition, définitions triviales.
- **Item 320 : 0 fiche** (JSON illisible probable ; réglé par la sortie structurée).
- Chaque item commence par un **tableau d'objectifs Rang/Rubrique/Intitulé** et a souvent une section « Points clés » et des sections marquées A/B : non exploités aujourd'hui.

## 2. Client Claude (`app/services/generation/claude_client.py`)

- `GENERATION_MODEL = "claude-sonnet-5"`, `PROMPT_VERSION = "p2"` → `GENERATION_VERSION = "claude-sonnet-5:p2"`.
- Génération :
  - `system` = consignes (§ 3), message utilisateur = item ;
  - `thinking={"type": "adaptive"}`, `output_config={"effort": "medium", "format": {...}}` (la couverture du tableau d'objectifs demande un peu de raisonnement ; le contrôle de fumée compare `low` et `medium` sur coût et couverture et garde le moins cher qui couvre les objectifs A) ;
  - **aucun** `temperature`/`top_p`/`top_k` (400 sur Sonnet 5), pas de préremplissage ;
  - `max_tokens=16000` (jusqu'à 40 fiches, nouveau tokenizer ~+30 %, réflexion comprise).
- **Sortie structurée** (`output_config.format`, `type: "json_schema"`) :
  - format : `{"flashcards": [{"type": "classique"|"definition"|"cas_clinique", "rang": "A"|"B", "recto": str, "verso": str}], "insufficient_text": bool}` ;
  - `required` partout, `additionalProperties: false`, `enum` sur `type` et `rang` ;
  - le code ne dépend pas de `minItems`/`maxItems` : il tronque au-delà de 40 et journalise ;
  - parsing : bloc texte cherché parmi `response.content` (un bloc de réflexion peut précéder) ; plus de retrait de ```` ``` ```` ni de consigne JSON dans le prompt.
- `stop_reason` `refusal` ou `max_tokens` → 0 fiche, usage **compté**, warning avec le numéro d'item ; `insufficient_text: true` → 0 fiche, info journalisée, l'item est marqué dans le résumé d'import (pas une erreur).
- Régénération (`regenerate_single_card`) : même modèle et réglages, schéma d'une fiche (avec `rang`), mêmes règles de rédaction, `max_tokens=2000`.
- `ask_json` (drill, Haiku 4.5) : sortie structurée avec le schéma attendu par `drill.py`, renvoie l'usage (§ 6).

## 3. Prompt `p2` (texte de référence, à affiner seulement si le contrôle de fumée le justifie)

System :

```
Tu rédiges des flashcards de révision pour des étudiants en médecine qui
préparent les EDN (ex-ECNi). Tu travailles uniquement à partir du texte
fourni : chaque fait d'une fiche doit y figurer. N'ajoute rien de tes
connaissances, même si c'est exact.

Méthode :
1. Repère le tableau des objectifs de l'item (colonnes Rang / Rubrique /
   Intitulé) et, s'il existe, la section « Points clés ». Les sections du
   texte peuvent aussi être marquées A ou B.
2. Couvre d'abord CHAQUE objectif de rang A par au moins une fiche
   (souvent 2 ou 3 pour un objectif riche), puis les points clés, puis le
   rang B s'il reste des notions utiles. Les notions de rang C ne sont pas
   évaluées aux EDN : ne fais aucune fiche dessus.
3. Le nombre de fiches dépend du contenu : autant que de notions à
   connaître, de 0 à 40. Un item court en aura peu, un item dense beaucoup.
4. Si le texte ne contient pas de vrai contenu d'enseignement (seulement
   un sommaire, un tableau d'objectifs sans développement, des énoncés de
   QCM), rends une liste vide avec insufficient_text = true.

Règles pour chaque fiche :
- Une seule notion par fiche, une seule question (pas de « et » qui
  enchaîne deux questions).
- La question se comprend seule : ni « selon le texte », ni mention du
  rang, du collège, du livre ou des auteurs.
- Réponse courte : 1 à 3 lignes, au plus 4 éléments de liste. Au-delà,
  découpe en plusieurs fiches (par situation, par étape, par ligne de
  tableau).
- Recopie exactement chiffres, seuils, doses, scores et classifications,
  avec leur contexte (quelle molécule, quel indicateur). Ne fusionne
  jamais deux schémas ou deux valeurs.
- Si le texte se contredit sur une valeur, ne fais pas de fiche sur
  cette valeur.
- Privilégie ce qui sert en situation clinique : signe d'appel, examen de
  première intention, facteur de risque majeur, critère de gravité,
  traitement de première intention, urgence. Évite les pourcentages et
  détails sans conséquence pratique.
- Pas deux fiches sur la même notion, y compris entre définition et
  classique.
- Corrige l'orthographe médicale évidente d'un mot mal lu, sans jamais
  modifier un chiffre.
- Ignore le bruit : filigranes, numéros de page, en-têtes répétés, mots à
  l'envers, corrigés « Réponse : X », énoncés de dossiers et détails
  propres à une vignette.

Types :
- « classique » : question précise → réponse courte.
- « definition » : terme technique ou critère propre à l'item → définition
  en une phrase. Jamais pour un concept générique ou pour le titre de
  l'item.
- « cas_clinique » : mini-vignette de 1 à 2 phrases (âge, sexe, contexte,
  signes) → diagnostic le plus probable ou conduite à tenir. Seulement si
  le texte donne tous les éléments de la vignette et de la réponse ; au
  plus 20 % des fiches.

Chaque fiche porte le rang (A ou B) de la notion qu'elle teste.
Tout en français.
```

Message utilisateur : `Item {n} — {titre}\n<texte_item>\n{texte nettoyé}\n</texte_item>`.

## 4. Découpage des items (`app/services/ocr/item_detector.py`, `ocr_processor.py`)

Objectif : chaque item reçoit **toutes ses pages et seulement les siennes**. Exigences, chacune couverte par un test sur les textes réels :
- **En-têtes courants coupés** : « Item 21 2 » (ou « Item 3 1 5 ») est lu comme 212 (315), en s'appuyant sur la cohérence avec les pages voisines (en-tête courant répété, `OBJECTIFS : N° 212`, sommaire, référentiel `item_titles` officiel). Un numéro seul dont le titre officiel ne correspond pas et qui interrompt un en-tête courant n'ouvre pas de nouvel item.
- **`OBJECTIFS : N° x` est aussi un signal d'en-tête** (et pas seulement une source de titre) : il ouvre l'item x, ce qui empêche un item de déborder sur le suivant quand l'en-tête « Item x » n'a pas été lu.
- **Sections hors item** : les parties de fin de livre ou transverses (« Dossiers progressifs », « Corrigés », « QCM », « Index », « Abréviations », sommaire) ferment l'item en cours et ne sont rattachées à aucun item.
- **Aucune page perdue** : un rapport de découpage (journalisé en fin d'OCR et visible dans le détail de job admin) liste pour chaque page son item ou sa section hors item ; une page de contenu non rattachée est un warning. La cause des pages perdues en hématologie (104, 117, 249-258, 277-283) est identifiée et corrigée.
- **Texte pivoté** : les caractères non droits (`upright == False` dans pdfplumber) sont extraits dans le bon ordre (ou la zone repasse par Tesseract avec détection d'orientation) : plus de mots à l'envers dans les tableaux.
- **Rang des objectifs** : les pictogrammes A/B mal lus (« O / 0 / G / Q / © / □ ») ne sont plus pris pour un rang ; le rang d'item reste « A si au moins un objectif A ». Le rang par fiche (§ 2) devient la source affichée dans l'app.
- Fixtures de test : les textes de pages des 3 collèges exportés de la prod **avant le vidage** (§ 8), stockés hors git (`collega_backend/tests/fixtures/private/`, ajouté au `.gitignore` : contenu sous droits) ; les tests qui en dépendent sont ignorés proprement s'ils sont absents (CI). Tests unitaires synthétiques (committés) pour chaque règle ci-dessus.
- Script `scripts/segmentation_report.py <pdf|fixture>` : tableau item → pages, caractères, nb d'objectifs A détectés ; résultat avant/après dans la PR pour les 3 collèges. PDFs disponibles à la racine du dépôt (git-ignorés) : `PNEUMO 8e college.pdf`, `CANCERO 4e college (1).pdf`, `HEMATO 5e college.pdf` (ajouté par l'utilisateur le 2026-09-24) ; `ANAPATH 4e.pdf` est abîmé.

## 5. Allègement du texte envoyé

- `app/services/generation/prompt_text.py` : `clean_for_prompt(text: str) -> str`, pure :
  - supprime les lignes de filigrane (motifs relevés en prod : « Pour avoir plus d'exclusivités rejoindre nous sur www.amis-med.com… », « Il a été diffusé exclusivement et gratuitement sur le forum © SBA-MEDECINE », « pour plus des livres médicaux gratuits… www.sba-medecin… », `Faille_V2`, `(cid:NNN)`) ;
  - supprime les lignes d'un seul caractère ou d'un seul fragment (« n », « - », « ed ») et les numéros de page seuls ;
  - supprime les en-têtes/pieds répétés (ligne identique après normalisation présente sur ≥ 50 % des pages d'un item d'au moins 3 pages) ;
  - réduit les suites de lignes vides.
- Appliqué **uniquement** au texte envoyé à Claude. **L'empreinte (`fingerprint.item_hash`) et `item_texts` restent calculés sur le texte brut.** Toute modification de `clean_for_prompt` impose d'incrémenter `PROMPT_VERSION`.
- Mesure avant/après via `count_tokens` (gratuit) sur `claude-sonnet-5`, par collège, dans la PR.

## 6. Comptabilité complète des tokens

- Table `claude_usage` (migration : prochain numéro libre) : `id` UUID PK, `created_at` TIMESTAMPTZ default now, `user_id` FK users ON DELETE SET NULL, `college_id` FK colleges ON DELETE SET NULL, `job_id` FK generation_jobs ON DELETE SET NULL, `kind` TEXT CHECK in (`generation`, `regeneration`, `evaluation`), `model` TEXT, `input_tokens` INT, `output_tokens` INT ; index (`user_id`, `created_at`) et (`job_id`).
- **Une ligne par appel facturé**, écrite en session courte juste après la réponse (avant le parsing) : comptée même si le job échoue, est annulé ou si la réponse est inutilisable. Appel sans réponse (`APIError`) : rien. Génération : `pipeline.py` ; régénération : route de régénération ; évaluation : `drill.py`.
- Même migration : reprise de l'historique (une ligne `generation`/`claude-sonnet-4-6` par `generation_jobs` ayant des tokens) puis **suppression** de `generation_jobs.input_tokens`/`output_tokens`. `item_generations.input_tokens` reste.
- `token_cost.py` : tarifs par modèle (`claude-sonnet-4-6` 3/15, `claude-sonnet-5` 2/10, `claude-haiku-4-5*` 1/5 USD/MTok, date de vérification en commentaire) ; modèle inconnu → tarif Sonnet 5 + warning ; coût calculé à la lecture.
- Admin : vues coût (total, par utilisatrice, détail de job) lues dans `claude_usage`, ventilation par `kind` et modèle, colonne « 30 derniers jours ».

## 7. Données et app

- Migration : `ck_flash_cards_card_type` accepte `cas_clinique` ; `flash_cards.rang` reçoit le rang **de la fiche** (A/B, rendu par Claude ; à défaut celui de l'item) ; les fiches stockées dans `item_generations` portent aussi `rang`.
- App (Flutter) :
  - `cas_clinique` se révise comme une fiche classique (on retourne la carte) ; les anciennes versions de l'app l'affichent déjà ainsi (seul `definition` a un comportement spécial) ;
  - libellé « Cas clinique » (et « Définition ») sur la carte du drill et dans la liste des fiches du collège, via un composant Collega UI (étiquette, couleur de la palette existante, pas de nouvelle couleur hors thème), story Widgetbook ;
  - tri de la liste : classique, cas clinique, définition ;
  - le rang affiché est celui de la fiche ;
  - tests widget + golden de l'étiquette.
- Résumé d'import : les items `insufficient_text` sont listés (« Pas assez de contenu : items 215… »), pour que l'utilisateur sache quoi vérifier.

## 8. Génération en parallèle, déploiement et vidage

- **Parallèle** : `asyncio.Semaphore(settings.generation_concurrency)` (défaut **4**) dans `pipeline.py`, chaque tâche avec sa session courte et son commit par item. Annulation : tâches en vol annulées, items commités conservés, job reprenable. Erreur d'API après les réessais du SDK : le job échoue (quota remboursé si réimport), les autres tâches sont annulées. 429 répétés au contrôle de fumée → défaut 2.
- **Avant le déploiement** : export des textes de pages des 3 collèges (fixtures § 4) et dump complet.
- **Vidage** (script `scripts/wipe_content.py --confirm`, exécuté une fois après la migration, avec l'OK déjà donné par l'utilisateur) :
  - supprime tous les collèges et, en cascade, items, fiches, révisions, jobs, événements, brouillons, `college_pages` ;
  - supprime le stock de contenu (`ocr_pages`, `item_texts`, `item_generations`) et les PDFs restants du volume ;
  - retire du référentiel `item_titles` les titres non officiels ;
  - remet à zéro les compteurs de réimport/quota des utilisatrices ;
  - **conserve** les comptes, les abonnements et `claude_usage` (`college_id`/`job_id` passent à NULL).
  - Le script affiche les comptes avant/après et refuse de tourner sans `--confirm`.
- Le déploiement du chantier 4 (avec le vidage) se fait **au retour de l'utilisateur**, en même temps que celui du chantier 2 (voir la passation). L'utilisateur réimporte ensuite ses collèges depuis l'app ; la session surveille les logs (découpage, `insufficient_text`, coût par collège) et rapporte le nombre de fiches par item.

## 9. Contrôle de fumée (avant déploiement)

`scripts/smoke_generation.py` (hors CI, clé réelle, quelques centimes) sur 3 items réels (un par collège, dont un long), après correction du découpage :
- fiches produites, nb par rang et par type, tokens entrée/sortie/réflexion, coût ;
- comparaison `effort` `low` vs `medium` ;
- vérification automatique : chaque nombre du verso figure dans le texte source (signalé sinon) ;
- résultat dans la PR pour lecture par l'utilisateur.

## 10. Tests

- Client (Anthropic simulé) :
  - paramètres (modèle, pas de `temperature`, `thinking`, `output_config`) ;
  - bloc de réflexion avant le texte ;
  - `refusal`/`max_tokens` → 0 fiche + usage ;
  - `insufficient_text` ;
  - troncature au-delà de 40 ;
  - `cas_clinique` et `rang` par fiche.
- Découpage : une règle = un test synthétique ; tests sur fixtures privées (items attendus et plages de pages pour les 3 collèges, 0 page de contenu perdue, 0 mot à l'envers connu).
- `clean_for_prompt` : filigranes, fragments, en-têtes répétés, texte propre inchangé ; invariance de `item_hash`.
- Postgres :
  - une ligne `claude_usage` par appel, y compris job échoué ;
  - `kind` de la régénération et de l'évaluation ;
  - migration (historique repris, colonnes supprimées, contrainte `card_type`) ;
  - totaux admin ;
  - `wipe_content` (ce qui part, ce qui reste).
- Parallélisme : 10 items, concurrence 4 → ≤ 4 appels simultanés, tous publiés ; annulation au milieu → items commités conservés.

## 11. Documents

- `audit-back-infra-2026-09-23.md` : chantier 4 fait, avec mesures (tokens avant/après, fiches par item, coût par collège).
- Mémoire Kage : règles de découpage, prompt `p2`, règle « modifier le nettoyage ou le prompt = incrémenter `PROMPT_VERSION` ».

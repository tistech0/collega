# Story 7.5 : Affinage du Prompt Persona Claude

Status: ready-for-dev

> **⚠️ STATUT MÉTIER — STORY DIFFÉRÉE**
>
> Cette story est créée en `ready-for-dev` pour avoir le contexte prêt, **mais le kick-off implémentation reste gated sur un signal explicite du Project Lead** (cf. décision 2026-05-19 et marqueur `[DIFFÉRÉ]` dans `sprint-status.yaml:128`).
>
> Le dev agent NE DOIT PAS commencer l'implémentation tant que le Project Lead n'a pas confirmé le go. La gating actuelle protège le travail en cours de la testeuse et permet de coordonner le wipe préalable de la base (cf. § Prérequis ci-dessous).

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Prérequis (opérationnels, hors scope code)

**Un wipe complet de la base prod (users inclus) est planifié avant le re-test du nouveau prompt** (décision Project Lead 2026-05-22). Conséquences pour cette story :

- **Aucune fiche ancienne ne subsiste** après le wipe → pas de question "que faire des fiches générées avec l'ancien prompt" (elles seront supprimées avec le reste).
- **Le hash-sharing ne court-circuite plus rien** : la table `generation_jobs` étant vidée, `find_similar_job` (`hash_sharing.py:29`) ne retournera jamais de match au premier réimport post-wipe → tout passe en génération Claude normale, avec le nouveau prompt. Aucune modification de `card_generator.py` ni de `hash_sharing.py` n'est nécessaire dans cette story.
- **La testeuse re-crée son compte** post-wipe, ré-upload son PDF, le pipeline OCR + génération Claude tourne de zéro → c'est le scénario de validation R5 naturel.
- **Timing du wipe** : pas encore décidé (sera coordonné avec la fin du collège testeuse). La présente story est indépendante du moment exact, tant que le wipe précède le kick-off de l'implémentation OU au minimum le test AC2.

**Hors scope story 7.5** : la procédure de wipe elle-même (script, ordre des truncates, gestion RevenueCat, backup éventuel) — c'est une opération ops distincte.

---

## Story

**Persona 1 — étudiante en médecine (R5)**

En tant qu'**étudiante en médecine**,
je veux que les fiches générées par Claude soient plus synthétiques et techniques (questions courtes, réponses ciblées, ton clinique direct),
afin de pouvoir réviser efficacement en sessions courtes (drill 10–20 cartes) sans être ralentie par la lecture de questions verbeuses ou de réponses pédagogiques travaillées qui ne correspondent pas à mon niveau de connaissances médicales.

**Persona 2 — développeur (qualité produit + maîtrise coût Claude)**

En tant que **développeur**,
je veux un nouveau prompt persona avec contraintes explicites de longueur, ton technique direct et exemples few-shot ancrés ECN, et un chemin de mesure objectif post-déploiement,
afin de pouvoir vérifier que l'itération produit améliore réellement la qualité (longueurs ≤ cibles dans ≥ 80% d'un échantillon de 50 fiches) avant de déclarer la story terminée.

**Items source :**
- R5 — Qualité contenu : "Prompt persona Claude trop verbeux — fiches à rendre plus synthétiques et techniques. **Différé.**" (cf. `_bmad-output/planning-artifacts/epics-v1.1.md:47`)
- Story epic L.314-351 (`_bmad-output/planning-artifacts/epics-v1.1.md`)
- Rétro MVP § Gap #3 "Validation Phase 0 testeuse" et AI-1 (`_bmad-output/implementation-artifacts/epic-mvp-retro-2026-05-19.md:111,153,183`)

---

## Acceptance Criteria

1. **AC1 — Nouveau prompt persona avec contraintes explicites + few-shot**
   - **Étant donné** le prompt actuel `GENERATION_PROMPT` (`collega_backend/app/services/generation/claude_client.py:14-34`) qui ne contient **aucune** contrainte de longueur, **aucun** exemple few-shot et un ton générique ("expert en fiches de révision médicale ECNi")
   - **Quand** la story est livrée
   - **Alors** un nouveau prompt remplace `GENERATION_PROMPT` avec **au minimum** les 4 éléments suivants :
     1. **Contraintes de longueur explicites** :
        - Cartes `classique` : `recto` (question) ≤ **15 mots**, `verso` (réponse) ≤ **40 mots**
        - Cartes `definition` : `recto` (terme) ≤ **5 mots** (souvent 1–3), `verso` (définition clinique) ≤ **30 mots**
     2. **Ton technique direct** : vocabulaire médical assumé (PA = pression artérielle, IDM = infarctus du myocarde, etc. — pas de paraphrase pédagogique du type "la pression sanguine artérielle, c'est-à-dire…"), pas de circonlocutions ("Il est important de noter que…"), pas d'hédging gratuit ("souvent", "parfois" sauf si cliniquement nécessaire).
     3. **Few-shot examples** : **3 à 5 exemples "bons"** + **1 à 2 exemples "mauvais" annotés** ("ÉVITER : … parce que …"), avec un mix `classique` + `definition`. Les exemples doivent être issus du domaine médical ECN (cardio / pneumo / cancero / anapath — voir les 4 PDFs disponibles à la racine du repo) et **PAS** d'un domaine fictif. Ils servent à ancrer le modèle sur la longueur ET le ton attendus.
     4. **Compteur cible respecté** : "Génère entre 2 et 5 flashcards classiques et 0 à 3 fiches définition selon le contenu" reste valide (pas de changement sur la quantité).
   - **Et** le contrat JSON de sortie reste **strictement identique** : `{"flashcards": [{"type": "classique"|"definition", "recto": "...", "verso": "..."}]}` — aucune modification de schéma car `card_generator.generate_for_college` (`card_generator.py:96-113`) et `ClaudeClient.generate_cards_for_item` (`claude_client.py:120-130`) parsent ces 3 clés exactes.
   - **Et** la modification reste **isolée à `GENERATION_PROMPT`** (la constante `REGENERATION_PROMPT` ligne 37-56 n'est **PAS** modifiée — voir AC6 pour la décision sur la régénération individuelle).

2. **AC2 — Mesure objective : longueurs respectées sur ≥ 80% d'un échantillon de 50 fiches**
   - **Étant donné** le nouveau prompt déployé en backend (post-wipe, cf. § Prérequis)
   - **Quand** on génère 50 fiches issues d'items réels (au minimum 1 collège complet ECN, ex : ANAPATH 4e ou CANCERO 4e — PDFs disponibles à la racine du repo : `ANAPATH 4e.pdf`, `CANCERO 4e college (1).pdf`, `PNEUMO 8e college.pdf`)
   - **Alors** un script de mesure (NEW : `collega_backend/scripts/measure_card_lengths.py`) :
     - Parcourt les `FlashCard` de l'échantillon (filtre `college_id IN (...)`)
     - Compte les mots de `recto` et `verso` (split simple sur whitespace, `len(s.split())`)
     - Calcule pour chaque type (`classique`, `definition`) le pourcentage de cartes dont `recto` ≤ cible-recto ET `verso` ≤ cible-verso
     - Émet un rapport texte/JSON : `{"classique": {"total": N, "within_target": M, "pct": ...}, "definition": {...}}`
     - Exit code : 0 si ≥ 80% sur chaque type, 1 sinon (pour intégration éventuelle en pipeline)
   - **Et** le critère de succès quantitatif est : **≥ 80% des fiches `classique` ET ≥ 80% des fiches `definition`** dans l'échantillon respectent les longueurs cibles d'AC1.
   - **Et** si le seuil n'est pas atteint au 1er run, le dev agent itère sur le prompt (ajouter exemples, durcir formulations) **avant** de marquer la story `done`. Loguer les itérations dans la section Dev Agent Record.
   - **Note** : la "validation qualitative testeuse" (jugement humain sur le ton et l'utilité pédagogique) reste **hors scope dev** — c'est une étape Project Lead post-merge, sur le PDF que la testeuse aura ré-uploadé.

3. **AC3 — Test unitaire qui vérifie la présence des contraintes dans le prompt**
   - **Étant donné** le fichier `collega_backend/tests/services/test_claude_client.py` qui couvre déjà 6 tests sur la structure du parsing (`TestClaudeClientGenerateCards`)
   - **Quand** la story est livrée
   - **Alors** une nouvelle classe `TestGenerationPromptContent` (NEW) ajoute au minimum 3 tests :
     ```python
     def test_prompt_contains_explicit_length_constraints():
         """AC1 — le prompt mentionne les cibles de longueur (mots ou caractères) pour recto/verso."""
         from app.services.generation.claude_client import GENERATION_PROMPT
         # Vérification souple : le prompt doit contenir une trace explicite de
         # contraintes de longueur, sans figer la formulation exacte.
         lower = GENERATION_PROMPT.lower()
         assert "mot" in lower or "word" in lower or "≤" in GENERATION_PROMPT
         # Au moins 3 nombres distincts (cibles classique recto + verso + definition...) doivent
         # apparaître — détecte une suppression accidentelle des cibles.
         import re
         numbers = re.findall(r"\b\d+\b", GENERATION_PROMPT)
         assert len(set(numbers)) >= 3  # 15, 40, 5, 30, ... au moins 3 distincts

     def test_prompt_contains_few_shot_examples():
         """AC1 — le prompt contient au moins 3 exemples "bons" et 1 contre-exemple "mauvais"."""
         from app.services.generation.claude_client import GENERATION_PROMPT
         lower = GENERATION_PROMPT.lower()
         assert lower.count("exemple") >= 3  # ≥ 3 exemples mentionnés
         # Au moins une trace d'un contre-exemple
         assert "éviter" in lower or "à éviter" in lower or "mauvais" in lower or "incorrect" in lower

     def test_prompt_output_contract_unchanged():
         """AC1 — le contrat JSON de sortie reste strictement {"flashcards": [...]} avec type/recto/verso."""
         from app.services.generation.claude_client import GENERATION_PROMPT
         assert '"flashcards"' in GENERATION_PROMPT
         assert '"type"' in GENERATION_PROMPT
         assert '"recto"' in GENERATION_PROMPT
         assert '"verso"' in GENERATION_PROMPT
         assert '"classique"' in GENERATION_PROMPT
         assert '"definition"' in GENERATION_PROMPT
     ```
   - **Et** les 6 tests existants de `TestClaudeClientGenerateCards` **continuent de passer sans modification** (le format de réponse mock JSON reste valide quel que soit le contenu du prompt — voir T2 pour confirmation).

4. **AC4 — Bench manuel sur 5 items avant la mesure 50 fiches**
   - **Étant donné** la nouvelle version du prompt
   - **Quand** elle est itérée par le dev agent
   - **Alors** un bench informel (script ou notebook ad-hoc) compare **côte à côte** sur **5 items réels distincts** :
     - Sortie ancien prompt (capturée en local en faisant tourner Claude avec l'ancienne version de `GENERATION_PROMPT` — facile à recréer puisque le code est trivial et la version git est disponible)
     - Sortie nouveau prompt
     - Diff qualitatif noté en 1–2 lignes (ex : "+1 fiche, recto -8 mots, verso plus technique")
   - **Et** ce bench n'est **pas un test automatisé** — c'est un artefact de revue humaine **AVANT** de lancer la mesure quantitative AC2. Il sert à éviter de dépenser 50 appels Claude sur un prompt manifestement cassé.
   - **Et** le rapport bench est référencé dans la section Dev Agent Record final (lien vers le fichier d'artefact, dans `_bmad-output/implementation-artifacts/7-5-prompt-bench-{date}.md`).
   - **NE PAS** facturer ces 5+5 appels Claude au quota d'un user prod — utiliser la clé API en local dev.

5. **AC5 — Documentation : section dans `docs/sdk-gotchas.md` OU note dans deferred-work**
   - **Étant donné** que `collega_backend/docs/sdk-gotchas.md` a été créé en Story 7.4 (cf. commit `72da25a` § Docs) et documente les pièges SDK
   - **Quand** la story est livrée
   - **Alors** **une** des deux actions suivantes (au choix du dev agent selon le format jugé le plus pertinent) :
     - **Soit** une nouvelle section dans `docs/sdk-gotchas.md` intitulée "Anthropic SDK — Prompt versioning interne (informationnel, non bloquant)" qui documente la convention adoptée : changement de prompt = constante littérale Python (pas de migration DB, pas de versionnement formel), pas de A/B testing en place pour le MVP, mesure post-hoc via `scripts/measure_card_lengths.py` (cf. AC2). Cette section sert de référence pour les futurs changements de prompt.
     - **Soit** une nouvelle entrée dans `deferred-work.md` (`## Deferred from: code review of 7-5-affinage-prompt-persona-claude (date)`) qui liste les items hors-scope identifiés pendant l'implémentation (typiquement : "prompt A/B testing", "prompt versioning DB", "intégration eval framework type promptfoo", "hash-sharing intra-user filter").
   - **Et** **NE PAS** créer de fichier `docs/prompt-engineering.md` ou similaire — un seul prompt en jeu (R5), pas besoin d'une doc dédiée pour le MVP. Si plusieurs prompts apparaissent en Phase 2, refacto à ce moment.
   - **Et** dans tous les cas, **ajouter au moins l'item suivant** dans `deferred-work.md` (peut être groupé avec l'option B ci-dessus) :
     ```
     Hash-sharing intra-user : `find_similar_job` (`hash_sharing.py:29`) ne filtre pas par `user_id`. En multi-user post-beta, un user qui ré-importe son propre PDF récupère ses propres anciennes fiches plutôt qu'une re-génération. Acceptable tant que les anciennes fiches restent valides ; à fixer dès qu'on aura plusieurs users qui pourraient avoir intérêt à régénérer (ex : changement de prompt futur). Solution : ajouter `user_id != current_user_id` au filtre, ou exposer un flag `force_regenerate` sur la route reimport.
     ```

6. **AC6 — Pas de modification de `REGENERATION_PROMPT` ni de `ClaudeClient.regenerate_single_card`**
   - **Étant donné** que la régénération individuelle d'une fiche (FR22, déclenchée depuis le bouton "Régénérer" en UI) utilise un prompt distinct `REGENERATION_PROMPT` (`claude_client.py:37-56`) qui prend en entrée le feedback textuel de l'étudiant et est conçu pour produire **une seule** fiche améliorée ciblée
   - **Quand** la story est livrée
   - **Alors** :
     - `REGENERATION_PROMPT` reste **inchangé** — son contrat est différent (réponse à un feedback ciblé, pas génération en lot) et son redesign mériterait une story dédiée (différé Phase 2 si jamais nécessaire)
     - La méthode `ClaudeClient.regenerate_single_card` (`claude_client.py:132-190`) reste **inchangée**
     - L'argument que la testeuse a soulevé concerne la **génération initiale** (volume + qualité moyenne) — le bouton "Régénérer" est un correctif à l'unité, pas le canal principal de production de fiches
   - **Et** une note explicite dans Dev Notes confirme cette décision (pour éviter qu'une review ultérieure ne demande "pourquoi tu n'as pas mis à jour les 2 prompts en cohérence" — la réponse est : scope R5 = prompt principal uniquement, REGENERATION_PROMPT est différé).

---

## Tasks / Subtasks

> **🛑 RAPPEL** : Ne PAS commencer les tasks tant que le Project Lead n'a pas confirmé le kick-off (et idéalement coordonné le wipe préalable, cf. § Prérequis).

### Backend — Prompt + tests

- [ ] **T1 — Rédiger et itérer le nouveau `GENERATION_PROMPT` (AC: #1, #4)**
  - Lire `collega_backend/app/services/generation/claude_client.py:14-34` (prompt actuel)
  - Optionnel : récupérer 2-3 exemples concrets de fiches "trop longues" générées avec l'ancien prompt (si pré-wipe, requête SQL ad-hoc ; sinon, simplement faire tourner l'ancien prompt localement sur 1-2 items des PDFs du repo et constater le travers)
  - Rédiger la nouvelle version du prompt avec :
    - En-tête de rôle inchangée ou plus précise (ex : "Tu es médecin sénior qui rédige des flashcards de révision ECN pour des co-internes — ton clinique direct, vocabulaire médical assumé.")
    - Bloc "**Contraintes strictes**" avec les cibles de longueur (cf. AC1)
    - Bloc "**Exemples de bonnes fiches**" avec 3-5 exemples ancrés ECN (mix classique + definition)
    - Bloc "**Exemples à ÉVITER**" avec 1-2 contre-exemples annotés ("ÉVITER : … parce que verbeux / parce que paraphrase pédagogique")
    - Bloc consigne de sortie JSON **identique à l'actuel** (cf. AC1)
  - Itérer en local (cf. T3) en faisant tourner `generate_cards_for_item` sur quelques items mockés avant de pousser en commit

- [ ] **T2 — Mettre à jour `claude_client.py` (AC: #1, #6)**
  - Fichier : `collega_backend/app/services/generation/claude_client.py`
  - **Remplacer UNIQUEMENT le contenu de la constante `GENERATION_PROMPT` (lignes 14-34)** par la nouvelle version finalisée à T1
  - **NE PAS** modifier `REGENERATION_PROMPT` (lignes 37-56) — confirmé en AC6
  - **NE PAS** modifier la classe `ClaudeClient`, ni `FlashCardData`, ni `ask_json`, ni `generate_cards_for_item`, ni `regenerate_single_card` — toute la logique de parsing JSON reste valide tant que le contrat de sortie est respecté
  - **CRITIQUE — Échappement des accolades** : la méthode `generate_cards_for_item` utilise `str.format()` (`prompt = GENERATION_PROMPT.format(item_number=..., rang=..., ocr_text=safe_ocr_text)` ligne 95-99). Toute accolade `{` ou `}` ajoutée dans le prompt **pour autre chose que les 3 placeholders `{item_number}`, `{rang}`, `{ocr_text}`** doit être doublée (`{{` / `}}`) — y compris dans les exemples JSON few-shot. Sinon `str.format()` lèvera un `KeyError` au runtime. Ce pattern d'échappement est déjà en place sur le `ocr_text` lui-même (`safe_ocr_text = item.ocr_text.replace("{", "{{").replace("}", "}}")` ligne 94) — appliquer la même rigueur au texte du prompt lui-même.
  - **NE PAS** changer `max_tokens=2000` (ligne 104). Avec des sorties plus synthétiques on aura de la marge, mais inutile de toucher.
  - **NE PAS** changer le modèle `claude-sonnet-4-6` (ligne 103). Le persona, pas le moteur, est l'objet de cette story. Un benchmark Haiku vs Sonnet serait une story séparée.

- [ ] **T3 — Tests unitaires `TestGenerationPromptContent` (AC: #3)**
  - Fichier : `collega_backend/tests/services/test_claude_client.py`
  - **Ajouter la classe `TestGenerationPromptContent`** à la fin du fichier (après `TestClaudeClientGenerateCards`)
  - Implémenter les 3 tests décrits dans AC3 :
    - `test_prompt_contains_explicit_length_constraints`
    - `test_prompt_contains_few_shot_examples`
    - `test_prompt_output_contract_unchanged`
  - **Pas d'appel Claude réel dans ces tests** — uniquement de l'inspection de la constante `GENERATION_PROMPT` en mémoire (rapide, déterministe, gratuit)
  - **Vérifier que les 6 tests existants de `TestClaudeClientGenerateCards` passent toujours sans modification** — ils mockent `anthropic.AsyncAnthropic` et ne dépendent pas du contenu du prompt

- [ ] **T4 — Script de mesure `scripts/measure_card_lengths.py` (AC: #2)**
  - Fichier NEW : `collega_backend/scripts/measure_card_lengths.py`
  - Pattern : script Python async standalone (pas un test pytest — c'est un outil d'audit ponctuel)
  - API CLI minimale :
    ```bash
    python scripts/measure_card_lengths.py --college-id <uuid> [--college-id <uuid>...] [--output json|text]
    ```
  - Logique :
    ```python
    """Mesure des longueurs de fiches générées vs cibles AC1 Story 7.5.

    Usage:
        python scripts/measure_card_lengths.py --college-id <uuid> [--output json]

    Cibles (AC1 Story 7.5):
        classique: recto ≤ 15 mots, verso ≤ 40 mots
        definition: recto ≤ 5 mots, verso ≤ 30 mots
    """
    from __future__ import annotations
    import argparse, asyncio, json, sys
    from uuid import UUID
    from sqlalchemy import select
    from app.core.database import async_session_factory
    from app.models.flash_card import FlashCard

    TARGETS = {
        "classique": {"recto": 15, "verso": 40},
        "definition": {"recto": 5, "verso": 30},
    }

    def _within_target(card_type: str, recto: str, verso: str) -> bool:
        t = TARGETS.get(card_type)
        if t is None:
            return False
        return len(recto.split()) <= t["recto"] and len(verso.split()) <= t["verso"]

    async def measure(college_ids: list[UUID]) -> dict:
        async with async_session_factory() as db:
            result = await db.execute(
                select(FlashCard).where(FlashCard.college_id.in_(college_ids))
            )
            cards = result.scalars().all()
        stats = {ct: {"total": 0, "within_target": 0} for ct in TARGETS}
        for c in cards:
            if c.card_type not in stats:
                continue
            stats[c.card_type]["total"] += 1
            if _within_target(c.card_type, c.recto, c.verso):
                stats[c.card_type]["within_target"] += 1
        for ct, s in stats.items():
            s["pct"] = (s["within_target"] / s["total"] * 100) if s["total"] else None
        return stats

    if __name__ == "__main__":
        parser = argparse.ArgumentParser()
        parser.add_argument("--college-id", action="append", required=True, type=UUID)
        parser.add_argument("--output", choices=["json", "text"], default="text")
        args = parser.parse_args()
        stats = asyncio.run(measure(args.college_id))
        if args.output == "json":
            print(json.dumps(stats, indent=2, default=str))
        else:
            for ct, s in stats.items():
                pct = f"{s['pct']:.1f}%" if s["pct"] is not None else "n/a"
                print(f"{ct}: {s['within_target']}/{s['total']} ({pct})")
        ok = all((s["pct"] or 0) >= 80 for s in stats.values() if s["total"] > 0)
        sys.exit(0 if ok else 1)
    ```
  - **CRITIQUE — Connexion DB en local** : ce script doit pointer sur la base **réellement utilisée pour la génération de l'échantillon**. En pratique : soit base prod NAS (via tunnel SSH temporaire au moment de la mesure, post-wipe + post-réimport testeuse), soit base de dev locale après avoir importé un PDF en local. Documenter dans une docstring du fichier.
  - **NE PAS** versionner de fichier `.env` ou de credentials dans le script — la connexion DB lit `settings.database_url` via le pattern existant.
  - **NE PAS** automatiser ce script en CI — c'est un outil de mesure ad-hoc, pas un test régulier.

### Validation qualité (dev-side puis Project Lead)

- [ ] **T5 — Bench manuel comparatif 5 items + rapport (AC: #4)**
  - Créer `_bmad-output/implementation-artifacts/7-5-prompt-bench-{YYYY-MM-DD}.md`
  - Structure du rapport :
    - Section 1 : prompt avant (copie du `GENERATION_PROMPT` antérieur)
    - Section 2 : prompt après (lien vers `claude_client.py` au commit en cours)
    - Section 3 : tableau pour 5 items distincts (idéalement : 1 item Cardio + 1 Pneumo + 1 Cancero + 1 Anapath + 1 au choix) avec colonnes : `item_number`, `rang`, `nb cartes avant`, `nb cartes après`, `longueur moy. recto avant/après`, `longueur moy. verso avant/après`, `verdict qualitatif (1 ligne)`
    - Section 4 : conclusion go/no-go pour passer à la mesure AC2 sur 50 fiches
  - **NE PAS** facturer ces 5+5 appels Claude au quota d'un user prod — utiliser la clé API en local dev.

- [ ] **T6 — Mesure objective AC2 sur 50+ fiches échantillon (AC: #2)**
  - Préparer l'échantillon : import d'un collège complet ECN (1 des 4 PDFs du repo, ou le PDF testeuse une fois qu'elle a ré-uploadé post-wipe)
  - Exécuter `python collega_backend/scripts/measure_card_lengths.py --college-id <uuid> --output text`
  - Vérifier que le résultat affiche **≥ 80% within_target sur les deux types** (classique ET definition)
  - **Si échec** : itérer sur le prompt (T1+T2), re-bench (T5), re-mesurer (T6). **Ne pas marquer la story `done`** avant que le seuil soit atteint.
  - Documenter le résultat dans Dev Agent Record (Completion Notes)

### Documentation

- [ ] **T7 — Section sdk-gotchas OU entrée deferred-work + note hash-sharing intra-user (AC: #5)**
  - **Au choix entre Option A et Option B** :
    - **Option A** : Éditer `collega_backend/docs/sdk-gotchas.md` pour ajouter une 5e section "Anthropic SDK — Prompt versioning interne" avec le contenu décrit en AC5. Insérer à la fin du fichier, avant la note "Document vivant" (existante).
    - **Option B** : Éditer `_bmad-output/implementation-artifacts/deferred-work.md` pour ajouter un bloc `## Deferred from: code review of 7-5-affinage-prompt-persona-claude (YYYY-MM-DD)` avec les items hors-scope (A/B testing prompt, versioning DB, integration promptfoo).
  - **ET dans tous les cas** : ajouter l'item "hash-sharing intra-user filter" dans `deferred-work.md` (cf. AC5 wording exact). Le wipe couvre le cas immédiat de la testeuse, mais la dette technique reste à tracker pour Phase 2 multi-users.

---

## Dev Notes

### Architecture & patterns

- **Stack backend (à respecter sans déviation) :**
  - Python 3.11+ (FastAPI + SQLAlchemy 2.0 async + asyncpg + ARQ)
  - SDK Anthropic : `anthropic.AsyncAnthropic` configuré dans `ClaudeClient.__init__` (`claude_client.py:67-71`) avec `max_retries=3`
  - Modèle utilisé : **`claude-sonnet-4-6`** pour la génération (ligne 103), `claude-haiku-4-5-20251001` pour `ask_json` générique (ligne 75). Ne PAS changer le modèle dans cette story — la qualité visée passe par le prompt, pas le moteur. Cf. `_bmad-output/planning-artifacts/architecture.md:39` "Claude API exclusivement backend (clé jamais dans l'app — NFR5)".
  - Pattern factory : `ClaudeClient()` est instancié par `CardGenerator.__init__` (`card_generator.py:23`) — un client par CardGenerator par job ARQ. Pas de singleton (ARQ recrée le worker process sur reload).

- **Données concernées :**
  - Modèle `FlashCard` (`collega_backend/app/models/flash_card.py`) : champs `recto: str`, `verso: str`, `card_type: str` ("classique" | "definition"), `rang: str` ("A" | "B"), `ocr_confidence_score`, `low_confidence`. Les longueurs sont stockées en `str` libre — pas de contrainte DB.
  - **Post-wipe** : aucune fiche en base au moment du kick-off. Toutes les fiches mesurées en AC2 sont fraîchement générées avec le nouveau prompt.

- **Flow de génération (à connaître pour ne rien casser) :**
  ```
  POST /v1/colleges/{id}/reimport
    → router incrémente atomiquement reload_count + monthly_reloads (Story 7.2)
    → ARQ enqueue generation_worker
    → generation_worker appelle CardGenerator.generate_for_college
      → check hash-sharing (court-circuite Claude si match)  ← inerte post-wipe
      → sinon : pour chaque Item du college → ClaudeClient.generate_cards_for_item  ← AC1 ici
      → INSERT FlashCards en DB
      → job.status = 'generation_complete'
    → SSE notifie Flutter
  ```

### Source tree & fichiers à toucher

**À MODIFIER :**
- `collega_backend/app/services/generation/claude_client.py` — uniquement la constante `GENERATION_PROMPT` (lignes 14-34)
- `collega_backend/tests/services/test_claude_client.py` — ajout d'une classe `TestGenerationPromptContent` à la fin
- `_bmad-output/implementation-artifacts/deferred-work.md` — au moins l'item "hash-sharing intra-user filter" (T7)
- *(éventuel)* `collega_backend/docs/sdk-gotchas.md` — ajout d'une section (T7 Option A)

**À CRÉER (NEW) :**
- `collega_backend/scripts/measure_card_lengths.py` — script de mesure AC2
- `_bmad-output/implementation-artifacts/7-5-prompt-bench-{date}.md` — rapport bench T5

**À NE PAS TOUCHER (alerte) :**
- `card_generator.py` (rien à faire — le wipe rend la logique hash-sharing inerte au premier réimport)
- `hash_sharing.py` (rien à faire — voir AC5 / T7 pour la note technique deferred)
- `REGENERATION_PROMPT` et `ClaudeClient.regenerate_single_card` (cf. AC6)
- `generation_worker.py` (orchestration ARQ — hors scope)
- Toute migration Alembic (rien à migrer — le prompt est une constante Python)
- Toute fiche existante en base (le wipe est ops, pas dev)

### Conventions tests (héritées Story 7.4)

- Backend pytest : pattern `class TestXxx` + méthodes `test_*`. Mocks via `unittest.mock.patch` + `AsyncMock`/`MagicMock`.
- Fixtures partagées : `collega_backend/tests/conftest.py` (notamment `_reset_apns_service_singleton` introduite en 7.4 — sans effet sur 7.5, mais l'autouse global continue de tourner).
- Tests existants `test_claude_client.py` (6 tests `TestClaudeClientGenerateCards`) : pattern de mock de `anthropic.AsyncAnthropic` au niveau de la classe (`patch("app.services.generation.claude_client.anthropic.AsyncAnthropic")`). À reprendre tel quel si on ajoute des tests intégration.

### Intelligence Story 7.4 (review-fix patterns récurrents — à éviter dès le 1er jet)

D'après le commit `72da25a` (Story 7.4 a généré 11 patches en review BMAD), voici les patterns récurrents à anticiper :
- **D1-D4 review-fix sur docs** : éviter les disclaimers prématurés ("V1 à valider") dans les docs livrées en CGU/privacy → pour 7.5, le prompt et les exemples doivent être **autoporteurs et confiants**, pas "version d'essai"
- **P5** : singleton state désynchronisé entre tests → pour 7.5, la constante `GENERATION_PROMPT` est immutable au module — pas de risque, MAIS si on était tenté de la transformer en variable lue depuis settings, attention au pattern "module-level mutable state" — **ne PAS faire ça pour cette story**

### Git intelligence — 5 derniers commits

- `72da25a` 7.4 — chronomètre + APNs singleton + CGU/privacy + 11 patches review
- `3ba3efa` 7.3 — hardening RGPD safe-delete + sécurité config Pydantic
- `0672cb9` 7.2 — atomicité quota + idempotence reimport (a touché `card_generator.py` lignes 51-74 sur la compensation quota hash-sharing — branche inerte post-wipe, ne pas y toucher)
- `8b2c131` 7.1 — corrections UX FlashCard & Router
- `7361a30` chore — sprint MVP retro + ouverture Epic 7

### Latest tech information

- **Anthropic Python SDK** : version installée à vérifier dans `collega_backend/pyproject.toml` ou `requirements.txt`. L'API `AsyncAnthropic().messages.create(model=..., max_tokens=..., messages=[...])` est stable depuis le SDK ≥ 0.40 (Q4 2025). Aucun changement breaking attendu sur cette story.
- **Modèle `claude-sonnet-4-6`** : reste le SOTA sur du raisonnement médical et du formatting structuré au 2026-05. Pas de raison de migrer vers `claude-opus-4-x` ou `claude-haiku-4-x` pour cette story (le coût Haiku serait tentant mais la qualité médicale Haiku est notoirement plus faible — à benchmarker en story dédiée si jamais). Le `claude-haiku-4-5-20251001` n'est utilisé que pour `ask_json` générique (méthode non appelée actuellement par le flow `generate_for_college` — vestige réutilisable).
- **Prompt caching Anthropic** : non utilisé actuellement (pas de `cache_control` dans `messages.create`). Le prompt étant ~2KB après les exemples few-shot et identique pour tous les items, **un cache prompt aurait du sens à terme** pour réduire la facture Claude. → À tracker en `deferred-work.md` (T7) comme item Phase 2.

### Project Structure Notes

- Alignement avec la structure unifiée : `collega_backend/app/services/generation/` est le module canonique pour tout ce qui touche à la génération (cf. `architecture.md:402-409`). Le script `scripts/measure_card_lengths.py` est un outil de measurement, OK à mettre au niveau `collega_backend/scripts/` (parallèle aux services métier).
- Pas de conflit détecté avec la structure ou les conventions de nommage.

### References

- Story epic source : `_bmad-output/planning-artifacts/epics-v1.1.md:314-351` (Story 7.5 différée)
- Mapping items : `_bmad-output/planning-artifacts/epics-v1.1.md:389` (R5 → 7.5)
- Rétro MVP § Gap #3 (validation testeuse) : `_bmad-output/implementation-artifacts/epic-mvp-retro-2026-05-19.md:109-111`
- Rétro MVP § AI-1 (action validation qualité) : `_bmad-output/implementation-artifacts/epic-mvp-retro-2026-05-19.md:153,183`
- Architecture, mapping FR génération : `_bmad-output/planning-artifacts/architecture.md:406-409,429`
- Architecture, NFR clé Claude backend : `_bmad-output/planning-artifacts/architecture.md:39,136,465`
- Code prompt actuel : `collega_backend/app/services/generation/claude_client.py:14-34`
- Code generator : `collega_backend/app/services/generation/card_generator.py:23,96-113`
- Hash-sharing similarity (à noter pour T7) : `collega_backend/app/services/generation/hash_sharing.py:29`
- Story 7.4 (intelligence) : `_bmad-output/implementation-artifacts/7-4-chronometre-apns-singleton-docs.md`
- Tests existants à préserver : `collega_backend/tests/services/test_claude_client.py:28-118`

---

## Questions ouvertes (à clore au kick-off avec le Project Lead)

1. **AC4 — Source des exemples few-shot** : utiliser un des 4 PDFs du repo (ANAPATH, CANCERO, PNEUMO, + un 4e) ou rédiger à partir d'items connus de la testeuse ? **Suggestion : prendre 3-4 items archétypaux des PDFs disponibles, un par grand domaine, pour ancrer le modèle sur la diversité.**
2. **AC2 — PDF source pour l'échantillon de 50 fiches** : un PDF du repo (dev), ou attendre que la testeuse ré-importe son PDF post-wipe (prod réelle) ? **Suggestion : faire les 2 si possible — un dev pour valider rapidement le seuil 80%, puis confirmation en prod sur le ré-import testeuse.**
3. **AC5 — Option doc sdk-gotchas vs deferred-work** : à décider au moment du merge selon ce qui semble le plus utile.
4. **Hors AC mais pertinent** : faut-il en profiter pour activer le **prompt caching Anthropic** sur ce prompt (réduction de la facture proportionnelle au volume) ? **Suggestion : NON pour cette story** (out of scope, mais à tracker en deferred-work via T7).

---

## Dev Agent Record

### Agent Model Used

_(à remplir par le dev agent au kick-off)_

### Debug Log References

### Completion Notes List

### File List


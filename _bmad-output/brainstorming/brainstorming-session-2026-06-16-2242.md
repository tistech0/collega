---
stepsCompleted: [1, 2, 3, 4]
workflow_completed: true
session_active: false
inputDocuments: []
session_topic: 'Périmètre dashboard admin (API + vue web) — Story 7.6, avant re-test prompt 7.5'
session_goals: 'Décider quoi afficher et quoi pouvoir gérer dans le dashboard admin, en réutilisant l API admin existante et les modèles de données réels. Court et pragmatique.'
selected_approach: 'ai-recommended'
techniques_used: ['Role Playing', 'Question Storming', 'Resource Constraints']
ideas_generated: []
context_file: ''
---

# Brainstorming Session Results

**Facilitator:** Lesurmatthis
**Date:** 2026-06-16

## Session Overview

**Topic:** Périmètre d'un dashboard admin (API + vue web) pour Collega — Story 7.6, à construire avant le re-test du prompt persona 7.5 (base prod wipée).

**Goals:** Décider quoi afficher et quoi pouvoir gérer, en s'appuyant sur l'API admin existante (`/v1/admin/` : list users, toggle beta, queue génération, stats collège, config anti-spam) et les modèles réels (User, College, Item, FlashCard, GenerationJob, TesterFeedback). Gap bloquant connu : create-user admin (register 403 post-wipe). Session courte et pragmatique.

### Session Setup

_Brainstorm court orienté décision de périmètre. Matériel de départ déjà cartographié (API + modèles + scénario de test post-wipe). Objectif : sortir une liste priorisée d'éléments dashboard prête à alimenter la Story 7.6._

## Technique Selection

**Approach:** AI-Recommended Techniques
**Techniques:** Role Playing → Question Storming (fusionné dans Role Playing) → Resource Constraints

## Technique Execution Results

### Role Playing — besoins par acteur du re-test post-wipe

**Acteur 1 — Admin / Project Lead (soir du test) :**
- Créer le compte testeuse en 3 s (gap bloquant : `register` = 403) + passage `is_beta` (bypass paywall)
- Suivre l'import en temps réel / consultable (OCR page X/Y, génération, succès/erreur)
- Repérer un job `failed` + `error_message` sans fouiller les logs NAS
- Conso tokens cloud (Claude) + coût €
- Stop / delete d'un import
- Inspecter les fiches générées d'un collège lié à un user

**Acteur 2 — Testeuse (vécu à surveiller à distance) :**
- Voir son feedback sur les fiches (`TesterFeedback`) = signal qualité prompt 7.5
- Détecter qu'elle est bloquée (quota reload, job planté, import jamais fini)

**Acteur 3 — Dev (debug à froid) :**
- Détail brut d'un job (`arq_job_id`, `pdf_hash`, `hash_shared`, timestamps, `error_message`)
- Confiance OCR par item (`low_confidence`) — distinguer mauvais OCR vs mauvais prompt

### Idées capturées (format)

- **[Admin #1] Conso tokens cloud** — tokens + coût € par import/user/global. *Backend : persister `response.usage` par `GenerationJob` (pas stocké aujourd'hui).*
- **[Admin #2] Contrôle import** — stop (annuler job ARQ) + delete (import + fiches).
- **[Admin #3] Inspecter fiches générées** — recto/verso/type/rang par collège d'un user. Fenêtre qualité 7.5.
- **[Admin #4/#5] Timeline persistée par job** — étapes OCR/génération/erreur écrites en base, lisibles à la demande. Couvre après-coup ET pendant (refresh). Pas de live SSE.
- **[Testeuse #6] Vue feedback fiches** — `TesterFeedback` non pertinents. Signal qualité n°1.
- **[Testeuse #7] Détecteur de blocage** — quota atteint / job `failed` / import non terminé.
- **[Dev #8] Détail brut d'un job** — debug sans Redis/psql.
- **[Dev #9] Confiance OCR par item** — `ocr_confidence_score` / `low_confidence`.
- **[Foundation] Create-user admin + toggle beta + liste/détail user** — onboarding testeuse + point d'entrée.

### Resource Constraints — décision de périmètre

**Décision Project Lead : TOUT en v1** (pas pressé pour le test 7.5 → on fait une console admin complète d'un coup, le test tournera dessus une fois prête).

Pas de découpe MVP/v2 retenue. Le périmètre Story 7.6 = l'ensemble des 9 idées + le socle (create-user, toggle beta, liste/détail user, overview KPI).

## Idea Organization and Prioritization

**Organisation thématique (3 thèmes + transverses) avec ordre de construction conseillé A → B → C :**

### Thème A — Onboarding & gestion users (1er)
- Create-user admin (`POST /v1/admin/users`) — débloque l'onboarding testeuse (register = 403)
- Toggle `is_beta` (existe déjà) — bypass paywall
- Liste users (existe) + **détail user** (ses collèges/jobs/quota) — NEW
- Reset quota `monthly_reloads` — NEW
- _Rationale : sans ce socle, pas de testeuse ni de point d'entrée._

### Thème B — Suivi & contrôle des imports (2e)
- Statut import + **timeline persistée** des étapes (OCR page X/Y, génération, erreur) — NEW (ajout backend : écrire les événements en base)
- **Stop** (annuler job ARQ) + **delete** (import + fiches) — NEW
- Détail brut job (`arq_job_id`, `pdf_hash`, `hash_shared`, timestamps, `error_message`) — NEW
- Confiance OCR par item (`ocr_confidence_score`, `low_confidence`) — données déjà présentes
- _Rationale : te rend voyant pendant le test._

### Thème C — Qualité & coût — pont vers Story 7.5 (3e)
- Inspecter fiches générées d'un collège (recto/verso/type/rang) — NEW
- Vue feedback testeuse (`TesterFeedback` non pertinents) — NEW
- Conso tokens cloud + coût € par import/user/global — NEW (ajout backend : persister `response.usage` par job)
- _Rationale : c'est ici qu'on juge le prompt 7.5._

### Transverses
- Overview KPI (users, jobs par statut, jobs `failed`) — NEW
- Détecteur de blocage (dérivé de B + quota, pas un écran séparé)

**Ajouts backend à prévoir dans la story :** (1) persister une timeline d'événements de traitement par job ; (2) persister l'usage tokens Anthropic (`response.usage`) par `GenerationJob`.

## Session Summary and Insights

**Décisions clés :**
- Story 7.6 « Dashboard admin (API + vue web) », formelle, dans Epic 7, AVANT le re-test 7.5.
- Périmètre = tout en v1 (Project Lead pas pressé pour le test → console admin complète d'un coup).
- Gap bloquant confirmé n°1 : create-user admin.
- Logs : historique persisté consultable suffit (refresh couvre le « pendant ») — pas de live SSE.

**Prochaine étape workflow :** [CC] `bmad-correct-course` (slotter 7.6 dans `epics-v1.1.md` + `sprint-status.yaml`) → [CS] `bmad-create-story 7.6` → [DS] dev + [CR] review. Ce doc de session sert d'input de périmètre.

_Session courte et orientée décision : Role Playing (besoins par acteur) → Resource Constraints (arbitrage périmètre). 9 idées + socle, regroupées en 3 thèmes séquençables._

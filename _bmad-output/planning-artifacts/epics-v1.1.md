---
stepsCompleted: ['step-01-inventory', 'step-02-stories-design']
status: ready-for-dev
createdAt: '2026-05-19'
parentEpics: '_bmad-output/planning-artifacts/epics.md'
inputDocuments:
  - '_bmad-output/planning-artifacts/prd.md'
  - '_bmad-output/planning-artifacts/architecture.md'
  - '_bmad-output/implementation-artifacts/epic-mvp-retro-2026-05-19.md'
  - '_bmad-output/implementation-artifacts/deferred-work.md'
scope: 'V1.1 — Hardening pré-beta + 4 retours testeuse (Phase 0 validée). Itération de correction et durcissement, vision produit inchangée vs PRD MVP.'
---

# AppMédecine — Epic V1.1 "Hardening + Retours Beta"

## Overview

Ce document décrit l'**Epic 7 : Hardening & Retours Beta**, qui prolonge le MVP (epics 1→6 livrés le 2026-05-18 et validés Phase 0 par la testeuse) en intégrant :

1. **4 retours utilisateurs immédiats** (R1-R4) issus du test sur iPhone par la testeuse
2. **9 items techniques** issus de la rétrospective MVP (`epic-mvp-retro-2026-05-19.md`) priorisés "async correctness"
3. **Dette infrastructure pré-prod** à régulariser avant l'élargissement de la beta
4. **1 retour différé** (R5 : prompt persona Claude) qui sera kické-off après que la testeuse ait terminé son collège actuel

Le PRD MVP reste la **vision produit** ; cet epic est une itération de hardening + UX fixes, pas une extension de scope.

## Inherited Requirements

Tous les **FR1-FR50**, **NFR1-NFR12** et **UX-DR1-UX-DR18** du MVP restent en vigueur (cf. `_bmad-output/planning-artifacts/epics.md`). Cet epic n'introduit **aucun nouveau FR/NFR/UX-DR**, mais :

- Renforce la **conformité NFR8** (atomicité quotas) et **NFR10** (résilience JWT/SSE)
- Corrige des **violations UX-DR mineures** (flip carte définition sans réponse — viole UX-DR9 ; démo s'affiche pour user loggé — viole UX-DR5)
- Ajoute une **préférence optionnelle** (chronomètre par carte — extension cosmétique de FR24, hors scope FR/NFR formel)

## Context — Source des items

### Retours testeuse (R1-R5)

Source : 1 testeuse (la sœur du développeur), test sur iPhone du développeur prêté, période MVP-validation (entre 2026-05-08 et 2026-05-19). Phase 0 du PRD formellement validée.

| ID | Type | Résumé |
|---|---|---|
| R1 | Feature | Chronomètre count-down par carte, activable/désactivable au milieu d'une session |
| R2 | Bug ergonomique | Re-flip de la carte impossible après avoir vu la réponse (tant qu'aucune évaluation cliquée) |
| R3 | Bug router | Écran démo s'affiche même quand l'utilisateur est authentifié |
| R4 | Bug UX critique | Cartes "définition" (avec input texte) retournables sans avoir répondu |
| R5 | Qualité contenu | Prompt persona Claude trop verbeux — fiches à rendre plus synthétiques et techniques. **Différé.** |

### Items techniques rétro (A1-A10)

Source : `epic-mvp-retro-2026-05-19.md` — priorité agreed par le Project Lead = **async correctness**. Items A8 retiré (rate limits déjà en place depuis 2026-05-08). Item A7 fermé (faux problème, mitigé par `get_current_user`).

| ID | Sévérité beta | Résumé |
|---|---|---|
| A1 | 🔴 HAUTE | Atomicité compteurs `reload_count` / `monthly_reloads` (race condition possible) |
| A2 | 🔴 HAUTE | Cascade DELETE /account côté Flutter non-atomique (backend rate limit déjà OK) |
| A3 | 🟠 MOYENNE | Rate limit search keyed sur IP (NAT partagé → 429 collectif) |
| A4 | 🟠 MOYENNE | Race OCR : 2 jobs `processing` parallèles possibles (pas de contrainte UNIQUE) |
| A5 | 🔴 HAUTE | Cron monthly reset jamais implémenté (compteurs deviennent permanents) |
| A6 | 🟠 MOYENNE | JWT figé au reconnect SSE (access token expire en 30 min, SSE max 3h) |
| A9 | 🟠 MOYENNE | Timeout client `evaluateSemantic` 5s < latence Claude réelle |
| A10 | 🟡 PERF | APNs `NotificationService` instancié à chaque push (devrait être singleton) |

### Dette infrastructure pré-prod

Source : `deferred-work.md` (Story 1.1 review) — items pré-existants devenus bloquants à l'approche du lancement.

- Validators Pydantic au démarrage : refuse `claude_api_key=""`, `secret_key < 32 chars`, `admin_password="change-me"` en mode prod
- Ports Redis (6379) et PostgreSQL (5432) à restreindre à `127.0.0.1:` ou à retirer dans `docker-compose.prod.yml`

> **Note :** Caddy Let's Encrypt + domaine public déjà en place sur `collegatest.matthislesur.com`.

### Tâches opérationnelles (P3 — hors stories de dev)

Ces items sont des actions du Project Lead, pas des stories techniques :

- **OP-1** Setup TestFlight (provisioning, certificats Apple, build release iOS) — optionnel tant qu'une seule testeuse, devient bloquant pour élargir
- **OP-2** Validation IAP RevenueCat sandbox end-to-end (Apple ID sandbox + achat réel + observation webhook) — bloquant lancement payant post-beta
- **OP-3** Dogfooding solo ≥ 5 jours sur iPhone après mergeur des stories S1-S3 — avant d'inviter d'autres testeuses

---

## Epic List

### Epic 7 : Hardening & Retours Beta

L'application est hardenisée pour supporter plusieurs utilisatrices concurrentes (atomicité quotas, rate limits par user, RGPD safe-delete) et intègre les corrections UX/router révélées par la testeuse Phase 0. La qualité des fiches générées sera traitée séparément (Story 7.5) une fois que la testeuse aura terminé son collège actuel.

**Items couverts :** R1, R2, R3, R4, R5 (différé), A1, A2, A3, A4, A5, A6, A9, A10, dette infra pré-prod
**Nouveau périmètre ajouté (2026-06-16) :** Stories 7.6-7.8 — Dashboard admin (API + vue web), découpé par thème A/B/C, prérequis du re-test 7.5 (source : brainstorm `brainstorming-session-2026-06-16-2242.md`)
**Items déjà adressés (hors scope) :** A7 (mitigé par pattern), A8 (rate limits déjà en place)
**Tâches opérationnelles parallèles :** OP-1, OP-2, OP-3

---

## Epic 7 : Hardening & Retours Beta

Cet epic regroupe en **8 stories** les corrections nécessaires avant l'élargissement de la beta au-delà de la testeuse actuelle. Les stories 7.1-7.5 sont groupées par **zone de modification** (frontend Flutter / backend Python / infra) pour minimiser les conflits de merge ; les **stories 7.6-7.8 (Dashboard admin)** ont été ajoutées le 2026-06-16 (via `correct-course`) — la console admin, prérequis du re-test du prompt persona (Story 7.5) sur base prod wipée, est découpée en 3 stories séquençables par thème (A → B → C), périmètre v1 complet conservé.

**Effort total estimé :** ~2.5j de dev sur S1-S4 + ~0.5j sur S5 différée + ~3.5-4j sur S6-S8 (console admin, 3 stories par thème — estimation provisoire à affiner au `create-story`).

### Story 7.1 : Corrections UX FlashCard & Router

**Couvre :** R2, R3, R4
**Composants :** `FlashCard` (Story 4.1), `app_router.dart` (Story 2.2 + 2.3)

En tant qu'**étudiante en médecine**,
je veux que les interactions avec les flashcards soient cohérentes et que la démo ne réapparaisse pas après inscription,
afin de ne pas être bloquée ou déroutée par des comportements non-intentionnels lors de mes révisions.

**Critères d'acceptance :**

**Étant donné** une carte de type "définition" (avec input texte) affichée recto en Mode Drill
**Quand** je tape sur la carte sans avoir soumis ma réponse via le champ texte
**Alors** la carte **ne se retourne pas**
**Et** un indicateur visuel (ex : `TapHint` discret ou bordure du champ texte) rappelle qu'il faut soumettre la réponse pour voir le verso

**Étant donné** une carte (classique ou définition) déjà retournée en Mode Drill
**Quand** je tape à nouveau sur la carte (avant d'avoir cliqué sur À revoir / Bien / Maîtrisé)
**Alors** la carte se retourne à nouveau vers le recto
**Et** je peux re-flip autant de fois que nécessaire tant qu'aucun bouton d'évaluation n'a été cliqué
**Et** dès qu'un bouton d'évaluation est cliqué, le flip se désactive (la carte glisse hors écran selon le pattern existant)

**Étant donné** un utilisateur authentifié (token valide en `flutter_secure_storage`)
**Quand** l'app démarre ou que le router évalue la route initiale
**Alors** la route `/demo` redirige **immédiatement** vers `/home` (jamais l'écran démo n'est affiché)
**Et** la route `/demo` reste accessible uniquement si l'utilisateur n'est pas authentifié

**Étant donné** un utilisateur authentifié qui tape l'URL `/demo` manuellement (cas iOS deep link)
**Quand** le router applique sa logique `redirect`
**Alors** la redirection se fait vers `/home` sans flash visuel de l'écran démo

**Tasks/Subtasks :**

- [ ] T1 — Ajouter un état `hasSubmittedAnswer: bool` dans `FlashCardState` pour les cartes définition + guard sur le `onTap` qui bloque le flip tant que `false`
- [ ] T2 — Modifier `FlashCard` pour permettre le flip bidirectionnel (retournement multiple) tant que `evaluation == null` dans le `DrillSessionNotifier`
- [ ] T3 — Ajouter dans `app_router.dart` une règle `redirect` qui vérifie `authProvider.isAuthenticated` ET la route cible == `/demo` → redirect vers `/home`
- [ ] T4 — Tests widget : 1 test pour le blocage flip carte définition sans réponse, 1 test pour le flip bidirectionnel, 1 test pour la redirection `/demo` → `/home` quand authentifié

---

### Story 7.2 : Hardening Async Backend (Atomicité Quotas, Rate Limit User, Race OCR)

**Couvre :** A1, A3, A4, A5, A6, A9
**Composants :** `colleges.py`, `search.py`, `sse_client.dart`, `card_evaluation.dart`, migrations Alembic

En tant que **développeur backend**,
je veux éliminer les race conditions et les limites manquantes qui ne se manifestent qu'en charge concurrente,
afin que l'app supporte sans incident les 5+ utilisatrices simultanées de la beta élargie.

**Critères d'acceptance :**

**Étant donné** deux requêtes de réimport concurrentes pour le même collège (ou pour deux collèges du même user dans la même seconde)
**Quand** elles tentent toutes deux d'incrémenter `reload_count` et `monthly_reloads`
**Alors** l'incrémentation utilise un seul statement SQL atomique : `UPDATE colleges SET reload_count = reload_count + 1 WHERE id = :id AND reload_count < :max RETURNING reload_count`
**Et** au moins une des deux requêtes échoue avec `429 RELOAD_LIMIT_REACHED` si la limite serait dépassée
**Et** aucun cas où les deux requêtes réussissent en faisant dépasser `reload_count > max`

**Étant donné** le 1er du mois UTC à 00:00
**Quand** le worker ARQ `cleanup_worker.py` exécute son cron quotidien
**Alors** une nouvelle fonction `reset_monthly_reloads` met à zéro `monthly_reloads` sur tous les `users` dont `monthly_reloads_reset_at < now - 30 days`
**Et** met à jour `monthly_reloads_reset_at = now`
**Et** un test d'intégration vérifie qu'après le reset, l'utilisateur peut à nouveau lancer 3 réimports

**Étant donné** un utilisateur authentifié appelant `GET /v1/search?q=...`
**Quand** il dépasse 30 requêtes par minute
**Alors** le rate limiting utilise `key_func=lambda req: req.state.user_id` au niveau du décorateur `@limiter.limit("30/minute", key_func=...)`
**Et** le `Limiter` global dans `app/core/limiter.py` reste sur `_get_client_ip` pour ne pas casser `/login` (5/min) et `DELETE /account` (3/min)

**Étant donné** deux requêtes `POST /v1/admin/colleges/{college_id}/process` concurrentes sur le même collège
**Quand** elles s'exécutent en parallèle
**Alors** la base PostgreSQL applique une contrainte `CREATE UNIQUE INDEX idx_one_processing_per_college ON generation_jobs (college_id) WHERE status = 'processing'`
**Et** la deuxième requête échoue avec `409 JOB_ALREADY_PROCESSING`
**Et** une migration Alembic `010_atomic_quota_and_unique_processing.py` ajoute la contrainte sans data loss

**Étant donné** une connexion SSE active depuis `sse_client.dart` ouverte depuis > 30 minutes (access token expiré)
**Quand** le client se déconnecte (background app, perte réseau, etc.) et tente de se reconnecter
**Alors** avant la reconnexion, le client appelle `authProvider.refreshAccessToken()` pour obtenir un nouveau JWT
**Et** la nouvelle connexion SSE utilise le token rafraîchi (passé via header `Authorization` ou query param selon l'implémentation actuelle)
**Et** si le refresh échoue (refresh token expiré aussi), l'utilisateur est redirigé vers `/login`

**Étant donné** un appel `POST /v1/flash-cards/{id}/evaluate-semantic` depuis Flutter
**Quand** Claude met plus de 5s à répondre (cas observé en pratique)
**Alors** le timeout Dio client est augmenté à 15s
**Et** en cas de timeout, le client retente une fois avant de basculer sur le fallback flip classique
**Et** un test mock vérifie ce comportement (timeout → retry → fallback)

**Tasks/Subtasks :**

- [ ] T1 — Migration Alembic `010_atomic_quota_and_unique_processing.py` (contrainte UNIQUE partial index + colonne `monthly_reloads_reset_at` si absente)
- [ ] T2 — Refactor `_increment_reload_counters` (ou équivalent) dans `colleges.py` en `UPDATE ... RETURNING` atomique
- [ ] T3 — Ajouter `reset_monthly_reloads` dans `cleanup_worker.py` + cron quotidien ARQ
- [ ] T4 — Modifier le décorateur `@limiter.limit` sur `GET /search` pour `key_func=user_id`
- [ ] T5 — Modifier `sse_client.dart` : appel `refreshAccessToken()` avant chaque tentative de reconnexion + fallback redirect `/login`
- [ ] T6 — Augmenter le timeout `evaluateSemantic` à 15s + retry 1× dans `flash_card_repository.dart` (ou équivalent)
- [ ] T7 — Tests : 2 tests d'atomicité quotas (parallèles), 1 test unique constraint OCR, 1 test cron monthly reset, 1 test rate limit search par user, 1 test SSE refresh-then-reconnect, 1 test timeout retry évaluation sémantique

---

### Story 7.3 : Hardening RGPD Safe-Delete & Sécurité Config

**Couvre :** A2, dette infra pré-prod (validators config + ports exposés)
**Composants :** `auth_providers.dart` (Story 6.2), `app/core/config.py`, `docker-compose.prod.yml`

En tant que **développeur**,
je veux que la suppression de compte soit atomique côté client et que la configuration prod refuse de démarrer avec des valeurs par défaut faibles,
afin de garantir conformité RGPD (aucun état zombie) et zéro déploiement prod avec credentials par défaut.

**Critères d'acceptance :**

**Étant donné** un utilisateur cliquant "Supprimer mon compte" depuis l'écran Profil
**Quand** la requête `DELETE /v1/account` est envoyée mais que le réseau timeout / 5xx
**Alors** Flutter ne nettoie **pas** `flutter_secure_storage` ni `AppDatabase.deleteEverything()` localement
**Et** l'utilisateur voit un toast `ShadToast.destructive` "Suppression échouée, réessaie" et reste sur l'écran Profil avec sa session intacte
**Et** s'il clique à nouveau, la requête est retentée (et soumise au rate limit backend de 3/min)

**Étant donné** la requête `DELETE /v1/account` qui réussit (200)
**Quand** Flutter procède au nettoyage local
**Alors** la séquence est : (1) `Purchases.logOut()` RevenueCat → (2) `AppDatabase.deleteEverything()` Drift → (3) `secureStorage.deleteAll()` → (4) `authNotifier.logout()` → (5) redirect `/welcome`
**Et** si l'une des étapes locales échoue, un toast d'erreur s'affiche mais la suite continue (compte déjà supprimé serveur, on tente de nettoyer au mieux)
**Et** un test d'intégration vérifie le happy path et le path d'erreur (network timeout, 5xx)

**Étant donné** le démarrage du backend en mode `ENVIRONMENT=production`
**Quand** `Settings()` est instancié depuis `app/core/config.py`
**Alors** un validator Pydantic refuse de démarrer si :
- `claude_api_key == ""` ou absent
- `secret_key.length < 32`
- `admin_password == "change-me"` ou vide
**Et** le serveur log un message explicite indiquant la variable d'environnement manquante avant `exit(1)`

**Étant donné** le mode `ENVIRONMENT=development`
**Quand** `Settings()` est instancié
**Alors** les validators sont relâchés (warning au lieu d'exit) pour permettre le dev local sans friction

**Étant donné** le fichier `docker-compose.prod.yml`
**Quand** je l'inspecte
**Alors** les services `db` et `redis` n'ont **pas** de `ports:` exposés sur l'host (ou alors uniquement `127.0.0.1:5432` / `127.0.0.1:6379`)
**Et** uniquement les services `api` et `caddy` exposent leurs ports nécessaires

**Tasks/Subtasks :**

- [ ] T1 — Ajouter try/catch dans `AuthNotifier.deleteAccount()` Flutter avec rollback explicite si l'appel HTTP échoue
- [ ] T2 — Test d'intégration `delete_account_test.dart` mockant Dio en timeout → assertion app reste loggée
- [ ] T3 — Test happy path : assertion séquence RC.logOut → Drift wipe → secureStorage wipe → logout → redirect `/welcome`
- [ ] T4 — Ajouter validators Pydantic dans `app/core/config.py` (mode-aware via `Settings.environment`)
- [ ] T5 — Tests unitaires des validators (test startup raise en prod, warning en dev)
- [ ] T6 — Mettre à jour `docker-compose.prod.yml` pour supprimer/restreindre les ports `db` et `redis`
- [ ] T7 — Vérifier que le NAS prod (`/mnt/user/appdata/compose-stacks/collega/.env` selon mémoire) a bien `secret_key` ≥ 32 chars et `admin_password` non-défaut **avant** de merger les validators

---

### Story 7.4 : Chronomètre Drill + APNs Singleton + Docs

**Couvre :** R1, A10, doc gotchas SDK, doc CGU/privacy
**Composants :** `FlashCard` + `DrillScreen` (4.1, 4.2), `RevisionPrefs` (6.1), `main.py` lifespan, `docs/`

En tant qu'**étudiante en médecine**,
je veux pouvoir activer un chronomètre avec limite de temps par carte pour me forcer à répondre rapidement (mode examen),
afin de m'entraîner dans des conditions plus proches de la pression réelle de l'ECN.

En tant que **développeur**,
je veux que le service APNs soit instancié une seule fois au démarrage et que les gotchas SDK soient documentées,
afin d'éviter une perte de perf à chaque notification et de ne plus repayer les ~1-2h de debug sur les pièges connus.

**Critères d'acceptance :**

**Étant donné** l'écran Profil → RevisionPrefsCard
**Quand** l'utilisatrice active le toggle "Chronomètre" et choisit une durée (par exemple via un stepper : 15s / 30s / 60s / 120s)
**Alors** la préférence est persistée dans `RevisionPrefs` (et sync `secure_storage`)
**Et** la prochaine session drill applique ce timer

**Étant donné** une session drill en cours avec chronomètre activé
**Quand** une carte est affichée recto
**Alors** un timer count-down visible (ex : ring discret en haut à droite de la carte) commence à décrémenter dès l'affichage
**Et** si le timer atteint 0 avant que la carte soit retournée, la carte est **auto-flip** sur le verso (l'utilisatrice voit la réponse) ET un bandeau `ShadToast` neutre indique "Temps écoulé" — l'évaluation reste manuelle (pas d'éval auto-"À revoir")

**Étant donné** une session drill en cours avec chronomètre activé
**Quand** l'utilisatrice tape sur un bouton "Pause" / "Stop chrono" intégré au header du Drill (icône horloge)
**Alors** le timer est désactivé pour le reste de la session (n'affecte pas les sessions suivantes)
**Et** elle peut le réactiver via le même bouton

**Étant donné** une carte définition avec chronomètre activé
**Quand** le timer expire avant soumission de la réponse
**Alors** le timer auto-soumet une réponse vide et auto-flip vers le verso (respecte le contrat R4 de Story 7.1 : pas de flip sans réponse, l'auto-submit compte comme une réponse explicite "sans réponse")

**Étant donné** le démarrage du backend FastAPI
**Quand** le `lifespan` context démarre
**Alors** une seule instance `APNsNotificationService` est créée et stockée dans `app.state.notification_service`
**Et** `get_notification_service()` retourne cette instance unique (singleton)
**Et** au shutdown, la connexion HTTP/2 vers APNs est proprement fermée

**Étant donné** le fichier `docs/sdk-gotchas.md` n'existe pas encore
**Quand** la story est terminée
**Alors** le fichier existe et documente : (1) `shadcn_ui 0.19.x` ShadSkeleton absent, (2) Dio intercepteur boucle infinie + pattern `_refreshDio` séparé, (3) `flutter_apns_only 1.6.0` signature `ApnsRemoteMessage` vs doc, (4) RevenueCat webhook timing async + pattern polling `/auth/me`

**Étant donné** que FR40 exige des CGU et une politique de confidentialité accessibles depuis l'app
**Quand** la story est terminée
**Alors** les deux documents finalisés existent dans `docs/legal/cgu.md` et `docs/legal/privacy.md` (en français, validés par le Project Lead)
**Et** les liens dans l'écran Profil (Story 6.2) pointent vers ces fichiers (ou vers une page web hébergée si décision prise)

**Tasks/Subtasks :**

- [ ] T1 — Étendre `RevisionPrefs` (modèle + repository) avec `timerEnabled: bool` et `timerDurationSeconds: int` (default 30)
- [ ] T2 — Ajouter UI toggle + stepper "Chronomètre" dans `RevisionPrefsCard` (écran Profil)
- [ ] T3 — Intégrer le widget `TimerRing` dans `FlashCard` (recto uniquement, masqué si verso)
- [ ] T4 — Logique auto-flip + toast "Temps écoulé" dans `DrillSessionNotifier`
- [ ] T5 — Bouton pause/stop chrono dans `DrillHeader` + state local à la session
- [ ] T6 — Refactor `get_notification_service` en singleton via `app.state` + cleanup au shutdown
- [ ] T7 — Tests : 1 test timer count-down avec auto-flip, 1 test pause durant session, 1 test persistance pref, 1 test singleton APNs
- [ ] T8 — Rédiger `docs/sdk-gotchas.md`
- [ ] T9 — Rédiger / valider CGU + politique de confidentialité

---

### Story 7.5 : Affinage du Prompt Persona Claude [DIFFÉRÉ]

> **Statut :** Différé. À démarrer après que la testeuse Phase 0 ait terminé son collège actuel (cf. décision Project Lead du 2026-05-19). Pas avant.

**Couvre :** R5
**Composants :** `card_generator.py` + prompts dans `app/services/generation/`

En tant qu'**étudiante en médecine**,
je veux que les fiches générées par Claude soient plus synthétiques et techniques (pas de questions trop longues, pas de réponses verbeuses),
afin de pouvoir réviser efficacement en sessions courtes sans être ralentie par la lecture.

**Critères d'acceptance :**

**Étant donné** le prompt persona actuel dans `card_generator.py`
**Quand** il est inspecté et comparé au feedback testeuse (questions trop longues, réponses trop travaillées)
**Alors** un nouveau prompt persona est proposé avec :
- Instructions explicites de synthèse (longueur cible : question ≤ 15 mots, réponse ≤ 40 mots pour flashcards classiques)
- Ton technique direct (vocabulaire médical assumé, pas de paraphrase pédagogique)
- Exemples few-shot mis à jour (3-5 exemples "bons" vs 1-2 "mauvais" pour ancrer)

**Étant donné** le nouveau prompt déployé en backend
**Quand** un nouveau collège est traité (ou un collège existant est réimporté via le quota normal de la testeuse)
**Alors** les fiches générées respectent les longueurs cibles dans ≥ 80% des cas (mesure : test sur 50 fiches échantillon)
**Et** la testeuse valide qualitativement la nouvelle qualité sur son re-import

**Étant donné** la décision prospectif uniquement (cf. décision 2026-05-19)
**Quand** le prompt change
**Alors** **aucune régénération automatique** des fiches existantes — seules les nouvelles générations (ou réimports via quota user) utilisent le nouveau prompt
**Et** les fiches existantes restent inchangées dans la base

**Tasks/Subtasks (à finaliser au kick-off de la story) :**

- [ ] T1 — Audit du prompt actuel + collecte d'exemples concrets de fiches "trop longues" depuis la testeuse
- [ ] T2 — Itération sur le nouveau prompt en bench Claude (sample de 5 items réels)
- [ ] T3 — Déploiement backend (pas de migration DB nécessaire)
- [ ] T4 — Re-import par la testeuse (consomme 1 reload de son quota)
- [ ] T5 — Validation qualitative + mesure de longueur sur 50 fiches échantillon

---

## Dashboard Admin (Stories 7.6 → 7.8)

> **Périmètre & source :** console admin (API + vue web) actée le 2026-06-16 via `correct-course`. Source de périmètre : `_bmad-output/brainstorming/brainstorming-session-2026-06-16-2242.md`. Décision Project Lead : **périmètre complet en v1** (pas de découpe MVP/v2). Le périmètre est **livré en 3 stories séquençables par thème (A → B → C)** — la découpe ne réduit pas le scope, elle réduit la taille de chaque story et permet de débloquer l'onboarding (7.6) avant le reste.
> **Composants partagés :** backend `app/api/v1/admin/` — étend l'API admin existante (`list users`, `toggle beta`, `queue génération`, `stats collège`, `config anti-spam`) ; **vue web admin** (réutilise le pattern de l'interface admin web Phase 0, Story 1.4) ; modèles réels `User` / `College` / `Item` / `FlashCard` / `GenerationJob` / `TesterFeedback`.
> **Séquencement vs Story 7.5 :** le re-test du prompt persona (7.5) est gated sur **7.6 + 7.7 + 7.8 done** (la console complète sert à onboarder la testeuse ET à juger la qualité/coût du nouveau prompt). 7.6 (onboarding) est le hard-blocker pour *démarrer* ; 7.8 (qualité/coût) est le *pont* d'évaluation du prompt.

### Story 7.6 : Dashboard Admin — Onboarding & Gestion Users (Thème A)

**Couvre :** Nouveau périmètre V1.1 — socle de la console admin. **Hard-blocker du re-test 7.5** : sans create-user admin, impossible d'onboarder la testeuse (base prod wipée, `register` = 403).
**Composants :** backend `app/api/v1/admin/` (users) ; vue web admin (écrans users + accueil console).
**Ajout backend :** aucun nouveau modèle DB (réutilise `User` / `College` / `GenerationJob`).

En tant que **Project Lead / admin**,
je veux créer et gérer les comptes utilisateurs depuis une console admin avec un overview d'entrée,
afin d'onboarder une testeuse sur une base prod wipée et d'avoir un point d'entrée unique sans toucher à psql.

**Critères d'acceptance :**

**Étant donné** une base prod wipée où `POST /v1/register` renvoie 403 par design
**Quand** l'admin appelle `POST /v1/admin/users` (email + mot de passe + flag `is_beta` optionnel) depuis la vue web
**Alors** un compte testeuse est créé en quelques secondes, avec `is_beta=true` si demandé (bypass paywall)
**Et** l'admin peut a posteriori toggler `is_beta` (route existante) et **reset le quota** `monthly_reloads` d'un user

**Étant donné** la liste des users (route existante)
**Quand** l'admin ouvre le **détail d'un user** (NEW)
**Alors** il voit ses collèges, ses `GenerationJob`, son quota (`reload_count` / `monthly_reloads`) et son statut beta

**Étant donné** l'écran d'accueil de la console
**Quand** l'admin l'ouvre
**Alors** un **overview KPI** affiche : nombre de users, jobs par statut, jobs `failed` (point d'entrée de la console)

**Tasks/Subtasks (à finaliser au `create-story` 7.6) :**

- [ ] T1 — Backend : `POST /v1/admin/users` (create-user) + endpoint reset quota `monthly_reloads` + endpoint détail user (collèges/jobs/quota)
- [ ] T2 — Backend : endpoint overview KPI (users, jobs par statut, jobs `failed`)
- [ ] T3 — Vue web admin : écran accueil (overview KPI) + liste/détail user + actions create-user / toggle beta / reset quota
- [ ] T4 — Tests backend : create-user (incl. 403 `register` toujours fermé), reset quota, détail user, agrégation KPI overview

---

### Story 7.7 : Dashboard Admin — Suivi & Contrôle des Imports (Thème B)

**Couvre :** Nouveau périmètre V1.1 — observabilité + contrôle du pipeline d'import. Te rend « voyant » pendant le test.
**Composants :** backend `app/api/v1/admin/` (jobs) + pipeline OCR/génération (instrumentation) + worker ARQ ; vue web admin (écrans imports/jobs).
**Ajout backend nouveau :** persister une **timeline d'événements de traitement** par `GenerationJob` (étapes OCR page X/Y, génération, succès/erreur — consultable à la demande, refresh couvre le « pendant », **pas de live SSE**).

En tant que **Project Lead / admin**,
je veux suivre l'avancement réel d'un import et pouvoir l'arrêter ou le supprimer,
afin de détecter et débloquer une testeuse coincée sans fouiller les logs NAS / Redis.

**Critères d'acceptance :**

**Étant donné** un import en cours ou terminé
**Quand** l'admin ouvre le détail du `GenerationJob`
**Alors** il voit la **timeline persistée** des étapes (OCR page X/Y, génération, erreur) lisible au refresh
**Et** le **détail brut** du job (`arq_job_id`, `pdf_hash`, `hash_shared`, timestamps, `error_message`) — debug sans Redis/psql
**Et** la **confiance OCR par item** (`ocr_confidence_score` / `low_confidence`) pour distinguer mauvais OCR vs mauvais prompt

**Étant donné** un import problématique (job `failed`, planté, ou à annuler)
**Quand** l'admin clique **Stop** ou **Delete**
**Alors** Stop annule le job ARQ en cours ; Delete supprime l'import **et** les fiches associées

**Étant donné** une testeuse potentiellement bloquée
**Quand** l'admin consulte la console
**Alors** un **détecteur de blocage** (dérivé : quota atteint / job `failed` / import jamais terminé) la signale — pas un écran séparé

**Tasks/Subtasks (à finaliser au `create-story` 7.7) :**

- [ ] T1 — Backend (ajout DB) : modèle/table **timeline d'événements** par `GenerationJob` + migration Alembic + écriture des étapes dans le pipeline OCR/génération + endpoint lecture
- [ ] T2 — Backend : endpoints **stop** (annuler job ARQ) + **delete** (import + fiches) ; endpoint détail brut job ; exposer `ocr_confidence_score` par item
- [ ] T3 — Vue web admin : écran liste/détail imports (timeline, détail brut, confiance OCR) + actions stop/delete + indicateur de blocage
- [ ] T4 — Tests backend : écriture+lecture timeline, stop job ARQ, delete import+fiches, exposition confiance OCR

---

### Story 7.8 : Dashboard Admin — Qualité & Coût (Thème C, pont vers 7.5)

**Couvre :** Nouveau périmètre V1.1 — c'est ici qu'on **juge le prompt 7.5** (qualité des fiches + coût de génération).
**Composants :** backend `app/api/v1/admin/` (fiches / feedback / usage) + pipeline génération (capture usage) ; vue web admin (écrans qualité/coût).
**Ajout backend nouveau :** persister l'**usage tokens Anthropic** (`response.usage`) par `GenerationJob` pour le suivi conso + coût €.

En tant que **Project Lead / admin**,
je veux inspecter les fiches générées, le feedback testeuse et le coût en tokens,
afin de juger la qualité et le coût du nouveau prompt persona (7.5) sur un re-import réel.

**Critères d'acceptance :**

**Étant donné** un collège lié à un user
**Quand** l'admin inspecte les **fiches générées** (recto / verso / type / rang)
**Alors** il peut juger qualitativement la sortie du prompt 7.5

**Étant donné** les `TesterFeedback` « non pertinents » remontés par la testeuse
**Quand** l'admin ouvre la **vue feedback**
**Alors** il voit le signal qualité n°1 du prompt 7.5

**Étant donné** que `response.usage` est désormais persisté par job
**Quand** l'admin consulte la **conso tokens**
**Alors** il voit tokens + coût € agrégés par import / par user / global

**Tasks/Subtasks (à finaliser au `create-story` 7.8) :**

- [ ] T1 — Backend (ajout DB) : persister `response.usage` Anthropic par `GenerationJob` + migration Alembic + capture dans le pipeline génération
- [ ] T2 — Backend : endpoints inspection fiches d'un collège + lecture `TesterFeedback` + agrégation conso/coût € (import/user/global)
- [ ] T3 — Vue web admin : écran inspection fiches + vue feedback + tableau conso tokens/coût
- [ ] T4 — Tests backend : capture+agrégation usage tokens, inspection fiches, lecture feedback

---

### Story 7.9 : Refonte Auth Console Admin — Session-Token (cookie httpOnly) [DIFFÉRÉ post-beta]

**Origine :** item 6 de la code review de la Story 7.6 (2026-06-17). Ajoutée le 2026-06-17 (décision PL : tracer puis traiter en dernier / post-beta).
**Couvre :** durcissement de l'authentification de la console admin web. Aujourd'hui la console garde les identifiants HTTP Basic en mémoire JS (exfiltrables via XSS) ; le vecteur XSS a été clos en review 7.6, d'où le risque accepté pour la beta.
**Composants :** `app/deps.py` (nouvelle dépendance `get_admin_session`), `app/core/security.py` (token de session, réutilise l'infra JWT HS256 existante), `app/api/v1/admin.py` (login/logout), `app/static/admin/index.html` (migration cookie), `app/core/config.py`, tests admin.

En tant que **Project Lead / admin**,
je veux que la console admin s'authentifie via un session-token en cookie httpOnly + Secure + SameSite (login/logout, expiration, CSRF),
afin qu'un futur XSS ne puisse plus voler les identifiants admin et que la session expire proprement.

**Décisions à acter au kick-off (T0) :** cookie en remplacement de Basic ou cohabitation (recommandé : cohabiter pour conserver l'accès API/curl) ; niveau CSRF (`SameSite=Strict` seul vs token double-submit) ; durée d'expiration session.

> **Séquencement :** non bloquant, **post-beta**. Story contextée et prête : `7-9-refonte-auth-admin-session-token.md`.

- [ ] T0 — Décisions archi (cookie vs Basic, niveau CSRF, expiration)
- [ ] T1 — Token de session admin (`security.py`)
- [ ] T2 — Endpoints `POST /v1/admin/login` + `/logout`
- [ ] T3 — Dépendance `get_admin_session` (`deps.py`)
- [ ] T4 — Protection CSRF
- [ ] T5 — Migration console web (suppression creds/Basic en JS)
- [ ] T6 — Tests (login/logout/cookie/expiration + non-régression register 403)

---

## Annexes

### A. Tâches opérationnelles parallèles (P3 — Project Lead)

| ID | Tâche | Effort | Bloquant pour... |
|---|---|---|---|
| OP-1 | Setup TestFlight + build release iOS | M | Élargir la beta au-delà de la testeuse actuelle |
| OP-2 | Validation IAP RevenueCat sandbox end-to-end | M | Lancement payant post-beta |
| OP-3 | Dogfooding solo ≥ 5 jours sur ton iPhone après mergeur S1-S3 | — | Inviter d'autres testeuses |

### B. Items fermés sans story (à mettre à jour dans deferred-work.md)

| Item | Raison de fermeture |
|---|---|
| A7 — JWT non-révocable post-DELETE | Faux problème en pratique : `get_current_user` fait `db.get(User, user_uuid)` → 401 immédiat dès que l'user est supprimé. Aucune fenêtre de 5 min. |
| A8 — Rate limit register/login | Déjà en place (vérif 2026-05-19) : `/register` bloqué 403 par design, `/login` `@limiter.limit("5/minute")`, `DELETE /account` `3/minute`, `/regenerate` `10/hour`, `/notifications/*` `10/minute`. |

### C. Items différés Phase 2 (post-beta, non bloquants)

- Dark mode Flutter (`brightness: Brightness.light` hardcodé)
- Google Fonts offline bundle (`allowRuntimeFetching = false`)
- Multi-tester architecture (FK `tester_id` au lieu de string global)
- Hash-sharing v2 (algorithme fuzzy ~90% au lieu de SHA256 exact)
- Mode Raisonnement (Flashcard Chains)
- Magic strings d'évaluation → enum
- ~80 items de `deferred-work.md` à triager avant lancement payant

### D. Mapping items → stories

| Item source | Story |
|---|---|
| R1 chronomètre | 7.4 |
| R2 re-flip carte | 7.1 |
| R3 démo si loggé | 7.1 |
| R4 flip carte définition | 7.1 |
| R5 prompt persona | 7.5 (différé) |
| A1 atomicité reload | 7.2 |
| A2 cascade DELETE | 7.3 |
| A3 rate limit search | 7.2 |
| A4 race OCR | 7.2 |
| A5 cron monthly reset | 7.2 |
| A6 JWT figé SSE | 7.2 |
| A9 timeout evaluateSemantic | 7.2 |
| A10 APNs singleton | 7.4 |
| Validators config prod | 7.3 |
| Ports DB/Redis exposés | 7.3 |
| Wiki gotchas SDK | 7.4 |
| CGU + privacy (FR40) | 7.4 |
| Dashboard admin — onboarding & users + KPI (nouveau, 2026-06-16) | 7.6 |
| Dashboard admin — suivi & contrôle imports (nouveau, 2026-06-16) | 7.7 |
| Dashboard admin — qualité & coût / pont 7.5 (nouveau, 2026-06-16) | 7.8 |

---

**Validation Project Lead :** Lesurmatthis (2026-05-19)
**Prochaine action recommandée :** créer les fichiers de story implementables (`_bmad-output/implementation-artifacts/7-1-corrections-ux-flashcard-router.md`, etc.) via `bmad-create-story` skill, story par story dans l'ordre 7.1 → 7.2 → 7.3 → 7.4. Story 7.5 différée jusqu'à signal de la testeuse.

**Addendum 2026-06-16 (`correct-course`) :** Dashboard Admin (API + vue web) acté dans Epic 7, **découpé en 3 stories par thème** : **7.6** Onboarding & users (+ KPI), **7.7** Suivi & contrôle imports, **7.8** Qualité & coût (pont 7.5). Périmètre v1 complet conservé. Source de périmètre = brainstorm `brainstorming-session-2026-06-16-2242.md`. Prochaine action : `bmad-create-story 7.6` puis 7.7, 7.8. **Séquencement :** le re-test de la Story 7.5 est gated sur 7.6 + 7.7 + 7.8 done ; 7.6 (onboarding) est le hard-blocker pour démarrer.

---
stepsCompleted: ['step-01-validate-prerequisites', 'step-02-design-epics', 'step-03-create-stories', 'step-04-final-validation']
status: complete
completedAt: '2026-04-27'
inputDocuments:
  - '_bmad-output/planning-artifacts/prd.md'
  - '_bmad-output/planning-artifacts/architecture.md'
  - '_bmad-output/planning-artifacts/ux-design-specification.md'
scope: 'MVP uniquement — Phase 0 (validation pipeline) + Phase 1 (Flutter iOS/iPadOS). Exclus : Mode Raisonnement, dictée/phrase à compléter, Android Phase 2, fonctionnalités V2+'
---

# AppMédecine — Epic Breakdown

## Overview

Ce document fournit la décomposition complète en épics et stories pour AppMédecine, dérivée du PRD, de la spec UX et des décisions d'architecture — périmètre MVP uniquement (Phase 0 + Phase 1 iOS/iPadOS).

## Requirements Inventory

### Functional Requirements

FR1: L'utilisateur peut explorer l'app via une démo interactive avec un collège fictif et des fiches pré-chargées, sans créer de compte.
FR2: L'utilisateur peut ignorer la démo et accéder directement à l'inscription.
FR3: L'utilisateur peut créer un compte avec email et mot de passe.
FR4: L'utilisateur peut souscrire à un abonnement payant via l'in-app purchase App Store.
FR5: L'utilisateur ne peut pas accéder aux fonctionnalités principales sans abonnement actif.
FR6: L'utilisateur peut consulter le prix et la durée d'abonnement avant de confirmer l'achat.
FR7: L'utilisateur peut consulter la liste des 40 collèges médicaux prédéfinis dans l'app.
FR8: L'utilisateur peut importer un fichier PDF depuis son stockage local dans un collège sélectionné.
FR9: Le système extrait le texte de chaque page d'un PDF via OCR en tâche de fond, sans bloquer l'interface.
FR10: Le système reprend automatiquement le traitement OCR si interrompu.
FR11: Le système calcule un score de confiance OCR par item et affiche un badge d'alerte si la qualité est insuffisante.
FR12: Le système détecte automatiquement les items et chapitres du PDF côté backend.
FR13: L'utilisateur peut suivre la progression de l'import et de la génération en temps réel.
FR14: L'utilisateur peut re-importer un collège dans la limite de 2 re-traitements par collège et 3 re-traitements par mois. Le premier import est libre.
FR15: Le système bloque gracieusement les re-traitements au-delà des limites et informe l'utilisateur de la date de réinitialisation.
FR16: Le système génère des flashcards classiques (recto/verso) et des fiches définition à partir du texte OCR via l'API Claude.
FR17: Le système tague automatiquement chaque fiche avec le rang de l'item source (A, B ou C).
FR18: Le système détecte si un PDF importé correspond à un traitement existant et sert les fiches sans nouvel appel Claude.
FR19: L'utilisateur peut signaler une fiche comme pertinente ou non pertinente.
FR20: L'utilisateur peut déclencher la régénération d'une fiche signalée négativement, avec le feedback transmis en contexte à Claude.
FR21: L'utilisateur peut supprimer une fiche jugée non pertinente.
FR22: Le système synchronise automatiquement les fiches générées en cache local sur l'appareil.
FR23: L'utilisateur reçoit une notification push à la fin de la génération d'un collège.
FR24: L'utilisateur peut lancer une session de quiz (Mode Drill) en sélectionnant collèges, items et rangs.
FR25: Le système présente les fiches en spaced repetition à 3 niveaux (À revoir / Bien / Maîtrisé).
FR26: L'utilisateur évalue chaque fiche selon son niveau de mémorisation.
FR27: Le système ajuste la fréquence de présentation selon le niveau déclaré.
FR28: L'utilisateur accède aux fiches générées et lance des sessions de quiz sans connexion internet.
FR29: Le système évalue la réponse à une fiche définition par proximité sémantique plutôt que correspondance textuelle exacte.
FR30: L'utilisateur configure un planning d'apprentissage en sélectionnant collèges, items, dates et disponibilité quotidienne.
FR31: Le système génère un planning algorithmique local, priorisé par rang (A→B→C).
FR32: L'utilisateur consulte sa session du jour (items, rangs, nombre de fiches).
FR33: L'utilisateur marque une session comme effectuée ou la décale.
FR34: L'utilisateur consulte sa progression par collège et par rang.
FR35: L'utilisateur configure un rappel quotidien de révision à l'heure de son choix.
FR36: L'utilisateur effectue une recherche full-text sur l'ensemble de ses collèges importés.
FR37: Le système affiche les résultats avec le passage contextuel et le chapitre source.
FR38: L'utilisateur lance une session de révision directement depuis un résultat de recherche.
FR39: L'utilisateur supprime son compte et toutes ses données associées depuis l'app.
FR40: L'utilisateur consulte la politique de confidentialité et les CGU depuis l'app.
FR41: L'utilisateur accède à la gestion de son abonnement (annulation) depuis les paramètres iOS.
FR42: Le système valide le statut d'abonnement actif avant chaque appel à l'API Claude.
FR43: L'opérateur consulte l'état de la queue de génération (traitements en attente, statut, temps).
FR44: L'opérateur gère les accès beta (accès gratuit sans abonnement).
FR45: L'opérateur ajuste les limites anti-spam côté backend sans mise à jour de l'app.
FR46: L'opérateur surveille les statuts d'abonnement et les webhooks App Store.
FR47: L'opérateur déclenche manuellement la génération d'un collège via une interface admin web sécurisée.
FR48: L'opérateur consulte les statistiques de génération : nombre de fiches, score de confiance OCR par item, taux de similarité hash-sharing.
FR49: Le testeur (accès restreint par authentification) parcourt et interagit avec les fiches d'un collège généré via une interface web.
FR50: Le testeur signale chaque fiche comme pertinente ou non (feedback transmis à l'opérateur).

### NonFunctional Requirements

NFR1: La recherche full-text retourne des résultats en moins d'une seconde pour un utilisateur avec 10 collèges indexés.
NFR2: La génération complète d'un collège (OCR → détection items → fiches Claude) se termine en moins de 2 heures.
NFR3: Les sessions quiz répondent en moins de 100ms (données locales).
NFR4: L'app démarre et affiche l'écran principal en moins de 3 secondes sur un iPhone supporté.
NFR5: La clé API Claude n'est jamais incluse dans le bundle de l'app — exclusivement côté backend.
NFR6: Le statut d'abonnement est validé côté backend (receipt App Store) avant chaque appel Claude.
NFR7: Toutes les communications app ↔ backend transitent en HTTPS.
NFR8: Les données utilisateur sont stockées avec accès scopé par user_id — aucune donnée cross-user accessible.
NFR9: Le texte OCR est supprimé du backend après génération des fiches — rétention maximale : 24 heures.
NFR10: Si Claude API est indisponible, les demandes restent en queue et reprennent automatiquement — l'utilisateur est informé du délai.
NFR11: Si l'OCR est interrompu (background, crash), il reprend au dernier point de sauvegarde.
NFR12: Une panne backend n'empêche pas l'accès aux fiches synchronisées ni les sessions quiz en cours.

### Additional Requirements

- **Starter Flutter :** `flutter create --org=com.lesurmatthis --platforms=ios,android collega_app` — iOS 16+ minimum (Vision Framework), Android structure incluse mais non activée Phase 1.
- **Starter Backend :** Structure `collega_backend/` calquée sur full-stack-fastapi-template (FastAPI 0.115+, Python 3.11+, SQLAlchemy 2.0 async, asyncpg, Alembic, ARQ, Poetry).
- **Infrastructure :** Docker Compose homelab (services : `api`, `db` PostgreSQL 16, `redis`, `caddy`). Deux environnements : `dev` (local) + `prod` (homelab). Caddy assure TLS Let's Encrypt automatique (NFR7).
- **Queue de génération :** ARQ (async Redis queue) — workers `generation_worker.py` + `cleanup_worker.py`. Retry backoff sur indisponibilité Claude (NFR10).
- **Progression OCR temps réel :** SSE (Server-Sent Events) via `StreamingResponse` FastAPI + `sse_client.dart` Flutter. Format : `{ "event": "...", "data": { ... } }`.
- **Reprise OCR (NFR11) :** Colonne `ocr_page_progress` dans la table `colleges` (Drift) — reconnexion SSE au retour foreground via `GET /v1/colleges/{id}/status`.
- **Nettoyage OCR (NFR9) :** `cleanup_worker.py` ARQ cron — supprime `ocr_text` ≤ 24h après génération.
- **Hash-sharing v1 :** Interface abstraite `SimilarityChecker` — algorithme remplaçable sans refonte. Seuil similarité ~90% (à calibrer sur vrais PDFs).
- **Anti-spam configurables (FR45) :** Colonnes `reload_count` (max 2/collège) et `monthly_reloads` (max 3/mois) en base, valeurs max en `pydantic-settings` — modifiables sans redéploiement.
- **Auth :** JWT access token (courte durée) + refresh token (longue durée). Stockage Flutter : `flutter_secure_storage` (Keychain iOS). Accès beta : flag `is_beta: bool` sur le modèle `User`.
- **IAP :** RevenueCat SDK Flutter + webhook RevenueCat → backend `/v1/webhooks/revenuecat`. Validation abonnement côté backend avant chaque appel Claude (NFR6).
- **Push notifications Phase 1 :** APNs direct via `aioapns` (Python async). Couche `NotificationService` abstraite pour migration FCM Phase 2.
- **Évaluation sémantique (FR29) :** Appel Claude ciblé sur les fiches définition (pas d'embedding local).
- **Interface admin Phase 0 :** Routes FastAPI + templates Jinja2/HTML statique, sécurisée HTTP Basic Auth. Couvre FR47–FR50.
- **PostgreSQL GIN index :** Sur le texte des fiches pour full-text search < 1s (NFR1). Scoping applicatif par `user_id` sur toutes les requêtes (NFR8).
- **State management Flutter :** Riverpod (`flutter_riverpod` + `riverpod_annotation`). Pattern `AsyncNotifier` pour tout état async. Aucun provider bloquant dans `main.dart` (NFR4).
- **Navigation Flutter :** GoRouter — deep linking, type-safe.
- **Architecture Flutter :** Feature-first (`features/demo`, `auth`, `colleges`, `generation`, `drill`, `planning`, `search`, `profile`).
- **Stockage local Flutter :** SQLite + Drift — migrations typées, offline-first. `ocr_page_progress` persisté.
- **Conventions de nommage :** BDD snake_case/pluriel, API `/v1/` snake_case, Dart PascalCase/camelCase/snake_case fichiers, Python snake_case. Wrapper `{ "data": ... }` / `{ "error": ... }` sur toutes les réponses API. ISO 8601 UTC pour toutes les dates.
- **Patterns de qualité :** `ShadSkeleton` pour loading (jamais `CircularProgressIndicator`), `ShadToast` pour erreurs non-bloquantes, `ShadAlertDialog` pour erreurs bloquantes. Jamais de `print()` en production.

### UX Design Requirements

UX-DR1: Implémenter les 7 composants custom AppMédecine : `FlashCard` (recto/verso, animation retournement, variants classique/définition, badge rang, badge OCR), `DrillEvaluationBar` (3 boutons À revoir/Bien/Maîtrisé, visible uniquement après retournement, feedback haptique), `SessionHeroCard` (hero accueil, collège + rang + durée + CTA "Commencer" + bouton "Modifier" inline), `CollegeProgressTile` (barre 4 segments Maîtrisé/Bien/À revoir/Non vues), `OcrConfidenceBadge` (variants orange/rouge, icône + texte, ShadPopover au tap), `ItemProgressBar` (barre segmentée 3 couleurs avec chiffres), `SearchResultTile` (terme surligné, chapitre source, CTA "Réviser l'item").
UX-DR2: Appliquer le thème shadcn_ui avec la palette couleur : Primary `#1B6B3A`, Primary container `#B7F2C8`, Secondary teal `#3D6B5E`, Surface `#F8FAF9`, On surface `#1A1C1A`, Error `#BA1A1A`, Warning `#F0A500`. Rang A → primary vert, Rang B → teal, Rang C → gris neutre.
UX-DR3: Typographie Inter uniquement (6 niveaux : displayMedium 28sp/700 → labelMedium 12sp/500). Espacement base 8px, margin écran 16px, padding card 16px, border-radius cards 12px, boutons 8px.
UX-DR4: Implémenter les animations flutter_animate : retournement FlashCard (`.flip().fade()`), card "Maîtrisé" disparaît vers le haut (`.slideY().fade()`), card "À revoir" disparaît vers le bas, entrée progressive des fiches générées (`.fadeIn().slideX()`), transitions d'écran (`.animate().fade()`).
UX-DR5: Bottom navigation 4 tabs (Accueil · Collèges · Recherche · Profil) — masquée pendant Mode Drill, écran fin de session, écran import progress.
UX-DR6: Breakpoint unique à 600px via `LayoutBuilder` — liste des 40 collèges en 2 colonnes sur iPad (≥600px), colonne unique sur iPhone (<600px).
UX-DR7: Accessibilité WCAG AA : contraste ≥ 4.5:1 sur tous les couples texte/fond, tap targets ≥ 44×44px, `Semantics` labels sur tous les composants custom (FlashCard, DrillEvaluationBar, OcrConfidenceBadge), respect du `MediaQuery.textScaleFactor` (Dynamic Type iOS), pas de dépendance à la couleur seule (OcrConfidenceBadge : icône + texte).
UX-DR8: Écran Mode Drill (recto) : plein écran sans bottom nav, DrillHeader avec ✕ + titre tronqué + badge rang, ProgressBar "X/24", TapHint footer qui disparaît après premier retournement.
UX-DR9: Écran Mode Drill (verso) : rappel question en bandeau grisé, AnswerList, AssessmentButtons 3 boutons empilés verticalement pleine largeur (ordre : À revoir en haut, Maîtrisé en bas).
UX-DR10: Écran fin de session : donut SVG mastery % en premier plan, StatsBento 3 cartes (Maîtrisé/Bien/À revoir), AnalysisTags points forts/à consolider, CTAs "Recommencer les erreurs" (primary) + "Retour accueil" (outlined).
UX-DR11: Écran import en cours : ProgressStepper 4 étapes (PDF reçu · OCR · Génération Claude · Classement), estimation de temps affichée uniquement sur l'étape active, banner "vous pouvez fermer l'app" visuellement prioritaire, bouton "Fermer et continuer" (outlined).
UX-DR12: Personnalisation de session : bottom sheet (pas d'écran dédié), single-select collège, multi-select rang (chips), stepper quantité fiches, filter chips statut (Toutes/À revoir/Non vues), CTA sticky "Enregistrer la session".
UX-DR13: États vides explicatifs sur chaque écran : Accueil sans collège (→ import), Accueil OCR en cours (`ShadProgress` + "Tes fiches arrivent..."), liste collèges (→ sélectionner un collège), search sans résultat, Mode Drill session terminée (résumé + prochaine session).
UX-DR14: Messages de quota (structure systématique) : 1/ "Tes fiches existantes sont toujours accessibles" · 2/ explication du blocage · 3/ date de réinitialisation. Jamais "bloqué" ou "interdit" — toujours "limite atteinte" + solution.
UX-DR15: Écran Profil : IdentityCard (prénom + année + faculté), SubscriptionCard (badge actif + barre quota imports `2/3`), RevisionPrefsCard (chips A/B/C toggleables + stepper fiches max), NotifCard (toggle rappel), bouton "Se déconnecter" en rouge.
UX-DR16: Écran détail collège : ProgressSummaryCard + FilterChips par rang (scrollable horizontal) + ItemList avec badge rang + mini barre de progression par item + chevron.
UX-DR17: Écran détail item : RangTabBar sticky (Rang A/B/C) + CollapsibleSections accordéon (Définition ouverte par défaut) + FlashcardStrip scroll horizontal + DrillLaunchBar fixe au-dessus du bottom nav (pas `bottom-0`).
UX-DR18: Un seul bouton primaire par écran. Hiérarchie : ShadButton filled (primary) · outline (secondary) · ghost (tertiary) · destructive. `ShadToast` pour feedback succès/erreur récupérable. `ShadAlertDialog` pour blocages quota. `ShadSkeleton` pour tous les états de chargement.

### FR Coverage Map

FR1: Epic 2 — Démo interactive sans compte
FR2: Epic 2 — Skip démo → inscription directe
FR3: Epic 2 — Création compte email/mdp
FR4: Epic 2 — In-app purchase App Store
FR5: Epic 2 — Paywall sans abonnement actif
FR6: Epic 2 — Prix/durée affichés avant achat
FR7: Epic 3 — Liste des 40 collèges
FR8: Epic 3 — Import PDF depuis stockage local
FR9: Epic 3 — OCR en tâche de fond (BGProcessingTask)
FR10: Epic 3 — Reprise OCR si interrompu
FR11: Epic 3 — Score confiance OCR + badge warning
FR12: Epic 3 — Détection items/chapitres backend
FR13: Epic 3 — Progression import/génération temps réel (SSE)
FR14: Epic 3 — Limites reimport (2/collège, 3/mois)
FR15: Epic 3 — Blocage gracieux + date réinitialisation
FR16: Epic 3 — Génération flashcards classiques + fiches définition
FR17: Epic 3 — Tagging rang A/B/C automatique
FR18: Epic 3 — Hash-sharing v1 (réutilisation fiches existantes)
FR19: Epic 3 — Feedback fiche (pouce haut/bas)
FR20: Epic 3 — Régénération fiche avec feedback transmis à Claude
FR21: Epic 3 — Suppression fiche
FR22: Epic 3 — Sync locale automatique des fiches (offline-first)
FR23: Epic 3 — Push notification "fiches prêtes"
FR24: Epic 4 — Lancement session Mode Drill (collèges, items, rangs)
FR25: Epic 4 — Spaced repetition 3 niveaux (À revoir / Bien / Maîtrisé)
FR26: Epic 4 — Évaluation fiche par l'étudiant
FR27: Epic 4 — Ajustement fréquence de présentation selon niveau
FR28: Epic 4 — Accès fiches + sessions quiz sans connexion internet
FR29: Epic 4 — Évaluation sémantique des réponses (fiches définition)
FR30: Epic 4 — Configuration planning (collèges, items, dates, disponibilité)
FR31: Epic 4 — Planning algorithmique local priorisé A→B→C
FR32: Epic 4 — Consultation session du jour (items, rangs, nb fiches)
FR33: Epic 4 — Marquer session effectuée ou décalée
FR34: Epic 4 — Progression par collège et par rang
FR35: Epic 4 — Rappel quotidien configurable
FR36: Epic 5 — Recherche full-text sur tous les collèges importés
FR37: Epic 5 — Résultats avec passage contextuel + chapitre source
FR38: Epic 5 — Lancement session de révision depuis un résultat
FR39: Epic 6 — Suppression compte + toutes les données (RGPD)
FR40: Epic 6 — CGU + politique de confidentialité accessibles depuis l'app
FR41: Epic 2 (Story 2.4) — Deep link gestion abonnement iOS + affichage lien dans Epic 6 (Story 6.1)
FR42: Epic 2 (Story 2.4) — Validation abonnement actif avant chaque appel Claude (guard backend)
FR43: Epic 1 — Monitoring queue de génération (opérateur)
FR44: Epic 1 — Gestion accès beta (opérateur)
FR45: Epic 1 — Limites anti-spam configurables sans redéploiement
FR46: Epic 1 — Surveillance abonnements + webhooks App Store
FR47: Epic 1 — Déclenchement manuel génération (interface admin web)
FR48: Epic 1 — Stats génération (fiches, score OCR, taux hash-sharing)
FR49: Epic 1 — Interface testeur web (navigation et interaction fiches)
FR50: Epic 1 — Feedback testeur par fiche (pertinente / non pertinente)

## Epic List

### Epic 1 : Infrastructure, Pipeline & Validation Phase 0
L'opérateur dispose d'un homelab fonctionnel (Docker Compose : PostgreSQL, Redis, Caddy), des deux projets initialisés (collega_app Flutter + collega_backend FastAPI), et peut déclencher manuellement la génération de fiches sur un collège réel via l'interface admin sécurisée. La testeuse valide la qualité des fiches générées via l'interface web dédiée. C'est le **go/no-go technique** avant d'investir dans le Flutter complet.
**FRs couverts :** FR43, FR44, FR45, FR46, FR47, FR48, FR49, FR50
*(Fondations backend réutilisées dans Epic 3 : pipeline OCR, génération Claude, hash-sharing v1)*

### Epic 2 : Découverte, Authentification & Abonnement
Un étudiant peut découvrir AppMédecine via la démo interactive (collège fictif, 3 fiches pré-chargées) sans créer de compte, puis s'inscrire et souscrire à l'abonnement mensuel via l'App Store. L'accès aux fonctionnalités principales est conditionné à un abonnement actif.
**FRs couverts :** FR1, FR2, FR3, FR4, FR5, FR6

### Epic 3 : Import PDF, OCR & Génération de Fiches
Un étudiant abonné peut consulter les 40 collèges disponibles, importer un PDF depuis son stockage local, suivre le traitement OCR et la génération Claude en temps réel (SSE), et obtenir des fiches de révision taguées par rang (A/B/C) avec indication de qualité OCR. Il peut donner du feedback, régénérer ou supprimer des fiches. Les fiches sont synchronisées automatiquement en local pour un accès offline.
**FRs couverts :** FR7, FR8, FR9, FR10, FR11, FR12, FR13, FR14, FR15, FR16, FR17, FR18, FR19, FR20, FR21, FR22, FR23

### Epic 4 : Mode Drill, Planning & Révision Offline
Un étudiant peut lancer des sessions de révision en spaced repetition (Mode Drill) entièrement en hors-ligne, configurer un planning algorithmique selon son propre cursus (collèges, items, disponibilité quotidienne), consulter sa progression par collège et par rang, et configurer des rappels quotidiens.
**FRs couverts :** FR24, FR25, FR26, FR27, FR28, FR29, FR30, FR31, FR32, FR33, FR34, FR35

### Epic 5 : Recherche Full-Text & Mode Stage
Un étudiant peut effectuer une recherche full-text sur l'ensemble de ses collèges importés et obtenir des résultats contextuels en moins d'une seconde, avec la possibilité de lancer directement une session de révision depuis un résultat (flow stage clinique → révision immédiate).
**FRs couverts :** FR36, FR37, FR38

### Epic 6 : Profil, Compte & Conformité RGPD
Un étudiant peut gérer son identité (prénom, année, faculté), consulter son quota d'imports et son abonnement, configurer ses préférences de révision et ses notifications, supprimer son compte et toutes ses données, et accéder aux CGU et politique de confidentialité depuis l'app.
**FRs couverts :** FR39, FR40, FR41, FR42

---

## Epic 1 : Infrastructure, Pipeline & Validation Phase 0

L'opérateur dispose d'un homelab fonctionnel (Docker Compose : PostgreSQL, Redis, Caddy), des deux projets initialisés (collega_app Flutter + collega_backend FastAPI), et peut déclencher manuellement la génération de fiches sur un collège réel via l'interface admin sécurisée. La testeuse valide la qualité des fiches générées via l'interface web dédiée. C'est le go/no-go technique avant d'investir dans le Flutter complet.

### Story 1.1 : Infrastructure Homelab & Squelettes Projets [Technical Foundation]

> Story de fondation technique — prérequis pour toutes les stories suivantes. Aucune valeur utilisateur directe.

En tant que **développeur**,
je veux que l'infrastructure homelab soit opérationnelle et les deux projets initialisés,
afin de pouvoir commencer l'implémentation des features sur une base stable et communicante.

**Critères d'acceptance :**

**Étant donné** un serveur homelab avec Docker installé
**Quand** j'exécute `docker-compose up`
**Alors** les 4 services démarrent sans erreur : `api` (FastAPI/Uvicorn), `db` (PostgreSQL 16), `redis`, `caddy`
**Et** `GET /health` sur l'API renvoie `{"data": {"status": "ok"}}` avec TLS Caddy actif

**Étant donné** le projet backend initialisé
**Quand** je consulte la structure `collega_backend/`
**Alors** elle correspond exactement à l'arborescence définie en architecture (app/, models/, schemas/, api/v1/, services/, workers/, alembic/)
**Et** `alembic upgrade head` s'exécute sans erreur sur une base PostgreSQL vide
**Et** les variables d'environnement sensibles (clé Claude, JWT secret) sont dans `.env` et jamais dans le code

**Étant donné** la migration initiale Alembic (Story 1.1 uniquement)
**Quand** elle est appliquée
**Alors** seules les tables `users` et `colleges` sont créées — aucune autre table
**Et** les tables `items`, `flash_cards`, `generation_jobs` sont créées dans les migrations des Stories 1.2 et 1.3 respectivement, quand elles sont nécessaires pour la première fois

**Étant donné** le projet Flutter initialisé avec `flutter create --org=com.lesurmatthis --platforms=ios,android collega_app`
**Quand** je lance l'app sur un simulateur iOS 16+
**Alors** l'app démarre sans erreur, affiche un écran vide (pas de crash), et `flutter analyze` ne retourne aucune erreur
**Et** les dépendances sont configurées dans `pubspec.yaml` : `flutter_riverpod`, `go_router`, `drift`, `shadcn_ui`, `flutter_animate`, `flutter_secure_storage`, `purchases_flutter`, `file_picker`
**Et** la structure feature-first existe : `lib/features/` avec sous-dossiers `demo/`, `auth/`, `colleges/`, `generation/`, `drill/`, `planning/`, `search/`, `profile/`

**Étant donné** les deux projets en cours de développement
**Quand** l'app Flutter appelle `GET /health`
**Alors** la réponse est reçue avec succès via HTTPS (Caddy TLS), confirmant la connectivité app ↔ backend

---

### Story 1.2 : Pipeline OCR Backend

En tant qu'**opérateur**,
je veux pouvoir soumettre un PDF de collège médical au pipeline OCR backend,
afin d'extraire automatiquement le texte par item avec un score de confiance, en préparation de la génération de fiches.

**Critères d'acceptance :**

**Étant donné** un PDF de collège médical soumis à l'endpoint admin
**Quand** `POST /v1/admin/colleges/{college_id}/process` est appelé avec le PDF
**Alors** un job ARQ est créé dans la queue Redis avec le statut `pending`
**Et** le job passe à `processing`, exécute l'OCR page par page, puis passe à `ocr_complete`
**Et** la table `items` est peuplée avec les items détectés, chacun ayant un `ocr_text`, un `ocr_confidence_score` (float 0.0–1.0) et le rang détecté (A/B/C)

**Étant donné** un PDF de mauvaise qualité (scan dégradé)
**Quand** l'OCR est exécuté
**Alors** les items avec un `ocr_confidence_score` < 0.7 sont marqués `low_confidence: true`
**Et** ces items sont quand même créés — le score dégradé n'empêche pas la suite du pipeline

**Étant donné** un job OCR interrompu (worker ARQ redémarré)
**Quand** le worker redémarre
**Alors** le job reprend à partir de la dernière page enregistrée dans `ocr_page_progress` (pas de reprise depuis le début)

**Étant donné** une liste de colleges dans la base
**Quand** `GET /v1/admin/colleges/{college_id}/status` est appelé
**Alors** la réponse inclut `{ "data": { "status": "ocr_complete"|"processing"|"pending", "ocr_page_progress": N, "total_pages": M } }`

**Étant donné** les contraintes de nommage définies en architecture
**Quand** le code est inspecté
**Alors** toutes les tables sont en snake_case pluriel, toutes les routes en `/v1/` snake_case, aucun `print()` en production, toutes les dates en ISO 8601 UTC

---

### Story 1.3 : Pipeline Génération de Fiches Claude

En tant qu'**opérateur**,
je veux que les items OCR'd d'un collège soient transformés en flashcards par Claude,
afin d'obtenir des fiches de révision taguées par rang (A/B/C), avec déduplication par hash-sharing.

**Critères d'acceptance :**

**Étant donné** un college avec des items au statut `ocr_complete`
**Quand** le `generation_worker` ARQ traite le job
**Alors** Claude génère pour chaque item : au minimum 1 flashcard classique (recto = question, verso = réponse) et 1 fiche définition si applicable
**Et** chaque flashcard est taguée avec le rang de l'item source (A, B ou C) via `rang: "A"|"B"|"C"`
**Et** le job passe au statut `generation_complete` avec un `card_count` total

**Étant donné** un college dont le PDF est identique (ou similaire à ≥ 90%) à un PDF déjà traité
**Quand** le pipeline évalue le hash-sharing via `SimilarityChecker`
**Alors** les fiches existantes sont réutilisées sans nouvel appel Claude
**Et** le job passe directement au statut `generation_complete` avec `hash_shared: true`
**Et** l'interface `SimilarityChecker` est abstraite — l'algorithme est remplaçable sans modifier le reste du pipeline

**Étant donné** que Claude API est temporairement indisponible
**Quand** le `generation_worker` tente un appel Claude
**Alors** il réessaie avec backoff exponentiel (max 3 tentatives)
**Et** après échec définitif, le job passe à `failed` et reste en queue pour reprise manuelle

**Étant donné** un job de génération terminé
**Quand** 24 heures se sont écoulées
**Alors** le `cleanup_worker` ARQ supprime le champ `ocr_text` de tous les items du job (mis à NULL)
**Et** les flashcards et métadonnées restent intactes

**Étant donné** les contraintes de sécurité NFR5
**Quand** le code est inspecté
**Alors** la clé API Claude est exclusivement dans les variables d'environnement Docker — absente de tout fichier versionné

---

### Story 1.4 : Interface Admin Web Phase 0

En tant qu'**opérateur**,
je veux une interface admin web sécurisée pour piloter le pipeline de génération et monitorer le système,
afin de valider la qualité end-to-end et d'ajuster la configuration sans déploiement.

**Critères d'acceptance :**

**Étant donné** l'interface admin accessible à `/admin`
**Quand** j'y accède sans credentials
**Alors** l'authentification HTTP Basic Auth est requise — accès refusé sans credentials valides

**Étant donné** que je suis connecté à l'interface admin (FR47)
**Quand** je sélectionne un collège et déclenche manuellement la génération
**Alors** un job ARQ est créé et apparaît dans la queue avec son statut (`pending` → `processing` → `generation_complete`)

**Étant donné** des jobs en cours (FR43)
**Quand** je consulte le tableau de bord de la queue
**Alors** je vois pour chaque job : college_id, statut, pages OCR traitées/total, nombre de fiches générées, temps écoulé
**Et** la page se rafraîchit ou dispose d'un bouton "Actualiser"

**Étant donné** la page des statistiques (FR48)
**Quand** je consulte les stats d'un collège traité
**Alors** je vois : nombre total de fiches par rang (A/B/C), score de confiance OCR moyen et par item, flag `hash_shared` avec taux de similarité

**Étant donné** la gestion des accès beta (FR44)
**Quand** je consulte la liste des utilisateurs
**Alors** je peux activer/désactiver le flag `is_beta` pour chaque utilisateur sans redéploiement

**Étant donné** la configuration anti-spam (FR45)
**Quand** je modifie les valeurs `RELOAD_COUNT_MAX` et `MONTHLY_RELOADS_MAX` dans la configuration backend (pydantic-settings)
**Alors** les nouvelles valeurs sont appliquées immédiatement sans redémarrage de l'app

**Étant donné** l'endpoint webhook RevenueCat (FR46)
**Quand** `POST /v1/webhooks/revenuecat` reçoit un event signé
**Alors** le statut d'abonnement de l'utilisateur est mis à jour dans la base
**Et** les events non signés ou avec signature invalide retournent 401

---

### Story 1.5 : Interface Testeur Web Phase 0

En tant que **testeuse**,
je veux naviguer dans les fiches d'un collège généré via une interface web dédiée et donner mon feedback fiche par fiche,
afin de valider la pertinence médicale des fiches pour le go/no-go du MVP Flutter.

**Critères d'acceptance :**

**Étant donné** l'interface testeur accessible à `/tester`
**Quand** j'y accède sans credentials
**Alors** l'authentification est requise (credentials distincts de l'admin) — accès refusé sans credentials valides

**Étant donné** que je suis connectée à l'interface testeur (FR49)
**Quand** je sélectionne un collège traité
**Alors** je vois la liste de tous les items avec leurs fiches, organisées par rang (A/B/C)
**Et** chaque fiche affiche : le recto (question), le verso (réponse), le rang, et un indicateur visuel si `ocr_confidence_score` < 0.7

**Étant donné** une fiche affichée (FR50)
**Quand** je clique sur "Pertinente" ou "Non pertinente"
**Alors** le feedback est enregistré en base avec `timestamp` et `tester_id`
**Et** la fiche suivante est affichée automatiquement

**Étant donné** ma session de feedback
**Quand** j'ai évalué toutes les fiches d'un item
**Alors** un résumé indique : X fiches pertinentes / Y non pertinentes pour cet item

**Étant donné** le feedback consolidé visible par l'opérateur
**Quand** l'opérateur consulte l'interface admin
**Alors** il voit le taux de pertinence global par collège et par rang

---

## Epic 2 : Découverte, Authentification & Abonnement

Un étudiant peut découvrir AppMédecine via la démo interactive (collège fictif, 3 fiches pré-chargées) sans créer de compte, puis s'inscrire et souscrire à l'abonnement mensuel via l'App Store. L'accès aux fonctionnalités principales est conditionné à un abonnement actif.

### Story 2.1 : Thème & Design System Flutter [Technical Foundation]

> Story de fondation technique — prérequis pour toutes les stories Flutter suivantes. Aucune valeur utilisateur directe.

En tant que **développeur**,
je veux que le thème shadcn_ui et les tokens de design soient configurés dans l'app,
afin que toutes les features suivantes utilisent une palette, une typographie et des composants cohérents dès le premier écran.

**Critères d'acceptance :**

**Étant donné** l'app Flutter lancée
**Quand** l'écran principal s'affiche
**Alors** le thème shadcn_ui est appliqué avec la palette : Primary `#1B6B3A`, Primary container `#B7F2C8`, Secondary `#3D6B5E`, Surface `#F8FAF9`, On surface `#1A1C1A`, Error `#BA1A1A`
**Et** la police Inter est chargée via `google_fonts` sur tous les textes
**Et** les 6 niveaux typographiques sont définis dans `app_theme.dart` (displayMedium 28sp/700 → labelMedium 12sp/500)

**Étant donné** un composant quelconque utilisant `ShadButton`
**Quand** il est rendu
**Alors** les 4 variants existent et respectent la hiérarchie : `filled` (primary vert), `outline` (secondary), `ghost` (tertiary), `destructive` (rouge)
**Et** un seul bouton `filled` primary est présent par écran

**Étant donné** n'importe quel état de chargement dans l'app
**Quand** des données sont en cours de récupération
**Alors** `ShadSkeleton` est utilisé — `CircularProgressIndicator` est absent du codebase

**Étant donné** le fichier `core/theme/app_theme.dart`
**Quand** je l'inspecte
**Alors** les espacements de base sont définis comme constantes : margin écran 16px, padding card 16px, espacement sections 24px, border-radius cards 12px, boutons 8px

---

### Story 2.2 : Démo Interactive (Collège Fictif)

En tant qu'**étudiant visiteur**,
je veux explorer une démo interactive avec un collège fictif et des fiches pré-chargées sans créer de compte,
afin de comprendre la valeur d'AppMédecine avant de m'engager.

**Critères d'acceptance :**

**Étant donné** l'app lancée pour la première fois (FR1)
**Quand** l'écran d'accueil s'affiche
**Alors** la démo interactive est proposée en premier — pas d'écran de connexion bloquant
**Et** le bouton "Essayer la démo" est le CTA primaire visible

**Étant donné** que je lance la démo
**Quand** j'entre dans le mode démo
**Alors** un collège fictif "Cardiologie Exemple" est pré-chargé avec 3 fiches (dont au moins 1 par rang A et B) et 1 souvenir d'item
**Et** toutes les features sont visibles (liste de fiches, rang A/B/C, barre de progression, bouton "Commencer") — seul l'import réel est désactivé

**Étant donné** que je suis dans la démo
**Quand** je tape sur une fiche
**Alors** l'animation de retournement FlashCard fonctionne (`.flip().fade()` flutter_animate)
**Et** la DrillEvaluationBar apparaît après retournement avec les 3 boutons À revoir / Bien / Maîtrisé

**Étant donné** que je veux m'inscrire depuis la démo (FR2)
**Quand** je tape sur "S'inscrire" ou "Commencer pour de vrai"
**Alors** je suis redirigé vers l'écran d'inscription sans perdre mon contexte

**Étant donné** que je veux ignorer la démo (FR2)
**Quand** je tape sur "Skip" / "Accéder directement"
**Alors** je suis redirigé vers l'écran d'inscription directement

**Étant donné** les contraintes App Store
**Quand** l'app est soumise
**Alors** la démo est accessible sans création de compte ni connexion réseau

---

### Story 2.3 : Inscription & Authentification

En tant qu'**étudiant**,
je veux créer un compte avec mon email et mon mot de passe, puis me connecter,
afin d'accéder à mon espace personnel sur AppMédecine.

**Critères d'acceptance :**

**Étant donné** l'écran d'inscription (FR3)
**Quand** je saisis un email valide et un mot de passe (≥ 8 caractères) et je valide
**Alors** un compte est créé côté backend (table `users`)
**Et** un JWT access token (courte durée) et un refresh token (longue durée) sont retournés
**Et** les tokens sont stockés dans `flutter_secure_storage` (Keychain iOS) — jamais en clair

**Étant donné** un email déjà utilisé
**Quand** je tente de m'inscrire avec ce même email
**Alors** un `ShadToast` d'erreur s'affiche : "Cet email est déjà utilisé"
**Et** je reste sur l'écran d'inscription

**Étant donné** l'écran de connexion
**Quand** je saisis mes identifiants corrects
**Alors** je suis authentifié et redirigé vers l'écran principal (ou le paywall si pas d'abonnement)

**Étant donné** un access token expiré
**Quand** l'app tente un appel API
**Alors** le refresh token est utilisé automatiquement pour obtenir un nouveau access token (intercepteur Dio)
**Et** si le refresh token est aussi expiré, je suis redirigé vers l'écran de connexion

**Étant donné** un utilisateur beta (flag `is_beta: true` en base)
**Quand** il se connecte
**Alors** il accède aux fonctionnalités principales sans abonnement payant
**Et** le backend valide `is_beta` avant chaque appel Claude

---

### Story 2.4 : Abonnement In-App Purchase & Paywall

En tant qu'**étudiant inscrit**,
je veux souscrire à l'abonnement mensuel via l'App Store et voir le prix avant de confirmer,
afin d'accéder à toutes les fonctionnalités d'AppMédecine.

**Critères d'acceptance :**

**Étant donné** un utilisateur connecté sans abonnement actif (FR5)
**Quand** il tente d'accéder à une fonctionnalité principale (import PDF, Mode Drill)
**Alors** le paywall s'affiche avec le prix (~9€/mois) et la durée clairement indiqués avant toute confirmation (FR6)
**Et** un bouton "Retour à la démo" permet de revenir sans pression

**Étant donné** le paywall affiché (FR4)
**Quand** je tape sur "S'abonner"
**Alors** la sheet native App Store IAP s'ouvre avec le prix exact
**Et** après confirmation d'achat, RevenueCat enregistre l'abonnement et envoie le webhook au backend

**Étant donné** le webhook RevenueCat reçu par le backend
**Quand** l'event `INITIAL_PURCHASE` est traité
**Alors** `user.is_subscribed` passe à `true` en base
**Et** l'utilisateur est redirigé vers l'écran principal sans délai perceptible

**Étant donné** un achat annulé ou échoué
**Quand** la sheet IAP est fermée sans confirmation
**Alors** le paywall est réaffiché avec un `ShadToast` neutre ("Achat annulé")
**Et** aucun changement n'est enregistré en base

**Étant donné** un abonnement actif (FR42)
**Quand** l'app effectue un appel au backend nécessitant Claude
**Alors** le backend valide `is_subscribed` (ou `is_beta`) avant de traiter la demande — un `401` est renvoyé si invalide
**Et** la clé RevenueCat de validation est exclusivement côté backend

**Étant donné** les exigences App Store
**Quand** l'app est soumise à review
**Alors** la politique d'annulation est accessible depuis les paramètres iOS (FR41 — deep link vers les abonnements iOS)

---

## Epic 3 : Import PDF, OCR & Génération de Fiches

Un étudiant abonné peut consulter les 40 collèges, importer un PDF, suivre le traitement OCR en temps réel via SSE, et obtenir des fiches de révision générées par Claude, avec indication de qualité OCR. Il peut donner du feedback, régénérer ou supprimer des fiches. Les fiches sont synchronisées localement pour un accès offline.

### Story 3.1 : Liste des Collèges & Navigation

En tant qu'**étudiant abonné**,
je veux consulter les 40 collèges médicaux disponibles et voir ma progression sur ceux que j'ai importés,
afin de choisir quel collège travailler et voir d'un coup d'œil où j'en suis.

**Critères d'acceptance :**

**Étant donné** l'onglet "Collèges" du bottom nav (FR7)
**Quand** je l'ouvre
**Alors** les 40 collèges médicaux prédéfinis sont listés, avec pour chacun : icône spécialité, nom, éditeur (ex : CEN)
**Et** les filtres "Tous / Importés / Non-importés" sont disponibles en chips scrollables

**Étant donné** un collège importé avec des fiches
**Quand** il s'affiche dans la liste
**Alors** le composant `CollegeProgressTile` affiche une barre de progression à 4 segments : Maîtrisé / Bien / À revoir / Non vues (gris)
**Et** les badges de rangs disponibles (A/B/C) sont visibles

**Étant donné** un collège non importé
**Quand** il s'affiche dans la liste
**Alors** il est grisé avec un badge "Non-importé" et un CTA "Charger ce collège"

**Étant donné** l'affichage sur iPad (≥ 600px)
**Quand** la liste des collèges est rendue
**Alors** elle s'affiche en grille 2 colonnes via `LayoutBuilder` (breakpoint 600px)

**Étant donné** aucun collège importé (état vide)
**Quand** l'écran s'affiche
**Alors** un état vide explicatif s'affiche : "Sélectionne un collège dans les 40 disponibles →" avec CTA vers l'import

---

### Story 3.2 : Import PDF & Progression OCR en Temps Réel

En tant qu'**étudiant abonné**,
je veux importer un PDF depuis mon stockage local et suivre l'avancement du traitement en temps réel,
afin de savoir où en est mon collège sans bloquer l'app ni rester sur un écran d'attente.

**Critères d'acceptance :**

**Étant donné** que je tape sur "Charger ce collège" (FR8)
**Quand** le file picker s'ouvre via `file_picker`
**Alors** je peux sélectionner un fichier PDF depuis mon stockage iOS
**Et** le PDF est copié dans le dossier privé de l'app après sélection

**Étant donné** un PDF sélectionné
**Quand** l'upload démarre
**Alors** l'app envoie le PDF au backend et un job de génération est créé
**Et** l'écran "Import en cours" s'affiche avec le `ProgressStepper` à 4 étapes : PDF reçu · OCR · Génération Claude · Classement

**Étant donné** le traitement OCR en cours (FR9)
**Quand** le backend envoie des events SSE `ocr_progress`
**Alors** la barre de progression se met à jour en temps réel (page X / total)
**Et** l'estimation de temps restant est affichée uniquement sur l'étape active
**Et** le banner "Vous pouvez fermer l'app, vous serez notifié" est visible et prioritaire

**Étant donné** que je ferme l'app pendant l'OCR (FR9 background)
**Quand** le `BGProcessingTask` iOS est actif
**Alors** l'OCR continue en tâche de fond
**Et** au retour foreground, l'app interroge `GET /v1/colleges/{id}/status` et se reconnecte au stream SSE si le job est encore actif

**Étant donné** un OCR interrompu (crash app ou reboot) (FR10)
**Quand** le worker ARQ redémarre
**Alors** le job reprend à partir de `ocr_page_progress` — pas depuis le début
**Et** l'app affiche le bon état de progression au retour foreground

**Étant donné** l'écran "Import en cours"
**Quand** je tape "Fermer et continuer"
**Alors** je reviens à l'écran précédent — le traitement continue en background sans interruption

---

### Story 3.3 : Affichage des Fiches Générées & Score de Confiance OCR

En tant qu'**étudiant**,
je veux consulter les fiches générées pour un collège, organisées par item et par rang, avec un indicateur de qualité OCR,
afin de savoir quelles fiches sont fiables et commencer à réviser.

**Critères d'acceptance :**

**Étant donné** une génération terminée (FR16, FR17)
**Quand** j'ouvre le détail d'un collège
**Alors** je vois la liste de tous les items avec : badge rang (A/B/C coloré), numéro d'item, titre, mini barre de progression À revoir/Bien/Maîtrisé, chevron
**Et** les FilterChips Rang A / Rang B / Rang C permettent de filtrer la liste

**Étant donné** que je tape sur un item
**Quand** l'écran détail item s'ouvre
**Alors** les tabs Rang A / Rang B / Rang C sont affichés en sticky sous le header
**Et** les sections du contenu sont en accordéon (Définition ouverte par défaut, autres fermées)
**Et** un strip horizontal de prévisualisation des fiches est visible avec question tronquée et bordure gauche colorée par rang
**Et** la `DrillLaunchBar` "Lancer le drill · X fiches" est fixée juste au-dessus du bottom nav

**Étant donné** un item avec un score OCR < 0.7 (FR11)
**Quand** ses fiches s'affichent
**Alors** le composant `OcrConfidenceBadge` est visible sur chaque fiche concernée :
- score entre 0.5 et 0.7 → variant orange "À vérifier"
- score < 0.5 → variant rouge "Source peu lisible"
**Et** le badge affiche icône + texte (jamais couleur seule)
**Et** un tap sur le badge ouvre un `ShadPopover` avec explication + lien "Voir dans le PDF original"

**Étant donné** les fiches générées (FR22)
**Quand** la génération est terminée
**Alors** toutes les fiches sont synchronisées automatiquement dans la base Drift locale
**Et** les fiches sont accessibles sans connexion internet (NFR12)

**Étant donné** l'état vide OCR en cours
**Quand** le collège est en cours de traitement
**Alors** l'écran affiche `ShadProgress` + "Tes fiches arrivent..." avec les fiches déjà générées qui apparaissent progressivement via `flutter_animate` `.fadeIn().slideX()`

---

### Story 3.4 : Hash-Sharing & Limites de Reimport

En tant qu'**étudiant**,
je veux pouvoir reimporter un collège avec une nouvelle édition du PDF, dans la limite autorisée,
afin de mettre à jour mes fiches sans pouvoir abuser du système.

**Critères d'acceptance :**

**Étant donné** un PDF similaire à ≥ 90% d'un traitement existant (FR18)
**Quand** le pipeline évalue la similarité via `SimilarityChecker`
**Alors** les fiches existantes sont servies sans appel Claude
**Et** le job passe directement à `generation_complete` avec `hash_shared: true`
**Et** le compteur `reload_count` n'est pas incrémenté pour un hash-share

**Étant donné** que je veux reimporter un collège (FR14)
**Quand** j'initie le reimport
**Alors** un `ShadAlertDialog` affiche les compteurs actuels avant confirmation : "Reimport X/2 pour ce collège · X/3 ce mois"
**Et** je dois confirmer explicitement avant que le reimport démarre

**Étant donné** que `reload_count` = 2 pour un collège (FR15)
**Quand** je tente un 3ème reimport de ce collège
**Alors** l'action est bloquée avec un `ShadAlertDialog` : "Ce collège ne peut plus être retraité"
**Et** le message confirme en premier : "Tes fiches existantes sont toujours accessibles"
**Et** le CTA principal est "Continuer à réviser" — pas de bouton de contournement

**Étant donné** que `monthly_reloads` = 3 pour le mois en cours (FR15)
**Quand** je tente n'importe quel reimport ce mois
**Alors** l'action est bloquée avec : "Limite mensuelle atteinte · Réinitialisation le JJ/MM"
**Et** le message confirme en premier : "Tes fiches existantes sont toujours accessibles"

**Étant donné** l'opérateur backend (FR45)
**Quand** il modifie `RELOAD_COUNT_MAX` ou `MONTHLY_RELOADS_MAX` dans la config pydantic-settings
**Alors** les nouvelles limites s'appliquent immédiatement sans redéploiement ni mise à jour de l'app

---

### Story 3.5 : Feedback Fiches, Régénération & Notification Push

En tant qu'**étudiant**,
je veux pouvoir signaler une fiche comme non pertinente, la régénérer avec mon feedback ou la supprimer, et être notifié quand mes fiches sont prêtes,
afin d'améliorer la qualité de mes fiches et savoir sans ouvrir l'app quand elles sont disponibles.

**Critères d'acceptance :**

**Étant donné** une fiche affichée (FR19)
**Quand** je tape sur le pouce bas
**Alors** un `ShadAlertDialog` s'affiche avec deux options : "Régénérer avec mon feedback" ou "Supprimer la fiche"

**Étant donné** que je choisis "Régénérer" (FR20)
**Quand** je saisis mon feedback (optionnel) et confirme
**Alors** une requête de régénération est envoyée au backend avec le feedback en contexte Claude
**Et** un job ARQ est créé pour régénérer uniquement cette fiche
**Et** la fiche est remplacée dans Drift local après génération
**Et** le `OcrConfidenceBadge` disparaît si la nouvelle fiche a un score OCR acceptable

**Étant donné** que je choisis "Supprimer" (FR21)
**Quand** je confirme la suppression
**Alors** la fiche est supprimée de Drift local et du backend (scopé par `user_id`)
**Et** les compteurs de progression de l'item sont mis à jour

**Étant donné** que je tape le pouce haut sur une fiche (FR19)
**Quand** le feedback positif est enregistré
**Alors** un `ShadToast` vert s'affiche brièvement : "Fiche signalée comme pertinente"
**Et** aucune action supplémentaire n'est requise

**Étant donné** la fin de génération d'un collège (FR23)
**Quand** le `generation_worker` termine avec succès
**Alors** une notification push APNs est envoyée au device de l'utilisateur : "Tes fiches [Collège X] sont prêtes !"
**Et** la notification est reçue même si l'app est en background ou fermée
**Et** un tap sur la notification ouvre directement l'écran du collège concerné

---

## Epic 4 : Mode Drill, Planning & Révision Offline

Un étudiant peut lancer des sessions de révision en spaced repetition (Mode Drill) entièrement en hors-ligne, configurer un planning algorithmique selon son propre cursus (collèges, items, disponibilité quotidienne), consulter sa progression par collège et par rang, et configurer des rappels quotidiens.

### Story 4.1 : Composants FlashCard & DrillEvaluationBar [Technical Foundation]

> Story de fondation technique — composants réutilisables requis par Story 4.2. Aucune valeur utilisateur directe.

En tant que **développeur**,
je veux que les composants `FlashCard` et `DrillEvaluationBar` soient implémentés et testés de façon isolée,
afin que le Mode Drill puisse les assembler sans reconstruire la logique d'interaction.

**Critères d'acceptance :**

**Étant donné** le composant `FlashCard`
**Quand** il est rendu en état recto
**Alors** la question s'affiche en `titleMedium` centré, avec le badge rang A/B/C en haut à droite (`ShadBadge` coloré : vert/teal/gris)
**Et** si la fiche a un `OcrConfidenceBadge`, il est visible en superposition

**Étant donné** que l'utilisateur tape sur la `FlashCard`
**Quand** le retournement se déclenche
**Alors** l'animation `.flip().fade()` de `flutter_animate` s'exécute en < 300ms
**Et** la réponse s'affiche en état verso
**Et** la `DrillEvaluationBar` apparaît sous la card (invisible avant retournement)

**Étant donné** la `DrillEvaluationBar` visible
**Quand** elle est rendue
**Alors** 3 boutons sont empilés verticalement pleine largeur : "À revoir" (bordure error rouge), "Bien" (bordure secondary teal), "Maîtrisé" (filled primary vert)
**Et** un feedback haptique se déclenche au tap sur chacun

**Étant donné** le tap sur "Maîtrisé"
**Quand** l'animation de sortie se déclenche
**Alors** la card disparaît vers le haut (`.slideY(end: -1).fade()`)

**Étant donné** le tap sur "À revoir"
**Quand** l'animation de sortie se déclenche
**Alors** la card disparaît vers le bas (`.slideY(end: 1).fade()`)

**Étant donné** les deux variants du composant
**Quand** le variant `définition` est utilisé
**Alors** le recto affiche un terme médical, le verso affiche la définition — même logique de retournement et d'évaluation

---

### Story 4.2 : Mode Drill — Session de Révision

En tant qu'**étudiant**,
je veux lancer une session de révision en Mode Drill et évaluer mes fiches en spaced repetition, entièrement hors-ligne,
afin d'ancrer mes connaissances par rang (A→B→C) avec un feedback immédiat sur ma progression.

**Critères d'acceptance :**

**Étant donné** un étudiant avec des fiches synchronisées localement (FR24, FR28)
**Quand** il lance une session depuis la `DrillLaunchBar` ou la `SessionHeroCard`
**Alors** la session démarre sans aucun appel réseau — toutes les données viennent de Drift
**Et** le temps de réponse entre taps est < 100ms (NFR3)

**Étant donné** une session de drill en cours (FR25)
**Quand** les fiches sont présentées
**Alors** l'ordre de présentation suit le spaced repetition : les fiches "À revoir" reviennent plus fréquemment que "Bien", et "Maîtrisé" le moins souvent
**Et** la `ProgressBar` "X / total" avance à chaque fiche évaluée

**Étant donné** l'évaluation d'une fiche (FR26, FR27)
**Quand** je tape "À revoir", "Bien" ou "Maîtrisé"
**Alors** le niveau de la fiche est mis à jour dans Drift immédiatement
**Et** la fréquence de réapparition est ajustée : "À revoir" → réapparaît dans la session en cours, "Bien" → prochaine session, "Maîtrisé" → dans plusieurs jours

**Étant donné** une fiche de type définition (FR29)
**Quand** je saisis une réponse textuelle et la soumets
**Alors** un appel Claude est effectué pour évaluer la proximité sémantique de ma réponse
**Et** le résultat (correct / partiel / incorrect) est affiché avec un retour qualitatif
**Et** si hors-ligne, le mode définition bascule sur auto-évaluation (recto/verso classique)

**Étant donné** la fin d'une session (toutes les fiches évaluées)
**Quand** l'écran de fin s'affiche
**Alors** le donut SVG affiche le % de maîtrise global de la session
**Et** les 3 cartes `StatsBento` montrent les comptes Maîtrisé / Bien / À revoir avec couleurs codées
**Et** les chips d'analyse identifient les points forts et points à consolider par thème
**Et** le CTA "Recommencer les erreurs" (primary) relance une session avec uniquement les fiches "À revoir"

**Étant donné** le mode drill actif
**Quand** l'écran est affiché
**Alors** le bottom nav est masqué — sortie uniquement via le bouton ✕ (DrillHeader)

---

### Story 4.3 : Écran d'Accueil & SessionHeroCard

En tant qu'**étudiant**,
je veux voir ma session du jour dès l'ouverture de l'app et la lancer en un tap,
afin de commencer à réviser sans décision à prendre.

**Critères d'acceptance :**

**Étant donné** l'écran d'accueil (FR32)
**Quand** il s'affiche
**Alors** la `SessionHeroCard` est le premier élément visible avec : nom du collège, rang, nombre de fiches, durée estimée, CTA "Commencer" (primary), bouton "Modifier" (icône edit inline)
**Et** un tap sur "Commencer" lance immédiatement le Mode Drill sans écran intermédiaire

**Étant donné** la SearchBar en haut de l'accueil
**Quand** je tape dessus
**Alors** je suis redirigé vers l'onglet Recherche avec le focus sur le champ de saisie

**Étant donné** la grille des collèges récents sous la hero card
**Quand** elle s'affiche
**Alors** les 2 derniers collèges actifs sont visibles avec leur barre de progression `CollegeProgressTile` (mini)

**Étant donné** aucun collège importé (état vide accueil)
**Quand** l'écran s'affiche
**Alors** la hero card affiche : "Importe ton premier collège pour commencer →" avec CTA vers l'onglet Collèges

**Étant donné** une génération OCR en cours
**Quand** l'écran d'accueil s'affiche
**Alors** la hero card affiche `ShadProgress` + "Tes fiches arrivent..." à la place du CTA "Commencer"

**Étant donné** le tap sur "Modifier" dans la `SessionHeroCard`
**Quand** le bottom sheet de personnalisation s'ouvre
**Alors** il s'affiche par-dessus l'accueil (fond dimmé) sans navigation vers un écran dédié
**Et** les options disponibles sont : single-select collège, multi-select rang (chips A/B/C), stepper quantité fiches, filter chips statut (Toutes / À revoir / Non vues)
**Et** le CTA "Enregistrer la session" est sticky en bas du sheet

---

### Story 4.4 : Planning Algorithmique & Personnalisation

En tant qu'**étudiant**,
je veux configurer un planning d'apprentissage selon mon cursus et ma disponibilité quotidienne,
afin que l'app me propose automatiquement quoi réviser chaque jour sans que j'aie à décider.

**Critères d'acceptance :**

**Étant donné** l'écran d'accueil avec une `SessionHeroCard` affichée
**Quand** il n'y a pas encore de planning configuré (premier lancement ou après suppression)
**Alors** un lien "Configurer mon planning →" s'affiche sous la SessionHeroCard
**Et** un tap ouvre l'écran de configuration du planning (écran dédié, pas un bottom sheet)

**Étant donné** un planning déjà actif
**Quand** l'étudiant veut modifier la configuration globale (dates, disponibilité, collèges)
**Alors** un lien discret "Modifier le planning" est visible sous la SessionHeroCard (distinct du bouton "Modifier" qui ouvre la personnalisation rapide de la session)
**Et** un tap ouvre le même écran de configuration du planning

**Étant donné** l'écran de configuration du planning (FR30)
**Quand** je le complète
**Alors** je peux sélectionner : les collèges à inclure, les items à prioriser (optionnel — tous par défaut), les dates de début/fin, ma disponibilité quotidienne en minutes

**Étant donné** la configuration soumise (FR31)
**Quand** le planning est généré
**Alors** le calcul est effectué entièrement en local (Drift + Riverpod) — aucun appel réseau
**Et** la priorisation suit A→B→C : toutes les fiches Rang A d'un item avant de passer au Rang B
**Et** la `SessionHeroCard` de l'accueil reflète la session du jour calculée

**Étant donné** une session marquée comme effectuée (FR33)
**Quand** je tape "Session terminée" en fin de drill
**Alors** la session est marquée `completed` dans Drift
**Et** le planning recalcule automatiquement la prochaine session sans intervention

**Étant donné** une session que je veux décaler (FR33)
**Quand** je tape "Décaler à demain" depuis la `SessionHeroCard`
**Alors** la session est reportée au lendemain
**Et** le planning se réajuste sans pénalité ni message culpabilisant

**Étant donné** le planning actif
**Quand** j'accède aux paramètres du planning global
**Alors** je peux modifier collèges, dates et disponibilité
**Et** un recalcul complet est déclenché automatiquement après confirmation

---

### Story 4.5 : Progression par Collège/Rang & Rappels

En tant qu'**étudiant**,
je veux consulter ma progression détaillée par collège et par rang, et configurer un rappel quotidien,
afin de rester motivé et de ne pas oublier de réviser.

**Critères d'acceptance :**

**Étant donné** l'écran de progression d'un collège (FR34)
**Quand** je l'ouvre
**Alors** le composant `ItemProgressBar` affiche pour chaque item la répartition À revoir / Bien / Maîtrisé en barre segmentée 3 couleurs avec les chiffres exacts
**Et** les FilterChips Rang A / Rang B / Rang C permettent de filtrer la vue
**Et** un résumé global "X% maîtrisé" est affiché en haut

**Étant donné** le tab Collèges
**Quand** je consulte un `CollegeProgressTile`
**Alors** la barre 4 segments (Maîtrisé / Bien / À revoir / Non vues) reflète les données Drift en temps réel après chaque session

**Étant donné** les paramètres de notification (FR35)
**Quand** j'active le rappel quotidien et sélectionne une heure
**Alors** le token APNs est enregistré côté backend avec l'heure choisie
**Et** une notification push est envoyée chaque jour à l'heure configurée : "C'est l'heure de réviser !"

**Étant donné** que je désactive les rappels
**Quand** je bascule le toggle dans l'écran Profil
**Alors** les notifications quotidiennes s'arrêtent immédiatement
**Et** les notifications "Fiches prêtes" (FR23) restent actives indépendamment

---

## Epic 5 : Recherche Full-Text & Mode Stage

Un étudiant peut effectuer une recherche full-text sur l'ensemble de ses collèges importés et obtenir des résultats contextuels en moins d'une seconde, avec la possibilité de lancer directement une session de révision depuis un résultat (flow stage clinique → révision immédiate).

### Story 5.1 : Recherche Full-Text & Résultats Contextuels

En tant qu'**étudiant**,
je veux saisir un terme clinique dans la barre de recherche et obtenir instantanément les items et fiches correspondants avec leur contexte,
afin de retrouver en quelques secondes l'item lié à un cas vu en stage.

**Critères d'acceptance :**

**Étant donné** l'onglet Recherche (FR36)
**Quand** je l'ouvre depuis le bottom nav ou la SearchBar de l'accueil
**Alors** le champ de recherche est immédiatement focusé avec le clavier ouvert
**Et** le placeholder indique : "Rechercher un item, un signe, une dose..."

**Étant donné** que je saisis un terme (ex : "BNP")
**Quand** la recherche est exécutée via `GET /v1/search?q=BNP`
**Alors** les résultats s'affichent en < 1 seconde pour un utilisateur avec 10 collèges indexés (NFR1 — GIN index PostgreSQL)
**Et** le compteur "X items trouvés" est affiché sous la barre

**Étant donné** les résultats affichés (FR37)
**Quand** je les consulte
**Alors** chaque `SearchResultTile` affiche : titre de l'item, badge rang (A/B/C coloré), provenance (numéro item · nom collège), extrait contextuel avec le terme recherché surligné en vert clair `#B7F2C8`
**Et** une bordure gauche colorée code le rang sans répéter le badge (vert Rang A, teal Rang B)

**Étant donné** qu'aucun résultat ne correspond au terme saisi
**Quand** la recherche retourne zéro résultat
**Alors** l'état vide s'affiche : "Aucun résultat pour '[terme]' — essaie un autre mot"
**Et** la barre de recherche reste accessible et focusée

**Étant donné** la recherche nécessitant une connexion internet
**Quand** l'étudiant est hors-ligne et tape dans la SearchBar
**Alors** un `ShadToast` informatif s'affiche : "La recherche nécessite une connexion internet"
**Et** les fiches restent accessibles via la navigation par collège (offline-first)

---

### Story 5.2 : Lancement Session depuis un Résultat de Recherche

En tant qu'**étudiant en stage**,
je veux lancer directement une session de révision sur un item depuis son résultat de recherche,
afin de réviser à chaud le cas clinique que je viens de voir sans quitter le contexte de ma recherche.

**Critères d'acceptance :**

**Étant donné** un résultat de recherche affiché (FR38)
**Quand** je tape sur le CTA "Réviser l'item" d'un résultat Rang A
**Alors** le Mode Drill se lance directement sur les fiches Rang A de cet item uniquement
**Et** le DrillHeader indique le contexte : "Item [N] · [Nom Collège]"

**Étant donné** un résultat de rang inférieur (B ou C)
**Quand** il s'affiche dans la liste
**Alors** le CTA "Réviser l'item" est absent — un tap sur la carte ouvre la vue détail de l'item
**Et** le bouton `DrillLaunchBar` dans la vue détail item permet de lancer le drill sur le rang souhaité

**Étant donné** que le drill lancé depuis la recherche se termine
**Quand** l'écran de fin de session s'affiche
**Alors** le CTA "Retour à l'accueil" est proposé en secondary
**Et** le CTA "Nouvelle recherche" est proposé en primary pour poursuivre le flow stage

---

## Epic 6 : Profil, Compte & Conformité RGPD

Un étudiant peut gérer son identité (prénom, année, faculté), consulter son quota d'imports et son abonnement, configurer ses préférences de révision et ses notifications, supprimer son compte et toutes ses données, et accéder aux CGU et politique de confidentialité depuis l'app.

### Story 6.1 : Écran Profil & Préférences

> **Note FR41 :** Le deep link iOS vers les paramètres d'abonnement (`itms-apps://`) est implémenté dans Story 2.4. Cette story ajoute le point d'entrée visible dans l'écran Profil (bouton "Gérer mon abonnement").

En tant qu'**étudiant**,
je veux gérer mon identité, consulter mon quota d'import et mon abonnement, et configurer mes préférences de révision depuis un écran centralisé,
afin d'avoir une vue complète de mon compte et de personnaliser l'expérience selon mon usage.

**Critères d'acceptance :**

**Étant donné** l'onglet Profil du bottom nav
**Quand** je l'ouvre
**Alors** l'écran affiche dans l'ordre : `IdentityCard`, `SubscriptionCard`, `RevisionPrefsCard`, `NotifCard`, section App

**Étant donné** la `IdentityCard`
**Quand** elle s'affiche
**Alors** prénom (obligatoire), année et faculté (facultatifs) sont visibles en mode lecture
**Et** un tap ouvre un champ éditable en ligne — pas de navigation vers un écran séparé

**Étant donné** la `SubscriptionCard`
**Quand** l'abonnement est actif
**Alors** le badge "Actif" (discret, non alarmiste) s'affiche avec la date de prochain renouvellement
**Et** la barre de quota d'import indique "X/3 reimports utilisés ce mois"
**Et** si l'abonnement est en cours de résiliation, un bandeau `error-container` s'affiche

**Étant donné** la `RevisionPrefsCard`
**Quand** je la consulte
**Alors** des chips A / B / C toggleables définissent les rangs inclus par défaut dans les sessions
**Et** un stepper "Fiches max par session" est disponible
**Et** ces préférences sont synchronisées avec les valeurs par défaut du bottom sheet de personnalisation de session

**Étant donné** la section App (FR40)
**Quand** je tape sur "CGU" ou "Politique de confidentialité"
**Alors** le document correspondant s'affiche dans l'app sans quitter l'app

**Étant donné** la gestion d'abonnement (FR41)
**Quand** je tape sur "Gérer mon abonnement"
**Alors** je suis redirigé vers les paramètres d'abonnement iOS natifs (deep link `itms-apps://`) où l'annulation est possible

---

### Story 6.2 : Suppression de Compte & Conformité RGPD

> **Note FR42 :** Le guard de validation d'abonnement côté backend (vérification `is_subscribed OR is_beta` avant chaque appel Claude) est implémenté dans Story 2.4. Cette story ajoute uniquement la réaction Flutter au `403` reçu lors de la suppression et le flux RGPD complet.

En tant qu'**étudiant**,
je veux pouvoir supprimer mon compte et toutes mes données associées directement depuis l'app,
afin d'exercer mon droit à l'effacement conformément au RGPD.

**Critères d'acceptance :**

**Étant donné** le bouton "Supprimer mon compte" dans l'écran Profil (FR39)
**Quand** je tape dessus
**Alors** un `ShadAlertDialog` s'affiche avec avertissement clair : "Cette action est irréversible. Toutes tes fiches et données seront supprimées définitivement."
**Et** deux actions : "Annuler" (outlined) et "Supprimer définitivement" (destructive rouge)

**Étant donné** que je confirme la suppression
**Quand** la requête `DELETE /v1/auth/account` est envoyée
**Alors** le backend supprime en cascade : compte utilisateur, fiches, items, jobs de génération, tokens APNs — scopés par `user_id` (NFR8)
**Et** les données Drift locales sont effacées sur l'appareil
**Et** je suis redirigé vers l'écran d'accueil (démo) avec un `ShadToast` : "Ton compte a été supprimé"

**Étant donné** un utilisateur avec un abonnement actif lors de la suppression
**Quand** la suppression est confirmée
**Alors** la suppression de données s'effectue normalement côté backend
**Et** un message informe que l'abonnement doit être annulé séparément depuis les paramètres iOS

**Étant donné** la validation d'abonnement avant chaque appel Claude (FR42)
**Quand** le backend reçoit une requête de génération
**Alors** il vérifie `is_subscribed OR is_beta` sur le `user_id` extrait du JWT avant tout traitement
**Et** si invalide, retourne `{"error": {"code": "SUBSCRIPTION_REQUIRED", "message": "..."}}` avec HTTP 403
**Et** l'app Flutter affiche le paywall à réception d'un 403 sur un endpoint de génération

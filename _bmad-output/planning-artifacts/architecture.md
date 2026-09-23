---
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8]
lastStep: 8
status: 'complete'
completedAt: '2026-04-26'
inputDocuments:
  - '_bmad-output/planning-artifacts/prd.md'
  - '_bmad-output/planning-artifacts/ux-design-specification.md'
workflowType: 'architecture'
project_name: 'appMedecine'
user_name: 'Lesurmatthis'
date: '2026-04-26'
---

# Architecture Decision Document

_This document builds collaboratively through step-by-step discovery. Sections are appended as we work through each architectural decision together._

## Project Context Analysis

### Requirements Overview

**Functional Requirements:**
50 FR répartis en 8 domaines : Onboarding & Accès (FR1–6), Import & OCR (FR7–15), Génération & Fiches (FR16–23), Révision (FR24–35), Recherche (FR36–38), Compte & RGPD (FR39–42), Administration (FR43–48), Testeur Phase 0 (FR49–50).

**Non-Functional Requirements:**
12 NFR critiques : search < 1s (GIN index), génération < 2h (async queue), quiz < 100ms (offline-first), clé Claude jamais dans l'app, abonnement validé côté backend, texte OCR conservé avec le collège (NFR9 remplacée au chantier 1, 2026-09-23).

**Scale & Complexity:**
Complexité : HAUTE.

- Primary domain: Mobile Flutter (iOS-first) + Backend FastAPI/PostgreSQL
- Complexity level: High — pipeline async multi-étapes, hybrid offline/cloud, IAP + receipt validation, hash-sharing modulaire, quotas configurables runtime
- Estimated architectural components: ~12

### Technical Constraints & Dependencies

- iOS Vision Framework + BGProcessingTask (OCR natif iOS, iOS 16+)
- Claude API exclusivement backend (clé jamais dans l'app — NFR5)
- App Store IAP avec validation receipt côté serveur (NFR6)
- PostgreSQL GIN index (search full-text < 1s — NFR1)
- shadcn_ui + flutter_animate (design system décidé en UX)
- Développeur solo : opérabilité et simplicité comme contrainte architecturale de premier rang

### Cross-Cutting Concerns Identified

1. **Authentification & validation abonnement** — vérifiée à chaque appel backend générant des coûts Claude
2. **Gestion d'état offline/online** — révision 100% hors ligne, génération/search 100% cloud
3. **Propagation des états de progression longs** — OCR, génération Claude, upload : chaque étape a un état visible et récupérable
4. **Nettoyage des données** — contenu (pages OCR, textes d'items, générations) stocké par empreinte et purgé quand plus aucun collège ne le référence ; PDF supprimés avec le collège ou le compte (chantier 1 ; l'ancienne purge du texte OCR à 24 h, NFR9, est abandonnée)
5. **Configuration runtime des quotas anti-spam** — `reload_count` et `monthly_reloads` modifiables sans redéploiement
6. **RGPD** — suppression compte + données utilisateur en cascade depuis l'app (FR39)

## Starter Template Evaluation

### Primary Technology Domain

Mobile-first (Flutter iOS/Android) + Backend API (FastAPI + PostgreSQL) — deux projets distincts, stack entièrement décidé en amont.

### Flutter Mobile App

**Commande d'initialisation :**

```bash
flutter create --org=com.lesurmatthis --platforms=ios,android appmedecine
```

**Décisions fournies :** Dart null safety natif, Impeller iOS (Skia retiré), KTS Android build scripts, iOS 16+ minimum (Vision Framework).

**Stockage local (offline-first) :** SQLite + Drift — données structurées, migrations typées, requêtes complexes sur fiches/items/progression. Isar exclu (décision brainstorming 2026-04-25).

### FastAPI Backend

**Stack :** FastAPI 0.115+ · Python 3.11+ · SQLAlchemy 2.0 async · asyncpg · Alembic · PostgreSQL

**Référence structure :** full-stack-fastapi-template (backend uniquement — React non pertinent)

```
backend/
├── app/
│   ├── api/          # routes FastAPI
│   ├── models/       # SQLAlchemy ORM
│   ├── schemas/      # Pydantic (in/out)
│   ├── core/         # config, sécurité, logging
│   ├── services/     # pipeline OCR, Claude, hash-sharing
│   └── workers/      # tâches background génération
├── alembic/          # migrations
└── pyproject.toml    # Poetry
```

**Queue de génération :** ARQ (async Redis queue) — léger, persistant, async natif Python, adapté au volume solo dev. Celery écarté (over-engineering pour les volumes attendus).

**Note :** L'initialisation des deux projets (`flutter create` + structure FastAPI) constitue la première story d'implémentation.

## Core Architectural Decisions

### Decision Priority Analysis

**Décisions critiques (bloquent l'implémentation) :**
- State management Flutter → Riverpod
- Auth strategy → JWT + refresh token
- IAP validation → RevenueCat
- Progression OCR temps réel → SSE
- Hébergement → Homelab Docker Compose

**Décisions importantes (structurent l'architecture) :**
- Navigation Flutter → GoRouter
- Architecture Flutter → feature-first
- Push notifications → APNs direct Phase 1
- Admin interface → FastAPI + HTML statique (Basic Auth)

**Décisions différées (post-MVP) :**
- Migration push notifications → Firebase FCM (Phase 2 Android)
- Infrastructure cloud → à réévaluer après 20 utilisateurs
- Staging environment → ajout si charge le justifie

### Data Architecture

**Stockage local Flutter :** SQLite + Drift
- Migrations typées, requêtes complexes sur fiches/items/progression
- Offline-first : fiches et sessions quiz 100% locales après sync initiale (NFR12)

**PostgreSQL :** GIN index sur le texte des fiches pour full-text search < 1s (NFR1)
- Row-level scoping par `user_id` côté applicatif (NFR8)
- Texte OCR conservé avec le collège, par empreinte (`ocr_pages`, `item_texts`) : permet la régénération à tout moment et le réimport incrémental ; supprimé avec le collège (chantier 1, remplace NFR9)

**Hash-sharing v1 :** Interface abstraite `SimilarityChecker` dès le départ — algorithme remplaçable sans refonte (similarité textuelle post-OCR, seuil ~90% à calibrer sur vrais PDFs)

**Quotas anti-spam :** Colonnes `reload_count` (max 2/collège) et `monthly_reloads` (max 3/mois) en base, valeurs max en config backend — modifiables sans redéploiement (FR45)

### Authentication & Security

**Auth :** JWT access token (courte durée) + refresh token (longue durée)
- Stockage Flutter : `flutter_secure_storage` (Keychain iOS)
- Validation abonnement : RevenueCat SDK Flutter + webhook RevenueCat → backend (NFR6)
- Clé Claude exclusivement dans les variables d'environnement backend (NFR5)

**Accès beta :** Flag `is_beta: bool` sur le modèle `User`, activé manuellement par l'opérateur via interface admin. Vérifié côté backend avant chaque appel Claude (FR44)

**Toutes les routes backend :** HTTPS via Caddy (TLS Let's Encrypt automatique — NFR7)

### API & Communication Patterns

**REST API :** Préfixe `/v1/` sur toutes les routes. Format d'erreur standardisé Pydantic.

**Progression OCR → app :** SSE (Server-Sent Events) — stream unidirectionnel backend→app
- Correspond à l'UX "fiches qui arrivent progressivement" (pas d'écran de blocage)
- Plus simple que WebSocket, suffisant pour ce cas d'usage unidirectionnel

**Push notifications Phase 1 :** APNs direct via `aioapns` (Python async)
- "Fiches prêtes" (FR23) + rappel quotidien optionnel (FR35)
- Couche notifications abstraite dès le départ pour migration FCM Phase 2

**Évaluation sémantique (FR29) :** Appel Claude ciblé pour les fiches définition (pas d'embedding local). Coût négligeable, déclenché uniquement sur réponse textuelle significative.

### Frontend Architecture (Flutter)

**State management :** Riverpod (`flutter_riverpod` + `riverpod_annotation`)
- Async natif, bien adapté offline-first, typé, standard 2025-2026

**Navigation :** GoRouter — deep linking, type-safe, recommandation officielle Flutter team

**Organisation du code :** Feature-first
```
lib/
├── features/
│   ├── auth/
│   ├── colleges/
│   ├── drill/
│   ├── search/
│   ├── planning/
│   └── profile/
├── shared/          # composants partagés
└── core/            # config, routing, theme
```

**Design system :** shadcn_ui + flutter_animate (décidé en UX spec)
- Breakpoint iPad unique à 600px via `LayoutBuilder`

### Infrastructure & Deployment

**Hébergement :** Homelab — Docker Compose sur serveur maison
```yaml
services:
  api        # FastAPI (Uvicorn)
  db         # PostgreSQL 16
  redis      # ARQ queue
  caddy      # Reverse proxy + TLS Let's Encrypt automatique
```

**Environnements :** `dev` (local Docker Compose) + `prod` (homelab)
- Pas de staging Phase 1 — développeur solo, validation directe en beta contrôlée
- Révision infrastructure cloud après ~20 utilisateurs payants

**Interface admin (Phase 0) :** Routes FastAPI + templates Jinja2 ou HTML statique
- Sécurisé par HTTP Basic Auth
- Déclenchement manuel génération, monitoring queue, gestion accès beta (FR47–FR50)

### Decision Impact Analysis

**Séquence d'implémentation imposée par les décisions :**
1. Setup Docker Compose (homelab) + Caddy + PostgreSQL + Redis
2. `flutter create` + structure feature-first + Riverpod + GoRouter
3. Auth JWT + RevenueCat IAP
4. Pipeline OCR → SSE → génération Claude → Drift local
5. Mode Drill offline-first
6. Search full-text PostgreSQL GIN
7. Interface admin Phase 0

**Dépendances inter-composants clés :**
- SSE requiert une connexion persistante → gérer la reconnexion côté Flutter si background
- RevenueCat webhook → backend doit exposer un endpoint public signé (HTTPS Caddy obligatoire dès le départ)
- ARQ workers partagent le pool PostgreSQL async → limiter les connexions concurrentes (pool sizing)

## Implementation Patterns & Consistency Rules

### Naming Patterns

**Base de données (PostgreSQL) — snake_case, pluriel**
```sql
-- ✅ Correct
users, college_imports, flash_cards, ocr_results
user_id, college_id, created_at, reload_count
-- ❌ Incorrect
Users, FlashCard, userId, createdAt
```

**API endpoints (FastAPI) — snake_case, pluriel, ressources**
```
✅  GET    /v1/colleges
✅  POST   /v1/colleges/{college_id}/import
✅  GET    /v1/flash-cards
❌  GET    /v1/getColleges
❌  POST   /v1/college/Import
```

**Dart/Flutter — conventions officielles**
```
Fichiers     : snake_case  → flash_card_widget.dart
Classes      : PascalCase  → class FlashCardWidget {}
Variables    : camelCase   → final flashCardCount
```

**Python/FastAPI — snake_case partout (modèles, fonctions, variables)**

### Structure Patterns

**Flutter — feature-first, structure interne uniforme par feature**
```
features/drill/
├── data/
│   ├── drill_repository.dart
│   └── drill_remote_datasource.dart
├── domain/
│   └── drill_state.dart
├── presentation/
│   ├── drill_screen.dart
│   └── widgets/
└── drill_providers.dart
```

**Python — modules par domaine dans `services/` (ocr/, generation/, search/, billing/)**

### Format Patterns

**Réponse API — wrapper systématique**
```json
{ "data": { ... } }
{ "data": [...], "total": 42 }
{ "error": { "code": "QUOTA_EXCEEDED", "message": "...", "reset_at": "..." } }
```

**Dates — ISO 8601 UTC partout (jamais timestamp Unix)**
**JSON — snake_case côté API (Pydantic gère la conversion)**

### Communication Patterns

**Riverpod — AsyncNotifier + naming uniforme**
```dart
// Provider    : [feature]Provider
// Notifier    : [Feature]Notifier extends AsyncNotifier<[Feature]State>
// State       : [Feature]State — immuable avec copyWith
```

**SSE events — format uniforme**
```json
{ "event": "ocr_progress",       "data": { "page": 12, "total": 380 } }
{ "event": "card_generated",     "data": { "card_id": "uuid", "rang": "A" } }
{ "event": "generation_complete","data": { "college_id": 5, "card_count": 84 } }
```

### Process Patterns

**Erreurs Flutter — AsyncValue.when() + ShadToast (non-bloquant) / ShadAlertDialog (bloquant)**
**Erreurs FastAPI — HTTPException avec detail structuré `{code, message, ...}`**
**Loading — ShadSkeleton systématiquement (jamais CircularProgressIndicator)**
**Tests Flutter — `test/features/[feature]/` ; Tests Python — `tests/` miroir de `app/`**

### Enforcement Guidelines

**Tous les agents MUST :**
- snake_case en base et API, PascalCase classes Dart, snake_case fichiers Dart
- Wrapper `{ "data": ... }` ou `{ "error": ... }` sur toutes les réponses API
- ISO 8601 UTC pour toutes les dates
- AsyncNotifier Riverpod pour tout état async Flutter
- ShadSkeleton pour loading, ShadToast pour erreurs non-bloquantes
- SSE format `{ "event": "...", "data": { ... } }` pour tous les streams

**Tous les agents NEVER :**
- `print()` ou `debugPrint()` en code de production
- Logique métier dans les widgets Flutter (→ dans les Notifiers)
- Appels API directs depuis les widgets (→ via Repository + Provider)
- Retourner une erreur dans le champ `"data"` d'une réponse API

## Project Structure & Boundaries

### Complete Project Directory Structure

**Flutter App (`collega_app/`)**

```
collega_app/
├── pubspec.yaml                    # flutter_riverpod, go_router, drift, shadcn_ui,
│                                   # flutter_animate, flutter_secure_storage,
│                                   # purchases_flutter (RevenueCat), file_picker
├── analysis_options.yaml
├── .env.dart                       # endpoints backend (jamais de secrets)
├── lib/
│   ├── main.dart                   # entry point, ProviderScope, GoRouter
│   ├── app.dart                    # MaterialApp + thème shadcn_ui
│   ├── core/
│   │   ├── router/app_router.dart  # GoRouter — toutes les routes
│   │   ├── theme/app_theme.dart    # palette #1B6B3A, Inter, tokens shadcn
│   │   ├── database/
│   │   │   ├── app_database.dart   # Drift database
│   │   │   └── tables/             # colleges, flash_cards, items, sessions
│   │   ├── network/
│   │   │   ├── api_client.dart     # Dio + intercepteur JWT
│   │   │   └── sse_client.dart     # SSE streaming progression OCR
│   │   └── utils/
│   │       ├── logger.dart         # logging prod (jamais print)
│   │       └── date_utils.dart     # ISO 8601 UTC
│   ├── features/
│   │   ├── demo/                   # FR1 — démo interactive sans compte
│   │   ├── auth/                   # FR2–6 — inscription, login, paywall IAP
│   │   │   └── data/revenuecat_service.dart
│   │   ├── colleges/               # FR7–15 — liste, import, OCR, progression
│   │   │   └── widgets/
│   │   │       ├── college_progress_tile.dart
│   │   │       └── ocr_confidence_badge.dart
│   │   ├── generation/             # FR16–23 — fiches, feedback, régénération
│   │   │   └── widgets/flash_card_widget.dart
│   │   ├── drill/                  # FR24–29 — Mode Drill, spaced repetition (offline)
│   │   │   └── widgets/
│   │   │       ├── drill_evaluation_bar.dart
│   │   │       └── item_progress_bar.dart
│   │   ├── planning/               # FR30–35 — session du jour, planning algo (offline)
│   │   │   └── widgets/session_hero_card.dart
│   │   ├── search/                 # FR36–38 — full-text, mode stage
│   │   │   └── widgets/search_result_tile.dart
│   │   └── profile/                # FR39–42 — compte, RGPD, abonnement
│   └── shared/widgets/
│       ├── bottom_nav_bar.dart
│       └── error_view.dart
└── test/features/                  # tests co-localisés par feature
```

**FastAPI Backend (`collega_backend/`)**

```
collega_backend/
├── pyproject.toml                  # fastapi, sqlalchemy, alembic, asyncpg,
│                                   # arq, anthropic, aioapns, pydantic-settings
├── docker-compose.yml              # api, db (PostgreSQL), redis, caddy
├── Caddyfile                       # TLS Let's Encrypt automatique
├── .env.example
├── alembic/versions/
└── app/
    ├── main.py
    ├── deps.py                     # dépendances (session DB, user courant)
    ├── core/
    │   ├── config.py               # pydantic-settings (quotas anti-spam configurables)
    │   ├── security.py             # JWT
    │   ├── database.py             # async engine
    │   └── redis.py                # pool Redis (ARQ)
    ├── models/
    │   ├── user.py                 # id, email, is_beta, monthly_reloads
    │   ├── college.py              # id, user_id, reload_count, status
    │   ├── flash_card.py           # rang, ocr_confidence, generation_id (sortie Claude d'origine)
    │   ├── item.py
    │   └── generation_job.py       # status, queue ARQ
    ├── schemas/
    ├── api/v1/
    │   ├── auth.py                 # /v1/auth/register, /login, /refresh
    │   ├── colleges.py             # /v1/colleges — import, reload (quota check)
    │   ├── flash_cards.py          # feedback, delete
    │   ├── search.py               # GIN PostgreSQL < 1s
    │   ├── generation.py           # SSE /v1/generation/{job_id}/stream
    │   ├── billing.py              # /v1/webhooks/revenuecat
    │   ├── notifications.py        # APNs token registration
    │   └── admin.py                # Phase 0 (Basic Auth) — FR47–50
    ├── services/
    │   ├── ocr/
    │   │   ├── ocr_processor.py
    │   │   └── confidence_scorer.py
    │   ├── generation/
    │   │   ├── claude_client.py
    │   │   ├── hash_sharing.py     # SimilarityChecker (interface abstraite)
    │   │   └── card_generator.py
    │   ├── search/full_text_search.py
    │   ├── billing/revenuecat.py
    │   └── notifications/apns_service.py
    └── workers/
        ├── settings.py
        ├── generation_worker.py    # génération Claude + retry (NFR10)
        ├── cleanup_worker.py       # quotas mensuels, uploads par morceaux orphelins
        └── maintenance_worker.py   # imports bloqués, purge du contenu non référencé et des PDF orphelins
tests/
├── api/
├── services/
└── workers/
```

### Requirements to Structure Mapping

| Domaine FR | Flutter | Backend |
|---|---|---|
| Onboarding/Auth (FR1–6) | `auth/`, `demo/` | `api/v1/auth.py`, `services/billing/` |
| Import & OCR (FR7–15) | `colleges/` | `api/v1/colleges.py`, `services/ocr/` |
| Génération fiches (FR16–23) | `generation/` | `services/generation/`, `workers/` |
| Drill & révision (FR24–29) | `drill/` | — (100% local Drift) |
| Planning (FR30–35) | `planning/` | — (100% local) |
| Search (FR36–38) | `search/` | `api/v1/search.py`, `services/search/` |
| Compte & RGPD (FR39–42) | `profile/` | `api/v1/auth.py` (delete cascade) |
| Admin Phase 0 (FR43–50) | — | `api/v1/admin.py` |

### Data Flow — Flux Principaux

```
Import PDF :  file_picker → SSE /v1/generation/{id}/stream → OCR → ARQ → Claude → Drift
Drill :       Drift (local) → Riverpod → UI  [aucun appel réseau]
Search :      Flutter → GET /v1/search → PostgreSQL GIN → résultats contextuels
IAP :         App Store → RevenueCat → POST /v1/webhooks/revenuecat → user.is_subscribed
Push :        ARQ worker → aioapns → APNs → iPhone
Nettoyage :   maintenance_worker (ARQ cron) → contenu non référencé, PDF orphelins, imports bloqués
```

## Architecture Validation Results

### Cohérence ✅

Toutes les décisions sont compatibles : Flutter 3.41.5 + Riverpod + GoRouter + Drift · FastAPI + SQLAlchemy 2.0 async + asyncpg + ARQ · RevenueCat SDK + webhook FastAPI · SSE (StreamingResponse) + Dio Flutter · Caddy + Docker Compose homelab.

### Couverture des Exigences ✅

**50 FR — tous couverts architecturalement** (mapping complet dans la section Project Structure).

**12 NFR adressés :**

| NFR | Composant |
|---|---|
| NFR1 search < 1s | GIN index PostgreSQL |
| NFR2 génération < 2h | ARQ async + retry backoff |
| NFR3 quiz < 100ms | Drift local, zéro réseau |
| NFR4 startup < 3s | Lazy loading Riverpod (aucun provider bloquant dans main.dart) |
| NFR5 clé Claude backend | `claude_client.py` + env vars Docker |
| NFR6 abonnement validé | RevenueCat webhook + guard backend avant Claude |
| NFR7 HTTPS | Caddy TLS Let's Encrypt automatique |
| NFR8 isolation user_id | Scoping applicatif PostgreSQL sur toutes les requêtes |
| NFR9 (remplacée) texte OCR conservé avec le collège | `services/content/` + `maintenance_worker.py` (purge à la suppression) |
| NFR10 Claude indisponible | ARQ queue persistante + retry backoff |
| NFR11 OCR reprise | Voir gap résolu ci-dessous |
| NFR12 offline quiz | Drift local après sync initiale |

### Gaps Identifiés et Résolus

**Gap 1 — NFR4 startup (résolu)**
Règle ajoutée : aucun provider bloquant dans `main.dart`. Providers `colleges` et `planning` en lazy init Riverpod (comportement par défaut).

**Gap 2 — NFR11 reprise OCR (résolu)**
- Colonne `ocr_page_progress: int` dans `colleges_table` (Drift) — persiste la page courante
- Au retour foreground : `GET /v1/colleges/{id}/status` → reconnexion SSE si job encore actif en queue ARQ

**Gap 3 — Flux SSE → Drift (résolu)**
Chaîne documentée : `sse_client.dart` reçoit events → notifie `GenerationNotifier` (Riverpod) → `generation_repository.dart` écrit dans Drift → UI se met à jour via `ref.watch`

### Architecture Completeness Checklist

- [x] Contexte projet analysé (50 FR, 12 NFR, complexité haute)
- [x] Stack technique décidée et versions vérifiées
- [x] Décisions critiques documentées (Riverpod, GoRouter, RevenueCat, SSE, ARQ, Caddy)
- [x] Patterns de nommage, structure et communication définis
- [x] Structure complète des deux projets (collega_app + collega_backend)
- [x] Mapping FR → composants
- [x] Flux de données principaux documentés
- [x] Gaps identifiés et résolus

### Architecture Readiness Assessment

**Statut : PRÊT POUR L'IMPLÉMENTATION**
**Confiance : Haute**

**Points forts :**
- Architecture offline-first claire : Drift local = source de vérité pour la révision
- Pipeline async cohérent bout en bout (BGProcessingTask → SSE → ARQ → Claude → Drift)
- Hash-sharing modulaire via `SimilarityChecker` (interface abstraite — remplaçable sans refonte)
- Quotas anti-spam configurables sans redéploiement (`pydantic-settings`)
- Homelab Docker Compose : simplicité opérationnelle maximale pour un développeur solo

**À surveiller post-lancement :**
- `shadcn_ui` Flutter (port communautaire) : vérifier maintenance active avant de démarrer
- Pool sizing PostgreSQL + ARQ workers : ajuster selon charge réelle en beta
- Abstraire `NotificationService` dès le départ pour migration APNs → FCM Phase 2 Android

### Implementation Handoff

**Première story d'implémentation :**
1. `docker-compose up` homelab — PostgreSQL + Redis + Caddy opérationnels
2. `flutter create --org=com.lesurmatthis --platforms=ios,android collega_app`
3. Setup `collega_backend/` avec structure FastAPI + Alembic + ARQ

**Règle fondamentale pour tous les agents :**
Ce document fait autorité. Toute décision architecturale non documentée ici doit être résolue en cohérence avec les décisions existantes — jamais en introduisant un nouveau pattern sans validation.

# Chantier 5 — Refactorisation et nettoyage admin/testeur : spécification

Date : 2026-09-24 · Statut : validée avec l'utilisateur · Branche : `feat/refonte-back-infra` (commune aux chantiers 2 à 5)
Contexte : `audit-back-infra-2026-09-23.md` (« Architecture du code », « Admin »). Aucun changement de comportement visible pour l'app, sauf le format d'erreur unifié (compatible, § 4).

## 1. Décisions

| # | Décision |
|---|---|
| R1 | **Partie testeur web supprimée** : page `/tester`, routes `/v1/tester/*`, identifiants `TESTER_*`. Les avis passent désormais par l'app (pouces du drill → `flash_cards.user_feedback`, API conservée). |
| R2 | La table `tester_feedbacks` est **exportée en CSV puis supprimée** par migration. |
| R3 | Les vues admin « feedback » et « pertinence » lisent `flash_cards.user_feedback`. |
| R4 | Les réglages anti-spam (`reload_count_max`, `monthly_reloads_max`) sont **enregistrés en base** (table de réglages) et lus par l'API et le worker ; les valeurs du `.env` servent de valeurs par défaut. |
| R5 | Refactorisation **sans changement de comportement** (hors R1-R4 et § 4) : les tests existants restent verts sans être réécrits, sauf les imports. |

## 2. Découpage des modules

- `app/api/v1/colleges.py` (922 lignes) → paquet `app/api/v1/colleges/` :
  - `catalog.py` : liste, limites de réimport ;
  - `imports.py` : upload simple et par morceaux, lancement d'import ;
  - `status.py` : statut, flux SSE ;
  - `cards.py` : items et fiches.

  Le `router` est exposé par `__init__.py` : mêmes chemins, mêmes noms de dépendances.
- `app/api/v1/admin.py` (975 lignes) → paquet `app/api/v1/admin/` :
  - `colleges.py` : import admin, stats, suppression, fiches, feedback ;
  - `jobs.py` : file, détail, arrêt ;
  - `users.py` : liste, création, bêta, reset-quota, détail, reset-password du chantier 2 ;
  - `usage.py` : vue d'ensemble, coûts ;
  - `config.py`.
- **Service d'import partagé** `app/services/imports.py` : la logique commune à l'import utilisatrice (`colleges`) et à l'import admin — création/réutilisation du collège, contrôle du PDF, verrou, quota, création du job, mise en file ARQ — n'existe qu'une fois. Les routes ne gardent que l'HTTP (lecture de la requête, codes de réponse).
- Les monkeypatch des tests (`app.api.v1.admin.abort_arq_job`, `async_session_factory` dans `tests/api_pg.py`…) sont mis à jour vers les nouveaux modules ; aucune assertion de test n'est modifiée.

## 3. Pool ARQ unique

- Un seul pool ARQ créé dans le `lifespan` de `app/main.py`, stocké dans `app.state.arq`, fermé à l'arrêt ; dépendance `get_arq(request)`.
- Remplace les 4 `create_pool` ad hoc (`colleges.py` × 2, `admin.py`, `services/jobs/arq_control.py`).
- `chunked_upload` utilise le même pool.
- Tests : un faux pool injecté par surcharge de dépendance.

## 4. Erreurs uniformes

- `app/core/errors.py` : `AppError(status_code, code, message, extra=None)`, avec un gestionnaire qui répond `{"detail": {"code": ..., "message": ...}}`. C'est le format déjà utilisé par les `HTTPException` de l'app : l'app mobile n'a rien à changer.
- Les `HTTPException(status_code, detail={"code": ...})` existantes (~70) passent à `AppError` ou à des fabriques nommées (`not_found("JOB_NOT_FOUND")`…).
- Gestionnaires ajoutés au même format :
  - 422 de validation → `code: "VALIDATION_ERROR"`, avec la liste des champs en `extra` ;
  - 429 slowapi → `code: "RATE_LIMITED"` et en-tête `Retry-After` ;
  - 500 → `code: "INTERNAL_ERROR"`, sans détail interne ; l'exception est journalisée.
- Tests : un test par gestionnaire. Côté app, vérifier que `api_client.dart` lit bien `detail.code` pour les 422 et 429. Si un écran affichait le détail brut, le faire passer au message du code.

## 5. Suppression du testeur

- Supprimés :
  - `app/api/v1/tester.py` ;
  - `app/schemas/tester.py` ;
  - `app/models/tester_feedback.py` et son import dans `models/__init__.py` ;
  - `get_tester_user` et `_http_basic_tester` dans `deps.py` ;
  - `tester_username`/`tester_password` et leurs validateurs dans `config.py` ;
  - le montage `/tester` et le routeur dans `main.py` ;
  - `app/static/index.html` (page testeur) ;
  - les tests du testeur.
- `app/static/admin/` et `logo.svg` restent. Si le logo n'était servi que par le montage `/tester`, il est servi par le montage admin.
- Les références au testeur dans `admin/index.html` et `schemas/admin.py` sont retirées ou basculées sur `user_feedback` (R3).
- **Export avant suppression** : `scripts/export_tester_feedbacks.py` écrit `tester_feedbacks_<date>.csv`. L'export est lancé sur le NAS **avant** la migration, puis rapatrié dans `_bmad-output/implementation-artifacts/exports/` (git-ignoré s'il contient du contenu de fiches : à vérifier ; sinon committé). Migration : `DROP TABLE tester_feedbacks`.
- Les variables `TESTER_*` du `.env` du NAS deviennent inutiles. Elles sont **laissées en place**, parce que le `.env` n'est jamais réécrit ; la config ignore les variables inconnues (vérifier `extra="ignore"`).
- Docs : les mentions du testeur web sont retirées de `docs/` et de `privacy.md`, si elles existent.

## 6. Réglages en base

- Table `app_settings` (`key` TEXT PK, `value` JSONB, `updated_at`) : migration au prochain numéro libre.
- `app/services/app_settings.py` :
  - `get_setting(db, key, default)` ;
  - `set_setting(db, key, value)` ;
  - cache mémoire de 30 s par processus, invalidé localement à l'écriture ; le worker et les autres processus voient la nouvelle valeur en ≤ 30 s.
- `GET`/`PATCH /v1/admin/config` lisent et écrivent la table. Les valeurs de `settings` (`.env`) servent de défaut tant qu'aucune ligne n'existe. Validation : entiers ≥ 0.
- Tous les lecteurs de `settings.reload_count_max`/`monthly_reloads_max` (limites de réimport, quota, écran `reload-limits`) passent par `get_setting`.
- Tests Postgres : PATCH puis GET ; valeur vue par un autre processus simulé (cache expiré) ; défaut `.env` sans ligne.

## 7. Divers

- Imports différés (`from arq import create_pool` dans les fonctions, `from app.schemas.college import …` dans `claude_client`) remontés en tête de module quand il n'y a pas de cycle.
- Code mort signalé par ruff/vulture et confirmé par une recherche : supprimé.
- `CLAUDE.md` (section conventions du chantier 3) : structure `api/v1/<domaine>/`, `AppError`, pool ARQ du lifespan, service d'import partagé.

## 8. Vérification

- Suite complète verte : unitaires, Postgres et app.
- Comparaison de l'OpenAPI avant/après : mêmes chemins et mêmes méthodes, moins `/v1/tester/*`.
- Déploiement par `deploy.sh`, avec l'export CSV fait avant.
- Contrôles :
  - console admin : fiches, feedback, coûts, config (modifier une valeur, redémarrer l'API, constater qu'elle persiste) ;
  - un import depuis l'app ;
  - `/tester` → 404.

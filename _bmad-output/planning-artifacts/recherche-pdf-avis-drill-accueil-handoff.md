# Prompt de reprise — recherche, PDF local, avis en drill, série sur l'Accueil

À coller tel quel dans une nouvelle session Claude Code ouverte à la racine du dépôt `collega`.

---

Implémente les 4 plans validés de la fonctionnalité « recherche en sections, PDF sur le téléphone, avis pendant le drill, série sur l'Accueil ». La spec et les plans ont été écrits et approuvés le 2026-09-26 ; ne refais pas le cadrage.

**À lire d'abord**
- Spec : `_bmad-output/planning-artifacts/recherche-pdf-avis-drill-accueil-spec.md`
- Plans, **dans cet ordre d'exécution** :
  1. `_bmad-output/planning-artifacts/avis-drill-plan.md` (4 tâches, app seule)
  2. `_bmad-output/planning-artifacts/recherche-sections-plan.md` (4 tâches, app seule)
  3. `_bmad-output/planning-artifacts/accueil-serie-plan.md` (8 tâches, app seule, migration drift 8 → 9)
  4. `_bmad-output/planning-artifacts/pdf-local-plan.md` (11 tâches, backend + app, migration drift 9 → 10)
- `CLAUDE.md` du dépôt (commandes de test, conventions backend, déploiement, NAS).

**Méthode**
- Utilise le skill `superpowers:executing-plans` (exécution native : j'ai choisi que tu implémentes toi-même, tâche par tâche, en TDD, avec un commit par tâche), puis une relecture indépendante de toute la branche à la fin (`superpowers:requesting-code-review`).
- Branche : crée `feat/recherche-pdf-drill-accueil` **à partir de `feat/beta-testflight`** (qui n'est pas encore mergée dans `main` et contient l'outillage iOS/TestFlight dont on a besoin).
- **Autonomie** : je ne suis pas disponible pendant l'implémentation. Si tu rencontres un problème ou un choix non prévu, prends la solution que tu recommandes, note-la (fichier de plan concerné, section « Écarts » ou journal en fin de plan) et continue. Ne t'arrête que sur un vrai blocage (par ex. `pdfrx` 1.0.103 ne compile pas ET le repli PDFKit natif échoue aussi).
- Tests : backend `docker compose -f docker-compose.test.yml up -d` puis `.venv/bin/python -m pytest -q`, `ruff check .`, `ruff format --check .`, `mypy app/core app/services` (0 erreur), `alembic check`. App : `flutter test` **par dossier** (`test/core`, puis chaque `test/features/<dossier>`), jamais toute la suite ; goldens régénérés quand un plan le demande.
- Kage : `kage_context` au début, `kage_learn` pour les vraies découvertes, `kage_refresh` + `kage_pr_check` à la fin.

**Déjà décidé (ne pas rediscuter)**
- Recherche : sections empilées « Collèges » (local, dès 1 caractère, nom + éditeur, sans accents) puis « Items » (serveur inchangé) ; collège non importé → action « Importer ».
- Drill : deux icônes pouce seules en haut de la feuille de réponse (verso), feuille « À corriger » partagée avec la vue item, régénération non bloquante.
- Accueil : option B (grand rond coché + coches dans la semaine, animation une seule fois, vibration légère `CgHaptics.good()`, rien si « Réduire les animations ») + badge « N jours d'affilée » dès 2, série **sur le téléphone uniquement**.
- PDF : copie locale gardée à l'import (hors iCloud), retéléchargement depuis le serveur si absente ou périmée (`pdf_version` = id du dernier import publié), lecteur `pdfrx` 1.0.103 montrant tout le PDF ouvert à la page de l'item, avec bandeau « Item N · p. X–Y » ; accès : ligne « Mon PDF du collège » (vue collège), lien « Lire dans le PDF · p. X–Y » (item), « Vérifier dans le PDF » (feuille « Source à vérifier »). Avertissement Wi-Fi toujours affiché.

**Quand tout est implémenté et vert**
1. Pousse la branche.
2. Produis un build TestFlight de la branche avec `collega_app/tool/build_ipa.sh` (clé API App Store Connect, voir la mémoire « Beta TestFlight ») **pointant sur le backend de prod**. Attention : la partie PDF a besoin du nouveau backend ; tant qu'il n'est pas déployé, la ligne PDF doit simplement se comporter comme « PDF indisponible » sans planter (vérifie-le).
3. Donne-moi une liste de vérification courte à faire sur mon iPhone (Wi-Fi, 4G, hors ligne, drill, recherche « neuro », Accueil après une session, PDF d'un collège importé avant cette version).
4. **Arrête-toi là** et attends mon retour du test sur téléphone.

**Après mon « c'est bon »** (seulement à ce moment-là)
1. Merge dans `main` (et `feat/beta-testflight` si toujours non mergée : demande-moi l'ordre si doute), pousse.
2. Déploie le backend **uniquement** via `collega_backend/scripts/deploy.sh <sha>` (CI verte requise, dump avant migration, image étiquetée par commit, jamais `latest`). Ne touche jamais au `.env` de prod sur le NAS au-delà d'un ajout de ligne précis ; n'affiche jamais un secret.
3. Vérifie la prod (route `/v1/colleges/{id}/pdf` sur un collège de test, logs API) puis envoie un nouveau build TestFlight depuis `main`.
4. Mets à jour les mémoires (auto-mémoire et Kage) avec l'état final.

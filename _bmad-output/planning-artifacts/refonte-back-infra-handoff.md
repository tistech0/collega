# Refonte back/infra — passation pour l'implémentation autonome

Date : 2026-09-24 · Chantiers 0 et 1 : faits, déployés, mergés (main `0e6a28d` + specs de ce jour).
Audit de référence : `audit-back-infra-2026-09-23.md`.

## Ordre et specs (toutes validées par l'utilisateur)

| Ordre | Chantier | Spec | Branche |
|---|---|---|---|
| 1 | 3 — Outillage de développement (CI, `deploy.sh`, ruff/mypy, image, Redis, docs) | `chantier-3-outillage-dev-spec.md` | `feat/chantier-3-outillage` |
| 2 | 5 — Refactorisation et nettoyage admin/testeur | `chantier-5-refacto-spec.md` | `feat/chantier-5-refacto` |
| 3 | 2 — Sécurité (Cloudflare Access admin, rotation des sessions, PyJWT, limites) | `chantier-2-securite-spec.md` | `feat/chantier-2-securite` |
| 4 | 4 — Génération des fiches (Sonnet 5, prompt p2, découpage, coûts, vidage + réimport) | `chantier-4-couts-claude-spec.md` | `feat/chantier-4-generation` |

Chaque branche part de `main` **après** le merge de la précédente. Les numéros de migration sont attribués dans l'ordre d'implémentation (prochain numéro libre au moment du chantier).

## Méthode par chantier

1. `kage_context` sur le chantier ; relire la spec et le code actuel (les specs décrivent l'intention ; le code a pu bouger).
2. Écrire le plan (`superpowers:writing-plans`) dans `_bmad-output/planning-artifacts/chantier-N-…-plan.md`, sur la branche du chantier.
3. Implémenter tâche par tâche en TDD (`superpowers:subagent-driven-development` ou `executing-plans`), commits fréquents.
4. Suite complète verte : backend (`docker compose -f docker-compose.test.yml up -d` puis `pytest`), app (`flutter test` **par dossier**), et CI verte dès le chantier 3.
5. Revue de code indépendante de toute la branche (agent séparé) ; corriger tout ce qui est fondé.
6. Déployer sur le NAS (dès le chantier 3 : `deploy.sh`, sinon procédure du chantier 1) avec **dump avant migration** ; surveiller les logs ; vérifications de la spec.
7. Mémoire : `kage_learn` pour les apprentissages, `kage_refresh`, `kage_propose_from_diff`/`kage_pr_summarize`, `kage_pr_check` ; mettre à jour l'audit (chantier marqué fait) et la mémoire auto (`project_refonte_back_infra_2026_09.md`).
8. Rapport à l'utilisateur, puis **attendre son « OK merge »** avant de merger dans `main` et d'attaquer le chantier suivant.

## Règles d'autonomie (demandées par l'utilisateur)

- Aller jusqu'au bout ; tout bug ou problème rencontré est corrigé tout de suite, jamais reporté dans un fichier « à faire plus tard ».
- Devant un choix, prendre la solution recommandée et la noter dans le rapport ; ne poser une question que si une décision est vraiment celle de l'utilisateur (hors specs) ou bloquante.
- Merge dans `main` **uniquement** après « OK merge ».
- Ne **jamais écraser** le `.env` du NAS (`/mnt/user/appdata/compose-stacks/collega/.env`) : seulement ajouter une variable ; ne jamais afficher de secret de prod.
- Le vidage de contenu du chantier 4 est **autorisé** (décision C6) ; aucune autre suppression de données de prod sans accord.
- Contenu publié (CGU, confidentialité…) : éditeur Matthis Lesur, contact@matthislesur.com.
- Alertes : Telegram direct (Unraid notify niveau `alert`), pas healthchecks.io.

## Ce qui reste à l'utilisateur

- Chantier 2 : créer l'application Cloudflare Access `collega-admin` (étapes guidées dans la spec § 7).
- Chantiers 2 et 4 : installer la nouvelle build sur l'iPhone (`collega_app/tool/run_device.sh --release -d 00008110-000115D43499801E`) et valider ; une seule installation si 2 et 4 sont prêts ensemble. Rebuild à faire de toute façon avant le 28/09.
- Chantier 4 : fournir le PDF d'hématologie (à la racine du dépôt, git-ignoré) ; lire le contrôle de fumée ; réimporter ses collèges après le vidage.
- Les « OK merge ».
- Hors chantiers : compte Apple Developer payant + clé APNs `.p8` (le code fait comme si elle existait) ; à l'arrivée de la clé, corriger l'écart de bundle ID et ajouter les entitlements.
- Après toute la refonte : fonctionnalité « question pendant le drill » (pouces), puis test hors LAN et reprise d'upload.

## Prompt à coller dans la nouvelle session

```
On implémente la refonte back/infra de Collega en autonomie. Lis
_bmad-output/planning-artifacts/refonte-back-infra-handoff.md et suis-le :
ordre 3 → 5 → 2 → 4, une branche par chantier, plan puis TDD, revue
indépendante, déploiement avec dump, mémoire Kage à jour. Corrige tout
problème rencontré sans le reporter, choisis toujours la solution que tu
recommandes, et attends mon « OK merge » à la fin de chaque chantier avant
d'enchaîner. Commence par le chantier 3.
```

# Refonte back/infra — passation pour l'implémentation autonome

Date : 2026-09-24 · Chantiers 0 et 1 : faits, déployés, mergés (main `0e6a28d` + specs de ce jour).
Audit de référence : `audit-back-infra-2026-09-23.md`.

## Ordre et specs (toutes validées par l'utilisateur)

**Une seule branche pour tous les chantiers : `feat/refonte-back-infra`** (créée le 2026-09-24, contient déjà les specs). Les chantiers s'enchaînent dessus **sans attendre l'utilisateur** : il ne revient qu'une fois les quatre terminés.

| Ordre | Chantier | Spec |
|---|---|---|
| 1 | 3 — Outillage de développement (CI, `deploy.sh`, ruff/mypy, image, Redis, docs) | `chantier-3-outillage-dev-spec.md` |
| 2 | 5 — Refactorisation et nettoyage admin/testeur | `chantier-5-refacto-spec.md` |
| 3 | 2 — Sécurité (Cloudflare Access admin, rotation des sessions, PyJWT, limites) | `chantier-2-securite-spec.md` |
| 4 | 4 — Génération des fiches (Sonnet 5, prompt p2, découpage, coûts, vidage + réimport) | `chantier-4-couts-claude-spec.md` |

Numéros de migration attribués dans l'ordre d'implémentation (prochain numéro libre).

## Méthode par chantier

1. `kage_context` sur le chantier ; relire la spec et le code actuel (les specs décrivent l'intention ; le code a pu bouger).
2. Écrire le plan (`superpowers:writing-plans`) dans `_bmad-output/planning-artifacts/chantier-N-…-plan.md`.
3. Implémenter tâche par tâche en TDD (`superpowers:subagent-driven-development` ou `executing-plans`), commits fréquents sur `feat/refonte-back-infra`, push régulier.
4. Suite complète verte : backend (`docker compose -f docker-compose.test.yml up -d` puis `pytest`), app (`flutter test` **par dossier**), et CI verte dès le chantier 3.
5. Revue de code indépendante du chantier (agent séparé) ; corriger tout ce qui est fondé.
6. Déploiement : voir la politique ci-dessous.
7. Mémoire : `kage_learn`, `kage_refresh`, `kage_propose_from_diff`/`kage_pr_summarize`, `kage_pr_check` ; audit mis à jour (chantier fait) ; mémoire auto (`project_refonte_back_infra_2026_09.md`).
8. Enchaîner directement sur le chantier suivant.

## Politique de déploiement (l'utilisateur est absent pendant l'implémentation)

- **Chantiers 3 et 5 : déployés en autonomie** depuis la branche (`deploy.sh <sha>`, dump avant migration, vérifications de la spec). Ils ne changent rien pour l'app installée. Pour le chantier 5 : export CSV de `tester_feedbacks` avant la migration.
- **Chantiers 2 et 4 : implémentés, testés et contrôlés (dont le contrôle de fumée Claude du chantier 4), mais PAS déployés.** Ils demandent l'utilisateur :
  - le chantier 2 déconnecterait en boucle l'app actuellement installée (elle ne garde pas le nouveau refresh token) ;
  - le chantier 4 vide les collèges.

  Ils sont déployés ensemble à son retour, dans cet ordre :
  1. il installe la nouvelle build sur l'iPhone ;
  2. déploiement (migrations 2 et 4) ;
  3. vidage du contenu ;
  4. il configure Cloudflare Access admin ;
  5. il réimporte ses collèges pendant que la session surveille les logs.
- Rien n'est mergé dans `main` sans son « OK merge », donné une seule fois à la fin pour toute la branche.

## Règles d'autonomie (demandées par l'utilisateur)

- Aller jusqu'au bout ; tout bug ou problème rencontré est corrigé tout de suite, jamais reporté dans un fichier « à faire plus tard ».
- Devant un choix, prendre la solution recommandée et la noter dans le rapport ; ne poser une question que si une décision est vraiment celle de l'utilisateur et bloquante (sinon, choisir et continuer).
- Ne **jamais écraser** le `.env` du NAS (`/mnt/user/appdata/compose-stacks/collega/.env`) : seulement ajouter une variable ; ne jamais afficher de secret de prod.
- Le vidage de contenu du chantier 4 est autorisé (décision C6), au moment du déploiement final ; aucune autre suppression de données de prod sans accord.
- Contenu publié (CGU, confidentialité…) : éditeur Matthis Lesur, contact@matthislesur.com.
- Alertes : Telegram direct (Unraid notify niveau `alert`), pas healthchecks.io.

## À rappeler à l'utilisateur UNIQUEMENT à la toute fin (rapport final, après les 4 chantiers)

Rapport final : ce qui a été fait par chantier, mesures du chantier 4 (tokens, fiches par item au contrôle de fumée), ce qui est déployé et ce qui attend. Puis la liste de ses actions, dans l'ordre :
1. Installer la nouvelle build sur l'iPhone : `collega_app/tool/run_device.sh --release -d 00008110-000115D43499801E` (à faire de toute façon avant le 28/09).
2. Donner le feu vert au déploiement 2 + 4, avec le vidage des collèges.
3. Créer l'application Cloudflare Access `collega-admin` (chantier 2, spec § 7, étapes guidées).
4. Réimporter ses collèges (PNEUMO, CANCERO, HEMATO) depuis l'app et parcourir quelques fiches.
5. « OK merge » de `feat/refonte-back-infra` dans `main`.

Hors chantiers, à rappeler aussi :
- compte Apple Developer payant + clé APNs `.p8` (le code fait comme si elle existait ; à l'arrivée : écart de bundle ID et entitlements) ;
- ensuite : pouces pendant le drill, test hors LAN, reprise d'upload.

## Prompt à coller dans la nouvelle session

```
On implémente la refonte back/infra de Collega en autonomie totale. Lis
_bmad-output/planning-artifacts/refonte-back-infra-handoff.md et suis-le :
branche feat/refonte-back-infra, ordre 3 → 5 → 2 → 4 enchaînés sans
m'attendre, plan puis TDD, revue indépendante, déploiement selon la
politique du document, mémoire Kage à jour. Corrige tout problème
rencontré sans le reporter et choisis toujours la solution que tu
recommandes. Je reviens seulement quand les 4 chantiers sont finis : fais
alors le rapport final avec la liste de mes actions.
```

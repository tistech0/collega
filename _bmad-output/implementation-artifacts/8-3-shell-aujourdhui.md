# Story 8.3 : Shell 4 onglets + Aujourd'hui (et moteur de la session du jour)

Status: done

## Story

En tant qu'**étudiante qui révise le soir (Léa)**, je veux ouvrir Collega et trouver ma session du jour prête — combien de fiches, combien de temps, de quels collèges — et la lancer d'un tap,
afin de réviser sans rien décider.

## Constats de l'analyse (code, 2026-09-22)

| # | Constat | Conséquence |
|---|---|---|
| C1 | Les fiches n'arrivent dans Drift **qu'à l'ouverture d'un item** (`ItemDetailNotifier.build` → `syncCardsToDrift`, `colleges_detail_providers.dart:80-97`). La session lancée depuis l'accueil ne voit que les items déjà ouverts ; le hors-ligne est incomplet. | **Bug existant corrigé ici** : synchronisation de toutes les fiches d'un collège. Nouvel endpoint backend `GET /v1/colleges/{id}/cards` (seul `…/items/{item_id}/cards` existe). |
| C2 | La session est **mono-collège** (`HomeSessionConfig.collegeId`, `DrillSessionParams.collegeId`) ; `PlannedSession` n'a qu'un `collegeId` et pas de fiches. | Moteur de session du jour **mixte** (fonction pure) + session figée persistée. |
| C3 | Aucun journal de révisions (`flash_cards` n'a que `drillLevel`/`nextReviewAt`/`reviewCount`). | Table `review_log` : semaine (8.3), progression par rang (8.8), fin de session (8.5). |
| C4 | Session marquée faite par un bouton manuel, affiché même hors session du jour ; pas de reprise persistée ; le provider family du drill garde une session terminée en mémoire. | Auto-clôture et reprise : moteur ici, branchement du drill en 8.4. |
| C5 | Filtre « non vues » compté à l'accueil mais jamais transmis au drill (`DrillSessionParams` n'a pas le champ) → compteur ≠ contenu. | Disparaît : la session du jour est une liste d'ids figée. |
| C6 | Convention de durée incohérente : accueil `fiches/5` min, planning `minutes×5` fiches (150 fiches pour 30 min) ; la maquette dit « 24 fiches · 20 min ». | Une seule constante : **1 fiche ≈ 50 s** (`kSecondsPerCard`), utilisée partout. |
| C7 | `postponeSession` : id `'<cfg>-postponed-<day>'` inséré → collision si on décale deux fois la même journée. | Corrigé (upsert). |
| C8 | Tests pré-existants rouges : `home_notifier_test` (secure storage sans binding), `home_screen_test` (flux Drift en attente). | Les tests de l'écran réécrit remplacent ces fichiers ; plus de rouge dans `test/features/home`. |

## Critères d'acceptance

**Shell et navigation**
1. Tab bar `CgTabBar` 4 onglets **Aujourd'hui · Bibliothèque · Progression · Profil** (`/home`, `/colleges`, `/progress`, `/profile`) ; masquée dans le drill et l'import (routes hors shell) ; onglet actif re-tapé → remonte en haut ; haptique.
2. `/progress` est protégé comme les autres ; en attendant 8.8, il affiche `CgState.empty` « Ta première session remplira cette page ».
3. `/search` n'est plus un onglet : route poussée plein écran (sheet en 8.10), ouverte depuis l'action loupe d'Aujourd'hui ; les redirections (auth, paywall, R3 démo → accueil) restent valides ; tests du routeur mis à jour.

**Moteur de la session du jour**
4. `buildDailySession(cards, {collegeIds, budget, now})` (pur) : fiches `a_revoir` d'abord (plus ancienne révision prévue d'abord), puis fiches dues (`bien`/`maitrise` dont `nextReviewAt ≤ now`), puis `new` par rang A → B → C (collèges alternés dans un même rang), tronqué au budget. Collèges = ceux du planning, sinon tous les collèges importés et prêts.
5. Budget = minutes/jour du planning × 60 / `kSecondsPerCard` (50 s), sinon nombre par défaut des préférences, sinon 24.
6. La session du jour est **figée** à sa première construction (table Drift `daily_sessions` : jour, ids de fiches, position, `startedAt`, `completedAt`) ; « Personnaliser » la reconstruit (collèges, rangs, nombre, statut) tant qu'elle n'est pas commencée.
7. `review_log` (fiche, collège, rang, verdict, horodatage) ; API `recordVerdict` + `completeIfLast` prêtes pour le drill (8.4) : à la dernière fiche, `completedAt` est posé et la session planifiée du jour marquée faite.
8. Synchronisation de toutes les fiches des collèges prêts au chargement d'Aujourd'hui et au tirer-pour-rafraîchir, **sans écraser** l'état de révision local (`drillLevel`, `nextReviewAt`, `reviewCount`) ; migration Drift v7.

**Écran Aujourd'hui** (maquette `direction-d-fusion.html` écran 1)
9. `CgPage` : large title daté (« Lundi 21 »), sous-titre « septembre · jour 1 sur 30 du planning » (sans planning : « septembre ») ; action loupe (recherche).
10. Hero : grand nombre (`numeral`, 52 pt si largeur < 390) + « fiches · 20 min » ; répartition par collège (« Cancérologie · 16 · rang A », 3 lignes max puis « et 2 autres ») ; « dont à revoir 6 » ; `CgButton` primary **Commencer** (seul primaire) ; quiet **Personnaliser la session** (sheet).
11. Session commencée non finie : « 12 sur 24 » + **Reprendre** ; session faite : « Session faite » + récap (maîtrisées / à revoir) + « Prochaine session demain » — plus de bouton « Session terminée ✓ ».
12. « Cette semaine » : 7 pastilles L→D (faite = pleine `accent`, aujourd'hui = contour 2 pt, à venir = vide), Semantics « lundi, session faite ».
13. « Mes collèges » : `CgListRow` (icône, nom, « 177 fiches · 42 % maîtrisées », `CgRankBar` 6 pt) → détail collège.
14. **Quatre états** : vide « Importe ton premier collège » → Bibliothèque ; chargement `CgSkeleton` (hero + lignes) ; erreur `CgState.error` (« Tes fiches sont là… ») seulement si rien de local ; hors-ligne : tout s'affiche depuis Drift, pas de message bloquant. Import en cours sans collège prêt : état dédié « Ton premier collège est en préparation » (progression, pas d'action).
15. Aucun widget Material/shadcn, aucune valeur brute ; Dynamic Type 1,6 sans débordement (goldens 3×2 des états prêt / en cours / fait / vide / chargement).

## Tâches

- [x] T1 Backend : `GET /v1/colleges/{college_id}/cards` (toutes les fiches, même contrôle d'accès que `/items`), tests pytest, déploiement.
- [x] T2 Drift v7 : tables `daily_sessions`, `review_log` ; sync fiches par collège sans écraser l'état local ; tests.
- [x] T3 `buildDailySession` + budget (`kSecondsPerCard`) + tests purs.
- [x] T4 `DailySessionRepository` / provider : obtenir-ou-construire, personnaliser, `recordVerdict`, `completeIfLast`, reprise ; planning : marquage + correctif `postponeSession`.
- [x] T5 Shell `CgTabBar`, route `/progress`, `/search` hors onglets, redirections ; tests routeur.
- [x] T6 Écran Aujourd'hui + sheet Personnaliser (`CgSheet`, `CgSegmented`, `CgListRow` à coche) ; tests widget + goldens des états.
- [x] T7 Build iPhone `tool/run_device.sh --release -d 00008110-000115D43499801E` → validation visuelle utilisateur.

## Dev Notes

- Réutiliser : `collegesProvider`, `collegeDrillStatsProvider`/`DrillStats`, `planningProvider` (config : `collegeIds`, `dailyMinutes`, dates), `revisionPrefsProvider` (défauts rangs / nombre), `CollegeDetailRepository` (sync items), composants Collega UI (`lib/core/ui/components`).
- `DrillSessionParams` reçoit un mode « session du jour » (`dailySessionDay`) : le drill charge alors les ids figés (branchement complet en 8.4 ; en 8.3, « Commencer » lance déjà le drill existant sur ces fiches).
- Tests ciblés : `flutter test test/features/home test/features/today test/core/router test/core/database`, `pytest tests/api/test_college_cards.py`.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (1M context)

### Completion Notes List

- **Backend** (déployé, image `tistech0/collega-backend:story83`, sauvegarde `collega_pre_8-3_20260922_2115.dump`) : `GET /v1/colleges/{id}/cards` ; **bug existant corrigé** : `user_feedback` n'était jamais renvoyé → chaque synchronisation effaçait le pouce local. Vérifié en prod : 177 (CNEC) + 164 (CEP) fiches.
- **Drift v7** : `daily_sessions`, `review_log`, `user_colleges` (cache hors-ligne des collèges) ; `deleteEverything` les couvre (RGPD).
- **Moteur** : `buildDailySession` pur (à revoir → dues → nouvelles A→B→C, collèges alternés), convention unique 1 fiche ≈ 50 s (planning aligné : `cardsPerDay`), session figée dès qu'elle est commencée, recalculée avant (avec ses réglages Personnaliser), jamais figée vide.
- **Drill du jour** : `DrillSessionParams.daily(jour)` ; chaque verdict journalisé (jour de session), file + position enregistrées, clôture automatique à la dernière fiche (planning du jour marqué fait), reprise sans double réinsertion ; boutons « Session terminée ✓ » supprimés.
- **Shell** : `CgTabBar` 4 onglets, `/progress` (état vide jusqu'en 8.8), `/search` hors onglets, onglet re-tapé → haut / racine, écrans non migrés rognés au-dessus de la capsule.
- **Aujourd'hui** : maquette écran 1, états prêt / commencé (« 12 sur 24 · Reprendre ») / fait / rien à réviser / vide / en préparation / chargement / erreur (réseau ≠ autre) ; sheet Personnaliser avec aperçu vivant ; recalcul au changement de jour.
- **Revue adversariale — 3 bloquants + 7 importants + 7 mineurs corrigés** : barre « Lancer le drill » sous la tab bar (anciens écrans), session vide figée si la 1re synchro échoue, drill du jour sans persistance (et écran de fin périmé), liste vide du serveur qui aurait effacé toutes les fiches, import échoué « en préparation » à vie, compte suivant voyant les données du précédent (→ `LocalDataOwner` : base vidée seulement si un AUTRE compte se connecte — la progression est locale et doit survivre à une déconnexion), position de reprise = index de file, retour perdu (push), minuit/reprise d'app, `postponeSession` (collision d'id), aperçu Personnaliser (ordre, erreur, présélection), message d'erreur réseau vs autre.
- **Assumé** : un réimport régénère les fiches (nouveaux ids) → progression du collège repartie de zéro ; le décompte d'Aujourd'hui compte les fiches réellement présentes.
- Tests : 801 app (dossiers ciblés : core, today, drill, planning, profile, colleges, search, auth, shell, demo, generation, smoke) + 232 backend verts ; anciens tests de l'accueil (dont les rouges pré-existants home_notifier/home_screen) supprimés avec l'écran.

### File List

- Backend : app/api/v1/colleges.py ; tests/api/test_college_cards.py, tests/api/test_colleges.py
- App : lib/core/database/{app_database.dart,tables/daily_sessions_table.dart,tables/review_log_table.dart,tables/user_colleges_table.dart} ; lib/core/utils/{epoch_day,fr_dates}.dart ; lib/core/router/app_router.dart ; lib/features/today/** ; lib/features/shell/** ; lib/features/progress/progress_screen.dart ; lib/features/colleges/{colleges_providers.dart,data/college_cards_sync.dart,data/colleges_repository.dart} ; lib/features/drill/{drill_providers.dart,data/drill_repository.dart,domain/drill_session_state.dart,presentation/drill_screen.dart} ; lib/features/planning/{domain/planning_models.dart,data/planning_repository.dart} ; lib/features/auth/{auth_providers.dart,data/local_data_owner.dart} ; lib/features/profile/presentation/profile_screen.dart ; supprimés : lib/features/home/**, lib/shared/widgets/bottom_nav_bar.dart
- Tests : test/features/today/**, test/features/shell/**, test/features/drill/drill_daily_session_test.dart, test/features/auth/local_data_owner_test.dart, test/core/router/app_router_test.dart, test/core/utils_fr_dates_test.dart, planning, colleges_providers ; supprimés : test/features/home/**

---
epic: 8
title: Refonte UX/UI — Collega v2
date: 2026-09-22
branch: feat/redesign-ux-ui
inputDocuments:
  - '_bmad-output/planning-artifacts/ux-design-specification-v2.md'
  - '_bmad-output/planning-artifacts/ux-audit-2026-09-21.html'
  - '_bmad-output/planning-artifacts/directions-v2/direction-d-fusion.html'
---

# Epic 8 — Refonte UX/UI Collega v2

## Overview

L'app passe d'un rendu Material hétérogène à un système propre « Collega UI » :
palette pierre/sarcelle, Instrument Sans, quatorze composants maison sur
primitives Flutter + Cupertino, navigation à quatre onglets
(Aujourd'hui · Bibliothèque · Progression · Profil), drill plein écran à trois
gestes, et les quatre états (vide, chargement, erreur, hors-ligne) dessinés sur
chaque écran. Référence unique : `ux-design-specification-v2.md` ; référence
visuelle : `directions-v2/direction-d-fusion.html`.

**Séquencement** : story 8.0 (backend, titres d'items) → 8.1-8.2 (socle) →
un écran par story, du plus vu au moins vu → 8.15 (retrait de shadcn_ui).
Chaque story à partir de 8.3 est vérifiable sur l'iPhone
(`collega_app/tool/run_device.sh --release -d 00008110-000115D43499801E`).

**Tests** : dossiers ciblés uniquement (`flutter test test/core/ui`,
`flutter test test/features/<x>`), jamais la suite complète
(packet Kage `gotcha-flutter-test-complet-*`). Chaque composant a une entrée
Widgetbook et des golden tests en 3 largeurs (375 / 393 / 430) × 2 échelles de
texte (1,0 / 1,6).

**Périmètre exclu** : iPad, paysage, thème sombre, localisation.

---

## Story 8.0 — Tout item a un titre (backend + migration)

**Pourquoi d'abord** : la Bibliothèque, le Détail collège, la Recherche et la
Fin de session affichent des titres d'items. Aujourd'hui `chapter_title` est
vide pour les collèges importés (CNEC : « Item 310 » sans titre), parce que
`ItemDetector._extract_chapter` ne cherche que « chapitre X » / « partie X »
(`collega_backend/app/services/ocr/item_detector.py:33`), motif absent des
en-têtes de collèges qui écrivent « Item 310 – Tumeurs du testicule ».

En tant qu'**étudiant**, je veux voir le nom de chaque item plutôt qu'un numéro,
afin de choisir quoi réviser sans ouvrir la fiche.

**Critères d'acceptance**

- **Étant donné** une page d'en-tête « Item 310 – Tumeurs du testicule »,
  **quand** l'OCR détecte l'item, **alors** `chapter_title` vaut « Tumeurs du
  testicule » (tirets, deux-points, points et sauts de ligne acceptés comme
  séparateurs ; casse d'origine conservée ; 200 caractères max).
- **Étant donné** un en-tête sans titre exploitable, **quand** l'item est créé,
  **alors** le titre est repris du **référentiel officiel des items ECN**
  (table statique `item_number → titre`, 367 entrées, versionnée dans le repo).
- **Étant donné** ni en-tête ni entrée de référentiel, **quand** l'item est
  créé, **alors** l'item est enregistré avec `chapter_title = NULL` **et** un
  log `warning` nommant le collège et le numéro ; ce cas doit être nul sur les
  collèges de beta.
- **Étant donné** la base de production actuelle, **quand** la migration
  s'exécute, **alors** tout item existant dont `chapter_title` est vide ou nul
  reçoit son titre depuis le référentiel officiel, sans réimport ni appel
  Claude.
- **Étant donné** l'API `/v1/colleges/{id}` et la recherche, **quand** un item
  est renvoyé, **alors** `chapter_title` est présent pour tous les items des
  collèges de beta.
- **Étant donné** l'app, **quand** elle synchronise les items, **alors** le
  titre est stocké en local et affiché ; le repli « Item 310 » n'apparaît que
  si le titre est nul.

**Tasks**

- [ ] T1 — Élargir l'extraction de titre dans `item_detector.py` : capture du
      reste de la ligne d'en-tête après `_ITEM_HEADER_PATTERN`, nettoyage
      (séparateurs, numéro de page, majuscules parasites) ; conserver
      `_CHAPTER_PATTERN` en second recours.
- [ ] T2 — Ajouter `app/data/ecn_items.py` (ou JSON) : référentiel officiel
      `item_number → titre` + accesseur testé.
- [ ] T3 — Chaîner les sources dans `ocr_worker.py` : en-tête → référentiel →
      NULL + warning.
- [ ] T4 — Migration Alembic : backfill des items existants depuis le
      référentiel ; idempotente, sans data loss.
- [ ] T5 — Contrainte de non-régression : test qui échoue si un item est créé
      avec un titre vide alors que le référentiel en contient un.
- [ ] T6 — App : afficher le titre partout où l'item est listé ; repli explicite
      si nul.
- [ ] T7 — Tests backend ciblés (`pytest tests/services/test_item_detector.py`,
      test de migration) + vérification sur la prod (CNEC et CEP : 100 % des
      items titrés).

---

## Story 8.1 — Tokens, thème et fondation Collega UI

En tant que **développeur**, je veux une source unique de vérité visuelle,
afin qu'aucun écran ne redéfinisse une couleur, une taille ou une durée.

**Critères d'acceptance**

- `lib/core/ui/tokens/` expose couleurs, typographie (Instrument Sans via
  `google_fonts`), espaces, rayons, durées et courbes, aux valeurs figées dans
  la section « Direction de design » du spec.
- Un test de contraste automatique vérifie les couples du spec et échoue sous
  le seuil.
- `MaterialApp` est neutralisé (aucun style Material visible) ; les surfaces,
  le fond, la typographie viennent des tokens.
- Widgetbook est installé et démarre avec une page « Tokens » (palette, échelle
  typographique, espaces).
- `flutter_svg` est ajouté ; le wordmark Collega est rendu en SVG.
- Aucun écran existant n'est modifié par cette story (l'app continue de tourner
  avec shadcn_ui).

**Tasks** : T1 tokens · T2 thème/neutralisation Material · T3 test de contraste ·
T4 widgetbook + page Tokens · T5 flutter_svg + wordmark · T6 goldens de la page
Tokens.

---

## Story 8.2 — Les quatorze composants Collega UI

En tant que **développeur**, je veux les composants spécifiés, testés et
catalogués, afin que les écrans ne fassent qu'assembler.

**Critères d'acceptance**

- `CgButton`, `CgTabBar`, `CgHeader`, `CgListRow`/`CgListGroup`, `CgSegmented`,
  `CgSheet`, `CgDrillCard`, `CgVerdictBar`, `CgRing`, `CgRankBar`, `CgBadge`,
  `CgField`, `CgState`, `CgSkeleton`/`CgToast` existent avec les variantes et
  états décrits au spec (§ Stratégie de composants).
- Chaque composant a une entrée Widgetbook couvrant toutes ses variantes et
  états, et des golden tests en 3 largeurs × 2 échelles de texte.
- Les gestes de `CgDrillCard` (tap, swipe 3 directions, seuils, retour
  élastique, prévisualisation du verdict) sont couverts par des tests de widget.
- `MediaQuery.disableAnimations` et `textScaler` ≥ 1,6 sont respectés par tous
  les composants (vérifié en golden).
- Aucun composant n'importe `shadcn_ui` ni un widget Material visible.

**Tasks** : une tâche par composant + T15 goldens + T16 revue d'accessibilité
(labels, cibles 44 pt).

---

## Stories d'écran

Chaque story d'écran suit le même contrat :

1. L'écran est reconstruit avec les composants Collega UI, conforme à la
   maquette de référence et aux patterns du spec.
2. Ses **quatre états** sont implémentés (vide, chargement via `CgSkeleton`,
   erreur via `CgState.error`, hors-ligne via `CgState.offline`) avec les
   copies du spec — aucun `e.toString()` ne subsiste.
3. Un seul bouton primaire, vocabulaire du spec, haptique et mouvement aux
   durées du spec.
4. Tests : widget tests ciblés du dossier concerné + goldens des états.
5. Vérification sur l'iPhone avant de passer à la suivante.

| Story | Écran | Points spécifiques |
|---|---|---|
| **8.3** | Shell + Aujourd'hui | Tab bar 4 onglets (nouvelle structure de routes), large title daté, grand nombre, mix par collège, « Commencer », semaine, mes collèges, état vide « Importe ton premier collège », reprise de session en cours |
| **8.4** | Drill | Écran plein sarcelle, réponse qui glisse par le bas, 3 gestes + 3 boutons, réinsertion « à revoir » conservée (toast 2 s), mode définition, sheet « Quitter ? », **session marquée faite automatiquement** |
| **8.5** | Fin de session | Bloc sarcelle + score qui s'incrémente, stats à filets, « consolidé », prochaine session, un primaire ; suppression du bouton « Session terminée ✓ » (le planning avance seul) |
| **8.6** | Bibliothèque | Mes collèges en tête puis catalogue, lignes désactivées pour le non importé, action « Importer », champ de recherche qui ouvre la sheet, bandeau hors-ligne |
| **8.7** | Détail collège | En-tête avec `CgRankBar` + légende chiffrée (plus de « 0 % · 0 fiches »), segmented rangs, items **titrés**, « Réviser ce collège » ancré, réimport déplacé dans une action sheet explicite |
| **8.8** | Progression (nouvel onglet) | Valeur en large title, `CgRankBar` 22 pt + légende, semaine en barres, anneaux par collège, par rang, accès au planning |
| **8.9** | Planning | Collèges importés cochés par défaut, `CupertinoDatePicker`, durées en segmented, **aperçu vivant** (« 341 fiches · 30 jours · ~12/jour »), vue du planning après enregistrement, « Décaler aujourd'hui » |
| **8.10** | Recherche | Sheet plein écran, récentes + exemples, extrait = phrase entière avec terme surligné, titre d'item, un seul CTA par résultat, états vide / aucun résultat / hors-ligne |
| **8.11** | Détail item | Segmented rangs, fiches dépliables, badge OCR + popover, pouces de feedback avec état visible, **suppression déplacée dans une action sheet séparée du signalement**, suppression de l'icône bookmark inactive, « Réviser cet item » ancré |
| **8.12** | Entrée : marque, login, démo | Écran de marque (wordmark SVG animé), login avec autofill et erreurs inline, mention « Beta privée · accès sur invitation », **route `/auth/register` retirée** (réactivable par flag), démo en action secondaire |
| **8.13** | Import et import en cours | Écran d'import qui annonce PDF attendu / 500 Mo / durée / quota avant le choix de fichier ; import en cours avec étapes, compteur de fiches au fil de l'eau, reprise ; **fin d'import → détail du collège prêt** (plus de retour au catalogue) ; messages de quota au format du spec |
| **8.14** | Profil, paywall, CGU | Groupes insetGrouped, `CupertinoSwitch`, rangs par défaut lisibles, quota d'imports correct (barre vide à 0/3), « Se déconnecter » neutre et « Supprimer mon compte » destructif en action sheet ; paywall avec bénéfices ; CGU/Confidentialité aux styles du spec |
| **8.15** | Retrait de shadcn_ui | Suppression de la dépendance et de `app_theme.dart` v1, nettoyage des imports, passage VoiceOver sur les 5 écrans cœur, vérification finale des contrastes et des goldens |

---

## Risques et points d'attention

- **Routes** : la story 8.3 change la structure des onglets (`/progress`
  apparaît, `/search` devient une sheet). Les deep links et la redirection
  `/demo` → `/home` doivent rester valides (retour testeuse R3).
- **Drill** : le geste vertical « Bien » ne doit pas entrer en conflit avec le
  scroll de la feuille de réponse (direction verrouillée après 12 pt) ni avec
  le balayage retour iOS (le drill n'a pas de retour par balayage).
- **Session auto-clôturée** (8.4/8.5) : le marquage du planning passe du bouton
  au moteur de session ; vérifier qu'une session quittée en cours ne marque
  rien et que « Reprendre » fonctionne.
- **Migration 8.0** : exécutée sur la prod NAS (voir packet Kage
  `runbook-d-ployer-le-backend-*`), idempotente, testée d'abord en local.
- **Suite de tests** : `flutter test` complet n'est pas vert avant cette epic
  (home_notifier, blocage après profile_screen_test) ; ne pas confondre ces
  échecs pré-existants avec des régressions de la refonte.

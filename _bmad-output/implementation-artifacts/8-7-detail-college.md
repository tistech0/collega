# Story 8.7 : Détail collège (maquette 6) — livrée avec la 8.6

Status: review

## Story

En tant qu'**étudiante**, je veux voir où j'en suis dans un collège et lancer sa révision d'un geste,
afin de travailler un collège précis sans passer par la session du jour.

## Critères d'acceptance (maquette `direction-d-fusion.html` écran 6, spec v2 § Détail collège)

1. `CollegeDetailScreen` entièrement Collega UI : `CgPage` avec « ‹ Bibliothèque » (ou « ‹ Aujourd'hui » quand on vient d'Aujourd'hui : route `/home/colleges/:id`, onglet Aujourd'hui actif), titre = nom du collège, sous-titre « CNEC · 177 fiches · 32 items ».
2. En-tête : `CgRankBar` 10 pt + légende chiffrée (maîtrisées / bien / à revoir / non vues) calculée sur les fiches du collège — jamais « 0 % · 0 fiches ».
3. `CgSegmented` Tous / Rang A / Rang B / Rang C filtre les items et l'en-tête.
4. Items **titrés** (`itemDisplayTitle`), badge de rang, « Item 310 · 6 fiches », `CgRankBar` par item (vivante), chevron → détail d'item ; OCR douteux signalé dans le sous-titre (« · OCR à vérifier »).
5. Un seul primaire ancré : « Réviser ce collège · N fiches » (N = min(24, fiches du filtre présentes sur l'iPhone, que le drill lira) ; fiches pas encore téléchargées → « Fiches en cours de téléchargement » inactif ; filtré : « Réviser le rang B · N fiches » ; lance `launchDrill` (fiches à revoir d'abord).
6. Réimport déplacé dans une action sheet explicite (bouton « … » en tête) : « Réimporter le PDF » → limites → `showCgDialogSheet` avec la conséquence écrite (« Les nouvelles fiches remplaceront les fiches existantes. ») ; limites atteintes → sheet d'information ; erreur → toast.
7. États : chargement skeleton ; import en cours → « Les fiches arrivent » ; import échoué → `CgState.error` + « Relancer l'import » ; aucun item → état vide + « Réimporter » ; hors-ligne sans cache → `CgState.offline` ; filtre vide → « Aucun item de rang C dans ce collège ».
8. Accessibilité : légende lue, badges de rang, cibles 44 pt, Dynamic Type 1,6 sans débordement.
9. Goldens 3×2 : chargé, filtré rang B.

## Tâches

- [x] T1 `CollegeDetailScreen` Collega UI (en-tête, segmented, items, primaire ancré)
- [x] T2 Réimport en action sheet + sheets de limites
- [x] T3 États (en cours, échoué, vide, hors-ligne, filtre vide)
- [x] T4 Tests + goldens, revue adversariale, build iPhone (validation 8.6 + 8.7 ensemble)

## Dev Agent Record

### Completion Notes List

- Détail collège Collega UI : en-tête (retour, titre, « CNEC · 30 fiches · 6 items »), barre 10 pt + légende chiffrée, segmented Tous / Rang A-C, items titrés triés par numéro (badge rang, « Item 310 · 6 fiches », « OCR à vérifier », barre par item), primaire ancré « Réviser ce collège · N fiches » / « Réviser le rang B · N fiches », réimport dans l'action sheet « … » (limites → sheets explicatives, conséquence écrite avant confirmation, toast si injoignable), états (squelette avec titre, en cours, échoué + « Relancer l'import », vide + « Réimporter », hors-ligne, erreur).
- Le détail synchronise items **et fiches** du collège dans Drift avant l'affichage ; hors-ligne sans cache → état hors-ligne (plus « aucune fiche »).
- **Revue adversariale — corrigé** : N du bouton compté sur les fiches Drift (le drill lit Drift) ; après un import ou un réimport (même `college_id`), les nouvelles fiches sont téléchargées et le détail ouvert se recharge (`collegeDataVersionProvider`, pas d'`invalidate` qui construirait en debug un provider jamais lu) ; suppression d'une fiche → même mécanisme ; filtre de rang = état de l'écran (survit au rechargement) ; lien direct vers un collège non importé → l'import garde la Bibliothèque en dessous ; spinner du tirer-pour-rafraîchir tenu jusqu'aux items ; illustration « feuillets » pour l'import en cours ; ouvert depuis Aujourd'hui → `/home/colleges/:id` (onglet et retour cohérents).
- Tests : 35 → 41 tests du détail, notifier (synchro fiches, hors-ligne sans cache), import (fiches rechargées à la fin) ; goldens chargé / rang B 3×2.

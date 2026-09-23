# Story 8.8 : Progression (maquette 4) — livrée avec la 8.9

Status: done

> Regroupée avec la 8.9 (Planning) à la demande de l'utilisateur (2026-09-23).

## Story

En tant qu'**étudiante**, je veux voir en un écran où j'en suis — tout, cette semaine, par collège, par rang, mon planning —
afin d'éprouver une fierté calme sans rien chercher.

## Critères d'acceptance (maquette `direction-d-fusion.html` écran 4, spec v2 § Progression)

1. `ProgressScreen` Collega UI, onglet 3 : large title = valeur (« 31 % »), sous-titre « de tes 341 fiches sont maîtrisées » ; rien révisé → « 341 fiches à découvrir » / « Ta première session remplira cette page » (jamais « 0 % »).
2. `CgRankBar` 22 pt + légende chiffrée (maîtrisées / bien / à revoir / non vues), totaux = fiches de tous les collèges prêts (non vues recalées sur le total serveur).
3. « Cette semaine · N fiches » : 7 barres lundi → dimanche = fiches distinctes révisées ce jour-là (**toutes** les révisions : session du jour, collège, item, recherche, refaire les erreurs), initiales L M M J V S D, aujourd'hui repéré ; VoiceOver : « lundi, 24 fiches ».
4. « Par collège » : `CgRing` s (part maîtrisée), nom, « 177 fiches · 74 maîtrisées » (neuf : « 164 fiches à découvrir »), `CgRankBar` ; tap → détail collège sous `/progress/colleges/:id` (onglet Progression gardé, « ‹ Progression »).
5. « Par rang » : badge A/B/C, `CgRankBar`, « 48 % » ; rangs sans fiche absents.
6. « Planning » : ligne « 21 sept. → 21 oct. » · « 30 min par jour · jour 1 sur 30 » (décalé : « aujourd'hui décalé ») → écran Planning ; sans planning : « Planifier tes révisions ».
7. Données vivantes (Drift) et hors-ligne ; états : squelette (anneaux), vide (aucun collège prêt) « Ta première session remplira cette page » + « Aller à la Bibliothèque », erreur / hors-ligne sans cache.
8. Re-tap de l'onglet → haut ; animations des anneaux une fois ; Dynamic Type 1,6 ; goldens 3×2 (avec données, rien révisé, vide).

## Tâches

- [x] T1 Journal : toutes les révisions (`review_log.daily`, schéma v8), `weekCounts`
- [x] T2 `progressProvider` (vivant)
- [x] T3 `ProgressScreen` + routes `/progress/colleges/...` + tests + goldens

## Dev Agent Record

### Completion Notes List

- Journal : toute révision est journalisée (`review_log.daily`, schéma v8 ; le bilan du jour et la reprise ne lisent que `daily`), `weekCounts` compte les fiches distinctes par jour.
- `progressProvider` (StreamProvider autoDispose) : totaux (non vues recalées sur le serveur), collèges, rangs, semaine, planning ; abonné aux tables avant le premier calcul, mises à jour regroupées (150 ms), actif seulement onglet affiché.
- `ProgressScreen` : valeur en large title (« 341 fiches à découvrir » avant tout drill, jamais « 0 % »), barre 22 pt + légende, semaine en barres (VoiceOver par jour), anneaux par collège → `/progress/colleges/:id` (`CollegeDetailOrigin.progress`), rangs (valeur au-dessus d'une barre de même longueur), ligne Planning ; états ; retour au premier plan après minuit → recalcul.
- Squelettes : la pulsation en double (enveloppe `CgSkeletonPulse` autour de formes qui pulsent déjà) retirée sur Aujourd'hui, Bibliothèque, détail collège, Progression.
- Tests : progress 40, today/drill/planning/colleges/shell/core verts ; goldens prêt / rien révisé / vide 3×2.

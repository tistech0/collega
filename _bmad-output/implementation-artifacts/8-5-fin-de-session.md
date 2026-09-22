# Story 8.5 : Fin de session (pic de la Peak-end rule)

Status: ready-for-dev

## Story

En tant qu'**étudiante**, à la dernière fiche je veux voir d'un coup d'œil ce que j'ai gagné et quand je reviens,
afin de finir sur une satisfaction nette et brève, sans rien avoir à déclarer.

## Critères d'acceptance (maquette `direction-d-fusion.html` écran 3 — haut Bloc, bas Feuille)

1. Plein écran, sans tab bar ; haut en **bloc sarcelle** (`accent`, bas arrondi `r-l`) : « Session terminée · 19 min », score en `score` (96) qui **s'incrémente** de 0 à *maîtrisées* en `CgMotion.ringFill` puis « /24 » atténué, « maîtrisées » ; barre blanche segmentée (maîtrisées blanc, bien blanc 50 %, à revoir `review`).
2. Bas Feuille : 3 stats à filet coloré (maîtrisées / bien / à revoir, chiffres tabulaires) ; « Ce que tu as consolidé » : titres des items dont au moins une fiche est maîtrisée (3 max, puis « et N autres ») ; « Prochaine session » : session du jour → « Demain · N fiches » (+ « à revoir en priorité » s'il en reste) ; autres drills → pas de section.
3. Un seul primaire **Terminer** (retour à l'écran d'origine, fondu) ; secondaire quiet **Refaire les N à revoir** si N > 0 (repasse les fiches « à revoir » de la session) ; drill lancé depuis la recherche : quiet **Retour à la recherche**.
4. Aucune déclaration : la session du jour est déjà close (8.3/8.4) ; plus aucun bouton « Session terminée ✓ ».
5. Haptique `success` à l'apparition ; mouvement réduit → valeurs finales directes (pas de comptage, pas d'extension de barre).
6. Durée : depuis l'ouverture du drill (ou `startedAt` de la session du jour).
7. Accessibilité : score lu « 18 fiches maîtrisées sur 24 », boutons standard ; Dynamic Type 1,6 sans débordement (le score plafonné à 1,3×).
8. Goldens 3×2 : session du jour (avec à revoir), drill d'item sans à revoir.

## Tâches

- [ ] T1 `DrillSessionSummary` enrichi : durée, items consolidés (titres depuis Drift), prochaine session.
- [ ] T2 `DrillEndScreen` Collega UI (remplace l'ancien écran shadcn) + tests + goldens.
- [ ] T3 Revue adversariale, build iPhone (validation 8.4 + 8.5 ensemble : le drill et sa fin forment un seul parcours).

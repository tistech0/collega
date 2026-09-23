# Story 8.4 : Drill plein écran (maquette 2a)

Status: done

## Story

En tant qu'**étudiante**, je veux réviser mes fiches en plein écran d'un geste — toucher pour voir la réponse, glisser pour juger —
afin que la session devienne un réflexe, sans chercher de bouton ni perdre la question.

## Critères d'acceptance

1. `DrillScreen` est entièrement Collega UI : `CgDrillCard` (fond sarcelle, réponse qui glisse par le bas, 3 gestes + `CgVerdictBar`), aucun widget Material/shadcn, aucune valeur brute.
2. En-tête : ✕ · « 3 / 24 » + contexte (« Session du jour », nom d'item, « Cancérologie », « Recherche ») · emplacement chronomètre. Barre de progression = position dans la file (réinsertions comprises), avance à la sortie de la carte.
3. Badge rang + nom du collège de la fiche (session mixte : le collège change sans surprise).
4. Verdict (geste ou bouton) → `evaluate` puis fiche suivante ; 1er « à revoir » → réinsertion 3 plus loin + toast 2 s « Elle reviendra dans quelques questions » (au ras du bas : pas de tab bar).
5. Quitter (✕ ou balayage depuis le bord gauche) → `CgSheet.dialog` « Quitter ? » avec la conséquence écrite (« 12 fiches jugées sont enregistrées. » ; session du jour : « Ta session reprendra là où tu l'as laissée. ») ; « Continuer » reste ; « Quitter » sort. Aucun retour par balayage natif.
6. Mode définition (`cardType == definition`) : champ `CgField` multiligne dans le recto + « Valider » ; la réponse ne s'ouvre qu'après validation (ou expiration du chrono) ; le retour sémantique (Correct / Partiel / À revoir + texte) s'affiche en tête de la feuille réponse. Erreur réseau → la réponse s'ouvre quand même.
7. **Chronomètre (demande utilisateur 2026-09-22)** : réglage Profil à 3 choix *Désactivé / Activé / Demander* (migration de l'ancien booléen) ; mode *Demander* → sheet au lancement (« Avec chrono · 30 s » / « Sans chrono », fermeture = annuler le lancement) ; pendant le drill, l'emplacement d'en-tête **active/désactive** le chrono (tap) et le **met en pause** (appui long) ; à l'expiration, la réponse s'ouvre et un toast « Temps écoulé » s'affiche.
8. Chargement : écran sarcelle + skeleton de carte ; erreur : `CgState.error` (« Tes fiches sont là… », Réessayer / Quitter) ; session vide : écran de fin.
9. Le lancement repart toujours de l'état en base (plus d'écran de fin périmé en mémoire) — `launchDrill` utilisé par Aujourd'hui, le détail d'item et la recherche.
10. Accessibilité : carte lue « Fiche rang A, Cancérologie. Question : … », 3 verdicts boutons, chrono libellé (« Chronomètre activé, 18 secondes » / « Activer le chronomètre »), cibles 44 pt, mouvement réduit respecté, Dynamic Type 1,6.
11. Goldens 3×2 : recto, verso, définition avec retour, chrono actif.

## Hors story

L'écran de fin est redessiné en 8.5 (il reste l'ancien d'ici là, sans le bouton « Session terminée ✓ » supprimé en 8.3).

## Tâches

- [x] T1 Préférence chronomètre 3 choix (modèle, stockage, migration, Profil)
- [x] T2 `launchDrill` (sheet « Demander », invalidation de l'état, route `/drill` avec `DrillLaunch`)
- [x] T3 `CgDrillCard.trailing` (emplacement d'en-tête) + `DrillTimerSlot` (anneau, tap, appui long)
- [x] T4 `DrillScreen` réécrit (carte, verdicts, toast, quitter, définition, chrono, états)
- [ ] T5 Tests + goldens, revue adversariale, build iPhone

## Dev Agent Record

### Completion Notes List

- Drill Collega UI (maquette 2a) : `CgDrillCard` + verdicts + toast de réinsertion + « Quitter ? » (conséquence écrite, PopScope) + mode définition (champ dans le recto, retour sémantique en tête de réponse) ; « Réviser cet item » remplace « Lancer le drill » (vocabulaire du spec).
- **Chronomètre (demande utilisateur)** : réglage 3 choix Désactivé / Activé / Demander (migration de l'ancien booléen) ; sheet au lancement en mode Demander (fermer = annuler) ; emplacement d'en-tête : tap = activer/couper, appui long = pause ; expiration → réponse ouverte + « Temps écoulé ».
- `launchDrill` : point d'entrée unique (Aujourd'hui, détail d'item, recherche), repart toujours de l'état en base, verrou anti double tap.
- **Revue adversariale — 7 correctifs** : clavier qui cachait le champ et « Valider » (le recto remonte au-dessus du clavier), retour sémantique tardif appliqué à la fiche suivante (et l'ouvrant), double tap = deux drills, `timerExpired` jamais posé, chrono qui tournait pendant « Quitter ? », glissé du recto qui pouvait juger la réponse ouverte sous le doigt, « refaire les à revoir » qui écrasait la file du jour enregistrée.
- Piège Dart noté : une fonction `async` qui renvoie un Future l'attend (le verrou restait posé pendant tout le drill) → résultat enveloppé dans un record.
- Tests : 289 verts (drill, today, search, colleges) + 59 `cg_drill_card` ; goldens recto / verso / définition / chrono 3×2.
- Validation iPhone groupée avec la 8.5 (le drill et sa fin forment un seul parcours).

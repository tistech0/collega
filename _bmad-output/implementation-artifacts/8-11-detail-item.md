# Story 8.11 : Détail item — livrée avec la 8.10

Status: done

## Story

En tant qu'**étudiante**, je veux relire les fiches d'un item, signaler une fiche douteuse sans risquer de la supprimer par erreur,
et réviser l'item d'un geste.

## Critères d'acceptance (spec v2 § Détail item, audit « Détail item »)

1. `ItemDetailScreen` Collega UI (plus de Scaffold, TabBar, strip, accordéon shadcn, **icône marque-page inactive retirée**) ; retour « ‹ Cancérologie » (ou « ‹ Recherche », qui rouvre la recherche) ; onglet d'origine gardé (`/colleges`, `/home/colleges`, `/progress/colleges`).
2. En-tête : titre de l'item, « Item 310 · Cancérologie · 6 fiches », `CgRankBar` 10 pt + légende (vivante).
3. Rangs : `CgSegmented` Toutes / Rang A… seulement si l'item a des fiches de plusieurs rangs ; sinon badge du rang.
4. Fiches dépliables (question → réponse), VoiceOver « déplié / replié » ; badge OCR « À vérifier » tapable → explication en sheet.
5. Pouces **avec état visible** (libellé « Utile » / « À corriger », sélection lue par VoiceOver, pas la couleur seule). Pouce bas = **signaler** : feedback enregistré, sheet « Signaler cette fiche » (note facultative) → « Régénérer la fiche » ou « Plus tard » (toast « Fiche signalée »).
6. **Suppression séparée** : « … » de la fiche → action sheet (« Régénérer la fiche », « Supprimer la fiche » destructif) → confirmation écrite. Jamais Supprimer à côté de Régénérer dans un même dialogue.
7. Primaire ancré « Réviser cet item · N fiches ».
8. États : squelette ; hors-ligne sans cache `CgState.offline` (plus « aucune fiche ») ; erreur ; aucune fiche. Dynamic Type 1,6, 44 pt. Goldens 3×2 : replié, fiche dépliée signalée.
9. Le shell ne traite plus le détail d'item en écran legacy (seul Profil le reste jusqu'en 8.14).

## Tâches

- [x] T1 `ItemDetailNotifier` : hors-ligne sans cache → erreur réseau
- [x] T2 `ItemDetailScreen` Collega UI (en-tête, rangs, fiches dépliables, pouces, OCR, actions)
- [x] T3 Routes / shell / retour recherche + tests + goldens, revue adversariale, build iPhone (validation 8.10 + 8.11)

## Dev Agent Record

### Completion Notes List

- `ItemDetailScreen` Collega UI : en-tête (titre lu dans Drift via `itemInfoProvider`, sans recharger le collège), barre + légende vivantes, badge ou segmented des rangs présents, fiches dépliables (VoiceOver déplié/replié), pouces à état lisible, pouce bas = signaler (+ régénérer avec note), « … » → régénérer / supprimer (confirmation écrite), badge OCR expliqué, « Réviser cet item » ancré ; états (squelette, hors-ligne, erreur, aucune fiche, réimport en cours « Les fiches arrivent ») ; marque-page, strip et accordéon retirés ; `FlashCardWidget` / `OcrConfidenceBadge` supprimés (plus utilisés).
- Shell : seul Profil reste en écran legacy.
- **Revue adversariale — corrigé** : retour par balayage iOS depuis la recherche rouvre aussi la sheet (`PopScope`) ; filtre sur un rang disparu → « Toutes » (plus d'assertion) ; signalement : plus d'« enregistré » affirmé, échec dit par toast ; note des sheets sans contrôleur libéré pendant l'animation ; collège en réimport ≠ « introuvable ».
- Tests : search 50, item detail 32, drill 143, suite par dossiers 1 097 verts ; goldens recherche (accueil, résultats) et item (replié, déplié) 3×2.

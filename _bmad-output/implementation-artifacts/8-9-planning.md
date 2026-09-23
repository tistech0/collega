# Story 8.9 : Planning — livrée avec la 8.8

Status: done

## Story

En tant qu'**étudiante**, je veux planifier mes révisions jusqu'à mon examen en voyant tout de suite si c'est faisable,
puis retrouver mon planning, afin de ne plus rien configurer à l'aveugle.

## Critères d'acceptance (spec v2 § Parcours 5, audit « Planning »)

1. Route `/progress/planning` (poussée depuis Progression, onglet Progression gardé) ; `/planning/config` redirige. Entièrement Collega UI (Cupertino pour la date), aucun Material.
2. Sans planning (ou « Planifier à nouveau ») → formulaire :
   - « Collèges » : lignes inset avec coche, **collèges prêts tous cochés par défaut** (planning existant : ses collèges) ;
   - « Période » : « Début » et « Examen » → sheet `CupertinoDatePicker` en français ; l'examen reste après le début ;
   - « Temps par jour » : `CgSegmented` 15 / 30 / 45 / 60 min ;
   - **aperçu vivant** recalculé à chaque changement : « 341 fiches · 30 jours · ~12 par jour » + « Faisable en 30 min par jour » ou « Trop court : 34 fiches par jour, ~29 min. Allonge la période ou le temps par jour. » ;
   - un seul primaire ancré « Planifier » (inactif sans collège) → enregistre, haptique succès, affiche la vue du planning.
3. Avec planning → vue : période, « 30 min par jour · jour 3 sur 30 », collèges, **calendrier de la période** (jours faits pleins, aujourd'hui cerclé, décalé barré, à venir en creux ; VoiceOver par jour) ; actions quiet « Décaler aujourd'hui » (ou « Annuler le décalage ») et « Planifier à nouveau » (formulaire prérempli + « Annuler » pour revenir à la vue) ; « … » → « Supprimer le planning » (destructif, confirmation écrite).
4. « Décaler aujourd'hui » sans pénalité : le planning est prolongé d'un jour ; Aujourd'hui dit « Session décalée à demain » et propose « Réviser quand même » ; impossible si la session du jour est commencée ou faite, ou hors période.
5. Le planning ne génère plus de sessions par jour (moteur de la session du jour depuis 8.3) : `PlanningGenerator` retiré.
6. États : aucun collège prêt → `CgState.empty` « Importe un collège pour planifier » ; Dynamic Type 1,6 ; goldens 3×2 (formulaire, vue).

## Tâches

- [x] T1 `PlanningNotifier` : plan / postponeToday / cancelPostpone / clear ; repo ; retrait du générateur
- [x] T2 Aujourd'hui : session décalée
- [x] T3 `PlanningScreen` (formulaire + aperçu + vue + calendrier) + localisation fr (sélecteur de date)
- [x] T4 Tests + goldens, revue adversariale, build iPhone (validation 8.8 + 8.9 ensemble)

## Dev Agent Record

### Completion Notes List

- Planning = période + collèges + temps par jour + jours décalés (`planning_sessions` status `postponed`) ; `PlanningGenerator` et l'ancien écran supprimés ; `/planning/config` redirige vers `/progress/planning`.
- `PlanningScreen` Collega UI : formulaire (collèges prêts cochés, dates en sheet `CupertinoDatePicker` en français, 15/30/45/60 min, aperçu vivant faisable / trop court), « Planifier » → vue (période, résumé, collèges, calendrier mois par mois, décaler / annuler, planifier à nouveau, supprimer en action sheet).
- Aujourd'hui : « Session décalée à demain » + « Réviser quand même ».
- App en français (`flutter_localizations`, `CFBundleLocalizations` fr).
- **Revue adversariale — tous les points corrigés** : dates en jours civils (± 24 h dérapait au changement d'heure : décalage sans effet le 25 oct., annulation qui retirait 2 jours, examen par défaut à J+29) ; jour relu à l'horloge dans décaler/annuler + rechargement au retour au premier plan après minuit ; décaler/annuler en une transaction ; erreurs signalées par toast ; décalage refusé si session commencée/faite ou hors période (vérifié dans le notifier, bouton masqué tant que les jours ne sont pas lus) ; sélecteur borné au maximum ; état hors-ligne ; année dans les mois quand la période change d'année ; « Annuler » en re-planification ; horloge unique pour Progression ; garde de migration v1 (`drillLevel`).
- Tests : planning 45 (dont changements d'heure 25 oct. et 28 mars), goldens formulaire / vue 3×2.

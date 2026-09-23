# Story 8.10 : Recherche (sheet plein écran) — livrée avec la 8.11

Status: done

> Regroupée avec la 8.11 (Détail item) à la demande de l'utilisateur (2026-09-23).

## Story

En tant qu'**étudiante en stage**, je veux chercher un item, un signe ou une dose d'une main et juger d'un coup d'œil chaque résultat,
afin d'arriver sur la bonne fiche et de la réviser en trois taps.

## Critères d'acceptance (spec v2 § Parcours 2, § Recherche et filtres, audit « Recherche »)

1. Recherche = `CgSheet` plein écran ouverte depuis Aujourd'hui (loupe) et la Bibliothèque (champ) ; clavier ouvert à l'arrivée ; « Annuler » ferme ; la sheet garde la dernière recherche. `/search` redirige vers Aujourd'hui. Aucun Material/shadcn.
2. Avant de chercher : « Récentes » (5 dernières, stockées sur l'iPhone, « Effacer ») puis « Cherche un item, un signe, une dose » + 3 exemples tapables (BNP, Gardasil, dyspnée).
3. Résultats dès 2 caractères, 300 ms de délai ; « N résultats » en tête ; une ligne par item : badge de rang, **titre d'item**, « Item 290 · Cancérologie », **extrait = la phrase entière** avec le terme surligné (`accent-soft`) — correctif serveur `build_excerpt`, déployé.
4. Un seul CTA par résultat : la ligne ouvre le détail d'item (« ‹ Recherche » y ramène) ; « Réviser » en action secondaire lance le drill de l'item (fin : « Retour à la recherche » rouvre la sheet).
5. États : chargement squelette ; aucun résultat « Aucun résultat pour « xyz » » ; hors-ligne `CgState.offline` « La recherche a besoin d'une connexion » + « Tes collèges restent disponibles » + Bibliothèque ; erreur `CgState.error` + Réessayer. Jamais de toast seul.
6. Accessibilité : champ lu « Rechercher », résultat = bouton avec action « Réviser », 44 pt, Dynamic Type 1,6. Goldens 3×2 : accueil (récentes + exemples), résultats.

## Tâches

- [x] T1 Backend : extrait = phrase entière (`build_excerpt`), tests, déployé (image b064cda)
- [x] T2 `SearchNotifier` (2 caractères, 300 ms, hors-ligne vs erreur, relancer) + récentes
- [x] T3 `showSearchSheet` + entrées Aujourd'hui / Bibliothèque + tests + goldens

## Dev Agent Record

### Completion Notes List

- Serveur : `build_excerpt` rend la phrase entière (réponse d'abord, abréviations et « ; » ne coupent pas) — images `b064cda` puis `b948dc4` déployées, vérifié en prod (« alcool », « BNP »).
- App : `showSearchSheet(context, origin:)` (sheet plein écran, clavier ouvert, « Annuler », dernière recherche gardée), accueil récentes + exemples, résultats (titre, item · collège, extrait surligné `accentSoft` fenêtré autour du terme), ligne = ouvrir l'item sous l'onglet d'origine, « Réviser » en action ; états squelette / aucun résultat / hors-ligne / erreur ; ancien écran et tuile supprimés, `/search` redirigé.
- **Revue adversariale — tous les points corrigés** : « Terminer » en fin de drill lancé depuis la recherche fermait l'écran mais laissait la sheet ouverte (route sans page accrochée au shell) → drill puis routes sans page dépilés avant `go('/home')` ; « Aucun résultat » affiché pendant le délai de 300 ms (`isPending`) ; onglet d'origine gardé ; recherches d'un autre compte (déconnexion : état oublié ; autre compte : trousseau effacé) ; terme caché par la coupe à 3 lignes (fenêtre client) ; « Rechercher » au clavier immédiat ; VoiceOver « Rechercher » ; récentes sérialisées et tolérantes à un trousseau en échec.

# Story 8.6 : Bibliothèque (maquette 5) — livrée avec la 8.7

Status: review

> Regroupée avec la 8.7 (Détail collège) à la demande de l'utilisateur (2026-09-23) :
> un seul parcours, une seule validation iPhone.

## Story

En tant qu'**étudiante**, je veux voir d'abord mes collèges avec leur progression, puis le catalogue où importer,
afin de trouver en un regard ce que je révise et ce que je peux ajouter.

## Critères d'acceptance (maquette `direction-d-fusion.html` écran 5, spec v2 § Bibliothèque)

1. `CollegesScreen` entièrement Collega UI : `CgPage` large title « Bibliothèque », tab bar réservée, tirer pour rafraîchir, re-tap de l'onglet = retour en haut. Aucun widget Material / shadcn, aucune valeur brute.
2. Champ de recherche (aspect `CgField.search`, « Un item, un signe, une dose… ») qui ouvre la recherche (route `/search`, sheet en 8.10) ; lu « Rechercher » par VoiceOver.
3. Section « Mes collèges » : collèges importés, ordre alphabétique ; icône du collège (SVG Collega UI, plus d'icônes Material), sous-titre « CNEC · 177 fiches · 42 % maîtrisées » (ou « · à découvrir »), `CgRankBar` vivante (Drift) ; tap → détail. Import en cours : « CEN · import en cours, les fiches arrivent » ; import échoué : « CEDEF · l'import n'a pas abouti » (l'éditeur reste en tête, comme les autres lignes). Sans collège : « Choisis un collège dans le catalogue ».
4. Section « Catalogue · N collèges » : lignes désactivées (titre `ink2`, icône grisée), éditeur en sous-titre, action `quiet` « Importer » → écran d'import ; VoiceOver : « Importer » est l'action de la ligne.
5. États : chargement `CgSkeletonList` ; réseau injoignable sans cache → `CgState.offline` + Réessayer (squelette pendant la nouvelle tentative) ; erreur serveur ou autre → `CgState.error` ; liste servie par le cache faute de réseau → bandeau 32 pt `soft` « Hors connexion » sous le champ, nouvelle tentative au retour au premier plan.
6. La reprise d'un upload interrompu (story 7.11) est conservée (montage + retour au premier plan).
7. Aujourd'hui « Mes collèges » utilise les mêmes icônes de collège.
8. Goldens 3×2 : avec collèges (dont un en import), sans collège, hors-ligne.

## Tâches

- [x] T1 Icônes SVG des 39 collèges (`college_icons.dart`), catalogue en `String` SVG (plus de `IconData`)
- [x] T2 `CollegesNotifier.isOffline` (liste servie par le cache)
- [x] T3 `CollegesScreen` Collega UI + tests + goldens
- [x] T4 Nettoyage : `CollegeProgressTile`, `ItemProgressBar` et leurs tests supprimés

## Dev Agent Record

### Completion Notes List

- Bibliothèque Collega UI : faux champ de recherche (bouton « Rechercher… »), « Mes collèges » (icône, sous-titre éditeur · fiches · maîtrise, barre vivante, import en cours / échoué dits), « Catalogue · N collèges » (lignes désactivées + « Importer »), états (squelette, hors-ligne, erreur, bandeau « Hors connexion »), reprise d'upload 7.11 conservée, re-tap de l'onglet (mixin `TabReselectScrollMixin`).
- 39 icônes SVG de collège (`CollegeIcons`), catalogue sans `IconData` Material ; Aujourd'hui les réutilise.
- `CollegeProgressTile` et `ItemProgressBar` supprimés.
- **Revue adversariale (8.6 + 8.7) — tous les points corrigés** : tab bar réservée deux fois (le shell traitait encore la Bibliothèque en écran legacy) ; « Hors connexion » seulement quand le réseau manque (`isNetworkUnreachable`), pas sur un 500 ; bandeau retenté au retour au premier plan ; squelette pendant « Réessayer ».
- Tests : colleges 147, shell/today/core/drill/search 879 cumulés verts ; goldens bibliothèque (mes collèges, vide, hors-ligne) 3×2.

# Story 8.2 : Les quatorze composants Collega UI

Status: in-progress

## Story

En tant que **développeur**, je veux les composants spécifiés, testés et catalogués,
afin que les écrans (8.3 → 8.14) ne fassent qu'assembler.

## Critères d'acceptance

1. `CgButton`, `CgTabBar`, `CgHeader` (+ `CgPage`), `CgListRow`/`CgListGroup`, `CgSegmented`, `CgSheet`, `CgDrillCard`, `CgVerdictBar`, `CgRing`, `CgRankBar`, `CgBadge`, `CgField`, `CgState`, `CgSkeleton`/`CgToast` existent avec les variantes et états du spec v2 (§ Stratégie de composants) — contrats ci-dessous.
2. Chaque composant a une entrée Widgetbook couvrant variantes et états, et des goldens en 3 largeurs × 2 échelles de texte (`cgGoldenMatrix`).
3. Les gestes de `CgDrillCard` (tap, swipe 3 directions, verrouillage de direction 12 pt, prévisualisation 40 pt, seuils 35 % / 25 %, retour élastique, recto non swipable) sont couverts par des tests de widget.
4. `MediaQuery.disableAnimations` et `textScaler` ≥ 1,6 sont respectés (goldens à 1,6 ; tests de mouvement réduit).
5. Aucun composant n'importe `shadcn_ui` ni `package:flutter/material.dart` (Cupertino autorisé pour le natif : champ, indicateur, action sheet).
6. Aucune valeur brute : couleurs via `CgTheme.of(context).colors`, tailles via `CgSpace`/`CgRadius`/`CgType`, durées via `CgMotion.resolve`. Une géométrie propre au composant est une constante nommée du composant.
7. Accessibilité : `Semantics` sur chaque composant (libellés français), cibles ≥ 44 pt, jamais la couleur seule.

## Conventions (communes à tous les composants)

- Fichiers : `lib/core/ui/components/cg_<nom>.dart` ; tests `test/core/ui/components/cg_<nom>_test.dart` (goldens dans `test/core/ui/components/goldens/`) ; Widgetbook `widgetbook/lib/use_cases/cg_<nom>_use_cases.dart` exposant `final WidgetbookComponent cg<Nom>Component`.
- Base existante : tokens `lib/core/ui/tokens/*`, thème `lib/core/ui/theme/cg_theme.dart`, icônes `lib/core/ui/foundation/cg_icon.dart` (`CgIcon(CgIcons.search)`), haptique `lib/core/ui/foundation/cg_haptics.dart`, goldens `test/support/cg_golden.dart` (`cgGoldenMatrix`, `cgTestApp`), police `test/support/cg_fonts.dart`.
- Chaque golden montre une planche de tous les états/variantes du composant ; vérifier visuellement le PNG à 1,6×.
- Tests par fichier uniquement (`flutter test test/core/ui/components/cg_<nom>_test.dart`).

## Contrats d'API

### CgButton
`CgButton({required String label, required VoidCallback? onPressed, CgButtonVariant variant = primary, CgButtonSize size = regular, bool loading = false, bool expand = true, String? icon})`
- `CgButtonVariant { primary, secondary, quiet, destructive, inverse }` : primary fond `accent` texte `accentInk` ; secondary fond `surface` contour `line` texte `ink` ; quiet texte `accent` sans fond ; destructive texte `danger` (sans fond, réservé aux sheets) ; inverse fond `accentInk` texte `accent` (sur bloc sarcelle).
- `CgButtonSize { regular (54), compact (44) }`, rayon `CgRadius.button`, texte `CgType.head`.
- Pressé : échelle 0,97 en `CgMotion.fast` (0 si mouvement réduit). Désactivé (`onPressed == null`) : texte `ink3`, fond `soft` pour primary/secondary. Chargement : indicateur (CupertinoActivityIndicator couleur du texte) à la place du libellé, largeur figée, non tapable, Semantics `label` inchangé + « chargement ».
- `Semantics(button: true, enabled:, label: label)`.

### CgTabBar
`CgTabBar({required List<CgTabItem> items, required int currentIndex, required ValueChanged<int> onTap, bool collapsed = false})`, `CgTabItem({required String icon, required String label})`.
- Capsule flottante `CgSpace.tabBarHeight`, marges `tabBarInset` latérales, `tabBarBottom` + safe area en bas ; fond `surface` à 78 % + flou (BackdropFilter σ 24) + ombre douce ; 4 cellules icône 22 + libellé `CgType.tab`.
- Actif : icône et libellé `accent`, pastille `accentSoft` (glisse en `CgMotion.fast`) ; inactif `ink3`. Haptique `CgHaptics.selection()` au changement (pas sur l'onglet déjà actif — `onTap` est quand même appelé : l'écran remonte en haut).
- `collapsed` : pastille d'icônes seules (largeur réduite, centrée), transition `CgMotion.base`.
- Semantics : chaque cellule `button`, `selected`, libellé lu.
- `CgTabBar.reservedHeight(context)` : hauteur à réserver en bas des listes (64 + 22 + safe area).

### CgHeader et CgPage
`CgHeader.large({required String title, String? subtitle, Widget? trailing})` — titre `CgType.titleL` (plafonné 1,3×), sous-titre `CgType.bodyS` `ink2`, trailing 44×44.
`CgHeader.inline({required String title, String? backLabel, VoidCallback? onBack, Widget? trailing})` — barre 44 pt, titre `head` centré, « ‹ backLabel » en `accent`.
`CgPage({required String title, String? subtitle, String? backLabel, VoidCallback? onBack, Widget? trailing, required List<Widget> children, Widget? bottomAction, bool reserveTabBar = false, Future<void> Function()? onRefresh, ScrollController? controller})` — page défilante : large title qui se réduit en barre inline (titre centré + fond `ground` flouté) quand il sort de l'écran ; « ‹ backLabel » au-dessus du large title si `backLabel` ; `bottomAction` ancré en bas au-dessus de la safe area (et de la tab bar si `reserveTabBar`) ; padding bas suffisant pour ne rien masquer ; `CupertinoSliverRefreshControl` si `onRefresh`.

### CgListRow / CgListGroup
`CgListRow({required String title, String? subtitle, Widget? leading, CgRowTrailing trailing = none, String? value, String? actionLabel, VoidCallback? onAction, Widget? progress, VoidCallback? onTap, bool enabled = true, bool selected = false, int titleMaxLines = 2})`, `enum CgRowTrailing { none, chevron, value, action, check, custom }` + `Widget? trailingWidget` pour `custom` (switch).
- Titre `head` (désactivé : `ink2`, poids 500, pas de chevron), sous-titre `meta` `ink2`, valeur `bodyS` `ink3` tabulaire, action `quiet` compacte (texte `accent` 14/600, cible 44), coche `accent` si `selected`.
- Pressé : fond `soft` en `CgMotion.fast`. Filet `line` 1 pt entre lignes (géré par le groupe, jamais après la dernière).
- Dynamic Type > 1,6 : deux niveaux (titre puis valeur/trailing sous le titre).
- Semantics : une ligne = un nœud (titre, sous-titre, valeur) ; `button` si `onTap` ; `selected`.
`CgListGroup({required List<Widget> children, CgListVariant variant = plain, String? header})` — `plain` : filets sur `ground` ; `inset` : groupe `surface` rayon `CgRadius.l`, padding interne `rowInset`. `header` : intertitre `label` `ink3` au-dessus.
`CgSectionTitle(String)` : intertitre de section (13/600 `ink3`, marge haute `section`, basse `related`).

### CgSegmented
`CgSegmented<T>({required List<T> values, required String Function(T) labelOf, required T selected, required ValueChanged<T> onChanged})` — 2 à 4 valeurs (assert). Rail `soft` `CgRadius.s`, pastille `surface` + ombre légère qui glisse (`CgMotion.base`), texte `bodyS`/600 `ink` sélectionné, `ink2` sinon. Haptique `selection`. Dynamic Type > 1,6 : liste de lignes à coche. Semantics `inMutuallyExclusiveGroup`, `selected`, `button`.

### CgSheet
- `Future<T?> showCgSheet<T>(BuildContext, {String? title, required WidgetBuilder builder, CgSheetDetent detent = half, Widget? primary, Widget? secondary})` — route modale maison (PopupRoute) : voile `scrim`, feuille `ground` rayon `CgRadius.l` en haut, poignée, titre `title`, contenu, pied (primary + secondary), glisser vers le bas pour fermer, clavier qui pousse le contenu ; montée `CgMotion.sheetRise`/`CgMotion.out` (fondu si mouvement réduit). `CgSheetDetent { half, full }`.
- `Future<bool> showCgDialogSheet(BuildContext, {required String title, required String message, required String confirmLabel, required String cancelLabel, bool destructive = false})` — question + 2 actions (confirm `primary` ou `destructive`, cancel `quiet`) ; renvoie true si confirmé.
- `Future<void> showCgActionSheet(BuildContext, {String? title, String? message, required List<CgSheetAction> actions, String cancelLabel = 'Annuler'})` — délègue à `CupertinoActionSheet` (`showCupertinoModalPopup`), `CgSheetAction({required String label, required VoidCallback onPressed, bool destructive = false})`.

### CgDrillCard (l'écran de drill) et CgVerdictBar
`enum CgVerdict { review, good, mastered }` (à revoir / bien / maîtrisé).
`CgDrillCard({required String question, required String answer, required String rank, required String collegeName, required int index, required int total, required ValueChanged<CgVerdict> onVerdict, required VoidCallback onClose, String contextLabel = 'Session du jour', bool showFlipHint = true, Widget? answerHeader, Widget? frontInput, bool canFlip = true, VoidCallback? onFlip})`
- Plein écran fond `accent`, texte `accentInk`. En-tête : ✕ (44×44, Semantics « Quitter la session ») · « index / total » + `contextLabel` · vide. Barre de progression segmentée 4 pt (segments = total, pleins jusqu'à index−1 ; au-delà de 40 segments, barre continue). Badge « Rang X » (fond blanc 18 %) + collège. Question 30/600 (26 si largeur < 390) centrée verticalement. Invite « Touche pour voir la réponse » 13 pt si `showFlipHint`.
- Tap (si `canFlip`) → verso : la question remonte en bandeau 17/500 (`CgMotion.questionLift`), feuille `ground` rayon `l` qui monte depuis le bas (`CgMotion.sheetRise`, `CgMotion.out`) jusqu'à ~31 % de la hauteur ; contenu : `answerHeader` optionnel (feedback de définition), réponse `body` 20/400 défilable, invite « Glisse à droite si tu maîtrises, à gauche pour revoir, vers le haut si c'est bien », `CgVerdictBar`. Haptique `flip`, `onFlip`.
- Gestes sur le verso (feuille) : direction verrouillée après 12 pt ; horizontal gauche = review, droite = mastered ; vertical haut = good (bas : aucun verdict, retour) ; prévisualisation dès 40 pt : étiquette « À revoir » (fond `review`, texte `onReview`) en haut à gauche, « Maîtrisé » (fond `ink`, texte `ground`) en haut à droite, « Bien » (fond `good`, texte `ink`) en haut au centre, opacité croissante sur 80 pt ; rotation légère (x / largeur × 6°) ; relâcher sous le seuil (35 % de la largeur, 25 % de la hauteur vers le haut) → retour élastique (`CgMotion.elastic`) ; au-delà → sortie dans la direction en `CgMotion.base` puis `onVerdict` ; haptique du verdict. Le défilement de la réponse ne doit pas déclencher de verdict tant que la direction n'est pas verrouillée horizontale ou que le texte est en haut.
- Recto : un drag ne donne jamais de verdict ; la carte résiste (translation max 8 pt, retour élastique) et l'invite se renforce (opacité 1).
- Boutons `CgVerdictBar` : même animation de sortie que le swipe dans la direction du verdict.
- `frontInput` (mode définition) : champ intégré au recto sous la question ; le parent passe `canFlip: false` tant que la saisie n'est pas validée, puis `canFlip: true` (ou appelle le flip via clé : exposer `CgDrillCardState.flip()`).
- Mouvement réduit : fondus `CgMotion.fast` à la place des glissements, pas de rotation.
- Semantics carte : `label: 'Fiche rang A, Cancérologie. Question : …'`, `hint: 'Touche pour voir la réponse'` (recto) ; les 3 boutons restent le chemin VoiceOver.
`CgVerdictBar({required ValueChanged<CgVerdict> onVerdict, bool enabled = true})` — 3 boutons égaux 54 pt : « À revoir » (fond `surface`, contour `line`, texte `reviewInk`), « Bien » (fond `surface`, texte `ink`), « Maîtrisé » (fond `accent`, texte `accentInk`) ; haptique par verdict (`CgHaptics.review/good/mastered`) ; pressé 0,97 ; Dynamic Type > 1,6 : empilés. Semantics `button`.

### CgRing
`CgRing({required double value /* 0..1 */, CgRingSize size = s, String? centerLabel, String? semanticLabel, bool animate = true})`, `CgRingSize { s (56), m (84), l (200) }`. Rail `unseen`, arc `accent` bouts ronds, départ en haut, sens horaire ; épaisseur 5 / 7 / 14 ; valeur centrée (par défaut pourcentage entier) en `label` (s), `head` (m), `display` (l), tabulaire. Remplissage 0 → valeur en `CgMotion.ringFill` (`CgMotion.out`) une fois à l'apparition ; mouvement réduit ou `animate: false` : valeur directe. Semantics `value: '42 %'`.

### CgRankBar
`CgRankBar({required int mastered, required int good, required int review, required int unseen, CgRankBarSize size = row, bool legend = false})`, `CgRankBarSize { row (6), header (10), hero (22) }`. Segments `mastered`/`good`/`review` proportionnels au **total** (unseen = rail), rayon = moitié de la hauteur (hero : 8). Légende optionnelle : pastille 10 pt + « 104 maîtrisées », « 40 bien », « 17 à revoir », « 180 non vues » (`label` `ink2`, wrap). Total 0 : rail seul. Semantics : « 104 maîtrisées, 40 bien, 17 à revoir, 180 non vues ».

### CgBadge
`CgBadge.rank(String rank /* A|B|C */)` (A : fond `accentSoft` texte `accent` ; B : `rankBSoft` / `rankB` ; C : `soft` / `rankC`) hauteur 22, rayon `CgRadius.badge`, `label`/600 ; `CgBadge.ocr({VoidCallback? onTap})` (icône `warning` + « À vérifier », texte `warningInk`, fond `soft`, cible 44 si tapable) ; `CgBadge.beta()` (« Beta », fond `accentSoft`) ; `CgBadge.count(int)`. Semantics : « Rang A », « Source à vérifier », etc.

### CgField
`CgField({String? label, String? placeholder, TextEditingController? controller, FocusNode? focusNode, CgFieldKind kind = text, String? helper, String? error, bool enabled = true, ValueChanged<String>? onChanged, ValueChanged<String>? onSubmitted, TextInputAction? textInputAction, Iterable<String>? autofillHints, bool autofocus = false, int minLines = 3 /* multiline */})`, `CgFieldKind { text, email, password, search, multiline }`.
- Libellé 15/500 au-dessus, champ 50 pt `surface` contour `line` 1 pt rayon `CgRadius.s` (CupertinoTextField habillé) ; focus : contour `accent` 2 pt ; erreur : contour `danger` + message `danger` sous le champ (remplace l'aide `ink2`) ; désactivé : texte `ink3`.
- `email` : clavier email, pas d'autocorrection, `autofillHints` email par défaut ; `password` : masqué + bouton œil 44 pt (Semantics « Afficher le mot de passe ») ; `search` : 40 pt, fond `soft` sans contour, loupe à gauche, bouton effacer quand non vide ; `multiline` : hauteur libre.
- Semantics : libellé + erreur annoncée (`liveRegion` sur le message).

### CgState
`CgState.empty({required String title, required String message, String? actionLabel, VoidCallback? onAction, CgIllustration illustration = CgIllustration.sheets})`, `CgState.error(...)`, `CgState.offline(...)` (mêmes champs ; illustrations par défaut `broken`, `offline`). Illustration SVG monochrome `accent` 96 pt (formes abstraites, jamais d'emoji), apparition fondu + montée 8 pt en `CgMotion.slow` (aucune si mouvement réduit) ; titre `title` ; texte `bodyS` `ink2` centré ; action `CgButton` (primary pour empty, secondary pour error/offline, compact). `CgIllustration { sheets, broken, offline, search, done }`. Semantics : titre en en-tête.

### CgSkeleton / CgToast
`CgSkeleton.line({double width = double.infinity, double height = 14})`, `CgSkeleton.block({double? width, required double height, double radius = CgRadius.l})`, `CgSkeleton.ring({double size = 56})`, `CgSkeletonList({int rows = 5})` (lignes de liste : pastille 36 + 2 lignes) — fond `soft`, pulsation d'opacité 1 → 0,55 → 1 en `CgMotion.skeletonPulse` (statique si mouvement réduit), `ExcludeSemantics` + un seul `Semantics(label: 'Chargement')` pour `CgSkeletonList`.
`void showCgToast(BuildContext, String message, {bool aboveTabBar = true})` — capsule `ink`, texte `ground` `bodyS`, une ligne (ellipse), en bas au-dessus de la tab bar, 2 s (`CgMotion.toast`), un seul à la fois (le suivant remplace), `SemanticsService.announce`. Fondu + montée 8 pt (fondu seul si mouvement réduit).

## Tâches

- [x] T0 Base : `CgIcons` (29 icônes de la maquette) + `CgIcon`, `CgHaptics`
- [ ] T1 CgButton · T2 CgBadge · T3 CgField · T4 CgSegmented
- [ ] T5 CgListRow/CgListGroup · T6 CgHeader/CgPage · T7 CgTabBar
- [ ] T8 CgDrillCard · T9 CgVerdictBar
- [ ] T10 CgRing · T11 CgRankBar · T12 CgSkeleton/CgToast
- [ ] T13 CgSheet · T14 CgState (+ illustrations)
- [ ] T15 Widgetbook : une entrée par composant, `widgetbook/lib/main.dart` · barrel `lib/core/ui/collega_ui.dart`
- [ ] T16 Revue d'accessibilité (libellés, cibles 44 pt) + test « aucun import Material/shadcn dans components »

## Dev Agent Record

### Agent Model Used

### Completion Notes List

### File List

# Story 8.1 : Tokens, thème et fondation Collega UI

Status: done

## Story

En tant que **développeur**, je veux une source unique de vérité visuelle,
afin qu'aucun écran ne redéfinisse une couleur, une taille ou une durée.

## Critères d'acceptance

1. `lib/core/ui/tokens/` expose couleurs (`CgColors`), typographie (`CgType`, Instrument Sans), espaces (`CgSpace`), rayons (`CgRadius`), durées et courbes (`CgMotion`), aux valeurs de la section « Direction de design » du spec v2.
2. Un test de contraste automatique (`test/core/ui/tokens/contrast_test.dart`) vérifie les couples du spec et échoue sous le seuil.
3. `MaterialApp` est neutralisé (`neutralizeMaterial` : pas d'ondulation, de surbrillance ni de transition Android ; plateforme iOS) ; `buildCgMaterialTheme` dérive fond, surfaces, accent et police des tokens ; `CgTheme` est fourni au-dessus des routes.
4. Widgetbook est installé (`collega_app/widgetbook/`, cible web) et démarre avec une page « Tokens » (palette + contrastes, échelle typographique, espaces, rayons, mouvement, wordmark).
5. `flutter_svg` est ajouté ; le wordmark Collega est rendu en SVG (`CgWordmark`).
6. Aucun écran existant n'est modifié : les écrans shadcn gardent leurs couleurs (seule l'ondulation Material disparaît) ; titre d'app « Collega ».
7. Goldens de la page Tokens en 3 largeurs (375 / 393 / 430) × 2 échelles (1,0 / 1,6).

## Décisions et écarts au spec (tranchés par les tests)

| Sujet | Spec | Retenu | Pourquoi |
|---|---|---|---|
| `ink3` | `#9A9E97` | `#838880` | 2,26:1 sur `ground`, sous le seuil ≥ 3:1 du spec lui-même |
| `rank-b` | `#4C6A6E` | `#4C696D` | 4,50 → 4,56:1 sur son fond de badge `#DDE3E3` |
| `rank-c` | `#8B8A80` | `#64635B` | texte de badge 12-13 pt : 3,9 → 4,6:1 sur `soft` |
| Texte sur `review` | blanc (maquette) | `ink` (`onReview`) | blanc = 2,9:1 ; `ink` = 5,7:1 |
| `title-l` | 32 (échelle) / 34 (`CgHeader`, maquette) | 34 | la maquette et le composant font foi |
| Police | `google_fonts` | **embarquée** (`assets/fonts`, OFL) | hors-ligne garanti, goldens fidèles ; instances statiques 400/500/600/700 générées (fontTools) depuis la police variable Google Fonts, `tnum` présent |
| Wordmark | SVG | contours d'Instrument Sans Bold (−2 %) en `SvgPicture.string` | aucune dépendance à une police au rendu ; source `assets/brand/wordmark.svg` |
| Widgetbook | — | paquet séparé, **web** | le build macOS/iOS hérite des plugins de l'app (pods) ; le catalogue n'en a pas besoin |
| Cupertino | accent seul | via `cupertinoOverrideTheme` | `ShadApp.router` n'expose pas `cupertinoThemeBuilder` |

Styles ajoutés à l'échelle du spec : `numeral` 64 (grand nombre d'Aujourd'hui), `score` 96 (fin de session), `meta` 14 (sous-titre de ligne), `tab` 10,5 (tab bar) — tous présents dans la maquette. Dynamic Type : `CgTextScaleCap` plafonne `display`/`titleL`/`numeral`/`score` à 1,3×.

## Tâches

- [x] T1 tokens (`cg_colors`, `cg_type`, `cg_space`, `cg_radius`, `cg_motion`, `contrast`)
- [x] T2 thème / neutralisation Material (`lib/core/ui/theme/cg_theme.dart`, `lib/app.dart`)
- [x] T3 test de contraste (22 couples + luminance des états + `line` discret)
- [x] T4 Widgetbook + page Tokens (`lib/core/ui/gallery/cg_tokens_page.dart`, `widgetbook/`)
- [x] T5 flutter_svg + wordmark (`lib/core/ui/brand/cg_wordmark.dart`)
- [x] T6 goldens de la page Tokens (`test/core/ui/gallery/goldens/`, utilitaire `test/support/cg_golden.dart` réutilisé en 8.2)

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (1M context)

### Completion Notes List

- `flutter test test/core test/features/smoke_test.dart` : 88 verts. `widgetbook/` : `flutter test` vert, `flutter analyze` propre, `flutter build web` OK.
- Goldens générés sur macOS (Flutter 3.27.1) ; `test/support/cg_fonts.dart` charge la police embarquée (sans lui : rendu Ahem).
- Utilitaire `cgGoldenMatrix(name, builder, height:)` : 6 goldens par sujet, animations réduites par défaut.

### File List

- collega_app/pubspec.yaml, pubspec.lock (flutter_svg, fonts, description Collega)
- collega_app/assets/fonts/ (4 TTF + OFL.txt), assets/brand/wordmark.svg
- collega_app/lib/core/ui/tokens/{cg_colors,cg_type,cg_space,cg_radius,cg_motion,contrast}.dart
- collega_app/lib/core/ui/theme/cg_theme.dart, lib/core/ui/brand/cg_wordmark.dart, lib/core/ui/gallery/cg_tokens_page.dart
- collega_app/lib/app.dart
- collega_app/test/core/ui/** (tokens, contraste, thème, câblage app, wordmark, page Tokens + goldens), test/support/{cg_fonts,cg_golden}.dart
- collega_app/widgetbook/ (nouveau paquet)

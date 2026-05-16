# Story 2.1 : Thème & Design System Flutter

Status: done

<!-- Story de fondation technique — prérequis pour toutes les stories Flutter suivantes. Aucune valeur utilisateur directe. -->

## Story

En tant que **développeur**,
je veux que le thème `shadcn_ui` et les tokens de design soient configurés dans l'app,
afin que toutes les features suivantes utilisent une palette, une typographie et des composants cohérents dès le premier écran.

## Acceptance Criteria

1. **Thème shadcn_ui appliqué avec la palette définie**
   - Étant donné l'app Flutter lancée, quand l'écran principal s'affiche, alors `ShadApp.router` est le widget racine (plus `MaterialApp.router`)
   - Primary `#1B6B3A`, Primary container `#B7F2C8`, Secondary `#3D6B5E`, Surface `#F8FAF9`, On surface `#1A1C1A`, Error `#BA1A1A` sont exposés via `AppColors`

2. **Typographie Inter via google_fonts**
   - `google_fonts` est dans `pubspec.yaml`
   - La police Inter est chargée via `GoogleFonts.interTextTheme()` et appliquée globalement dans `app_theme.dart`
   - Les 6 niveaux sont définis dans `app_theme.dart` : `displayMedium` 28sp/700, `titleLarge` 22sp/600, `titleMedium` 18sp/600, `bodyLarge` 16sp/400, `bodyMedium` 14sp/400, `labelMedium` 12sp/500

3. **Constantes d'espacement dans app_theme.dart**
   - `AppSpacing.screenMargin = 16.0`, `cardPadding = 16.0`, `sectionSpacing = 24.0`, `cardRadius = 12.0`, `buttonRadius = 8.0`, `baseUnit = 8.0`
   - Ces constantes existent déjà — ne pas les supprimer, seulement vérifier leur présence

4. **BottomNavBar fonctionnel (4 tabs)**
   - `bottom_nav_bar.dart` ne lève plus `UnimplementedError` — implémenté avec `NavigationBar` Material 3 (shadcn_ui n'a pas de composant bottom nav natif)
   - 4 onglets : Accueil (home_outlined / home), Collèges (school_outlined / school), Recherche (search), Profil (person_outlined / person)
   - L'onglet actif utilise la couleur primary `#1B6B3A`

5. **ShellRoute GoRouter + scaffold principal**
   - `app_router.dart` contient un `ShellRoute` qui wrappe les 4 routes tab avec `BottomNavBar`
   - Routes stubs créées : `/home`, `/colleges`, `/search`, `/profile` — chacune affiche `Scaffold(body: Center(child: Text('...')))` en attendant l'implémentation
   - Route initiale `/` redirige vers `/home`

6. **Aucun CircularProgressIndicator dans le codebase**
   - `grep -r "CircularProgressIndicator" lib/` ne retourne aucun résultat
   - Tout état de chargement utilise `ShadSkeleton`

7. **`flutter analyze` sans erreur**
   - `flutter analyze` passe proprement après les modifications

## Tasks / Subtasks

- [x] **T1 — Ajouter google_fonts à pubspec.yaml** (AC: #2)
  - [x] Ajouter `google_fonts: ^6.2.1` dans `dependencies`
  - [x] Lancer `flutter pub get`

- [x] **T2 — Implémenter app_theme.dart complet** (AC: #1, #2, #3)
  - [x] Garder `AppColors` et `AppSpacing` existants (ils sont corrects)
  - [x] Ajouter `AppTypography` avec les 6 niveaux Inter
  - [x] Remplacer `buildAppTheme()` par `buildShadTheme()` qui retourne `ShadThemeData`
  - [x] Configurer le `colorScheme` shadcn_ui avec les 6 couleurs de la palette
  - [x] Appliquer `GoogleFonts.interTextTheme()` comme `textTheme` de base

- [x] **T3 — Migrer app.dart de MaterialApp.router vers ShadApp.router** (AC: #1)
  - [x] Remplacer `MaterialApp.router` par `ShadApp.router`
  - [x] Passer `theme: buildShadTheme()` à `ShadApp.router`
  - [x] Conserver `routerConfig: appRouter` et `debugShowCheckedModeBanner: false`

- [x] **T4 — Implémenter bottom_nav_bar.dart** (AC: #4)
  - [x] Remplacer le stub `throw UnimplementedError(...)` par une vraie implémentation
  - [x] Utiliser `NavigationBar` (Material 3) — shadcn_ui n'a pas de BottomNav natif
  - [x] 4 destinations avec icônes outlined/filled selon état actif
  - [x] Couleur active = `AppColors.primary`

- [x] **T5 — Mettre à jour app_router.dart avec ShellRoute** (AC: #5)
  - [x] Créer `_AppShell` widget qui wraps le contenu avec `BottomNavBar`
  - [x] Définir les 4 routes tab stubs : `/home`, `/colleges`, `/search`, `/profile`
  - [x] Route `/` redirige vers `/home` (`redirect: (ctx, state) => '/home'`)
  - [x] `_AppShell` gère `currentIndex` en lisant `GoRouterState.of(context).fullPath`

- [x] **T6 — Vérification finale** (AC: #6, #7)
  - [x] `grep -r "CircularProgressIndicator" lib/` → 0 résultat
  - [x] `flutter analyze` → 0 erreur

### Review Findings

- [x] [Review][Decision] AppTypography non connectée au thème global → résolu: connectée via `ShadTextTheme.copyWith` (h2, h3, large, p, small, muted). [AC2] [`app_theme.dart`]
- [x] [Review][Decision] AC4 — Couleur icône onglet actif → résolu: `NavigationBarTheme` ajouté avec `iconTheme` selected = `AppColors.primary`. [AC4] [`bottom_nav_bar.dart`]
- [x] [Review][Decision] `_tabIndex` désynchronisation GoRouterState → résolu: remplacé `fullPath ?? '/home'` par `uri.path` (non-nullable, fiable en GoRouter 14.x). [AC5] [`app_router.dart`]
- [x] [Review][Patch] Double Scaffold dans les stubs — supprimé le `Scaffold` de chaque stub; `_AppShell` fournit le seul Scaffold. [`app_router.dart`]
- [x] [Review][Patch] `redirect` ne gère pas `state.fullPath == null` — guard corrigée: `if (state.fullPath == null || state.fullPath == '/') return '/home';` [`app_router.dart:7-9`]
- [x] [Review][Patch] `AppTypography` — paramètre `BuildContext context` supprimé des 6 méthodes. [`app_theme.dart:25-36`]
- [x] [Review][Defer] Dark mode non géré — `brightness: Brightness.light` hardcodé, pas de `darkTheme` — deferred, hors scope story 2.1 [`app_theme.dart:41`]
- [x] [Review][Defer] `google_fonts` non bundlé offline — fonte chargée par réseau en production — deferred, déploiement hors scope [`pubspec.yaml`]
- [x] [Review][Defer] `onTap` sans bounds check sur `paths[i]` — risque si tabs ajoutés/retirés sans synchronisation — deferred, safe avec 4 tabs fixes actuellement [`app_router.dart`]
- [x] [Review][Defer] Smoke test faible — seul `takeException() isNull` vérifié, pas de assertion sur widgets rendus — deferred, amélioration test hors scope [`smoke_test.dart`]

## Dev Notes

### Contexte de migration critique

**app.dart** utilise actuellement `MaterialApp.router`. La migration vers `ShadApp.router` est le changement central de cette story. `ShadApp` wrappe `MaterialApp` en interne et applique le thème shadcn_ui en plus du thème Material — les deux coexistent, shadcn_ui prend le dessus pour ses propres composants.

**ATTENTION** : `buildAppTheme()` dans `app_theme.dart` retourne `ThemeData`. Après la story, on retourne `ShadThemeData`. Renommer en `buildShadTheme()` pour éviter toute confusion dans les stories suivantes.

### shadcn_ui 0.19.0 — API de configuration

```dart
import 'package:shadcn_ui/shadcn_ui.dart';

ShadThemeData buildShadTheme() {
  return ShadThemeData(
    brightness: Brightness.light,
    colorScheme: const ShadColorScheme.fromName(
      'custom',
      background: Color(0xFFF8FAF9),        // Surface
      foreground: Color(0xFF1A1C1A),        // On surface
      primary: Color(0xFF1B6B3A),
      primaryForeground: Color(0xFFFFFFFF),
      secondary: Color(0xFF3D6B5E),
      secondaryForeground: Color(0xFFFFFFFF),
      destructive: Color(0xFFBA1A1A),
      destructiveForeground: Color(0xFFFFFFFF),
      // ... autres champs requis — voir pub.dev/packages/shadcn_ui
    ),
    textTheme: ShadTextTheme.fromGoogleFont(GoogleFonts.inter),
  );
}
```

> **Vérifier l'API exacte** de `ShadColorScheme` et `ShadTextTheme` dans la documentation pubdev de `shadcn_ui 0.19.x` avant d'implémenter — l'API a évolué entre 0.17 et 0.19. Consulter les exemples du package (`example/lib/`) si nécessaire.

### Typographie Inter — 6 niveaux

```dart
class AppTypography {
  static TextStyle displayMedium(BuildContext context) =>
      GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700);
  static TextStyle titleLarge(BuildContext context) =>
      GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600);
  static TextStyle titleMedium(BuildContext context) =>
      GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600);
  static TextStyle bodyLarge(BuildContext context) =>
      GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400);
  static TextStyle bodyMedium(BuildContext context) =>
      GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400);
  static TextStyle labelMedium(BuildContext context) =>
      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500);
}
```

### ShellRoute + BottomNav — pattern GoRouter

```dart
// app_router.dart
final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (ctx, s) => const _HomeStub()),
        GoRoute(path: '/colleges', builder: (ctx, s) => const _CollegesStub()),
        GoRoute(path: '/search', builder: (ctx, s) => const _SearchStub()),
        GoRoute(path: '/profile', builder: (ctx, s) => const _ProfileStub()),
      ],
    ),
  ],
);

class _AppShell extends StatelessWidget {
  const _AppShell({required this.child});
  final Widget child;

  int _tabIndex(BuildContext context) {
    final path = GoRouterState.of(context).fullPath ?? '/home';
    if (path.startsWith('/colleges')) return 1;
    if (path.startsWith('/search')) return 2;
    if (path.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavBar(
        currentIndex: _tabIndex(context),
        onTap: (i) {
          const paths = ['/home', '/colleges', '/search', '/profile'];
          context.go(paths[i]);
        },
      ),
    );
  }
}
```

### BottomNavBar — implémentation Material 3

shadcn_ui ^0.19.0 ne fournit pas de `BottomNavigationBar` — utiliser `NavigationBar` de Material 3 (déjà disponible via le `MaterialApp` interne de `ShadApp`) :

```dart
// shared/widgets/bottom_nav_bar.dart
import 'package:flutter/material.dart';
import 'package:collega_app/core/theme/app_theme.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      indicatorColor: AppColors.primaryContainer,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Accueil',
        ),
        NavigationDestination(
          icon: Icon(Icons.school_outlined),
          selectedIcon: Icon(Icons.school),
          label: 'Collèges',
        ),
        NavigationDestination(
          icon: Icon(Icons.search),
          selectedIcon: Icon(Icons.search),
          label: 'Recherche',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outlined),
          selectedIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
    );
  }
}
```

### Fichiers existants à préserver

| Fichier | État actuel | Action Story 2.1 |
|---------|------------|------------------|
| `core/theme/app_theme.dart` | Stub avec `AppColors`, `AppSpacing`, `buildAppTheme()` | Conserver `AppColors` + `AppSpacing`, remplacer `buildAppTheme()` par `buildShadTheme()`, ajouter `AppTypography` |
| `app.dart` | `MaterialApp.router` | Migrer vers `ShadApp.router` |
| `core/router/app_router.dart` | Route `/` avec `_HomeScreen` stub | Remplacer par ShellRoute + 4 tab routes stubs |
| `shared/widgets/bottom_nav_bar.dart` | `throw UnimplementedError(...)` | Implémenter avec `NavigationBar` |
| `shared/widgets/error_view.dart` | Existant | Ne pas toucher |
| `core/network/api_client.dart` | Existant | Ne pas toucher |
| `core/database/app_database.dart` | Existant | Ne pas toucher |
| `main.dart` | `ProviderScope` + `App()` | Ne pas toucher |

### Anti-patterns à éviter

- **Ne pas** utiliser `CircularProgressIndicator` — utiliser `ShadSkeleton`
- **Ne pas** utiliser `MaterialApp` directement — `ShadApp` le wrappe en interne
- **Ne pas** mettre de logique métier dans les widgets — dans les Notifiers (Riverpod)
- **Ne pas** définir plusieurs boutons `filled` primary sur le même écran (UX-DR18)
- **Ne pas** créer les écrans de features réels — seulement des stubs `_HomeStub`, etc.

### Règles qualité (architecture)

- `flutter analyze` doit passer à 0 erreur
- Jamais `print()` ou `debugPrint()` en code de production — utiliser `lib/core/utils/logger.dart`
- Tous les fichiers Dart : PascalCase classes, camelCase méthodes/variables, snake_case noms de fichiers

### Project Structure Notes

- `app_theme.dart` → `lib/core/theme/app_theme.dart` (UPDATE)
- `app.dart` → `lib/app.dart` (UPDATE)
- `app_router.dart` → `lib/core/router/app_router.dart` (UPDATE)
- `bottom_nav_bar.dart` → `lib/shared/widgets/bottom_nav_bar.dart` (UPDATE)
- Aucun fichier à créer en dehors de ces 4

### References

- Palette + typographie : [epics.md#Story 2.1 AC + UX-DR2, UX-DR3]
- Structure fichiers Flutter : [architecture.md#Project Structure & Boundaries]
- shadcn_ui setup : [architecture.md#Core Architectural Decisions — Design system]
- BottomNav UX : [epics.md#UX-DR5] — 4 tabs, masquée pendant Mode Drill (story future)
- Anti-patterns : [architecture.md#Implementation Patterns — Anti-patterns]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- `ShadColorScheme.fromName('custom', ...)` non fonctionnel (lève une exception) — utilisé `ShadColorScheme(...)` direct avec tous les champs requis
- `ShadApp.router` en mode shadcn utilise `WidgetsApp.router` + `GlobalMaterialLocalizations` (pas `MaterialApp`) — `flutter/widgets.dart` doit être importé explicitement dans `app.dart`
- `google_fonts: ^6.2.1` résolu en `6.3.0` par pub
- Smoke test mis à jour avec `pumpAndSettle()` car `shadcn_ui` via `flutter_animate` crée un timer qui persiste sans settle

### Completion Notes List

- T1 : `google_fonts: ^6.2.1` ajouté dans `pubspec.yaml`, résolu en `6.3.0`
- T2 : `app_theme.dart` réécrit avec `AppTypography` (6 niveaux Inter), `buildShadTheme()` retournant `ShadThemeData`, `ShadColorScheme` complet (20 tokens couleur), `ShadTextTheme.fromGoogleFont(GoogleFonts.inter)`
- T3 : `app.dart` migré vers `ShadApp.router` + `buildShadTheme()` + import `flutter/widgets.dart`
- T4 : `bottom_nav_bar.dart` implémenté avec `NavigationBar` Material 3, 4 destinations, `indicatorColor: AppColors.primaryContainer`
- T5 : `app_router.dart` reécrit avec `ShellRoute`, `_AppShell`, 4 route stubs, redirect `/` → `/home`
- T6 : `grep CircularProgressIndicator` → 0 résultat ; `flutter analyze` → 0 erreur ; smoke test → passé

### File List

- `collega_app/pubspec.yaml` (UPDATE — google_fonts 6.3.0 ajouté)
- `collega_app/lib/core/theme/app_theme.dart` (UPDATE)
- `collega_app/lib/app.dart` (UPDATE)
- `collega_app/lib/core/router/app_router.dart` (UPDATE)
- `collega_app/lib/shared/widgets/bottom_nav_bar.dart` (UPDATE)
- `collega_app/test/features/smoke_test.dart` (UPDATE — pumpAndSettle)

### Change Log

- 2026-05-04 : Story 2.1 implémentée — thème shadcn_ui, typographie Inter, BottomNavBar, ShellRoute GoRouter

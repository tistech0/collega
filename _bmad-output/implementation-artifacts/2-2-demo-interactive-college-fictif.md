# Story 2.2 : Démo Interactive (Collège Fictif)

Status: done

## Story

En tant qu'**étudiant visiteur**,
je veux explorer une démo interactive avec un collège fictif et des fiches pré-chargées sans créer de compte,
afin de comprendre la valeur d'AppMédecine avant de m'engager.

## Acceptance Criteria

1. **Démo proposée en premier — CTA primaire visible (FR1)**
   - Étant donné l'app lancée pour la première fois
   - Quand l'écran d'accueil s'affiche
   - Alors la démo interactive est proposée en premier — pas d'écran de connexion bloquant
   - Et le bouton "Essayer la démo" est le CTA primaire visible (ShadButton filled)

2. **Collège fictif "Cardiologie Exemple" pré-chargé**
   - Étant donné que je lance la démo
   - Quand j'entre dans le mode démo
   - Alors un collège fictif "Cardiologie Exemple" est visible avec 3 fiches (dont au moins 1 Rang A et 1 Rang B) et 1 item "Insuffisance Cardiaque"
   - Et les badges Rang A / Rang B sont colorés (vert primary / teal secondary)
   - Et une barre de progression "0/3 fiches" est visible

3. **Animation FlashCard + DrillEvaluationBar fonctionnelle**
   - Étant donné que je suis dans la démo
   - Quand je tape sur une fiche
   - Alors l'animation de retournement FlashCard s'exécute (via flutter_animate — `.flip()` + `.fade()`) en < 300ms
   - Et la DrillEvaluationBar apparaît après retournement avec les 3 boutons : "À revoir" (rouge) / "Bien" (teal) / "Maîtrisé" (vert)
   - Et un feedback haptique se déclenche au tap sur chaque bouton d'évaluation

4. **Redirection vers inscription depuis la démo (FR2)**
   - Étant donné que je suis dans la démo
   - Quand je tape sur "S'inscrire" ou "Commencer pour de vrai"
   - Alors je suis redirigé vers `/auth/register` (stub pour Story 2.3)

5. **Skip démo → inscription directe (FR2)**
   - Étant donné que je veux ignorer la démo
   - Quand je tape sur "Accéder directement" ou "Skip"
   - Alors je suis redirigé vers `/auth/register` directement depuis l'écran d'accueil démo

6. **Démo sans compte ni connexion réseau (contrainte App Store)**
   - Étant donné les contraintes App Store
   - Quand la démo est lancée hors ligne
   - Alors toutes les données du collège fictif sont disponibles (hardcodées dans le code Dart — zéro appel réseau)
   - Et `flutter analyze` passe à 0 erreur

## Tasks / Subtasks

- [x] **T1 — Données démo hardcodées** (AC: #2, #6)
  - [x] Créer `lib/features/demo/domain/demo_data.dart` avec : `DemoFlashCard`, `DemoItem`, `DemoCollege` (classes simples, pas de Drift ni réseau)
  - [x] Implémenter `demoCollege` : collège "Cardiologie Exemple", 1 item "Insuffisance Cardiaque" (n°1), 3 fiches hardcodées (rang A/A/B)
  - [x] Toutes les données sont `const` — aucune dépendance externe

- [x] **T2 — State management Riverpod** (AC: #3)
  - [x] Créer `lib/features/demo/demo_providers.dart`
  - [x] Définir `DemoDrillState` (immutable, avec `copyWith`) : `currentIndex`, `isFlipped`, `evaluations` (Map<int, String>), `isComplete`
  - [x] Implémenter `DemoDrillNotifier extends Notifier<DemoDrillState>` avec méthodes : `flip()`, `evaluate(String rang)`, `reset()`
  - [x] Exposer via `demoDrillProvider = NotifierProvider<DemoDrillNotifier, DemoDrillState>`

- [x] **T3 — Widget DemoFlashCardWidget** (AC: #3)
  - [x] Créer `lib/features/demo/presentation/widgets/demo_flash_card_widget.dart`
  - [x] Recto (question) + verso (réponse) avec animation retournement via flutter_animate
  - [x] Badge rang coloré (ShadBadge) : Rang A → `AppColors.primary`, Rang B → `AppColors.secondary`
  - [x] Accessibilité : `Semantics(label: 'Flashcard Rang $rang — $question', hint: 'Tapoter pour retourner')`
  - [x] Tap target ≥ 44×44px (SizedBox minimum ou GestureDetector avec HitTestBehavior.opaque)
  - [x] Callback `onFlip` notifié au retournement

- [x] **T4 — Widget DemoDrillEvaluationBar** (AC: #3)
  - [x] Créer `lib/features/demo/presentation/widgets/demo_drill_evaluation_bar.dart`
  - [x] 3 ShadButton empilés verticalement pleine largeur : "À revoir" (variant `destructive`), "Bien" (variant `outline`), "Maîtrisé" (variant `primary`)
  - [x] Apparition via `AnimatedOpacity` : opacity 0.0 avant retournement → 1.0 après (durée 200ms)
  - [x] `HapticFeedback.lightImpact()` au tap sur chaque bouton
  - [x] Callback `onEvaluate(String rang)` avec valeurs `'A_REVOIR'`, `'BIEN'`, `'MAITRISE'`

- [x] **T5 — DemoDrillScreen** (AC: #2, #3, #4)
  - [x] Créer `lib/features/demo/presentation/demo_drill_screen.dart`
  - [x] DrillHeader : `IconButton` ✕ (retour → `context.go('/demo')`) + titre "Cardiologie Exemple" (AppTypography.bodyLarge, centré) + ShadBadge "Rang A" (shrink-0)
  - [x] `ShadProgress` : "X/3 fiches" mis à jour après chaque évaluation
  - [x] Corps : `DemoFlashCardWidget` (centered, min height 300px) + `DemoDrillEvaluationBar` dessous
  - [x] Pas de BottomNavBar — `Scaffold` sans `bottomNavigationBar`
  - [x] Écran récap (quand `isComplete == true`) : compteurs Maîtrisé/Bien/À revoir + CTA "Commencer pour de vrai" filled → `/auth/register` + CTA "Recommencer" outline → `ref.read(demoDrillProvider.notifier).reset()`

- [x] **T6 — DemoScreen (landing)** (AC: #1, #2, #4, #5)
  - [x] Créer `lib/features/demo/presentation/demo_screen.dart`
  - [x] `Scaffold` sans `bottomNavigationBar`
  - [x] ShadCard présentant le collège fictif : nom "Cardiologie Exemple", 3 lignes de fiches preview (question tronquée, badge rang), CTA "Commencer" → déclenche navigation vers `/demo/drill`
  - [x] CTA primaire (bas d'écran) : `ShadButton` filled "Essayer la démo" → `context.go('/demo/drill')`
  - [x] CTA secondaire ghost : "Accéder directement" → `context.go('/auth/register')`

- [x] **T7 — Mise à jour app_router.dart** (AC: #1, #4, #5)
  - [x] Changer `initialLocation: '/demo'`
  - [x] Adapter redirect : `if (state.fullPath == null || state.fullPath == '/') return '/demo';`
  - [x] Ajouter hors ShellRoute : `GoRoute(path: '/demo', builder: ...)`, `GoRoute(path: '/demo/drill', builder: ...)`, `GoRoute(path: '/auth/register', builder: ...stub...)`
  - [x] Conserver ShellRoute inchangé (4 routes stubs `/home`, `/colleges`, `/search`, `/profile`)

- [x] **T8 — Tests et validation** (AC: tous)
  - [x] Créer `test/features/demo/demo_screen_test.dart` : widget test vérifiant présence "Essayer la démo" et "Accéder directement"
  - [x] Créer `test/features/demo/demo_providers_test.dart` : unit test sur `DemoDrillNotifier` — `flip()` change `isFlipped`, `evaluate()` ajoute à `evaluations`, après 3 évals `isComplete == true`
  - [x] Vérifier que `test/features/smoke_test.dart` passe toujours (App se construit sans exception)
  - [x] `flutter analyze` → 0 erreur

## Dev Notes

### Contexte d'implémentation critique

Cette story est la **première feature Flutter fonctionnelle** (Story 2.1 était du design system / plomberie). L'écran de démo sera le point d'entrée visible de l'app, sans réseau, sans auth.

**État actuel des fichiers existants après Story 2.1 :**

| Fichier | État | Ce que Story 2.2 touche |
|---|---|---|
| `lib/core/router/app_router.dart` | GoRouter, `initialLocation: '/home'`, ShellRoute 4 stubs | Changer initialLocation, ajouter 3 routes hors Shell |
| `lib/app.dart` | ShadApp.router + buildShadTheme() | NE PAS TOUCHER |
| `lib/core/theme/app_theme.dart` | AppColors, AppSpacing, AppTypography, buildShadTheme() | NE PAS TOUCHER |
| `lib/shared/widgets/bottom_nav_bar.dart` | NavigationBar Material 3 | NE PAS TOUCHER |
| `lib/main.dart` | ProviderScope + App() | NE PAS TOUCHER |
| `lib/features/demo/` | Dossier vide | CRÉER les fichiers |

### Architecture de la feature demo/

Suivre le pattern feature-first défini en architecture :

```
lib/features/demo/
├── domain/
│   └── demo_data.dart           # Modèles + données hardcodées (const)
├── presentation/
│   ├── demo_screen.dart         # Écran landing (CTA principal)
│   ├── demo_drill_screen.dart   # Écran drill plein écran
│   └── widgets/
│       ├── demo_flash_card_widget.dart    # FlashCard avec animation
│       └── demo_drill_evaluation_bar.dart # Barre 3 boutons évaluation
└── demo_providers.dart          # Riverpod Notifier (state drill)
```

### Modèles de données demo_data.dart

```dart
enum DemoCardType { classic, definition }

class DemoFlashCard {
  const DemoFlashCard({
    required this.id,
    required this.front,
    required this.back,
    required this.rang,
    required this.type,
  });
  final String id;
  final String front;
  final String back;
  final String rang; // 'A' ou 'B'
  final DemoCardType type;
}

class DemoItem {
  const DemoItem({required this.number, required this.title, required this.rang, required this.cards});
  final int number;
  final String title;
  final String rang;
  final List<DemoFlashCard> cards;
}

class DemoCollege {
  const DemoCollege({required this.name, required this.item});
  final String name;
  final DemoItem item;
}

// Données hardcodées — const, zéro réseau
const demoCollege = DemoCollege(
  name: 'Cardiologie Exemple',
  item: DemoItem(
    number: 1,
    title: 'Insuffisance Cardiaque',
    rang: 'A',
    cards: [
      DemoFlashCard(
        id: 'demo-1',
        front: 'Quels sont les signes cliniques de l\'insuffisance cardiaque gauche ?',
        back: 'Dyspnée d\'effort → de repos, orthopnée, crépitants bilatéraux, toux nocturne, expectorations rosées mousseuses.',
        rang: 'A',
        type: DemoCardType.classic,
      ),
      DemoFlashCard(
        id: 'demo-2',
        front: 'Définition : Insuffisance cardiaque',
        back: 'Incapacité du cœur à assurer un débit adapté aux besoins métaboliques, malgré des pressions de remplissage normales ou élevées.',
        rang: 'A',
        type: DemoCardType.definition,
      ),
      DemoFlashCard(
        id: 'demo-3',
        front: 'Quel biomarqueur clé pour le diagnostic de l\'insuffisance cardiaque ?',
        back: 'BNP (> 100 pg/mL) ou NT-proBNP (> 300 pg/mL en urgence) — marqueur de surcharge de pression/volume ventriculaire.',
        rang: 'B',
        type: DemoCardType.classic,
      ),
    ],
  ),
);
```

### State management Riverpod — demo_providers.dart

Utiliser `Notifier` (synchrone, pas `AsyncNotifier`) car les données sont hardcodées :

```dart
@immutable
class DemoDrillState {
  const DemoDrillState({
    this.currentIndex = 0,
    this.isFlipped = false,
    this.evaluations = const {},
    this.isComplete = false,
  });
  final int currentIndex;
  final bool isFlipped;
  final Map<int, String> evaluations; // index → 'A_REVOIR' | 'BIEN' | 'MAITRISE'
  final bool isComplete;

  DemoDrillState copyWith({ int? currentIndex, bool? isFlipped, Map<int, String>? evaluations, bool? isComplete }) =>
    DemoDrillState(
      currentIndex: currentIndex ?? this.currentIndex,
      isFlipped: isFlipped ?? this.isFlipped,
      evaluations: evaluations ?? this.evaluations,
      isComplete: isComplete ?? this.isComplete,
    );
}

class DemoDrillNotifier extends Notifier<DemoDrillState> {
  @override
  DemoDrillState build() => const DemoDrillState();

  void flip() => state = state.copyWith(isFlipped: !state.isFlipped);

  void evaluate(String rang) {
    final newEvals = Map<int, String>.from(state.evaluations)..[state.currentIndex] = rang;
    final total = demoCollege.item.cards.length;
    final nextIndex = state.currentIndex + 1;
    state = state.copyWith(
      evaluations: newEvals,
      currentIndex: nextIndex < total ? nextIndex : state.currentIndex,
      isFlipped: false,
      isComplete: newEvals.length >= total,
    );
  }

  void reset() => state = const DemoDrillState();
}

final demoDrillProvider = NotifierProvider<DemoDrillNotifier, DemoDrillState>(
  DemoDrillNotifier.new,
);
```

### Animation FlashCard avec flutter_animate

**flutter_animate v4.5.0** est dans le pubspec. La méthode recommandée pour l'animation de retournement :

```dart
// DemoFlashCardWidget utilise un StatefulWidget avec AnimationController
// pour le contrôle précis du flip, + flutter_animate pour le fade de transition.

// Approche : deux widgets (recto/verso) avec AnimatedSwitcher ou Transform.
// La doc flutter_animate mentionne FlipEffect, mais le résultat est plus propre
// avec un AnimationController custom + Transform.rotateY combiné à flutter_animate .fade()

// Pattern recommandé pour le retournement de card :
class DemoFlashCardWidget extends StatefulWidget { ... }
class _DemoFlashCardWidgetState extends State<DemoFlashCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _rotateAnim = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  void _flip() {
    if (_controller.isCompleted) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
    widget.onFlip?.call();
  }

  Widget _buildSide(bool showFront) {
    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001) // perspective
        ..rotateY(showFront ? 0 : pi),
      alignment: Alignment.center,
      child: showFront ? _buildRecto() : _buildVerso(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isFlipped ? null : _flip,
      child: AnimatedBuilder(
        animation: _rotateAnim,
        builder: (ctx, _) {
          final angle = _rotateAnim.value * pi;
          final showFront = angle <= pi / 2;
          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: angle <= pi / 2 ? _buildRecto() : _buildVerso(),
          );
        },
      ),
    );
  }
}
```

> **Alternative plus simple**: Utiliser `AnimatedSwitcher` avec un `transitionBuilder` personnalisé pour un flip Y. Moins précis mais plus rapide à implémenter. Le dev peut choisir selon son jugement — l'important est que l'animation soit < 300ms et fluide.

**Animation de sortie de card (après évaluation) :**
```dart
// Maîtrisé → sort par le haut
cardWidget.animate().slideY(end: -1.5, duration: 250.ms).fade(end: 0)

// À revoir → sort par le bas  
cardWidget.animate().slideY(end: 1.5, duration: 250.ms).fade(end: 0)
```

### Routing GoRouter — changements à effectuer

**Avant (Story 2.1) :**
```dart
final appRouter = GoRouter(
  initialLocation: '/home',
  redirect: (context, state) {
    if (state.fullPath == null || state.fullPath == '/') return '/home';
    return null;
  },
  routes: [ShellRoute(...)], // ShellRoute avec /home, /colleges, /search, /profile
);
```

**Après (Story 2.2) :**
```dart
final appRouter = GoRouter(
  initialLocation: '/demo',
  redirect: (context, state) {
    if (state.fullPath == null || state.fullPath == '/') return '/demo';
    return null;
  },
  routes: [
    // Hors ShellRoute — pas de BottomNavBar
    GoRoute(path: '/demo', builder: (ctx, s) => const DemoScreen()),
    GoRoute(path: '/demo/drill', builder: (ctx, s) => const DemoDrillScreen()),
    GoRoute(path: '/auth/register', builder: (ctx, s) => const _AuthRegisterStub()),
    // ShellRoute INCHANGÉ
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

// Stub minimal pour auth/register (sera implémenté en Story 2.3)
class _AuthRegisterStub extends StatelessWidget {
  const _AuthRegisterStub();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Inscription'),
            ShadButton.ghost(
              onPressed: () => context.go('/demo'),
              child: const Text('Retour à la démo'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Composants shadcn_ui à utiliser

| Besoin | Composant shadcn_ui |
|---|---|
| CTA principal "Essayer la démo" | `ShadButton` (filled, default) |
| CTA secondaire "Accéder directement" | `ShadButton.ghost` |
| Badge rang A/B | `ShadBadge` avec `backgroundColor` : primary/secondary |
| Card collège fictif | `ShadCard` avec `padding: EdgeInsets.all(AppSpacing.cardPadding)` |
| Barre progression "X/3 fiches" | `ShadProgress` (value: currentIndex / total) |
| Bouton "À revoir" | `ShadButton.destructive` |
| Bouton "Bien" | `ShadButton.outline` avec couleur secondary |
| Bouton "Maîtrisé" | `ShadButton` (filled primary) |

**ATTENTION** : Ne jamais utiliser `CircularProgressIndicator` — utiliser `ShadSkeleton` pour les états de chargement (non applicable ici mais règle générale à respecter).

### Règles qualité à respecter

- `flutter analyze` → 0 erreur avant de marquer la story terminée
- Jamais `print()` ou `debugPrint()` → utiliser `lib/core/utils/logger.dart` si besoin de logs
- Logique métier dans `DemoDrillNotifier` (Riverpod), jamais dans les widgets directement
- Widgets consomment le state via `ConsumerWidget` + `ref.watch(demoDrillProvider)`
- Nommage : PascalCase classes, camelCase méthodes, snake_case fichiers

### Test pattern à suivre

```dart
// demo_providers_test.dart — pure unit test, pas de widget
void main() {
  group('DemoDrillNotifier', () {
    late ProviderContainer container;
    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('état initial correct', () {
      final state = container.read(demoDrillProvider);
      expect(state.currentIndex, 0);
      expect(state.isFlipped, false);
      expect(state.isComplete, false);
    });

    test('flip() bascule isFlipped', () {
      container.read(demoDrillProvider.notifier).flip();
      expect(container.read(demoDrillProvider).isFlipped, true);
    });

    test('evaluate() après 3 évals → isComplete = true', () {
      final notifier = container.read(demoDrillProvider.notifier);
      notifier.flip();
      notifier.evaluate('MAITRISE');
      notifier.flip();
      notifier.evaluate('BIEN');
      notifier.flip();
      notifier.evaluate('A_REVOIR');
      expect(container.read(demoDrillProvider).isComplete, true);
    });
  });
}
```

### Anti-patterns à éviter absolument

- **Ne pas** créer de vraie logique d'auth dans `/auth/register` — c'est un stub vide (Story 2.3 s'en charge)
- **Ne pas** faire d'appels Dio/réseau dans la feature demo — tout est hardcodé
- **Ne pas** utiliser `CircularProgressIndicator`
- **Ne pas** toucher à `app.dart`, `main.dart`, `app_theme.dart`, `bottom_nav_bar.dart`
- **Ne pas** supprimer ou modifier le ShellRoute existant dans `app_router.dart` — seulement ajouter des routes et changer `initialLocation`
- **Ne pas** implémenter les vrais composants `FlashCard` et `DrillEvaluationBar` dans leurs emplacements définitifs (`generation/widgets/`, `drill/widgets/`) — Story 4.1 s'en charge avec la full spec. Les widgets de cette story sont préfixés `Demo` et scoped dans `features/demo/`

### Références

- Palette couleurs + typographie : [epics.md#UX-DR2, UX-DR3]
- FlashCard + DrillEvaluationBar (spec complète pour Story 4.1) : [epics.md#Story 4.1]
- shadcn_ui usage patterns : [architecture.md#Implementation Patterns — Process Patterns]
- Navigation GoRouter ShellRoute : [collega_app/lib/core/router/app_router.dart] (état post Story 2.1)
- flutter_animate API : [pubspec.yaml#flutter_animate: ^4.5.0]
- Anti-patterns : [architecture.md#Enforcement Guidelines — NEVER]
- Accessibilité FlashCard : [epics.md#UX-DR7]
- UX landing screen démo : [ux-design-specification.md#Onboarding → Paywall — démo interactive]

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

### Completion Notes List

- T1 : `demo_data.dart` créé avec modèles const `DemoFlashCard`, `DemoItem`, `DemoCollege` et données hardcodées (3 fiches : 2 Rang A + 1 Rang B). Zéro réseau, zéro dépendance externe.
- T2 : `demo_providers.dart` — `DemoDrillState` immutable avec `copyWith`, `DemoDrillNotifier` avec `flip()`, `evaluate()`, `reset()`. Exposé via `demoDrillProvider`.
- T3 : `DemoFlashCardWidget` — animation de retournement 3D via `AnimationController` + `Transform.rotateY` (300ms). Badges ShadBadge colorés. Semantics accessibilité. Tap target 300px de hauteur.
- T4 : `DemoDrillEvaluationBar` — 3 boutons ShadButton (destructive/outline/filled), `AnimatedOpacity` 200ms, `HapticFeedback.lightImpact()` au tap.
- T5 : `DemoDrillScreen` — header avec ✕, ShadProgress, FlashCard + EvaluationBar, écran récap avec compteurs et CTA.
- T6 : `DemoScreen` — landing avec ShadCard collège fictif (3 lignes preview), CTA "Essayer la démo" (filled) + "Accéder directement" (ghost).
- T7 : `app_router.dart` — `initialLocation: '/demo'`, 3 routes hors ShellRoute (`/demo`, `/demo/drill`, `/auth/register`), ShellRoute inchangé.
- T8 : 6 unit tests Riverpod passent, 3 widget tests DemoScreen passent, smoke test passe. `flutter analyze` → 0 erreur.

### File List

- `collega_app/lib/features/demo/domain/demo_data.dart` (créé)
- `collega_app/lib/features/demo/demo_providers.dart` (créé)
- `collega_app/lib/features/demo/presentation/widgets/demo_flash_card_widget.dart` (créé)
- `collega_app/lib/features/demo/presentation/widgets/demo_drill_evaluation_bar.dart` (créé)
- `collega_app/lib/features/demo/presentation/demo_drill_screen.dart` (créé)
- `collega_app/lib/features/demo/presentation/demo_screen.dart` (créé)
- `collega_app/lib/core/router/app_router.dart` (modifié)
- `collega_app/test/features/demo/demo_providers_test.dart` (créé)
- `collega_app/test/features/demo/demo_screen_test.dart` (créé)

### Change Log

- 2026-05-04 : Story 2.2 créée par create-story — démo interactive collège fictif
- 2026-05-04 : Story 2.2 implémentée — démo interactive collège fictif (T1→T8 complets, tous tests verts, flutter analyze 0 erreur)

### Review Findings

- [x] [Review][Decision] Stories 2.1 et 2.2 fusionnées dans ce diff — Résolution : séparer en 2 commits (commit 1 : app.dart + app_theme.dart + bottom_nav_bar.dart + pubspec pour Story 2.1 ; commit 2 : features/demo/ + app_router.dart + tests pour Story 2.2)

- [x] [Review][Patch] Badge "Rang A" hardcodé dans DemoDrillScreen — corrigé : `'Rang ${currentCard.rang}'` avec couleur dynamique [`demo_drill_screen.dart:52`]
- [x] [Review][Patch] Badge "Rang A" hardcodé dans DemoScreen — corrigé : `'Rang ${demoCollege.item.rang}'` avec couleur dynamique [`demo_screen.dart:52`]
- [x] [Review][Patch] evaluate() sans garde isComplete — corrigé : `if (state.isComplete) return;` ajouté en tête de méthode [`demo_providers.dart:43`]
- [x] [Review][Patch] Verso de la FlashCard affiché en miroir — corrigé : contre-rotation `Transform(rotateY(pi))` appliquée sur `_buildVerso()` [`demo_flash_card_widget.dart:94-102`]
- [x] [Review][Patch] Card non réinitialisée dans didUpdateWidget — corrigé : `if (widget.card != oldWidget.card) { _controller.value = 0.0; return; }` ajouté avant la condition isFlipped [`demo_flash_card_widget.dart:44`]
- [x] [Review][Patch] AnimationController non pré-initialisé quand isFlipped==true à la création — corrigé : `if (widget.isFlipped) _controller.value = 1.0;` dans initState [`demo_flash_card_widget.dart:39`]
- [x] [Review][Patch] État isComplete persistant sur re-navigation vers /demo/drill — corrigé : `NotifierProvider.autoDispose` + `AutoDisposeNotifier` [`demo_providers.dart:54`]

- [x] [Review][Defer] Redirect '/demo' redondant avec initialLocation '/demo' — dead code sans impact fonctionnel [`app_router.dart:11`] — deferred, pre-existing
- [x] [Review][Defer] Magic strings 'A_REVOIR'/'BIEN'/'MAITRISE' non encapsulées — tech debt intentionnel conforme à la spec, à extraire en enum/constantes dans une story de refactoring [`demo_providers.dart`] — deferred, pre-existing
- [x] [Review][Defer] Google Fonts sans `allowRuntimeFetching = false` — déjà présent dans deferred-work.md (review 2.1) — deferred, pre-existing

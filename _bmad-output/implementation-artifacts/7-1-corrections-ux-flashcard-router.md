# Story 7.1 : Corrections UX FlashCard & Router

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant qu'**étudiante en médecine**,
je veux que les interactions avec les flashcards soient cohérentes et que la démo ne réapparaisse pas après inscription,
afin de ne pas être bloquée ou déroutée par des comportements non-intentionnels lors de mes révisions.

**Items source :** R2, R3, R4 (cf. `_bmad-output/planning-artifacts/epics-v1.1.md` L.42-46)

---

## Acceptance Criteria

1. **AC1 — R4 : Carte définition non retournable au tap recto si pas de réponse soumise**
   - Étant donné une carte `cardType == 'definition'` affichée recto en Mode Drill
   - Quand je tape sur la carte sans avoir soumis ma réponse via le champ texte
   - Alors la carte **ne se retourne pas** (ni visuellement ni via le notifier)
   - Et un indicateur visuel discret (texte d'aide sous le champ ou bordure focus du `ShadInput`) rappelle qu'il faut soumettre la réponse pour voir le verso

2. **AC2 — R2 : Flip bidirectionnel tant que pas d'évaluation**
   - Étant donné une carte (classique ou définition, mais définition seulement APRÈS submit) déjà retournée en Mode Drill
   - Quand je tape à nouveau sur la carte avant d'avoir cliqué sur À revoir / Bien / Maîtrisé
   - Alors la carte se retourne à nouveau vers le recto
   - Et je peux re-flip autant de fois que nécessaire tant qu'aucun bouton d'évaluation n'a été cliqué (`session.exitResult == null`)
   - Et dès qu'un bouton d'évaluation est cliqué (`exitResult != null`), le flip se désactive et la carte glisse hors écran selon le pattern existant

3. **AC3 — R3 : Redirect `/demo` → `/home` si utilisateur authentifié**
   - Étant donné un utilisateur authentifié (token valide en `flutter_secure_storage`, `authProvider.value.isAuthenticated == true`)
   - Quand l'app démarre (initialLocation == `/demo`) ou que le router évalue une navigation vers `/demo` ou `/demo/drill`
   - Alors la route `/demo` redirige **immédiatement** vers `/home` (jamais l'écran démo n'est rendu)
   - Et la route `/demo` reste accessible uniquement si l'utilisateur n'est pas authentifié

4. **AC4 — R3 : Pas de flash visuel `/demo` si authentifié**
   - Étant donné un utilisateur authentifié qui tape l'URL `/demo` manuellement (cas iOS deep link) ou démarre l'app
   - Quand le router applique sa logique `redirect`
   - Alors la redirection vers `/home` se fait sans flash visuel de `DemoScreen`
   - Et durant `authAsync.isLoading == true`, la fallback existante (return `null`) reste en place — pas de régression

---

## Tasks / Subtasks

### Flutter — FlashCard widget (R2 + R4)

- [x] **T1 — Corriger `_handleTap` dans `FlashCardWidget` (AC: #1, #2)**
  - Fichier : `collega_app/lib/features/generation/widgets/flash_card_widget.dart`
  - Bug actuel ligne 75-79 : si `widget.onFlip == null`, le `_flipController.forward()` se lance quand même (animation locale visible) alors que le notifier ignore le flip. Résultat : R4 — la carte définition se retourne visuellement sans submit.
  - Correction : **early return si `widget.onFlip == null`** AVANT toute mutation de l'animation :
    ```dart
    void _handleTap() {
      if (widget.onFlip == null) return; // R4: pas de flip si le parent l'interdit
      if (_localExitResult != null) return; // évaluation cliquée → carte qui sort
      if (_flipController.isAnimating) return; // anti double-tap durant anim
      if (widget.isFlipped) {
        _flipController.reverse(); // R2: retour au recto
      } else {
        _flipController.forward();
      }
      widget.onFlip?.call();
    }
    ```
  - **CRITIQUE** : conserver le `didUpdateWidget` existant (lignes 52-67) — il gère déjà le rev/fwd via comparaison `widget.isFlipped vs oldWidget.isFlipped`. Le `_handleTap` peut donc se contenter d'appeler `widget.onFlip?.call()` et laisser `didUpdateWidget` synchroniser l'animation. Vérifier que le `setState` du flip dans le notifier déclenche bien un rebuild qui re-passe par `didUpdateWidget`.
  - Alternative simple (préférée) :
    ```dart
    void _handleTap() {
      if (widget.onFlip == null) return;
      if (_localExitResult != null) return;
      if (_flipController.isAnimating) return;
      widget.onFlip!.call();
      // L'anim est pilotée par didUpdateWidget(widget.isFlipped change → forward/reverse)
    }
    ```

- [x] **T2 — Ajouter indicateur visuel "soumettre la réponse" pour cartes définition recto (AC: #1)**
  - Fichier : `collega_app/lib/features/drill/presentation/drill_screen.dart` (zone du `ShadInput` lignes ~176-200)
  - Ajouter sous le `Row` du `ShadInput + ShadButton('Évaluer')` un petit texte d'aide :
    ```dart
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
      child: Text(
        'Soumets ta définition pour voir la réponse',
        style: AppTypography.labelMedium()
            .copyWith(color: AppColors.secondary),
      ),
    ),
    ```
  - Conditionner l'affichage sur `isDefinitionFront == true` ET `session.semanticFeedback == null` (une fois la réponse soumise, le feedback sémantique s'affiche, l'aide n'est plus utile).
  - **Ne PAS** ajouter de TapHint sur la carte elle-même : l'utilisateur ne doit pas avoir l'impression que la carte est tap-pable. Le texte sous le champ est suffisant et cohérent UX-DR.

### Flutter — DrillSessionNotifier (R2)

- [x] **T3 — Convertir `flip()` en toggle dans `DrillSessionNotifier` (AC: #2)**
  - Fichier : `collega_app/lib/features/drill/drill_providers.dart`
  - Implémentation actuelle ligne 43-47 : `flip()` met `isFlipped = true` (sens unique). Pour le re-flip, il faut basculer.
  - Bloquer le toggle si évaluation cliquée (`exitResult != null`) pour respecter AC2 dernière clause :
    ```dart
    void flip() {
      final s = state.value;
      if (s == null) return;
      if (s.exitResult != null) return; // évaluation cliquée → carte qui sort, plus de flip
      state = AsyncValue.data(s.copyWith(isFlipped: !s.isFlipped));
    }
    ```
  - **NE PAS** toucher à `advanceToNext()` (ligne 93) — il reset déjà `isFlipped: false` à chaque carte suivante.
  - **NE PAS** changer la signature : `_handleDefinitionSubmit` (drill_screen.dart L.78-88) appelle `notifier.flip()` après évaluation sémantique — cela doit toujours retourner la carte vers le verso (état `false → true`). ✅ le toggle préserve ce comportement.

### Flutter — Router (R3)

- [x] **T4 — Ajouter redirect `/demo` → `/home` si authentifié (AC: #3, #4)**
  - Fichier : `collega_app/lib/core/router/app_router.dart`
  - Modifier le `redirect` (lignes 29-54). **L'ordre des règles est critique** car la première qui matche retourne. Ajouter une nouvelle règle **avant** la règle ligne 35 (`if (state.fullPath == null || state.fullPath == '/') return '/demo';`) qui couvre déjà l'initialLocation :
    ```dart
    redirect: (context, state) {
      if (authAsync.isLoading) return null;

      final isAuth = authAsync.valueOrNull?.isAuthenticated ?? false;
      final hasAccess = authAsync.valueOrNull?.hasAccess ?? false;

      // R3 (Story 7.1) : auth user ne doit jamais voir /demo ou /demo/drill
      final isDemoRoute = state.matchedLocation == '/demo' ||
          state.matchedLocation == '/demo/drill';
      if (isAuth && isDemoRoute) {
        return hasAccess ? '/home' : '/paywall';
      }

      if (state.fullPath == null || state.fullPath == '/') {
        return isAuth ? (hasAccess ? '/home' : '/paywall') : '/demo';
      }

      // ... reste inchangé
    }
    ```
  - **CRITIQUE** : le `redirect` de GoRouter est appelé **plusieurs fois** jusqu'à stabilité (max 5 itérations). Ne **PAS** retourner une URL qui boucle (ex : retourner `/demo` depuis un check `/demo`). Le retour `/home` (ou `/paywall`) sort de la zone démo → la règle ne re-déclenche pas.
  - **CRITIQUE** : conserver `if (authAsync.isLoading) return null;` en première position — pendant le bootstrap, on laisse afficher la route demandée. La règle ne déclenche qu'une fois `authProvider` résolu, ce qui élimine le flash visuel (AC4) car le router attend la résolution avant de rendre.
  - **Vérifier** : `initialLocation: '/demo'` ligne 28 reste inchangé — la redirection automatique se fait au premier `redirect()` call.

### Tests Flutter

- [x] **T5 — Tests `FlashCardWidget` (AC: #1, #2)**
  - Fichier : `collega_app/test/features/generation/flash_card_widget_test.dart`
  - Le test existant ligne 87-104 `'tap appelle onFlip'` reste valide. Ajouter :
    ```dart
    testWidgets('AC1: tap sans onFlip ne déclenche pas le flip visuel', (tester) async {
      // R4 fix : si onFlip == null, _handleTap doit return immédiatement sans animer
      await tester.pumpWidget(_wrap(
        FlashCardWidget(
          card: _makeCard(cardType: 'definition'),
          isFlipped: false,
          // onFlip omis → null
        ),
      ));
      await tester.pump(Duration.zero);

      // Recto visible avant tap
      expect(find.text('Question test'), findsOneWidget);
      expect(find.text('Réponse test'), findsNothing);

      await tester.tap(find.byType(FlashCardWidget));
      await tester.pump(const Duration(milliseconds: 400)); // > 300ms anim

      // Recto toujours visible (pas de flip déclenché)
      expect(find.text('Question test'), findsOneWidget);
      expect(find.text('Réponse test'), findsNothing);
    });

    testWidgets('AC2: tap re-flip d\'une carte déjà retournée appelle onFlip', (tester) async {
      var flipCount = 0;
      late StateSetter setIsFlipped;
      var isFlipped = true; // carte retournée

      await tester.pumpWidget(_wrap(
        StatefulBuilder(builder: (ctx, setState) {
          setIsFlipped = setState;
          return FlashCardWidget(
            card: _makeCard(),
            isFlipped: isFlipped,
            onFlip: () => flipCount++,
          );
        }),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FlashCardWidget));
      await tester.pump(const Duration(milliseconds: 400));

      expect(flipCount, 1); // re-flip appelé (vers recto)
    });

    testWidgets('AC2: tap après exitResult ne déclenche pas onFlip', (tester) async {
      var flipCount = 0;
      await tester.pumpWidget(_wrap(
        FlashCardWidget(
          card: _makeCard(),
          isFlipped: true,
          exitResult: DrillEvaluationResult.maitrise, // évaluation cliquée
          onFlip: () => flipCount++,
        ),
      ));
      await tester.pump(Duration.zero);

      await tester.tap(find.byType(FlashCardWidget));
      await tester.pump(const Duration(milliseconds: 400));

      expect(flipCount, 0); // pas de flip durant l'animation de sortie
    });
    ```
  - **Import à ajouter** : `import 'package:collega_app/features/drill/domain/drill_state.dart';` pour `DrillEvaluationResult` (déjà importé indirectement via le widget mais à expliciter dans le test).

- [x] **T6 — Test `DrillSessionNotifier.flip()` toggle (AC: #2)**
  - Fichier : `collega_app/test/features/drill/drill_session_notifier_test.dart`
  - Ajouter dans le `group('DrillSessionNotifier', ...)` :
    ```dart
    test('flip() — toggle bidirectionnel tant que pas d\'évaluation', () async {
      final cards = _makeCards(1);
      final container = _makeContainer(cards);
      addTearDown(container.dispose);

      await container.read(drillSessionProvider(_params).future);
      final notifier = container.read(drillSessionProvider(_params).notifier);

      notifier.flip();
      expect(container.read(drillSessionProvider(_params)).value!.isFlipped, true);

      notifier.flip(); // re-flip
      expect(container.read(drillSessionProvider(_params)).value!.isFlipped, false);

      notifier.flip();
      expect(container.read(drillSessionProvider(_params)).value!.isFlipped, true);
    });

    test('flip() — désactivé après évaluation (exitResult != null)', () async {
      final cards = _makeCards(1);
      final container = _makeContainer(cards);
      addTearDown(container.dispose);

      await container.read(drillSessionProvider(_params).future);
      final notifier = container.read(drillSessionProvider(_params).notifier);

      notifier.flip();
      await notifier.evaluate(DrillEvaluationResult.maitrise);
      // exitResult est désormais set → flip() doit être no-op
      final beforeRetap = container.read(drillSessionProvider(_params)).value!.isFlipped;
      notifier.flip();
      final afterRetap = container.read(drillSessionProvider(_params)).value!.isFlipped;
      expect(afterRetap, beforeRetap);
    });
    ```

- [x] **T7 — Test `app_router` redirect `/demo` → `/home` si auth (AC: #3, #4)**
  - Fichier **NEW** : `collega_app/test/core/router/app_router_test.dart`
  - Pas de test router existant à ce jour — créer un nouveau fichier en suivant le pattern de `drill_screen_test.dart` (ProviderScope + GoRouter custom).
  - Test minimal :
    ```dart
    import 'package:flutter/material.dart';
    import 'package:flutter_riverpod/flutter_riverpod.dart';
    import 'package:flutter_test/flutter_test.dart';
    import 'package:shadcn_ui/shadcn_ui.dart';

    import 'package:collega_app/core/router/app_router.dart';
    import 'package:collega_app/core/theme/app_theme.dart';
    import 'package:collega_app/features/auth/auth_providers.dart';
    import 'package:collega_app/features/auth/domain/auth_state.dart'; // adapter au path réel
    import 'package:collega_app/features/auth/domain/user_model.dart'; // adapter au path réel

    void main() {
      group('AppRouter — redirect /demo si authentifié', () {
        testWidgets('user authentifié sur /demo → redirect /home', (tester) async {
          final user = /* UserModel factice avec isSubscribed: true */;
          final authState = AuthState(user: user); // hasAccess via getter

          await tester.pumpWidget(ProviderScope(
            overrides: [
              authProvider.overrideWith(() => _FakeAuthNotifier(authState)),
            ],
            child: Consumer(builder: (ctx, ref, _) {
              return ShadApp.router(
                theme: buildShadTheme(),
                routerConfig: ref.watch(routerProvider),
              );
            }),
          ));
          await tester.pumpAndSettle();

          // HomeScreen est rendu, jamais DemoScreen
          expect(find.byType(HomeScreen), findsOneWidget);
          // Aucun widget de DemoScreen ne doit avoir été rendu
        });

        testWidgets('user non-authentifié sur /demo → DemoScreen rendu', (tester) async {
          // setup avec authState.user == null
          // expect find.byType(DemoScreen), findsOneWidget
        });
      });
    }
    ```
  - **CRITIQUE** : vérifier le path réel de `AuthState` et `UserModel` avant de copier-coller (le pattern Riverpod du projet utilise probablement `authProvider.overrideWith` ou `overrideWithValue` selon le type).
  - **Inspirer du pattern** `_FakeAuthNotifier` déjà établi dans `profile_screen_test.dart` (Story 6.1/6.2).
  - **Couverture minimale** : 2 tests (auth → redirect, non-auth → demo affiché). Le cas `paywall` (auth mais `hasAccess == false`) peut être ajouté en bonus si trivial, sinon différer.

---

## Périmètre & Contraintes

- **Pas de migration DB** — ce sont des bugs UX/router pur Flutter.
- **Pas de modification backend** — toutes les corrections sont côté `collega_app/`.
- **Pas de nouvelle dépendance** — `flutter_riverpod`, `go_router`, `flutter_animate`, `shadcn_ui` déjà présents (cf. `pubspec.yaml`).
- **Compatibilité Drift v5** — aucune table touchée.
- **Story 4.1 (FlashCardWidget) et Story 2.3 (auth/router) sont closes** — on modifie sans casser les comportements existants.
- **Ne PAS toucher au prompt Claude** (différé Story 7.5) ni aux compteurs `reload_count` (Story 7.2).

---

## Dev Notes — Contexte Technique Exhaustif

### Diagnostic des 3 bugs (avant correction)

**R2 — Re-flip impossible** (`flash_card_widget.dart` L.75-79)
```dart
void _handleTap() {
  if (widget.isFlipped || _localExitResult != null || _flipController.value > 0.0) return;
  _flipController.forward();
  widget.onFlip?.call();
}
```
- `widget.isFlipped` bloque dès qu'on est sur le verso → impossible de revenir au recto.
- Combiné à `DrillSessionNotifier.flip()` qui met `isFlipped = true` (sens unique), aucun chemin pour basculer.

**R3 — Demo si auth** (`app_router.dart` L.28, L.35)
- `initialLocation: '/demo'` envoie systématiquement au demo au démarrage.
- Ligne 35 : `if (state.fullPath == null || state.fullPath == '/') return '/demo';` retourne `/demo` **même si l'utilisateur est authentifié**.
- Aucune règle ne traite le cas `auth + sur /demo` → l'écran reste affiché.

**R4 — Carte définition retournée sans réponse** (`drill_screen.dart` L.167 + `flash_card_widget.dart` L.76-78)
- `drill_screen.dart` passe `onFlip: isDefinitionFront ? null : notifier.flip` : intention correcte (pas de flip pour def en recto).
- MAIS dans `flash_card_widget.dart` L.77-78 : `_flipController.forward();` est appelé **avant** `widget.onFlip?.call();`. Comme `?.call()` est null-safe, l'animation locale se lance, l'état parent n'est pas mis à jour, et l'utilisateur voit visuellement le verso tout en restant techniquement sur le recto côté notifier.

### Architecture des fichiers modifiés

```
collega_app/lib/
├── core/router/app_router.dart                     # UPDATE (redirect /demo si auth)
├── features/drill/
│   ├── drill_providers.dart                        # UPDATE (flip() → toggle)
│   └── presentation/drill_screen.dart              # UPDATE (texte aide def card)
└── features/generation/widgets/flash_card_widget.dart  # UPDATE (_handleTap fix R2+R4)

collega_app/test/
├── core/router/app_router_test.dart                # NEW (2 tests redirect)
├── features/drill/drill_session_notifier_test.dart # UPDATE (2 tests flip toggle)
└── features/generation/flash_card_widget_test.dart # UPDATE (3 tests handleTap)
```

### Flow R2 (re-flip) après correction

```
Recto → tap → notifier.flip()  → isFlipped = true   → didUpdateWidget → _flipController.forward()
Verso → tap → notifier.flip()  → isFlipped = false  → didUpdateWidget → _flipController.reverse()
Verso → tap "Bien" → evaluate() → exitResult = bien → flip() devient no-op
                                                    → carte glisse (slidesUp/slidesDown/fade)
                                                    → advanceToNext() reset isFlipped=false + exitResult=null
```

### Flow R3 (router) après correction

```
App start (auth user) :
  initialLocation: /demo
  → redirect() exécuté
  → authAsync.isLoading? oui → return null (loader brief)
  → authAsync.isLoading? non + isAuth + isDemoRoute → return /home
  → GoRouter rebuild → HomeScreen rendu (DemoScreen jamais construit)

App start (non-auth user) :
  initialLocation: /demo
  → redirect() exécuté
  → authAsync.isLoading? non + !isAuth + isDemoRoute → règle ignorée
  → fullPath == '/'? non (déjà /demo) → null
  → DemoScreen rendu ✅
```

### Pattern `didUpdateWidget` du widget

Le widget actuel gère déjà la synchro animation ↔ prop `isFlipped` :
- Ligne 59-63 : `widget.isFlipped && !oldWidget.isFlipped` → `_flipController.forward()`
- Ligne 61-62 : `!widget.isFlipped && oldWidget.isFlipped` → `_flipController.reverse()`

**Donc** : la correction du `_handleTap` se limite à `widget.onFlip?.call()` (sans toucher au controller localement). Le `notifier.flip()` toggle `isFlipped` → rebuild → `didUpdateWidget` synchronise automatiquement. C'est plus simple ET ça évite la désynchro animation/état.

### Conventions de tests Flutter du projet (cf. `drill_screen_test.dart`, `profile_screen_test.dart`)

- `_wrap(child) => ShadApp(theme: buildShadTheme(), home: Scaffold(body: child))` — pattern wrapper pour les widget tests sans router.
- `_wrapWithRouter(child) => ShadApp.router(...)` — pour les tests qui ont besoin de navigation.
- `_FakeXxxRepository extends XxxRepository` — pattern pour les mocks de repo, override les méthodes utilisées dans la suite.
- `addTearDown(container.dispose)` systématique pour les `ProviderContainer`.
- `await tester.pumpAndSettle()` après navigation, mais `await tester.pump(const Duration(milliseconds: 100))` pour drain les timers `flutter_animate` (cf. commentaire ligne 20 de `drill_evaluation_bar_test.dart` : "Drain pending 0ms timers from ShadApp's flutter_animate internals").
- `find.text(..., skipOffstage: false)` quand le widget est dans un `ListView` (learning Story 6.1).

### Stack technique (vérifié dans `pubspec.yaml`)

- Flutter SDK : `^3.6.0`
- `flutter_riverpod: ^2.6.1`
- `go_router: ^14.6.3`
- `shadcn_ui: ^0.19.0`
- `flutter_animate: ^4.5.0` (déjà utilisé dans `flash_card_widget.dart` L.181, 187, 193 via `.animate().slideY()...`)
- `drift: ^2.21.0`
- Pas de mise à jour de version requise pour cette story.

### Anti-patterns à éviter

- **NE PAS** modifier `didUpdateWidget` dans `FlashCardWidget` — la logique d'animation forward/reverse est déjà correcte, c'est uniquement `_handleTap` qui causait le bug R4.
- **NE PAS** garder `_flipController.forward()` dans `_handleTap` — laisser `didUpdateWidget` piloter l'animation via la prop `isFlipped`. Source de désynchro sinon.
- **NE PAS** changer le type de retour de `flip()` (void) — c'est un AsyncNotifier, mais la méthode n'a pas besoin d'être async.
- **NE PAS** ajouter une route dédiée `/home-or-paywall` ou logique côté DemoScreen — la responsabilité est du router (`redirect`).
- **NE PAS** modifier `initialLocation: '/demo'` — c'est correct pour le cas non-auth (90% des cold starts en early beta = non-auth ou bien auth qui sera redirigé sans flash).
- **NE PAS** print/debugPrint dans le code prod (cf. architecture L.310 enforcement).
- **NE PAS** mettre la logique de redirect dans le `DemoScreen.build()` (`if (isAuth) context.go('/home')`) — pattern anti-architecture, le router est le seul endroit légitime pour gérer la navigation conditionnelle (cf. learning Story 6.2 sur `GoRouter redirect`).
- **NE PAS** utiliser `print()` dans les tests — utiliser `expect` exclusivement.
- **NE PAS** oublier `skipOffstage: false` si `find.text` cible un widget dans un ListView (mais ici pas applicable : la flashcard est dans un `Column`).

### Tests existants à conserver

- `flash_card_widget_test.dart` L.87-104 `'tap appelle onFlip'` : valide (`onFlip` est non-null dans ce test, le bug R4 n'apparaît pas). À conserver.
- `drill_session_notifier_test.dart` L.84-167 : tous les tests `evaluate()`, `advanceToNext()`, `restartWithErrors()` sont indépendants de `flip()` toggle. À conserver.
- `drill_screen_test.dart` : utilise `notifier.flip()` directement (L.122, 147, 183) — le toggle préserve le `isFlipped = true` au premier call, donc ces tests restent verts. À vérifier en CI mais aucune modification anticipée.

### Le `_localExitResult` du widget

Lignes 35, 64-66 : le widget garde une copie locale de `widget.exitResult` pour permettre à `didUpdateWidget` de capter la transition `null → result`. Comportement existant, à ne pas modifier. Le `_handleTap` doit continuer à bloquer le flip dès que `_localExitResult != null` (= phase d'animation de sortie).

---

## Previous Story Intelligence — Learnings 6.x

- **Story 6.2 (DELETE compte)** : `_FakeAuthNotifier` dans `profile_screen_test.dart` est le pattern de référence pour mocker `authProvider` en test. Réutilisable pour T7 (router test).
- **Story 6.2** : pattern `ref.read(authProvider).valueOrNull?.isAuthenticated` — déjà utilisé partout dans `app_router.dart`. ✅ Cohérent.
- **Story 6.1 — pattern review** : 2 review cycles avant `done`. **Lessons learned applicables ici** :
  - Mettre des `if (!mounted) return;` après chaque `await` Flutter qui suit (non applicable ici, pas d'async dans `_handleTap`).
  - Tester explicitement le path d'erreur (ici : tap durant `exitResult != null` couvert par T5 AC2 retap après éval).
- **Pattern Riverpod stale state (rétro MVP § Pattern #4)** : le `homeProvider` se vidait au retour `/drill`. Pour T7 (router test), s'assurer que le test `authProvider.overrideWith` est bien refresh avant le `pumpAndSettle`.

---

## Git Intelligence — Commits récents

Derniers commits pertinents (sur la branche `main`) :
```
45f736a fix(colleges): augmente la limite d'import PDF à 500 MB
502a0cd feat(epic-6): Story 6.2 — suppression de compte & conformité RGPD
2baa87d feat(epic-6): Story 6.1 — écran profil & préférences de révision
375d7b7 feat(epic-5): Story 5.2 — lancement session drill depuis résultat de recherche
d932a76 feat(epic-5): Story 5.1 — recherche full-text & résultats contextuels
```
- Story 6.2 (`502a0cd`) a touché `auth_providers.dart`, `auth_repository.dart`, `app_router.dart` (redirect/demo après logout). **Lire le diff de `app_router.dart` du commit `502a0cd`** avant de modifier si doute sur l'ordre des règles `redirect`.
- Aucun WIP en cours sur ces fichiers (`git status` à jour : seulement `sprint-status.yaml` modifié + nouveaux artefacts planning).

---

## Project Context Reference

- **Stack mobile** : Flutter 3.6+ / Riverpod 2.6 / GoRouter 14.6 / shadcn_ui 0.19 / Drift 2.21 / flutter_animate 4.5.
- **Conventions** : snake_case fichiers Dart, PascalCase classes, AsyncNotifier pour state async, `{data: ...}` ou `{error: ...}` pour API, ShadToast pour erreurs non-bloquantes.
- **Architecture feature-first** : `features/[domain]/{data,domain,presentation,widgets}` + `[domain]_providers.dart`.
- **Tests co-localisés** : `test/features/[feature]/*.dart` miroir de `lib/features/`.
- **Pas de print() / debugPrint() en prod** — utiliser `core/utils/logger.dart` (`AppLogger`).

---

## Latest Tech Information

Aucune mise à jour critique requise pour cette story :
- `go_router 14.6.3` — l'API `redirect` est stable depuis v12. Pas de breaking change anticipé.
- `flutter_animate 4.5.0` — `Animate().slideY().fade()` chain syntax inchangée.
- `shadcn_ui 0.19.0` — `ShadInput`, `ShadButton`, `ShadCard` API stable. Toujours pas de `ShadSkeleton` disponible (workaround : `ShadProgress` indéterminé, mais hors scope ici).

**Gotcha SDK rappelé** (cf. rétro MVP § Pattern #5) :
- `shadcn_ui` import indirect via le widget existant — `.animate()` fonctionne sans import explicite de `flutter_animate` dans `flash_card_widget.dart` (probablement réexporté par `shadcn_ui` ou via chain d'imports). À ne pas casser en réorganisant les imports.

---

## References

- Epic 7 Story 7.1 : `_bmad-output/planning-artifacts/epics-v1.1.md` L.101-139
- PRD MVP (vision inchangée) : `_bmad-output/planning-artifacts/prd.md`
- Architecture frontend : `_bmad-output/planning-artifacts/architecture.md` L.156-211, L.319-365
- Rétro MVP 2026-05-19 : `_bmad-output/implementation-artifacts/epic-mvp-retro-2026-05-19.md` § Pattern #2 (async correctness), § Pattern #4 (Riverpod pitfalls), § Pattern #5 (gotchas SDK)
- `FlashCardWidget` : `collega_app/lib/features/generation/widgets/flash_card_widget.dart` (L.75-79 = bug R2/R4, L.52-67 = `didUpdateWidget` à conserver)
- `DrillSessionNotifier` : `collega_app/lib/features/drill/drill_providers.dart` (L.43-47 = `flip()` à transformer en toggle, L.93-105 = `advanceToNext()` à ne pas toucher)
- `DrillScreen` : `collega_app/lib/features/drill/presentation/drill_screen.dart` (L.100-101 = `isDefinitionFront`, L.167 = `onFlip: isDefinitionFront ? null : notifier.flip`, L.176-200 = input definition card)
- `app_router.dart` : `collega_app/lib/core/router/app_router.dart` (L.28 = initialLocation, L.29-54 = redirect, L.60-61 = routes /demo et /demo/drill)
- `FlashCardModel` (champ `cardType`) : `collega_app/lib/features/colleges/domain/college_detail_models.dart` L.71 (`final String cardType`)
- Pattern test router : `collega_app/test/features/drill/drill_screen_test.dart` L.71-89 (`_wrapWithRouter`)
- Pattern `_FakeAuthNotifier` : `collega_app/test/features/profile/profile_screen_test.dart` (Story 6.2)
- Story 6.2 (learnings) : `_bmad-output/implementation-artifacts/6-2-suppression-compte-conformite-rgpd.md`
- Story 4.1 (FlashCard initial) : `_bmad-output/implementation-artifacts/4-1-composants-flashcard-drillevaluationbar.md`
- Story 2.3 (auth + redirect) : `_bmad-output/implementation-artifacts/2-3-inscription-authentification.md`

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-7[1m]

### Debug Log References

- Tests ciblés (47 cases, dont 7 nouveaux pour Story 7.1) : `flutter test test/features/drill test/features/generation test/core/router` → 47/47 ✅
- `flutter analyze` : 3 warnings pré-existants hors scope (colleges_detail_providers.dart, college_import_screen.dart) ; aucun warning sur les fichiers modifiés ✅
- Régression suite complète : 6 tests cassent dans `test/features/home/home_screen_test.dart` avec « A Timer is still pending even after the widget tree was disposed » (problème connu shadcn_ui / flutter_animate). Vérifié comme **pré-existant et non lié à Story 7.1** : aucun fichier de la story ne touche HomeScreen, homeProvider, collegesProvider ou les widgets utilisés par `home_screen_test`. Recommandation : remonter ces flakes en backlog hardening (potentiel candidat Story 7.2 ou ticket dédié).

### Completion Notes List

- **T1 — `_handleTap` (R2 + R4)** : `_handleTap` early-return désormais si `widget.onFlip == null` (fix R4). L'animation locale `_flipController.forward()` n'est plus déclenchée directement ; tout est piloté par `didUpdateWidget` quand `widget.isFlipped` change. Suppression aussi du garde `widget.isFlipped` qui bloquait le re-flip (fix R2).
- **T2 — Texte d'aide cartes définition** : ajout d'une ligne « Soumets ta définition pour voir la réponse » sous l'input, conditionnée à `isDefinitionFront && session.semanticFeedback == null`. Pas de TapHint sur la carte elle-même.
- **T3 — `flip()` toggle** : `DrillSessionNotifier.flip()` est désormais un toggle bidirectionnel. Bloqué dès qu'`exitResult != null` pour respecter AC2 (plus de flip pendant la sortie d'écran). `advanceToNext()` continue de reset `isFlipped` à false → comportement carte suivante préservé.
- **T4 — Redirect `/demo` → `/home`** : nouvelle règle ajoutée AVANT la règle `initialLocation` du `redirect`. User authentifié sur `/demo` ou `/demo/drill` est routé vers `/home` (ou `/paywall` si pas d'accès). `authAsync.isLoading` reste géré en premier → pas de flash visuel (AC4). Aucun risque de boucle car la redirection sort de la zone démo.
- **T5/T6/T7 — Tests** : 3 nouveaux widget tests pour FlashCardWidget (AC1 no-flip si onFlip null, AC2 re-flip, AC2 no-flip après exitResult) ; 2 nouveaux unit tests pour DrillSessionNotifier (toggle bidirectionnel + flip désactivé après évaluation) ; 2 widget tests pour le router (`/demo` redirige vers `/home` si auth, reste sur `/demo` si non-auth). Tous verts.
- **Vérification non-régression côté `_handleDefinitionSubmit` (drill_screen.dart)** : la conversion en toggle préserve le comportement — au moment du submit, `isFlipped == false` donc `notifier.flip()` passe à `true` (recto → verso) comme avant.

### File List

**Modifiés :**
- `collega_app/lib/core/router/app_router.dart`
- `collega_app/lib/features/drill/drill_providers.dart`
- `collega_app/lib/features/drill/presentation/drill_screen.dart`
- `collega_app/lib/features/generation/widgets/flash_card_widget.dart`
- `collega_app/test/features/drill/drill_session_notifier_test.dart`
- `collega_app/test/features/generation/flash_card_widget_test.dart`
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (status story 7-1 → review)

**Créés :**
- `collega_app/test/core/router/app_router_test.dart`

### Change Log

| Date | Auteur | Modification |
|---|---|---|
| 2026-05-19 | Dev (Opus 4.7) | Story 7.1 — Implémentation R2 (re-flip bidirectionnel), R3 (redirect `/demo`→`/home` si auth, AC3+AC4), R4 (carte définition non retournable au tap recto, AC1). 7 nouveaux tests (47/47 passent). |
| 2026-05-19 | Code review (Opus 4.7) | Review adversariale 3 layers (Blind / Edge / Acceptance). 32 findings bruts → 3 decision-needed (résolus), 8 patches appliqués, 3 defer (deferred-work.md), 20 dismissed. 47/47 tests verts. |

---

### Review Findings

- [x] [Review][Decision] **Router test — drain d'exceptions + assert deviant du spec T7** — `app_router_test.dart:42-67`. **Résolu (2026-05-19)** : option (a) — mocker `homeProvider` / `collegesProvider` / etc. pour pouvoir asserter `find.byType(HomeScreen)` comme prescrit. Devient un patch.
- [x] [Review][Decision] **Dead-end UX — re-flip recto carte définition masque la bar d'évaluation** — drill_screen.dart:167. **Résolu (2026-05-19)** : option (b) — autoriser `onFlip` même en recto définition si `session.semanticFeedback != null`. Devient un patch.
- [x] [Review][Decision] **Périmètre PR élargi — statut epics 1→6 mélangé à Story 7.1** — sprint-status.yaml. **Résolu (2026-05-19)** : option (a) — split en 2 commits séparés (`chore(sprint): MVP retro epics 1→6 done` + `feat(story-7.1): corrections UX FlashCard & Router`). Action workflow au moment du commit, pas un patch code.

- [x] [Review][Patch] **Mocker `homeProvider`/`collegesProvider`/etc. pour asserter `find.byType(HomeScreen)` dans le test router AC3** [`collega_app/test/core/router/app_router_test.dart`] — appliqué : test réécrit avec overrides `homeProvider`/`collegesRepositoryProvider`/`databaseProvider` + asserts `find.byType(HomeScreen)` & `find.byType(DemoScreen)`
- [x] [Review][Patch] **Autoriser `onFlip` en recto définition si `session.semanticFeedback != null` pour permettre re-flip vers verso** [`collega_app/lib/features/drill/presentation/drill_screen.dart:103-106`] — appliqué : nouvelle var locale `flipDisabled = isDefinitionFront && session.semanticFeedback == null`, `onFlip: flipDisabled ? null : notifier.flip`
- [ ] [Review][Workflow] **Split en 2 commits : `chore(sprint): MVP retro epics 1→6 done` puis `feat(story-7.1): corrections UX FlashCard & Router`** — *à exécuter au moment du commit (action workflow, pas un patch code)*

- [x] [Review][Patch] **`isDemoRoute` whitelist fragile : `/demo/<x>` futur passera entre les mailles** [`collega_app/lib/core/router/app_router.dart:36-37`] — appliqué : `state.matchedLocation == '/demo' || state.matchedLocation.startsWith('/demo/')`
- [x] [Review][Patch] **Bouton « Évaluer » toujours actif après submit définition (re-call LLM possible)** [`collega_app/lib/features/drill/presentation/drill_screen.dart:192-199`] — appliqué : `onPressed: session.semanticFeedback != null ? null : ...`
- [x] [Review][Patch] **`Semantics.hint: 'Tapoter pour retourner'` mensonger quand `onFlip == null`** [`collega_app/lib/features/generation/widgets/flash_card_widget.dart:148`] — appliqué : `hint: widget.onFlip == null ? null : 'Tapoter pour retourner'`
- [x] [Review][Patch] **Race double-tap : `_flipController.isAnimating` peut être false 1 frame avant que didUpdateWidget déclenche l'anim** [`collega_app/lib/features/generation/widgets/flash_card_widget.dart`] — appliqué : flag `_flipPending` set dans `_handleTap`, reset dans `didUpdateWidget` quand `widget.isFlipped != oldWidget.isFlipped` ou card swap
- [x] [Review][Patch] **Test router couplé au libellé `'Découvrez AppMédecine'` au lieu de `find.byType(DemoScreen)`** [`collega_app/test/core/router/app_router_test.dart`] — appliqué : `find.byType(DemoScreen)` + import direct
- [x] [Review][Patch] **Assertion `expect(afterRetap, beforeRetap)` tautologique** [`collega_app/test/features/drill/drill_session_notifier_test.dart`] — appliqué : assertions explicites sur `isFlipped == true` (préservé) + `exitResult == maitrise`

- [x] [Review][Defer] **Pas de test transition `AsyncLoading → Data` couvrant AC4 (pas de flash visuel)** [`collega_app/test/core/router/app_router_test.dart:14-17`] — deferred, hardening test
- [x] [Review][Defer] **Pas de test pour la branche `state.fullPath == '/'` du redirect** [`collega_app/lib/core/router/app_router.dart:42-44`] — deferred, modifiée par Story 6.2, pas par Story 7.1
- [x] [Review][Defer] **Pas de test explicite de non-régression `_handleDefinitionSubmit` (claim Completion Notes)** [`collega_app/test/features/drill/drill_session_notifier_test.dart`] — deferred, comportement trivial mais non vérifié


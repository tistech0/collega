# Story 4.1 : Composants FlashCard & DrillEvaluationBar [Technical Foundation]

Status: done

> Story de fondation technique — composants réutilisables requis par Story 4.2. Aucune valeur utilisateur directe.

## Story

En tant que **développeur**,
je veux que les composants `FlashCard` et `DrillEvaluationBar` soient implémentés et testés de façon isolée,
afin que le Mode Drill puisse les assembler sans reconstruire la logique d'interaction.

## Acceptance Criteria

1. **FlashCard recto — badge rang + OcrConfidenceBadge (AC1)**
   - Étant donné le composant `FlashCard` rendu en état recto
   - Quand il s'affiche
   - Alors la question s'affiche en `AppTypography.titleMedium()` centré
   - Et le badge rang A/B/C est en haut à droite (`ShadBadge`) : vert (`AppColors.primary`) / teal (`AppColors.secondary`) / gris neutre (`Color(0xFF6B7C6E)`)
   - Et si la fiche a `lowConfidence == true`, le `OcrConfidenceBadge` est visible en superposition

2. **Animation de retournement < 300ms (AC2)**
   - Étant donné que l'utilisateur tape sur la `FlashCard`
   - Quand le retournement se déclenche
   - Alors l'animation s'exécute en < 300ms (AnimationController 300ms + Transform.rotateY, pattern identique à `DemoFlashCardWidget`)
   - Et la réponse (`verso`) s'affiche en état verso
   - Et la `DrillEvaluationBar` apparaît sous la card (invisible avant retournement via `AnimatedOpacity`)

3. **DrillEvaluationBar — 3 boutons + feedback haptique (AC3)**
   - Étant donné la `DrillEvaluationBar` visible (après retournement)
   - Quand elle est rendue
   - Alors 3 boutons sont empilés verticalement pleine largeur :
     - "À revoir" → `ShadButton.destructive`
     - "Bien" → `ShadButton.outline` avec `foregroundColor: AppColors.secondary`
     - "Maîtrisé" → `ShadButton` filled primary
   - Et `HapticFeedback.lightImpact()` se déclenche au tap sur chacun

4. **Animation de sortie "Maîtrisé" → vers le haut (AC4)**
   - Étant donné le tap sur "Maîtrisé"
   - Quand l'animation de sortie se déclenche
   - Alors la card disparaît vers le haut : `cardWidget.animate().slideY(end: -1.5, duration: 250.ms).fade(end: 0)`

5. **Animation de sortie "À revoir" → vers le bas (AC5)**
   - Étant donné le tap sur "À revoir"
   - Quand l'animation de sortie se déclenche
   - Alors la card disparaît vers le bas : `cardWidget.animate().slideY(end: 1.5, duration: 250.ms).fade(end: 0)`

6. **Variant définition — même comportement (AC6)**
   - Étant donné le variant `définition` (cardType == 'definition')
   - Quand il est utilisé
   - Alors le recto affiche un terme médical, le verso la définition
   - Et la logique de retournement et d'évaluation est identique

---

## Tasks / Subtasks

- [x] **T1 — Domaine drill : enum DrillEvaluationResult** (AC: #3, #4, #5)
  - [x] Créer `collega_app/lib/features/drill/domain/drill_state.dart`
  - [x] Définir `enum DrillEvaluationResult { aRevoir, bien, maitrise }`
  - [x] Ajouter extension helper :
    ```dart
    extension DrillEvaluationResultX on DrillEvaluationResult {
      bool get slidesUp => this == DrillEvaluationResult.maitrise;
      bool get slidesDown => this == DrillEvaluationResult.aRevoir;
    }
    ```

- [x] **T2 — FlashCardWidget** (AC: #1, #2, #4, #5, #6)
  - [x] Créer `collega_app/lib/features/generation/widgets/flash_card_widget.dart`
  - [x] Accepte `FlashCardModel card`, `bool isFlipped`, `DrillEvaluationResult? exitResult`, callbacks `onFlip` et `onExitComplete`
  - [x] Animation flip interne : AnimationController 300ms + Transform.rotateY (pattern exact de `DemoFlashCardWidget`)
  - [x] Afficher `OcrConfidenceBadge(score: card.ocrConfidenceScore)` en overlay sur la card (Positioned en bas-gauche)
  - [x] Quand `exitResult` change depuis `null` vers une valeur : déclencher animation de sortie via `flutter_animate`
  - [x] Maîtrisé → `.slideY(end: -1.5, duration: 250.ms).fade(end: 0)`, callback `onExitComplete` en `onComplete`
  - [x] À revoir → `.slideY(end: 1.5, duration: 250.ms).fade(end: 0)`, callback `onExitComplete` en `onComplete`
  - [x] Bien → `.fade(end: 0, duration: 250.ms)`, callback `onExitComplete` en `onComplete`
  - [x] Badge rang via `_rangBadgeColor(card.rang)` : A → `AppColors.primary`, B → `AppColors.secondary`, C → `const Color(0xFF6B7C6E)`
  - [x] `Semantics(label: 'Flashcard Rang ${card.rang} — ${card.recto}', hint: 'Tapoter pour retourner')`
  - [x] Tap target SizedBox height 300 minimum (HitTestBehavior.opaque sur GestureDetector)
  - [x] `didUpdateWidget` : si card change → `_controller.value = 0.0`

- [x] **T3 — DrillEvaluationBar** (AC: #3)
  - [x] Créer `collega_app/lib/features/drill/widgets/drill_evaluation_bar.dart`
  - [x] Import `DrillEvaluationResult` depuis `drill/domain/drill_state.dart`
  - [x] Paramètres : `bool isVisible`, `void Function(DrillEvaluationResult) onEvaluate`
  - [x] `AnimatedOpacity(opacity: isVisible ? 1.0 : 0.0, duration: 200ms)` + `IgnorePointer(ignoring: !isVisible)`
  - [x] `HapticFeedback.lightImpact()` avant d'appeler `onEvaluate` dans chaque `_onTap`
  - [x] Ordre exact des boutons : À revoir (destructive) → Bien (outline secondary) → Maîtrisé (filled)
  - [x] Ajout `Semantics(label: 'Évaluation: ...')` sur chaque bouton

- [x] **T4 — Créer les dossiers intermédiaires vides** (prérequis T2, T3)
  - [x] `collega_app/lib/features/generation/` (nouveau dossier)
  - [x] `collega_app/lib/features/generation/widgets/` (nouveau dossier)
  - [x] `collega_app/lib/features/drill/domain/` (nouveau dossier)
  - [x] `collega_app/lib/features/drill/widgets/` (nouveau dossier)

- [x] **T5 — Tests widget** (AC: #1, #2, #3, #4, #5)
  - [x] Créer `collega_app/test/features/drill/flash_card_widget_test.dart`
  - [x] Test : rendu recto — vérifier `card.recto` visible, badge rang, OcrConfidenceBadge absent si score >= 0.7
  - [x] Test : rendu recto — OcrConfidenceBadge visible si `lowConfidence == true` (score = 0.4)
  - [x] Test : tap → `onFlip` appelé, `isFlipped == true` visible
  - [x] Test : `DrillEvaluationBar` invisible avant retournement (opacity 0), visible après (`isVisible: true`)
  - [x] Créer `collega_app/test/features/drill/drill_evaluation_bar_test.dart`
  - [x] Test : 3 boutons présents avec textes corrects
  - [x] Test : tap "Maîtrisé" → `onEvaluate(DrillEvaluationResult.maitrise)` appelé
  - [x] Test : tap "À revoir" → `onEvaluate(DrillEvaluationResult.aRevoir)` appelé
  - [x] Test : `isVisible: false` → boutons non interactifs (`IgnorePointer`)

- [x] **T6 — Validation finale**
  - [x] `flutter analyze` → 0 nouvelle erreur (2 infos pré-existants dans colleges_detail_providers.dart)
  - [x] `flutter test test/features/drill/` → 13/13 verts, 0 régression
  - [x] `flutter test` (suite complète) → 68/68 verts, 0 nouvelle régression

### Review Findings

> Code review du 2026-05-12 — 3 `decision-needed`, 10 `patch`, 8 `defer`, 6 dismissed.

**Décisions requises :**
- [x] [Review][Decision] F5 — Card identity swap pendant exit animation : si la card change (`didUpdateWidget`) alors qu'une animation de sortie est en cours, `onExitComplete` se déclenche pour la mauvaise card. Faut-il avorter l'animation et reset le controller ? Ou garantir côté parent que la card ne change jamais pendant l'exit ?
- [x] [Review][Decision] F7 — `exitResult` réinitialisé à `null` en pleine animation : si le parent reset `exitResult=null` avant que les 250ms soient écoulés, `onExitComplete` ne se déclenche jamais. Faut-il que le widget mémorise l'`exitResult` en état interne (one-way) ? Ou est-ce un contrat caller-side ?
- [x] [Review][Decision] F22 — Animation de sortie "Bien" (fade) non spécifiée dans la story : l'AC ne définit que `maitrise` (slideY up) et `aRevoir` (slideY down). Le `else` branch ajoute un `fade` pour `bien`. Est-ce intentionnel ou du scope-creep ? S'il est absent, la card resterait visible après évaluation "Bien".

**Patches :**
- [x] [Review][Patch] F1 — `didUpdateWidget` : missing `_flipController.forward()` quand `isFlipped` passe `false→true` depuis le parent [flash_card_widget.dart:50-58]
- [x] [Review][Patch] F2 — `onExitComplete` appelé après `dispose()` : ajouter `if (!mounted) return` dans le callback flutter_animate [flash_card_widget.dart:171-187]
- [x] [Review][Patch] F3 — Test valide `lowConfidence` au lieu du seuil de score : le badge est piloté par `ocrConfidenceScore`, pas par le flag `lowConfidence` [flash_card_widget_test.dart]
- [x] [Review][Patch] F4 — Tap autorisé pendant l'animation de sortie : `_handleTap` ne vérifie pas `widget.exitResult != null` [flash_card_widget.dart:67-70]
- [x] [Review][Patch] F6 — Animation de sortie recréée à chaque `build()` quand `exitResult != null` : flutter_animate redémarre l'animation à chaque rebuild [flash_card_widget.dart:169-188]
- [x] [Review][Patch] F11 — Flicker une frame à `angle == pi/2` : condition `showFront = angle <= pi / 2` devrait être `< pi / 2` [flash_card_widget.dart:148-149]
- [x] [Review][Patch] F12 — `_handleTap` peut appeler `onFlip` deux fois avant que le parent mette à jour `isFlipped` (double-tap pendant animation) [flash_card_widget.dart:67-70]
- [x] [Review][Patch] F18 — Extension `slidesUp`/`slidesDown` définie mais non utilisée dans `FlashCardWidget` (code mort) [drill_state.dart:8-9 + flash_card_widget.dart:169-188]
- [x] [Review][Patch] F21 — Fichier test dans le mauvais dossier : `test/features/drill/flash_card_widget_test.dart` devrait être `test/features/generation/` [flash_card_widget_test.dart]
- [x] [Review][Patch] F23 — Test "DrillEvaluationBar invisible avant flip" incomplet : ne vérifie pas opacity=0 ni IgnorePointer [flash_card_widget_test.dart]

**Différés :**
- [x] [Review][Defer] F8 — `score == 0.0` masqué par condition `<= 0.0` — comportement pré-existant Story 3.3 [ocr_confidence_badge.dart:27] — deferred, pre-existing
- [x] [Review][Defer] F9 — Popover reste ouvert si le badge sort du viewport — limitation shadcn_ui [ocr_confidence_badge.dart:59] — deferred, pre-existing
- [x] [Review][Defer] F10 — Tap en file peut passer à travers toggle rapide de `isVisible` — comportement pipeline gesture Flutter [drill_evaluation_bar.dart:18] — deferred, pre-existing
- [x] [Review][Defer] F14 — `AnimatedOpacity` + `IgnorePointer` : pas de source unique de vérité — décision architecturale à revoir en Story 4.2 [drill_evaluation_bar.dart] — deferred, pre-existing
- [x] [Review][Defer] F16 — Pas de test pour l'animation flip ni `didUpdateWidget` card-change — hors T5 requis [flash_card_widget_test.dart] — deferred, pre-existing
- [x] [Review][Defer] F17 — `OcrConfidenceBadge` : aucun accès clavier/screen reader au contenu du popover — gap pré-existant Story 3.3 [ocr_confidence_badge.dart] — deferred, pre-existing
- [x] [Review][Defer] F19 — `_makeCard` fixture utilise des IDs fixes (`'test-id'`) — risque test-data collision future [flash_card_widget_test.dart] — deferred, pre-existing
- [x] [Review][Defer] F27 — Extension sans getter `slidesNeutral` pour `bien` — choix de design, inférence par exclusion [drill_state.dart:8-9] — deferred, pre-existing

---

## Dev Notes

### Architecture : emplacements des fichiers

```
collega_app/lib/
├── features/
│   ├── generation/          # NOUVEAU — dossier à créer (vide actuellement)
│   │   └── widgets/
│   │       └── flash_card_widget.dart    # CE FICHIER — Story 4.1
│   └── drill/               # NOUVEAU — dossier à créer (vide actuellement)
│       ├── domain/
│       │   └── drill_state.dart         # CE FICHIER — DrillEvaluationResult enum
│       └── widgets/
│           └── drill_evaluation_bar.dart  # CE FICHIER — Story 4.1
```

**IMPORTANT** : Les deux dossiers `features/generation/` et `features/drill/` sont **entièrement vides** — aucun fichier existant. Créer la structure de dossiers et les fichiers.

**NE PAS** placer `FlashCardWidget` dans `features/drill/` — l'architecture spécifie `features/generation/widgets/` car la FlashCard est utilisée dans le contexte de visualisation des fiches (Story 3.3 `ItemDetailScreen`) ET dans le Mode Drill.

### Modèle FlashCardModel (existant — NE PAS recréer)

```
collega_app/lib/features/colleges/domain/college_detail_models.dart
```

Champs pertinents pour FlashCard :
```dart
final String id;
final String cardType;    // 'classic' ou 'definition'
final String rang;        // 'A', 'B', ou 'C'
final String recto;       // question / terme médical
final String verso;       // réponse / définition
final double ocrConfidenceScore;
final bool lowConfidence;
```

### Composants existants à RÉUTILISER (NE PAS recréer)

| Composant | Chemin | Usage dans FlashCard |
|---|---|---|
| `OcrConfidenceBadge` | `colleges/presentation/widgets/ocr_confidence_badge.dart` | Overlay sur la card si `lowConfidence == true` |
| `AppColors` | `core/theme/app_theme.dart` | primary, secondary, rangC `Color(0xFF6B7C6E)` |
| `AppSpacing` | `core/theme/app_theme.dart` | cardPadding 16, cardRadius 12, screenMargin 16 |
| `AppTypography` | `core/theme/app_theme.dart` | titleMedium (question), bodyLarge (réponse) |
| `ShadBadge` | `shadcn_ui ^0.19.0` | Badge rang coloré |
| `ShadButton`, `ShadButton.outline`, `ShadButton.destructive` | `shadcn_ui ^0.19.0` | Boutons DrillEvaluationBar |
| `ShadCard` | `shadcn_ui ^0.19.0` | Container de la card (recto/verso) |

### Référence : DemoFlashCardWidget (pattern animation à copier)

La logique d'animation flip **est exactement celle de** `DemoFlashCardWidget` :

```
collega_app/lib/features/demo/presentation/widgets/demo_flash_card_widget.dart
```

Copier cette logique et adapter pour `FlashCardModel` :
- `AnimationController` 300ms + `CurvedAnimation(curve: Curves.easeInOut)`
- `_rotateAnim = Tween<double>(begin: 0.0, end: 1.0).animate(...)`
- `AnimatedBuilder` + `Transform(Matrix4..rotateY(angle))`
- Contre-rotation du verso : `Transform(Matrix4..rotateY(pi))`
- `didUpdateWidget` : si `widget.card != oldWidget.card` → `_controller.value = 0.0`
- `initState` : si `widget.isFlipped` → `_controller.value = 1.0`

### FlashCardWidget — implémentation complète

```dart
// collega_app/lib/features/generation/widgets/flash_card_widget.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/presentation/widgets/ocr_confidence_badge.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';

class FlashCardWidget extends StatefulWidget {
  const FlashCardWidget({
    super.key,
    required this.card,
    required this.isFlipped,
    this.exitResult,
    this.onFlip,
    this.onExitComplete,
  });

  final FlashCardModel card;
  final bool isFlipped;
  final DrillEvaluationResult? exitResult;
  final VoidCallback? onFlip;
  final VoidCallback? onExitComplete;

  @override
  State<FlashCardWidget> createState() => _FlashCardWidgetState();
}

class _FlashCardWidgetState extends State<FlashCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _rotateAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    if (widget.isFlipped) _flipController.value = 1.0;
  }

  @override
  void didUpdateWidget(FlashCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.card != oldWidget.card) {
      _flipController.value = 0.0;
      return;
    }
    if (!widget.isFlipped && oldWidget.isFlipped) {
      _flipController.reverse();
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isFlipped) return;
    _flipController.forward();
    widget.onFlip?.call();
  }

  Color _rangBadgeColor(String rang) {
    switch (rang) {
      case 'A': return AppColors.primary;
      case 'B': return AppColors.secondary;
      default:  return const Color(0xFF6B7C6E); // gris neutre Rang C
    }
  }

  Widget _buildCardSide({required bool isFront}) {
    final text = isFront ? widget.card.recto : widget.card.verso;
    final label = isFront ? 'Question' : 'Réponse';
    return ShadCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShadBadge(
                    backgroundColor: _rangBadgeColor(widget.card.rang),
                    child: Text(
                      'Rang ${widget.card.rang}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: AppTypography.labelMedium()
                        .copyWith(color: AppColors.secondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: Text(
                    text,
                    style: AppTypography.titleMedium(),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          // OcrConfidenceBadge overlay — visible uniquement si low confidence
          if (isFront)
            Positioned(
              bottom: 0,
              left: 0,
              child: OcrConfidenceBadge(score: widget.card.ocrConfidenceScore),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget card = Semantics(
      label: 'Flashcard Rang ${widget.card.rang} — ${widget.card.recto}',
      hint: 'Tapoter pour retourner',
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: double.infinity,
          height: 300,
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
                child: showFront
                    ? _buildCardSide(isFront: true)
                    : Transform(
                        transform: Matrix4.identity()..rotateY(pi),
                        alignment: Alignment.center,
                        child: _buildCardSide(isFront: false),
                      ),
              );
            },
          ),
        ),
      ),
    );

    // Appliquer l'animation de sortie si exitResult est défini
    if (widget.exitResult != null) {
      final result = widget.exitResult!;
      if (result == DrillEvaluationResult.maitrise) {
        card = card
            .animate()
            .slideY(end: -1.5, duration: 250.ms)
            .fade(end: 0, duration: 250.ms)
            .callback(callback: (_) => widget.onExitComplete?.call());
      } else if (result == DrillEvaluationResult.aRevoir) {
        card = card
            .animate()
            .slideY(end: 1.5, duration: 250.ms)
            .fade(end: 0, duration: 250.ms)
            .callback(callback: (_) => widget.onExitComplete?.call());
      } else {
        // DrillEvaluationResult.bien
        card = card
            .animate()
            .fade(end: 0, duration: 250.ms)
            .callback(callback: (_) => widget.onExitComplete?.call());
      }
    }

    return card;
  }
}
```

**Attention flutter_animate** : Le `.callback(callback: ...)` se déclenche à la fin de l'animation. Vérifier l'API exacte de la version `^4.5.0` — si `callback` n'est pas disponible directement, utiliser `onComplete` sur l'`AnimateController` ou gérer via un `AnimationController` séparé pour la sortie.

### DrillEvaluationBar — implémentation complète

```dart
// collega_app/lib/features/drill/widgets/drill_evaluation_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';

class DrillEvaluationBar extends StatelessWidget {
  const DrillEvaluationBar({
    super.key,
    required this.isVisible,
    required this.onEvaluate,
  });

  final bool isVisible;
  final void Function(DrillEvaluationResult result) onEvaluate;

  void _onTap(DrillEvaluationResult result) {
    HapticFeedback.lightImpact();
    onEvaluate(result);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !isVisible,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: 'Évaluation: À revoir',
                child: ShadButton.destructive(
                  onPressed: () => _onTap(DrillEvaluationResult.aRevoir),
                  child: const Text('À revoir'),
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: 'Évaluation: Bien',
                child: ShadButton.outline(
                  onPressed: () => _onTap(DrillEvaluationResult.bien),
                  foregroundColor: AppColors.secondary,
                  child: const Text('Bien'),
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: 'Évaluation: Maîtrisé',
                child: ShadButton(
                  onPressed: () => _onTap(DrillEvaluationResult.maitrise),
                  child: const Text('Maîtrisé'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### DrillEvaluationResult enum

```dart
// collega_app/lib/features/drill/domain/drill_state.dart
enum DrillEvaluationResult {
  aRevoir,
  bien,
  maitrise,
}

extension DrillEvaluationResultX on DrillEvaluationResult {
  bool get slidesUp   => this == DrillEvaluationResult.maitrise;
  bool get slidesDown => this == DrillEvaluationResult.aRevoir;

  String get label {
    switch (this) {
      case DrillEvaluationResult.aRevoir:  return 'À revoir';
      case DrillEvaluationResult.bien:     return 'Bien';
      case DrillEvaluationResult.maitrise: return 'Maîtrisé';
    }
  }
}
```

### Animation de sortie — détail technique flutter_animate ^4.5.0

L'API `flutter_animate ^4.5.0` utilise `.animate()` pour chaîner les effets. Le `.callback(callback: ...)` est disponible.

```dart
// Pattern pour l'animation de sortie (dans _FlashCardWidgetState.build)
// Ne pas utiliser TweenAnimationBuilder car flutter_animate est plus lisible

// Maîtrisé
card.animate().slideY(end: -1.5, duration: 250.ms).fade(end: 0.0, duration: 250.ms)

// À revoir
card.animate().slideY(end: 1.5, duration: 250.ms).fade(end: 0.0, duration: 250.ms)

// Bien
card.animate().fade(end: 0.0, duration: 250.ms)
```

**Attention** : L'animation de sortie est appliquée **conditionnellement** (quand `exitResult != null`). Éviter de recréer l'`Animate` widget à chaque build inutilement.

**Alternative si `.callback` pose problème** : Utiliser un `AnimationController` dédié à la sortie + `addStatusListener` :

```dart
_exitController.addStatusListener((status) {
  if (status == AnimationStatus.completed) {
    widget.onExitComplete?.call();
  }
});
```

### Pattern de test à suivre (cohérent avec les stories précédentes)

```dart
// test/features/drill/flash_card_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/generation/widgets/flash_card_widget.dart';

FlashCardModel _makeCard({
  String rang = 'A',
  String cardType = 'classic',
  double ocrScore = 0.9,
  bool lowConfidence = false,
}) => FlashCardModel(
      id: 'test-id',
      itemId: 'item-id',
      collegeId: 'college-id',
      cardType: cardType,
      rang: rang,
      recto: 'Question test',
      verso: 'Réponse test',
      ocrConfidenceScore: ocrScore,
      lowConfidence: lowConfidence,
    );

Widget _wrap(Widget child) => ShadApp(
      theme: buildShadTheme(),
      home: Scaffold(body: child),
    );

void main() {
  group('FlashCardWidget', () {
    testWidgets('recto affiche question + badge rang', (tester) async {
      await tester.pumpWidget(_wrap(
        FlashCardWidget(card: _makeCard(rang: 'A'), isFlipped: false),
      ));
      expect(find.text('Question test'), findsOneWidget);
      expect(find.text('Rang A'), findsOneWidget);
    });

    testWidgets('OcrConfidenceBadge absent si score >= 0.7', (tester) async {
      await tester.pumpWidget(_wrap(
        FlashCardWidget(card: _makeCard(ocrScore: 0.9, lowConfidence: false), isFlipped: false),
      ));
      expect(find.text('À vérifier'), findsNothing);
      expect(find.text('Source peu lisible'), findsNothing);
    });

    testWidgets('OcrConfidenceBadge visible si lowConfidence == true', (tester) async {
      await tester.pumpWidget(_wrap(
        FlashCardWidget(card: _makeCard(ocrScore: 0.4, lowConfidence: true), isFlipped: false),
      ));
      expect(find.text('Source peu lisible'), findsOneWidget);
    });

    testWidgets('tap appelle onFlip', (tester) async {
      var flipped = false;
      await tester.pumpWidget(_wrap(
        FlashCardWidget(
          card: _makeCard(),
          isFlipped: false,
          onFlip: () { flipped = true; },
        ),
      ));
      await tester.tap(find.byType(FlashCardWidget));
      expect(flipped, isTrue);
    });
  });
}
```

```dart
// test/features/drill/drill_evaluation_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';
import 'package:collega_app/features/drill/widgets/drill_evaluation_bar.dart';

Widget _wrap(Widget child) => ShadApp(
      theme: buildShadTheme(),
      home: Scaffold(body: child),
    );

void main() {
  group('DrillEvaluationBar', () {
    testWidgets('3 boutons présents', (tester) async {
      await tester.pumpWidget(_wrap(
        DrillEvaluationBar(isVisible: true, onEvaluate: (_) {}),
      ));
      expect(find.text('À revoir'), findsOneWidget);
      expect(find.text('Bien'), findsOneWidget);
      expect(find.text('Maîtrisé'), findsOneWidget);
    });

    testWidgets('tap Maîtrisé → callback maitrise', (tester) async {
      DrillEvaluationResult? result;
      await tester.pumpWidget(_wrap(
        DrillEvaluationBar(isVisible: true, onEvaluate: (r) { result = r; }),
      ));
      await tester.tap(find.text('Maîtrisé'));
      expect(result, DrillEvaluationResult.maitrise);
    });

    testWidgets('tap À revoir → callback aRevoir', (tester) async {
      DrillEvaluationResult? result;
      await tester.pumpWidget(_wrap(
        DrillEvaluationBar(isVisible: true, onEvaluate: (r) { result = r; }),
      ));
      await tester.tap(find.text('À revoir'));
      expect(result, DrillEvaluationResult.aRevoir);
    });

    testWidgets('isVisible false → boutons non interactifs', (tester) async {
      var called = false;
      await tester.pumpWidget(_wrap(
        DrillEvaluationBar(isVisible: false, onEvaluate: (_) { called = true; }),
      ));
      await tester.tap(find.text('Maîtrisé'), warnIfMissed: false);
      expect(called, isFalse);
    });
  });
}
```

### Anti-patterns à éviter

- **NE PAS** recréer `DemoFlashCardWidget` ou `DemoDrillEvaluationBar` — copier/adapter le pattern d'animation, **pas** le widget existant (modèles différents)
- **NE PAS** placer `FlashCardWidget` dans `features/drill/widgets/` — il appartient à `features/generation/widgets/` (architecture spec)
- **NE PAS** placer `DrillEvaluationBar` dans `features/generation/widgets/` — il appartient à `features/drill/widgets/`
- **NE PAS** utiliser `ShadSkeleton` — absent de `shadcn_ui ^0.19.0` (découvert en Story 3.5)
- **NE PAS** utiliser `CircularProgressIndicator` pour les états de chargement — `CircularProgressIndicator(strokeWidth: 2)` 20px si nécessaire mais Story 4.1 n'a pas d'états async
- **NE PAS** mettre de logique métier dans les widgets — ces composants sont purs (UI + animation uniquement)
- **NE PAS** appeler `print()` ou `debugPrint()` — utiliser `AppLogger` (core/utils/logger.dart)
- **NE PAS** déplacer `item_progress_bar.dart` depuis `colleges/presentation/widgets/` — il y est déjà utilisé et sera référencé par Story 4.5
- **NE PAS** créer `drill_providers.dart` ou `drill_repository.dart` dans cette story — Story 4.2 s'en charge
- **NE PAS** ajouter de logique de spaced repetition — hors scope Story 4.1

### État du codebase au début de cette story

| Composant | État | Chemin |
|---|---|---|
| `FlashCardModel` | ✅ Existe — id, cardType, rang, recto, verso, ocrConfidenceScore, lowConfidence, userFeedback | `colleges/domain/college_detail_models.dart:42` |
| `OcrConfidenceBadge` | ✅ Existe — ShadPopover, variants orange/rouge, SizedBox.shrink si score >= 0.7 | `colleges/presentation/widgets/ocr_confidence_badge.dart` |
| `ItemProgressBar` | ✅ Existe (dans colleges/widgets) — barre seg. rang A/B/C | `colleges/presentation/widgets/item_progress_bar.dart` |
| `CollegeProgressTile` | ✅ Existe | `colleges/widgets/college_progress_tile.dart` |
| `AppColors`, `AppSpacing`, `AppTypography` | ✅ Existent | `core/theme/app_theme.dart` |
| `DemoFlashCardWidget` | ✅ Existe — référence animation flip | `demo/presentation/widgets/demo_flash_card_widget.dart` |
| `DemoDrillEvaluationBar` | ✅ Existe — référence boutons + haptic | `demo/presentation/widgets/demo_drill_evaluation_bar.dart` |
| `features/generation/` | 🚫 Dossier vide — à créer | — |
| `features/drill/` | 🚫 Dossier vide — à créer | — |
| `shadcn_ui: ^0.19.0` | ✅ `ShadBadge`, `ShadCard`, `ShadButton`, `ShadButton.outline`, `ShadButton.destructive` disponibles | `pubspec.yaml` |
| `flutter_animate: ^4.5.0` | ✅ `.slideY()`, `.fade()`, `.animate()`, `.callback()` disponibles | `pubspec.yaml` |

### Intelligence git (commits récents)

- `feat(epic-3): Stories 3-1 à 3-5` : `flutter analyze` → 0 erreur a été validé avant chaque merge
- Pattern de test établi : `ShadApp(theme: buildShadTheme(), home: Scaffold(body: ...))` pour les widget tests
- Pattern `_makeCard(...)` / `_makeItem(...)` pour créer des fixtures dans les tests
- `ConsumerStatefulWidget` pour les écrans qui lisent le state Riverpod
- Les tests Flutter ne nécessitent pas mockito — utiliser des callbacks et états directs

### Règles qualité héritées des stories précédentes

- `flutter analyze` → 0 erreur avant de marquer terminée
- Logique métier dans les Notifiers, jamais dans les widgets
- Pattern `_wrap(Widget child)` dans les tests pour wraper avec `ShadApp` + `buildShadTheme()`
- `HapticFeedback.lightImpact()` systématique sur les boutons d'évaluation
- `Semantics` labels obligatoires sur les composants custom (UX-DR7)
- Tap targets ≥ 44×44px (SizedBox minimum sur GestureDetector)
- `if (!mounted) return` dans tous les callbacks async (non applicable ici — composants synchrones)

---

### Références

- `DemoFlashCardWidget` (animation flip — pattern à copier) : `collega_app/lib/features/demo/presentation/widgets/demo_flash_card_widget.dart`
- `DemoDrillEvaluationBar` (boutons + haptic — référence) : `collega_app/lib/features/demo/presentation/widgets/demo_drill_evaluation_bar.dart`
- `FlashCardModel` (modèle) : `collega_app/lib/features/colleges/domain/college_detail_models.dart:42`
- `OcrConfidenceBadge` (widget existant) : `collega_app/lib/features/colleges/presentation/widgets/ocr_confidence_badge.dart`
- `app_theme.dart` (couleurs, spacing, typographie) : `collega_app/lib/core/theme/app_theme.dart`
- Architecture drill structure : `_bmad-output/planning-artifacts/architecture.md#Structure Patterns`
- UX composants custom : `_bmad-output/planning-artifacts/epics.md#UX-DR1, UX-DR4, UX-DR7`
- Pattern test : `collega_app/test/features/colleges/college_detail_screen_test.dart`
- flutter_animate API : `pubspec.yaml#flutter_animate: ^4.5.0`

---

## Dev Agent Record

### Agent Model Used

claude-sonnet-4-6

### Debug Log References

- Bug corrigé : `OcrConfidenceBadge` utilisait `ShadPopover` sans `controller` ni `visible` (assertion shadcn_ui 0.19.3). Converti en StatefulWidget avec `ShadPopoverController`.
- `flutter_animate` déjà ré-exporté par `shadcn_ui` → import redondant supprimé dans `flash_card_widget.dart`.
- Pattern test flutter_animate : `await tester.pump(Duration.zero)` requis après `pumpWidget` pour drainer les timers 0ms de ShadApp (identique au pattern de `college_detail_screen_test.dart`).

### Completion Notes List

- Créé `drill_state.dart` : enum `DrillEvaluationResult` + extension `DrillEvaluationResultX` avec `slidesUp`, `slidesDown`, `label`.
- Créé `flash_card_widget.dart` : animation flip 300ms (pattern `DemoFlashCardWidget`), animations de sortie conditionnelles via `flutter_animate` (.slideY / .fade / .callback), badge rang A/B/C, OcrConfidenceBadge overlay, Semantics, tap target 300px.
- Créé `drill_evaluation_bar.dart` : 3 boutons (destructive/outline/filled), `AnimatedOpacity` + `IgnorePointer`, `HapticFeedback.lightImpact()`, Semantics.
- 13 tests widget créés (7 FlashCard + 5 DrillEvaluationBar + 1 smoke). 68/68 tests total passent, 0 régression.

### File List

- `collega_app/lib/features/drill/domain/drill_state.dart` (créé)
- `collega_app/lib/features/drill/widgets/drill_evaluation_bar.dart` (créé)
- `collega_app/lib/features/generation/widgets/flash_card_widget.dart` (créé)
- `collega_app/lib/features/colleges/presentation/widgets/ocr_confidence_badge.dart` (modifié — bugfix ShadPopoverController)
- `collega_app/test/features/drill/flash_card_widget_test.dart` (créé)
- `collega_app/test/features/drill/drill_evaluation_bar_test.dart` (créé)

## Change Log

- 2026-05-12 — Implémentation Story 4.1 : création de `drill_state.dart` (enum DrillEvaluationResult), `flash_card_widget.dart` (animation flip + sortie), `drill_evaluation_bar.dart` (3 boutons + haptic). Bugfix `OcrConfidenceBadge` (ShadPopoverController). 13 tests widget, 68/68 tests passent. Statut → review.

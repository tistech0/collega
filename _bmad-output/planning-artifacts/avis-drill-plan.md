# Partie C — Avis sur une fiche pendant le drill : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Au verso d'une fiche en drill, deux icônes pouce permettent de dire « Utile » ou « À corriger » (avec régénération non bloquante), exactement comme dans la vue item.

**Architecture:** Un composant générique `CgCardFeedback` (design system) affiche les deux icônes. `CgDrillCard` reçoit un emplacement optionnel `answerActions` en haut de la feuille de réponse. Le signalement (feuille + note) sort de `item_detail_screen.dart` dans `card_report.dart`, partagé par la vue item et le drill ; le drill parle directement à `CollegeDetailRepository` (qui met déjà à jour Drift) et note l'avis dans l'état de session via `DrillSessionNotifier.setCardFeedback`.

**Tech Stack:** Flutter 3.27.1, Riverpod 2, Drift, flutter_test (goldens tagués `golden`).

**Spec:** `_bmad-output/planning-artifacts/recherche-pdf-avis-drill-accueil-spec.md`, section « C. Avis sur une fiche pendant le drill » (lire aussi l'introduction).

## Global Constraints

- Aucun changement serveur. Routes réutilisées : `POST /v1/flash-cards/{id}/feedback` (`CollegeDetailRepository.submitFeedback`) et `POST /v1/flash-cards/{id}/regenerate` (`CollegeDetailRepository.regenerateCard`, limitée à 10/heure).
- Tests : depuis `collega_app/`, **par dossier** : `flutter test test/core`, `flutter test test/features/drill`, `flutter test test/features/colleges`. Jamais toute la suite d'un coup.
- Goldens : tag `golden`, exécutés en local macOS. Mise à jour : `flutter test --update-goldens --tags golden <fichier>` puis **vérifier l'image à l'œil** avant de commiter.
- Textes en français, tutoiement, apostrophe typographique `’`.
- Libellés VoiceOver imposés : « Fiche utile » / « Signaler la fiche » (mêmes que la vue item).
- Cibles tactiles ≥ `CgSpace.tapTarget` (44 pt). État choisi : icône `accent` sur fond `accentSoft` ; non choisi : icône `ink2`, bordure `line`.
- Aucune couleur ni taille en dur hors constantes nommées (`static const _x = …`), comme le reste de Collega UI.
- Commits en français, préfixe `feat(avis-drill)` / `refactor(avis-drill)` / `test(avis-drill)`, terminés par `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

## Review Focus

- **Toucher une icône au verso ne doit jamais juger la fiche** (le `Listener` de `CgDrillCard` capte tout pointeur posé sur la feuille) → test « tap sur l'icône : aucun verdict » (Task 2).
- **Réseau coupé pendant « Utile » / « À corriger »** : toast, l'icône ne passe pas à l'état choisi, le drill continue → tests Task 4.
- **Régénération qui échoue ou se termine après la sortie du drill** : jamais d'exception (pas de `ref` après `dispose`), toast seulement si l'écran est encore là → test « quitter pendant la régénération » (Task 4).
- **Vue item ouverte après un avis donné en drill** : `itemDetailProvider` n'est pas `autoDispose`, il garderait l'ancien état → invalidation après chaque avis/régénération, testée (Task 4).
- **Fiche « à revoir » réinsérée plus loin** : l'avis donné au premier passage s'affiche au second (même `cardId`, état dans `cards`) → test notifier (Task 3).

## File Structure

Créés :
- `collega_app/lib/core/ui/components/cg_card_feedback.dart` — `CgCardFeedback` : deux icônes pouce à bascule (générique, sans logique métier).
- `collega_app/lib/features/colleges/presentation/card_report.dart` — `CardNoteBody`, `CardReportChoice`, `CardReportResult`, `showCardReportSheet` (feuille « Signaler cette fiche » partagée).
- `collega_app/test/core/ui/components/cg_card_feedback_test.dart`
- `collega_app/test/features/colleges/card_report_test.dart`
- `collega_app/test/features/drill/drill_card_feedback_test.dart`

Modifiés :
- `collega_app/lib/core/ui/collega_ui.dart` (export)
- `collega_app/lib/core/ui/components/cg_drill_card.dart` (emplacement `answerActions`)
- `collega_app/lib/features/colleges/presentation/item_detail_screen.dart` (utilise `card_report.dart`, `_NoteBody` supprimé)
- `collega_app/lib/features/drill/drill_providers.dart` (`setCardFeedback`)
- `collega_app/lib/features/drill/presentation/drill_screen.dart` (branchement)
- Tests : `test/core/ui/components/cg_drill_card_test.dart`, `test/features/drill/drill_session_notifier_test.dart` ; goldens `test/features/drill/goldens/drill_verso_*.png` régénérés.

---

### Task 1: Composant `CgCardFeedback`

**Files:**
- Create: `collega_app/lib/core/ui/components/cg_card_feedback.dart`
- Modify: `collega_app/lib/core/ui/collega_ui.dart`
- Test: `collega_app/test/core/ui/components/cg_card_feedback_test.dart`

**Interfaces:**
- Produces: `class CgCardFeedback extends StatelessWidget { const CgCardFeedback({super.key, required String? feedback, required VoidCallback onUseful, required VoidCallback onReport}); static const usefulKey = ValueKey('cg-card-feedback-useful'); static const reportKey = ValueKey('cg-card-feedback-report'); }` — `feedback` vaut `'positive'`, `'negative'` ou `null` (valeurs de `FlashCardModel.userFeedback`).

- [ ] **Step 1: Écrire le test qui échoue**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/collega_ui.dart';

import '../../../support/cg_golden.dart';

Widget _host({String? feedback, VoidCallback? onUseful, VoidCallback? onReport}) => cgTestApp(
      Center(
        child: CgCardFeedback(
          feedback: feedback,
          onUseful: onUseful ?? () {},
          onReport: onReport ?? () {},
        ),
      ),
    );

void main() {
  testWidgets('deux icônes étiquetées pour VoiceOver, 44 pt chacune', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.bySemanticsLabel('Fiche utile'), findsOneWidget);
    expect(find.bySemanticsLabel('Signaler la fiche'), findsOneWidget);
    for (final key in [CgCardFeedback.usefulKey, CgCardFeedback.reportKey]) {
      final size = tester.getSize(find.byKey(key));
      expect(size.width, greaterThanOrEqualTo(CgSpace.tapTarget));
      expect(size.height, greaterThanOrEqualTo(CgSpace.tapTarget));
    }
  });

  testWidgets('toucher appelle le bon rappel', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(_host(onUseful: () => calls.add('useful'), onReport: () => calls.add('report')));
    await tester.tap(find.byKey(CgCardFeedback.usefulKey));
    await tester.tap(find.byKey(CgCardFeedback.reportKey));
    expect(calls, ['useful', 'report']);
  });

  testWidgets('état choisi annoncé (selected) et lisible sans la couleur (fond accentSoft)', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(feedback: 'positive'));
    expect(
      tester.getSemantics(find.byKey(CgCardFeedback.usefulKey)),
      matchesSemantics(label: 'Fiche utile', isButton: true, isSelected: true, hasSelectedState: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.byKey(CgCardFeedback.reportKey)),
      matchesSemantics(label: 'Signaler la fiche', isButton: true, hasSelectedState: true, hasTapAction: true),
    );
    final decorated = tester.widgetList<DecoratedBox>(
      find.descendant(of: find.byKey(CgCardFeedback.usefulKey), matching: find.byType(DecoratedBox)),
    );
    expect(
      decorated.any((d) => (d.decoration as BoxDecoration).color == CgThemeData.light.colors.accentSoft),
      isTrue,
    );
    handle.dispose();
  });
}
```

- [ ] **Step 2: Lancer le test, vérifier l'échec**

Run: `flutter test test/core/ui/components/cg_card_feedback_test.dart`
Expected: FAIL (`CgCardFeedback` introuvable).

- [ ] **Step 3: Implémenter**

`lib/core/ui/components/cg_card_feedback.dart` :

```dart
import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';

/// Avis sur une fiche en deux icônes seules (drill, spec « avis pendant le
/// drill ») : pouce haut « Fiche utile », pouce bas « Signaler la fiche ».
/// L'avis choisi se lit sans la couleur : fond `accentSoft` + état annoncé.
class CgCardFeedback extends StatelessWidget {
  const CgCardFeedback({super.key, required this.feedback, required this.onUseful, required this.onReport});

  /// `'positive'`, `'negative'` ou null (valeurs de `user_feedback`).
  final String? feedback;
  final VoidCallback onUseful;
  final VoidCallback onReport;

  static const usefulKey = ValueKey('cg-card-feedback-useful');
  static const reportKey = ValueKey('cg-card-feedback-report');

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _Toggle(
        key: usefulKey,
        icon: CgIcons.thumbUp,
        semanticLabel: 'Fiche utile',
        selected: feedback == 'positive',
        onTap: onUseful,
      ),
      _Toggle(
        key: reportKey,
        icon: CgIcons.thumbDown,
        semanticLabel: 'Signaler la fiche',
        selected: feedback == 'negative',
        onTap: onReport,
      ),
    ]);
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({super.key, required this.icon, required this.semanticLabel, required this.selected, required this.onTap});

  final String icon;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  static const _disc = 36.0;
  static const _iconSize = 18.0;
  static const _border = 1.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: CgSpace.tapTarget,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? c.accentSoft : null,
                border: Border.all(color: selected ? c.accentSoft : c.line, width: _border),
              ),
              child: SizedBox.square(
                dimension: _disc,
                child: Center(child: CgIcon(icon, size: _iconSize, color: selected ? c.accent : c.ink2)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Dans `lib/core/ui/collega_ui.dart`, ajouter après `export 'components/cg_card_type_tag.dart';` :

```dart
export 'components/cg_card_feedback.dart';
```

- [ ] **Step 4: Lancer le test, vérifier le succès**

Run: `flutter test test/core/ui/components/cg_card_feedback_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add collega_app/lib/core/ui/components/cg_card_feedback.dart collega_app/lib/core/ui/collega_ui.dart collega_app/test/core/ui/components/cg_card_feedback_test.dart
git commit -m "feat(avis-drill): composant CgCardFeedback (pouces seuls, état choisi lisible)

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Emplacement `answerActions` dans `CgDrillCard`

**Files:**
- Modify: `collega_app/lib/core/ui/components/cg_drill_card.dart` (constructeur ~l. 45-66, champs ~l. 93-95, `_sheet` ~l. 865-870)
- Test: `collega_app/test/core/ui/components/cg_drill_card_test.dart`

**Interfaces:**
- Consumes: `CgCardFeedback` (Task 1) — seulement dans le test.
- Produces: paramètre `Widget? answerActions` de `CgDrillCard` : affiché en haut à droite de la feuille de réponse (au-dessus de `answerHeader`), donc invisible et inerte au recto (la feuille est sous `IgnorePointer` + `ExcludeSemantics` tant qu'elle est fermée).

Note : la maquette plaçait les icônes « à droite du libellé Réponse », mais la feuille n'a pas de libellé « Réponse » ; elles occupent une rangée alignée à droite en tête de feuille.

- [ ] **Step 1: Écrire les tests qui échouent**

Dans `test/core/ui/components/cg_drill_card_test.dart`, ajouter le paramètre `Widget? answerActions` à la fonction `_card({...})` et le passer à `CgDrillCard(... answerActions: answerActions, ...)`. Puis ajouter à la fin de `main()` :

```dart
  group('verso — actions de la réponse', () {
    Widget actions(List<String> calls) => CgCardFeedback(
          feedback: null,
          onUseful: () => calls.add('useful'),
          onReport: () => calls.add('report'),
        );

    testWidgets('recto : actions ni visibles pour VoiceOver ni touchables', (tester) async {
      _phone(tester);
      final calls = <String>[];
      await tester.pumpWidget(_card(answerActions: actions(calls)));
      expect(find.bySemanticsLabel('Fiche utile'), findsNothing);
      await tester.tap(find.byKey(CgCardFeedback.usefulKey), warnIfMissed: false);
      expect(calls, isEmpty);
    });

    testWidgets('verso : toucher une action l’appelle et ne juge jamais la fiche', (tester) async {
      _phone(tester);
      final calls = <String>[];
      final verdicts = <CgVerdict>[];
      await tester.pumpWidget(_card(flipped: true, verdicts: verdicts, answerActions: actions(calls)));
      expect(find.bySemanticsLabel('Fiche utile'), findsOneWidget);
      await tester.tap(find.byKey(CgCardFeedback.reportKey));
      await tester.pumpAndSettle();
      expect(calls, ['report']);
      expect(verdicts, isEmpty);
      expect(_state(tester).dragOffset, Offset.zero);
    });

    testWidgets('verso : actions au-dessus de la réponse, alignées à droite', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_card(flipped: true, answerActions: actions([])));
      final icons = tester.getRect(find.byType(CgCardFeedback));
      final answer = tester.getRect(find.byKey(CgDrillCard.answerKey));
      expect(icons.bottom, lessThanOrEqualTo(answer.top));
      expect(icons.right, closeTo(answer.right, 1));
    });
  });
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `flutter test test/core/ui/components/cg_drill_card_test.dart`
Expected: FAIL à la compilation (`answerActions` n'existe pas).

- [ ] **Step 3: Implémenter**

Dans `CgDrillCard` : ajouter `this.answerActions,` dans le constructeur (après `this.answerHeader,`) et le champ, sous `answerHeader` :

```dart
  /// En haut à droite de la feuille de réponse (avis sur la fiche) : de simples
  /// touchers, qui ne jugent jamais la fiche.
  final Widget? answerActions;
```

Dans `_sheet`, remplacer le début de la `Column` :

```dart
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (widget.answerActions != null) ...[
                        Align(alignment: Alignment.centerRight, child: widget.answerActions!),
                        const SizedBox(height: CgSpace.s1),
                      ],
                      if (widget.answerHeader != null) ...[
```

Aucun autre changement : un toucher (sans déplacement au-delà de `lockDistance`) ne produit pas de verdict dans `_onPointerUp`, comme pour les boutons de `CgVerdictBar` déjà présents dans la feuille. Si le test « ne juge jamais » échoue, lire `_onPointerUp` et exclure le pointeur posé sur `answerActions` (même technique que `_downOnAnswer` : un `Listener(onPointerDown: (_) => _downOnActions = true)` autour de l'emplacement, et `if (onActions) return;` dans `_onPointerDown` après la lecture des drapeaux).

- [ ] **Step 4: Lancer, vérifier le succès (fichier + dossier core)**

Run: `flutter test test/core/ui/components/cg_drill_card_test.dart` puis `flutter test test/core`
Expected: PASS. Les goldens de `CgDrillCard` ne changent pas (emplacement nul par défaut).

- [ ] **Step 5: Commit**

```bash
git add collega_app/lib/core/ui/components/cg_drill_card.dart collega_app/test/core/ui/components/cg_drill_card_test.dart
git commit -m "feat(avis-drill): emplacement answerActions en tête de la feuille de réponse

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Feuille de signalement partagée + `setCardFeedback`

**Files:**
- Create: `collega_app/lib/features/colleges/presentation/card_report.dart`
- Modify: `collega_app/lib/features/colleges/presentation/item_detail_screen.dart` (`_report` ~l. 278-311, `_askRegenerate`, `_explainOcr`, classe `_NoteBody` ~l. 390-413 supprimée)
- Modify: `collega_app/lib/features/drill/drill_providers.dart` (après `setSemanticFeedback`)
- Test: `collega_app/test/features/colleges/card_report_test.dart`, `collega_app/test/features/drill/drill_session_notifier_test.dart`

**Interfaces:**
- Produces:
  - `class CardNoteBody extends StatelessWidget { const CardNoteBody({super.key, required String message, ValueChanged<String>? onNote}); }` (ex-`_NoteBody`, inchangé).
  - `enum CardReportChoice { regenerate, later }`
  - `class CardReportResult { const CardReportResult(this.choice, this.note); final CardReportChoice choice; final String? note; }` — `note` rognée, `null` si vide.
  - `Future<CardReportResult> showCardReportSheet(BuildContext context, {required String message, required String regenerateLabel, required String laterLabel})` — feuille titrée « Signaler cette fiche » ; fermée sans choix → `CardReportChoice.later`.
  - `void DrillSessionNotifier.setCardFeedback(String cardId, String? feedback)` — met à jour `userFeedback` de la fiche dans `state.cards` (toutes ses occurrences dans la file partagent l'index).

- [ ] **Step 1: Écrire les tests qui échouent**

`test/features/colleges/card_report_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/features/colleges/presentation/card_report.dart';

import '../../support/cg_golden.dart';

void main() {
  Future<CardReportResult?> open(WidgetTester tester, Future<void> Function() act) async {
    CardReportResult? result;
    await tester.pumpWidget(cgTestApp(Builder(
      builder: (context) => GestureDetector(
        onTap: () async => result = await showCardReportSheet(
          context,
          message: 'Message.',
          regenerateLabel: 'Régénérer et continuer',
          laterLabel: 'Continuer sans régénérer',
        ),
        child: const Text('ouvrir'),
      ),
    )));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    await act();
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('titre, message, note facultative ; « Régénérer » renvoie la note rognée', (tester) async {
    final result = await open(tester, () async {
      expect(find.text('Signaler cette fiche'), findsOneWidget);
      expect(find.text('Message.'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), '  Réponse fausse  ');
      await tester.tap(find.text('Régénérer et continuer'));
    });
    expect(result?.choice, CardReportChoice.regenerate);
    expect(result?.note, 'Réponse fausse');
  });

  testWidgets('« Continuer sans régénérer » → later, note vide → null', (tester) async {
    final result = await open(tester, () => tester.tap(find.text('Continuer sans régénérer')));
    expect(result?.choice, CardReportChoice.later);
    expect(result?.note, isNull);
  });
}
```

Dans `test/features/drill/drill_session_notifier_test.dart`, ajouter dans `group('DrillSessionNotifier', ...)` :

```dart
    test('setCardFeedback : avis noté sur la fiche, gardé quand elle revient dans la file', () async {
      final container = _makeContainer(_makeCards(2));
      addTearDown(container.dispose);
      final notifier = container.read(drillSessionProvider(_params).notifier);
      await container.read(drillSessionProvider(_params).future);

      notifier.setCardFeedback('card-0', 'negative');
      var s = container.read(drillSessionProvider(_params)).requireValue;
      expect(s.currentCard!.userFeedback, 'negative');
      expect(s.cards[1].userFeedback, isNull);

      // 1er « à revoir » : la fiche est réinsérée plus loin, même index dans `cards`.
      notifier.flip();
      await notifier.evaluate(DrillEvaluationResult.aRevoir);
      notifier.advanceToNext();
      s = container.read(drillSessionProvider(_params)).requireValue;
      final again = s.queue.skip(s.currentQueuePos).map((i) => s.cards[i]).firstWhere((c) => c.id == 'card-0');
      expect(again.userFeedback, 'negative');
    });

    test('setCardFeedback : fiche inconnue → rien ne change', () async {
      final container = _makeContainer(_makeCards(1));
      addTearDown(container.dispose);
      await container.read(drillSessionProvider(_params).future);
      final before = container.read(drillSessionProvider(_params)).requireValue;
      container.read(drillSessionProvider(_params).notifier).setCardFeedback('absente', 'positive');
      expect(container.read(drillSessionProvider(_params)).requireValue.cards, before.cards);
    });
```

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `flutter test test/features/colleges/card_report_test.dart` puis `flutter test test/features/drill/drill_session_notifier_test.dart`
Expected: FAIL (fichier `card_report.dart` et méthode `setCardFeedback` absents).

- [ ] **Step 3: Implémenter `card_report.dart`**

```dart
import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/collega_ui.dart';

/// Texte d'une sheet, avec une note facultative (le champ gère son texte : rien
/// à libérer pendant l'animation de fermeture).
class CardNoteBody extends StatelessWidget {
  const CardNoteBody({super.key, required this.message, this.onNote});

  final String message;
  final ValueChanged<String>? onNote;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: CgSpace.s4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(message, style: CgType.body.copyWith(color: c.ink2)),
        if (onNote != null) ...[
          const SizedBox(height: CgSpace.s4),
          CgField(
            label: 'Qu’est-ce qui ne va pas ? (facultatif)',
            kind: CgFieldKind.multiline,
            onChanged: onNote,
          ),
        ],
      ]),
    );
  }
}

enum CardReportChoice { regenerate, later }

class CardReportResult {
  const CardReportResult(this.choice, this.note);

  final CardReportChoice choice;

  /// Remarque rognée ; null si vide.
  final String? note;
}

/// Feuille « Signaler cette fiche » (vue item et drill) : remarque facultative,
/// régénérer ou non. Jamais de suppression ici. Fermée sans choix = plus tard.
Future<CardReportResult> showCardReportSheet(
  BuildContext context, {
  required String message,
  required String regenerateLabel,
  required String laterLabel,
}) async {
  var note = '';
  final choice = await showCgSheet<CardReportChoice>(
    context,
    title: 'Signaler cette fiche',
    builder: (_) => CardNoteBody(message: message, onNote: (v) => note = v),
    primary: Builder(
      builder: (s) => CgButton(
        label: regenerateLabel,
        onPressed: () => Navigator.of(s, rootNavigator: true).pop(CardReportChoice.regenerate),
      ),
    ),
    secondary: Builder(
      builder: (s) => CgButton(
        label: laterLabel,
        variant: CgButtonVariant.quiet,
        onPressed: () => Navigator.of(s, rootNavigator: true).pop(CardReportChoice.later),
      ),
    ),
  );
  final text = note.trim();
  return CardReportResult(choice ?? CardReportChoice.later, text.isEmpty ? null : text);
}
```

- [ ] **Step 4: Brancher la vue item sur `card_report.dart`**

Dans `item_detail_screen.dart` : importer `package:collega_app/features/colleges/presentation/card_report.dart` ; supprimer la classe `_NoteBody` ; remplacer `_NoteBody(` par `CardNoteBody(` dans `_askRegenerate` et `_explainOcr` ; remplacer `_report` par :

```dart
  /// Pouce bas = signaler (spec v2) : le signalement est enregistré tout de
  /// suite ; régénérer est proposé, jamais supprimer.
  Future<void> _report(FlashCardModel card) async {
    CgHaptics.selection();
    // Envoyé tout de suite ; le résultat n'est dit qu'une fois connu.
    final sent = _notifier.submitNegativeFeedback(card.id).then((_) => true, onError: (Object _) => false);
    final result = await showCardReportSheet(
      context,
      message: 'Dis ce qui ne va pas : la fiche peut être régénérée en tenant compte de ta remarque.',
      regenerateLabel: 'Régénérer la fiche',
      laterLabel: 'Plus tard',
    );
    final ok = await sent;
    if (!mounted) return;
    if (!ok) showCgToast(context, 'Le signalement n’a pas pu s’enregistrer. Réessaie.');
    if (result.choice == CardReportChoice.regenerate) {
      await _regenerate(card, result.note);
    } else if (ok) {
      showCgToast(context, 'Fiche signalée');
    }
  }
```

- [ ] **Step 5: `setCardFeedback` dans `DrillSessionNotifier`** (après `setSemanticFeedback`)

```dart
  /// Avis donné pendant le drill (spec « avis pendant le drill ») : noté sur la
  /// fiche, qu'elle revienne ou non dans la file.
  void setCardFeedback(String cardId, String? feedback) {
    final s = state.value;
    if (s == null || !s.cards.any((c) => c.id == cardId)) return;
    state = AsyncValue.data(s.copyWith(
      cards: [for (final c in s.cards) c.id == cardId ? c.copyWith(userFeedback: feedback) : c],
    ));
  }
```

- [ ] **Step 6: Lancer, vérifier le succès**

Run: `flutter test test/features/colleges` puis `flutter test test/features/drill`
Expected: PASS, y compris `item_detail_screen_test.dart` inchangé (« pouce bas = signaler », « signaler puis Régénérer la fiche avec la note », « signalement non enregistré »).

- [ ] **Step 7: Commit**

```bash
git add collega_app/lib/features/colleges/presentation/card_report.dart collega_app/lib/features/colleges/presentation/item_detail_screen.dart collega_app/lib/features/drill/drill_providers.dart collega_app/test/features/colleges/card_report_test.dart collega_app/test/features/drill/drill_session_notifier_test.dart
git commit -m "refactor(avis-drill): feuille de signalement partagée, setCardFeedback du drill

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Avis dans l'écran de drill

**Files:**
- Modify: `collega_app/lib/features/drill/presentation/drill_screen.dart` (`_DrillActiveState`, `build` → `CgDrillCard(answerActions: …)`)
- Create: `collega_app/test/features/drill/drill_card_feedback_test.dart`
- Modify (goldens) : `collega_app/test/features/drill/goldens/drill_verso_*.png`

**Interfaces:**
- Consumes: `CgCardFeedback` (Task 1), `CgDrillCard.answerActions` (Task 2), `showCardReportSheet` / `CardReportChoice` (Task 3), `DrillSessionNotifier.setCardFeedback` (Task 3), `collegeDetailRepositoryProvider` et `itemDetailProvider` (`features/colleges/colleges_detail_providers.dart`), `CollegeDetailRepository.submitFeedback(String cardId, String feedback)` et `.regenerateCard(String cardId, {String? userNote})` (mettent déjà à jour Drift).
- Produces: rien pour d'autres tâches.

Décisions :
- Le chrono est déjà arrêté au verso (`DrillTimerSlot(running: !session.isFlipped)`) : rien à mettre en pause pendant la feuille.
- `itemDetailProvider` n'est pas `autoDispose` : après un avis ou une régénération, on l'invalide (clé `'${card.collegeId}:${card.itemId}'`) pour que la vue item relise le serveur.
- La régénération survit à la sortie du drill : on capture `ProviderScope.containerOf(context, listen: false)` avant tout `await` et on n'utilise plus `ref` ensuite.

- [ ] **Step 1: Écrire les tests qui échouent**

`test/features/drill/drill_card_feedback_test.dart` (reprend les faux de `drill_screen_test.dart`, qui sont privés à ce fichier) :

```dart
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/database/app_database.dart';
import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/colleges/colleges_detail_providers.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/data/college_detail_repository.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/drill/data/drill_repository.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';
import 'package:collega_app/features/drill/drill_launcher.dart';
import 'package:collega_app/features/drill/drill_providers.dart';
import 'package:collega_app/features/drill/presentation/drill_screen.dart';
import 'package:collega_app/features/profile/domain/revision_prefs.dart';
import 'package:collega_app/features/profile/profile_providers.dart';
import 'package:collega_app/features/today/today_providers.dart';

class _DrillRepo extends DrillRepository {
  _DrillRepo(this.cards) : super(dio: Dio(), db: AppDatabase.forTesting(NativeDatabase.memory()));
  final List<FlashCardModel> cards;
  final updated = <String, DrillEvaluationResult>{};
  @override
  Future<List<FlashCardModel>> getCardsForDrill({
    required String collegeId, String? itemId, List<String>? rangs, bool onlyARevoir = false, int maxCards = 0,
  }) async => List.of(cards);
  @override
  Future<void> updateCardDrillLevel(String cardId, DrillEvaluationResult result) async => updated[cardId] = result;
}

class _CardsRepo extends CollegeDetailRepository {
  _CardsRepo({this.offline = false, this.regenGate, this.regenFails = false})
      : super(dio: Dio(), db: AppDatabase.forTesting(NativeDatabase.memory()));
  final bool offline;
  final Completer<void>? regenGate;
  final bool regenFails;
  final feedbacks = <String>[];
  final regenerated = <(String, String?)>[];

  DioException get _net => DioException(requestOptions: RequestOptions(path: '/x'), type: DioExceptionType.connectionError);

  @override
  Future<void> submitFeedback(String cardId, String feedback) async {
    feedbacks.add('$cardId:$feedback');
    if (offline) throw _net;
  }

  @override
  Future<FlashCardModel> regenerateCard(String cardId, {String? userNote}) async {
    regenerated.add((cardId, userNote));
    await regenGate?.future;
    if (regenFails) throw _net;
    return _card(0).copyWith(recto: 'Question régénérée ?');
  }
}

class _Today extends TodayNotifier {
  @override
  Future<TodayState> build() async => const TodayNoCollege();
}

class _Prefs extends RevisionPrefsNotifier {
  @override
  Future<RevisionPrefs> build() async => const RevisionPrefs();
}

class _Colleges extends CollegesNotifier {
  @override
  Future<List<CollegeListEntry>> build() async => [
        for (final c in kCollegeCatalog)
          CollegeListEntry(
            catalog: c,
            userStatus: c.refId == 3
                ? const UserCollegeStatus(refId: 3, collegeId: 'c3', status: 'generation_complete', cardCountA: 3, cardCountB: 0, cardCountC: 0)
                : null,
          ),
      ];
}

FlashCardModel _card(int i, {String? feedback}) => FlashCardModel(
      id: 'card-$i', itemId: 'i1', collegeId: 'c3', cardType: 'classique', rang: 'A',
      recto: 'Question $i ?', verso: 'Réponse $i.', ocrConfidenceScore: 1, lowConfidence: false,
      userFeedback: feedback,
    );

const _params = DrillSessionParams(collegeId: 'c3', itemId: 'i1', itemName: 'Tumeurs du testicule');

late ProviderContainer _container;

Widget _app(_DrillRepo drill, _CardsRepo cards, {List<String>? visited}) {
  final router = GoRouter(initialLocation: '/drill', routes: [
    GoRoute(path: '/home', builder: (_, __) { visited?.add('/home'); return const SizedBox(); }),
    GoRoute(path: '/drill', builder: (_, __) => const DrillScreen(launch: DrillLaunch(params: _params))),
  ]);
  _container = ProviderContainer(overrides: [
    todayProvider.overrideWith(_Today.new),
    drillRepositoryProvider.overrideWithValue(drill),
    collegeDetailRepositoryProvider.overrideWithValue(cards),
    revisionPrefsProvider.overrideWith(_Prefs.new),
    collegesProvider.overrideWith(_Colleges.new),
  ]);
  addTearDown(_container.dispose);
  return UncontrolledProviderScope(
    container: _container,
    child: CgTheme(
      data: CgThemeData.light,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: buildCgMaterialTheme(CgThemeData.light),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    ),
  );
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _flip(WidgetTester tester) async {
  await tester.tap(find.byType(CgDrillCard));
  await tester.pumpAndSettle();
}

bool _selected(WidgetTester tester, Key key) =>
    tester.getSemantics(find.byKey(key)).hasFlag(SemanticsFlag.isSelected);

void main() {
  testWidgets('recto : pas d’avis ; verso : les deux icônes', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_DrillRepo([_card(0), _card(1)]), _CardsRepo()));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Fiche utile'), findsNothing);
    await _flip(tester);
    expect(find.bySemanticsLabel('Fiche utile'), findsOneWidget);
    expect(find.bySemanticsLabel('Signaler la fiche'), findsOneWidget);
  });

  testWidgets('avis déjà donné (Drift) : affiché choisi', (tester) async {
    _phone(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_DrillRepo([_card(0, feedback: 'positive')]), _CardsRepo()));
    await tester.pumpAndSettle();
    await _flip(tester);
    expect(_selected(tester, CgCardFeedback.usefulKey), isTrue);
    expect(_selected(tester, CgCardFeedback.reportKey), isFalse);
    handle.dispose();
  });

  testWidgets('« Utile » : enregistré, choisi, aucun verdict, la fiche reste', (tester) async {
    _phone(tester);
    final handle = tester.ensureSemantics();
    final drill = _DrillRepo([_card(0), _card(1)]);
    final cards = _CardsRepo();
    await tester.pumpWidget(_app(drill, cards));
    await tester.pumpAndSettle();
    await _flip(tester);
    await tester.tap(find.byKey(CgCardFeedback.usefulKey));
    await tester.pumpAndSettle();
    expect(cards.feedbacks, ['card-0:positive']);
    expect(_selected(tester, CgCardFeedback.usefulKey), isTrue);
    expect(drill.updated, isEmpty);
    expect(find.text('Réponse 0.'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('« Utile » hors ligne : toast, pas choisi', (tester) async {
    _phone(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_DrillRepo([_card(0)]), _CardsRepo(offline: true)));
    await tester.pumpAndSettle();
    await _flip(tester);
    await tester.tap(find.byKey(CgCardFeedback.usefulKey));
    await tester.pump();
    expect(find.text('Ton retour n’a pas pu s’enregistrer. Réessaie.'), findsOneWidget);
    expect(_selected(tester, CgCardFeedback.usefulKey), isFalse);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    handle.dispose();
  });

  testWidgets('« À corriger » → feuille ; « Continuer sans régénérer » → « Fiche signalée », drill intact', (tester) async {
    _phone(tester);
    final drill = _DrillRepo([_card(0), _card(1)]);
    final cards = _CardsRepo();
    await tester.pumpWidget(_app(drill, cards));
    await tester.pumpAndSettle();
    await _flip(tester);
    await tester.tap(find.byKey(CgCardFeedback.reportKey));
    await tester.pumpAndSettle();
    expect(cards.feedbacks, ['card-0:negative']);
    expect(find.text('Signaler cette fiche'), findsOneWidget);
    await tester.tap(find.text('Continuer sans régénérer'));
    await tester.pump();
    expect(find.text('Fiche signalée'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(cards.regenerated, isEmpty);
    expect(drill.updated, isEmpty);
    expect(find.text('Réponse 0.'), findsOneWidget);
    await tester.tap(find.byKey(CgVerdictBar.buttonKey(CgVerdict.mastered)));
    await tester.pumpAndSettle();
    expect(drill.updated['card-0'], DrillEvaluationResult.maitrise);
  });

  testWidgets('« Régénérer et continuer » : non bloquant, note transmise, on juge la même fiche', (tester) async {
    _phone(tester);
    final gate = Completer<void>();
    final drill = _DrillRepo([_card(0), _card(1)]);
    final cards = _CardsRepo(regenGate: gate);
    await tester.pumpWidget(_app(drill, cards));
    await tester.pumpAndSettle();
    await _flip(tester);
    await tester.tap(find.byKey(CgCardFeedback.reportKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Dose fausse');
    await tester.tap(find.text('Régénérer et continuer'));
    await tester.pump();
    expect(cards.regenerated, [('card-0', 'Dose fausse')]);
    expect(find.text('Nouvelle version en préparation'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    // Régénération toujours en cours : la fiche courante se juge normalement.
    expect(find.text('Réponse 0.'), findsOneWidget);
    await tester.tap(find.byKey(CgVerdictBar.buttonKey(CgVerdict.good)));
    await tester.pumpAndSettle();
    expect(drill.updated['card-0'], DrillEvaluationResult.bien);
    gate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('régénération en échec : toast dédié', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_DrillRepo([_card(0), _card(1)]), _CardsRepo(regenFails: true)));
    await tester.pumpAndSettle();
    await _flip(tester);
    await tester.tap(find.byKey(CgCardFeedback.reportKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Régénérer et continuer'));
    await tester.pumpAndSettle();
    expect(find.text('La régénération a échoué. Réessaie plus tard depuis la fiche de l’item.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('quitter pendant la régénération : aucune exception, résultat ignoré', (tester) async {
    _phone(tester);
    final gate = Completer<void>();
    final visited = <String>[];
    await tester.pumpWidget(_app(_DrillRepo([_card(0), _card(1)]), _CardsRepo(regenGate: gate), visited: visited));
    await tester.pumpAndSettle();
    await _flip(tester);
    await tester.tap(find.byKey(CgCardFeedback.reportKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Régénérer et continuer'));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(CgDrillCard.closeKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitter'));
    await tester.pumpAndSettle();
    expect(visited, ['/home']);
    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('après un avis, la vue item relira le serveur (itemDetailProvider invalidé)', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app(_DrillRepo([_card(0)]), _CardsRepo()));
    await tester.pumpAndSettle();
    var builds = 0;
    // Compte les reconstructions via un provider dérivé.
    final sub = _container.listen<int>(
      Provider<int>((ref) {
        ref.watch(itemDetailProvider('c3:i1'));
        return ++builds;
      }),
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    final before = builds;
    await _flip(tester);
    await tester.tap(find.byKey(CgCardFeedback.usefulKey));
    await tester.pumpAndSettle();
    expect(builds, greaterThan(before));
  });
}
```

Note pour le dernier test : `_CardsRepo.getCards` n'est pas surchargé ; `itemDetailProvider` retombera sur `getCardsFromDrift` (base en mémoire vide) puis `rethrow` — c'est sans importance, seule l'invalidation est observée. Si le `Provider` anonyme gêne l'analyseur, le déclarer en `final _probe = Provider<int>(...)` au niveau du fichier avec un compteur global remis à zéro dans le test.

- [ ] **Step 2: Lancer, vérifier l'échec**

Run: `flutter test test/features/drill/drill_card_feedback_test.dart`
Expected: FAIL (aucune icône d'avis au verso).

- [ ] **Step 3: Implémenter dans `drill_screen.dart`**

Imports à ajouter :

```dart
import 'dart:async';

import 'package:collega_app/core/utils/logger.dart';
import 'package:collega_app/features/colleges/colleges_detail_providers.dart';
import 'package:collega_app/features/colleges/data/college_detail_repository.dart';
import 'package:collega_app/features/colleges/presentation/card_report.dart';
```

Dans `_DrillActiveState`, ajouter :

```dart
  // ─── Avis sur la fiche (spec « avis pendant le drill ») ─────────────────────

  /// La vue item n'est pas autoDispose : elle relira le serveur à sa prochaine ouverture.
  static void _refreshItem(ProviderContainer container, FlashCardModel card) =>
      container.invalidate(itemDetailProvider('${card.collegeId}:${card.itemId}'));

  Future<void> _useful(FlashCardModel card) async {
    CgHaptics.selection();
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      await container.read(collegeDetailRepositoryProvider).submitFeedback(card.id, 'positive');
    } catch (_) {
      if (mounted) showCgToast(context, 'Ton retour n’a pas pu s’enregistrer. Réessaie.');
      return;
    }
    _refreshItem(container, card);
    if (mounted) _notifier.setCardFeedback(card.id, 'positive');
  }

  /// Pouce bas = signaler : enregistré tout de suite ; régénérer part en
  /// arrière-plan, le drill reste sur la fiche.
  Future<void> _report(FlashCardModel card) async {
    CgHaptics.selection();
    final container = ProviderScope.containerOf(context, listen: false);
    final repo = container.read(collegeDetailRepositoryProvider);
    final sent = repo.submitFeedback(card.id, 'negative').then((_) => true, onError: (Object _) => false);
    final result = await showCardReportSheet(
      context,
      message: 'Dis ce qui ne va pas : une nouvelle version sera préparée pendant que tu continues ton drill.',
      regenerateLabel: 'Régénérer et continuer',
      laterLabel: 'Continuer sans régénérer',
    );
    final ok = await sent;
    if (ok) _refreshItem(container, card);
    if (!mounted) return;
    if (ok) _notifier.setCardFeedback(card.id, 'negative');
    if (!ok) showCgToast(context, 'Le signalement n’a pas pu s’enregistrer. Réessaie.');
    if (result.choice == CardReportChoice.regenerate) {
      unawaited(_regenerate(container, repo, card, result.note));
      if (ok) showCgToast(context, 'Nouvelle version en préparation');
    } else if (ok) {
      showCgToast(context, 'Fiche signalée');
    }
  }

  /// Survit à la sortie du drill : ni `ref` ni `context` après l'attente, sauf
  /// si l'écran est encore monté. La nouvelle fiche est déjà écrite dans Drift
  /// par le dépôt (sessions suivantes) ; la session en cours garde l'ancienne.
  Future<void> _regenerate(
    ProviderContainer container,
    CollegeDetailRepository repo,
    FlashCardModel card,
    String? note,
  ) async {
    try {
      await repo.regenerateCard(card.id, userNote: note);
      _refreshItem(container, card);
    } catch (e) {
      AppLogger.error('régénération depuis le drill', tag: 'Drill', error: e);
      if (mounted) showCgToast(context, 'La régénération a échoué. Réessaie plus tard depuis la fiche de l’item.');
    }
  }
```

Dans `build`, passer à `CgDrillCard` (à côté de `answerHeader:`) :

```dart
        answerActions: CgCardFeedback(
          feedback: card.userFeedback,
          onUseful: () => _useful(card),
          onReport: () => _report(card),
        ),
```

Vérifier que `showCgToast` accepte l'enchaînement de deux toasts (« Le signalement… » puis rien, ou « Nouvelle version… ») : dans le cas `!ok` + régénérer, un seul toast (l'échec du signalement) est montré, ce qui est voulu.

- [ ] **Step 4: Lancer, vérifier le succès**

Run: `flutter test test/features/drill/drill_card_feedback_test.dart`
Expected: PASS (10 tests).

- [ ] **Step 5: Régénérer et contrôler les goldens du verso**

Run: `flutter test --update-goldens --tags golden test/features/drill/drill_screen_test.dart`
Puis ouvrir `test/features/drill/goldens/drill_verso_*.png` : les deux pouces apparaissent en haut à droite de la feuille, rien ne déborde à 375 pt et Dynamic Type max ; recto, définition et timer inchangés (`git diff --stat` ne doit lister que les `drill_verso_*`).

- [ ] **Step 6: Suites par dossier**

Run: `flutter test test/core`, `flutter test test/features/drill`, `flutter test test/features/colleges`
Expected: PASS partout (dont « accessibilité au verso » et « Dynamic Type 1,6 sur 375 » de `drill_screen_test.dart`).

- [ ] **Step 7: Commit**

```bash
git add collega_app/lib/features/drill/presentation/drill_screen.dart collega_app/test/features/drill/drill_card_feedback_test.dart collega_app/test/features/drill/goldens
git commit -m "feat(avis-drill): pouces Utile / À corriger au verso du drill, régénération non bloquante

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

## Auto-revue (faite)

- Couverture de la spec C : emplacement au verso (T2, T4) ; icônes seules + état choisi `accent`/`accentSoft` + VoiceOver (T1) ; avis existant affiché (T4) ; toucher ≠ geste (T2, T4) ; « Utile » + toast d'échec (T4) ; feuille « À corriger » avec « Régénérer et continuer » / « Continuer sans régénérer » (T3, T4) ; régénération non bloquante, nouvelle fiche dans Drift pour les sessions suivantes (T4, via `regenerateCard` → `syncCardsToDrift`) ; chrono : déjà arrêté au verso, documenté (T4) ; refacto partagée (T3) ; `CgDrillCard` reste générique (T2) ; vue item toujours verte (T3 step 6).
- Écarts assumés avec la spec : pas de libellé « Réponse » dans la feuille (icônes sur une rangée alignée à droite) ; pas de « service » dédié : `CollegeDetailRepository` met déjà Drift à jour, le drill l'appelle directement.
- Noms croisés vérifiés : `CgCardFeedback.usefulKey/reportKey`, `answerActions`, `showCardReportSheet`, `CardReportChoice`, `CardReportResult.note`, `setCardFeedback(String, String?)`, `CardNoteBody`.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/components/cg_drill_card.dart';
import 'package:collega_app/core/ui/components/cg_verdict_bar.dart';
import 'package:collega_app/core/ui/gallery/cg_drill_card_gallery.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';

import '../../../support/cg_golden.dart';

const c = CgColors.light;
const _w = 393.0;
const _h = 844.0;
const _question = 'Quel est le schéma vaccinal contre HPV (Gardasil 9) recommandé en France ?';
const _answer = 'Filles et garçons dès 11 ans : 2 doses entre 11 et 14 ans, 3 doses entre 15 et 19 ans.';
const _gestureHint = "Glisse à droite si tu maîtrises, à gauche pour revoir, vers le haut si c'est bien";
final _longAnswer = List.filled(30, 'Rattrapage jusqu\'à 26 ans pour les HSH, prise en charge à 65 %.').join(' ');

/// Écran iPhone 15 (393 × 844) : les seuils se calculent sur ces dimensions.
void _phone(WidgetTester tester, {double width = _w, double height = _h}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Enregistre les appels `HapticFeedback.vibrate` (canal plateforme).
List<String> _recordHaptics() {
  final calls = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') calls.add(call.arguments as String);
    return null;
  });
  addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return calls;
}

Widget _card({
  List<CgVerdict>? verdicts,
  VoidCallback? onFlip,
  VoidCallback? onClose,
  bool canFlip = true,
  bool flipped = false,
  bool reduced = false,
  double textScale = 1,
  String question = _question,
  String answer = _answer,
  int index = 3,
  int total = 24,
  Key? key,
}) =>
    cgTestApp(
      CgDrillCard(
        key: key,
        question: question,
        answer: answer,
        rank: 'A',
        collegeName: 'Cancérologie',
        index: index,
        total: total,
        onVerdict: (v) => verdicts?.add(v),
        onClose: onClose ?? () {},
        canFlip: canFlip,
        onFlip: onFlip,
        initiallyFlipped: flipped,
      ),
      disableAnimations: reduced,
      textScale: textScale,
    );

CgDrillCardState _state(WidgetTester tester) => tester.state<CgDrillCardState>(find.byType(CgDrillCard));

double _previewOpacity(WidgetTester tester, CgVerdict v) =>
    tester.widget<Opacity>(find.byKey(CgDrillCard.previewKey(v))).opacity;

/// Point de départ d'un geste sur la feuille, hors texte défilable (l'invite de geste).
Offset _sheetGrip(WidgetTester tester) => tester.getCenter(find.text(_gestureHint));

void main() {
  group('recto', () {
    testWidgets('anatomie : ✕, compteur, contexte, rang, collège, question, invite ; réponse cachée', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_card());
      expect(find.text('3 / 24'), findsOneWidget);
      expect(find.text('Session du jour'), findsOneWidget);
      expect(find.text('Rang A'), findsOneWidget);
      expect(find.text('Cancérologie'), findsOneWidget);
      expect(find.text(_question), findsOneWidget);
      expect(find.text('Touche pour voir la réponse'), findsOneWidget);
      // La feuille de réponse attend sous l'écran.
      expect(tester.getRect(find.text(_answer)).top, greaterThanOrEqualTo(_h));
      expect(_state(tester).isFlipped, isFalse);
      // Question 30/600 (largeur ≥ 390).
      final style = tester.widget<DefaultTextStyle>(
        find.ancestor(of: find.text(_question), matching: find.byType(DefaultTextStyle)).first,
      ).style;
      expect(style.fontSize, 30);
      expect(style.fontWeight, FontWeight.w600);
    });

    testWidgets('question 26 pt sous 390 de large', (tester) async {
      _phone(tester, width: 375);
      await tester.pumpWidget(_card());
      final style = tester.widget<DefaultTextStyle>(
        find.ancestor(of: find.text(_question), matching: find.byType(DefaultTextStyle)).first,
      ).style;
      expect(style.fontSize, 26);
    });

    testWidgets('barre segmentée : un segment par fiche, pleins jusqu\'à index − 1', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_card());
      final segments = tester
          .widgetList<AnimatedContainer>(find.descendant(
            of: find.byKey(CgDrillCard.progressKey),
            matching: find.byType(AnimatedContainer),
          ))
          .toList();
      expect(segments, hasLength(24));
      final on = segments.where((s) => (s.decoration as BoxDecoration?)?.color == c.accentInk).length;
      expect(on, 2);
    });

    testWidgets('au-delà de 40 fiches : barre continue', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_card(index: 11, total: 100));
      final bar = tester.widget<FractionallySizedBox>(find.descendant(
        of: find.byKey(CgDrillCard.progressKey),
        matching: find.byType(FractionallySizedBox),
      ));
      expect(bar.widthFactor, closeTo(0.1, 1e-9));
    });

    testWidgets('tap → verso : réponse visible, question en bandeau, haptique flip, onFlip', (tester) async {
      _phone(tester);
      final calls = _recordHaptics();
      var flips = 0;
      await tester.pumpWidget(_card(onFlip: () => flips++));
      await tester.tap(find.text(_question));
      await tester.pumpAndSettle();
      expect(_state(tester).isFlipped, isTrue);
      expect(flips, 1);
      expect(calls, ['HapticFeedbackType.lightImpact']);
      final answer = tester.getRect(find.text(_answer));
      expect(answer.bottom, lessThan(_h));
      expect(answer.top, greaterThan(_h * 0.31));
      final style = tester.widget<DefaultTextStyle>(
        find.ancestor(of: find.text(_question), matching: find.byType(DefaultTextStyle)).first,
      ).style;
      expect(style.fontSize, 17);
      expect(style.fontWeight, FontWeight.w500);
      // La question reste visible, au-dessus de la feuille.
      expect(tester.getRect(find.text(_question)).top, lessThan(_h * 0.31));
      // Un second tap ne rejoue rien.
      await tester.tap(find.text(_question));
      await tester.pumpAndSettle();
      expect(flips, 1);
    });

    testWidgets('canFlip: false empêche le tap ; flip() public retourne quand même', (tester) async {
      _phone(tester);
      var flips = 0;
      await tester.pumpWidget(_card(canFlip: false, onFlip: () => flips++));
      await tester.tap(find.text(_question));
      await tester.pumpAndSettle();
      expect(_state(tester).isFlipped, isFalse);
      expect(flips, 0);
      _state(tester).flip();
      await tester.pumpAndSettle();
      expect(_state(tester).isFlipped, isTrue);
      expect(flips, 1);
    });

    for (final (name, delta) in [
      ('horizontal', const Offset(-300, 0)),
      ('vertical', const Offset(0, -400)),
    ]) {
      testWidgets('drag $name : jamais de verdict, translation bornée à 8 pt puis retour, invite renforcée', (tester) async {
        _phone(tester);
        final verdicts = <CgVerdict>[];
        await tester.pumpWidget(_card(verdicts: verdicts));
        final gesture = await tester.startGesture(tester.getCenter(find.text(_question)));
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(delta / 10);
          await tester.pump();
          expect(_state(tester).dragOffset.distance, lessThanOrEqualTo(8));
        }
        expect(_state(tester).dragOffset.distance, 8);
        final hint = tester.widget<AnimatedOpacity>(
          find.ancestor(of: find.text('Touche pour voir la réponse'), matching: find.byType(AnimatedOpacity)),
        );
        expect(hint.opacity, 1);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(_state(tester).dragOffset, Offset.zero);
        expect(_state(tester).isFlipped, isFalse);
        expect(verdicts, isEmpty);
      });
    }
  });

  group('verso — gestes', () {
    for (final (name, delta, verdict) in [
      ('gauche au-delà de 35 % → à revoir', const Offset(-_w * 0.4, 0), CgVerdict.review),
      ('droite au-delà de 35 % → maîtrisé', const Offset(_w * 0.4, 0), CgVerdict.mastered),
      ('haut au-delà de 25 % → bien', const Offset(0, -_h * 0.3), CgVerdict.good),
    ]) {
      testWidgets(name, (tester) async {
        _phone(tester);
        final calls = _recordHaptics();
        final verdicts = <CgVerdict>[];
        await tester.pumpWidget(_card(verdicts: verdicts, flipped: true));
        await tester.dragFrom(_sheetGrip(tester), delta);
        await tester.pump(const Duration(milliseconds: 50));
        // onVerdict attend la fin de la sortie.
        expect(verdicts, isEmpty);
        await tester.pumpAndSettle();
        expect(verdicts, [verdict]);
        expect(calls, [
          switch (verdict) {
            CgVerdict.review => 'HapticFeedbackType.mediumImpact',
            CgVerdict.good => 'HapticFeedbackType.lightImpact',
            CgVerdict.mastered => 'HapticFeedbackType.heavyImpact',
          },
        ]);
      });
    }

    testWidgets('bas : aucun verdict, retour', (tester) async {
      _phone(tester);
      final verdicts = <CgVerdict>[];
      await tester.pumpWidget(_card(verdicts: verdicts, flipped: true));
      await tester.dragFrom(_sheetGrip(tester), const Offset(0, _h * 0.4));
      await tester.pumpAndSettle();
      expect(verdicts, isEmpty);
      expect(_state(tester).dragOffset, Offset.zero);
    });

    for (final (name, delta) in [
      ('gauche', const Offset(-_w * 0.3, 0)),
      ('droite', const Offset(_w * 0.3, 0)),
      ('haut', const Offset(0, -_h * 0.2)),
    ]) {
      testWidgets('sous le seuil ($name) : retour élastique, aucun verdict', (tester) async {
        _phone(tester);
        final verdicts = <CgVerdict>[];
        await tester.pumpWidget(_card(verdicts: verdicts, flipped: true));
        await tester.dragFrom(_sheetGrip(tester), delta);
        await tester.pump();
        expect(_state(tester).dragOffset, isNot(Offset.zero));
        await tester.pumpAndSettle();
        expect(_state(tester).dragOffset, Offset.zero);
        expect(verdicts, isEmpty);
      });
    }

    testWidgets('direction verrouillée après 12 pt : un drag parti horizontal ne devient pas vertical', (tester) async {
      _phone(tester);
      final verdicts = <CgVerdict>[];
      await tester.pumpWidget(_card(verdicts: verdicts, flipped: true));
      final gesture = await tester.startGesture(_sheetGrip(tester));
      await gesture.moveBy(const Offset(14, 0));
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        await gesture.moveBy(const Offset(0, -50));
        await tester.pump();
      }
      expect(_state(tester).dragOffset.dy, 0);
      expect(_state(tester).dragOffset.dx, 14);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(verdicts, isEmpty);
    });

    testWidgets('prévisualisation : étiquette invisible sous 40 pt, visible au-delà', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_card(flipped: true));
      for (final (v, dir) in [
        (CgVerdict.review, const Offset(-1, 0)),
        (CgVerdict.mastered, const Offset(1, 0)),
        (CgVerdict.good, const Offset(0, -1)),
      ]) {
        final gesture = await tester.startGesture(_sheetGrip(tester));
        await gesture.moveBy(dir * 36);
        await tester.pump();
        expect(_previewOpacity(tester, v), 0, reason: '${v.name} à 36 pt');
        await gesture.moveBy(dir * 64); // 100 pt : (100 − 40) / 80
        await tester.pump();
        expect(_previewOpacity(tester, v), closeTo(0.75, 1e-6), reason: '${v.name} à 100 pt');
        for (final other in CgVerdict.values.where((o) => o != v)) {
          expect(_previewOpacity(tester, other), 0, reason: '${other.name} pendant ${v.name}');
        }
        await gesture.moveBy(dir * 30); // 130 pt : pleine opacité au-delà de 120 pt
        await tester.pump();
        expect(_previewOpacity(tester, v), 1);
        await gesture.moveTo(_sheetGrip(tester));
        await gesture.up();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('rotation légère : x / largeur × 6°', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_card(flipped: true));
      final gesture = await tester.startGesture(_sheetGrip(tester));
      await gesture.moveBy(const Offset(_w / 4, 0));
      await tester.pump();
      expect(_state(tester).dragRotation, closeTo(0.25 * 6 * 3.141592653589793 / 180, 1e-9));
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('sur le verso, un drag hors de la feuille (bandeau) ne fait rien', (tester) async {
      _phone(tester);
      final verdicts = <CgVerdict>[];
      await tester.pumpWidget(_card(verdicts: verdicts, flipped: true));
      await tester.dragFrom(tester.getCenter(find.text(_question)), const Offset(-_w * 0.5, 0));
      await tester.pumpAndSettle();
      expect(verdicts, isEmpty);
    });
  });

  group('verso — boutons', () {
    for (final (v, label, haptic, sign) in [
      (CgVerdict.review, 'À revoir', 'HapticFeedbackType.mediumImpact', -1.0),
      (CgVerdict.good, 'Bien', 'HapticFeedbackType.lightImpact', 0.0),
      (CgVerdict.mastered, 'Maîtrisé', 'HapticFeedbackType.heavyImpact', 1.0),
    ]) {
      testWidgets('« $label » : même verdict, même sortie, haptique distincte', (tester) async {
        _phone(tester);
        final calls = _recordHaptics();
        final verdicts = <CgVerdict>[];
        await tester.pumpWidget(_card(verdicts: verdicts, flipped: true));
        await tester.tap(find.byKey(CgVerdictBar.buttonKey(v)));
        await tester.pump(); // première frame du ticker
        await tester.pump(const Duration(milliseconds: 120));
        final offset = _state(tester).dragOffset;
        if (sign == 0) {
          expect(offset.dy, lessThan(0), reason: 'bien sort vers le haut');
          expect(offset.dx, 0);
        } else {
          expect(offset.dx.sign, sign);
          expect(offset.dy, 0);
        }
        expect(verdicts, isEmpty);
        await tester.pumpAndSettle();
        expect(verdicts, [v]);
        expect(calls, [haptic]);
      });
    }

    testWidgets('pendant la sortie, un second tap est ignoré', (tester) async {
      _phone(tester);
      final verdicts = <CgVerdict>[];
      await tester.pumpWidget(_card(verdicts: verdicts, flipped: true));
      await tester.tap(find.byKey(CgVerdictBar.buttonKey(CgVerdict.mastered)));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.byKey(CgVerdictBar.buttonKey(CgVerdict.review)), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(verdicts, [CgVerdict.mastered]);
    });

    testWidgets('une seule fiche : nouvelle question → retour au recto', (tester) async {
      _phone(tester);
      final verdicts = <CgVerdict>[];
      await tester.pumpWidget(_card(verdicts: verdicts, flipped: true));
      await tester.tap(find.byKey(CgVerdictBar.buttonKey(CgVerdict.good)));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_card(verdicts: verdicts, question: 'Question suivante ?', index: 4));
      await tester.pumpAndSettle();
      expect(_state(tester).isFlipped, isFalse);
      expect(_state(tester).dragOffset, Offset.zero);
      expect(find.text('4 / 24'), findsOneWidget);
      expect(tester.getRect(find.text(_answer)).top, greaterThanOrEqualTo(_h));
    });
  });

  group('mouvement réduit', () {
    testWidgets('retournement en fondu (pas de glissement)', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_card(reduced: true));
      await tester.tap(find.text(_question));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      final opacity = tester.widget<Opacity>(find.byKey(CgDrillCard.sheetKey)).opacity;
      expect(opacity, greaterThan(0));
      expect(opacity, lessThan(1));
      final mid = tester.getRect(find.text(_answer)).top;
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text(_answer)).top, mid);
    });

    testWidgets('pas de rotation, sortie en fondu, verdict toujours émis', (tester) async {
      _phone(tester);
      final verdicts = <CgVerdict>[];
      await tester.pumpWidget(_card(verdicts: verdicts, flipped: true, reduced: true));
      final gesture = await tester.startGesture(_sheetGrip(tester));
      await gesture.moveBy(const Offset(_w * 0.2, 0));
      await gesture.moveBy(const Offset(_w * 0.2, 0));
      await tester.pump();
      expect(_state(tester).dragRotation, 0);
      await gesture.up();
      await tester.pump(); // première frame du ticker
      await tester.pump(const Duration(milliseconds: 75));
      final opacity = tester.widget<Opacity>(find.byKey(CgDrillCard.sheetKey)).opacity;
      expect(opacity, greaterThan(0));
      expect(opacity, lessThan(1));
      await tester.pumpAndSettle();
      expect(verdicts, [CgVerdict.mastered]);

      // Boutons aussi.
      await tester.pumpWidget(_card(verdicts: verdicts, flipped: true, reduced: true, key: const Key('b')));
      await tester.tap(find.byKey(CgVerdictBar.buttonKey(CgVerdict.review)));
      await tester.pumpAndSettle();
      expect(verdicts, [CgVerdict.mastered, CgVerdict.review]);
    });
  });

  group('Semantics', () {
    testWidgets('carte, invite, ✕ et trois verdicts', (tester) async {
      _phone(tester);
      final handle = tester.ensureSemantics();
      var closes = 0;
      await tester.pumpWidget(_card(onClose: () => closes++));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Fiche rang A, Cancérologie. Question : $_question')),
        containsSemantics(
          label: 'Fiche rang A, Cancérologie. Question : $_question',
          hint: 'Touche pour voir la réponse',
          hasTapAction: true,
        ),
      );
      final close = find.bySemanticsLabel('Quitter la session');
      expect(tester.getSemantics(close), containsSemantics(isButton: true, hasTapAction: true));
      expect(tester.getSize(find.byKey(CgDrillCard.closeKey)), const Size(44, 44));
      await tester.tap(find.byKey(CgDrillCard.closeKey));
      expect(closes, 1);
      // Recto : la réponse et les verdicts ne sont pas lus.
      expect(find.bySemanticsLabel('Maîtrisé'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Filles et garçons')), findsNothing);

      _state(tester).flip();
      await tester.pumpAndSettle();
      for (final label in ['À revoir', 'Bien', 'Maîtrisé']) {
        expect(
          tester.getSemantics(find.bySemanticsLabel(label)),
          containsSemantics(isButton: true, hasTapAction: true),
          reason: label,
        );
      }
      expect(find.bySemanticsLabel(RegExp('Filles et garçons')), findsOneWidget);
      handle.dispose();
    });
  });

  group('Dynamic Type et réponse longue', () {
    testWidgets('1,6 sur 375 : question longue lisible, sans débordement', (tester) async {
      _phone(tester, width: 375);
      final long = List.filled(4, _question).join(' ');
      await tester.pumpWidget(_card(textScale: 1.6, question: long));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      _state(tester).flip();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('2,0 : verdicts empilés dans la feuille, sans débordement', (tester) async {
      _phone(tester, width: 375);
      await tester.pumpWidget(_card(textScale: 2, flipped: true, answer: _longAnswer));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final review = tester.getRect(find.byKey(CgVerdictBar.buttonKey(CgVerdict.review)));
      final good = tester.getRect(find.byKey(CgVerdictBar.buttonKey(CgVerdict.good)));
      expect(review.bottom, lessThanOrEqualTo(good.top));
    });

    testWidgets('réponse longue : un glissé vertical sur le texte le fait défiler, jamais « bien »', (tester) async {
      _phone(tester);
      final verdicts = <CgVerdict>[];
      await tester.pumpWidget(_card(verdicts: verdicts, flipped: true, answer: _longAnswer));
      final before = tester.getRect(find.text(_longAnswer)).top;
      await tester.dragFrom(tester.getCenter(find.byKey(CgDrillCard.answerKey)), const Offset(0, -_h * 0.3));
      await tester.pumpAndSettle();
      expect(verdicts, isEmpty);
      expect(tester.getRect(find.text(_longAnswer)).top, lessThan(before), reason: 'la réponse a défilé');
      expect(_state(tester).dragOffset, Offset.zero);
    });

    testWidgets('réponse longue : « bien » par glissé vers le haut depuis la feuille hors texte', (tester) async {
      _phone(tester);
      final verdicts = <CgVerdict>[];
      await tester.pumpWidget(_card(verdicts: verdicts, flipped: true, answer: _longAnswer));
      await tester.dragFrom(_sheetGrip(tester), const Offset(0, -_h * 0.3));
      await tester.pumpAndSettle();
      expect(verdicts, [CgVerdict.good]);
    });

    testWidgets('réponse longue : un glissé horizontal sur le texte juge quand même', (tester) async {
      _phone(tester);
      final verdicts = <CgVerdict>[];
      await tester.pumpWidget(_card(verdicts: verdicts, flipped: true, answer: _longAnswer));
      await tester.dragFrom(tester.getCenter(find.byKey(CgDrillCard.answerKey)), const Offset(-_w * 0.4, 0));
      await tester.pumpAndSettle();
      expect(verdicts, [CgVerdict.review]);
    });

    testWidgets('réponse courte : un glissé vers le haut sur le texte donne « bien »', (tester) async {
      _phone(tester);
      final verdicts = <CgVerdict>[];
      await tester.pumpWidget(_card(verdicts: verdicts, flipped: true));
      await tester.dragFrom(tester.getCenter(find.text(_answer)), const Offset(0, -_h * 0.3));
      await tester.pumpAndSettle();
      expect(verdicts, [CgVerdict.good]);
    });
  });

  group('retours de revue 8.2', () {
    testWidgets('balayage depuis le bord gauche : onClose (« Quitter ? »), jamais de verdict', (tester) async {
      _phone(tester);
      final verdicts = <CgVerdict>[];
      var closed = 0;
      await tester.pumpWidget(_card(verdicts: verdicts, flipped: true, onClose: () => closed++));
      await tester.pumpAndSettle();
      final y = _sheetGrip(tester).dy;
      await tester.dragFrom(Offset(4, y), const Offset(_w * 0.6, 0));
      await tester.pumpAndSettle();
      expect(verdicts, isEmpty);
      expect(closed, 1);
    });

    testWidgets('balayage court depuis le bord : ni verdict ni fermeture', (tester) async {
      _phone(tester);
      final verdicts = <CgVerdict>[];
      var closed = 0;
      await tester.pumpWidget(_card(verdicts: verdicts, flipped: true, onClose: () => closed++));
      await tester.pumpAndSettle();
      await tester.dragFrom(Offset(4, _sheetGrip(tester).dy), const Offset(20, 0));
      await tester.pumpAndSettle();
      expect(verdicts, isEmpty);
      expect(closed, 0);
    });

    testWidgets('mode définition : le retournement ferme le clavier et retire le champ de VoiceOver', (tester) async {
      _phone(tester);
      final handle = tester.ensureSemantics();
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final key = GlobalKey<CgDrillCardState>();
      await tester.pumpWidget(cgTestApp(CgDrillCard(
        key: key,
        question: _question,
        answer: _answer,
        rank: 'A',
        collegeName: 'Cancérologie',
        index: 1,
        total: 3,
        onVerdict: (_) {},
        onClose: () {},
        canFlip: false,
        frontInput: EditableText(
          controller: TextEditingController(text: 'ma définition'),
          focusNode: focus,
          style: const TextStyle(),
          cursorColor: const Color(0xFF000000),
          backgroundCursorColor: const Color(0xFF000000),
        ),
      )));
      focus.requestFocus();
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      key.currentState!.flip();
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isFalse);
      expect(find.bySemanticsLabel('ma définition'), findsNothing);
      handle.dispose();
    });

    testWidgets('même fiche repassée après un verdict (cardKey) : la carte repart au recto', (tester) async {
      _phone(tester);
      final verdicts = <CgVerdict>[];
      Widget build(Object cardKey) => cgTestApp(CgDrillCard(
            cardKey: cardKey,
            question: _question,
            answer: _answer,
            rank: 'A',
            collegeName: 'Cancérologie',
            index: 3,
            total: 3,
            onVerdict: verdicts.add,
            onClose: () {},
            initiallyFlipped: true,
          ));
      await tester.pumpWidget(build('fiche-1#1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CgVerdictBar.buttonKey(CgVerdict.review)));
      await tester.pumpAndSettle();
      expect(verdicts, [CgVerdict.review]);
      await tester.pumpWidget(build('fiche-1#2'));
      await tester.pumpAndSettle();
      final state = _state(tester);
      expect(state.isFlipped, isFalse);
      await tester.tap(find.byType(CgDrillCard));
      await tester.pumpAndSettle();
      expect(state.isFlipped, isTrue, reason: 'la carte doit rester utilisable');
    });

    testWidgets('même contenu repassé sans cardKey après la sortie : repart aussi au recto', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_card(flipped: true, index: 3, total: 3));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(CgVerdictBar.buttonKey(CgVerdict.good)));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_card(flipped: true, index: 3, total: 3));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CgDrillCard));
      await tester.pumpAndSettle();
      expect(_state(tester).isFlipped, isTrue);
      expect(find.byKey(CgVerdictBar.buttonKey(CgVerdict.good)), findsOneWidget);
    });
  });

  group('goldens', () {
    cgGoldenMatrix('cg_drill_card_recto', () => const CgDrillCardGallery(state: CgDrillCardGalleryState.recto));
    cgGoldenMatrix('cg_drill_card_verso', () => const CgDrillCardGallery(state: CgDrillCardGalleryState.verso));
    // Rotation visible : animations non réduites (l'état figé ne lance aucune animation).
    cgGoldenMatrix(
      'cg_drill_card_drag',
      () => const CgDrillCardGallery(state: CgDrillCardGalleryState.drag),
      disableAnimations: false,
    );
  });
}

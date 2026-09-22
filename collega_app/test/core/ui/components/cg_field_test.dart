import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/components/cg_field.dart';
import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/gallery/cg_field_gallery.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';

import '../../../support/cg_golden.dart';

const c = CgColors.light;
const _box = ValueKey('cg-field-box');

Widget _app(Widget field, {double textScale = 1}) =>
    cgTestApp(Padding(padding: const EdgeInsets.all(CgSpace.gutter), child: field), textScale: textScale);

BoxDecoration _decoration(WidgetTester tester) =>
    tester.widget<DecoratedBox>(find.byKey(_box)).decoration as BoxDecoration;

CupertinoTextField _input(WidgetTester tester) => tester.widget<CupertinoTextField>(find.byType(CupertinoTextField));

void main() {
  group('anatomie', () {
    testWidgets('libellé 15/500 au-dessus, champ 50 pt surface, contour line 1 pt, rayon s', (tester) async {
      await tester.pumpWidget(_app(const CgField(label: 'Email', placeholder: 'prenom@exemple.fr')));
      final label = tester.widget<Text>(find.text('Email'));
      expect(label.style?.fontSize, 15);
      expect(label.style?.fontWeight, FontWeight.w500);
      expect(tester.getBottomLeft(find.text('Email')).dy, lessThanOrEqualTo(tester.getTopLeft(find.byKey(_box)).dy));
      expect(tester.getSize(find.byKey(_box)).height, 50);
      final deco = _decoration(tester);
      expect(deco.color, c.surface);
      expect(deco.borderRadius, CgRadius.sAll);
      expect((deco.border! as Border).top.color, c.line);
      expect((deco.border! as Border).top.width, 1);
      expect(_input(tester).style?.color, c.ink);
      expect(_input(tester).cursorColor, c.accent);
    });

    testWidgets('aide sous le champ en ink2', (tester) async {
      await tester.pumpWidget(_app(const CgField(label: 'Email', helper: 'Celui de ton compte')));
      expect(tester.widget<Text>(find.text('Celui de ton compte')).style?.color, c.ink2);
      expect(tester.getTopLeft(find.text('Celui de ton compte')).dy, greaterThanOrEqualTo(tester.getBottomLeft(find.byKey(_box)).dy));
    });
  });

  group('états', () {
    testWidgets('focus : contour accent 2 pt', (tester) async {
      await tester.pumpWidget(_app(const CgField(label: 'Email')));
      await tester.tap(find.byType(CupertinoTextField));
      await tester.pump();
      final border = _decoration(tester).border! as Border;
      expect(border.top.color, c.accent);
      expect(border.top.width, 2);
    });

    testWidgets('erreur : contour danger, message danger à la place de l\'aide', (tester) async {
      await tester.pumpWidget(_app(const CgField(
        label: 'Email',
        helper: 'Celui de ton compte',
        error: 'Email ou mot de passe incorrect',
      )));
      expect((_decoration(tester).border! as Border).top.color, c.danger);
      expect(tester.widget<Text>(find.text('Email ou mot de passe incorrect')).style?.color, c.danger);
      expect(find.text('Celui de ton compte'), findsNothing);
    });

    testWidgets('désactivé : texte ink3, non éditable', (tester) async {
      await tester.pumpWidget(_app(CgField(
        label: 'Email',
        controller: TextEditingController(text: 'camille@exemple.fr'),
        enabled: false,
      )));
      expect(_input(tester).style?.color, c.ink3);
      expect(_input(tester).enabled, isFalse);
    });

    testWidgets('onChanged, onSubmitted, textInputAction transmis', (tester) async {
      final changes = <String>[];
      final submits = <String>[];
      await tester.pumpWidget(_app(CgField(
        label: 'Email',
        onChanged: changes.add,
        onSubmitted: submits.add,
        textInputAction: TextInputAction.next,
      )));
      await tester.enterText(find.byType(CupertinoTextField), 'a@b.fr');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      expect(changes.last, 'a@b.fr');
      expect(submits, ['a@b.fr']);
      expect(_input(tester).textInputAction, TextInputAction.next);
    });
  });

  group('variantes', () {
    testWidgets('email : clavier email, sans autocorrection, autofill email', (tester) async {
      await tester.pumpWidget(_app(const CgField(label: 'Email', kind: CgFieldKind.email)));
      final input = _input(tester);
      expect(input.keyboardType, TextInputType.emailAddress);
      expect(input.autocorrect, isFalse);
      expect(input.autofillHints, contains(AutofillHints.email));
    });

    testWidgets('password : masqué, bouton œil 44 pt qui révèle puis remasque', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const CgField(label: 'Mot de passe', kind: CgFieldKind.password)));
      expect(_input(tester).obscureText, isTrue);
      expect(_input(tester).autofillHints, contains(AutofillHints.password));
      final eye = find.bySemanticsLabel('Afficher le mot de passe');
      expect(eye, findsOneWidget);
      final eyeButton = find.byKey(const ValueKey('cg-field-reveal'));
      expect(tester.getSize(eyeButton).width, greaterThanOrEqualTo(CgSpace.tapTarget));
      expect(tester.getSize(eyeButton).height, greaterThanOrEqualTo(CgSpace.tapTarget));
      await tester.tap(eyeButton);
      await tester.pump();
      expect(_input(tester).obscureText, isFalse);
      expect(find.bySemanticsLabel('Masquer le mot de passe'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('search : 40 pt, fond soft sans contour, loupe, effacer quand non vide', (tester) async {
      final changes = <String>[];
      await tester.pumpWidget(_app(CgField(
        placeholder: 'Un item, un signe, une dose…',
        kind: CgFieldKind.search,
        onChanged: changes.add,
      )));
      expect(tester.getSize(find.byKey(_box)).height, 40);
      expect(_decoration(tester).color, c.soft);
      expect(_decoration(tester).border, isNull);
      expect(tester.widgetList<CgIcon>(find.byType(CgIcon)).map((i) => i.svg), contains(CgIcons.search));
      final clear = find.byKey(const ValueKey('cg-field-clear'));
      expect(clear, findsNothing);
      await tester.enterText(find.byType(CupertinoTextField), 'cancer');
      await tester.pump();
      expect(clear, findsOneWidget);
      expect(tester.getSize(clear).width, greaterThanOrEqualTo(CgSpace.tapTarget));
      expect(tester.getSize(clear).height, greaterThanOrEqualTo(CgSpace.tapTarget));
      await tester.tap(clear);
      await tester.pump();
      expect(_input(tester).controller!.text, isEmpty);
      expect(changes.last, '');
      expect(clear, findsNothing);
    });

    testWidgets('multiline : hauteur libre (minLines 3), lignes illimitées', (tester) async {
      await tester.pumpWidget(_app(const CgField(label: 'Ta définition', kind: CgFieldKind.multiline)));
      expect(_input(tester).minLines, 3);
      expect(_input(tester).maxLines, isNull);
      expect(tester.getSize(find.byKey(_box)).height, greaterThan(50));
    });

    testWidgets('multiline : placeholder en haut, qui disparaît sans faire perdre le focus', (tester) async {
      await tester.pumpWidget(_app(const CgField(
        label: 'Ta définition',
        placeholder: 'Écris ta réponse…',
        kind: CgFieldKind.multiline,
      )));
      final top = tester.getTopLeft(find.byKey(_box)).dy;
      expect(tester.getTopLeft(find.text('Écris ta réponse…')).dy - top, lessThan(CgSpace.s4));
      await tester.tap(find.byType(CupertinoTextField));
      await tester.pump();
      final state = tester.state(find.byType(EditableText));
      await tester.enterText(find.byType(CupertinoTextField), 'T');
      await tester.pump();
      expect(find.text('Écris ta réponse…'), findsNothing);
      expect(tester.state(find.byType(EditableText)), same(state));
      expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue);
    });

    testWidgets('contrôleur externe : le texte est celui du parent', (tester) async {
      final controller = TextEditingController(text: 'déjà là');
      addTearDown(controller.dispose);
      await tester.pumpWidget(_app(CgField(label: 'Email', controller: controller)));
      expect(find.text('déjà là'), findsOneWidget);
    });
  });

  group('Dynamic Type', () {
    testWidgets('1,6 : le champ grandit, rien ne déborde', (tester) async {
      await tester.pumpWidget(_app(
        const Column(children: [
          CgField(label: 'Mot de passe', kind: CgFieldKind.password, helper: 'Au moins 8 caractères'),
          CgField(placeholder: 'Un item, un signe, une dose…', kind: CgFieldKind.search),
        ]),
        textScale: 1.6,
      ));
      expect(tester.getSize(find.byKey(_box).first).height, greaterThan(50));
      expect(tester.takeException(), isNull);
    });
  });

  group('Semantics', () {
    testWidgets('le champ porte son libellé', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const CgField(label: 'Email')));
      expect(
        tester.getSemantics(find.byType(EditableText)),
        matchesSemantics(label: 'Email', isTextField: true, hasEnabledState: true, isEnabled: true,
            hasTapAction: true, hasFocusAction: true),
      );
      handle.dispose();
    });

    testWidgets('l\'erreur est annoncée (liveRegion)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const CgField(label: 'Email', error: 'Email ou mot de passe incorrect')));
      expect(
        tester.getSemantics(find.text('Email ou mot de passe incorrect')),
        matchesSemantics(label: 'Email ou mot de passe incorrect', isLiveRegion: true),
      );
      handle.dispose();
    });
  });

  testWidgets('search : contour accent 2 pt au focus (focus visible, clavier externe)', (tester) async {
    await tester.pumpWidget(cgTestApp(const Padding(
      padding: EdgeInsets.all(20),
      child: CgField(kind: CgFieldKind.search, placeholder: 'Un item, un signe, une dose…'),
    )));
    expect(_decoration(tester).border, isNull);
    await tester.tap(find.byType(CupertinoTextField));
    await tester.pump();
    final border = _decoration(tester).border as Border;
    expect(border.top.color, CgColors.light.accent);
    expect(border.top.width, 2);
  });

  group('goldens', () {
    cgGoldenMatrix('cg_field', () => const CgFieldGallery(), height: 1700);
  });
}

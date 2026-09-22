import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/components/cg_list_row.dart';
import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/gallery/cg_list_row_gallery.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

import '../../../support/cg_golden.dart';

const c = CgColors.light;

TextStyle? _style(WidgetTester tester, String text) => tester.widget<Text>(find.text(text)).style;

/// Filets posés par [CgListGroup] (clé stable, un par intervalle entre lignes).
Finder _separators() => find.byKey(const ValueKey('cg-list-separator'));

Widget _group({CgListVariant variant = CgListVariant.plain, String? header, int rows = 3}) => CgListGroup(
      variant: variant,
      header: header,
      children: [
        for (var i = 0; i < rows; i++) CgListRow(title: 'Ligne $i', onTap: () {}),
      ],
    );

void main() {
  group('CgListRow — anatomie', () {
    testWidgets('titre head ink, sous-titre meta ink2, valeur bodyS ink3 tabulaire', (tester) async {
      await tester.pumpWidget(cgTestApp(const CgListRow(
        title: 'Cancérologie',
        subtitle: '177 fiches · 42 % maîtrisées',
        trailing: CgRowTrailing.value,
        value: '42 %',
      )));
      final title = _style(tester, 'Cancérologie')!;
      expect(title.fontSize, CgType.head.fontSize);
      expect(title.fontWeight, CgType.head.fontWeight);
      expect(title.color, c.ink);
      final sub = _style(tester, '177 fiches · 42 % maîtrisées')!;
      expect(sub.fontSize, CgType.meta.fontSize);
      expect(sub.color, c.ink2);
      final value = _style(tester, '42 %')!;
      expect(value.fontSize, CgType.bodyS.fontSize);
      expect(value.color, c.ink3);
      expect(value.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    testWidgets('chevron ink3 si trailing chevron', (tester) async {
      await tester.pumpWidget(cgTestApp(CgListRow(title: 'Pneumologie', trailing: CgRowTrailing.chevron, onTap: () {})));
      final icon = tester.widget<CgIcon>(find.byType(CgIcon));
      expect(icon.svg, CgIcons.chevronRight);
      expect(icon.color, c.ink3);
    });

    testWidgets('titre : 2 lignes max par défaut, puis ellipse', (tester) async {
      await tester.pumpWidget(cgTestApp(const CgListRow(title: 'Chirurgie générale, viscérale et digestive')));
      final text = tester.widget<Text>(find.text('Chirurgie générale, viscérale et digestive'));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('progress posé sous le sous-titre', (tester) async {
      await tester.pumpWidget(cgTestApp(const CgListRow(
        title: 'Cancérologie',
        subtitle: '177 fiches',
        progress: SizedBox(key: Key('p'), height: 6),
      )));
      expect(tester.getTopLeft(find.byKey(const Key('p'))).dy,
          greaterThan(tester.getBottomLeft(find.text('177 fiches')).dy));
    });

    testWidgets('selected + trailing check : coche accent ; non sélectionnée : pas de coche', (tester) async {
      await tester.pumpWidget(cgTestApp(Column(children: [
        CgListRow(key: const Key('on'), title: 'Cancérologie', trailing: CgRowTrailing.check, selected: true, onTap: () {}),
        CgListRow(key: const Key('off'), title: 'Pneumologie', trailing: CgRowTrailing.check, onTap: () {}),
      ])));
      final on = find.descendant(of: find.byKey(const Key('on')), matching: find.byType(CgIcon));
      expect(tester.widget<CgIcon>(on).svg, CgIcons.check);
      expect(tester.widget<CgIcon>(on).color, c.accent);
      expect(find.descendant(of: find.byKey(const Key('off')), matching: find.byType(CgIcon)), findsNothing);
    });

    testWidgets('custom : trailingWidget affiché (switch)', (tester) async {
      await tester.pumpWidget(cgTestApp(CgListRow(
        title: 'Rappel quotidien',
        trailing: CgRowTrailing.custom,
        trailingWidget: CupertinoSwitch(value: true, onChanged: (_) {}),
      )));
      expect(find.byType(CupertinoSwitch), findsOneWidget);
    });
  });

  group('CgListRow — états', () {
    testWidgets('tap appelle onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(cgTestApp(CgListRow(title: 'Cancérologie', onTap: () => taps++)));
      await tester.tap(find.byType(CgListRow));
      expect(taps, 1);
    });

    testWidgets('pressé : fond soft en CgMotion.fast, puis retour', (tester) async {
      await tester.pumpWidget(cgTestApp(CgListRow(title: 'Cancérologie', onTap: () {})));
      Color? fill() => (tester
              .widget<AnimatedContainer>(find.descendant(of: find.byType(CgListRow), matching: find.byType(AnimatedContainer)))
              .decoration as BoxDecoration?)
          ?.color;
      expect(fill(), isNot(c.soft));
      final gesture = await tester.startGesture(tester.getCenter(find.byType(CgListRow)));
      await tester.pumpAndSettle();
      expect(fill(), c.soft);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(fill(), isNot(c.soft));
    });

    testWidgets('désactivée : titre ink2 poids 500, pas de chevron, ligne non tapable', (tester) async {
      var taps = 0;
      await tester.pumpWidget(cgTestApp(CgListRow(
        title: 'Anatomie pathologique',
        trailing: CgRowTrailing.chevron,
        enabled: false,
        onTap: () => taps++,
      )));
      final title = _style(tester, 'Anatomie pathologique')!;
      expect(title.color, c.ink2);
      expect(title.fontWeight, FontWeight.w500);
      expect(find.byType(CgIcon), findsNothing);
      await tester.tap(find.byType(CgListRow));
      expect(taps, 0);
    });

    testWidgets('désactivée + action « Importer » : action quiet 14/600 accent, tapable, cible ≥ 44', (tester) async {
      var imports = 0;
      await tester.pumpWidget(cgTestApp(CgListRow(
        title: 'Anatomie pathologique',
        subtitle: 'CoPath',
        enabled: false,
        trailing: CgRowTrailing.action,
        actionLabel: 'Importer',
        onAction: () => imports++,
      )));
      final style = _style(tester, 'Importer')!;
      expect(style.color, c.accent);
      expect(style.fontSize, 14);
      expect(style.fontWeight, FontWeight.w600);
      final target = find.byKey(const ValueKey('cg-row-action'));
      final size = tester.getSize(target);
      expect(size.width, greaterThanOrEqualTo(CgSpace.tapTarget));
      expect(size.height, greaterThanOrEqualTo(CgSpace.tapTarget));
      await tester.tap(find.text('Importer'));
      expect(imports, 1);
    });

    testWidgets('mouvement réduit : pas d’animation du fond pressé', (tester) async {
      await tester.pumpWidget(cgTestApp(CgListRow(title: 'Cancérologie', onTap: () {}), disableAnimations: true));
      final box = tester.widget<AnimatedContainer>(
        find.descendant(of: find.byType(CgListRow), matching: find.byType(AnimatedContainer)),
      );
      expect(box.duration, Duration.zero);
    });
  });

  group('CgListRow — Dynamic Type', () {
    testWidgets('1,0× : valeur sur la même ligne que le titre', (tester) async {
      await tester.pumpWidget(cgTestApp(const CgListRow(title: 'Rang A', trailing: CgRowTrailing.value, value: '48 %')));
      expect(tester.getCenter(find.text('48 %')).dy, closeTo(tester.getCenter(find.text('Rang A')).dy, 2));
    });

    testWidgets('1,6× : deux niveaux, la valeur passe sous le titre', (tester) async {
      await tester.pumpWidget(cgTestApp(
        const CgListRow(title: 'Rang A', trailing: CgRowTrailing.value, value: '48 %'),
        textScale: 1.6,
      ));
      expect(tester.getTopLeft(find.text('48 %')).dy, greaterThanOrEqualTo(tester.getBottomLeft(find.text('Rang A')).dy));
      expect(tester.getTopLeft(find.text('48 %')).dx, tester.getTopLeft(find.text('Rang A')).dx);
    });

    testWidgets('1,6× : l’action « Importer » passe aussi sous le titre, toujours tapable', (tester) async {
      var imports = 0;
      await tester.pumpWidget(cgTestApp(
        CgListRow(
          title: 'Chirurgie générale, viscérale et digestive',
          subtitle: 'CFCVD',
          enabled: false,
          trailing: CgRowTrailing.action,
          actionLabel: 'Importer',
          onAction: () => imports++,
        ),
        textScale: 1.6,
      ));
      expect(tester.getTopLeft(find.text('Importer')).dy, greaterThan(tester.getBottomLeft(find.text('CFCVD')).dy));
      await tester.tap(find.text('Importer'));
      expect(imports, 1);
    });
  });

  group('CgListRow — Semantics', () {
    testWidgets('une ligne = un nœud : titre, sous-titre, valeur ; bouton si onTap ; selected', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(cgTestApp(CgListRow(
        title: 'Cancérologie',
        subtitle: '177 fiches',
        trailing: CgRowTrailing.value,
        value: '42 %',
        selected: true,
        onTap: () {},
      )));
      expect(
        tester.getSemantics(find.byType(CgListRow)),
        matchesSemantics(
          label: 'Cancérologie\n177 fiches\n42 %',
          isButton: true,
          hasTapAction: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('désactivée + action : le nœud unique déclenche l’action', (tester) async {
      final handle = tester.ensureSemantics();
      var imports = 0;
      await tester.pumpWidget(cgTestApp(CgListRow(
        title: 'Cardiologie',
        subtitle: 'SFC',
        enabled: false,
        trailing: CgRowTrailing.action,
        actionLabel: 'Importer',
        onAction: () => imports++,
      )));
      final node = tester.getSemantics(find.byType(CgListRow));
      expect(node.label, 'Cardiologie\nSFC\nImporter');
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.semantics.tap(find.semantics.byLabel('Cardiologie\nSFC\nImporter'));
      expect(imports, 1);
      handle.dispose();
    });

    testWidgets('ligne tapable + action : action exposée en action personnalisée', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(cgTestApp(CgListRow(
        title: 'Cancérologie',
        trailing: CgRowTrailing.action,
        actionLabel: 'Mettre à jour',
        onAction: () {},
        onTap: () {},
      )));
      final node = tester.getSemantics(find.byType(CgListRow));
      expect(node.label, 'Cancérologie');
      expect(node.getSemanticsData().hasAction(SemanticsAction.customAction), isTrue);
      handle.dispose();
    });

    testWidgets('cible ≥ 44 pt même sans sous-titre', (tester) async {
      await tester.pumpWidget(cgTestApp(CgListRow(title: 'A', onTap: () {})));
      expect(tester.getSize(find.byType(CgListRow)).height, greaterThanOrEqualTo(CgSpace.tapTarget));
    });
  });

  group('CgListGroup', () {
    testWidgets('filets entre lignes, jamais après la dernière (couleur line, 1 pt)', (tester) async {
      await tester.pumpWidget(cgTestApp(_group()));
      expect(_separators(), findsNWidgets(2));
      final sep = tester.widget<ColoredBox>(
        find.descendant(of: _separators().first, matching: find.byType(ColoredBox)),
      );
      expect(sep.color, c.line);
      expect(tester.getSize(_separators().first).height, 1);
      expect(tester.getTopLeft(_separators().last).dy, lessThan(tester.getTopLeft(find.text('Ligne 2')).dy));
    });

    testWidgets('une seule ligne : aucun filet', (tester) async {
      await tester.pumpWidget(cgTestApp(_group(rows: 1)));
      expect(_separators(), findsNothing);
    });

    testWidgets('plain : pas de fond ; inset : surface, rayon l, texte à rowInset du bord', (tester) async {
      await tester.pumpWidget(cgTestApp(Column(children: [
        KeyedSubtree(key: const Key('plain'), child: _group()),
        KeyedSubtree(key: const Key('inset'), child: _group(variant: CgListVariant.inset)),
      ])));
      final insetBox = tester.widget<DecoratedBox>(
        find.descendant(of: find.byKey(const Key('inset')), matching: find.byKey(const ValueKey('cg-list-inset'))),
      );
      final deco = insetBox.decoration as BoxDecoration;
      expect(deco.color, c.surface);
      expect(deco.borderRadius, CgRadius.lAll);
      expect(find.descendant(of: find.byKey(const Key('plain')), matching: find.byKey(const ValueKey('cg-list-inset'))),
          findsNothing);
      final groupLeft = tester.getTopLeft(find.byKey(const Key('inset'))).dx;
      final textLeft = tester.getTopLeft(find.descendant(of: find.byKey(const Key('inset')), matching: find.text('Ligne 0'))).dx;
      expect(textLeft - groupLeft, CgSpace.rowInset);
      final plainText = tester.getTopLeft(find.descendant(of: find.byKey(const Key('plain')), matching: find.text('Ligne 0'))).dx;
      expect(plainText, tester.getTopLeft(find.byKey(const Key('plain'))).dx);
    });

    testWidgets('header : intertitre ink3 au-dessus, lu comme en-tête', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(cgTestApp(_group(header: 'Mes collèges')));
      expect(_style(tester, 'Mes collèges')!.color, c.ink3);
      expect(tester.getTopLeft(find.text('Mes collèges')).dy, lessThan(tester.getTopLeft(find.text('Ligne 0')).dy));
      expect(tester.getSemantics(find.text('Mes collèges')), matchesSemantics(label: 'Mes collèges', isHeader: true));
      handle.dispose();
    });
  });

  group('CgSectionTitle', () {
    testWidgets('13/600 ink3, marge haute section, basse related', (tester) async {
      await tester.pumpWidget(cgTestApp(const Align(
        alignment: Alignment.topLeft,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CgSectionTitle('Catalogue · 38 collèges'),
          SizedBox(key: Key('next'), height: 10, width: 10),
        ]),
      )));
      final style = _style(tester, 'Catalogue · 38 collèges')!;
      expect(style.fontSize, 13);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, c.ink3);
      expect(tester.getTopLeft(find.text('Catalogue · 38 collèges')).dy, CgSpace.section);
      expect(tester.getTopLeft(find.byKey(const Key('next'))).dy - tester.getBottomLeft(find.text('Catalogue · 38 collèges')).dy,
          CgSpace.related);
    });
  });

  group('goldens', () {
    cgGoldenMatrix('cg_list_row', () => const CgListRowGallery(), height: 1900);
  });
}

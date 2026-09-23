import 'package:flutter/cupertino.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collega_app/core/ui/components/cg_button.dart';
import 'package:collega_app/core/ui/components/cg_sheet.dart';
import 'package:collega_app/core/ui/gallery/cg_sheet_gallery.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';

import '../../../support/cg_golden.dart';

const c = CgColors.light;

/// Hôte : un bouton « Ouvrir » qui lance [open] avec un contexte sous le Navigator.
Future<void> _pumpHost(
  WidgetTester tester,
  void Function(BuildContext context) open, {
  bool disableAnimations = false,
}) async {
  await tester.pumpWidget(cgTestApp(
    Builder(
      builder: (context) => Center(
        child: CgButton(label: 'Ouvrir', expand: false, onPressed: () => open(context)),
      ),
    ),
    disableAnimations: disableAnimations,
  ));
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

BoxDecoration _panelDecoration(WidgetTester tester) => tester
    .widget<DecoratedBox>(
      find.descendant(of: find.byType(CgSheetPanel), matching: find.byType(DecoratedBox)).first,
    )
    .decoration as BoxDecoration;

void main() {
  group('showCgSheet', () {
    testWidgets('affiche poignée, titre, contenu et pied (primary + secondary)', (tester) async {
      await _pumpHost(tester, (context) {
        showCgSheet<void>(
          context,
          title: 'Personnaliser',
          builder: (_) => const Text('Contenu'),
          primary: CgButton(label: 'Commencer', onPressed: () {}),
          secondary: CgButton(label: 'Plus tard', onPressed: () {}, variant: CgButtonVariant.quiet),
        );
      });
      expect(find.byType(CgSheetPanel), findsOneWidget);
      expect(find.text('Personnaliser'), findsOneWidget);
      expect(find.text('Contenu'), findsOneWidget);
      // Pied : primary au-dessus du secondary.
      expect(
        tester.getTopLeft(find.text('Commencer')).dy,
        lessThan(tester.getTopLeft(find.text('Plus tard')).dy),
      );
      expect(find.byKey(CgSheetPanel.handleKey), findsOneWidget);
    });

    testWidgets('feuille ground arrondie en haut, voile scrim', (tester) async {
      await _pumpHost(tester, (context) {
        showCgSheet<void>(context, builder: (_) => const Text('Contenu'));
      });
      final deco = _panelDecoration(tester);
      expect(deco.color, c.ground);
      expect(
        deco.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(CgRadius.l)),
      );
      final barrier = tester.widget<ModalBarrier>(find.byType(ModalBarrier).last);
      expect(barrier.color, c.scrim);
    });

    testWidgets('half ≈ 50 % de l\'écran, ancrée en bas', (tester) async {
      await _pumpHost(tester, (context) {
        showCgSheet<void>(context, builder: (_) => const Text('Moitié'));
      });
      // Surface de test : 800 × 600.
      expect(tester.getSize(find.byType(CgSheetPanel)).height, closeTo(300, 1));
      expect(tester.getBottomLeft(find.byType(CgSheetPanel)).dy, 600);
    });

    testWidgets('full ≈ plein écran sous la safe area', (tester) async {
      // FakeViewPadding est en pixels physiques.
      tester.view.padding = FakeViewPadding(top: 47 * tester.view.devicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await _pumpHost(tester, (context) {
        showCgSheet<void>(context, detent: CgSheetDetent.full, builder: (_) => const Text('Plein'));
      });
      final top = tester.getTopLeft(find.byType(CgSheetPanel)).dy;
      expect(top, greaterThanOrEqualTo(47));
      expect(top, lessThan(47 + 20));
      expect(tester.getBottomLeft(find.byType(CgSheetPanel)).dy, 600);
    });

    testWidgets('tap sur le voile : ferme, résultat null', (tester) async {
      Object? result = 'pas encore';
      await _pumpHost(tester, (context) async {
        result = await showCgSheet<String>(context, builder: (_) => const Text('Contenu'));
      });
      await tester.tapAt(const Offset(400, 20));
      await tester.pumpAndSettle();
      expect(find.byType(CgSheetPanel), findsNothing);
      expect(result, isNull);
    });

    testWidgets('le contenu renvoie une valeur par Navigator.pop', (tester) async {
      String? result;
      await _pumpHost(tester, (context) async {
        result = await showCgSheet<String>(
          context,
          builder: (sheetContext) => CgButton(
            label: 'Choisir',
            onPressed: () => Navigator.of(sheetContext).pop('A'),
          ),
        );
      });
      await tester.tap(find.text('Choisir'));
      await tester.pumpAndSettle();
      expect(result, 'A');
    });

    testWidgets('glisser vers le bas au-delà du seuil : ferme', (tester) async {
      await _pumpHost(tester, (context) {
        showCgSheet<void>(context, title: 'Titre', builder: (_) => const Text('Contenu'));
      });
      await tester.drag(find.byKey(CgSheetPanel.handleKey), const Offset(0, 200));
      await tester.pumpAndSettle();
      expect(find.byType(CgSheetPanel), findsNothing);
    });

    testWidgets('glisser court et lent : la feuille revient', (tester) async {
      await _pumpHost(tester, (context) {
        showCgSheet<void>(context, title: 'Titre', builder: (_) => const Text('Contenu'));
      });
      final top = tester.getTopLeft(find.byType(CgSheetPanel)).dy;
      final gesture = await tester.startGesture(tester.getCenter(find.text('Titre')));
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 8), timeStamp: Duration(milliseconds: 100 * (i + 1)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      // Pendant le glissement, la feuille suit le doigt.
      expect(tester.getTopLeft(find.byType(CgSheetPanel)).dy, greaterThan(top));
      await gesture.up(timeStamp: const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(find.byType(CgSheetPanel), findsOneWidget);
      expect(tester.getTopLeft(find.byType(CgSheetPanel)).dy, closeTo(top, 0.5));
    });

    testWidgets('clavier : la feuille remonte au-dessus des viewInsets', (tester) async {
      tester.view.viewInsets = FakeViewPadding(bottom: 200 * tester.view.devicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await _pumpHost(tester, (context) {
        showCgSheet<void>(context, builder: (_) => const Text('Contenu'));
      });
      expect(tester.getBottomLeft(find.byType(CgSheetPanel)).dy, closeTo(400, 0.5));
    });

    testWidgets('mouvement réduit : fondu, aucun glissement', (tester) async {
      await _pumpHost(tester, disableAnimations: true, (context) {
        showCgSheet<void>(context, builder: (_) => const Text('Contenu'));
      });
      final ancestors = find.ancestor(of: find.byType(CgSheetPanel), matching: find.byType(SlideTransition));
      expect(ancestors, findsNothing);
      expect(
        find.ancestor(of: find.byType(CgSheetPanel), matching: find.byType(FadeTransition)),
        findsWidgets,
      );
    });

    testWidgets('mouvement normal : montée (SlideTransition)', (tester) async {
      await _pumpHost(tester, (context) {
        showCgSheet<void>(context, builder: (_) => const Text('Contenu'));
      });
      expect(
        find.ancestor(of: find.byType(CgSheetPanel), matching: find.byType(SlideTransition)),
        findsOneWidget,
      );
    });

    testWidgets('Semantics : titre en en-tête, poignée « Fermer » actionnable', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpHost(tester, (context) {
        showCgSheet<void>(context, title: 'Personnaliser', builder: (_) => const Text('Contenu'));
      });
      expect(
        tester.getSemantics(find.text('Personnaliser')),
        matchesSemantics(label: 'Personnaliser', isHeader: true),
      );
      expect(
        tester.getSemantics(find.byKey(CgSheetPanel.handleKey)),
        matchesSemantics(label: 'Fermer', isButton: true, hasTapAction: true),
      );
      // Le voile porte aussi « Fermer » : on vise la poignée (bouton).
      tester.semantics.tap(find.semantics.byPredicate(
        (node) => node.label == 'Fermer' && node.hasFlag(SemanticsFlag.isButton),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(CgSheetPanel), findsNothing);
      handle.dispose();
    });
  });

  group('showCgDialogSheet', () {
    Future<bool?> openDialog(WidgetTester tester, {bool destructive = false}) async {
      bool? result;
      await _pumpHost(tester, (context) async {
        result = await showCgDialogSheet(
          context,
          title: 'Quitter ?',
          message: '12 fiches jugées sont enregistrées.',
          confirmLabel: 'Quitter',
          cancelLabel: 'Continuer',
          destructive: destructive,
        );
      });
      return result;
    }

    testWidgets('confirmer : true', (tester) async {
      bool? result;
      await _pumpHost(tester, (context) async {
        result = await showCgDialogSheet(
          context,
          title: 'Quitter ?',
          message: '12 fiches jugées sont enregistrées.',
          confirmLabel: 'Quitter',
          cancelLabel: 'Continuer',
        );
      });
      expect(find.text('12 fiches jugées sont enregistrées.'), findsOneWidget);
      await tester.tap(find.text('Quitter'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('annuler : false', (tester) async {
      bool? result;
      await _pumpHost(tester, (context) async {
        result = await showCgDialogSheet(
          context,
          title: 'Quitter ?',
          message: 'Message',
          confirmLabel: 'Quitter',
          cancelLabel: 'Continuer',
        );
      });
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('fermeture par glissement : false', (tester) async {
      bool? result;
      await _pumpHost(tester, (context) async {
        result = await showCgDialogSheet(
          context,
          title: 'Quitter ?',
          message: 'Message',
          confirmLabel: 'Quitter',
          cancelLabel: 'Continuer',
        );
      });
      await tester.drag(find.byKey(CgSheetPanel.handleKey), const Offset(0, 250));
      await tester.pumpAndSettle();
      expect(find.byType(CgSheetPanel), findsNothing);
      expect(result, isFalse);
    });

    testWidgets('variantes : confirm primary / destructive, cancel quiet', (tester) async {
      await openDialog(tester);
      CgButton button(String label) =>
          tester.widget<CgButton>(find.ancestor(of: find.text(label), matching: find.byType(CgButton)));
      expect(button('Quitter').variant, CgButtonVariant.primary);
      expect(button('Continuer').variant, CgButtonVariant.quiet);

      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await openDialog(tester, destructive: true);
      expect(button('Quitter').variant, CgButtonVariant.destructive);
    });
  });

  group('showCgActionSheet', () {
    testWidgets('délègue à CupertinoActionSheet ; action → callback et fermeture', (tester) async {
      var reported = 0;
      var deleted = 0;
      await _pumpHost(tester, (context) {
        showCgActionSheet(
          context,
          title: 'Cette fiche',
          message: 'Que veux-tu faire ?',
          actions: [
            CgSheetAction(label: 'Signaler la fiche', onPressed: () => reported++),
            CgSheetAction(label: 'Supprimer la fiche', onPressed: () => deleted++, destructive: true),
          ],
        );
      });
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
      final destructive = tester.widget<CupertinoActionSheetAction>(
        find.ancestor(of: find.text('Supprimer la fiche'), matching: find.byType(CupertinoActionSheetAction)),
      );
      expect(destructive.isDestructiveAction, isTrue);
      final plain = tester.widget<CupertinoActionSheetAction>(
        find.ancestor(of: find.text('Signaler la fiche'), matching: find.byType(CupertinoActionSheetAction)),
      );
      expect(plain.isDestructiveAction, isFalse);

      await tester.tap(find.text('Signaler la fiche'));
      await tester.pumpAndSettle();
      expect(reported, 1);
      expect(deleted, 0);
      expect(find.byType(CupertinoActionSheet), findsNothing);
    });

    testWidgets('Annuler : ferme sans appeler d\'action', (tester) async {
      var calls = 0;
      await _pumpHost(tester, (context) {
        showCgActionSheet(
          context,
          actions: [CgSheetAction(label: 'Supprimer', onPressed: () => calls++, destructive: true)],
        );
      });
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byType(CupertinoActionSheet), findsNothing);
    });
  });

  testWidgets('Dynamic Type 1,6 : le panneau se rend sans débordement', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(cgTestApp(
      Align(
        alignment: Alignment.bottomCenter,
        child: CgSheetPanel.dialog(
          title: 'Supprimer cette fiche ?',
          message: 'Elle disparaît de tes révisions. Tes autres fiches restent.',
          confirmLabel: 'Supprimer',
          cancelLabel: 'Garder la fiche',
          destructive: true,
          onConfirm: () {},
          onCancel: () {},
        ),
      ),
      textScale: 1.6,
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('Supprimer cette fiche ?'), findsOneWidget);
  });

  testWidgets('CgSheetFooter : primaire puis secondaire, au-dessus de la safe area', (tester) async {
    await tester.pumpWidget(cgTestApp(MediaQuery(
      data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: CgSheetFooter(
          primary: CgButton(label: 'Enregistrer', onPressed: () {}),
          secondary: CgButton(label: 'Annuler', onPressed: () {}, variant: CgButtonVariant.quiet),
        ),
      ),
    )));
    final save = tester.getRect(find.text('Enregistrer'));
    final cancel = tester.getRect(find.text('Annuler'));
    expect(save.top, lessThan(cancel.top));
    expect(tester.getBottomLeft(find.byType(CgSheetFooter)).dy - tester.getBottomLeft(find.byType(CgButton).last).dy,
        greaterThanOrEqualTo(34));
  });

  group('goldens', () {
    cgGoldenMatrix('cg_sheet', () => const CgSheetGallery(), height: 1200);
  });
}

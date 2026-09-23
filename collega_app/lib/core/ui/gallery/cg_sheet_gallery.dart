import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/components/cg_button.dart';
import 'package:collega_app/core/ui/components/cg_sheet.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Planche de [CgSheetPanel] (Widgetbook + goldens) : sheet à pied, dialog,
/// dialog destructif, chacun posé sur le voile `scrim`. L'action sheet est
/// native (`CupertinoActionSheet`) : elle n'est montrée que dans Widgetbook.
class CgSheetGallery extends StatelessWidget {
  const CgSheetGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    void noop() {}

    Widget onScrim(Widget panel) => ColoredBox(
          color: c.scrim,
          child: Padding(padding: const EdgeInsets.only(top: CgSpace.s8), child: panel),
        );

    Widget setting(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: CgSpace.s2),
          child: Row(children: [
            Expanded(child: Text(label, style: CgType.head.copyWith(color: c.ink))),
            Text(value, style: CgType.bodyS.copyWith(color: c.ink2)),
          ]),
        );

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        onScrim(CgSheetPanel(
          title: 'Personnaliser la session',
          expand: false,
          primary: CgButton(label: 'Commencer', onPressed: noop),
          secondary: CgButton(label: 'Réinitialiser', onPressed: noop, variant: CgButtonVariant.quiet),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            setting('Durée', '20 min'),
            setting('Collèges', 'Tous'),
          ]),
        )),
        onScrim(CgSheetPanel.dialog(
          title: 'Quitter la session ?',
          message: '12 fiches jugées sont enregistrées. Tu reprendras à la fiche suivante.',
          confirmLabel: 'Quitter',
          cancelLabel: 'Continuer',
          onConfirm: noop,
          onCancel: noop,
        )),
        onScrim(CgSheetPanel.dialog(
          title: 'Supprimer cette fiche ?',
          message: 'Elle disparaît de tes révisions. Tes autres fiches restent.',
          confirmLabel: 'Supprimer',
          cancelLabel: 'Garder la fiche',
          destructive: true,
          onConfirm: noop,
          onCancel: noop,
        )),
      ]),
    );
  }
}

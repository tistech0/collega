import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:collega_app/core/ui/components/cg_button.dart';
import 'package:collega_app/core/ui/components/cg_sheet.dart';
import 'package:collega_app/core/ui/gallery/cg_sheet_gallery.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';

/// Un bouton qui ouvre une sheet (la route est poussée sur le Navigator racine).
Widget _opener(String label, void Function(BuildContext context) open) => Builder(
      builder: (context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(CgSpace.gutter),
          child: CgButton(label: label, expand: false, onPressed: () => open(context)),
        ),
      ),
    );

void _openDetent(BuildContext context, CgSheetDetent detent) {
  showCgSheet<void>(
    context,
    title: detent == CgSheetDetent.half ? 'Personnaliser la session' : 'Rechercher',
    detent: detent,
    builder: (_) => const Text('Contenu de la sheet. Glisse vers le bas ou touche le voile pour fermer.'),
    primary: CgButton(
      label: 'Commencer',
      onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
    ),
    secondary: CgButton(
      label: 'Réinitialiser',
      variant: CgButtonVariant.quiet,
      onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
    ),
  );
}

final WidgetbookComponent cgSheetComponent = WidgetbookComponent(
  name: 'CgSheet',
  useCases: [
    WidgetbookUseCase(name: 'Planche (panneaux statiques)', builder: (_) => const CgSheetGallery()),
    WidgetbookUseCase(
      name: 'Sheet moitié',
      builder: (_) => _opener('Ouvrir la sheet', (context) => _openDetent(context, CgSheetDetent.half)),
    ),
    WidgetbookUseCase(
      name: 'Sheet plein écran',
      builder: (_) => _opener('Ouvrir la sheet', (context) => _openDetent(context, CgSheetDetent.full)),
    ),
    WidgetbookUseCase(
      name: 'Dialog',
      builder: (context) {
        final destructive = context.knobs.boolean(label: 'Destructif');
        return _opener('Ouvrir le dialog', (context) {
          showCgDialogSheet(
            context,
            title: destructive ? 'Supprimer cette fiche ?' : 'Quitter la session ?',
            message: destructive
                ? 'Elle disparaît de tes révisions. Tes autres fiches restent.'
                : '12 fiches jugées sont enregistrées. Tu reprendras à la fiche suivante.',
            confirmLabel: destructive ? 'Supprimer' : 'Quitter',
            cancelLabel: destructive ? 'Garder la fiche' : 'Continuer',
            destructive: destructive,
          );
        });
      },
    ),
    WidgetbookUseCase(
      name: 'Action sheet',
      builder: (_) => _opener('Ouvrir les actions', (context) {
        showCgActionSheet(
          context,
          title: 'Cette fiche',
          actions: [
            CgSheetAction(label: 'Signaler la fiche', onPressed: () {}),
            CgSheetAction(label: 'Supprimer la fiche', onPressed: () {}, destructive: true),
          ],
        );
      }),
    ),
  ],
);

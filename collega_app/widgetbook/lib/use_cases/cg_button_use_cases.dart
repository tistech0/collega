import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:collega_app/core/ui/components/cg_button.dart';
import 'package:collega_app/core/ui/gallery/cg_button_gallery.dart';

final WidgetbookComponent cgButtonComponent = WidgetbookComponent(
  name: 'CgButton',
  useCases: [
    WidgetbookUseCase(name: 'Planche (toutes variantes)', builder: (_) => const CgButtonGallery()),
    WidgetbookUseCase(
      name: 'Interactif',
      builder: (context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: CgButton(
            label: context.knobs.string(label: 'Libellé', initialValue: 'Commencer'),
            variant: context.knobs.list(
              label: 'Variante',
              options: CgButtonVariant.values,
              labelBuilder: (v) => v.name,
            ),
            size: context.knobs.list(
              label: 'Taille',
              options: CgButtonSize.values,
              labelBuilder: (v) => v.name,
            ),
            loading: context.knobs.boolean(label: 'Chargement'),
            expand: context.knobs.boolean(label: 'Pleine largeur', initialValue: true),
            onPressed: context.knobs.boolean(label: 'Désactivé') ? null : () {},
          ),
        ),
      ),
    ),
  ],
);

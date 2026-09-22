import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:collega_app/core/ui/components/cg_field.dart';
import 'package:collega_app/core/ui/gallery/cg_field_gallery.dart';

final WidgetbookComponent cgFieldComponent = WidgetbookComponent(
  name: 'CgField',
  useCases: [
    WidgetbookUseCase(name: 'Planche (toutes variantes)', builder: (_) => const CgFieldGallery()),
    WidgetbookUseCase(
      name: 'Interactif',
      builder: (context) {
        final kind = context.knobs.list(
          label: 'Variante',
          options: CgFieldKind.values,
          labelBuilder: (v) => v.name,
        );
        final label = context.knobs.stringOrNull(label: 'Libellé', initialValue: 'Email');
        final error = context.knobs.stringOrNull(label: 'Erreur', initialValue: null);
        // Clé par variante : changer de variante repart d'un champ vide.
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: CgField(
              key: ValueKey(kind),
              kind: kind,
              label: kind == CgFieldKind.search ? null : label,
              placeholder: context.knobs.string(label: 'Placeholder', initialValue: 'prenom@exemple.fr'),
              helper: context.knobs.stringOrNull(label: 'Aide', initialValue: 'Celui de ton compte Collega'),
              error: (error == null || error.isEmpty) ? null : error,
              enabled: !context.knobs.boolean(label: 'Désactivé'),
            ),
          ),
        );
      },
    ),
  ],
);

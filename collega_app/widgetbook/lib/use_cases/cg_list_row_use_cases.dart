import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:collega_app/core/ui/components/cg_list_row.dart';
import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/gallery/cg_list_row_gallery.dart';

final WidgetbookComponent cgListRowComponent = WidgetbookComponent(
  name: 'CgListRow / CgListGroup',
  useCases: [
    WidgetbookUseCase(name: 'Planche (toutes variantes)', builder: (_) => const CgListRowGallery()),
    WidgetbookUseCase(
      name: 'Interactif',
      builder: (context) {
        final trailing = context.knobs.list(
          label: 'Trailing',
          options: const [CgRowTrailing.chevron, CgRowTrailing.value, CgRowTrailing.action, CgRowTrailing.check, CgRowTrailing.none],
          labelBuilder: (v) => v.name,
        );
        final rows = context.knobs.int.slider(label: 'Lignes', initialValue: 3, min: 1, max: 6);
        final title = context.knobs.string(label: 'Titre', initialValue: 'Cancérologie');
        final subtitle = context.knobs.stringOrNull(label: 'Sous-titre', initialValue: '177 fiches · 42 % maîtrisées');
        final enabled = !context.knobs.boolean(label: 'Désactivée (non importé)');
        final selected = context.knobs.boolean(label: 'Sélectionnée');
        final leading = context.knobs.boolean(label: 'Icône', initialValue: true);
        final progress = context.knobs.boolean(label: 'Progression');
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: CgListGroup(
            variant: context.knobs.list(
              label: 'Variante',
              options: CgListVariant.values,
              labelBuilder: (v) => v.name,
            ),
            header: context.knobs.stringOrNull(label: 'Intertitre', initialValue: 'Mes collèges'),
            children: [
              for (var i = 0; i < rows; i++)
                CgListRow(
                  title: i == 0 ? title : '$title ${i + 1}',
                  subtitle: subtitle,
                  leading: leading ? CgRowIcon(CgIcons.document, muted: !enabled) : null,
                  trailing: trailing,
                  value: '42 %',
                  actionLabel: 'Importer',
                  onAction: () {},
                  selected: selected && i == 0,
                  enabled: enabled,
                  progress: progress ? const GalleryProgress(mastered: 0.42, good: 0.14, review: 0.06) : null,
                  onTap: () {},
                ),
            ],
          ),
        );
      },
    ),
  ],
);

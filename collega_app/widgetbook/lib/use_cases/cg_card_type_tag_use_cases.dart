import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:collega_app/core/ui/components/cg_card_type_tag.dart';
import 'package:collega_app/core/ui/gallery/cg_card_type_tag_gallery.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';

final WidgetbookComponent cgCardTypeTagComponent = WidgetbookComponent(
  name: 'CgCardTypeTag',
  useCases: [
    WidgetbookUseCase(name: 'Planche (toutes variantes)', builder: (_) => const CgCardTypeTagGallery()),
    WidgetbookUseCase(
      name: 'Interactif',
      builder: (context) {
        final type = context.knobs.list(
          label: 'Type',
          options: CgCardType.values,
          labelBuilder: (t) => t.name,
        );
        final onAccent = context.knobs.boolean(label: 'Sur le recto (accent)');
        final tag = CgCardTypeTag(type, onAccent: onAccent);
        return Center(
          child: onAccent
              ? ColoredBox(
                  color: CgTheme.of(context).colors.accent,
                  child: Padding(padding: const EdgeInsets.all(CgSpace.s4), child: tag),
                )
              : tag,
        );
      },
    ),
  ],
);

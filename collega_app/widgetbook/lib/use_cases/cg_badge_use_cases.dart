import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:collega_app/core/ui/components/cg_badge.dart';
import 'package:collega_app/core/ui/gallery/cg_badge_gallery.dart';

final WidgetbookComponent cgBadgeComponent = WidgetbookComponent(
  name: 'CgBadge',
  useCases: [
    WidgetbookUseCase(name: 'Planche (toutes variantes)', builder: (_) => const CgBadgeGallery()),
    WidgetbookUseCase(
      name: 'Interactif',
      builder: (context) {
        final variant = context.knobs.list(
          label: 'Variante',
          options: const ['rank', 'ocr', 'beta', 'count'],
        );
        final badge = switch (variant) {
          'rank' => CgBadge.rank(
              context.knobs.list(label: 'Rang', options: const ['A', 'B', 'C']),
              short: context.knobs.boolean(label: 'Lettre seule'),
            ),
          'ocr' => CgBadge.ocr(onTap: context.knobs.boolean(label: 'Tapable (OCR)') ? () {} : null),
          'beta' => CgBadge.beta(),
          _ => CgBadge.count(context.knobs.int.slider(label: 'Compteur', initialValue: 12, min: 0, max: 999)),
        };
        return Center(child: badge);
      },
    ),
  ],
);

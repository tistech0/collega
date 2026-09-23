import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:collega_app/core/ui/components/cg_skeleton.dart';
import 'package:collega_app/core/ui/gallery/cg_skeleton_gallery.dart';

final WidgetbookComponent cgSkeletonComponent = WidgetbookComponent(
  name: 'CgSkeleton',
  useCases: [
    WidgetbookUseCase(name: 'Planche (formes et liste)', builder: (_) => const CgSkeletonGallery()),
    WidgetbookUseCase(
      name: 'Interactif',
      // La pulsation tourne ici ; elle se fige quand « Réduire les animations » est actif.
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: CgSkeletonList(
          rows: context.knobs.double.slider(label: 'Lignes', initialValue: 5, min: 1, max: 8, divisions: 7).round(),
        ),
      ),
    ),
  ],
);

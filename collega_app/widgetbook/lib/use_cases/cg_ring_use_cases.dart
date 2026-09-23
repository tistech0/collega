import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:collega_app/core/ui/components/cg_ring.dart';
import 'package:collega_app/core/ui/gallery/cg_ring_gallery.dart';

final WidgetbookComponent cgRingComponent = WidgetbookComponent(
  name: 'CgRing',
  useCases: [
    WidgetbookUseCase(name: 'Planche (toutes tailles)', builder: (_) => const CgRingGallery()),
    WidgetbookUseCase(
      name: 'Interactif',
      // Déplacer le curseur anime l'arc de l'ancienne valeur à la nouvelle.
      builder: (context) => Center(
        child: CgRing(
          value: context.knobs.double.slider(label: 'Valeur', initialValue: 0.42, min: 0, max: 1),
          size: context.knobs.list(
            label: 'Taille',
            options: CgRingSize.values,
            initialOption: CgRingSize.m,
            labelBuilder: (v) => v.name,
          ),
          centerLabel: context.knobs.stringOrNull(label: 'Texte central', initialValue: null),
          animate: context.knobs.boolean(label: 'Animé', initialValue: true),
        ),
      ),
    ),
  ],
);

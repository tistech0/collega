import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:collega_app/core/ui/components/cg_rank_bar.dart';
import 'package:collega_app/core/ui/gallery/cg_rank_bar_gallery.dart';

final WidgetbookComponent cgRankBarComponent = WidgetbookComponent(
  name: 'CgRankBar',
  useCases: [
    WidgetbookUseCase(name: 'Planche (tailles et cas limites)', builder: (_) => const CgRankBarGallery()),
    WidgetbookUseCase(
      name: 'Interactif',
      builder: (context) {
        int count(String label, int initial) =>
            context.knobs.double.slider(label: label, initialValue: initial.toDouble(), min: 0, max: 300, divisions: 300).round();
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: CgRankBar(
              mastered: count('Maîtrisées', 104),
              good: count('Bien', 40),
              review: count('À revoir', 17),
              unseen: count('Non vues', 180),
              size: context.knobs.list(
                label: 'Taille',
                options: CgRankBarSize.values,
                initialOption: CgRankBarSize.hero,
                labelBuilder: (v) => v.name,
              ),
              legend: context.knobs.boolean(label: 'Légende', initialValue: true),
            ),
          ),
        );
      },
    ),
  ],
);

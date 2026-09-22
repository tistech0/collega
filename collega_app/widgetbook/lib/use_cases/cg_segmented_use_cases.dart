import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:collega_app/core/ui/components/cg_segmented.dart';
import 'package:collega_app/core/ui/gallery/cg_segmented_gallery.dart';

const _sets = <String, List<String>>{
  'Rangs (4)': ['Tous', 'A', 'B', 'C'],
  'Bibliothèque (2)': ['Tous', 'Importés'],
  'Durées (3)': ['10 min', '20 min', '30 min'],
  'Libellés longs (2)': ['Mes collèges', 'Catalogue complet'],
};

final WidgetbookComponent cgSegmentedComponent = WidgetbookComponent(
  name: 'CgSegmented',
  useCases: [
    WidgetbookUseCase(name: 'Planche (toutes variantes)', builder: (_) => const CgSegmentedGallery()),
    WidgetbookUseCase(
      name: 'Interactif',
      builder: (context) {
        final values = _sets[context.knobs.list(label: 'Valeurs', options: _sets.keys.toList())]!;
        // Clé par jeu de valeurs : changer de jeu repart de la première valeur.
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _Interactive(key: ValueKey(values), values: values),
          ),
        );
      },
    ),
  ],
);

class _Interactive extends StatefulWidget {
  const _Interactive({super.key, required this.values});

  final List<String> values;

  @override
  State<_Interactive> createState() => _InteractiveState();
}

class _InteractiveState extends State<_Interactive> {
  late String _selected = widget.values.first;

  @override
  Widget build(BuildContext context) => CgSegmented<String>(
        values: widget.values,
        labelOf: (v) => v,
        selected: _selected,
        onChanged: (v) => setState(() => _selected = v),
      );
}

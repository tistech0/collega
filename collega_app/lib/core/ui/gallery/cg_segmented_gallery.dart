import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/components/cg_segmented.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Planche de toutes les variantes et états de [CgSegmented] (Widgetbook + goldens).
/// Chaque exemple est vivant : taper change la sélection.
class CgSegmentedGallery extends StatelessWidget {
  const CgSegmentedGallery({super.key});

  /// Échelle de démonstration du mode liste (au-delà du seuil de 1,6×).
  static const _listDemoScale = 1.8;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    Widget caption(String text) => Padding(
          padding: const EdgeInsets.only(top: CgSpace.s5, bottom: CgSpace.related),
          child: Text(text, style: CgType.label.copyWith(color: c.ink3)),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(CgSpace.gutter),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        caption('4 valeurs · rangs'),
        const _Demo(values: ['Tous', 'A', 'B', 'C'], initial: 'Tous'),
        caption('2 valeurs · bibliothèque'),
        const _Demo(values: ['Tous', 'Importés'], initial: 'Importés'),
        caption('3 valeurs · durée de session'),
        const _Demo(values: ['10 min', '20 min', '30 min'], initial: '20 min'),
        caption('Libellés longs (deux lignes)'),
        const _Demo(values: ['Mes collèges', 'Catalogue complet'], initial: 'Mes collèges'),
        caption('Dynamic Type > 1,6 : liste à coche'),
        Builder(builder: (context) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(_listDemoScale)),
            child: const _Demo(values: ['Tous', 'A', 'B', 'C'], initial: 'B'),
          );
        }),
      ]),
    );
  }
}

class _Demo extends StatefulWidget {
  const _Demo({required this.values, required this.initial});

  final List<String> values;
  final String initial;

  @override
  State<_Demo> createState() => _DemoState();
}

class _DemoState extends State<_Demo> {
  late String _selected = widget.initial;

  @override
  Widget build(BuildContext context) => CgSegmented<String>(
        values: widget.values,
        labelOf: (v) => v,
        selected: _selected,
        onChanged: (v) => setState(() => _selected = v),
      );
}

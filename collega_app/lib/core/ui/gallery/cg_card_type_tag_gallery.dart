import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/components/cg_badge.dart';
import 'package:collega_app/core/ui/components/cg_card_type_tag.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Libellés de démonstration (en production : `CardType.label`, côté domaine).
const _casClinique = 'Cas clinique';
const _definition = 'Définition';

/// Planche de [CgCardTypeTag] (Widgetbook + goldens) : sur fond clair, à côté du
/// badge de rang, et sur le recto `accent` du drill.
class CgCardTypeTagGallery extends StatelessWidget {
  const CgCardTypeTagGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    Widget caption(String text) => Padding(
          padding: const EdgeInsets.only(top: CgSpace.s5, bottom: CgSpace.related),
          child: Text(text, style: CgType.label.copyWith(color: c.ink3)),
        );
    Widget line(List<Widget> children) => Wrap(
          spacing: CgSpace.s2,
          runSpacing: CgSpace.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(CgSpace.gutter),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        caption('Types (rien pour une fiche classique)'),
        line(const [CgCardTypeTag(_casClinique), CgCardTypeTag(_definition)]),
        caption('Avec le rang de la fiche (liste des fiches)'),
        line([CgBadge.rank('A', short: true), const CgCardTypeTag(_casClinique)]),
        const SizedBox(height: CgSpace.s2),
        line([CgBadge.rank('B', short: true), const CgCardTypeTag(_definition)]),
        caption('Sur le recto du drill'),
        DecoratedBox(
          decoration: BoxDecoration(color: c.accent, borderRadius: CgRadius.sAll),
          child: Padding(
            padding: const EdgeInsets.all(CgSpace.s4),
            child: line(const [
              CgCardTypeTag(_casClinique, onAccent: true),
              CgCardTypeTag(_definition, onAccent: true),
            ]),
          ),
        ),
      ]),
    );
  }
}

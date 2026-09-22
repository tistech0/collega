import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/components/cg_badge.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Planche de toutes les variantes et états de [CgBadge] (Widgetbook + goldens).
class CgBadgeGallery extends StatelessWidget {
  const CgBadgeGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    void noop() {}
    Widget caption(String text) => Padding(
          padding: const EdgeInsets.only(top: CgSpace.s5, bottom: CgSpace.related),
          child: Text(text, style: CgType.label.copyWith(color: c.ink3)),
        );
    Widget line(List<Widget> badges) => Wrap(
          spacing: CgSpace.s2,
          runSpacing: CgSpace.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: badges,
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(CgSpace.gutter),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        caption('Rang'),
        line([CgBadge.rank('A'), CgBadge.rank('B'), CgBadge.rank('C')]),
        caption('Rang court (lignes d\'items)'),
        line([CgBadge.rank('A', short: true), CgBadge.rank('B', short: true), CgBadge.rank('C', short: true)]),
        caption('OCR : informatif · tapable (cible 44\u00A0pt)'),
        line([CgBadge.ocr(), CgBadge.ocr(onTap: noop)]),
        caption('Beta · compteur'),
        line([CgBadge.beta(), CgBadge.count(3), CgBadge.count(128)]),
      ]),
    );
  }
}

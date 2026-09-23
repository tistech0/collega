import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/components/cg_skeleton.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Planche des formes de [CgSkeleton] et de [CgSkeletonList] (Widgetbook + goldens).
///
/// Les goldens tournent en mouvement réduit : la pulsation y est figée à 1.
class CgSkeletonGallery extends StatelessWidget {
  const CgSkeletonGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    Widget caption(String text) => Padding(
          padding: const EdgeInsets.only(bottom: CgSpace.related),
          child: Text(text, style: CgType.label.copyWith(color: c.ink3)),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(CgSpace.gutter),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        caption('line · block · ring'),
        const CgSkeleton.line(),
        const SizedBox(height: CgSpace.s2),
        const CgSkeleton.line(width: 180),
        const SizedBox(height: CgSpace.s4),
        const CgSkeleton.block(height: 96),
        const SizedBox(height: CgSpace.s4),
        const Row(children: [
          CgSkeleton.ring(),
          SizedBox(width: CgSpace.s4),
          CgSkeleton.ring(size: 84),
        ]),
        const SizedBox(height: CgSpace.section),
        caption('CgSkeletonList (3 lignes)'),
        const CgSkeletonList(rows: 3),
      ]),
    );
  }
}

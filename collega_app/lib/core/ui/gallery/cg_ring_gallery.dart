import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/components/cg_ring.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';

/// Planche de toutes les tailles et valeurs de [CgRing] (Widgetbook + goldens).
///
/// Les goldens tournent en mouvement réduit : les anneaux y sont à leur valeur.
class CgRingGallery extends StatelessWidget {
  const CgRingGallery({super.key});

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: CgSpace.section);
    return const SingleChildScrollView(
      padding: EdgeInsets.all(CgSpace.gutter),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // s : 0 (rail seul), faible, moyen, plein.
        Wrap(spacing: CgSpace.s4, runSpacing: CgSpace.s4, children: [
          CgRing(value: 0),
          CgRing(value: 0.18),
          CgRing(value: 0.42),
          CgRing(value: 1),
        ]),
        gap,
        Wrap(spacing: CgSpace.s4, runSpacing: CgSpace.s4, children: [
          CgRing(value: 0.42, size: CgRingSize.m),
          CgRing(value: 0.74, size: CgRingSize.m),
          CgRing(value: 0.5, size: CgRingSize.m, centerLabel: '12/24'),
        ]),
        gap,
        Center(child: CgRing(value: 0.42, size: CgRingSize.l)),
      ]),
    );
  }
}

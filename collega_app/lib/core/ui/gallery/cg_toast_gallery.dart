import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/components/cg_toast.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';

/// Planche de [CgToastCapsule] rendue statiquement (Widgetbook + goldens) :
/// messages courts et message trop long (une ligne, ellipse).
class CgToastGallery extends StatelessWidget {
  const CgToastGallery({super.key});

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: CgSpace.s4);
    return const SingleChildScrollView(
      padding: EdgeInsets.all(CgSpace.gutter),
      child: Column(children: [
        CgToastCapsule(message: 'Elle reviendra dans quelques questions'),
        gap,
        CgToastCapsule(message: 'Fiche signalée'),
        gap,
        CgToastCapsule(message: 'Rappel enregistré pour demain matin à 8 h, tous les jours de la semaine'),
      ]),
    );
  }
}

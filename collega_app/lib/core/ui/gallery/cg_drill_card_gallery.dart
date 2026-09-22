import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/components/cg_drill_card.dart';

/// États figés de la planche [CgDrillCardGallery].
enum CgDrillCardGalleryState { recto, verso, drag }

/// Planche de [CgDrillCard] (Widgetbook + goldens), écran plein : recto, verso,
/// et verso en cours de glissé vers la gauche (étiquette « À revoir » pleine,
/// rotation) grâce à `debugDragOffset`.
class CgDrillCardGallery extends StatelessWidget {
  const CgDrillCardGallery({super.key, this.state = CgDrillCardGalleryState.recto});

  final CgDrillCardGalleryState state;

  /// Au-delà de 40 + 80 pt : étiquette à pleine opacité.
  static const _dragOffset = Offset(-130, 0);

  static const question = 'Quel est le schéma vaccinal contre HPV (Gardasil 9) recommandé en France ?';
  static const answer = 'Filles et garçons dès 11 ans : 2 doses entre 11 et 14 ans, 3 doses entre 15 et 19 ans. '
      'Rattrapage jusqu\'à 26 ans pour les HSH. Prise en charge à 65 % par l\'Assurance maladie.';

  @override
  Widget build(BuildContext context) {
    return CgDrillCard(
      question: question,
      answer: answer,
      rank: 'A',
      collegeName: 'Cancérologie',
      index: 3,
      total: 24,
      onVerdict: (_) {},
      onClose: () {},
      initiallyFlipped: state != CgDrillCardGalleryState.recto,
      debugDragOffset: state == CgDrillCardGalleryState.drag ? _dragOffset : null,
    );
  }
}

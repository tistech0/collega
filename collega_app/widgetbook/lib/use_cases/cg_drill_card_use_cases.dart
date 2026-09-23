import 'package:flutter/widgets.dart';
import 'package:widgetbook/widgetbook.dart';

import 'package:collega_app/core/ui/components/cg_drill_card.dart';
import 'package:collega_app/core/ui/gallery/cg_drill_card_gallery.dart';

final WidgetbookComponent cgDrillCardComponent = WidgetbookComponent(
  name: 'CgDrillCard',
  useCases: [
    WidgetbookUseCase(
      name: 'Recto',
      builder: (_) => const CgDrillCardGallery(state: CgDrillCardGalleryState.recto),
    ),
    WidgetbookUseCase(
      name: 'Verso',
      builder: (_) => const CgDrillCardGallery(state: CgDrillCardGalleryState.verso),
    ),
    WidgetbookUseCase(
      name: 'Glissé en cours (« À revoir »)',
      builder: (_) => const CgDrillCardGallery(state: CgDrillCardGalleryState.drag),
    ),
    WidgetbookUseCase(
      name: 'Session jouable (3 fiches)',
      builder: (context) => _DrillPlayground(
        reduceMotion: context.knobs.boolean(label: 'Réduire les animations'),
        showFlipHint: context.knobs.boolean(label: 'Invite de retournement', initialValue: true),
      ),
    ),
  ],
);

typedef _Card = ({String question, String answer, String rank, String college});

const _cards = <_Card>[
  (
    question: 'Quel est le schéma vaccinal contre HPV (Gardasil 9) recommandé en France ?',
    answer: 'Filles et garçons dès 11 ans : 2 doses entre 11 et 14 ans, 3 doses entre 15 et 19 ans. '
        'Rattrapage jusqu\'à 26 ans pour les HSH. Prise en charge à 65 % par l\'Assurance maladie.',
    rank: 'A',
    college: 'Cancérologie',
  ),
  (
    question: 'Quels sont les critères de gravité d\'une pneumopathie aiguë communautaire ?',
    answer: 'Score CRB-65 : confusion, fréquence respiratoire ≥ 30/min, PAS < 90 mmHg ou PAD ≤ 60 mmHg, '
        'âge ≥ 65 ans. Hospitalisation dès 1 critère, réanimation si signes de choc ou de détresse.',
    rank: 'B',
    college: 'Pneumologie',
  ),
  (
    question: 'Quelle est la première mesure devant une hyperkaliémie avec signes ECG ?',
    answer: 'Gluconate de calcium 10 % IV lente (cardioprotection immédiate), sous scope, '
        'puis insuline-glucose et traitement de la cause.',
    rank: 'A',
    college: 'Néphrologie',
  ),
];

/// Session de démonstration : les verdicts enchaînent les 3 fiches (l'écran,
/// pas la carte, passe à la suivante) ; ✕ recommence.
class _DrillPlayground extends StatefulWidget {
  const _DrillPlayground({required this.reduceMotion, required this.showFlipHint});

  final bool reduceMotion;
  final bool showFlipHint;

  @override
  State<_DrillPlayground> createState() => _DrillPlaygroundState();
}

class _DrillPlaygroundState extends State<_DrillPlayground> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final card = _cards[_index % _cards.length];
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: widget.reduceMotion),
      child: CgDrillCard(
        question: card.question,
        answer: card.answer,
        rank: card.rank,
        collegeName: card.college,
        index: _index % _cards.length + 1,
        total: _cards.length,
        showFlipHint: widget.showFlipHint,
        onVerdict: (_) => setState(() => _index++),
        onClose: () => setState(() => _index = 0),
      ),
    );
  }
}

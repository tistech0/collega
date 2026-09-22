import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/components/cg_rank_bar.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Planche des tailles et cas limites de [CgRankBar] (Widgetbook + goldens).
class CgRankBarGallery extends StatelessWidget {
  const CgRankBarGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    const gap = SizedBox(height: CgSpace.section);
    Widget caption(String text) => Padding(
          padding: const EdgeInsets.only(bottom: CgSpace.related),
          child: Text(text, style: CgType.label.copyWith(color: c.ink3)),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(CgSpace.gutter),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        caption('hero · 22 pt + légende (Progression)'),
        const CgRankBar(mastered: 104, good: 40, review: 17, unseen: 180, size: CgRankBarSize.hero, legend: true),
        gap,
        caption('header · 10 pt + légende (Détail collège)'),
        const CgRankBar(mastered: 74, good: 25, review: 11, unseen: 67, size: CgRankBarSize.header, legend: true),
        gap,
        caption('row · 6 pt (lignes)'),
        const CgRankBar(mastered: 42, good: 14, review: 6, unseen: 38),
        const SizedBox(height: CgSpace.row),
        const CgRankBar(mastered: 3, good: 0, review: 2, unseen: 5),
        const SizedBox(height: CgSpace.row),
        caption('tout maîtrisé · rien de vu · total nul'),
        const CgRankBar(mastered: 7, good: 0, review: 0, unseen: 0),
        const SizedBox(height: CgSpace.row),
        const CgRankBar(mastered: 0, good: 0, review: 0, unseen: 4),
        const SizedBox(height: CgSpace.row),
        const CgRankBar(mastered: 0, good: 0, review: 0, unseen: 0),
      ]),
    );
  }
}

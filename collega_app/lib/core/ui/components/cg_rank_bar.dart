import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// `row` 6 pt (lignes), `header` 10 pt (tête de collège), `hero` 22 pt (tête de Progression).
enum CgRankBarSize { row, header, hero }

/// Répartition Maîtrisé / Bien / À revoir / Non vues (spec v2 § CgRankBar).
///
/// Les segments `mastered` → `good` → `review` partent de la gauche et sont
/// proportionnels au **total** de fiches (non vues comprises) : le reste de la
/// largeur est le rail `unseen`. Total nul : rail seul.
///
/// Jamais sans les chiffres à proximité : soit [legend], soit un texte voisin
/// (« 177 fiches · 42 % maîtrisées »). Demande une largeur bornée.
class CgRankBar extends StatelessWidget {
  const CgRankBar({
    super.key,
    required this.mastered,
    required this.good,
    required this.review,
    required this.unseen,
    this.size = CgRankBarSize.row,
    this.legend = false,
  })  : assert(mastered >= 0 && good >= 0 && review >= 0 && unseen >= 0);

  final int mastered;
  final int good;
  final int review;
  final int unseen;
  final CgRankBarSize size;

  /// Légende sous la barre : pastille + « 104 maîtrisées », etc.
  final bool legend;

  /// Repères des segments et du rail (tests, captures).
  static const masteredKey = ValueKey('cg-rank-bar-mastered');
  static const goodKey = ValueKey('cg-rank-bar-good');
  static const reviewKey = ValueKey('cg-rank-bar-review');
  static const railKey = ValueKey('cg-rank-bar-rail');

  /// Hauteurs (spec v2) ; rayon = moitié de la hauteur, sauf `hero` (8).
  static const _heightRow = 6.0;
  static const _heightHeader = 10.0;
  static const _heightHero = 22.0;
  static const _radiusHero = 8.0;

  /// Légende de la maquette (`.leg`) : pastille 10 pt à coins de 2 pt.
  static const _dotSize = 10.0;
  static const _dotRadius = 2.0;
  static const _dotGap = CgSpace.s1;
  static const _legendGapX = CgSpace.s3;
  static const _legendGapY = CgSpace.s2;

  int get _total => mastered + good + review + unseen;

  /// « 104 maîtrisées, 40 bien, 17 à revoir, 180 non vues » (accord au singulier).
  List<String> get _labels => [
        '$mastered ${mastered > 1 ? 'maîtrisées' : 'maîtrisée'}',
        '$good bien',
        '$review à revoir',
        '$unseen ${unseen > 1 ? 'non vues' : 'non vue'}',
      ];

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final (double height, double radius) = switch (size) {
      CgRankBarSize.row => (_heightRow, _heightRow / 2),
      CgRankBarSize.header => (_heightHeader, _heightHeader / 2),
      CgRankBarSize.hero => (_heightHero, _radiusHero),
    };
    final total = _total;
    final segments = [
      (masteredKey, mastered, c.mastered),
      (goodKey, good, c.good),
      (reviewKey, review, c.review),
    ];

    final Widget bar = ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(radius)),
      child: ColoredBox(
        key: railKey,
        color: c.unseen,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: LayoutBuilder(builder: (context, constraints) {
            // Total nul : aucun segment (et aucune division par zéro).
            if (total == 0) return const SizedBox.shrink();
            return Row(children: [
              for (final (key, count, color) in segments)
                if (count > 0)
                  ColoredBox(
                    key: key,
                    color: color,
                    child: SizedBox(width: constraints.maxWidth * count / total, height: height),
                  ),
            ]);
          }),
        ),
      ),
    );

    final labels = _labels;
    return Semantics(
      container: true,
      label: labels.join(', '),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bar,
          if (legend) ...[
            const SizedBox(height: CgSpace.related),
            Wrap(
              spacing: _legendGapX,
              runSpacing: _legendGapY,
              children: [
                for (final (i, color) in [c.mastered, c.good, c.review, c.unseen].indexed)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.all(Radius.circular(_dotRadius)),
                      ),
                      child: const SizedBox.square(dimension: _dotSize),
                    ),
                    const SizedBox(width: _dotGap),
                    Flexible(child: Text(labels[i], style: CgType.label.copyWith(color: c.ink2))),
                  ]),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Étiquette du type de fiche (spec chantier 4 § 7) : « Cas clinique »,
/// « Définition ». [label] null (fiche classique) : rien n'est affiché. Le
/// libellé vient du domaine (`CardType.label`) : Collega UI ne connaît pas les types.
///
/// Même gabarit que [CgBadge] (22 pt, grandit avec le Dynamic Type, `label` 600)
/// mais **contourée** là où le badge de rang est plein : les deux se distinguent
/// côte à côte sans couleur nouvelle. Le mot porte l'information, jamais la couleur.
/// [onAccent] : posée sur le recto `accent` du drill (texte et contour `accentInk`).
class CgCardTypeTag extends StatelessWidget {
  const CgCardTypeTag(this.label, {super.key, this.onAccent = false});

  final String? label;
  final bool onAccent;

  static const _minHeight = 22.0;
  static const _borderWidth = 1.0;

  /// Contour sur `accent` : `accentInk` estompé, comme le fond du badge de rang du drill.
  static const _onAccentBorderAlpha = 0.6;

  /// Couleurs (contour, texte) selon le fond.
  static (Color border, Color ink) colorsFor(CgColors c, {required bool onAccent}) =>
      onAccent ? (c.accentInk.withValues(alpha: _onAccentBorderAlpha), c.accentInk) : (c.ink3, c.ink2);

  @override
  Widget build(BuildContext context) {
    final text = label;
    if (text == null) return const SizedBox.shrink();
    final (border, ink) = colorsFor(CgTheme.of(context).colors, onAccent: onAccent);

    return Semantics(
      container: true,
      label: 'Fiche ${text.toLowerCase()}',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _minHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: CgRadius.badgeAll,
            border: Border.all(color: border, width: _borderWidth),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CgSpace.s2),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                text,
                maxLines: 1,
                softWrap: false,
                style: CgType.label.copyWith(color: ink, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

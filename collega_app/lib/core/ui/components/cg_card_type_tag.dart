import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Type d'une fiche (`card_type` du serveur, chantier 4).
enum CgCardType {
  classique,
  casClinique,
  definition;

  /// Valeur du serveur → type ; inconnue : classique (elle se révise comme telle).
  static CgCardType parse(String? value) => switch (value) {
        'cas_clinique' => CgCardType.casClinique,
        'definition' => CgCardType.definition,
        _ => CgCardType.classique,
      };

  /// Libellé affiché ; null pour la fiche classique (aucune étiquette).
  String? get label => switch (this) {
        CgCardType.classique => null,
        CgCardType.casClinique => 'Cas clinique',
        CgCardType.definition => 'Définition',
      };

  /// Ordre des listes de fiches : classique, cas clinique, définition.
  int get sortOrder => index;
}

/// Étiquette du type de fiche (spec chantier 4 § 7) : « Cas clinique » ou
/// « Définition », rien pour une fiche classique.
///
/// Même gabarit que [CgBadge] (22 pt, grandit avec le Dynamic Type, `label` 600)
/// mais **contourée** là où le badge de rang est plein : les deux se distinguent
/// côte à côte sans couleur nouvelle. Le mot porte l'information, jamais la couleur.
/// [onAccent] : posée sur le recto `accent` du drill (texte et contour `accentInk`).
class CgCardTypeTag extends StatelessWidget {
  const CgCardTypeTag(this.type, {super.key, this.onAccent = false});

  /// Depuis la valeur `card_type` du serveur.
  CgCardTypeTag.fromApi(String? cardType, {Key? key, bool onAccent = false})
      : this(CgCardType.parse(cardType), key: key, onAccent: onAccent);

  final CgCardType type;
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
    final label = type.label;
    if (label == null) return const SizedBox.shrink();
    final (border, ink) = colorsFor(CgTheme.of(context).colors, onAccent: onAccent);

    return Semantics(
      container: true,
      label: 'Fiche ${label.toLowerCase()}',
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
                label,
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

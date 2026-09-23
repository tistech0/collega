import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/foundation/cg_haptics.dart';
import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Sélecteur de 2 à 4 valeurs exclusives (spec v2 § CgSegmented) : filtres
/// « Tous / A / B / C », « Tous / Importés », durées de session.
///
/// Composant contrôlé : le parent tient [selected] et le met à jour dans
/// [onChanged]. Retaper la valeur déjà choisie ne fait rien. Au-delà de 1,6×
/// de Dynamic Type, les segments ne tiennent plus : le composant devient une
/// liste de lignes à coche (même contrat, mêmes Semantics).
class CgSegmented<T> extends StatelessWidget {
  CgSegmented({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  })  : assert(values.length >= 2 && values.length <= 4, 'CgSegmented : 2 à 4 valeurs'),
        assert(values.contains(selected), 'CgSegmented : selected doit faire partie de values');

  final List<T> values;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Retrait de la pastille dans sa cellule (maquette `.seg` : padding 3 px).
  static const _pillInset = 3.0;
  static const _pillRadius = BorderRadius.all(Radius.circular(CgRadius.s - _pillInset));

  /// Ombre légère de la pastille (maquette : 0 1px 3px rgba(0,0,0,.08)), teintée `ink`.
  static const _pillShadowAlpha = 0.08;
  static const _pillShadowBlur = 3.0;
  static const _pillShadowOffset = Offset(0, 1);

  /// Au-delà de cette échelle de texte : liste de lignes à coche.
  static const _listModeScale = 1.6;
  static const _labelMaxLines = 2;

  void _select(T value) {
    if (value == selected) return;
    CgHaptics.selection();
    onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return scale > _listModeScale ? _buildList(context) : _buildRail(context);
  }

  Widget _buildRail(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final index = values.indexOf(selected);
    return DecoratedBox(
      key: const ValueKey('cg-segmented-rail'),
      decoration: BoxDecoration(color: c.soft, borderRadius: CgRadius.sAll),
      child: LayoutBuilder(builder: (context, constraints) {
        final cell = constraints.maxWidth / values.length;
        return Stack(children: [
          AnimatedPositioned(
            key: const ValueKey('cg-segmented-pill'),
            duration: CgMotion.resolve(context, CgMotion.base),
            curve: CgMotion.out,
            left: index * cell + _pillInset,
            width: cell - 2 * _pillInset,
            top: _pillInset,
            bottom: _pillInset,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: _pillRadius,
                boxShadow: [
                  BoxShadow(
                    color: c.ink.withValues(alpha: _pillShadowAlpha),
                    blurRadius: _pillShadowBlur,
                    offset: _pillShadowOffset,
                  ),
                ],
              ),
            ),
          ),
          // Hauteur commune : si un libellé passe sur deux lignes, toutes les
          // cellules (et la pastille) prennent sa hauteur.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final value in values) Expanded(child: _segment(context, value)),
              ],
            ),
          ),
        ]);
      }),
    );
  }

  /// Une cellule : toute sa hauteur (≥ 44 pt, rail compris) est tapable.
  Widget _segment(BuildContext context, T value) {
    final c = CgTheme.of(context).colors;
    final on = value == selected;
    final label = labelOf(value);
    return _semantics(
      key: const ValueKey('cg-segmented-segment'),
      value: value,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CgSpace.tapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CgSpace.s1 + _pillInset, vertical: CgSpace.s2),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: _labelMaxLines,
                overflow: TextOverflow.ellipsis,
                style: CgType.bodyS.copyWith(
                  color: on ? c.ink : c.ink2,
                  // Maquette : 500 au repos, 600 sélectionné.
                  fontWeight: on ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Dynamic Type > 1,6 : une ligne par valeur, coche `accent` sur la sélection.
  Widget _buildList(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.surface, borderRadius: CgRadius.lAll),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final (i, value) in values.indexed) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.only(left: CgSpace.rowInset),
              child: SizedBox(height: 1, width: double.infinity, child: ColoredBox(color: c.line)),
            ),
          KeyedSubtree(key: ValueKey(i), child: _row(context, value)),
        ],
      ]),
    );
  }

  Widget _row(BuildContext context, T value) {
    final c = CgTheme.of(context).colors;
    final on = value == selected;
    final label = labelOf(value);
    // La coche suit le Dynamic Type : même taille que le texte qu'elle marque.
    final checkSize = MediaQuery.textScalerOf(context).scale(CgType.bodyS.fontSize!);
    return _semantics(
      key: const ValueKey('cg-segmented-row'),
      value: value,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _select(value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CgSpace.tapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CgSpace.rowInset, vertical: CgSpace.s2),
            child: Row(children: [
              Expanded(
                child: Text(
                  label,
                  style: CgType.bodyS.copyWith(color: c.ink, fontWeight: on ? FontWeight.w600 : FontWeight.w400),
                ),
              ),
              // La coche garde sa place : le libellé ne bouge pas quand elle apparaît.
              SizedBox.square(
                dimension: checkSize,
                child: on ? CgIcon(CgIcons.check, size: checkSize, color: c.accent) : null,
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _semantics({required Key key, required T value, required String label, required Widget child}) {
    return Semantics(
      key: key,
      container: true,
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: value == selected,
      label: label,
      excludeSemantics: true,
      onTap: () => _select(value),
      child: child,
    );
  }
}

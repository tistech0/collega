import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/foundation/cg_haptics.dart';
import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Un onglet : icône `CgIcons.*` et libellé lu par VoiceOver.
@immutable
class CgTabItem {
  const CgTabItem({required this.icon, required this.label});

  final String icon;
  final String label;
}

/// Navigation principale (spec v2 § CgTabBar) : capsule flottante, `surface` à
/// 90 % + flou, pastille `accentSoft` qui glisse sous l'onglet actif.
///
/// À poser en bas d'un `Stack` (`Positioned(left: 0, right: 0, bottom: 0)`) :
/// la barre porte elle-même ses marges et la safe area basse. Masquée dans le
/// drill, l'import en cours et les sheets plein écran (c'est l'écran qui ne la
/// pose pas). `collapsed` : pastille d'icônes seules, au défilement vers le bas.
class CgTabBar extends StatelessWidget {
  const CgTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.collapsed = false,
  }) : assert(items.length >= 2);

  final List<CgTabItem> items;
  final int currentIndex;

  /// Appelé à chaque tap, y compris sur l'onglet déjà actif (l'écran remonte alors en haut).
  final ValueChanged<int> onTap;
  final bool collapsed;

  /// Les quatre onglets de l'app.
  static const mainItems = [
    CgTabItem(icon: CgIcons.today, label: 'Aujourd’hui'),
    CgTabItem(icon: CgIcons.library, label: 'Bibliothèque'),
    CgTabItem(icon: CgIcons.progress, label: 'Progression'),
    CgTabItem(icon: CgIcons.profile, label: 'Profil'),
  ];

  /// Hauteur à réserver en bas d'une liste pour que rien ne passe sous la barre.
  static double reservedHeight(BuildContext context) =>
      CgSpace.tabBarHeight + CgSpace.tabBarBottom + MediaQuery.paddingOf(context).bottom;

  /// Matière de la capsule (maquette `.tab`).
  /// Opacité du fond : libellés inactifs (`ink3`) ≥ 4,5:1 même au-dessus du
  /// contenu le plus sombre qui défile dessous (revue 8.15).
  static const fillAlpha = 0.9;
  static const _blurSigma = 24.0;
  static const _shadowAlpha = 0.16;
  static const _shadowBlur = 30.0;
  static const _shadowOffset = Offset(0, 8);
  static const _innerPadding = 6.0;

  static const _iconSize = 22.0;
  static const _labelGap = 3.0;
  static const _pillHeight = 52.0;

  /// Comme UITabBar, les libellés ne suivent pas Dynamic Type (10,5 pt figés) :
  /// « Bibliothèque » ne tiendrait plus dans sa cellule sur un écran de 375.
  static const _labelMaxScale = 1.0;

  /// Réduite : cellules d'icône seules (cible ≥ 44 conservée).
  static const _collapsedHeight = 48.0;
  static const _collapsedCellWidth = 52.0;
  static const _collapsedPillHeight = 40.0;

  void _handleTap(int index) {
    if (index != currentIndex) CgHaptics.selection();
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        CgSpace.tabBarInset,
        0,
        CgSpace.tabBarInset,
        CgSpace.tabBarBottom + safeBottom,
      ),
      child: SizedBox(
        height: CgSpace.tabBarHeight,
        child: LayoutBuilder(builder: (context, constraints) {
          final fullWidth = constraints.maxWidth;
          final collapsedWidth = items.length * _collapsedCellWidth + 2 * _innerPadding;
          return TweenAnimationBuilder<double>(
            tween: Tween(end: collapsed ? 1 : 0),
            duration: CgMotion.resolve(context, CgMotion.base),
            curve: CgMotion.out,
            builder: (context, t, _) => Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                width: lerpDouble(fullWidth, collapsedWidth, t),
                height: lerpDouble(CgSpace.tabBarHeight, _collapsedHeight, t),
                child: _capsule(context, t),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// [t] : 0 déployée → 1 réduite.
  Widget _capsule(BuildContext context, double t) {
    final c = CgTheme.of(context).colors;
    final pillHeight = lerpDouble(_pillHeight, _collapsedPillHeight, t)!;
    final n = items.length;
    return DecoratedBox(
      key: const ValueKey('cg-tab-capsule'),
      decoration: BoxDecoration(
        borderRadius: CgRadius.pill,
        boxShadow: [
          BoxShadow(color: c.ink.withValues(alpha: _shadowAlpha), blurRadius: _shadowBlur, offset: _shadowOffset),
        ],
      ),
      child: ClipRRect(
        borderRadius: CgRadius.pill,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
          child: DecoratedBox(
            key: const ValueKey('cg-tab-fill'),
            decoration: BoxDecoration(color: c.surface.withValues(alpha: fillAlpha)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _innerPadding),
              child: Stack(children: [
                // Pastille active : alignement relatif, elle suit la capsule quand
                // celle-ci se réduit et glisse d'un onglet à l'autre.
                AnimatedAlign(
                  alignment: Alignment(n == 1 ? 0 : -1 + 2 * currentIndex / (n - 1), 0),
                  duration: CgMotion.resolve(context, CgMotion.fast),
                  curve: CgMotion.out,
                  child: FractionallySizedBox(
                    widthFactor: 1 / n,
                    child: SizedBox(
                      height: pillHeight,
                      child: DecoratedBox(
                        key: const ValueKey('cg-tab-pill'),
                        decoration: BoxDecoration(color: c.accentSoft, borderRadius: CgRadius.pill),
                      ),
                    ),
                  ),
                ),
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (var i = 0; i < n; i++) Expanded(child: _cell(context, i, t)),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(BuildContext context, int i, double t) {
    final c = CgTheme.of(context).colors;
    final active = i == currentIndex;
    final color = active ? c.accent : c.ink3;
    final item = items[i];
    return Semantics(
      container: true,
      button: true,
      selected: active,
      label: item.label,
      onTap: () => _handleTap(i),
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('cg-tab-$i'),
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: () => _handleTap(i),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CgIcon(item.icon, size: _iconSize, color: color),
          if (t < 1)
            ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 1 - t,
                child: Opacity(
                  opacity: 1 - t,
                  child: Padding(
                    padding: const EdgeInsets.only(top: _labelGap),
                    child: CgTextScaleCap(
                      maxScale: _labelMaxScale,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(item.label, style: CgType.tab.copyWith(color: color), maxLines: 1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Signale au sous-arbre qu'une [CgTabBar] flotte en bas de l'écran (posé par le
/// shell). Les éléments flottants (toast) se placent alors au-dessus d'elle ;
/// dans le drill ou l'import, absents du shell, ils descendent au ras du bas.
class CgTabBarScope extends InheritedWidget {
  const CgTabBarScope({super.key, required super.child});

  static bool isPresent(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CgTabBarScope>() != null;

  @override
  bool updateShouldNotify(CgTabBarScope oldWidget) => false;
}

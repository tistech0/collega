import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';

import 'package:collega_app/core/ui/components/cg_tab_bar.dart';
import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

enum _CgHeaderKind { large, inline }

/// Tête d'écran (spec v2 § CgHeader).
///
/// - [CgHeader.large] : tête d'onglet, large title 34/700 (plafonné à 1,3× de
///   Dynamic Type) + sous-titre `ink2` + action 44 × 44 à droite.
/// - [CgHeader.inline] : barre 44 pt des écrans poussés, titre 17/600 centré,
///   « ‹ Parent » en `accent`.
///
/// Dans un écran défilant, utiliser [CgPage], qui passe de l'un à l'autre au scroll.
class CgHeader extends StatelessWidget {
  const CgHeader.large({Key? key, required String title, String? subtitle, Widget? trailing})
      : this._(key: key, kind: _CgHeaderKind.large, title: title, subtitle: subtitle, trailing: trailing);

  const CgHeader.inline({Key? key, required String title, String? backLabel, VoidCallback? onBack, Widget? trailing})
      : this._(
          key: key,
          kind: _CgHeaderKind.inline,
          title: title,
          backLabel: backLabel,
          onBack: onBack,
          trailing: trailing,
        );

  const CgHeader._({
    super.key,
    required _CgHeaderKind kind,
    required this.title,
    this.subtitle,
    this.backLabel,
    this.onBack,
    this.trailing,
    bool titleVisible = true,
    GlobalKey? titleKey,
  })  : _kind = kind,
        _titleVisible = titleVisible,
        _titleKey = titleKey;

  final _CgHeaderKind _kind;
  final String title;
  final String? subtitle;

  /// Libellé de l'écran parent (« Bibliothèque ») ; `null` : pas de retour.
  final String? backLabel;

  /// Par défaut : `Navigator.maybePop`.
  final VoidCallback? onBack;

  /// Action à droite, posée dans une case 44 × 44.
  final Widget? trailing;

  /// [CgPage] : titre et action inline masqués tant que le large title est visible.
  final bool _titleVisible;

  /// [CgPage] : mesure du large title pour savoir quand il quitte l'écran.
  final GlobalKey? _titleKey;

  /// Barre inline (maquette : 44 pt, retour 15 pt).
  static const _barHeight = CgSpace.tapTarget;
  static const _backIconSize = 22.0;

  /// Retour : pas plus de 40 % de la barre, le titre reste centré et lisible.
  static const _backMaxFraction = 0.4;

  /// Maquette `.lt` : 2 pt entre le large title et son sous-titre.
  static const _subtitleGap = 2.0;

  @override
  Widget build(BuildContext context) =>
      _kind == _CgHeaderKind.large ? _buildLarge(context) : _buildInline(context);

  Widget _buildLarge(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          CgTextScaleCap(
            child: Semantics(
              header: true,
              child: Text(title, key: _titleKey, style: CgType.titleL.copyWith(color: c.ink)),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: _subtitleGap),
            Text(subtitle!, style: CgType.bodyS.copyWith(color: c.ink2)),
          ],
        ]),
      ),
      if (trailing != null) ...[
        const SizedBox(width: CgSpace.s2),
        // Centrée sur la première ligne du titre (et non sur tout le bloc).
        Transform.translate(
          offset: Offset(0, (_largeTitleLineHeight(context) - CgSpace.tapTarget) / 2),
          child: _TrailingSlot(child: trailing!),
        ),
      ],
    ]);
  }

  /// Hauteur d'une ligne de large title, à l'échelle plafonnée.
  static double _largeTitleLineHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: CgType.displayMaxScale);
    return scaler.scale(CgType.titleL.fontSize!) * CgType.titleL.height!;
  }

  Widget _buildInline(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final duration = CgMotion.resolve(context, CgMotion.fast);
    // La barre garde 44 pt : son texte est plafonné comme le large title
    // (UINavigationBar ne grandit pas non plus avec Dynamic Type).
    return CgTextScaleCap(
      child: SizedBox(
        height: _barHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CgSpace.s2),
          child: LayoutBuilder(builder: (context, constraints) {
            return NavigationToolbar(
              leading: backLabel == null
                  ? null
                  : ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: constraints.maxWidth * _backMaxFraction),
                      child: _BackButton(
                        label: backLabel!,
                        iconSize: _backIconSize,
                        onTap: onBack ?? () => Navigator.maybePop(context),
                      ),
                    ),
              middle: _fade(
                key: const ValueKey('cg-page-inline-title'),
                duration: duration,
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: CgType.head.copyWith(color: c.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              trailing: trailing == null
                  ? null
                  : _fade(duration: duration, child: _TrailingSlot(child: trailing!)),
              middleSpacing: CgSpace.s2,
            );
          }),
        ),
      ),
    );
  }

  /// Titre/action de la barre : fondu, et hors VoiceOver / hors tap quand masqués.
  Widget _fade({Key? key, required Duration duration, required Widget child}) {
    return AnimatedOpacity(
      key: key,
      opacity: _titleVisible ? 1 : 0,
      duration: duration,
      curve: CgMotion.out,
      child: IgnorePointer(
        ignoring: !_titleVisible,
        child: ExcludeSemantics(excluding: !_titleVisible, child: child),
      ),
    );
  }
}

class _TrailingSlot extends StatelessWidget {
  const _TrailingSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: const ValueKey('cg-header-trailing'),
      dimension: CgSpace.tapTarget,
      child: Center(child: child),
    );
  }
}

/// « ‹ Parent » : chevron + libellé `accent`, cible ≥ 44 pt.
class _BackButton extends StatefulWidget {
  const _BackButton({required this.label, required this.iconSize, required this.onTap});

  final String label;
  final double iconSize;
  final VoidCallback onTap;

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  /// Pressé : le libellé s'estompe, comme un bouton de barre iOS.
  static const _pressedOpacity = 0.4;

  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Semantics(
      button: true,
      label: 'Retour, ${widget.label}',
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('cg-header-back'),
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: CgSpace.tapTarget, minHeight: CgSpace.tapTarget),
          child: AnimatedOpacity(
            opacity: _pressed ? _pressedOpacity : 1,
            duration: CgMotion.resolve(context, CgMotion.fast),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CgIcon(CgIcons.chevronLeft, size: widget.iconSize, color: c.accent),
              Flexible(
                child: Text(
                  widget.label,
                  style: CgType.bodyS.copyWith(color: c.accent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Page défilante type iOS (spec v2 § Layout, § Navigation) : large title qui se
/// réduit en barre inline (titre centré, fond `ground` flouté) quand il quitte
/// l'écran ; « ‹ Parent » au-dessus ; action primaire ancrée en bas ; aucun
/// contenu masqué par l'action, la tab bar ou les safe areas.
class CgPage extends StatefulWidget {
  const CgPage({
    super.key,
    required this.title,
    this.subtitle,
    this.backLabel,
    this.onBack,
    this.trailing,
    required this.children,
    this.bottomAction,
    this.reserveTabBar = false,
    this.onRefresh,
    this.controller,
  });

  final String title;
  final String? subtitle;
  final String? backLabel;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Contenu, posé dans la gouttière de 20 pt.
  final List<Widget> children;

  /// Action primaire ancrée en bas (un `CgButton`), au-dessus de la safe area
  /// et, si [reserveTabBar], de la tab bar.
  final Widget? bottomAction;

  /// Écran d'onglet : réserve la place de la [CgTabBar] flottante posée par le parent.
  final bool reserveTabBar;

  /// Tirer pour rafraîchir (`CupertinoSliverRefreshControl`).
  final Future<void> Function()? onRefresh;

  /// Pour remonter en haut au re-tap de l'onglet actif.
  final ScrollController? controller;

  @override
  State<CgPage> createState() => _CgPageState();
}

class _CgPageState extends State<CgPage> {
  /// Espace entre la barre (44 pt) et le large title : 44 + 4 = 48 (`beforeLargeTitle`).
  static const _largeTitleGap = CgSpace.beforeLargeTitle - CgHeader._barHeight;

  /// Barre réduite : `ground` translucide sur flou (matière iOS).
  static const _barFillAlpha = 0.86;
  static const _barBlurSigma = 20.0;
  static const _hairline = 0.5;

  final _titleKey = GlobalKey();
  bool _collapsed = false;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    _update(notification.metrics.pixels);
    return false;
  }

  /// Le large title a quitté l'écran quand le défilement dépasse sa hauteur
  /// (il commence `_largeTitleGap` sous la barre).
  void _update(double pixels) {
    final box = _titleKey.currentContext?.findRenderObject() as RenderBox?;
    final titleHeight = box?.hasSize == true ? box!.size.height : 0.0;
    final collapsed = pixels >= _largeTitleGap + titleHeight;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
  }

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final padding = MediaQuery.paddingOf(context);
    final barHeight = padding.top + CgHeader._barHeight;
    // Clavier ouvert : l'action ancrée et la fin de liste remontent au-dessus de lui
    // (la page ne compte pas sur un Scaffold qui se redimensionne).
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final bottomReserve = keyboard > 0
        ? keyboard
        : (widget.reserveTabBar ? CgTabBar.reservedHeight(context) : padding.bottom);
    final hasAction = widget.bottomAction != null;
    // Sans action ancrée, la fin de liste doit remonter au-dessus de la tab bar /
    // de l'indicateur d'accueil ; avec action, la bande du bas s'en charge.
    final listBottom = (hasAction ? 0 : bottomReserve) + CgSpace.s6;

    final scroll = LayoutBuilder(builder: (context, constraints) {
      // Pro Max : la colonne reste à 430 pt, centrée (rien ne s'étire).
      final side = CgSpace.gutter + math.max(0.0, (constraints.maxWidth - CgSpace.maxContentWidth) / 2);
      return NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CustomScrollView(
          controller: widget.controller,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: barHeight)),
            if (widget.onRefresh != null) CupertinoSliverRefreshControl(onRefresh: widget.onRefresh),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, _largeTitleGap, side, listBottom),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  CgHeader._(
                    kind: _CgHeaderKind.large,
                    title: widget.title,
                    subtitle: widget.subtitle,
                    // Une seule instance de `trailing` montée à la fois (GlobalKey, état) :
                    // dans le large title tant qu'il est visible, puis dans la barre.
                    // (emplacement vide gardé : le titre ne se réorganise pas au défilement).
                    trailing: _collapsed && widget.trailing != null ? const SizedBox.shrink() : widget.trailing,
                    titleKey: _titleKey,
                  ),
                  ...widget.children,
                ]),
              ),
            ),
          ],
        ),
      );
    });

    final bar = SizedBox(
      key: const ValueKey('cg-page-bar'),
      height: barHeight,
      child: Stack(fit: StackFit.expand, children: [
        AnimatedOpacity(
          opacity: _collapsed ? 1 : 0,
          duration: CgMotion.resolve(context, CgMotion.fast),
          curve: CgMotion.out,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: _barBlurSigma, sigmaY: _barBlurSigma),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.ground.withValues(alpha: _barFillAlpha),
                  border: Border(bottom: BorderSide(color: c.line, width: _hairline)),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: padding.top),
          child: CgHeader._(
            kind: _CgHeaderKind.inline,
            title: widget.title,
            backLabel: widget.backLabel,
            onBack: widget.onBack,
            trailing: _collapsed ? widget.trailing : null,
            titleVisible: _collapsed,
          ),
        ),
      ]),
    );

    return Column(children: [
      Expanded(
        child: Stack(children: [
          Positioned.fill(child: scroll),
          Positioned(top: 0, left: 0, right: 0, child: bar),
        ]),
      ),
      if (hasAction)
        ColoredBox(
          color: c.ground,
          child: Padding(
            padding: EdgeInsets.fromLTRB(CgSpace.gutter, CgSpace.s3, CgSpace.gutter, bottomReserve + CgSpace.s3),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: CgSpace.maxContentWidth - 2 * CgSpace.gutter),
                child: widget.bottomAction,
              ),
            ),
          ),
        ),
    ]);
  }
}

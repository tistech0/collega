import 'package:flutter/cupertino.dart';

import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

enum CgButtonVariant { primary, secondary, quiet, destructive, inverse }

enum CgButtonSize { regular, compact }

/// Toute action (spec v2 § CgButton). Un seul `primary` par écran, ancré en bas.
/// Le libellé est un verbe ; `destructive` ne s'utilise que dans une sheet.
class CgButton extends StatefulWidget {
  const CgButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = CgButtonVariant.primary,
    this.size = CgButtonSize.regular,
    this.loading = false,
    this.expand = true,
    this.icon,
  });

  final String label;

  /// `null` : bouton désactivé (visible, non tapable).
  final VoidCallback? onPressed;
  final CgButtonVariant variant;
  final CgButtonSize size;
  final bool loading;

  /// Pleine largeur (défaut) ou largeur du contenu.
  final bool expand;

  /// Icône optionnelle avant le libellé (`CgIcons.*`).
  final String? icon;

  @override
  State<CgButton> createState() => _CgButtonState();
}

class _CgButtonState extends State<CgButton> {
  static const _pressedScale = 0.97;
  static const _iconGap = CgSpace.s2;
  static const _iconSize = 20.0;

  /// Dynamic Type : le bouton grandit au lieu de tronquer (hauteur minimale, pas fixe).
  static const _maxLines = 2;
  static const _verticalPadding = CgSpace.s2;
  static const _horizontalPadding = CgSpace.s5;

  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final disabled = widget.onPressed == null;
    final (Color? fill, Color? border, Color text) = switch (widget.variant) {
      _ when disabled && _hasFill => (c.soft, null, c.ink3),
      _ when disabled => (null, null, c.ink3),
      CgButtonVariant.primary => (c.accent, null, c.accentInk),
      CgButtonVariant.secondary => (c.surface, c.line, c.ink),
      CgButtonVariant.quiet => (null, null, c.accent),
      CgButtonVariant.destructive => (null, null, c.danger),
      CgButtonVariant.inverse => (c.accentInk, null, c.accent),
    };
    final height = widget.size == CgButtonSize.regular
        ? CgSpace.buttonHeight
        : CgSpace.buttonHeightCompact;
    final style = CgType.head.copyWith(color: text);

    final Widget label = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                CgIcon(widget.icon!, size: _iconSize, color: text),
                const SizedBox(width: _iconGap),
              ],
              Flexible(
                child: Text(widget.label, style: style, maxLines: _maxLines, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
              ),
            ],
          );
    // En chargement, le libellé reste en place (invisible) sous l'indicateur :
    // la largeur ne bouge pas.
    final Widget content = widget.loading
        ? Stack(alignment: Alignment.center, children: [
            Visibility.maintain(visible: false, child: label),
            // Mouvement réduit : indicateur figé (aucune animation en boucle).
            CgMotion.reduced(context)
                ? CupertinoActivityIndicator.partiallyRevealed(color: text)
                : CupertinoActivityIndicator(color: text),
          ])
        : label;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.loading ? '${widget.label}, chargement' : widget.label,
      excludeSemantics: true,
      onTap: _enabled ? widget.onPressed : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _setPressed(true) : null,
        onTapUp: _enabled ? (_) => _setPressed(false) : null,
        onTapCancel: _enabled ? () => _setPressed(false) : null,
        onTap: _enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _pressed ? _pressedScale : 1,
          duration: CgMotion.resolve(context, CgMotion.fast),
          curve: CgMotion.out,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: height,
              minWidth: widget.expand ? double.infinity : 0,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: fill,
                borderRadius: CgRadius.buttonAll,
                border: border == null ? null : Border.all(color: border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding, vertical: _verticalPadding),
                child: Center(widthFactor: 1, child: content),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasFill => switch (widget.variant) {
        CgButtonVariant.primary || CgButtonVariant.secondary || CgButtonVariant.inverse => true,
        _ => false,
      };
}

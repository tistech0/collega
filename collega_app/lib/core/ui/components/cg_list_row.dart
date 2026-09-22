import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/foundation/cg_icon.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_colors.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Élément à droite d'une [CgListRow].
enum CgRowTrailing { none, chevron, value, action, check, custom }

/// `plain` : filets sur `ground` (listes d'onglets) ; `inset` : groupe `surface`
/// arrondi (réservé au Profil et au Planning).
enum CgListVariant { plain, inset }

/// Au-delà de cette échelle de texte, la ligne passe en deux niveaux
/// (spec v2 § Dynamic Type). Seuil inclusif : la matrice de goldens à 1,6× le couvre.
const double _twoLevelScale = 1.6;

/// Contexte posé par [CgListGroup] : retrait horizontal du contenu et débord du
/// fond pressé (plain : jusqu'au bord de l'écran, par-delà la gouttière).
class _CgListScope extends InheritedWidget {
  const _CgListScope({required this.contentInset, required this.pressedBleed, required super.child});

  final double contentInset;
  final double pressedBleed;

  static _CgListScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CgListScope>();

  @override
  bool updateShouldNotify(_CgListScope oldWidget) =>
      contentInset != oldWidget.contentInset || pressedBleed != oldWidget.pressedBleed;
}

/// Ligne de contenu : collège, item, réglage, résultat (spec v2 § CgListRow).
///
/// Une ligne = un seul nœud VoiceOver (titre, sous-titre, valeur). Désactivée
/// (`enabled: false`) = collège du catalogue non importé : titre `ink2` 500,
/// pas de chevron, la ligne ne se tape plus mais l'action « Importer » oui.
/// Les filets sont posés par [CgListGroup], jamais par la ligne.
class CgListRow extends StatefulWidget {
  const CgListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing = CgRowTrailing.none,
    this.trailingWidget,
    this.value,
    this.actionLabel,
    this.onAction,
    this.progress,
    this.onTap,
    this.enabled = true,
    this.selected = false,
    this.titleMaxLines = 2,
  })  : assert(trailing != CgRowTrailing.value || value != null, 'trailing value : `value` requis'),
        assert(trailing != CgRowTrailing.action || actionLabel != null, 'trailing action : `actionLabel` requis'),
        assert(trailing != CgRowTrailing.custom || trailingWidget != null, 'trailing custom : `trailingWidget` requis');

  final String title;
  final String? subtitle;

  /// Icône 36 pt ([CgRowIcon]), badge de rang, anneau 56 pt.
  final Widget? leading;
  final CgRowTrailing trailing;

  /// Pour [CgRowTrailing.custom] (ex. `CupertinoSwitch`).
  final Widget? trailingWidget;

  /// Pour [CgRowTrailing.value] (« 42 % », « 30 min »).
  final String? value;

  /// Pour [CgRowTrailing.action] : action `quiet` compacte (« Importer »).
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Barre de progression sous le sous-titre (CgRankBar 6 pt).
  final Widget? progress;
  final VoidCallback? onTap;
  final bool enabled;

  /// Avec [CgRowTrailing.check] : coche `accent`.
  final bool selected;
  final int titleMaxLines;

  @override
  State<CgListRow> createState() => _CgListRowState();
}

class _CgListRowState extends State<CgListRow> {
  /// Géométrie de la maquette (`.row` : padding 14, gap 14, `.m` margin-top 1).
  static const _verticalPadding = 14.0;
  static const _gap = 14.0;
  static const _subtitleGap = 1.0;
  static const _chevronSize = 18.0;
  static const _checkSize = 22.0;

  /// Action `quiet` compacte : 14/600 (plus petite que le titre de ligne).
  static const _actionFontSize = 14.0;

  bool _pressed = false;

  VoidCallback? get _rowTap => widget.enabled ? widget.onTap : null;

  bool get _hasAction => widget.trailing == CgRowTrailing.action;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final scope = _CgListScope.maybeOf(context);
    final contentInset = scope?.contentInset ?? 0;
    final bleed = scope?.pressedBleed ?? 0;
    final scale = MediaQuery.textScalerOf(context).scale(CgType.head.fontSize!) / CgType.head.fontSize!;
    final twoLevel = scale >= _twoLevelScale;

    final titleStyle = widget.enabled
        ? CgType.head.copyWith(color: c.ink)
        : CgType.head.copyWith(color: c.ink2, fontWeight: FontWeight.w500);

    // Sous le titre en deux niveaux : la valeur et l'action (pas le chevron,
    // la coche ni le switch, qui restent à droite).
    final Widget? below = twoLevel ? _valueOrAction(c, alignStart: true) : null;
    final Widget? right = twoLevel ? _sideTrailing(c) : (_valueOrAction(c, alignStart: false) ?? _sideTrailing(c));

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: titleStyle, maxLines: widget.titleMaxLines, overflow: TextOverflow.ellipsis),
        if (widget.subtitle != null) ...[
          const SizedBox(height: _subtitleGap),
          Text(widget.subtitle!, style: CgType.meta.copyWith(color: c.ink2)),
        ],
        if (below != null) below,
        if (widget.progress != null) ...[
          const SizedBox(height: CgSpace.related),
          widget.progress!,
        ],
      ],
    );

    final content = Row(children: [
      if (widget.leading != null) ...[widget.leading!, const SizedBox(width: _gap)],
      Expanded(child: text),
      if (right != null) ...[const SizedBox(width: _gap), right],
    ]);

    // VoiceOver : la ligne se tape ; désactivée, c'est l'action qui répond.
    final VoidCallback? semanticTap = _rowTap ?? (_hasAction ? widget.onAction : null);
    final customActions = _rowTap != null && _hasAction && widget.onAction != null
        ? {CustomSemanticsAction(label: widget.actionLabel!): widget.onAction!}
        : null;
    final showsCheck = widget.trailing == CgRowTrailing.check || widget.selected;

    return MergeSemantics(
      child: Semantics(
        button: semanticTap != null,
        enabled: semanticTap != null ? true : (widget.enabled ? null : false),
        selected: showsCheck ? widget.selected : null,
        onTap: semanticTap,
        customSemanticsActions: customActions,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTapDown: _rowTap != null ? (_) => _setPressed(true) : null,
          onTapUp: _rowTap != null ? (_) => _setPressed(false) : null,
          onTapCancel: _rowTap != null ? () => _setPressed(false) : null,
          onTap: _rowTap,
          child: Stack(clipBehavior: Clip.none, children: [
            // Fond pressé : déborde de la gouttière en `plain` (bord à bord, comme iOS).
            Positioned(
              top: 0,
              bottom: 0,
              left: -bleed,
              right: -bleed,
              child: AnimatedContainer(
                duration: CgMotion.resolve(context, CgMotion.fast),
                curve: CgMotion.out,
                decoration: BoxDecoration(color: _pressed ? c.soft : c.soft.withValues(alpha: 0)),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: CgSpace.tapTarget),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: contentInset, vertical: _verticalPadding),
                child: content,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// Valeur ou action (les seuls éléments qui passent sous le titre en deux niveaux).
  Widget? _valueOrAction(CgColors c, {required bool alignStart}) {
    switch (widget.trailing) {
      case CgRowTrailing.value:
        return Text(
          widget.value!,
          style: CgType.bodyS.copyWith(color: c.ink3, fontFeatures: const [FontFeature.tabularFigures()]),
        );
      case CgRowTrailing.action:
        final label = Text(
          widget.actionLabel!,
          style: CgType.meta.copyWith(color: c.accent, fontSize: _actionFontSize, fontWeight: FontWeight.w600),
        );
        return GestureDetector(
          key: const ValueKey('cg-row-action'),
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: widget.onAction,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: CgSpace.tapTarget, minHeight: CgSpace.tapTarget),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              alignment: alignStart ? Alignment.centerLeft : Alignment.center,
              // Ligne tapable : l'action passe par une action personnalisée VoiceOver,
              // son libellé ne s'ajoute pas à celui de la ligne.
              child: _rowTap != null ? ExcludeSemantics(child: label) : label,
            ),
          ),
        );
      default:
        return null;
    }
  }

  /// Éléments qui restent toujours à droite.
  Widget? _sideTrailing(CgColors c) {
    switch (widget.trailing) {
      case CgRowTrailing.chevron:
        return widget.enabled ? CgIcon(CgIcons.chevronRight, size: _chevronSize, color: c.ink3) : null;
      case CgRowTrailing.check:
        // Place réservée même non cochée : le titre ne bouge pas à la sélection.
        return SizedBox.square(
          dimension: _checkSize,
          child: widget.selected ? CgIcon(CgIcons.check, size: _checkSize, color: c.accent) : null,
        );
      case CgRowTrailing.custom:
        return widget.trailingWidget;
      default:
        return widget.selected ? CgIcon(CgIcons.check, size: _checkSize, color: c.accent) : null;
    }
  }
}

/// Icône de tête de ligne : 36 pt, rayon `s`, fond `accentSoft` (grisée : `soft`
/// + icône `ink3`, collèges du catalogue). Maquette `.ico` / `.ico.g`.
class CgRowIcon extends StatelessWidget {
  const CgRowIcon(this.icon, {super.key, this.muted = false});

  final String icon;
  final bool muted;

  static const _size = 36.0;
  static const _iconSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return SizedBox.square(
      dimension: _size,
      child: DecoratedBox(
        decoration: BoxDecoration(color: muted ? c.soft : c.accentSoft, borderRadius: CgRadius.sAll),
        child: Center(child: CgIcon(icon, size: _iconSize, color: muted ? c.ink3 : c.accent)),
      ),
    );
  }
}

/// Groupe de lignes : filet `line` 1 pt entre les lignes, jamais après la dernière.
class CgListGroup extends StatelessWidget {
  const CgListGroup({super.key, required this.children, this.variant = CgListVariant.plain, this.header});

  final List<Widget> children;
  final CgListVariant variant;

  /// Intertitre au-dessus du groupe ([CgSectionTitle]).
  final String? header;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final inset = variant == CgListVariant.inset;
    final rows = <Widget>[
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) _Separator(color: c.line, indent: inset ? CgSpace.rowInset : 0),
        children[i],
      ],
    ];
    final column = _CgListScope(
      contentInset: inset ? CgSpace.rowInset : 0,
      pressedBleed: inset ? 0 : CgSpace.gutter,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: rows),
    );
    final body = inset
        ? DecoratedBox(
            key: const ValueKey('cg-list-inset'),
            decoration: BoxDecoration(color: c.surface, borderRadius: CgRadius.lAll),
            child: ClipRRect(borderRadius: CgRadius.lAll, child: column),
          )
        : column;
    if (header == null) return body;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: inset ? CgSpace.rowInset : 0),
        child: CgSectionTitle(header!),
      ),
      body,
    ]);
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.color, required this.indent});

  final Color color;
  final double indent;

  static const _thickness = 1.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('cg-list-separator'),
      height: _thickness,
      child: Padding(padding: EdgeInsets.only(left: indent), child: ColoredBox(color: color)),
    );
  }
}

/// Intertitre de section (maquette `.sec`) : 13/600 `ink3`, lu comme en-tête.
class CgSectionTitle extends StatelessWidget {
  const CgSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return Padding(
      padding: const EdgeInsets.only(top: CgSpace.section, bottom: CgSpace.related),
      child: Semantics(
        header: true,
        child: Text(text, style: CgType.label.copyWith(fontWeight: FontWeight.w600, color: c.ink3)),
      ),
    );
  }
}

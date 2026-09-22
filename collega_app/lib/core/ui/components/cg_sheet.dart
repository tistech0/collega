import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'package:collega_app/core/ui/components/cg_button.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Hauteur d'une sheet : moitié d'écran ou plein écran (sous la safe area).
enum CgSheetDetent { half, full }

/// Action d'une [showCgActionSheet]. `destructive` : texte rouge natif.
@immutable
class CgSheetAction {
  const CgSheetAction({required this.label, required this.onPressed, this.destructive = false});

  final String label;
  final VoidCallback onPressed;
  final bool destructive;
}

/// Sheet modale Collega UI (spec v2 § CgSheet) : voile `scrim`, feuille `ground`
/// arrondie en haut, poignée, titre, contenu, pied (primary + secondary).
/// Glisser vers le bas ou toucher le voile ferme (résultat `null`) ; le clavier
/// pousse la feuille.
///
/// Les boutons de [primary] / [secondary] ferment eux-mêmes la feuille :
/// `Navigator.of(context, rootNavigator: true).pop(valeur)` (la sheet est
/// poussée sur le Navigator racine, au-dessus de la tab bar).
Future<T?> showCgSheet<T>(
  BuildContext context, {
  String? title,
  required WidgetBuilder builder,
  CgSheetDetent detent = CgSheetDetent.half,
  Widget? primary,
  Widget? secondary,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(_CgSheetRoute<T>(
    reduced: CgMotion.reduced(context),
    scrim: CgTheme.of(context).colors.scrim,
    detent: detent,
    panelBuilder: (_, dismiss) => CgSheetPanel(
      title: title,
      primary: primary,
      secondary: secondary,
      onDismiss: dismiss,
      child: Builder(builder: builder),
    ),
  ));
}

/// Question + deux actions (spec v2 § Feedback — Décision) : la conséquence est
/// écrite dans [message]. Renvoie `true` si confirmé ; annuler, toucher le voile
/// ou glisser pour fermer renvoie `false`.
Future<bool> showCgDialogSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final result = await Navigator.of(context, rootNavigator: true).push<bool>(_CgSheetRoute<bool>(
    reduced: CgMotion.reduced(context),
    scrim: CgTheme.of(context).colors.scrim,
    detent: null,
    panelBuilder: (routeContext, dismiss) => CgSheetPanel.dialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      onConfirm: () => Navigator.of(routeContext).pop(true),
      onCancel: () => Navigator.of(routeContext).pop(false),
      onDismiss: dismiss,
    ),
  ));
  return result ?? false;
}

/// Liste d'actions native (`CupertinoActionSheet`) : signaler, supprimer…
/// Le seul endroit où une action destructive apparaît (spec v2 § Hiérarchie des
/// actions). La feuille se ferme avant l'appel du callback, qui peut donc
/// enchaîner sur une confirmation ([showCgDialogSheet]).
Future<void> showCgActionSheet(
  BuildContext context, {
  String? title,
  String? message,
  required List<CgSheetAction> actions,
  String cancelLabel = 'Annuler',
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    barrierColor: CgTheme.of(context).colors.scrim,
    builder: (sheetContext) => CupertinoActionSheet(
      title: title == null ? null : Text(title),
      message: message == null ? null : Text(message),
      actions: [
        for (final action in actions)
          CupertinoActionSheetAction(
            isDestructiveAction: action.destructive,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              action.onPressed();
            },
            child: Text(action.label),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(sheetContext).pop(),
        child: Text(cancelLabel),
      ),
    ),
  );
}

/// Le contenu visible d'une sheet, sans la route : poignée, titre, contenu, pied.
///
/// Utilisé par [showCgSheet] / [showCgDialogSheet], et rendu tel quel dans les
/// planches (goldens, Widgetbook).
class CgSheetPanel extends StatelessWidget {
  const CgSheetPanel({
    super.key,
    this.title,
    required this.child,
    this.primary,
    this.secondary,
    this.expand = true,
    this.onDismiss,
  });

  /// Question + deux actions : confirm `primary` (ou `destructive`), cancel `quiet`.
  factory CgSheetPanel.dialog({
    Key? key,
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
    bool destructive = false,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
    VoidCallback? onDismiss,
  }) {
    return CgSheetPanel(
      key: key,
      title: title,
      expand: false,
      onDismiss: onDismiss,
      primary: CgButton(
        label: confirmLabel,
        onPressed: onConfirm,
        variant: destructive ? CgButtonVariant.destructive : CgButtonVariant.primary,
      ),
      secondary: CgButton(label: cancelLabel, onPressed: onCancel, variant: CgButtonVariant.quiet),
      child: _DialogMessage(message),
    );
  }

  /// Repère de la poignée (tests, glisser pour fermer).
  static const handleKey = Key('cg-sheet-handle');

  final String? title;
  final Widget child;
  final Widget? primary;
  final Widget? secondary;

  /// `true` : la feuille remplit la hauteur donnée (detent), le contenu prend
  /// l'espace restant. `false` : la feuille épouse son contenu (dialog).
  final bool expand;

  /// Fermeture sans résultat. Rend la poignée actionnable par VoiceOver
  /// (« Fermer ») : le glissement n'est pas accessible à tous.
  final VoidCallback? onDismiss;

  static const _handleWidth = 36.0;
  static const _handleHeight = 5.0;
  static const _handleZone = CgSpace.s6;
  static const _topRadius = BorderRadius.vertical(top: Radius.circular(CgRadius.l));

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final hasFooter = primary != null || secondary != null;

    final Widget handle = SizedBox(
      height: _handleZone,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(color: c.ink3, borderRadius: CgRadius.pill),
          child: const SizedBox(width: _handleWidth, height: _handleHeight),
        ),
      ),
    );

    final Widget content = Padding(
      padding: EdgeInsets.fromLTRB(
        CgSpace.gutter,
        title == null ? 0 : CgSpace.s3,
        CgSpace.gutter,
        hasFooter ? 0 : CgSpace.s4 + safeBottom,
      ),
      child: child,
    );

    return DecoratedBox(
      decoration: BoxDecoration(color: c.ground, borderRadius: _topRadius),
      child: Column(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          onDismiss == null
              ? ExcludeSemantics(key: handleKey, child: handle)
              : Semantics(key: handleKey, container: true, button: true, label: 'Fermer', onTap: onDismiss, excludeSemantics: true, child: handle),
          if (title != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CgSpace.gutter),
              child: Semantics(
                container: true,
                header: true,
                child: Text(title!, style: CgType.title.copyWith(color: c.ink)),
              ),
            ),
          if (expand) Expanded(child: content) else Flexible(child: content),
          if (hasFooter) CgSheetFooter(primary: primary, secondary: secondary),
        ],
      ),
    );
  }
}

/// Message d'un dialog : défile s'il ne tient pas (Dynamic Type, petit écran).
class _DialogMessage extends StatelessWidget {
  const _DialogMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return SingleChildScrollView(
      child: Text(message, style: CgType.bodyS.copyWith(color: c.ink2)),
    );
  }
}

/// Route modale maison : voile, position (detent, clavier), montée ou fondu.
class _CgSheetRoute<T> extends PopupRoute<T> {
  _CgSheetRoute({
    required this.reduced,
    required this.scrim,
    required this.detent,
    required this.panelBuilder,
  });

  /// Mouvement réduit, lu au moment de l'ouverture (contexte de l'appelant).
  final bool reduced;
  final Color scrim;

  /// `null` : la feuille épouse son contenu (dialog).
  final CgSheetDetent? detent;
  final Widget Function(BuildContext context, VoidCallback dismiss) panelBuilder;

  static const _halfFraction = 0.5;

  /// Écart entre la safe area haute et une feuille `full` (on voit qu'elle est posée).
  static const _fullTopGap = CgSpace.s3;

  @override
  Color? get barrierColor => scrim;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Fermer';

  // Mouvement réduit : fondu court (même règle que CgDrillCard) au lieu de la montée.
  @override
  Duration get transitionDuration => reduced ? CgMotion.fast : CgMotion.sheetRise;

  @override
  Duration get reverseTransitionDuration => reduced ? CgMotion.fast : CgMotion.base;

  void _dismiss() {
    if (isCurrent) navigator?.pop();
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    final topLimit = mq.padding.top + _fullTopGap;
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      child: LayoutBuilder(builder: (context, constraints) {
        final screen = constraints.maxHeight;
        final available = math.max(0.0, screen - keyboard - topLimit);
        final height = switch (detent) {
          CgSheetDetent.half => math.min(screen * _halfFraction, available),
          CgSheetDetent.full => available,
          null => null,
        };
        // Le clavier est absorbé ici : le contenu ne doit pas le compter deux fois.
        final panel = MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: _CgSheetDraggable(
            onDismiss: _dismiss,
            child: Builder(builder: (context) => panelBuilder(context, _dismiss)),
          ),
        );
        return Padding(
          padding: EdgeInsets.only(bottom: keyboard),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: height == null
                ? ConstrainedBox(constraints: BoxConstraints(maxHeight: available), child: panel)
                : SizedBox(width: double.infinity, height: height, child: panel),
          ),
        );
      }),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (reduced) return FadeTransition(opacity: animation, child: child);
    return SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
        CurvedAnimation(parent: animation, curve: CgMotion.out, reverseCurve: CgMotion.out.flipped),
      ),
      child: child,
    );
  }
}

/// Glisser vers le bas pour fermer. Sous le seuil, la feuille revient.
///
/// Un contenu défilant garde ses propres glissements verticaux (il gagne
/// l'arène de gestes) : on ferme alors par la poignée, le titre ou le voile.
class _CgSheetDraggable extends StatefulWidget {
  const _CgSheetDraggable({required this.onDismiss, required this.child});

  final VoidCallback onDismiss;
  final Widget child;

  @override
  State<_CgSheetDraggable> createState() => _CgSheetDraggableState();
}

class _CgSheetDraggableState extends State<_CgSheetDraggable> with SingleTickerProviderStateMixin {
  /// Fraction de la hauteur de la feuille au-delà de laquelle le relâcher ferme.
  static const _dismissFraction = 0.25;

  /// Vitesse (pt/s) vers le bas qui ferme quelle que soit la distance.
  static const _dismissVelocity = 700.0;

  late final AnimationController _settle;
  double _offset = 0;
  double _settleFrom = 0;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(vsync: this)..addListener(_onSettle);
  }

  void _onSettle() => setState(() => _offset = _settleFrom * (1 - CgMotion.out.transform(_settle.value)));

  void _onUpdate(DragUpdateDetails details) {
    _settle.stop();
    setState(() => _offset = math.max(0, _offset + details.delta.dy));
  }

  void _onEnd(DragEndDetails details) {
    final height = context.size?.height ?? 0;
    final fast = (details.primaryVelocity ?? 0) > _dismissVelocity;
    if (fast || _offset > height * _dismissFraction) {
      // La feuille part d'où elle est : la sortie de la route prolonge le geste.
      widget.onDismiss();
      return;
    }
    _settleFrom = _offset;
    _settle
      ..duration = CgMotion.resolve(context, CgMotion.base)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: _onUpdate,
      onVerticalDragEnd: _onEnd,
      child: Transform.translate(offset: Offset(0, _offset), child: widget.child),
    );
  }
}

/// Pied de sheet : action principale puis secondaire, au-dessus de la safe area.
///
/// `showCgSheet(primary:, secondary:)` le pose avec des boutons figés à l'appel.
/// Quand le bouton dépend de l'état du contenu (sélection de « Personnaliser »,
/// texte de « Signaler »), le contenu pose lui-même un [CgSheetFooter] à jour.
class CgSheetFooter extends StatelessWidget {
  const CgSheetFooter({super.key, this.primary, this.secondary});

  final Widget? primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(CgSpace.gutter, CgSpace.s5, CgSpace.gutter, CgSpace.s4 + safeBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (primary != null) primary!,
          if (primary != null && secondary != null) const SizedBox(height: CgSpace.s2),
          if (secondary != null) secondary!,
        ],
      ),
    );
  }
}

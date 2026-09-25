import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/components/cg_tab_bar.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_radius.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// Hauteur réservée à la tab bar flottante sous le toast : capsule
/// (`CgSpace.tabBarHeight`, 64) + écart au bas de l'écran
/// (`CgSpace.tabBarBottom`, 22). La safe area s'y ajoute. Même réserve que
/// `CgTabBar.reservedHeight`, recopiée ici pour ne pas lier le toast à la tab bar.
const double cgToastTabBarReserve = CgSpace.tabBarHeight + CgSpace.tabBarBottom;

/// Écart entre le toast et ce qu'il surplombe (tab bar ou safe area).
const double _toastGap = CgSpace.s3;

/// Montée du toast à l'apparition (supprimée en mouvement réduit).
const double _toastRise = 8;

/// Toast affiché ; le suivant le remplace.
OverlayEntry? _current;

/// Entrées insérées et pas encore retirées. `OverlayEntry.mounted` reste faux tant
/// que l'entrée n'a pas été construite : deux toasts dans la même frame resteraient
/// affichés tous les deux si l'on s'y fiait.
final _live = <OverlayEntry>{};

/// Confirmation légère d'une action que l'écran ne montre pas déjà (spec v2
/// § CgToast) : « Elle reviendra dans quelques questions », « Fiche signalée ».
/// Jamais pour une erreur bloquante.
///
/// Capsule en bas de l'écran, au-dessus de la safe area et de la tab bar s'il y en
/// a une ([aboveTabBar] ; par défaut détecté via [CgTabBarScope]), pendant
/// [CgMotion.toast] ; un seul à la fois ; annoncée à VoiceOver. Ne capte aucun tap.
/// Après un `await`, l'appelant vérifie `context.mounted` avant d'appeler.
///
/// Une ligne par défaut ; [maxLines] > 1 pour un message qui doit se lire en
/// entier (liste d'items), avec une [duration] plus longue pour le lire.
void showCgToast(
  BuildContext context,
  String message, {
  bool? aboveTabBar,
  int maxLines = 1,
  Duration? duration,
}) {
  final overTabBar = aboveTabBar ?? CgTabBarScope.isPresent(context);
  final overlay = Overlay.of(context, rootOverlay: true);
  // L'overlay racine est au-dessus des MediaQuery/thèmes posés par l'écran :
  // le toast reprend ceux de l'appelant (mouvement réduit, Dynamic Type).
  final theme = CgTheme.of(context);
  final reduced = CgMotion.reduced(context);
  final textScaler = MediaQuery.textScalerOf(context);

  _dismiss(_current);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (overlayContext) => CgTheme(
      data: theme,
      child: MediaQuery(
        data: MediaQuery.of(overlayContext).copyWith(disableAnimations: reduced, textScaler: textScaler),
        child: _CgToastOverlay(
          message: message,
          maxLines: maxLines,
          duration: duration ?? CgMotion.toast,
          aboveTabBar: overTabBar,
          onDone: () => _dismiss(entry),
          onDetached: () => _live.remove(entry),
        ),
      ),
    ),
  );
  _current = entry;
  _live.add(entry);
  overlay.insert(entry);
  SemanticsService.announce(message, Directionality.of(context));
}

void _dismiss(OverlayEntry? entry) {
  if (entry == null) return;
  if (identical(_current, entry)) _current = null;
  // Déjà retirée, ou overlay démonté entre-temps (écran fermé) : plus rien à faire.
  if (!_live.remove(entry)) return;
  entry.remove();
  entry.dispose();
}

class _CgToastOverlay extends StatefulWidget {
  const _CgToastOverlay({
    required this.message,
    required this.maxLines,
    required this.duration,
    required this.aboveTabBar,
    required this.onDone,
    required this.onDetached,
  });

  final String message;
  final int maxLines;
  final Duration duration;
  final bool aboveTabBar;
  final VoidCallback onDone;

  /// Appelé quand le widget quitte l'arbre (retrait normal ou overlay démonté).
  final VoidCallback onDetached;

  @override
  State<_CgToastOverlay> createState() => _CgToastOverlayState();
}

class _CgToastOverlayState extends State<_CgToastOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.dismissed && _hiding) widget.onDone();
    });
  late final CurvedAnimation _curve = CurvedAnimation(parent: _controller, curve: CgMotion.out);

  /// Durée d'affichage : du temps de lecture, pas une animation — elle ne
  /// dépend donc pas du mouvement réduit.
  Timer? _timer;
  bool _hiding = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Mouvement réduit : le fondu reste (il ne déplace rien), raccourci à
    // `fast` ; seule la montée disparaît. D'où `fast` et non `resolve(...)`,
    // qui supprimerait aussi le fondu.
    _controller.duration = CgMotion.reduced(context) ? CgMotion.fast : CgMotion.base;
    _controller.forward();
    _timer = Timer(widget.duration, _hide);
  }

  void _hide() {
    if (!mounted) return;
    _hiding = true;
    _controller.reverse();
  }

  @override
  void dispose() {
    widget.onDetached();
    _timer?.cancel();
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final bottom = safeBottom + (widget.aboveTabBar ? cgToastTabBarReserve : 0) + _toastGap;
    final rise = CgMotion.reduced(context) ? 0.0 : _toastRise;

    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.fromLTRB(CgSpace.gutter, 0, CgSpace.gutter, bottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: _curve,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, rise * (1 - _curve.value)),
              child: child,
            ),
            child: FadeTransition(
              opacity: _curve,
              // VoiceOver l'a déjà entendu via l'annonce : pas de seconde lecture.
              child: ExcludeSemantics(child: CgToastCapsule(message: widget.message, maxLines: widget.maxLines)),
            ),
          ),
        ),
      ),
    );
  }
}

/// La capsule du toast, rendue seule (planche, Widgetbook) ou par [showCgToast].
class CgToastCapsule extends StatelessWidget {
  const CgToastCapsule({super.key, required this.message, this.maxLines = 1});

  final String message;

  /// Au-delà d'une ligne, la capsule devient un bloc arrondi (`r-l`) qui passe à la ligne.
  final int maxLines;

  static const _padding = EdgeInsets.symmetric(horizontal: CgSpace.s5, vertical: CgSpace.s3);

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: c.ink, borderRadius: maxLines > 1 ? CgRadius.lAll : CgRadius.pill),
      child: Padding(
        padding: _padding,
        child: Text(
          message,
          maxLines: maxLines,
          softWrap: maxLines > 1,
          overflow: TextOverflow.ellipsis,
          style: CgType.bodyS.copyWith(color: c.ground),
        ),
      ),
    );
  }
}

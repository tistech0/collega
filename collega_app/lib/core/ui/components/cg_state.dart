import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/components/cg_button.dart';
import 'package:collega_app/core/ui/components/cg_illustrations.dart';
import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

export 'package:collega_app/core/ui/components/cg_illustrations.dart' show CgIllustration;

enum _CgStateKind { empty, error, offline }

/// État d'écran (spec v2 § CgState, § Les quatre états) : illustration, titre,
/// message, action. Le texte suit l'ordre rassurer → expliquer → proposer ;
/// jamais de message technique, jamais d'excuse ; `offline` dit ce qui reste
/// possible.
///
/// Centré dans l'espace donné ; le défilement éventuel est celui du parent.
class CgState extends StatefulWidget {
  /// Ce qui manque, et l'action qui remplit (bouton `primary`).
  const CgState.empty({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.illustration = CgIllustration.sheets,
  }) : _kind = _CgStateKind.empty;

  /// Rien ne peut s'afficher : rassurer, expliquer, proposer (bouton `secondary`).
  const CgState.error({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.illustration = CgIllustration.broken,
  }) : _kind = _CgStateKind.error;

  /// Le réseau manque pour cet écran ; dire ce qui reste disponible (bouton `secondary`).
  const CgState.offline({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.illustration = CgIllustration.offline,
  }) : _kind = _CgStateKind.offline;

  final _CgStateKind _kind;
  final String title;
  final String message;

  /// Verbe de l'action ; sans libellé, pas de bouton.
  final String? actionLabel;
  final VoidCallback? onAction;
  final CgIllustration illustration;

  @override
  State<CgState> createState() => _CgStateState();
}

class _CgStateState extends State<CgState> with SingleTickerProviderStateMixin {
  /// Montée de l'illustration à l'apparition.
  static const _rise = CgSpace.s2;

  /// Colonne de texte : une ligne de message reste lisible (≈ 45 caractères).
  static const _maxTextWidth = 320.0;

  late final AnimationController _appear;
  late final Animation<double> _curve;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _appear = AnimationController(vsync: this, duration: CgMotion.slow);
    _curve = CurvedAnimation(parent: _appear, curve: CgMotion.out);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Une seule fois, à l'apparition ; mouvement réduit : posée d'emblée.
    if (_started) return;
    _started = true;
    if (CgMotion.reduced(context)) {
      _appear.value = 1;
    } else {
      _appear.forward();
    }
  }

  @override
  void dispose() {
    _appear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final actionLabel = widget.actionLabel;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CgSpace.gutter, vertical: CgSpace.section),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxTextWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _curve,
                child: AnimatedBuilder(
                  animation: _curve,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, _rise * (1 - _curve.value)),
                    child: child,
                  ),
                  child: CgIllustrationArt(widget.illustration),
                ),
              ),
              const SizedBox(height: CgSpace.s5),
              Semantics(
                container: true,
                header: true,
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: CgType.title.copyWith(color: c.ink),
                ),
              ),
              const SizedBox(height: CgSpace.s2),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: CgType.bodyS.copyWith(color: c.ink2),
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: CgSpace.s6),
                CgButton(
                  label: actionLabel,
                  onPressed: widget.onAction,
                  size: CgButtonSize.compact,
                  expand: false,
                  variant: widget._kind == _CgStateKind.empty
                      ? CgButtonVariant.primary
                      : CgButtonVariant.secondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

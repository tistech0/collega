import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/collega_ui.dart';

/// Rond coché de l'Accueil (partie D) : « Session faite » et jours faits de la
/// semaine. [animate] n'a d'effet qu'à la création : rebond, coche révélée de
/// gauche à droite et un retour haptique, une seule fois (jamais si les
/// animations sont réduites).
class DoneCheck extends StatefulWidget {
  const DoneCheck({super.key, required this.size, this.animate = false});

  final double size;
  final bool animate;

  static const duration = Duration(milliseconds: 800); // CgMotion.slow × 2
  static const scaleKey = ValueKey('done-check-scale');
  static const _checkRatio = 0.55;

  @override
  State<DoneCheck> createState() => _DoneCheckState();
}

class _DoneCheckState extends State<DoneCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: DoneCheck.duration);
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.15).chain(CurveTween(curve: CgMotion.out)), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: CgMotion.out)), weight: 20),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
  ]).animate(_controller);
  late final Animation<double> _reveal =
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 0.75, curve: Curves.easeOut));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.animate && !CgMotion.reduced(context)) {
      _controller.forward();
      CgHaptics.good();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Transform.scale(
          key: DoneCheck.scaleKey,
          scale: _scale.value,
          child: DecoratedBox(
            decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
            child: Center(
              child: ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: _reveal.value,
                  child: CgIcon(CgIcons.check, size: widget.size * DoneCheck._checkRatio, color: c.accentInk),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

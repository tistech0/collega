import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/theme/cg_theme.dart';
import 'package:collega_app/core/ui/tokens/cg_motion.dart';
import 'package:collega_app/core/ui/tokens/cg_space.dart';
import 'package:collega_app/core/ui/tokens/cg_type.dart';

/// `s` 56 pt (lignes), `m` 84 pt (tête de collège), `l` 200 pt (fin de session).
enum CgRingSize { s, m, l }

/// Anneau de progression (spec v2 § CgRing) : la part maîtrisée d'un collège
/// ou d'une session. Rail `unseen`, arc `accent` (bouts ronds, départ en haut,
/// sens horaire), valeur centrée en chiffres tabulaires.
///
/// Se remplit de 0 à [value] en [CgMotion.ringFill] une seule fois, à
/// l'apparition ; si [value] change ensuite, l'arc va de l'ancienne valeur à
/// la nouvelle. Mouvement réduit ou `animate: false` : valeur directe.
class CgRing extends StatefulWidget {
  const CgRing({
    super.key,
    required this.value,
    this.size = CgRingSize.s,
    this.centerLabel,
    this.semanticLabel,
    this.animate = true,
  });

  /// Part remplie, de 0 à 1 (ramenée dans ces bornes).
  final double value;
  final CgRingSize size;

  /// Texte central ; par défaut le pourcentage entier (« 42 % »).
  final String? centerLabel;

  /// Ce que mesure l'anneau, lu par VoiceOver avant la valeur.
  final String? semanticLabel;
  /// Remplissage animé à l'apparition. Dans une liste paresseuse, passer `false`
  /// (ou `true` seulement au premier affichage de l'écran) : une ligne recréée au
  /// défilement rejouerait sinon son animation (spec : une fois par écran).
  final bool animate;

  @override
  State<CgRing> createState() => _CgRingState();
}

class _CgRingState extends State<CgRing> with SingleTickerProviderStateMixin {
  /// Écart entre le bord intérieur du trait et le texte central.
  static const _labelInset = CgSpace.s1;

  /// Diamètres et épaisseurs de trait (spec v2 § CgRing).
  static const _diameterS = 56.0;
  static const _diameterM = 84.0;
  static const _diameterL = 200.0;
  static const _strokeS = 5.0;
  static const _strokeM = 7.0;
  static const _strokeL = 14.0;

  /// La valeur est un chiffre : toujours tabulaire (`head` ne l'est pas).
  static const _tabular = [FontFeature.tabularFigures()];

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: CgMotion.ringFill);
  late final CurvedAnimation _curve = CurvedAnimation(parent: _controller, curve: CgMotion.out);

  /// Valeur de départ de l'animation en cours (0 à l'apparition).
  double _from = 0;
  bool _started = false;

  double get _target => widget.value.clamp(0.0, 1.0);

  bool get _instant => !widget.animate || CgMotion.reduced(context);

  /// Valeur affichée à l'instant.
  double get _shown => _from + (_target - _from) * _curve.value;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Première apparition : `initState` n'a pas encore accès à MediaQuery.
    if (_started) return;
    _started = true;
    if (_instant) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(CgRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.value.clamp(0.0, 1.0);
    if (old == _target) return;
    if (_instant) {
      _controller.value = 1;
      _from = _target;
      return;
    }
    // Repart de ce qui est affiché (même en plein remplissage), pas de 0.
    _from = _from + (old - _from) * _curve.value;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    final (double diameter, double stroke, TextStyle style) = switch (widget.size) {
      CgRingSize.s => (_diameterS, _strokeS, CgType.label.copyWith(fontWeight: FontWeight.w700)),
      CgRingSize.m => (_diameterM, _strokeM, CgType.head),
      CgRingSize.l => (_diameterL, _strokeL, CgType.display),
    };
    final percent = '${(_target * 100).round()} %';

    return Semantics(
      label: widget.semanticLabel,
      value: percent,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: diameter,
        child: Stack(fit: StackFit.expand, children: [
          AnimatedBuilder(
            animation: _curve,
            builder: (context, _) => CustomPaint(
              painter: CgRingPainter(progress: _shown, track: c.unseen, arc: c.accent, strokeWidth: stroke),
            ),
          ),
          // Taille fixe : au-delà de ce que l'anneau contient, le texte se
          // réduit au lieu de déborder (Dynamic Type).
          Padding(
            padding: EdgeInsets.all(stroke + _labelInset),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.centerLabel ?? percent,
                  maxLines: 1,
                  softWrap: false,
                  style: style.copyWith(color: c.ink, fontFeatures: _tabular),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Dessine le rail et l'arc de [CgRing] (public pour les tests).
class CgRingPainter extends CustomPainter {
  const CgRingPainter({
    required this.progress,
    required this.track,
    required this.arc,
    required this.strokeWidth,
  });

  /// Part affichée (0..1).
  final double progress;
  final Color track;
  final Color arc;
  final double strokeWidth;

  /// Départ en haut (12 h), sens horaire.
  static const _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circle = rect.deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = track;
    canvas.drawOval(circle, paint);
    // À 0, un bout rond dessinerait un point : rien.
    if (progress <= 0) return;
    paint
      ..color = arc
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(circle, _start, 2 * math.pi * progress.clamp(0.0, 1.0), false, paint);
  }

  @override
  bool shouldRepaint(CgRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.track != track ||
      oldDelegate.arc != arc ||
      oldDelegate.strokeWidth != strokeWidth;
}

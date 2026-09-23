import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:collega_app/core/ui/collega_ui.dart';

/// Emplacement chronomètre de l'en-tête du drill (story 8.4, demande utilisateur) :
/// tap = activer / désactiver le chrono pour la session ; appui long = pause.
/// Actif : anneau qui se vide sur la durée par fiche, secondes restantes au centre.
class DrillTimerSlot extends StatefulWidget {
  const DrillTimerSlot({
    super.key,
    required this.enabled,
    required this.paused,
    required this.running,
    required this.durationSeconds,
    required this.cardKey,
    required this.onToggle,
    required this.onTogglePause,
    required this.onExpired,
  });

  final bool enabled;
  final bool paused;

  /// Faux quand la réponse est ouverte : le temps ne compte que sur le recto.
  final bool running;
  final int durationSeconds;

  /// Change à chaque fiche : le compte repart de la durée complète.
  final Object cardKey;
  final VoidCallback onToggle;
  final VoidCallback onTogglePause;
  final VoidCallback onExpired;

  @override
  State<DrillTimerSlot> createState() => _DrillTimerSlotState();
}

class _DrillTimerSlotState extends State<DrillTimerSlot> with SingleTickerProviderStateMixin {
  static const _ringSize = 30.0;
  static const _stroke = 2.5;
  static const _railAlpha = 0.22;
  static const _idleAlpha = 0.85;

  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.durationSeconds),
  )..addStatusListener(_onStatus);

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(DrillTimerSlot old) {
    super.didUpdateWidget(old);
    if (old.durationSeconds != widget.durationSeconds) {
      // Un contrôleur en marche garde sa durée : on le relance sur la nouvelle.
      _clock.stop();
      _clock.duration = Duration(seconds: widget.durationSeconds);
    }
    if (old.cardKey != widget.cardKey || (!old.enabled && widget.enabled)) _clock.value = 0;
    _sync();
  }

  void _sync() {
    final tick = widget.enabled && widget.running && !widget.paused;
    if (tick && !_clock.isAnimating && !_clock.isCompleted) {
      _clock.forward();
    } else if (!tick && _clock.isAnimating) {
      _clock.stop();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && widget.enabled) widget.onExpired();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  int get _remaining => (widget.durationSeconds * (1 - _clock.value)).ceil();

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final label = !widget.enabled
            ? 'Activer le chronomètre'
            : 'Chronomètre activé, $_remaining secondes${widget.paused ? ', en pause' : ''}';
        return Semantics(
          button: true,
          label: label,
          hint: widget.enabled ? 'Touche pour désactiver, appui long pour la pause' : null,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onToggle,
            onLongPress: widget.enabled ? widget.onTogglePause : null,
            child: SizedBox.square(
              dimension: CgSpace.tapTarget,
              child: Center(
                child: !widget.enabled
                    ? CgIcon(CgIcons.clock, color: c.accentInk.withValues(alpha: _idleAlpha))
                    : SizedBox.square(
                        dimension: _ringSize,
                        child: CustomPaint(
                          painter: _RingPainter(
                            progress: 1 - _clock.value,
                            color: c.accentInk,
                            rail: c.accentInk.withValues(alpha: _railAlpha),
                            stroke: _stroke,
                          ),
                          child: Center(
                            child: MediaQuery.withNoTextScaling(
                              child: Text(
                                widget.paused ? '‖' : '$_remaining',
                                style: CgType.label.copyWith(color: c.accentInk, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color, required this.rail, required this.stroke});

  final double progress;
  final Color color;
  final Color rail;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final deflated = rect.deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(deflated, 0, 2 * math.pi, false, paint..color = rail);
    canvas.drawArc(deflated, -math.pi / 2, 2 * math.pi * progress, false, paint..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.rail != rail;
}

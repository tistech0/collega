import 'dart:math';

import 'package:flutter/material.dart';

import 'package:collega_app/core/theme/app_theme.dart';

/// Anneau de chronomètre count-down affiché sur le recto d'une carte drill.
///
/// Le timer est local au widget (pas de provider) pour éviter les rebuilds en
/// cascade des watchers du `drillSessionProvider` à chaque tick d'animation.
/// L'expiration est propagée au notifier via le callback [onExpired].
class TimerRing extends StatefulWidget {
  const TimerRing({
    super.key,
    required this.durationSeconds,
    required this.cardId,
    required this.isPaused,
    required this.onExpired,
    this.size = 48.0,
  });

  /// Durée totale du count-down en secondes (≥ 1).
  final int durationSeconds;

  /// Identifiant de la carte courante — change → reset du timer.
  final String cardId;

  /// État pause local à la session drill.
  final bool isPaused;

  /// Appelé une seule fois lorsque le timer atteint 0.
  final VoidCallback onExpired;

  /// Taille (width = height) du widget en pixels.
  final double size;

  @override
  State<TimerRing> createState() => _TimerRingState();
}

class _TimerRingState extends State<TimerRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.durationSeconds.clamp(1, 3600)),
    );
    _controller.addStatusListener(_handleStatus);
    if (!widget.isPaused) {
      _controller.forward();
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_expired) {
      _expired = true;
      widget.onExpired();
    }
  }

  @override
  void didUpdateWidget(covariant TimerRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset complet uniquement sur changement de carte — un changement de
    // durée seul (ex : iPad split-view qui modifie les prefs) ne rearm PAS
    // _expired, sinon onExpired pourrait re-firer et déclencher un 2e toast
    // "Temps écoulé" sur la même carte.
    if (widget.cardId != oldWidget.cardId) {
      _expired = false;
      _controller.duration =
          Duration(seconds: widget.durationSeconds.clamp(1, 3600));
      _controller.reset();
      if (!widget.isPaused) {
        _controller.forward();
      }
      return;
    }
    // Changement de durée seul : mettre à jour la duration mais sans rearmer.
    if (widget.durationSeconds != oldWidget.durationSeconds) {
      _controller.duration =
          Duration(seconds: widget.durationSeconds.clamp(1, 3600));
    }
    // Transition pause / reprise.
    if (widget.isPaused != oldWidget.isPaused) {
      if (widget.isPaused) {
        _controller.stop();
      } else if (!_expired) {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPaused = widget.isPaused;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final remaining =
              (widget.durationSeconds * (1 - _controller.value)).ceil();
          final clamped = remaining < 0 ? 0 : remaining;
          final ringColor =
              isPaused ? AppColors.secondary : AppColors.primary;
          return Semantics(
            label: isPaused
                ? 'Chronomètre en pause, $clamped secondes restantes'
                : 'Chronomètre, $clamped secondes restantes',
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _TimerRingPainter(
                    progress: 1 - _controller.value,
                    color: ringColor,
                  ),
                ),
                Text(
                  '${clamped}s',
                  style: TextStyle(
                    fontSize: widget.size * 0.28,
                    fontWeight: FontWeight.w600,
                    color: ringColor,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TimerRingPainter extends CustomPainter {
  _TimerRingPainter({required this.progress, required this.color});

  /// 1.0 = plein (début), 0.0 = vide (expiration).
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 4.0;
    final radius = size.width / 2 - strokeWidth;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Fond
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Arc actif décroissant
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_TimerRingPainter old) =>
      old.progress != progress || old.color != color;
}

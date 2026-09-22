import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/drill_providers.dart';

/// Écran de fin de session (ancien rendu, redessiné en story 8.5).
class DrillEndScreen extends StatelessWidget {
  const DrillEndScreen({super.key, required this.session, required this.notifier, required this.params});

  final DrillSessionState session;
  final DrillSessionNotifier notifier;
  final DrillSessionParams params;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(child: _DrillEndScreen(session: session, notifier: notifier, params: params)),
      );
}

// ─── Écran de fin ─────────────────────────────────────────────────────────────

class _DrillEndScreen extends ConsumerWidget {
  const _DrillEndScreen({
    required this.session,
    required this.notifier,
    required this.params,
  });

  final DrillSessionState session;
  final DrillSessionNotifier notifier;
  final DrillSessionParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary =
        DrillSessionSummary.fromEvaluations(session.evaluations);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenMargin),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Session terminée',
            style: AppTypography.titleLarge(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sectionSpacing),
          Center(child: _MasteryCircle(ratio: summary.masteryRatio)),
          const SizedBox(height: AppSpacing.sectionSpacing),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Maîtrisé',
                  count: summary.maitrisCount,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'Bien',
                  count: summary.bienCount,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  label: 'À revoir',
                  count: summary.aRevoirCount,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sectionSpacing),
          ShadButton(
            onPressed:
                summary.aRevoirCount > 0 ? notifier.restartWithErrors : null,
            width: double.infinity,
            child: const Text('Recommencer les erreurs'),
          ),
          if (params.fromSearch) ...[
            const SizedBox(height: 8),
            ShadButton(
              // La recherche est hors onglets : elle remplace le drill et garde un retour.
              onPressed: () => context.pushReplacement('/search'),
              width: double.infinity,
              child: const Text('Nouvelle recherche'),
            ),
            const SizedBox(height: 8),
            ShadButton.outline(
              onPressed: () => _leave(context),
              width: double.infinity,
              child: const Text("Retour à l'accueil"),
            ),
          ] else ...[
            const SizedBox(height: 8),
            ShadButton.outline(
              onPressed: () => _leave(context),
              width: double.infinity,
              child: const Text("Retour à l'accueil"),
            ),
          ],
        ],
      ),
    );
  }
}

class _MasteryCircle extends StatelessWidget {
  const _MasteryCircle({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(160, 160),
      painter: _DonutPainter(ratio: ratio),
      child: SizedBox(
        width: 160,
        height: 160,
        child: Center(
          child: Text(
            '${(ratio * 100).round()}%',
            style: AppTypography.titleLarge()
                .copyWith(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.ratio});

  final double ratio;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 20.0;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi,
      false,
      Paint()
        ..color = const Color(0xFFE8F5EC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (ratio > 0) {
      canvas.drawArc(
        rect,
        -pi / 2,
        2 * pi * ratio,
        false,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.ratio != ratio;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          Text(
            '$count',
            style: AppTypography.titleLarge()
                .copyWith(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.labelMedium(), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// Quitte le drill : retour à l'écran d'origine (Aujourd'hui se recalcule au
/// retour ; la session du jour est déjà close automatiquement, story 8.3).
void _leave(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/drill/drill_providers.dart';
import 'package:collega_app/features/drill/widgets/drill_evaluation_bar.dart';
import 'package:collega_app/features/generation/widgets/flash_card_widget.dart';
import 'package:collega_app/features/planning/planning_providers.dart';

class DrillScreen extends ConsumerWidget {
  const DrillScreen({super.key, required this.params});

  final DrillSessionParams params;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drillAsync = ref.watch(drillSessionProvider(params));
    final notifier = ref.read(drillSessionProvider(params).notifier);

    return Scaffold(
      body: SafeArea(
        child: drillAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (session) => session.isComplete
              ? _DrillEndScreen(session: session, notifier: notifier)
              : _DrillActiveView(
                  session: session,
                  notifier: notifier,
                  itemTitle: params.itemName,
                ),
        ),
      ),
    );
  }
}

class _DrillActiveView extends ConsumerStatefulWidget {
  const _DrillActiveView({
    required this.session,
    required this.notifier,
    this.itemTitle,
  });

  final DrillSessionState session;
  final DrillSessionNotifier notifier;
  final String? itemTitle;

  @override
  ConsumerState<_DrillActiveView> createState() => _DrillActiveViewState();
}

class _DrillActiveViewState extends ConsumerState<_DrillActiveView> {
  final _answerController = TextEditingController();

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Color _rangColor(String rang) {
    switch (rang) {
      case 'A':
        return AppColors.primary;
      case 'B':
        return AppColors.secondary;
      default:
        return const Color(0xFF6B7C6E);
    }
  }

  Future<void> _handleDefinitionSubmit(String cardId, String answer) async {
    if (answer.trim().isEmpty) return;
    try {
      final repo = ref.read(drillRepositoryProvider);
      final feedback = await repo.evaluateSemantic(cardId, answer.trim());
      widget.notifier.setSemanticFeedback(feedback);
      widget.notifier.flip();
    } catch (_) {
      widget.notifier.flip();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final notifier = widget.notifier;
    final card = session.currentCard;

    if (card == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isDefinitionFront =
        card.cardType == 'definition' && !session.isFlipped;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
            vertical: 8,
          ),
          child: Row(
            children: [
              Semantics(
                label: 'Quitter le drill',
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => context.pop(),
                ),
              ),
              Expanded(
                child: Text(
                  widget.itemTitle ?? card.itemId,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLarge(),
                ),
              ),
              ShadBadge(
                backgroundColor: _rangColor(card.rang),
                child: Text(
                  'Rang ${card.rang}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        // Progress
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${session.evaluatedCount} / ${session.totalInitial} fiches',
                style: AppTypography.labelMedium(),
              ),
              const SizedBox(height: 4),
              ShadProgress(
                value: session.totalInitial == 0
                    ? 0
                    : session.evaluatedCount / session.totalInitial,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenMargin),
            child: FlashCardWidget(
              card: card,
              isFlipped: session.isFlipped,
              exitResult: session.exitResult,
              onFlip: isDefinitionFront ? null : notifier.flip,
              onExitComplete: notifier.advanceToNext,
            ),
          ),
        ),
        // Semantic feedback banner
        if (session.semanticFeedback != null)
          _SemanticFeedbackBanner(feedback: session.semanticFeedback!),
        // Definition input (recto uniquement, avant retournement)
        if (isDefinitionFront)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenMargin,
              vertical: 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ShadInput(
                    controller: _answerController,
                    placeholder: const Text('Votre définition…'),
                  ),
                ),
                const SizedBox(width: 8),
                ShadButton(
                  onPressed: () {
                    _handleDefinitionSubmit(card.id, _answerController.text);
                    _answerController.clear();
                  },
                  child: const Text('Évaluer'),
                ),
              ],
            ),
          ),
        // Evaluation bar
        DrillEvaluationBar(
          isVisible: session.isFlipped,
          onEvaluate: notifier.evaluate,
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SemanticFeedbackBanner extends StatelessWidget {
  const _SemanticFeedbackBanner({required this.feedback});

  final SemanticFeedback feedback;

  Color get _color {
    switch (feedback.result) {
      case 'correct':
        return AppColors.primary;
      case 'partial':
        return AppColors.secondary;
      default:
        return AppColors.error;
    }
  }

  String get _label {
    switch (feedback.result) {
      case 'correct':
        return 'Correct';
      case 'partial':
        return 'Partiel';
      default:
        return 'Incorrect';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenMargin,
        vertical: 4,
      ),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        border: Border.all(color: _color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          ShadBadge(
            backgroundColor: _color,
            child: Text(_label, style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feedback.feedback,
              style: AppTypography.bodyMedium(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Écran de fin ─────────────────────────────────────────────────────────────

class _DrillEndScreen extends ConsumerWidget {
  const _DrillEndScreen({
    required this.session,
    required this.notifier,
  });

  final DrillSessionState session;
  final DrillSessionNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary =
        DrillSessionSummary.fromEvaluations(session.evaluations);
    final planningAsync = ref.watch(planningProvider);
    final todaySession = planningAsync.valueOrNull?.todaySession;

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
          if (todaySession != null) ...[
            const SizedBox(height: 8),
            ShadButton.outline(
              onPressed: () async {
                await ref
                    .read(planningProvider.notifier)
                    .markTodayCompleted();
                if (context.mounted) context.go('/home');
              },
              width: double.infinity,
              child: const Text('Session terminée ✓'),
            ),
          ],
          const SizedBox(height: 8),
          ShadButton.outline(
            onPressed: () => context.go('/home'),
            width: double.infinity,
            child: const Text('Retour à l\'accueil'),
          ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/demo/demo_providers.dart';
import 'package:collega_app/features/demo/domain/demo_data.dart';
import 'package:collega_app/features/demo/presentation/widgets/demo_drill_evaluation_bar.dart';
import 'package:collega_app/features/demo/presentation/widgets/demo_flash_card_widget.dart';

class DemoDrillScreen extends ConsumerWidget {
  const DemoDrillScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(demoDrillProvider);
    final notifier = ref.read(demoDrillProvider.notifier);
    final cards = demoCollege.item.cards;
    final total = cards.length;

    if (state.isComplete) {
      return _RecapScreen(evaluations: state.evaluations, notifier: notifier);
    }

    final currentCard = cards[state.currentIndex];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenMargin,
                vertical: 8,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => context.go('/demo'),
                  ),
                  Expanded(
                    child: Text(
                      demoCollege.name,
                      style: AppTypography.bodyLarge(),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  ShadBadge(
                    backgroundColor: currentCard.rang == 'A'
                        ? AppColors.primary
                        : AppColors.secondary,
                    child: Text(
                      'Rang ${currentCard.rang}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${state.currentIndex + (state.isFlipped ? 1 : 0)}/$total fiches',
                    style: AppTypography.labelMedium(),
                  ),
                  const SizedBox(height: 4),
                  ShadProgress(
                    value: (state.currentIndex + (state.isFlipped ? 1 : 0)) / total,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
                child: DemoFlashCardWidget(
                  card: currentCard,
                  isFlipped: state.isFlipped,
                  onFlip: notifier.flip,
                ),
              ),
            ),
            const SizedBox(height: 16),
            DemoDrillEvaluationBar(
              isVisible: state.isFlipped,
              onEvaluate: notifier.evaluate,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _RecapScreen extends StatelessWidget {
  const _RecapScreen({
    required this.evaluations,
    required this.notifier,
  });

  final Map<int, String> evaluations;
  final DemoDrillNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final maitrise = evaluations.values.where((v) => v == 'MAITRISE').length;
    final bien = evaluations.values.where((v) => v == 'BIEN').length;
    final aRevoir = evaluations.values.where((v) => v == 'A_REVOIR').length;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Résultat de la séance',
                style: AppTypography.titleLarge(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sectionSpacing),
              ShadCard(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  children: [
                    _RecapRow(label: 'Maîtrisé', count: maitrise, color: AppColors.primary),
                    const SizedBox(height: 8),
                    _RecapRow(label: 'Bien', count: bien, color: AppColors.secondary),
                    const SizedBox(height: 8),
                    _RecapRow(label: 'À revoir', count: aRevoir, color: AppColors.error),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionSpacing),
              ShadButton(
                onPressed: () => context.go('/auth/register'),
                child: const Text('Commencer pour de vrai'),
              ),
              const SizedBox(height: 8),
              ShadButton.outline(
                onPressed: () => notifier.reset(),
                child: const Text('Recommencer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  const _RecapRow({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodyLarge()),
        ShadBadge(
          backgroundColor: color,
          child: Text(
            '$count',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';

class DrillEvaluationBar extends StatelessWidget {
  const DrillEvaluationBar({
    super.key,
    required this.isVisible,
    required this.onEvaluate,
  });

  final bool isVisible;
  final void Function(DrillEvaluationResult result) onEvaluate;

  void _onTap(DrillEvaluationResult result) {
    HapticFeedback.lightImpact();
    onEvaluate(result);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !isVisible,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: 'Évaluation: À revoir',
                child: ShadButton.destructive(
                  onPressed: () => _onTap(DrillEvaluationResult.aRevoir),
                  child: const Text('À revoir'),
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: 'Évaluation: Bien',
                child: ShadButton.outline(
                  onPressed: () => _onTap(DrillEvaluationResult.bien),
                  foregroundColor: AppColors.secondary,
                  child: const Text('Bien'),
                ),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: 'Évaluation: Maîtrisé',
                child: ShadButton(
                  onPressed: () => _onTap(DrillEvaluationResult.maitrise),
                  child: const Text('Maîtrisé'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

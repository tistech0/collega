import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';

class DemoDrillEvaluationBar extends StatelessWidget {
  const DemoDrillEvaluationBar({
    super.key,
    required this.isVisible,
    required this.onEvaluate,
  });

  final bool isVisible;
  final void Function(String rang) onEvaluate;

  void _onTap(String rang) {
    HapticFeedback.lightImpact();
    onEvaluate(rang);
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
              ShadButton.destructive(
                onPressed: () => _onTap('A_REVOIR'),
                child: const Text('À revoir'),
              ),
              const SizedBox(height: 8),
              ShadButton.outline(
                onPressed: () => _onTap('BIEN'),
                foregroundColor: AppColors.secondary,
                child: const Text('Bien'),
              ),
              const SizedBox(height: 8),
              ShadButton(
                onPressed: () => _onTap('MAITRISE'),
                child: const Text('Maîtrisé'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

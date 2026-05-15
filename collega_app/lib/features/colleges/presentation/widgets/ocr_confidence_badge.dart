import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';

class OcrConfidenceBadge extends StatefulWidget {
  const OcrConfidenceBadge({super.key, required this.score});

  final double score;

  @override
  State<OcrConfidenceBadge> createState() => _OcrConfidenceBadgeState();
}

class _OcrConfidenceBadgeState extends State<OcrConfidenceBadge> {
  final _controller = ShadPopoverController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.score;
    if (!score.isFinite || score <= 0.0 || score >= 0.7) {
      return const SizedBox.shrink();
    }

    final isVeryLow = score < 0.5;
    final bgColor = isVeryLow ? AppColors.error : AppColors.warning;
    final label = isVeryLow ? 'Source peu lisible' : 'À vérifier';
    final icon = isVeryLow ? Icons.warning_rounded : Icons.info_outline_rounded;

    return ShadPopover(
      controller: _controller,
      popover: (context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isVeryLow
                  ? 'La qualité OCR de cette source est très faible. Les données peuvent contenir des erreurs.'
                  : 'La qualité OCR de cette source est moyenne. Certaines données peuvent être imprécises.',
              style: AppTypography.bodyMedium(),
            ),
            const SizedBox(height: 8),
            Text(
              'Vérifier dans le PDF original',
              style: AppTypography.bodyMedium()
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      child: GestureDetector(
        onTap: _controller.toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTypography.bodyMedium()
                    .copyWith(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

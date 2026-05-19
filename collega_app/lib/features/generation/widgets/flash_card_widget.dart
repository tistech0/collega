import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/colleges/domain/college_detail_models.dart';
import 'package:collega_app/features/colleges/presentation/widgets/ocr_confidence_badge.dart';
import 'package:collega_app/features/drill/domain/drill_state.dart';

class FlashCardWidget extends StatefulWidget {
  const FlashCardWidget({
    super.key,
    required this.card,
    required this.isFlipped,
    this.exitResult,
    this.onFlip,
    this.onExitComplete,
  });

  final FlashCardModel card;
  final bool isFlipped;
  final DrillEvaluationResult? exitResult;
  final VoidCallback? onFlip;
  final VoidCallback? onExitComplete;

  @override
  State<FlashCardWidget> createState() => _FlashCardWidgetState();
}

class _FlashCardWidgetState extends State<FlashCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _rotateAnim;
  DrillEvaluationResult? _localExitResult;
  bool _flipPending = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _rotateAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    if (widget.isFlipped) _flipController.value = 1.0;
    _localExitResult = widget.exitResult;
  }

  @override
  void didUpdateWidget(FlashCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.card != oldWidget.card) {
      _flipController.value = 0.0;
      _flipPending = false;
      if (_localExitResult != null) setState(() => _localExitResult = null);
      return;
    }
    if (widget.isFlipped != oldWidget.isFlipped) {
      _flipPending = false;
    }
    if (widget.isFlipped && !oldWidget.isFlipped) {
      _flipController.forward();
    } else if (!widget.isFlipped && oldWidget.isFlipped) {
      _flipController.reverse();
    }
    if (widget.exitResult != null && _localExitResult == null) {
      setState(() => _localExitResult = widget.exitResult);
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onFlip == null) return;
    if (_localExitResult != null) return;
    if (_flipPending) return;
    if (_flipController.isAnimating) return;
    _flipPending = true;
    widget.onFlip!.call();
  }

  Color _rangBadgeColor(String rang) {
    switch (rang) {
      case 'A':
        return AppColors.primary;
      case 'B':
        return AppColors.secondary;
      default:
        return const Color(0xFF6B7C6E);
    }
  }

  Widget _buildCardSide({required bool isFront}) {
    final text = isFront ? widget.card.recto : widget.card.verso;
    final label = isFront ? 'Question' : 'Réponse';
    return ShadCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShadBadge(
                    backgroundColor: _rangBadgeColor(widget.card.rang),
                    child: Text(
                      'Rang ${widget.card.rang}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: AppTypography.labelMedium()
                        .copyWith(color: AppColors.secondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: Text(
                    text,
                    style: AppTypography.titleMedium(),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          if (isFront)
            Positioned(
              bottom: 0,
              left: 0,
              child: OcrConfidenceBadge(score: widget.card.ocrConfidenceScore),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget card = Semantics(
      label: 'Flashcard Rang ${widget.card.rang} — ${widget.card.recto}',
      hint: widget.onFlip == null ? null : 'Tapoter pour retourner',
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: double.infinity,
          height: 300,
          child: AnimatedBuilder(
            animation: _rotateAnim,
            builder: (ctx, _) {
              final angle = _rotateAnim.value * pi;
              final showFront = angle < pi / 2;
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                alignment: Alignment.center,
                child: showFront
                    ? _buildCardSide(isFront: true)
                    : Transform(
                        transform: Matrix4.identity()..rotateY(pi),
                        alignment: Alignment.center,
                        child: _buildCardSide(isFront: false),
                      ),
              );
            },
          ),
        ),
      ),
    );

    if (_localExitResult != null) {
      final result = _localExitResult!;
      if (result.slidesUp) {
        card = card
            .animate()
            .slideY(end: -1.5, duration: 250.ms)
            .fade(end: 0, duration: 250.ms)
            .callback(callback: (_) { if (mounted) widget.onExitComplete?.call(); });
      } else if (result.slidesDown) {
        card = card
            .animate()
            .slideY(end: 1.5, duration: 250.ms)
            .fade(end: 0, duration: 250.ms)
            .callback(callback: (_) { if (mounted) widget.onExitComplete?.call(); });
      } else {
        card = card
            .animate()
            .fade(end: 0, duration: 250.ms)
            .callback(callback: (_) { if (mounted) widget.onExitComplete?.call(); });
      }
    }

    return card;
  }
}

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/demo/domain/demo_data.dart';

class DemoFlashCardWidget extends StatefulWidget {
  const DemoFlashCardWidget({
    super.key,
    required this.card,
    required this.isFlipped,
    this.onFlip,
  });

  final DemoFlashCard card;
  final bool isFlipped;
  final VoidCallback? onFlip;

  @override
  State<DemoFlashCardWidget> createState() => _DemoFlashCardWidgetState();
}

class _DemoFlashCardWidgetState extends State<DemoFlashCardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _rotateAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isFlipped) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(DemoFlashCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.card != oldWidget.card) {
      _controller.value = 0.0;
      return;
    }
    if (!widget.isFlipped && oldWidget.isFlipped) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.isFlipped) return;
    _controller.forward();
    widget.onFlip?.call();
  }

  Widget _buildRecto() {
    return _CardSide(
      rang: widget.card.rang,
      content: widget.card.front,
      isBack: false,
    );
  }

  Widget _buildVerso() {
    return _CardSide(
      rang: widget.card.rang,
      content: widget.card.back,
      isBack: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Flashcard Rang ${widget.card.rang} — ${widget.card.front}',
      hint: 'Tapoter pour retourner',
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
              final showFront = angle <= pi / 2;
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                alignment: Alignment.center,
                child: showFront
                    ? _buildRecto()
                    : Transform(
                        transform: Matrix4.identity()..rotateY(pi),
                        alignment: Alignment.center,
                        child: _buildVerso(),
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CardSide extends StatelessWidget {
  const _CardSide({
    required this.rang,
    required this.content,
    required this.isBack,
  });

  final String rang;
  final String content;
  final bool isBack;

  @override
  Widget build(BuildContext context) {
    final badgeColor = rang == 'A' ? AppColors.primary : AppColors.secondary;

    return ShadCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShadBadge(
                backgroundColor: badgeColor,
                child: Text(
                  'Rang $rang',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isBack ? 'Réponse' : 'Question',
                style: AppTypography.labelMedium().copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: Text(
                content,
                style: AppTypography.bodyLarge(),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/home/domain/home_session_config.dart';
import 'package:collega_app/features/home/home_providers.dart';

class SessionHeroCard extends StatelessWidget {
  const SessionHeroCard({
    super.key,
    required this.homeState,
    required this.onModify,
    this.onPostpone,
  });

  final HomeState homeState;
  final VoidCallback onModify;
  final VoidCallback? onPostpone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _semanticsLabel,
      child: ShadCard(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: switch (homeState) {
          HomeEmpty() => const _EmptyState(),
          HomeOcrInProgress(:final collegeName) =>
            _OcrInProgressState(collegeName: collegeName),
          HomeReady(:final sessionConfig, :final totalCards, :final estimatedDuration) =>
            _ReadyState(
              config: sessionConfig,
              cardCount: totalCards,
              duration: estimatedDuration,
              onModify: onModify,
              onPostpone: onPostpone,
            ),
        },
      ),
    );
  }

  String get _semanticsLabel => switch (homeState) {
        HomeEmpty() => 'Aucun collège importé. Importe ton premier collège pour commencer.',
        HomeOcrInProgress(:final collegeName) =>
          'Génération en cours pour $collegeName.',
        HomeReady(:final sessionConfig, :final totalCards) =>
          'Session pour ${sessionConfig.collegeName}, $totalCards fiches disponibles.',
      };
}

// ─── _ReadyState ──────────────────────────────────────────────────────────────

class _ReadyState extends StatelessWidget {
  const _ReadyState({
    required this.config,
    required this.cardCount,
    required this.duration,
    required this.onModify,
    this.onPostpone,
  });

  final HomeSessionConfig config;
  final int cardCount;
  final String duration;
  final VoidCallback onModify;
  final VoidCallback? onPostpone;

  void _launchDrill(BuildContext context) {
    context.push(
      '/drill',
      extra: DrillSessionParams(
        collegeId: config.collegeId,
        itemId: null,
        itemName: config.collegeName,
        rangs: config.rangs,
        onlyARevoir: config.onlyARevoir,
        maxCards: config.maxCards,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCards = cardCount > 0;
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 44),
                    child: Text(
                      config.collegeName,
                      style: AppTypography.titleMedium(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
        _RangsBadges(rangs: config.rangs),
        const SizedBox(height: 4),
        Text(duration, style: AppTypography.labelMedium().copyWith(color: const Color(0xFF6B7C6E))),
        const SizedBox(height: 12),
        if (hasCards)
          Text(
            '$cardCount fiches',
            style: AppTypography.displayMedium(),
          )
        else
          Text(
            'Aucune fiche disponible avec ces filtres',
            style: AppTypography.bodyMedium().copyWith(color: const Color(0xFF6B7C6E)),
          ),
        const SizedBox(height: 16),
        ShadButton(
          onPressed: hasCards ? () => _launchDrill(context) : null,
          width: double.infinity,
          child: const Text('Commencer'),
        ),
        if (onPostpone != null) ...[
          const SizedBox(height: 8),
          ShadButton.ghost(
            onPressed: onPostpone,
            width: double.infinity,
            child: Text(
              'Décaler à demain',
              style: AppTypography.labelMedium()
                  .copyWith(color: const Color(0xFF6B7C6E)),
            ),
          ),
        ],
      ],
    ),
        Positioned(
          top: 0,
          right: 0,
          child: SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: onModify,
              tooltip: 'Modifier la session',
            ),
          ),
        ),
      ],
    );
  }
}

class _RangsBadges extends StatelessWidget {
  const _RangsBadges({required this.rangs});
  final List<String>? rangs;

  @override
  Widget build(BuildContext context) {
    final active = (rangs == null || rangs!.isEmpty) ? ['A', 'B', 'C'] : rangs!;
    return Row(
      children: [
        for (final r in ['A', 'B', 'C'])
          if (active.contains(r)) ...[
            ShadBadge(child: Text(r)),
            const SizedBox(width: 4),
          ],
      ],
    );
  }
}

// ─── _OcrInProgressState ──────────────────────────────────────────────────────

class _OcrInProgressState extends StatelessWidget {
  const _OcrInProgressState({required this.collegeName});
  final String collegeName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Tes fiches arrivent...', style: AppTypography.titleMedium()),
        const SizedBox(height: 4),
        Text(collegeName, style: AppTypography.labelMedium()),
        const SizedBox(height: 12),
        const ShadProgress(),
      ],
    );
  }
}

// ─── _EmptyState ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Importe ton premier collège pour commencer',
          style: AppTypography.titleMedium(),
        ),
        const SizedBox(height: 16),
        ShadButton.outline(
          onPressed: () => context.go('/colleges'),
          width: double.infinity,
          child: const Text('Voir les collèges'),
        ),
      ],
    );
  }
}

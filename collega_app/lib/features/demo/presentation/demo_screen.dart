import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/demo/domain/demo_data.dart';

class DemoScreen extends StatelessWidget {
  const DemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = demoCollege.item.cards;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sectionSpacing),
              Text(
                'Découvrez AppMédecine',
                style: AppTypography.displayMedium(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Explorez une démo sans créer de compte',
                style: AppTypography.bodyMedium().copyWith(
                  color: AppColors.secondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sectionSpacing),
              ShadCard(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            demoCollege.name,
                            style: AppTypography.titleMedium(),
                          ),
                        ),
                        ShadBadge(
                          backgroundColor: demoCollege.item.rang == 'A'
                              ? AppColors.primary
                              : AppColors.secondary,
                          child: Text(
                            'Rang ${demoCollege.item.rang}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${demoCollege.item.title} — Item n°${demoCollege.item.number}',
                      style: AppTypography.bodyMedium().copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    ...cards.map((card) => _CardPreviewRow(card: card)),
                  ],
                ),
              ),
              const Spacer(),
              ShadButton(
                onPressed: () => context.go('/demo/drill'),
                child: const Text('Essayer la démo'),
              ),
              const SizedBox(height: 8),
              ShadButton.ghost(
                onPressed: () => context.go('/auth/register'),
                child: const Text('Accéder directement'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardPreviewRow extends StatelessWidget {
  const _CardPreviewRow({required this.card});
  final DemoFlashCard card;

  @override
  Widget build(BuildContext context) {
    final badgeColor = card.rang == 'A' ? AppColors.primary : AppColors.secondary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          ShadBadge(
            backgroundColor: badgeColor,
            child: Text(
              'Rang ${card.rang}',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              card.front,
              style: AppTypography.bodyMedium(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

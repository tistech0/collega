import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/colleges/colleges_providers.dart';
import 'package:collega_app/features/colleges/domain/college_models.dart';
import 'package:collega_app/features/colleges/domain/drill_stats.dart';

class CollegeProgressTile extends StatelessWidget {
  const CollegeProgressTile({
    super.key,
    required this.entry,
    this.onTap,
  });

  final CollegeListEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${entry.catalog.name}, ${entry.isImported ? "importé" : "non importé"}',
      child: entry.isImported
          ? _ImportedTile(
              entry: entry,
              collegeId: entry.userStatus!.collegeId,
              onTap: onTap,
            )
          : _NotImportedTile(entry: entry, onTap: onTap),
    );
  }
}

class _ImportedTile extends ConsumerWidget {
  const _ImportedTile({
    required this.entry,
    required this.collegeId,
    this.onTap,
  });
  final CollegeListEntry entry;
  final String collegeId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(collegeDrillStatsProvider(collegeId));
    final stats = statsAsync.valueOrNull ?? const DrillStats();
    return ShadCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(entry.catalog.icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.catalog.name,
                        style: AppTypography.titleMedium()
                            .copyWith(fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        entry.catalog.editor,
                        style: AppTypography.labelMedium(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                ShadBadge(child: const Text('A')),
                const SizedBox(width: 4),
                ShadBadge.secondary(child: const Text('B')),
                const SizedBox(width: 4),
                ShadBadge.outline(child: const Text('C')),
              ],
            ),
            const SizedBox(height: 6),
            _ProgressBar(
              mastered: stats.maitrise,
              well: stats.bien,
              toReview: stats.aRevoir,
              notSeen: stats.total == 0 ? 1 : stats.notSeen,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotImportedTile extends StatelessWidget {
  const _NotImportedTile({required this.entry, this.onTap});
  final CollegeListEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      backgroundColor: const Color(0xFFF1F5F2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                entry.catalog.icon,
                size: 20,
                color: const Color(0xFF6B7C6E),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.catalog.name,
                      style: AppTypography.titleMedium()
                          .copyWith(fontSize: 14, color: const Color(0xFF6B7C6E)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      entry.catalog.editor,
                      style: AppTypography.labelMedium(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ShadBadge.outline(child: const Text('Non-importé')),
              const Spacer(),
              ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: onTap,
                child: const Text('Charger'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.mastered,
    required this.well,
    required this.toReview,
    required this.notSeen,
  });

  final int mastered;
  final int well;
  final int toReview;
  final int notSeen;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            if (mastered > 0)
              Flexible(flex: mastered, child: Container(color: AppColors.primary)),
            if (well > 0)
              Flexible(flex: well, child: Container(color: AppColors.secondary)),
            if (toReview > 0)
              Flexible(flex: toReview, child: Container(color: AppColors.error)),
            if (notSeen > 0)
              Flexible(
                flex: notSeen,
                child: Container(color: Colors.grey.shade300),
              ),
          ],
        ),
      ),
    );
  }
}

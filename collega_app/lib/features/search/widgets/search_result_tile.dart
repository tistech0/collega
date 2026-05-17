import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/colleges/domain/college_catalog.dart';
import 'package:collega_app/features/drill/domain/drill_session_state.dart';
import 'package:collega_app/features/search/domain/search_result.dart';

class SearchResultTile extends StatelessWidget {
  const SearchResultTile({super.key, required this.result});
  final SearchResult result;

  Color get _borderColor => switch (result.rang) {
        'A' => AppColors.primary,
        'B' => AppColors.secondary,
        _ => Colors.transparent,
      };

  Color get _badgeColor => switch (result.rang) {
        'A' => AppColors.primary,
        'B' => AppColors.secondary,
        _ => AppColors.onSurface.withValues(alpha: 0.5),
      };

  String get _collegeName {
    try {
      return kCollegeCatalog.firstWhere((e) => e.refId == result.collegeRefId).name;
    } catch (_) {
      return 'Collège #${result.collegeRefId}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: _borderColor, width: 3)),
      ),
      child: ShadCard(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _badgeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Rang ${result.rang}',
                    style: AppTypography.labelMedium().copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.chapterTitle ?? 'Item ${result.itemNumber}',
                    style: AppTypography.titleMedium(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Item ${result.itemNumber} · $_collegeName',
              style: AppTypography.bodyMedium().copyWith(
                color: AppColors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            _HighlightedExcerpt(excerpt: result.excerpt),
            if (result.rang == 'A') ...[
              const SizedBox(height: 12),
              ShadButton(
                size: ShadButtonSize.sm,
                onPressed: () => context.push(
                  '/drill',
                  extra: DrillSessionParams(
                    collegeId: result.collegeId,
                    itemId: result.itemId,
                    itemName: 'Item ${result.itemNumber} · $_collegeName',
                    rangs: const ['A'],
                    fromSearch: true,
                  ),
                ),
                child: const Text("Réviser l'item"),
              ),
            ],
          ],
        ),
      ),
    );

    if (result.rang != 'A') {
      return GestureDetector(
        onTap: () => context.push(
          '/colleges/${result.collegeRefId}/items/${result.itemId}',
        ),
        child: card,
      );
    }
    return card;
  }
}

class _HighlightedExcerpt extends StatelessWidget {
  const _HighlightedExcerpt({required this.excerpt});
  final String excerpt;

  List<InlineSpan> _parse() {
    final parts = <InlineSpan>[];
    final regex = RegExp(r'<mark>(.*?)</mark>', dotAll: true);
    int lastEnd = 0;
    for (final match in regex.allMatches(excerpt)) {
      if (match.start > lastEnd) {
        parts.add(TextSpan(text: excerpt.substring(lastEnd, match.start)));
      }
      parts.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(backgroundColor: Color(0xFFB7F2C8)),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < excerpt.length) {
      parts.add(TextSpan(text: excerpt.substring(lastEnd)));
    }
    return parts;
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: AppTypography.bodyMedium(),
        children: _parse(),
      ),
    );
  }
}

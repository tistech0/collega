import 'package:flutter/material.dart';

import 'package:collega_app/core/theme/app_theme.dart';

class ItemProgressBar extends StatelessWidget {
  const ItemProgressBar({
    super.key,
    required this.countARevoir,
    required this.countBien,
    required this.countMaitrise,
    this.countNotSeen = 0,
    this.showCounts = false,
  });

  final int countARevoir;
  final int countBien;
  final int countMaitrise;
  final int countNotSeen;
  final bool showCounts;

  @override
  Widget build(BuildContext context) {
    final total = countARevoir + countBien + countMaitrise + countNotSeen;
    final bar = total == 0
        ? ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Container(height: 4, color: Colors.grey.shade300),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 4,
              child: Row(
                children: [
                  if (countMaitrise > 0)
                    Flexible(
                      flex: countMaitrise,
                      child: Container(color: AppColors.primary),
                    ),
                  if (countBien > 0)
                    Flexible(
                      flex: countBien,
                      child: Container(color: AppColors.secondary),
                    ),
                  if (countARevoir > 0)
                    Flexible(
                      flex: countARevoir,
                      child: Container(color: AppColors.error),
                    ),
                  if (countNotSeen > 0)
                    Flexible(
                      flex: countNotSeen,
                      child: Container(color: Colors.grey.shade300),
                    ),
                ],
              ),
            ),
          );

    if (!showCounts) return bar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        bar,
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          children: [
            if (countARevoir > 0)
              Text(
                'À revoir: $countARevoir',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            if (countBien > 0)
              Text(
                'Bien: $countBien',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            if (countMaitrise > 0)
              Text(
                'Maîtrisé: $countMaitrise',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            if (countNotSeen > 0)
              Text(
                'Non vues: $countNotSeen',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
      ],
    );
  }
}

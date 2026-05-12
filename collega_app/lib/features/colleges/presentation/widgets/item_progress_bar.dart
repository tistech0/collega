import 'package:flutter/material.dart';

import 'package:collega_app/core/theme/app_theme.dart';

class ItemProgressBar extends StatelessWidget {
  const ItemProgressBar({
    super.key,
    required this.countA,
    required this.countB,
    required this.countC,
  });

  final int countA;
  final int countB;
  final int countC;

  @override
  Widget build(BuildContext context) {
    final total = countA + countB + countC;
    if (total == 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Container(height: 4, color: Colors.grey.shade300),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 4,
        child: Row(
          children: [
            if (countA > 0)
              Flexible(
                flex: countA,
                child: Container(color: AppColors.primary),
              ),
            if (countB > 0)
              Flexible(
                flex: countB,
                child: Container(color: AppColors.secondary),
              ),
            if (countC > 0)
              Flexible(
                flex: countC,
                child: Container(color: AppColors.warning),
              ),
          ],
        ),
      ),
    );
  }
}

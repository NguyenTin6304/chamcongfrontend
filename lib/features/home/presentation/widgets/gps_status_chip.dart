import 'package:flutter/material.dart';

import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';

class GpsStatusChip extends StatelessWidget {
  const GpsStatusChip({super.key, required this.hasGps});

  final bool hasGps;

  @override
  Widget build(BuildContext context) {
    final color = hasGps ? AppColors.success : AppColors.warning;
    final bgColor = hasGps ? AppColors.successLight : AppColors.warningLight;
    final label = hasGps ? 'GPS đang hoạt động' : 'GPS không hoạt động';

    return Semantics(
      label: label,
      child: Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppRadius.chipAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppSpacing.sm,
              height: AppSpacing.sm,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTextStyles.chipText.copyWith(color: color),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

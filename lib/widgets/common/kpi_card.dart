import 'package:flutter/material.dart';

import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';

class KpiCard extends StatelessWidget {
  const KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    super.key,
    this.loading = false,
    this.subText,
    this.valueColor,
    this.subColor,
  });

  final String label;
  final String value;
  final bool loading;
  final String? subText;
  final Color? valueColor;
  final Color? subColor;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppTextStyles.sectionLabel.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 0.04,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    value,
                    style: AppTextStyles.kpiNumber.copyWith(
                      fontSize: 28,
                      color: valueColor ?? AppColors.textPrimary,
                    ),
                  ),
                if (subText != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subText!,
                    style: AppTextStyles.caption.copyWith(color: subColor),
                  ),
                ],
              ],
            ),
          ),
          Icon(icon, size: 20, color: iconColor),
        ],
      ),
    );
  }
}

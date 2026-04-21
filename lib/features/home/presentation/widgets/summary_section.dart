import 'package:flutter/material.dart';

import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';

class SummarySection extends StatelessWidget {
  const SummarySection({
    super.key,
    required this.todayWorkDuration,
    required this.weekWorkDuration,
    required this.onViewHistory,
  });

  final Duration todayWorkDuration;
  final Duration weekWorkDuration;
  final VoidCallback? onViewHistory;

  @override
  Widget build(BuildContext context) {
    final todayH = todayWorkDuration.inHours;
    final todayM = todayWorkDuration.inMinutes % 60;
    final weekH = weekWorkDuration.inHours;
    final weekM = weekWorkDuration.inMinutes % 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Tổng hợp hôm nay',
                style: AppTextStyles.sectionTitle.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: onViewHistory,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size(0, AppSizes.touchTargetMin),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              child: const Text('Xem nhật ký', style: AppTextStyles.body),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'GIỜ CÔNG HÔM NAY',
                value: '${todayH}h ${todayM.toString().padLeft(2, '0')}',
                accentColor: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _SummaryCard(
                label: 'GIỜ CÔNG TUẦN',
                value: '${weekH}h ${weekM.toString().padLeft(2, '0')}',
                accentColor: AppColors.overtime,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.accentColor,
  });

  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.paddingAllLg,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border(left: BorderSide(color: accentColor, width: 3)),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.sectionLabel.copyWith(color: accentColor),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            value,
            style: AppTextStyles.kpiNumber.copyWith(
              fontSize: 28,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

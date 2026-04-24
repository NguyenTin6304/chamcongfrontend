import 'package:flutter/material.dart';

import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';

enum StatusBadgeType { onTime, late, early, overtime, outOfRange, exception }

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.type, super.key});

  final StatusBadgeType type;

  String get _label => switch (type) {
        StatusBadgeType.onTime => 'Đúng giờ',
        StatusBadgeType.late => 'Vào muộn',
        StatusBadgeType.early => 'Vào sớm',
        StatusBadgeType.overtime => 'Tăng ca',
        StatusBadgeType.outOfRange => 'Ngoài vùng',
        StatusBadgeType.exception => 'Ngoại lệ',
      };

  Color get _background => switch (type) {
        StatusBadgeType.onTime => AppColors.badgeBgOnTime,
        StatusBadgeType.late => AppColors.badgeBgLate,
        StatusBadgeType.early => AppColors.badgeBgEarly,
        StatusBadgeType.overtime => AppColors.badgeBgOvertime,
        StatusBadgeType.outOfRange => AppColors.badgeBgOutOfRange,
        StatusBadgeType.exception => AppColors.badgeBgException,
      };

  Color get _foreground => switch (type) {
        StatusBadgeType.onTime => AppColors.badgeTextOnTime,
        StatusBadgeType.late => AppColors.badgeTextLate,
        StatusBadgeType.early => AppColors.badgeTextEarly,
        StatusBadgeType.overtime => AppColors.badgeTextOvertime,
        StatusBadgeType.outOfRange => AppColors.badgeTextOutOfRange,
        StatusBadgeType.exception => AppColors.badgeTextException,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: AppRadius.badgeAll,
      ),
      child: Text(
        _label,
        style: AppTextStyles.captionBold.copyWith(color: _foreground),
      ),
    );
  }
}

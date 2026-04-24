import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';

class DeadlineBadge extends StatelessWidget {
  const DeadlineBadge({required this.deadline, super.key});

  final DateTime? deadline;

  @override
  Widget build(BuildContext context) {
    final deadlineValue = deadline;
    final state = _deadlineState(deadlineValue);

    return Tooltip(
      message: deadlineValue == null
          ? 'Chưa có hạn giải trình'
          : DateFormat('dd/MM/yyyy HH:mm').format(deadlineValue.toLocal()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: state.bg,
          borderRadius: AppRadius.iconBoxAll,
          border: Border.all(color: state.border, width: 0.5),
        ),
        child: Text(
          state.label,
          style: AppTextStyles.captionBold,
        ),
      ),
    );
  }

  ({String label, Color bg, Color text, Color border}) _deadlineState(
    DateTime? deadline,
  ) {
    if (deadline == null) {
      return (
        label: '--',
        bg: AppColors.bgPage,
        text: AppColors.textMuted,
        border: AppColors.border,
      );
    }

    final remaining = deadline.toLocal().difference(DateTime.now());
    if (remaining.isNegative || remaining.inSeconds == 0) {
      return (
        label: 'Đã hết hạn',
        bg: AppColors.bgPage,
        text: AppColors.textMuted,
        border: AppColors.border,
      );
    }

    if (remaining > const Duration(hours: 48)) {
      return (
        label: _daysLabel(remaining),
        bg: AppColors.badgeBgOnTime,
        text: AppColors.badgeTextOnTime,
        border: AppColors.exceptionTabApprovedBorder,
      );
    }

    if (remaining > const Duration(hours: 24)) {
      return (
        label: 'Còn ${remaining.inHours} giờ',
        bg: AppColors.badgeBgLate,
        text: AppColors.badgeTextLate,
        border: AppColors.exceptionTabPendingBorder,
      );
    }

    return (
      label: _urgentLabel(remaining),
      bg: AppColors.badgeBgOutOfRange,
      text: AppColors.badgeTextOutOfRange,
      border: AppColors.exceptionTabRejectedBorder,
    );
  }

  String _daysLabel(Duration remaining) {
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    if (hours == 0) {
      return 'Còn $days ngày';
    }
    return 'Còn $days ngày $hours giờ';
  }

  String _urgentLabel(Duration remaining) {
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    if (hours <= 0) {
      return 'Còn $minutes phút !';
    }
    return 'Còn $hours giờ $minutes phút !';
  }
}

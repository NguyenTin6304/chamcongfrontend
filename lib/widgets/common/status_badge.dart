import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum StatusBadgeType { onTime, late, early, overtime, outOfRange, exception }

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.type, super.key});

  final StatusBadgeType type;

  String get _label {
    switch (type) {
      case StatusBadgeType.onTime:
        return 'Đúng giờ';
      case StatusBadgeType.late:
        return 'Vào muộn';
      case StatusBadgeType.early:
        return 'Vào sớm';
      case StatusBadgeType.overtime:
        return 'Tăng ca';
      case StatusBadgeType.outOfRange:
        return 'Ngoài vùng';
      case StatusBadgeType.exception:
        return 'Ngoại lệ';
    }
  }

  Color get _background {
    switch (type) {
      case StatusBadgeType.onTime:
        return AppColors.badgeBgOnTime;
      case StatusBadgeType.late:
        return AppColors.badgeBgLate;
      case StatusBadgeType.early:
        return AppColors.badgeBgEarly;
      case StatusBadgeType.overtime:
        return AppColors.badgeBgOvertime;
      case StatusBadgeType.outOfRange:
        return AppColors.badgeBgOutOfRange;
      case StatusBadgeType.exception:
        return AppColors.badgeBgException;
    }
  }

  Color get _foreground {
    switch (type) {
      case StatusBadgeType.onTime:
        return AppColors.badgeTextOnTime;
      case StatusBadgeType.late:
        return AppColors.badgeTextLate;
      case StatusBadgeType.early:
        return AppColors.badgeTextEarly;
      case StatusBadgeType.overtime:
        return AppColors.badgeTextOvertime;
      case StatusBadgeType.outOfRange:
        return AppColors.badgeTextOutOfRange;
      case StatusBadgeType.exception:
        return AppColors.badgeTextException;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

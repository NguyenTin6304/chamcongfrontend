import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum StatusBadgeType { onTime, late, early, overtime, outOfRange, exception }

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.type, super.key});

  final StatusBadgeType type;

  String get _label {
    switch (type) {
      case StatusBadgeType.onTime:
        return '\u0110\u00fang gi\u1edd';
      case StatusBadgeType.late:
        return 'V\u00e0o mu\u1ed9n';
      case StatusBadgeType.early:
        return '\u0110\u1ebfn s\u1edbm';
      case StatusBadgeType.overtime:
        return 'T\u0103ng ca';
      case StatusBadgeType.outOfRange:
        return 'Ngo\u00e0i v\u00f9ng';
      case StatusBadgeType.exception:
        return 'Ngo\u1ea1i l\u1ec7';
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

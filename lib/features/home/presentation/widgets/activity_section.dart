import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/utils/vn_date_utils.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';
import 'package:birdle/features/attendance/data/attendance_api.dart';

class ActivitySection extends StatelessWidget {
  const ActivitySection({super.key, required this.logs});

  final List<AttendanceLogItem> logs;

  @override
  Widget build(BuildContext context) {
    final sorted = [...logs]
      ..sort((a, b) {
        final ta = DateTime.tryParse(b.time) ?? DateTime(0);
        final tb = DateTime.tryParse(a.time) ?? DateTime(0);
        return ta.compareTo(tb);
      });
    final recent = sorted.take(3).toList();

    final firstDt = recent.isNotEmpty
        ? DateTime.tryParse(recent.first.time)?.toLocal()
        : null;
    final dateLabel = firstDt == null
        ? ''
        : '${VnDateUtils.weekdays[firstDt.weekday - 1]}, ${firstDt.day} tháng ${firstDt.month}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'SỰ KIỆN GẦN NHẤT',
                style: AppTextStyles.captionBold,
              ),
            ),
            if (dateLabel.isNotEmpty)
              Text(
                dateLabel,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (recent.isEmpty)
          Container(
            padding: AppSpacing.paddingAllLg,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardAll,
              boxShadow: AppShadows.card,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_available_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'Chưa có sự kiện hôm nay',
                  style: AppTextStyles.body,
                ),
              ],
            ),
          )
        else
          ...recent.map((log) => ActivityItem(log: log)),
      ],
    );
  }
}

class ActivityItem extends StatelessWidget {
  const ActivityItem({super.key, required this.log});

  final AttendanceLogItem log;

  @override
  Widget build(BuildContext context) {
    final isIn = log.type.toUpperCase() == 'IN';
    final dt = DateTime.tryParse(log.time)?.toLocal();
    final timeStr = dt == null ? '--:--' : DateFormat('HH:mm').format(dt);
    final amPm = dt == null ? '' : (dt.hour < 12 ? 'SA' : 'CH');
    final isSuccess = !log.isOutOfRange;

    final semanticDesc =
        '${isIn ? 'Điểm danh vào' : 'Điểm danh ra'} lúc $timeStr $amPm'
        '${log.matchedGeofence != null ? ', ${log.matchedGeofence}' : ''}'
        ', ${isSuccess ? 'thành công' : 'ngoài phạm vi'}';

    return Semantics(
      label: semanticDesc,
      child: Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: AppSpacing.paddingAllMd,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardAll,
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: AppSizes.iconBoxSize,
            height: AppSizes.iconBoxSize,
            decoration: BoxDecoration(
              color: isIn ? AppColors.primaryLight : AppColors.errorLight,
              borderRadius: AppRadius.iconBoxAll,
            ),
            child: Icon(
              isIn ? Icons.login : Icons.logout,
              size: AppSpacing.xl,
              color: isIn ? AppColors.primary : AppColors.error,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isIn ? 'Đã điểm danh vào' : 'Đã điểm danh ra',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  log.matchedGeofence ??
                      (isIn ? 'Bắt đầu ca làm' : 'Kết thúc ca làm'),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$timeStr $amPm',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isSuccess ? 'THÀNH CÔNG' : 'NGOÀI PHẠM VI',
                style: AppTextStyles.badgeLabel.copyWith(
                  color: isSuccess ? AppColors.success : AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

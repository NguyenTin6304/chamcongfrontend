import 'package:flutter/material.dart';

import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';
import 'package:birdle/widgets/common/notification_bell.dart';

class AdminTopbar extends StatelessWidget {
  const AdminTopbar({
    required this.title,
    required this.dateLabel,
    required this.searchController,
    required this.avatarText,
    required this.onReloadTap,
    required this.onAvatarTap,
    super.key,
  });

  final String title;
  final String dateLabel;
  final TextEditingController searchController;
  final String avatarText;
  final VoidCallback onReloadTap;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.headerTitle),
                Text(
                  dateLabel,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: 'Tải lại',
            onPressed: onReloadTap,
            icon: const Icon(Icons.refresh),
          ),
          const NotificationBell(),
          const SizedBox(width: AppSpacing.xs),
          InkWell(
            onTap: onAvatarTap,
            borderRadius: AppRadius.badgeAll,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.border,
              child: Text(
                avatarText,
                style: AppTextStyles.captionBold.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

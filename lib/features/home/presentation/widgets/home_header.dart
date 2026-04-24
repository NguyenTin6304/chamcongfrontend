import 'package:flutter/material.dart';

import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_text_styles.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/widgets/common/notification_bell.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.onNavigateToProfile});

  final VoidCallback? onNavigateToProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          const Icon(Icons.location_pin, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'Chấm Công',
            style: AppTextStyles.headerTitle.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          const NotificationBell(iconColor: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Semantics(
            button: true,
            label: 'Hồ sơ cá nhân',
            child: GestureDetector(
              onTap: onNavigateToProfile,
              child: const CircleAvatar(
                radius: AppSizes.headerAvatarRadius,
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.person, color: AppColors.primary, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

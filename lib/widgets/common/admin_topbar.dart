import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'notification_bell.dart';

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
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Tải lại',
            onPressed: onReloadTap,
            icon: const Icon(Icons.refresh),
          ),
          const NotificationBell(),
          const SizedBox(width: 4),
          InkWell(
            onTap: onAvatarTap,
            borderRadius: BorderRadius.circular(999),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.border,
              child: Text(
                avatarText,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

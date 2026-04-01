import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AdminTopbar extends StatelessWidget {
  const AdminTopbar({
    required this.title,
    required this.dateLabel,
    required this.searchController,
    required this.avatarText,
    required this.onAvatarTap,
    super.key,
  });

  final String title;
  final String dateLabel;
  final TextEditingController searchController;
  final String avatarText;
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
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                ),
                Text(
                  dateLabel,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 240,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Tìm kiếm',
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_outlined),
          ),
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

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AdminSidebarItem<T> {
  const AdminSidebarItem({
    required this.value,
    required this.icon,
    required this.label,
    this.badgeCount = 0,
    this.withDividerBefore = false,
  });

  final T value;
  final IconData icon;
  final String label;
  final int badgeCount;
  final bool withDividerBefore;
}

class AdminSidebar<T> extends StatelessWidget {
  const AdminSidebar({
    required this.items,
    required this.selected,
    required this.hovered,
    required this.displayName,
    required this.avatarText,
    required this.onTap,
    required this.onHoverChanged,
    super.key,
    this.roleLabel = '',
  });

  final List<AdminSidebarItem<T>> items;
  final T selected;
  final T? hovered;
  final String displayName;
  final String avatarText;
  final String roleLabel;
  final ValueChanged<T> onTap;
  final ValueChanged<T?> onHoverChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.sidebar,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chấm công',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Quản trị hệ thống',
                  style: TextStyle(fontSize: 11, color: AppColors.sidebarMuted),
                ),
                SizedBox(height: 32),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (_, index) {
                final item = items[index];
                final tile = _SidebarTile<T>(
                  item: item,
                  isActive: selected == item.value,
                  isHover: hovered == item.value,
                  onTap: () => onTap(item.value),
                  onHover: (v) => onHoverChanged(v ? item.value : null),
                );
                if (!item.withDividerBefore) return tile;
                return Column(
                  children: [
                    const Divider(color: AppColors.sidebarDivider, height: 1),
                    const SizedBox(height: 10),
                    tile,
                  ],
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemCount: items.length,
            ),
          ),
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.sidebarUserCard,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.sidebarAvatarBg,
                  child: Text(
                    avatarText,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        roleLabel,
                        style: const TextStyle(
                          color: AppColors.sidebarMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile<T> extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.isActive,
    required this.isHover,
    required this.onTap,
    required this.onHover,
  });

  final AdminSidebarItem<T> item;
  final bool isActive;
  final bool isHover;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;

  @override
  Widget build(BuildContext context) {
    final bg = isActive
        ? AppColors.primary
        : (isHover ? AppColors.sidebarHoverBg : Colors.transparent);
    final textColor = isActive
        ? Colors.white
        : (isHover ? AppColors.sidebarHoverText : AppColors.sidebarMuted);
    final iconColor = isActive ? Colors.white : AppColors.textMuted;

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 18, color: iconColor),
                const SizedBox(width: 10),
                Expanded(child: Text(item.label, style: TextStyle(color: textColor))),
                if (item.badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${item.badgeCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

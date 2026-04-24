import 'package:flutter/material.dart';

import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';

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

/// Sidebar with self-contained hover state.
/// Hover events never propagate to the parent — only [onTap] does.
class AdminSidebar<T> extends StatefulWidget {
  const AdminSidebar({
    required this.items,
    required this.selected,
    required this.displayName,
    required this.avatarText,
    required this.onTap,
    super.key,
    this.roleLabel = '',
  });

  final List<AdminSidebarItem<T>> items;
  final T selected;
  final String displayName;
  final String avatarText;
  final String roleLabel;
  final ValueChanged<T> onTap;

  @override
  State<AdminSidebar<T>> createState() => _AdminSidebarState<T>();
}

class _AdminSidebarState<T> extends State<AdminSidebar<T>> {
  T? _hovered;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.sidebar,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.lg,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chấm công',
                  style: AppTextStyles.headerTitle.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.surface,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Quản trị hệ thống',
                  style: TextStyle(fontSize: 11, color: AppColors.sidebarMuted),
                ),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              itemBuilder: (_, index) {
                final item = widget.items[index];
                final tile = _SidebarTile<T>(
                  item: item,
                  isActive: widget.selected == item.value,
                  isHover: _hovered == item.value,
                  onTap: () => widget.onTap(item.value),
                  onHover: (entered) {
                    setState(() {
                      _hovered = entered ? item.value : null;
                    });
                  },
                );
                if (!item.withDividerBefore) return tile;
                return Column(
                  children: [
                    const Divider(color: AppColors.sidebarDivider, height: 1),
                    const SizedBox(height: AppSpacing.md),
                    tile,
                  ],
                );
              },
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemCount: widget.items.length,
            ),
          ),
          Container(
            margin: const EdgeInsets.all(AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              color: AppColors.sidebarUserCard,
              borderRadius: AppRadius.iconBoxAll,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.sidebarAvatarBg,
                  child: Text(
                    widget.avatarText,
                    style: AppTextStyles.captionBold.copyWith(
                      color: AppColors.surface,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.chipText.copyWith(
                          color: AppColors.surface,
                        ),
                      ),
                      Text(
                        widget.roleLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.sidebarMuted,
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
        ? AppColors.surface
        : (isHover ? AppColors.sidebarHoverText : AppColors.sidebarMuted);
    final iconColor = isActive ? AppColors.surface : AppColors.textMuted;

    return MouseRegion(
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.iconBoxAll,
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: AppRadius.iconBoxAll,
            ),
            child: Row(
              children: [
                Icon(item.icon, size: 18, color: iconColor),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(item.label, style: TextStyle(color: textColor)),
                ),
                if (item.badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: AppRadius.badgeAll,
                    ),
                    child: Text(
                      '${item.badgeCount}',
                      style: AppTextStyles.captionBold.copyWith(
                        color: AppColors.surface,
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

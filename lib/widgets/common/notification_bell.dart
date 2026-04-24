import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:birdle/core/services/notification_store.dart';
import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, this.iconColor});

  /// Icon color — defaults to textPrimary.
  final Color? iconColor;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _link = LayerLink();
  OverlayEntry? _overlay;
  bool _isOpen = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    setState(() => _isOpen = true);
    // Cancel any pending clear so notifications don't vanish while reading.
    NotificationStore.cancelScheduledClear();
    // Remove badge + blue highlight.
    NotificationStore.markAllRead();

    _overlay = OverlayEntry(
      builder: (_) => _DropdownOverlay(
        link: _link,
        onClose: _close,
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _close() {
    _removeOverlay();
    if (mounted) setState(() => _isOpen = false);
    // Start 3-second countdown AFTER the panel closes, not while open.
    NotificationStore.scheduleClear();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: ValueListenableBuilder<List<AppNotification>>(
        valueListenable: NotificationStore.notifications,
        builder: (_, notifications, _) {
          final unread = NotificationStore.unreadCount;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Thông báo',
                onPressed: _toggle,
                icon: Icon(
                  _isOpen
                      ? Icons.notifications_active
                      : Icons.notifications_none_outlined,
                  color: widget.iconColor ?? AppColors.textPrimary,
                ),
              ),
              if (unread > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: IgnorePointer(
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17),
                      height: 17,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: AppRadius.badgeAll,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: AppTextStyles.mapOverlay.copyWith(
                          color: AppColors.surface,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Dropdown overlay ────────────────────────────────────────────────────────

class _DropdownOverlay extends StatelessWidget {
  const _DropdownOverlay({required this.link, required this.onClose});

  final LayerLink link;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full-screen tap-to-dismiss backdrop.
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onClose,
          child: const SizedBox.expand(),
        ),
        CompositedTransformFollower(
          link: link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 4),
          child: Material(
            elevation: 8,
            borderRadius: AppRadius.cardAll,
            shadowColor: const Color(0x42000000),
            child: _NotificationPanel(onClose: onClose),
          ),
        ),
      ],
    );
  }
}

// ── Notification panel ──────────────────────────────────────────────────────

class _NotificationPanel extends StatelessWidget {
  const _NotificationPanel({required this.onClose});

  final VoidCallback onClose;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return DateFormat('dd/MM HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AppNotification>>(
      valueListenable: NotificationStore.notifications,
      builder: (_, notifications, _) {
        return SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ─────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Thông báo',
                      style: AppTextStyles.bodyBold.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (notifications.isNotEmpty)
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: NotificationStore.clearAll,
                        child: Text(
                          'Xóa tất cả',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // ── Body ───────────────────────────────────────────────────
              if (notifications.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xxxl,
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.notifications_none,
                        size: 40,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Chưa có thông báo',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 0.5,
                      thickness: 0.5,
                      color: AppColors.border,
                    ),
                    itemBuilder: (_, i) => _NotificationItem(
                      item: notifications[i],
                      timeAgo: _timeAgo(notifications[i].receivedAt),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Single notification item ─────────────────────────────────────────────────

class _NotificationItem extends StatelessWidget {
  const _NotificationItem({required this.item, required this.timeAgo});

  final AppNotification item;
  final String timeAgo;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: item.isRead ? Colors.transparent : AppColors.primaryLight,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: item.isRead
                  ? AppColors.bgPage
                  : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: AppRadius.iconBoxAll,
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              size: 18,
              color: item.isRead ? AppColors.textMuted : AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight:
                        item.isRead ? FontWeight.w500 : FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (item.body.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.body,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    timeAgo,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!item.isRead)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.xs),
              child: CircleAvatar(
                radius: 4,
                backgroundColor: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

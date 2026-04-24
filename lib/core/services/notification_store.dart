import 'dart:async';

import 'package:flutter/foundation.dart';

class AppNotification {
  AppNotification({
    required this.title,
    required this.body,
    required this.receivedAt,
    this.isRead = false,
  });

  final String title;
  final String body;
  final DateTime receivedAt;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) => AppNotification(
        title: title,
        body: body,
        receivedAt: receivedAt,
        isRead: isRead ?? this.isRead,
      );
}

class NotificationStore {
  NotificationStore._();

  static final notifications = ValueNotifier<List<AppNotification>>([]);
  static Timer? _clearTimer;

  static int get unreadCount =>
      notifications.value.where((n) => !n.isRead).length;

  /// Add a new notification. Cancels any pending auto-clear so the new item
  /// is never immediately wiped.
  static void add(String title, String body) {
    _clearTimer?.cancel();
    _clearTimer = null;
    final n = AppNotification(
      title: title,
      body: body,
      receivedAt: DateTime.now(),
    );
    notifications.value = [n, ...notifications.value.take(49)];
  }

  /// Mark all notifications as read (removes badge + blue highlight).
  /// Does NOT start any timer — call [scheduleClear] separately when the
  /// panel closes.
  static void markAllRead() {
    if (unreadCount == 0) return;
    notifications.value = notifications.value
        .map((n) => n.isRead ? n : n.copyWith(isRead: true))
        .toList();
  }

  /// Start a countdown to clear all notifications [delay] after the panel
  /// is closed. Call when the panel closes.
  static void scheduleClear({
    Duration delay = const Duration(seconds: 3),
  }) {
    if (notifications.value.isEmpty) return;
    _clearTimer?.cancel();
    _clearTimer = Timer(delay, () {
      notifications.value = [];
      _clearTimer = null;
    });
  }

  /// Cancel a pending auto-clear. Call when the panel re-opens so
  /// notifications are not wiped while the user is looking at them.
  static void cancelScheduledClear() {
    _clearTimer?.cancel();
    _clearTimer = null;
  }

  /// Immediately clear all notifications (e.g. user taps "Xóa tất cả").
  static void clearAll() {
    _clearTimer?.cancel();
    _clearTimer = null;
    notifications.value = [];
  }
}

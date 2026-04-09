import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

String exceptionStatusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'PENDING_EMPLOYEE':
      return 'Chờ nhân viên giải trình';
    case 'PENDING_ADMIN':
      return 'Chờ admin xử lý';
    case 'APPROVED':
      return 'Đã duyệt';
    case 'REJECTED':
      return 'Từ chối';
    case 'EXPIRED':
      return 'Quá hạn';
    default:
      return status;
  }
}

({Color bg, Color text, Color border}) exceptionStatusPalette(
  String status, {
  bool active = true,
}) {
  if (!active) {
    return (
      bg: AppColors.bgPage,
      text: AppColors.textMuted,
      border: AppColors.border,
    );
  }
  switch (status.toUpperCase()) {
    case 'PENDING_EMPLOYEE':
      return (
        bg: AppColors.badgeBgLate,
        text: AppColors.badgeTextLate,
        border: AppColors.exceptionTabPendingBorder,
      );
    case 'PENDING_ADMIN':
      return (
        bg: AppColors.exceptionTabAllBg,
        text: AppColors.exceptionTabAllText,
        border: AppColors.exceptionTabAllBorder,
      );
    case 'APPROVED':
      return (
        bg: AppColors.badgeBgOnTime,
        text: AppColors.badgeTextOnTime,
        border: AppColors.exceptionTabApprovedBorder,
      );
    case 'REJECTED':
      return (
        bg: AppColors.badgeBgOutOfRange,
        text: AppColors.badgeTextOutOfRange,
        border: AppColors.exceptionTabRejectedBorder,
      );
    case 'EXPIRED':
      return (
        bg: AppColors.bgPage,
        text: AppColors.textMuted,
        border: AppColors.border,
      );
    default:
      return (
        bg: AppColors.bgPage,
        text: AppColors.textMuted,
        border: AppColors.border,
      );
  }
}

String exceptionTypeLabel(String type) {
  switch (type) {
    case 'SUSPECTED_LOCATION_SPOOF':
    case 'OUT_OF_RANGE':
      return 'Vị trí bất thường';
    case 'AUTO_CLOSED':
    case 'AUTO_CHECKOUT':
      return 'Tự động checkout';
    case 'MISSED_CHECKOUT':
    case 'FORGOT_CHECKOUT':
      return 'Quên checkout';
    case 'LARGE_TIME_DEVIATION':
      return 'Lệch thời gian lớn';
    case 'UNUSUAL_HOURS':
      return 'Giờ bất thường';
    default:
      return type;
  }
}

Color exceptionTypeColor(String type) {
  final upper = type.toUpperCase();
  if (upper.contains('LOCATION') ||
      upper.contains('SPOOF') ||
      upper.contains('RANGE')) {
    return AppColors.danger;
  }
  return AppColors.warning;
}

Color exceptionBorderColor(String type) {
  final upper = type.toUpperCase();
  if (upper.contains('LOCATION') ||
      upper.contains('SPOOF') ||
      upper.contains('RANGE')) {
    return AppColors.danger;
  }
  return AppColors.warning;
}

bool isOutsideLocationLabel(String label) {
  final normalized = label.trim().toLowerCase();
  return normalized.contains('ngoài') ||
      normalized.contains('outside') ||
      normalized.contains('out_of_range') ||
      normalized.contains('out of range');
}

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';

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

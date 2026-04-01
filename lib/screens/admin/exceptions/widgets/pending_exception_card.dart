import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';

class ExceptionModel {
  const ExceptionModel({
    required this.id,
    required this.employeeName,
    required this.employeeCode,
    required this.departmentName,
    required this.exceptionType,
    required this.status,
    required this.workDate,
    required this.checkInTime,
    required this.checkOutTime,
    required this.locationLabel,
    required this.reason,
    required this.reviewerName,
    required this.createdAt,
  });

  final int id;
  final String employeeName;
  final String employeeCode;
  final String departmentName;
  final String exceptionType;
  final String status;
  final DateTime? workDate;
  final String checkInTime;
  final String checkOutTime;
  final String locationLabel;
  final String reason;
  final String reviewerName;
  final DateTime? createdAt;
}

class PendingExceptionCard extends StatelessWidget {
  const PendingExceptionCard({
    required this.exception,
    required this.onApprove,
    required this.onReject,
    required this.onViewDetail,
    super.key,
    this.isProcessing = false,
  });

  final ExceptionModel exception;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewDetail;
  final bool isProcessing;

  bool get _isLocationType {
    final normalized = exception.exceptionType.toLowerCase();
    return normalized.contains('location') ||
        normalized.contains('gps') ||
        normalized.contains('range');
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return 'NA';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _timeAgo(DateTime? dateTime) {
    if (dateTime == null) {
      return '--';
    }
    final diff = DateTime.now().difference(dateTime.toLocal());
    if (diff.inMinutes < 1) {
      return 'Vừa xong';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes} phút trước';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours} giờ trước';
    }
    return '${diff.inDays} ngày trước';
  }

  String _labelForType(String raw) {
    final value = raw.trim();
    if (value.isEmpty || value == '-') {
      return 'Ngoại lệ';
    }
    final lower = value.toLowerCase();
    if (lower.contains('missed_checkout')) {
      return 'Quên checkout';
    }
    if (lower.contains('location') || lower.contains('gps')) {
      return 'Sai vị trí';
    }
    return value.replaceAll('_', ' ');
  }

  @override
  Widget build(BuildContext context) {
    final accent = _isLocationType ? AppColors.danger : AppColors.warning;
    final dateLabel = exception.workDate == null
        ? '--'
        : DateFormat('dd/MM/yyyy').format(exception.workDate!);

    return Container(
      width: 380,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 200,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.bgPage,
                      child: Text(
                        _initials(exception.employeeName),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exception.employeeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${exception.employeeCode} · ${exception.departmentName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _labelForType(exception.exceptionType),
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(exception.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.more_vert,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(label: 'Ngày', value: dateLabel),
                      _InfoChip(label: 'Giờ vào', value: exception.checkInTime),
                      _InfoChip(label: 'Giờ ra', value: exception.checkOutTime),
                      _InfoChip(label: 'Vị trí', value: exception.locationLabel),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isProcessing ? null : onViewDetail,
                      child: const Text('Xem chi tiết'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: isProcessing ? null : onReject,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.danger),
                        foregroundColor: AppColors.danger,
                      ),
                      child: isProcessing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Từ chối'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: isProcessing ? null : onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                      child: isProcessing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Phê duyệt'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 11,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

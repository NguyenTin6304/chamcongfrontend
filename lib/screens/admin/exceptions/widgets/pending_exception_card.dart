import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import 'exception_ui_helpers.dart';

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

  String _initials(String fullName) {
    final parts = fullName
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

  Color _avatarBg(String name) {
    final seeds = <Color>[
      AppColors.exceptionTabAllBg,
      AppColors.badgeBgOnTime,
      AppColors.badgeBgOvertime,
      AppColors.badgeBgLate,
    ];
    return seeds[name.hashCode.abs() % seeds.length];
  }

  String _timeAgo(DateTime? createdAt) {
    if (createdAt == null) {
      return '--';
    }
    final diff = DateTime.now().difference(createdAt.toLocal());
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

  @override
  Widget build(BuildContext context) {
    final typeColor = exceptionTypeColor(exception.exceptionType);
    final borderColor = exceptionBorderColor(exception.exceptionType);
    final isOutside = isOutsideLocationLabel(exception.locationLabel);
    final workDateText = exception.workDate == null
        ? '—'
        : DateFormat('dd/MM/yyyy').format(exception.workDate!.toLocal());
    final checkOut = exception.checkOutTime.trim().isEmpty ||
            exception.checkOutTime == '--'
        ? '—'
        : exception.checkOutTime;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(
          left: BorderSide(width: 4, color: borderColor),
          top: const BorderSide(width: 0.5, color: AppColors.border),
          right: const BorderSide(width: 0.5, color: AppColors.border),
          bottom: const BorderSide(width: 0.5, color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _avatarBg(exception.employeeName),
                child: Text(
                  _initials(exception.employeeName),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  exceptionTypeLabel(exception.exceptionType),
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _timeAgo(exception.createdAt),
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.more_vert, size: 16, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.exceptionCardMutedBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _DetailPair(
                        label: 'Ngày yêu cầu',
                        value: Text(workDateText, style: _valueStyle),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _DetailPair(
                        label: 'Giờ vào',
                        value: Text(exception.checkInTime, style: _valueStyle),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _DetailPair(
                        label: 'Giờ ra',
                        value: Text(
                          checkOut,
                          style: checkOut == '—'
                              ? _valueStyle.copyWith(color: AppColors.textMuted)
                              : _valueStyle,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _DetailPair(
                        label: 'Vị trí',
                        value: Row(
                          children: [
                            Icon(
                              isOutside
                                  ? Icons.location_off_outlined
                                  : Icons.location_on_outlined,
                              size: 14,
                              color: isOutside
                                  ? AppColors.danger
                                  : AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isOutside ? 'Ngoài vùng' : 'Trong vùng',
                              style: _valueStyle.copyWith(
                                color: isOutside
                                    ? AppColors.danger
                                    : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: isProcessing ? null : onViewDetail,
                child: const Text(
                  'Xem chi tiết',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: isProcessing ? null : onReject,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger),
                  foregroundColor: AppColors.danger,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
    );
  }
}

const TextStyle _valueStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: AppColors.textPrimary,
);

class _DetailPair extends StatelessWidget {
  const _DetailPair({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        value,
      ],
    );
  }
}


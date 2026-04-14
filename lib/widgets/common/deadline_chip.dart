import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';

class DeadlineChip extends StatefulWidget {
  const DeadlineChip({
    required this.deadline,
    super.key,
    this.compact = false,
    this.onTick,
  });

  final DateTime? deadline;
  final bool compact;
  final VoidCallback? onTick;

  @override
  State<DeadlineChip> createState() => _DeadlineChipState();
}

class _DeadlineChipState extends State<DeadlineChip> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant DeadlineChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.deadline == null) {
      return;
    }
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      widget.onTick?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final deadline = widget.deadline;
    final state = _deadlineState(deadline);
    final horizontal = widget.compact ? 8.0 : 10.0;
    final vertical = widget.compact ? 4.0 : 6.0;

    return Tooltip(
      message: deadline == null
          ? 'Chưa có hạn giải trình'
          : DateFormat('dd/MM/yyyy HH:mm').format(deadline.toLocal()),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontal,
          vertical: vertical,
        ),
        decoration: BoxDecoration(
          color: state.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: state.border, width: 0.5),
        ),
        child: Text(
          state.label,
          style: TextStyle(
            fontSize: widget.compact ? 11 : 12,
            fontWeight: FontWeight.w600,
            color: state.text,
          ),
        ),
      ),
    );
  }

  ({String label, Color bg, Color text, Color border}) _deadlineState(
    DateTime? deadline,
  ) {
    if (deadline == null) {
      return (
        label: '--',
        bg: AppColors.bgPage,
        text: AppColors.textMuted,
        border: AppColors.border,
      );
    }

    final remaining = deadline.toLocal().difference(DateTime.now());
    if (remaining.isNegative || remaining.inSeconds == 0) {
      return (
        label: 'Đã hết hạn',
        bg: AppColors.bgPage,
        text: AppColors.textMuted,
        border: AppColors.border,
      );
    }

    if (remaining > const Duration(hours: 48)) {
      return (
        label: _longLabel(remaining),
        bg: AppColors.badgeBgOnTime,
        text: AppColors.badgeTextOnTime,
        border: AppColors.exceptionTabApprovedBorder,
      );
    }

    if (remaining > const Duration(hours: 24)) {
      return (
        label: _hourLabel(remaining),
        bg: AppColors.badgeBgLate,
        text: AppColors.badgeTextLate,
        border: AppColors.exceptionTabPendingBorder,
      );
    }

    return (
      label: '${_hourMinuteLabel(remaining)} !',
      bg: AppColors.badgeBgOutOfRange,
      text: AppColors.badgeTextOutOfRange,
      border: AppColors.exceptionTabRejectedBorder,
    );
  }

  String _longLabel(Duration remaining) {
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    if (hours == 0) {
      return 'Còn $days ngày';
    }
    return 'Còn $days ngày $hours giờ';
  }

  String _hourLabel(Duration remaining) {
    return 'Còn ${remaining.inHours} giờ';
  }

  String _hourMinuteLabel(Duration remaining) {
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    if (hours <= 0) {
      return 'Còn $minutes phút';
    }
    return 'Còn $hours giờ $minutes phút';
  }
}

import 'package:flutter/material.dart';

import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';
import 'package:birdle/features/attendance/data/attendance_api.dart';

class CtaButton extends StatefulWidget {
  const CtaButton({
    super.key,
    required this.status,
    required this.isLoadingAction,
    required this.isEmployeeInactive,
    required this.employeeNotAssigned,
    required this.onCheckin,
    required this.onCheckout,
    this.isDesktop = false,
  });

  final AttendanceStatusResult? status;
  final bool isLoadingAction;
  final bool isEmployeeInactive;
  final bool employeeNotAssigned;
  final VoidCallback? onCheckin;
  final VoidCallback? onCheckout;
  final bool isDesktop;

  @override
  State<CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<CtaButton> {
  bool _isPressed = false;

  ({Color bg, String label, VoidCallback? tap, bool isDisabledStyle}) get _config {
    final canCheckin = widget.status?.canCheckin ?? false;
    final canCheckout = widget.status?.canCheckout ?? false;

    if (widget.isLoadingAction) {
      return (
        bg: canCheckout ? AppColors.error : AppColors.primary,
        label: '',
        tap: null,
        isDisabledStyle: false,
      );
    }
    if (widget.isEmployeeInactive) {
      return (
        bg: AppColors.errorLight,
        label: 'Tài khoản bị vô hiệu hoá',
        tap: null,
        isDisabledStyle: true,
      );
    }
    if (widget.employeeNotAssigned) {
      return (
        bg: AppColors.border,
        label: 'Chưa được gán nhân viên',
        tap: null,
        isDisabledStyle: false,
      );
    }
    if (canCheckin) {
      return (
        bg: AppColors.primary,
        label: 'Điểm danh vào →',
        tap: widget.onCheckin,
        isDisabledStyle: false,
      );
    }
    if (canCheckout) {
      return (
        bg: AppColors.error,
        label: 'Điểm danh ra →',
        tap: widget.onCheckout,
        isDisabledStyle: false,
      );
    }
    return (
      bg: AppColors.border,
      label: 'Điểm danh vào →',
      tap: null,
      isDisabledStyle: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config;

    final semanticLabel = widget.isLoadingAction
        ? 'Đang xử lý điểm danh'
        : cfg.isDisabledStyle
            ? 'Tài khoản bị vô hiệu hoá'
            : cfg.tap == null && widget.employeeNotAssigned
                ? 'Chưa được gán nhân viên, không thể điểm danh'
                : cfg.tap == null
                    ? 'Điểm danh vào — chờ trạng thái'
                    : cfg.label.replaceAll(' →', '');

    final button = Semantics(
      button: true,
      enabled: cfg.tap != null,
      label: semanticLabel,
      child: AnimatedScale(
        scale: (_isPressed && cfg.tap != null) ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        child: SizedBox(
          height: AppSizes.buttonHeight,
          child: Material(
            color: cfg.bg,
            borderRadius: AppRadius.buttonAll,
            child: InkWell(
              onTap: cfg.tap,
              onTapDown: cfg.tap != null
                  ? (_) => setState(() => _isPressed = true)
                  : null,
              onTapUp: cfg.tap != null
                  ? (_) => setState(() => _isPressed = false)
                  : null,
              onTapCancel: () => setState(() => _isPressed = false),
              borderRadius: AppRadius.buttonAll,
              child: Center(
                child: widget.isLoadingAction
                    ? const SizedBox(
                        width: AppSpacing.xxl,
                        height: AppSpacing.xxl,
                        child: CircularProgressIndicator(
                          color: AppColors.surface,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        cfg.label,
                        style: AppTextStyles.buttonLabel.copyWith(
                          color: cfg.isDisabledStyle
                              ? AppColors.error
                              : (cfg.tap != null
                                  ? AppColors.surface
                                  : AppColors.textSecondary),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.isDesktop) {
      return Center(
        child: SizedBox(width: AppSizes.desktopCtaMaxWidth, child: button),
      );
    }
    return SizedBox(width: double.infinity, child: button);
  }
}

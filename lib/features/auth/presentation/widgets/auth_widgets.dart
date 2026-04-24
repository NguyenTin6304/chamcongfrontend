import 'package:flutter/material.dart';

import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';

/// Branded logo + app name used in the login AppBar.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSizes.iconBoxSizeSm,
          height: AppSizes.iconBoxSizeSm,
          decoration: const BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: AppRadius.iconBoxAll,
          ),
          child: const Icon(Icons.location_pin, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Text('Chấm Công', style: AppTextStyles.headerTitle),

      ],
    );
  }
}

/// Error / info banner shared across all auth forms.
class AuthBanner extends StatelessWidget {
  const AuthBanner({super.key, required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final accent = isError ? AppColors.error : AppColors.primary;
    final bgColor = isError ? AppColors.errorLight : AppColors.primaryLight;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: AppSpacing.paddingAllMd,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.info_outline,
            size: 18,
            color: accent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Consistent [InputDecoration] for all auth form fields.
/// Uses design tokens — no raw [Colors] values.
InputDecoration authInputDecoration({
  required String label,
  required IconData icon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.surface,
    border: const OutlineInputBorder(borderRadius: AppRadius.cardAll),
    enabledBorder: const OutlineInputBorder(
      borderRadius: AppRadius.cardAll,
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: AppRadius.cardAll,
      borderSide: BorderSide(color: AppColors.primary, width: 1.6),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: AppRadius.cardAll,
      borderSide: BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: AppRadius.cardAll,
      borderSide: BorderSide(color: AppColors.error, width: 1.6),
    ),
  );
}

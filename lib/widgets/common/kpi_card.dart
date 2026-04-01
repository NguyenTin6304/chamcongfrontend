import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class KpiCard extends StatelessWidget {
  const KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    super.key,
    this.loading = false,
    this.subText,
    this.valueColor,
    this.subColor,
  });

  final String label;
  final String value;
  final bool loading;
  final String? subText;
  final Color? valueColor;
  final Color? subColor;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                    letterSpacing: 0.04,
                  ),
                ),
                const SizedBox(height: 8),
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: valueColor ?? AppColors.textPrimary,
                    ),
                  ),
                if (subText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subText!,
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                ],
              ],
            ),
          ),
          Icon(icon, size: 20, color: iconColor),
        ],
      ),
    );
  }
}

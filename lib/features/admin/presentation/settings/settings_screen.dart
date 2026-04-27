import 'package:flutter/material.dart';

import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';
import 'package:birdle/features/admin/presentation/settings/tabs/explanation_policy_settings_tab.dart';
import 'package:birdle/features/admin/presentation/settings/tabs/general_settings_tab.dart';
import 'package:birdle/features/admin/presentation/settings/tabs/rules_settings_tab.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int selectedTabIndex = 0;
  int? _hoveredIndex;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.settings_outlined, label: 'Chung'),
    (icon: Icons.person_outline, label: 'Tài khoản'),
    (icon: Icons.notifications_none_outlined, label: 'Thông báo'),
    (icon: Icons.access_time_outlined, label: 'Quy tắc chấm công'),
    (icon: Icons.timer_outlined, label: 'Chính sách giải trình'),
    (icon: Icons.lock_outline, label: 'Bảo mật'),
    (icon: Icons.email_outlined, label: 'Email & Tích hợp'),
    (icon: Icons.list_alt_outlined, label: 'Nhật ký hệ thống'),
    (icon: Icons.help_outline, label: 'Trợ giúp'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 220,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: AppRadius.cardAll,
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: ClipRRect(
              borderRadius: AppRadius.cardAll,
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final active = index == selectedTabIndex;
                  final hover = index == _hoveredIndex;
                  final showDivider = index == 8;

                  return Column(
                    children: [
                      if (showDivider)
                        const Divider(height: 1, color: AppColors.border),
                      MouseRegion(
                        onEnter: (_) => setState(() => _hoveredIndex = index),
                        onExit: (_) => setState(() => _hoveredIndex = null),
                        child: InkWell(
                          onTap: () => setState(() => selectedTabIndex = index),
                          child: SizedBox(
                            height: 44,
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 44,
                                  color: active
                                      ? AppColors.primary
                                      : Colors.transparent,
                                ),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    color: active
                                        ? AppColors.bgPage
                                        : (hover
                                              ? AppColors.background
                                              : Colors.transparent),
                                    child: Row(
                                      children: [
                                        Icon(
                                          item.icon,
                                          size: 16,
                                          color: active
                                              ? AppColors.primary
                                              : AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          item.label,
                                          style: AppTextStyles.chipText,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: AppRadius.cardAll,
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: IndexedStack(
              index: selectedTabIndex,
              children: const [
                GeneralSettingsTab(),
                _PlaceholderTab(),
                _PlaceholderTab(),
                RulesSettingsTab(),
                ExplanationPolicySettingsTab(),
                _PlaceholderTab(),
                _PlaceholderTab(),
                _PlaceholderTab(),
                _PlaceholderTab(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.construction_outlined, size: 48, color: AppColors.border),
          const SizedBox(height: 8),
          Text(
            'Tính năng đang phát triển',
            style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({
    required this.sidebar,
    required this.topbar,
    required this.body,
    super.key,
  });

  final Widget sidebar;
  final Widget topbar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Row(
        children: [
          sidebar,
          Expanded(
            child: Column(
              children: [
                topbar,
                Expanded(
                  child: Padding(padding: const EdgeInsets.all(24), child: body),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

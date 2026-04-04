import 'package:flutter/material.dart';

import '../admin_page.dart';

/// Single entry point for all admin routes.
/// Replaces the 6 thin per-section wrapper widgets.
class AdminShellPage extends StatelessWidget {
  const AdminShellPage({
    required this.email,
    this.initialSection,
    super.key,
  });

  final String email;
  final String? initialSection;

  @override
  Widget build(BuildContext context) {
    return AdminPage(email: email, initialSection: initialSection);
  }
}

import 'package:flutter/material.dart';

import '../admin_page.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context) {
    return AdminPage(email: email, initialSection: 'dashboard');
  }
}

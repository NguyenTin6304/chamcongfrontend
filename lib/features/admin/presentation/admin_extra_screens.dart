import 'package:flutter/material.dart';

import 'admin_page.dart';

class ExceptionsScreen extends StatelessWidget {
  const ExceptionsScreen({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context) {
    return AdminPage(email: email, initialSection: 'exceptions');
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context) {
    return AdminPage(email: email, initialSection: 'settings');
  }
}

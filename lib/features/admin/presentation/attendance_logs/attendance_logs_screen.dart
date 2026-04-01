import 'package:flutter/material.dart';

import '../admin_page.dart';

class AttendanceLogsScreen extends StatelessWidget {
  const AttendanceLogsScreen({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context) {
    return AdminPage(email: email, initialSection: 'attendance');
  }
}

import 'package:flutter/material.dart';

import '../admin_page.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({required this.email, super.key});

  final String email;

  @override
  Widget build(BuildContext context) {
    return AdminPage(email: email, initialSection: 'groups');
  }
}

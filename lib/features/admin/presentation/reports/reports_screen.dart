import 'package:flutter/material.dart';

import '../admin_page.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({required this.email, super.key});

  final String email;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AdminPage(email: widget.email, initialSection: 'reports');
  }
}

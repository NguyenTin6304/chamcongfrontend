import 'package:flutter/material.dart';

import '../../features/attendance/presentation/history_page.dart';
import '../../features/attendance/presentation/profile_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../theme/app_colors.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({
    required this.initialIndex,
    this.email = '',
    super.key,
  });

  final int initialIndex;
  final String email;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Trang chủ',
    ),
    NavigationDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history),
      label: 'Lịch sử',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Cá nhân',
    ),
  ];

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onTabSelected,
      destinations: _destinations,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bodies = [
      HomePageBody(onNavigate: _onTabSelected),
      HistoryPageBody(onNavigate: _onTabSelected),
      const ProfilePageBody(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _selectedIndex,
        children: bodies,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }
}

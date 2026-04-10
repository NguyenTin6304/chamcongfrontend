// ignore_for_file: unused_field

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/storage/token_storage.dart';
import '../../../../widgets/common/admin_sidebar.dart';
import '../../../../widgets/common/admin_topbar.dart';
import '../../data/admin_api.dart';
import '../../data/admin_data_cache.dart';
import '../admin_shell.dart';
import '../attendance_logs/attendance_logs_tab.dart';
import '../dashboard/dashboard_tab.dart';
import '../employees/employees_tab.dart';
import '../exceptions/exceptions_screen.dart' as admin_exceptions;
import '../geofences/geofences_tab.dart';
import '../groups/groups_tab.dart';
import '../reports/reports_tab.dart';
import '../settings/settings_screen.dart';

/// Single entry point for all admin routes.
/// Replaces the 6 thin per-section wrapper widgets.
class AdminShellPage extends StatefulWidget {
  const AdminShellPage({
    required this.email,
    this.initialSection,
    super.key,
  });

  final String email;
  final String? initialSection;

  @override
  State<AdminShellPage> createState() => _AdminShellPageState();
}

class _AdminShellPageState extends State<AdminShellPage> {
  final _tokenStorage = TokenStorage();
  final _adminApi = const AdminApi();
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  String? _token;
  bool _loadingExceptions = false;
  List<AttendanceExceptionItem> _exceptions = const [];
  final String _exceptionTypeFilter = 'SUSPECTED_LOCATION_SPOOF';
  final String _exceptionStatusFilter = 'OPEN';
  final Set<int> _updatingExceptionIds = {};
  _AdminShellNav _activeNav = _AdminShellNav.dashboard;
  final Set<_AdminShellNav> _tabsLoaded = {};
  String? _error;
  String? _info;

  bool get _isAnyLoading =>
      _loadingExceptions || _updatingExceptionIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _activeNav = _initialNavFromSection(widget.initialSection);
    AdminDataCache.instance.sessionExpired.addListener(_onSessionExpired);
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant AdminShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.email == widget.email &&
        oldWidget.initialSection == widget.initialSection) {
      return;
    }
    AdminDataCache.instance.invalidate();
    _tabsLoaded.clear();
    _activeNav = _initialNavFromSection(widget.initialSection);
    _bootstrap();
  }

  _AdminShellNav _initialNavFromSection(String? section) {
    switch (section) {
      case 'attendance':
      case 'logs':
        return _AdminShellNav.logs;
      case 'employees':
        return _AdminShellNav.employees;
      case 'groups':
        return _AdminShellNav.groups;
      case 'geofences':
        return _AdminShellNav.geofences;
      case 'reports':
        return _AdminShellNav.reports;
      case 'exceptions':
        return _AdminShellNav.exceptions;
      case 'settings':
        return _AdminShellNav.settings;
      case 'dashboard':
      default:
        return _AdminShellNav.dashboard;
    }
  }

  @override
  void dispose() {
    AdminDataCache.instance.sessionExpired.removeListener(_onSessionExpired);
    AdminDataCache.instance.invalidate();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSessionExpired() {
    if (!AdminDataCache.instance.sessionExpired.value) return;
    AdminDataCache.instance.sessionExpired.value = false;
    _handleUnauthorized();
  }

  Future<void> _handleUnauthorized() async {
    await _tokenStorage.clearToken();
    AdminDataCache.instance.invalidate();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (!mounted) {
      return;
    }

    if (token == null || token.isEmpty) {
      await _handleUnauthorized();
      return;
    }

    setState(() {
      _token = token;
    });

    if (_activeNav == _AdminShellNav.exceptions) {
      await _loadTabIfNeeded(_activeNav);
      return;
    }

    await Future.wait<void>([
      _loadExceptions(),
      _loadTabIfNeeded(_activeNav),
    ]);
  }

  Future<void> _refreshAll() async {
    _tabsLoaded.clear();
    AdminDataCache.instance.invalidate();
    if (_activeNav == _AdminShellNav.exceptions) {
      await _loadTabIfNeeded(_activeNav);
      return;
    }

    await Future.wait<void>([
      _loadExceptions(),
      _loadTabIfNeeded(_activeNav),
    ]);
  }

  Future<void> _logout() async {
    try {
      await _tokenStorage.clearToken();
      AdminDataCache.instance.invalidate();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (error) {
      _showSnack('Đăng xuất thất bại: $error');
    }
  }

  void _showSnack(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _vietnameseDateLabel() {
    const weekdays = <int, String>{
      DateTime.monday: 'Thứ hai',
      DateTime.tuesday: 'Thứ ba',
      DateTime.wednesday: 'Thứ tư',
      DateTime.thursday: 'Thứ năm',
      DateTime.friday: 'Thứ sáu',
      DateTime.saturday: 'Thứ bảy',
      DateTime.sunday: 'Chủ nhật',
    };
    final now = DateTime.now();
    final day = weekdays[now.weekday] ?? '';
    final date = DateFormat('dd/MM/yyyy').format(now);
    return '$day, $date';
  }

  String _displayNameFromEmail() {
    final trimmed = widget.email.trim();
    if (trimmed.isEmpty) {
      return 'Quản trị viên';
    }
    final prefix = trimmed.split('@').first.trim();
    if (prefix.isEmpty) {
      return 'Quản trị viên';
    }
    return prefix;
  }

  String _pageTitleForNav(_AdminShellNav nav) {
    switch (nav) {
      case _AdminShellNav.dashboard:
        return 'Bảng điều khiển';
      case _AdminShellNav.logs:
        return 'Nhật ký chấm công';
      case _AdminShellNav.employees:
        return 'Nhân viên';
      case _AdminShellNav.groups:
        return 'Nhóm';
      case _AdminShellNav.geofences:
        return 'Vùng địa lý';
      case _AdminShellNav.reports:
        return 'Báo cáo';
      case _AdminShellNav.exceptions:
        return 'Ngoại lệ';
      case _AdminShellNav.settings:
        return 'Cài đặt';
    }
  }

  List<AdminSidebarItem<_AdminShellNav>> _shellNavItems() {
    final pending = _exceptions.where((e) => e.status == 'OPEN').length;
    return [
      const AdminSidebarItem<_AdminShellNav>(
        value: _AdminShellNav.dashboard,
        icon: Icons.dashboard_outlined,
        label: 'Bảng điều khiển',
      ),
      const AdminSidebarItem<_AdminShellNav>(
        value: _AdminShellNav.logs,
        icon: Icons.receipt_long_outlined,
        label: 'Nhật ký chấm công',
      ),
      const AdminSidebarItem<_AdminShellNav>(
        value: _AdminShellNav.employees,
        icon: Icons.people_outline,
        label: 'Nhân viên',
      ),
      const AdminSidebarItem<_AdminShellNav>(
        value: _AdminShellNav.groups,
        icon: Icons.groups_2_outlined,
        label: 'Nhóm',
      ),
      const AdminSidebarItem<_AdminShellNav>(
        value: _AdminShellNav.geofences,
        icon: Icons.map_outlined,
        label: 'Vùng địa lý',
      ),
      const AdminSidebarItem<_AdminShellNav>(
        value: _AdminShellNav.reports,
        icon: Icons.bar_chart_outlined,
        label: 'Báo cáo',
      ),
      AdminSidebarItem<_AdminShellNav>(
        value: _AdminShellNav.exceptions,
        icon: Icons.error_outline,
        label: 'Ngoại lệ',
        badgeCount: pending,
      ),
      const AdminSidebarItem<_AdminShellNav>(
        value: _AdminShellNav.settings,
        icon: Icons.settings_outlined,
        label: 'Cài đặt',
        withDividerBefore: true,
      ),
    ];
  }

  void _onShellNavTap(_AdminShellNav nav) {
    _switchNav(nav);
  }

  Future<void> _switchNav(_AdminShellNav nav) async {
    if (_activeNav != nav) {
      setState(() {
        _activeNav = nav;
      });
    }
    await _loadTabIfNeeded(nav);
  }

  Future<void> _loadTabIfNeeded(_AdminShellNav nav) async {
    if (nav == _AdminShellNav.exceptions) {
      await _loadTabData(nav);
      return;
    }
    if (_tabsLoaded.contains(nav)) {
      return;
    }
    _tabsLoaded.add(nav);
    await _loadTabData(nav);
  }

  Future<void> _loadTabData(_AdminShellNav nav) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }

    switch (nav) {
      case _AdminShellNav.dashboard:
      case _AdminShellNav.logs:
      case _AdminShellNav.employees:
      case _AdminShellNav.groups:
      case _AdminShellNav.geofences:
      case _AdminShellNav.reports:
      case _AdminShellNav.settings:
        // SettingsScreen and RulesSettingsTab manage rule loading/saving locally.
        break;
      case _AdminShellNav.exceptions:
        // Shell keeps the lightweight badge state; detailed actions stay in
        // ExceptionsScreen.
        await _loadExceptions();
    }
  }

  Future<void> _loadExceptions() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _loadingExceptions = true;
      _error = null;
    });

    try {
      final items = await _adminApi.listAttendanceExceptions(
        token: token,
        exceptionType: _exceptionTypeFilter,
        statusFilter: _exceptionStatusFilter,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _exceptions = items;
      });
    } on UnauthorizedException {
      await _handleUnauthorized();
      return;
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Tải danh sách exception thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingExceptions = false;
        });
      }
    }
  }

  Widget _buildSidebar() {
    final name = _displayNameFromEmail();
    final avatarText = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return AdminSidebar<_AdminShellNav>(
      items: _shellNavItems(),
      selected: _activeNav,
      displayName: name,
      avatarText: avatarText,
      roleLabel: 'Quản trị viên',
      onTap: _onShellNavTap,
    );
  }

  Widget _buildTopbar() {
    final name = _displayNameFromEmail();
    final avatarText = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return AdminTopbar(
      title: _pageTitleForNav(_activeNav),
      dateLabel: _vietnameseDateLabel(),
      searchController: _searchController,
      avatarText: avatarText,
      onReloadTap: _refreshAll,
      onAvatarTap: _logout,
    );
  }

  Widget _buildContentByNav() {
    switch (_activeNav) {
      case _AdminShellNav.dashboard:
        return DashboardTab(
          onNavigateTo: (section) => _switchNav(_initialNavFromSection(section)),
        );
      case _AdminShellNav.logs:
        return const AttendanceLogsTab();
      case _AdminShellNav.employees:
        return const EmployeesTab();
      case _AdminShellNav.groups:
        return GroupsTab(
          onNavigateTo: (section) => _switchNav(_initialNavFromSection(section)),
        );
      case _AdminShellNav.geofences:
        return GeofencesTab(
          onNavigateTo: (section) => _switchNav(_initialNavFromSection(section)),
        );
      case _AdminShellNav.reports:
        return const ReportsTab();
      case _AdminShellNav.exceptions:
        return const admin_exceptions.ExceptionsScreen();
      case _AdminShellNav.settings:
        return SizedBox(
          height: MediaQuery.of(context).size.height - 108,
          child: const SettingsScreen(),
        );
    }
  }

  Widget _buildBanner({required String text, required bool isError}) {
    final color = isError ? Colors.red : Colors.blue;
    final icon = isError ? Icons.error_outline : Icons.info_outline;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      sidebar: _buildSidebar(),
      topbar: _buildTopbar(),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshAll,
            notificationPredicate: (_) => !kIsWeb,
            child: ListView(
              controller: _scrollController,
              primary: false,
              physics: const ClampingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.zero,
              children: [
                if (_error != null) _buildBanner(text: _error!, isError: true),
                if (_info != null) _buildBanner(text: _info!, isError: false),
                _buildContentByNav(),
              ],
            ),
          ),
          if (_isAnyLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}

enum _AdminShellNav {
  dashboard,
  logs,
  employees,
  groups,
  geofences,
  reports,
  exceptions,
  settings,
}

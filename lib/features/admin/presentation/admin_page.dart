import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'dart:math' as math;

import '../../../core/config/app_config.dart';
import '../../../core/download/file_downloader.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../widgets/common/admin_sidebar.dart';
import '../../../widgets/common/admin_topbar.dart';
import '../../../widgets/common/kpi_card.dart';
import '../../../widgets/common/status_badge.dart';
import '../data/admin_api.dart';
import 'admin_shell.dart';
import 'widgets/admin_location_picker.dart';
import 'exceptions/exceptions_screen.dart' as admin_exceptions;
import 'settings/settings_screen.dart';
import 'reports/reports_tab.dart';
part 'attendance_logs/widgets/attendance_detail_modal.dart';
part 'attendance_logs/widgets/attendance_filter_bar.dart';
part 'attendance_logs/widgets/attendance_stat_cards.dart';
part 'attendance_logs/widgets/attendance_table.dart';
part 'employees/widgets/employee_edit_panel.dart';
part 'employees/widgets/employee_table.dart';
part 'groups/widgets/group_card.dart';
part 'groups/widgets/group_card_grid.dart';
part 'groups/widgets/group_create_panel.dart';
part 'groups/widgets/unassigned_panel.dart';
part 'geofences/widgets/geofence_config_form.dart';
part 'geofences/widgets/geofence_list.dart';
part 'geofences/widgets/geofence_map.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({required this.email, this.initialSection, super.key});

  final String email;
  final String? initialSection;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _tokenStorage = TokenStorage();
  final _adminApi = const AdminApi();
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _scrollController = ScrollController();

  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _radiusController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _graceMinutesController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _checkoutGraceMinutesController = TextEditingController();
  final _cutoffMinutesController = TextEditingController();

  final _employeeCodeController = TextEditingController();
  final _employeeNameController = TextEditingController();
  final _searchController = TextEditingController();
  final _logsSearchController = TextEditingController();
  final _employeesSearchController = TextEditingController();
  final _groupsSearchController = TextEditingController();
  final _geofenceSearchController = TextEditingController();
  final _zoneNameController = TextEditingController();
  final _zoneLatController = TextEditingController();
  final _zoneLngController = TextEditingController();
  final _zoneRadiusController = TextEditingController();
  final _zoneAddressController = TextEditingController();
  final _zoneStartTimeController = TextEditingController();
  final _zoneEndTimeController = TextEditingController();
  final _zoneOvertimeStartController = TextEditingController();
  final MapController _geofenceMapController = MapController();

  final Set<int> _assigningEmployeeIds = {};
  final Set<int> _deletingEmployeeIds = {};
  final Map<int, int?> _selectedUserByEmployee = {};
  final _dashboardSectionKey = GlobalKey();
  final _logsSectionKey = GlobalKey();
  final _employeesSectionKey = GlobalKey();
  final _groupsSectionKey = GlobalKey();
  final _exceptionsSectionKey = GlobalKey();
  final _settingsSectionKey = GlobalKey();

  String? _token;

  bool _loadingRule = false;
  bool _savingRule = false;
  bool _loadingEmployees = false;
  bool _loadingUsers = false;
  bool _creatingEmployee = false;
  bool _downloadingReport = false;
  bool _loadingExceptions = false;
  bool _loadingDashboardSummary = false;
  bool _loadingDashboardLogs = false;
  bool _loadingDashboardWeekly = false;
  bool _weeklyError = false;
  bool _loadingDashboardGeofences = false;
  bool _loadingDashboardExceptions = false;
  bool _loadingDashboardGroups = false;
  bool _loadingGroupGeofenceCards = false;
  bool _savingGroup = false;
  bool _deletingGroup = false;
  bool _searchingGeofencePlaces = false;
  bool _reversingGeofenceAddress = false;
  bool _savingGeofenceConfig = false;
  bool _deletingGeofenceConfig = false;
  bool _exportingDashboardCsv = false;

  ActiveRuleResult? _activeRule;
  String? _ruleLocationAddress;
  List<EmployeeLite> _employees = const [];
  List<UserLite> _users = const [];
  List<AttendanceExceptionItem> _exceptions = const [];
  DashboardSummaryResult? _dashboardSummary;
  List<DashboardAttendanceLogItem> _dashboardLogs = const [];
  List<DashboardWeeklyTrendItem> _dashboardWeekly = const [];
  List<DashboardGeofenceItem> _dashboardGeofences = const [];
  List<DashboardExceptionItem> _dashboardExceptions = const [];
  List<GroupLite> _dashboardGroups = const [];

  int? _newEmployeeUserId;
  int? _expandedEmployeeId;
  DateTime? _reportFromDate;
  DateTime? _reportToDate;
  int? _reportEmployeeId;
  bool _reportIncludeEmpty = false;
  final DateTime _dashboardDate = DateTime.now();
  int? _dashboardGroupId;
  String _dashboardStatus = 'all';
  DateTime _logsFromDate = DateTime.now();
  DateTime _logsToDate = DateTime.now();
  String _logsSearch = '';
  int _logsPage = 1;
  int _logsPageSize = 10;
  int? _employeesGroupId;
  String _employeesStatus = 'all';
  // Page + pageSize are UI-only — backed by a ValueNotifier so pagination
  // clicks only rebuild the table subtree, not the entire AdminPage.
  final _employeesPaginationNotifier =
      ValueNotifier<({int page, int pageSize})>((page: 1, pageSize: 10));
  int get _employeesPage => _employeesPaginationNotifier.value.page;
  int get _employeesPageSize => _employeesPaginationNotifier.value.pageSize;
  String _groupsSearch = '';
  String _groupsStatus = 'all';
  final Map<int, List<GroupGeofenceLite>> _groupGeofencesByGroupId = {};
  DashboardGeofenceItem? _selectedGeofence;
  LatLng? _newGeofencePoint;
  final _geofenceZoomNotifier = ValueNotifier<double>(14);
  List<GeoPlaceSuggestion> _geofencePlaceSuggestions = const [];
  bool _zoneOvertimeEnabled = false;
  bool _zoneActive = true;
  final Set<int> _zoneAssignedGroupIds = {};

  String _exceptionTypeFilter = 'SUSPECTED_LOCATION_SPOOF';
  String? _exceptionStatusFilter = 'OPEN';
  final Set<int> _updatingExceptionIds = {};
  _AdminShellNav _activeNav = _AdminShellNav.dashboard;
  final Set<_AdminShellNav> _tabsLoaded = {};
  int _logsServerTotal = 0;
  final Set<int> _dashboardUpdatingExceptionIds = {};

  // ── Memoisation caches ────────────────────────────────────────────────────
  // _employeesView
  List<EmployeeLite>? _cachedEmployeesView;
  List<EmployeeLite>? _cachedEmployeesListRef;
  String _cachedEmployeesFilterKey = '';
  // _groupsView
  List<GroupLite>? _cachedGroupsView;
  List<GroupLite>? _cachedGroupsListRef;
  String _cachedGroupsFilterKey = '';
  // geofence circles/markers
  List<CircleMarker>? _cachedGeofenceCircles;
  List<Marker>? _cachedGeofenceMarkers;
  List<DashboardGeofenceItem>? _cachedGeofenceListRef;
  int? _cachedGeofenceSelectedId;
  // ─────────────────────────────────────────────────────────────────────────

  String? _error;
  String? _info;

  bool get _isAnyLoading =>
      _loadingRule ||
      _savingRule ||
      _loadingEmployees ||
      _loadingUsers ||
      _creatingEmployee ||
      _downloadingReport ||
      _loadingExceptions ||
      _loadingDashboardSummary ||
      _loadingDashboardLogs ||
      _loadingDashboardWeekly ||
      _loadingDashboardGeofences ||
      _loadingDashboardExceptions ||
      _loadingDashboardGroups ||
      _loadingGroupGeofenceCards ||
      _savingGroup ||
      _deletingGroup ||
      _savingGeofenceConfig ||
      _deletingGeofenceConfig ||
      _exportingDashboardCsv ||
      _assigningEmployeeIds.isNotEmpty ||
      _deletingEmployeeIds.isNotEmpty ||
      _updatingExceptionIds.isNotEmpty ||
      _dashboardUpdatingExceptionIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _activeNav = _initialNavFromSection(widget.initialSection);
    _resetGroupsFiltersToDefaults();
    _startTimeController.text = '08:00';
    _graceMinutesController.text = '30';
    _endTimeController.text = '17:30';
    _checkoutGraceMinutesController.text = '0';
    _cutoffMinutesController.text = '240';
    _zoneRadiusController.text = '200';
    _zoneStartTimeController.text = '08:00';
    _zoneEndTimeController.text = '17:30';
    _zoneOvertimeStartController.text = '18:00';
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

  void _resetGroupsFiltersToDefaults() {
    _groupsSearch = '';
    _groupsStatus = 'all';
    _groupsSearchController.text = '';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _radiusController.dispose();
    _startTimeController.dispose();
    _graceMinutesController.dispose();
    _endTimeController.dispose();
    _checkoutGraceMinutesController.dispose();
    _cutoffMinutesController.dispose();
    _employeeCodeController.dispose();
    _employeeNameController.dispose();
    _searchController.dispose();
    _logsSearchController.dispose();
    _employeesSearchController.dispose();
    _groupsSearchController.dispose();
    _geofenceSearchController.dispose();
    _zoneNameController.dispose();
    _zoneLatController.dispose();
    _zoneLngController.dispose();
    _zoneRadiusController.dispose();
    _zoneAddressController.dispose();
    _zoneStartTimeController.dispose();
    _zoneEndTimeController.dispose();
    _zoneOvertimeStartController.dispose();
    _geofenceZoomNotifier.dispose();
    _employeesPaginationNotifier.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (!mounted) {
      return;
    }

    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Thiếu token đăng nhập. Hãy đăng nhập lại.';
      });
      return;
    }

    setState(() {
      _token = token;
    });

    // Load shared data needed across all tabs, then initial tab.
    await Future.wait([_loadUsers(), _loadDashboardGroups()]);
    if (!mounted) return;
    await _loadTabIfNeeded(_activeNav);
  }

  Future<void> _refreshAll() async {
    // Clear per-tab cache so the current tab reloads fresh.
    _tabsLoaded.clear();
    await Future.wait([_loadUsers(), _loadDashboardGroups()]);
    if (!mounted) return;
    await _loadTabIfNeeded(_activeNav);
  }

  Future<void> _loadActiveRule() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _loadingRule = true;
      _error = null;
      _info = null;
    });

    try {
      final rule = await _adminApi.getActiveRule(token);
      if (!mounted) {
        return;
      }

      setState(() {
        _activeRule = rule;
        if (rule != null) {
          _latController.text = rule.latitude.toStringAsFixed(6);
          _lngController.text = rule.longitude.toStringAsFixed(6);
          _ruleLocationAddress =
              'lat=${rule.latitude.toStringAsFixed(6)}, lng=${rule.longitude.toStringAsFixed(6)}';
          _radiusController.text = rule.radiusM.toString();
          _startTimeController.text = (rule.startTime ?? '08:00');
          _graceMinutesController.text = (rule.graceMinutes ?? 30).toString();
          _endTimeController.text = (rule.endTime ?? '17:30');
          _checkoutGraceMinutesController.text =
              (rule.checkoutGraceMinutes ?? 0).toString();
          _cutoffMinutesController.text = (rule.crossDayCutoffMinutes ?? 240)
              .toString();
        } else {
          _latController.clear();
          _lngController.clear();
          _ruleLocationAddress = null;
          _startTimeController.text = '08:00';
          _graceMinutesController.text = '30';
          _endTimeController.text = '17:30';
          _checkoutGraceMinutesController.text = '0';
          _cutoffMinutesController.text = '240';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Tải rule thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingRule = false;
        });
      }
    }
  }

  bool _isValidCoordinate(double value, {required bool isLatitude}) {
    if (isLatitude) {
      return value >= -90 && value <= 90;
    }
    return value >= -180 && value <= 180;
  }

  bool get _hasValidRuleCoordinates {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (lat == null || lng == null) {
      return false;
    }
    return _isValidCoordinate(lat, isLatitude: true) &&
        _isValidCoordinate(lng, isLatitude: false);
  }

  void _onRuleLocationChanged(LocationPickerValue value) {
    if (!mounted) {
      return;
    }
    setState(() {
      _ruleLocationAddress = value.displayName;
      if (!value.hasValidCoordinates ||
          value.latitude == null ||
          value.longitude == null) {
        _latController.clear();
        _lngController.clear();
        return;
      }
      _latController.text = value.latitude!.toStringAsFixed(6);
      _lngController.text = value.longitude!.toStringAsFixed(6);
    });
  }

  Future<void> _loadUsers() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _loadingUsers = true;
      _error = null;
    });

    try {
      final users = await _adminApi.listUsers(token);
      if (!mounted) {
        return;
      }

      setState(() {
        _users = users;
        if (_newEmployeeUserId != null &&
            !_users.any((u) => u.id == _newEmployeeUserId)) {
          _newEmployeeUserId = null;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Tải danh sách user thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingUsers = false;
        });
      }
    }
  }

  void _syncSelectedUsers(List<EmployeeLite> employees) {
    final ids = employees.map((e) => e.id).toSet();
    final removed = _selectedUserByEmployee.keys
        .where((id) => !ids.contains(id))
        .toList();
    for (final id in removed) {
      _selectedUserByEmployee.remove(id);
    }

    for (final emp in employees) {
      _selectedUserByEmployee[emp.id] = emp.userId;
    }
  }

  Future<void> _loadEmployees({
    String? query,
    int? groupId,
    String? status,
  }) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _loadingEmployees = true;
      _error = null;
    });

    try {
      final employees = await _adminApi.listEmployees(
        token,
        query: query,
        groupId: groupId,
        status: status,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _employees = employees;
        _syncSelectedUsers(employees);
        if (_reportEmployeeId != null &&
            !_employees.any((e) => e.id == _reportEmployeeId)) {
          _reportEmployeeId = null;
        }
        if (_expandedEmployeeId != null &&
            !_employees.any((e) => e.id == _expandedEmployeeId)) {
          _expandedEmployeeId = null;
        }
      });
      // Clamp page after setState so _employeesTotalPages reads fresh data.
      final pages = _employeesTotalPages;
      if (_employeesPage > pages) {
        _employeesPaginationNotifier.value = (
          page: pages,
          pageSize: _employeesPageSize,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Không thể tải danh sách nhân viên.';
      });
      _showSnack('Không thể tải danh sách nhân viên.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingEmployees = false;
        });
      }
    }
  }

  Future<void> _saveRule() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Thiếu token đăng nhập. Hãy đăng nhập lại.';
      });
      return;
    }

    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final radius = int.tryParse(_radiusController.text.trim());
    final startTimeRaw = _startTimeController.text.trim();
    final graceMinutes = int.tryParse(_graceMinutesController.text.trim());
    final endTimeRaw = _endTimeController.text.trim();
    final checkoutGraceMinutes = int.tryParse(
      _checkoutGraceMinutesController.text.trim(),
    );
    final cutoffMinutes = int.tryParse(_cutoffMinutesController.text.trim());

    final startMatch = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(startTimeRaw);
    final startHour = startMatch == null
        ? null
        : int.tryParse(startMatch.group(1)!);
    final startMinute = startMatch == null
        ? null
        : int.tryParse(startMatch.group(2)!);
    final validStartTime =
        startHour != null &&
        startMinute != null &&
        startHour >= 0 &&
        startHour <= 23 &&
        startMinute >= 0 &&
        startMinute <= 59;

    final endMatch = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(endTimeRaw);
    final endHour = endMatch == null ? null : int.tryParse(endMatch.group(1)!);
    final endMinute = endMatch == null
        ? null
        : int.tryParse(endMatch.group(2)!);
    final validEndTime =
        endHour != null &&
        endMinute != null &&
        endHour >= 0 &&
        endHour <= 23 &&
        endMinute >= 0 &&
        endMinute <= 59;

    if (lat == null ||
        lng == null ||
        !_isValidCoordinate(lat, isLatitude: true) ||
        !_isValidCoordinate(lng, isLatitude: false) ||
        radius == null ||
        radius <= 0 ||
        !validStartTime ||
        graceMinutes == null ||
        graceMinutes < 0 ||
        !validEndTime ||
        checkoutGraceMinutes == null ||
        checkoutGraceMinutes < 0 ||
        cutoffMinutes == null ||
        cutoffMinutes < 0 ||
        cutoffMinutes > 720) {
      setState(() {
        _error =
            'Dữ liệu rule không hợp lệ. Kiểm tra lat/lng/radius/start_time/end_time (HH:mm), grace và cutoff (0-720 phút).';
      });
      return;
    }

    setState(() {
      _savingRule = true;
      _error = null;
      _info = null;
    });

    try {
      final updated = await _adminApi.updateActiveRule(
        token: token,
        latitude: lat,
        longitude: lng,
        radius: radius,
        startTime: startTimeRaw,
        graceMinutes: graceMinutes,
        endTime: endTimeRaw,
        checkoutGraceMinutes: checkoutGraceMinutes,
        crossDayCutoffMinutes: cutoffMinutes,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _activeRule = updated;
        _latController.text = updated.latitude.toStringAsFixed(6);
        _lngController.text = updated.longitude.toStringAsFixed(6);
        _radiusController.text = updated.radiusM.toString();
        _startTimeController.text = updated.startTime ?? startTimeRaw;
        _graceMinutesController.text = (updated.graceMinutes ?? graceMinutes)
            .toString();
        _endTimeController.text = updated.endTime ?? endTimeRaw;
        _checkoutGraceMinutesController.text =
            (updated.checkoutGraceMinutes ?? checkoutGraceMinutes).toString();
        _cutoffMinutesController.text =
            (updated.crossDayCutoffMinutes ?? cutoffMinutes).toString();
        _info = 'Đã cập nhật rule thành công.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Cập nhật rule thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingRule = false;
        });
      }
    }
  }

  List<UserLite> _unassignedUsers() {
    final assignedIds = _employees
        .map((e) => e.userId)
        .whereType<int>()
        .toSet();
    return _users
        .where((u) => !assignedIds.contains(u.id))
        .toList(growable: false);
  }

  List<DropdownMenuItem<int?>> _createEmployeeUserItems() {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('Tạo employee chưa gán user'),
      ),
    ];

    for (final u in _unassignedUsers()) {
      items.add(
        DropdownMenuItem<int?>(
          value: u.id,
          child: Text('${u.email} (id=${u.id}, ${u.role})'),
        ),
      );
    }

    final selected = _newEmployeeUserId;
    if (selected != null && !items.any((x) => x.value == selected)) {
      UserLite? fallback;
      for (final u in _users) {
        if (u.id == selected) {
          fallback = u;
          break;
        }
      }

      items.add(
        DropdownMenuItem<int?>(
          value: selected,
          child: Text(
            fallback == null
                ? 'user_id=$selected (không có trong list)'
                : '${fallback.email} (id=${fallback.id}, ${fallback.role})',
          ),
        ),
      );
    }

    return items;
  }

  Future<void> _createEmployee() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Thiếu token đăng nhập. Hãy đăng nhập lại.';
      });
      return;
    }

    final code = _employeeCodeController.text.trim();
    final fullName = _employeeNameController.text.trim();

    if (code.isEmpty || fullName.isEmpty) {
      setState(() {
        _error = 'Vui lòng nhập đầy đủ mã nhân viên và họ tên.';
      });
      return;
    }

    setState(() {
      _creatingEmployee = true;
      _error = null;
      _info = null;
    });

    try {
      final created = await _adminApi.createEmployee(
        token: token,
        code: code,
        fullName: fullName,
        userId: _newEmployeeUserId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _employeeCodeController.clear();
        _employeeNameController.clear();
        _newEmployeeUserId = null;

        _employees = [created, ..._employees.where((e) => e.id != created.id)];
        _selectedUserByEmployee[created.id] = created.userId;
        _expandedEmployeeId = created.id;
        _info = created.userId == null
            ? 'Đã tạo nhân viên ${created.code}.'
            : 'Đã tạo nhân viên ${created.code} và gán user_id=${created.userId}.';
      });

      await _loadUsers();
      await _loadEmployees();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Tạo employee thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _creatingEmployee = false;
        });
      }
    }
  }

  Future<void> _assignEmployee(
    EmployeeLite employee, {
    int? overrideUserId,
  }) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Thiếu token đăng nhập. Hãy đăng nhập lại.';
      });
      return;
    }

    final selectedUser = overrideUserId ?? _selectedUserByEmployee[employee.id];

    setState(() {
      _assigningEmployeeIds.add(employee.id);
      _error = null;
      _info = null;
    });

    try {
      final updated = await _adminApi.assignEmployeeUser(
        token: token,
        employeeId: employee.id,
        userId: selectedUser,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _employees = _employees
            .map((e) => e.id == updated.id ? updated : e)
            .toList(growable: false);
        _selectedUserByEmployee[updated.id] = updated.userId;
        _info = updated.userId == null
            ? 'Đã bỏ gán user khỏi ${updated.code}.'
            : 'Đã gán user_id=${updated.userId} cho ${updated.code}.';
      });

      await _loadUsers();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Gán user thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _assigningEmployeeIds.remove(employee.id);
        });
      }
    }
  }

  Future<void> _clearAssign(EmployeeLite employee) async {
    await _assignEmployee(employee, overrideUserId: null);
  }

  Future<void> _confirmDeleteEmployee(EmployeeLite employee) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa nhân viên'),
        content: Text(
          'Bạn có chắc muốn xóa ${employee.code} - ${employee.fullName}?\nHành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _deleteEmployee(employee);
    }
  }

  Future<void> _deleteEmployee(EmployeeLite employee) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Thiếu token đăng nhập. Hãy đăng nhập lại.';
      });
      return;
    }

    setState(() {
      _deletingEmployeeIds.add(employee.id);
      _error = null;
      _info = null;
    });

    try {
      await _adminApi.deleteEmployee(token: token, employeeId: employee.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _employees = _employees
            .where((x) => x.id != employee.id)
            .toList(growable: false);
        _selectedUserByEmployee.remove(employee.id);
        if (_reportEmployeeId == employee.id) {
          _reportEmployeeId = null;
        }
        if (_expandedEmployeeId == employee.id) {
          _expandedEmployeeId = null;
        }
        _info = 'Đã xóa nhân viên ${employee.code}.';
      });
      _showSnack('Đã xóa nhân viên ${employee.code}.');

      await _loadUsers();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Xóa employee thất bại: $error';
      });
      _showSnack('Xóa employee thất bại: $error');
    } finally {
      if (mounted) {
        setState(() {
          _deletingEmployeeIds.remove(employee.id);
        });
      }
    }
  }

  String _dateLabel(DateTime? value) {
    if (value == null) {
      return 'Tất cả';
    }
    return _dateFormat.format(value);
  }

  Future<void> _pickReportDate({required bool isFrom}) async {
    final initial = isFrom
        ? (_reportFromDate ?? DateTime.now())
        : (_reportToDate ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      if (isFrom) {
        _reportFromDate = picked;
      } else {
        _reportToDate = picked;
      }
    });
  }

  Future<void> _downloadReport() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Thiếu token đăng nhập. Hãy đăng nhập lại.';
      });
      return;
    }

    if (_reportFromDate != null &&
        _reportToDate != null &&
        _reportFromDate!.isAfter(_reportToDate!)) {
      setState(() {
        _error = 'Khoảng ngày không hợp lệ: from phải <= to.';
      });
      return;
    }

    setState(() {
      _downloadingReport = true;
      _error = null;
      _info = null;
    });

    try {
      final report = await _adminApi.downloadAttendanceReport(
        token: token,
        fromDate: _reportFromDate,
        toDate: _reportToDate,
        employeeId: _reportEmployeeId,
        includeEmpty: _reportIncludeEmpty,
      );

      final savedPath = await saveBytesAsFile(
        bytes: report.bytes,
        fileName: report.fileName,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _info = 'Đã tải file: ${report.fileName}. Vị trí: $savedPath';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Xuất Excel thất bại: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _downloadingReport = false;
        });
      }
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

  DateTime? _parseExceptionDateTimeInput(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }

    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})$',
    ).firstMatch(value);
    if (match == null) {
      return null;
    }

    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    final hour = int.tryParse(match.group(4)!);
    final minute = int.tryParse(match.group(5)!);
    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null) {
      return null;
    }

    return DateTime(year, month, day, hour, minute);
  }

  String _formatExceptionDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return DateFormat('dd/MM/yyyy HH:mm').format(value.toLocal());
  }

  Future<void> _resolveException(AttendanceExceptionItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Thiếu token đăng nhập. Hãy đăng nhập lại.';
      });
      return;
    }

    final noteController = TextEditingController(text: item.note ?? '');
    final timeController = TextEditingController(
      text: item.actualCheckoutTime == null
          ? ''
          : DateFormat(
              'yyyy-MM-dd HH:mm',
            ).format(item.actualCheckoutTime!.toLocal()),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Resolve exception'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${item.employeeCode} - ${item.fullName} | ${_dateFormat.format(item.workDate)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: timeController,
                  decoration: _decoration(
                    'Giờ checkout thực tế (yyyy-MM-dd HH:mm, optional)',
                    Icons.access_time,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: _decoration(
                    'Ghi chú xử lý (optional)',
                    Icons.note_alt_outlined,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Resolve'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      noteController.dispose();
      timeController.dispose();
      return;
    }

    final rawTime = timeController.text.trim();
    final parsedLocal = _parseExceptionDateTimeInput(rawTime);
    if (rawTime.isNotEmpty && parsedLocal == null) {
      noteController.dispose();
      timeController.dispose();
      _showSnack('Sai định dạng thời gian. Dùng yyyy-MM-dd HH:mm');
      return;
    }

    setState(() {
      _updatingExceptionIds.add(item.id);
      _error = null;
      _info = null;
    });

    try {
      final updated = await _adminApi.resolveAttendanceException(
        token: token,
        exceptionId: item.id,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
        actualCheckoutTime: parsedLocal?.toUtc(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _exceptions = _exceptions
            .map((e) => e.id == updated.id ? updated : e)
            .toList(growable: false);
        _info = 'Đã xử lý ngoại lệ #${updated.id}.';
      });
      await _loadExceptions();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Xử lý ngoại lệ thất bại: $error';
      });
    } finally {
      noteController.dispose();
      timeController.dispose();
      if (mounted) {
        setState(() {
          _updatingExceptionIds.remove(item.id);
        });
      }
    }
  }

  Future<void> _reopenException(AttendanceExceptionItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Thiếu token đăng nhập. Hãy đăng nhập lại.';
      });
      return;
    }

    final noteController = TextEditingController(text: item.note ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reopen exception'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${item.employeeCode} - ${item.fullName} | ${_dateFormat.format(item.workDate)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: _decoration(
                    'Ghi chú mở lại (tuỳ chọn)',
                    Icons.note_alt_outlined,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Huỷ'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reopen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      noteController.dispose();
      return;
    }

    setState(() {
      _updatingExceptionIds.add(item.id);
      _error = null;
      _info = null;
    });

    try {
      final updated = await _adminApi.reopenAttendanceException(
        token: token,
        exceptionId: item.id,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _exceptions = _exceptions
            .map((e) => e.id == updated.id ? updated : e)
            .toList(growable: false);
        _info = 'Đã mở lại ngoại lệ #${updated.id}.';
      });
      await _loadExceptions();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Mở lại ngoại lệ thất bại: $error';
      });
    } finally {
      noteController.dispose();
      if (mounted) {
        setState(() {
          _updatingExceptionIds.remove(item.id);
        });
      }
    }
  }

  Future<void> _logout() async {
    await _tokenStorage.clearToken();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _showSnack(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  List<DropdownMenuItem<int?>> _employeeReportItems() {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('Tất cả nhân viên'),
      ),
    ];

    for (final e in _employees) {
      items.add(
        DropdownMenuItem<int?>(
          value: e.id,
          child: Text('${e.code} - ${e.fullName} (id=${e.id})'),
        ),
      );
    }

    return items;
  }

  List<DropdownMenuItem<int?>> _userItemsForEmployee(EmployeeLite employee) {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('Không gán user')),
    ];

    // Only show users not already linked to a different employee
    for (final u in _users) {
      final linkedToOther = _employees.any(
        (e) => e.userId == u.id && e.id != employee.id,
      );
      if (!linkedToOther) {
        items.add(
          DropdownMenuItem<int?>(
            value: u.id,
            child: Text('${u.email} (id=${u.id}, ${u.role})'),
          ),
        );
      }
    }

    final selected = _selectedUserByEmployee[employee.id];
    if (selected != null && !items.any((x) => x.value == selected)) {
      items.add(
        DropdownMenuItem<int?>(
          value: selected,
          child: Text('user_id=$selected (không có trong list)'),
        ),
      );
    }

    return items;
  }

  Widget _buildEmployeeRow(EmployeeLite e) {
    final assigning = _assigningEmployeeIds.contains(e.id);
    final deleting = _deletingEmployeeIds.contains(e.id);
    final busy = assigning || deleting;
    final selected = _selectedUserByEmployee[e.id];
    final expanded = _expandedEmployeeId == e.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                _expandedEmployeeId = expanded ? null : e.id;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(child: Text('${e.id}')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${e.code} - ${e.fullName}'),
                        Text(
                          e.userId == null
                              ? 'Chưa gán user'
                              : 'user_id hiện tại=${e.userId}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 10),
            DropdownButtonFormField<int?>(
              initialValue: selected,
              isExpanded: true,
              decoration: _decoration('Chọn user để gán', Icons.person_outline),
              items: _userItemsForEmployee(e),
              onChanged: busy
                  ? null
                  : (value) {
                      setState(() {
                        _selectedUserByEmployee[e.id] = value;
                      });
                    },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => _assignEmployee(e),
                    icon: assigning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.link),
                    label: const Text('Lưu gán'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _clearAssign(e),
                    icon: const Icon(Icons.link_off),
                    label: const Text('Bỏ gán'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _confirmDeleteEmployee(e),
                    icon: deleting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    label: const Text('Xóa'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExceptionRow(AttendanceExceptionItem e) {
    final busy = _updatingExceptionIds.contains(e.id);
    final statusColor = e.status == 'OPEN' ? Colors.orange : Colors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${e.employeeCode} - ${e.fullName}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Chip(
                label: Text(e.status),
                labelStyle: TextStyle(color: statusColor),
                backgroundColor: statusColor.withValues(alpha: 0.1),
                side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Ngày công: ${_dateFormat.format(e.workDate)} | Type: ${e.exceptionType}',
          ),
          Text(
            'Check-in gốc: ${_formatExceptionDateTime(e.sourceCheckinTime)}',
          ),
          Text(
            'Checkout thực tế: ${_formatExceptionDateTime(e.actualCheckoutTime)}',
          ),
          if (e.resolvedAt != null)
            Text(
              'Resolved: ${_formatExceptionDateTime(e.resolvedAt)}'
              '${e.resolvedByEmail == null ? '' : ' bởi ${e.resolvedByEmail}'}',
            ),
          if (e.note != null && e.note!.trim().isNotEmpty)
            Text('Note: ${e.note}'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (e.status == 'OPEN')
                FilledButton.icon(
                  onPressed: busy ? null : () => _resolveException(e),
                  icon: busy
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.task_alt),
                  label: const Text('Resolve'),
                )
              else
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _reopenException(e),
                  icon: busy
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.undo),
                  label: const Text('Reopen'),
                ),
            ],
          ),
        ],
      ),
    );
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

  List<_ShellNavEntry> _shellNavItems() {
    final pending = _dashboardExceptions.isNotEmpty
        ? _dashboardExceptions.length
        : _exceptions.where((e) => e.status == 'OPEN').length;
    return [
      const _ShellNavEntry(
        nav: _AdminShellNav.dashboard,
        icon: Icons.dashboard_outlined,
        label: 'Bảng điều khiển',
      ),
      const _ShellNavEntry(
        nav: _AdminShellNav.logs,
        icon: Icons.receipt_long_outlined,
        label: 'Nhật ký chấm công',
      ),
      const _ShellNavEntry(
        nav: _AdminShellNav.employees,
        icon: Icons.people_outline,
        label: 'Nhân viên',
      ),
      const _ShellNavEntry(
        nav: _AdminShellNav.groups,
        icon: Icons.groups_2_outlined,
        label: 'Nhóm',
      ),
      const _ShellNavEntry(
        nav: _AdminShellNav.geofences,
        icon: Icons.map_outlined,
        label: 'Vùng địa lý',
      ),
      const _ShellNavEntry(
        nav: _AdminShellNav.reports,
        icon: Icons.bar_chart_outlined,
        label: 'Báo cáo',
      ),
      _ShellNavEntry(
        nav: _AdminShellNav.exceptions,
        icon: Icons.error_outline,
        label: 'Ngoại lệ',
        badgeCount: pending,
      ),
      const _ShellNavEntry(
        nav: _AdminShellNav.settings,
        icon: Icons.settings_outlined,
        label: 'Cài đặt',
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
    if (_tabsLoaded.contains(nav)) return;
    _tabsLoaded.add(nav);
    await _loadTabData(nav);
  }

  Future<void> _loadTabData(_AdminShellNav nav) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    switch (nav) {
      case _AdminShellNav.dashboard:
        await _loadDashboardData();
      case _AdminShellNav.logs:
        await _loadDashboardLogs(token);
      case _AdminShellNav.employees:
        await _loadEmployees();
      case _AdminShellNav.groups:
        if (_dashboardGroups.isEmpty) {
          await _loadDashboardGroups();
        }
        await _loadEmployees();
        await _loadGroupGeofenceCards();
      case _AdminShellNav.geofences:
        await _loadDashboardGeofences(token);
      case _AdminShellNav.reports:
        break; // ReportsTab loads its own data on mount
      case _AdminShellNav.exceptions:
        await _loadExceptions();
      case _AdminShellNav.settings:
        await _loadActiveRule();
    }
  }

  Widget _buildSidebar() {
    final name = _displayNameFromEmail();
    final avatarText = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    final items = _shellNavItems()
        .map(
          (item) => AdminSidebarItem<_AdminShellNav>(
            value: item.nav,
            icon: item.icon,
            label: item.label,
            badgeCount: item.badgeCount,
            withDividerBefore: item.nav == _AdminShellNav.settings,
          ),
        )
        .toList(growable: false);

    return AdminSidebar<_AdminShellNav>(
      items: items,
      selected: _activeNav,
      displayName: name,
      avatarText: avatarText,
      roleLabel: 'Quản trị viên',
      onTap: _onShellNavTap,
    );
  }

  Widget _buildTopbar() {
    final title = _pageTitleForNav(_activeNav);
    final name = _displayNameFromEmail();
    final avatarText = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return AdminTopbar(
      title: title,
      dateLabel: _vietnameseDateLabel(),
      searchController: _searchController,
      avatarText: avatarText,
      onReloadTap: () => _refreshAll(),
      onAvatarTap: _logout,
    );
  }

  Future<void> _loadDashboardGroups() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }
    setState(() {
      _loadingDashboardGroups = true;
    });
    try {
      final groups = await _adminApi.listGroups(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboardGroups = groups;
        if (_dashboardGroupId != null &&
            !_dashboardGroups.any((g) => g.id == _dashboardGroupId)) {
          _dashboardGroupId = null;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Không thể tải danh sách nhóm.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingDashboardGroups = false;
        });
      }
    }
  }

  Future<void> _loadDashboardData() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }
    await Future.wait([
      _loadDashboardSummary(token),
      _loadDashboardLogs(token),
      _loadDashboardWeekly(token),
      _loadDashboardGeofences(token),
      _loadDashboardExceptions(token),
    ]);
  }

  Future<void> _loadDashboardSummary(String token) async {
    setState(() {
      _loadingDashboardSummary = true;
    });
    try {
      final data = await _adminApi.getDashboardSummary(
        token: token,
        date: _dashboardDate,
        groupId: _dashboardGroupId,
        status: _dashboardStatus,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboardSummary = data;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboardSummary = null;
      });
      _showSnack('Không thể tải số liệu tổng quan.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingDashboardSummary = false;
        });
      }
    }
  }

  Future<void> _loadDashboardLogs(String token) async {
    setState(() {
      _loadingDashboardLogs = true;
    });
    try {
      final result = await _adminApi.listDashboardAttendanceLogs(
        token: token,
        fromDate: _logsFromDate,
        toDate: _logsToDate,
        groupId: _dashboardGroupId,
        status: _dashboardStatus,
        search: _logsSearch,
        page: _logsPage,
        limit: _logsPageSize,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboardLogs = result.items;
        _logsServerTotal = result.total;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboardLogs = const [];
        _logsServerTotal = 0;
      });
      _showSnack('Không thể tải nhật ký chấm công.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingDashboardLogs = false;
        });
      }
    }
  }

  Future<void> _loadDashboardWeekly(String token) async {
    setState(() {
      _loadingDashboardWeekly = true;
      _weeklyError = false;
    });
    try {
      final rows = await _adminApi.getDashboardWeeklyTrends(
        token: token,
        date: _dashboardDate,
        groupId: _dashboardGroupId,
        status: _dashboardStatus,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboardWeekly = rows;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboardWeekly = const [];
        _weeklyError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingDashboardWeekly = false;
        });
      }
    }
  }

  Future<void> _loadDashboardGeofences(String token) async {
    setState(() {
      _loadingDashboardGeofences = true;
    });
    try {
      final rows = await _adminApi.listDashboardGeofences(token: token);
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboardGeofences = rows;
      });
      _syncSelectedGeofence();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboardGeofences = const [];
        _selectedGeofence = null;
      });
      _showSnack('Không thể tải danh sách vùng địa lý.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingDashboardGeofences = false;
        });
      }
    }
  }

  Future<void> _loadDashboardExceptions(String token) async {
    setState(() {
      _loadingDashboardExceptions = true;
    });
    try {
      final rows = await _adminApi.listDashboardExceptions(token: token);
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboardExceptions = rows;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboardExceptions = const [];
      });
      _showSnack('Không thể tải ngoại lệ chờ duyệt.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingDashboardExceptions = false;
        });
      }
    }
  }

  Future<void> _onDashboardFilterChanged() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }
    await Future.wait([
      _loadDashboardSummary(token),
      _loadDashboardLogs(token),
      _loadDashboardWeekly(token),
    ]);
  }

  Future<void> _refreshLogsOnly() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }
    await _loadDashboardLogs(token);
  }

  Future<void> _refreshEmployeesOnly() async {
    await _loadEmployees();
  }

  String _userEmailById(int? userId) {
    if (userId == null) {
      return '--';
    }
    for (final user in _users) {
      if (user.id == userId) {
        return user.email;
      }
    }
    return '--';
  }

  String _employeeStatusLabel(EmployeeLite employee) {
    return _isEmployeeActive(employee) ? 'Hoạt động' : 'Không hoạt động';
  }

  Future<void> _showEmployeeDetail(EmployeeLite employee) async {
    await _showEmployeeDetailDialog(employee);
  }

  Future<void> _showEmployeeEditPanel(EmployeeLite employee) async {
    await _showEmployeeEditPanelDialog(employee);
  }

  Future<void> _showEmployeesActionMenu(
    EmployeeLite employee,
    Offset position,
  ) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const [
        PopupMenuItem<String>(value: 'group', child: Text('Đổi nhóm')),
        PopupMenuItem<String>(value: 'disable', child: Text('Vô hiệu hoá')),
        PopupMenuItem<String>(value: 'delete', child: Text('Xoá')),
      ],
    );
    if (selected == 'group') {
      await _showEmployeeEditPanel(employee);
      return;
    }
    if (selected == 'disable') {
      await _assignEmployee(employee, overrideUserId: null);
      await _refreshEmployeesOnly();
      return;
    }
    if (selected == 'delete') {
      await _confirmDeleteEmployee(employee);
    }
  }

  Future<void> _showCreateEmployeeDialog() async {
    final codeController = TextEditingController();
    final nameController = TextEditingController();
    int? selectedGroupId;
    int? selectedUserId;
    var creating = false;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> onCreate() async {
              final token = _token;
              if (token == null || token.isEmpty) {
                _showSnack('Phiên đăng nhập đã hết hạn.');
                return;
              }
              final code = codeController.text.trim();
              final fullName = nameController.text.trim();
              if (code.isEmpty || fullName.isEmpty) {
                _showSnack('Vui lòng nhập mã nhân viên và họ tên.');
                return;
              }
              setDialogState(() {
                creating = true;
              });
              try {
                final created = await _adminApi.createEmployee(
                  token: token,
                  code: code,
                  fullName: fullName,
                  userId: selectedUserId,
                  groupId: selectedGroupId,
                );
                if (!mounted) {
                  return;
                }
                setState(() {
                  _employees = [
                    created,
                    ..._employees.where((e) => e.id != created.id),
                  ];
                });
                await _refreshEmployeesOnly();
                _showSnack('Đã thêm nhân viên mới.');
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
              } catch (_) {
                if (!mounted) {
                  return;
                }
                _showSnack('Không thể thêm nhân viên.');
              } finally {
                if (mounted) {
                  setDialogState(() {
                    creating = false;
                  });
                }
              }
            }

            return AlertDialog(
              title: const Text('Thêm nhân viên'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: codeController,
                      decoration: _decoration(
                        'Mã nhân viên *',
                        Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameController,
                      decoration: _decoration('Họ tên *', Icons.person_outline),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      initialValue: selectedGroupId,
                      decoration: _decoration('Nhóm', Icons.groups_2_outlined),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Chưa phân nhóm'),
                        ),
                        ..._dashboardGroups.map(
                          (group) => DropdownMenuItem<int?>(
                            value: group.id,
                            child: Text(group.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedGroupId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      initialValue: selectedUserId,
                      decoration: _decoration(
                        'Liên kết tài khoản',
                        Icons.link_outlined,
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Không liên kết'),
                        ),
                        ..._unassignedUsers().map(
                          (user) => DropdownMenuItem<int?>(
                            value: user.id,
                            child: Text('${user.email} (${user.role})'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedUserId = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: creating
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Huỷ'),
                ),
                ElevatedButton(
                  onPressed: creating ? null : onCreate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: creating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Thêm'),
                ),
              ],
            );
          },
        );
      },
    );
    codeController.dispose();
    nameController.dispose();
  }

  Future<void> _exportDashboardCsv() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _showSnack('Phiên đăng nhập đã hết hạn.');
      return;
    }
    setState(() {
      _exportingDashboardCsv = true;
    });
    try {
      final result = await _adminApi.exportDashboardExcel(
        token: token,
        fromDate: _dashboardDate,
        toDate: _dashboardDate,
        groupId: _dashboardGroupId,
        status: _dashboardStatus,
      );
      await saveBytesAsFile(bytes: result.bytes, fileName: result.fileName);
      if (!mounted) {
        return;
      }
      _showSnack('Xuất CSV thành công.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Không thể xuất CSV. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() {
          _exportingDashboardCsv = false;
        });
      }
    }
  }

  Future<void> _handleDashboardExceptionAction({
    required DashboardExceptionItem item,
    required bool approve,
  }) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _showSnack('Phiên đăng nhập đã hết hạn.');
      return;
    }
    if (_dashboardUpdatingExceptionIds.contains(item.id)) {
      return;
    }

    final previous = _dashboardExceptions;
    setState(() {
      _dashboardUpdatingExceptionIds.add(item.id);
      _dashboardExceptions = _dashboardExceptions
          .where((e) => e.id != item.id)
          .toList(growable: false);
    });
    try {
      if (approve) {
        await _adminApi.approveDashboardException(
          token: token,
          exceptionId: item.id,
        );
      } else {
        await _adminApi.rejectDashboardException(
          token: token,
          exceptionId: item.id,
        );
      }
      if (!mounted) {
        return;
      }
      _showSnack(
        approve ? 'Đã duyệt ngoại lệ.' : 'Đã chuyển ngoại lệ sang xem lại.',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboardExceptions = previous;
      });
      _showSnack('Không thể cập nhật ngoại lệ.');
    } finally {
      if (mounted) {
        setState(() {
          _dashboardUpdatingExceptionIds.remove(item.id);
        });
      }
    }
  }

  String _dashboardStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'on_time':
      case 'ontime':
      case 'early':
        return 'Đúng giờ';
      case 'late':
        return 'Đi muộn';
      case 'out_of_range':
      case 'outofrange':
      case 'oor':
        return 'Ngoài vùng';
      case 'complete':
        return 'Đầy đủ';
      case 'missed_checkout':
        return 'Thiếu checkout';
      case 'absent':
        return 'Vắng mặt';
      case 'pending_timesheet':
        return 'Chờ duyệt';
      case 'missing_checkin_anomaly':
        return 'Bất thường';
      default:
        return status;
    }
  }

  Color _dashboardStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'late':
        return const Color(0xFFD97706);
      case 'out_of_range':
      case 'outofrange':
      case 'oor':
      case 'absent':
      case 'missing_checkin_anomaly':
        return const Color(0xFFDC2626);
      case 'missed_checkout':
      case 'pending_timesheet':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF16A34A);
    }
  }

  String _formatPercent(double value) {
    return value.toStringAsFixed(1).replaceAll('.0', '');
  }

  String _formatThousands(int value) {
    final chars = value.toString().split('');
    final out = <String>[];
    for (var i = 0; i < chars.length; i++) {
      out.add(chars[i]);
      final remain = chars.length - i - 1;
      if (remain > 0 && remain % 3 == 0) {
        out.add('.');
      }
    }
    return out.join();
  }

  List<DropdownMenuItem<int?>> _dashboardGroupItems() {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('Tất cả nhóm')),
    ];
    for (final g in _dashboardGroups) {
      items.add(DropdownMenuItem<int?>(value: g.id, child: Text(g.name)));
    }
    return items;
  }

  int get _logsTotalCount => _logsServerTotal;

  int get _logsTotalPages {
    if (_logsTotalCount == 0) {
      return 1;
    }
    return ((_logsTotalCount - 1) ~/ _logsPageSize) + 1;
  }

  // With server-side pagination _dashboardLogs already contains the current page.
  List<DashboardAttendanceLogItem> get _logsCurrentPageItems => _dashboardLogs;

  bool _isEmployeeActive(EmployeeLite employee) {
    if (employee.active != null) {
      return employee.active!;
    }
    return employee.userId != null;
  }

  String _employeeGroupName(EmployeeLite employee) {
    if (employee.groupName != null && employee.groupName!.trim().isNotEmpty) {
      return employee.groupName!;
    }
    if (employee.groupId == null) {
      return 'Chưa phân nhóm';
    }
    for (final group in _dashboardGroups) {
      if (group.id == employee.groupId) {
        return group.name;
      }
    }
    return 'Nhóm #${employee.groupId}';
  }

  List<EmployeeLite> get _employeesView {
    final filterKey =
        '${_employeesSearchController.text.trim()}|$_employeesGroupId|$_employeesStatus';
    if (_cachedEmployeesView != null &&
        identical(_cachedEmployeesListRef, _employees) &&
        _cachedEmployeesFilterKey == filterKey) {
      return _cachedEmployeesView!;
    }
    var list = _employees.toList(growable: false);
    final q = _employeesSearchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (e) =>
                e.code.toLowerCase().contains(q) ||
                e.fullName.toLowerCase().contains(q) ||
                (e.email?.toLowerCase().contains(q) ?? false),
          )
          .toList(growable: false);
    }
    if (_employeesGroupId != null) {
      list = list
          .where((e) => e.groupId == _employeesGroupId)
          .toList(growable: false);
    }
    if (_employeesStatus == 'active') {
      list = list.where(_isEmployeeActive).toList(growable: false);
    } else if (_employeesStatus == 'inactive') {
      list = list.where((e) => !_isEmployeeActive(e)).toList(growable: false);
    }
    _cachedEmployeesListRef = _employees;
    _cachedEmployeesFilterKey = filterKey;
    _cachedEmployeesView = list;
    return list;
  }

  int get _employeesTotalCount => _employeesView.length;

  int get _employeesTotalPages {
    if (_employeesTotalCount == 0) {
      return 1;
    }
    return ((_employeesTotalCount - 1) ~/ _employeesPageSize) + 1;
  }

  List<EmployeeLite> get _employeesCurrentPageItems {
    final rows = _employeesView;
    if (rows.isEmpty) {
      return const [];
    }
    final start = (_employeesPage - 1) * _employeesPageSize;
    if (start >= rows.length) {
      return const [];
    }
    final end = (start + _employeesPageSize).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  List<GroupLite> get _groupsView {
    final filterKey = '$_groupsSearch|$_groupsStatus';
    if (_cachedGroupsView != null &&
        identical(_cachedGroupsListRef, _dashboardGroups) &&
        _cachedGroupsFilterKey == filterKey) {
      return _cachedGroupsView!;
    }
    var list = _dashboardGroups.toList(growable: false);
    final query = _groupsSearch.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list
          .where((g) {
            final name = g.name.toLowerCase();
            final code = g.code.toLowerCase();
            return name.contains(query) || code.contains(query);
          })
          .toList(growable: false);
    }
    if (_groupsStatus == 'active') {
      list = list.where((g) => g.active).toList(growable: false);
    } else if (_groupsStatus == 'inactive') {
      list = list.where((g) => !g.active).toList(growable: false);
    }
    _cachedGroupsListRef = _dashboardGroups;
    _cachedGroupsFilterKey = filterKey;
    _cachedGroupsView = list;
    return list;
  }

  List<EmployeeLite> get _unassignedGroupEmployees {
    return _employees.where((e) => e.groupId == null).toList(growable: false);
  }

  int get _unassignedGroupCount => _unassignedGroupEmployees.length;

  Future<void> _refreshGroupsOnly() async {
    await _loadDashboardGroups();
    await _loadGroupGeofenceCards();
    await _loadEmployees();
  }

  Future<void> _loadGroupGeofenceCards() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }
    final groups = _dashboardGroups;
    if (groups.isEmpty) {
      setState(() {
        _groupGeofencesByGroupId.clear();
      });
      return;
    }
    setState(() {
      _loadingGroupGeofenceCards = true;
    });
    try {
      // Single aggregate request instead of N per-group requests.
      final summary = await _adminApi.listGroupGeofencesSummary(token: token);
      if (!mounted) {
        return;
      }
      setState(() {
        _groupGeofencesByGroupId.clear();
        for (final group in groups) {
          _groupGeofencesByGroupId[group.id] =
              summary[group.id] ?? const <GroupGeofenceLite>[];
        }
      });
    } catch (_) {
      // Fallback: per-group requests if aggregate endpoint is unavailable.
      try {
        final entries = await Future.wait(
          groups.map((group) async {
            try {
              final items = await _adminApi.listGroupGeofences(
                token: token,
                groupId: group.id,
              );
              return MapEntry(group.id, items);
            } catch (_) {
              return MapEntry(group.id, const <GroupGeofenceLite>[]);
            }
          }),
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _groupGeofencesByGroupId
            ..clear()
            ..addEntries(entries);
        });
      } catch (_) {
        // Silent — leave existing data untouched.
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingGroupGeofenceCards = false;
        });
      }
    }
  }

  void _syncSelectedGeofence() {
    if (!mounted) {
      return;
    }
    if (_dashboardGeofences.isEmpty) {
      setState(() {
        _selectedGeofence = null;
      });
      return;
    }
    if (_selectedGeofence == null) {
      _selectGeofenceForEdit(_dashboardGeofences.first, moveMap: false);
      return;
    }
    DashboardGeofenceItem? refreshed;
    for (final item in _dashboardGeofences) {
      if (item.id == _selectedGeofence!.id) {
        refreshed = item;
        break;
      }
    }
    if (refreshed == null) {
      _selectGeofenceForEdit(_dashboardGeofences.first, moveMap: false);
      return;
    }
    _selectGeofenceForEdit(refreshed, moveMap: false);
  }

  void _selectGeofenceForEdit(
    DashboardGeofenceItem item, {
    bool moveMap = true,
  }) {
    _zoneNameController.text = item.name;
    _zoneLatController.text = (item.latitude ?? AppConfig.defaultMapCenterLat)
        .toStringAsFixed(6);
    _zoneLngController.text = (item.longitude ?? AppConfig.defaultMapCenterLng)
        .toStringAsFixed(6);
    _zoneRadiusController.text = (item.radiusMeters ?? 200).toString();
    _zoneAddressController.text = item.address ?? '';
    _zoneStartTimeController.text = item.startTime ?? '08:00';
    _zoneEndTimeController.text = item.endTime ?? '17:30';
    _zoneOvertimeEnabled = item.overtimeEnabled ?? false;
    _zoneOvertimeStartController.text = item.overtimeStartTime ?? '18:00';
    _zoneActive = item.active;
    _zoneAssignedGroupIds
      ..clear()
      ..addAll(item.groupId == null ? const <int>[] : <int>[item.groupId!]);
    setState(() {
      _selectedGeofence = item;
      _newGeofencePoint = null;
    });
    if (moveMap && item.latitude != null && item.longitude != null) {
      _geofenceMapController.move(
        LatLng(item.latitude!, item.longitude!),
        _geofenceZoomNotifier.value,
      );
    }
  }

  Future<void> _searchGeofencePlaces(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _geofencePlaceSuggestions = const [];
      });
      return;
    }
    setState(() {
      _searchingGeofencePlaces = true;
    });
    try {
      final result = await _adminApi.searchGeoapifyPlaces(query: q);
      if (!mounted) {
        return;
      }
      setState(() {
        _geofencePlaceSuggestions = result;
      });
    } finally {
      if (mounted) {
        setState(() {
          _searchingGeofencePlaces = false;
        });
      }
    }
  }

  Future<void> _reverseZoneAddress() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }
    final lat = double.tryParse(_zoneLatController.text.trim());
    final lng = double.tryParse(_zoneLngController.text.trim());
    if (lat == null || lng == null) {
      return;
    }
    setState(() {
      _reversingGeofenceAddress = true;
    });
    try {
      final address = await _adminApi.reverseGeocodeAddress(
        token: token,
        latitude: lat,
        longitude: lng,
      );
      if (!mounted) {
        return;
      }
      if (address != null && address.isNotEmpty) {
        setState(() {
          _zoneAddressController.text = address;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _reversingGeofenceAddress = false;
        });
      }
    }
  }

  Future<void> _onGeofenceMapTap(LatLng point) async {
    setState(() {
      _newGeofencePoint = point;
      _zoneLatController.text = point.latitude.toStringAsFixed(6);
      _zoneLngController.text = point.longitude.toStringAsFixed(6);
    });
    _showSnack('Đã chọn điểm mới trên bản đồ.');
    await _reverseZoneAddress();
  }

  Future<void> _pickZoneTime(TextEditingController controller) async {
    final now = TimeOfDay.now();
    final current = controller.text.trim();
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(current);
    final initial = match == null
        ? now
        : TimeOfDay(
            hour: int.tryParse(match.group(1)!) ?? now.hour,
            minute: int.tryParse(match.group(2)!) ?? now.minute,
          );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) {
      return;
    }
    controller.text =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveGeofenceConfig() async {
    final token = _token;
    final selected = _selectedGeofence;
    if (token == null || token.isEmpty || selected == null) {
      _showSnack('Không thể lưu cấu hình vùng.');
      return;
    }
    final name = _zoneNameController.text.trim();
    final lat = double.tryParse(_zoneLatController.text.trim());
    final lng = double.tryParse(_zoneLngController.text.trim());
    final radius = int.tryParse(_zoneRadiusController.text.trim());
    if (name.isEmpty || lat == null || lng == null || radius == null) {
      _showSnack('Vui lòng nhập đầy đủ thông tin vùng địa lý.');
      return;
    }
    setState(() {
      _savingGeofenceConfig = true;
    });
    try {
      final updated = await _adminApi.updateGeofence(
        token: token,
        geofenceId: selected.id,
        name: name,
        latitude: lat,
        longitude: lng,
        radiusMeters: radius.clamp(10, 2000),
        active: _zoneActive,
        startTime: _zoneStartTimeController.text.trim(),
        endTime: _zoneEndTimeController.text.trim(),
        overtimeEnabled: _zoneOvertimeEnabled,
        overtimeStartTime: _zoneOvertimeEnabled
            ? _zoneOvertimeStartController.text.trim()
            : null,
        groupIds: _zoneAssignedGroupIds.toList(growable: false),
        address: _zoneAddressController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboardGeofences = _dashboardGeofences
            .map((e) => e.id == updated.id ? updated : e)
            .toList(growable: false);
      });
      _selectGeofenceForEdit(updated);
      _showSnack('Đã cập nhật vùng địa lý.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Không thể cập nhật vùng địa lý.');
    } finally {
      if (mounted) {
        setState(() {
          _savingGeofenceConfig = false;
        });
      }
    }
  }

  Future<void> _deleteSelectedGeofence() async {
    final token = _token;
    final selected = _selectedGeofence;
    if (token == null || token.isEmpty || selected == null) {
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoá vùng địa lý'),
        content: Text('Bạn có chắc muốn xoá "${selected.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    setState(() {
      _deletingGeofenceConfig = true;
    });
    try {
      await _adminApi.deleteGeofence(token: token, geofenceId: selected.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboardGeofences = _dashboardGeofences
            .where((e) => e.id != selected.id)
            .toList(growable: false);
      });
      _syncSelectedGeofence();
      _showSnack('Đã xoá vùng địa lý.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Không thể xoá vùng địa lý.');
    } finally {
      if (mounted) {
        setState(() {
          _deletingGeofenceConfig = false;
        });
      }
    }
  }

  Future<void> _assignEmployeeToGroup(
    EmployeeLite employee,
    int? groupId,
  ) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _showSnack('Phiên đăng nhập đã hết hạn.');
      return;
    }
    try {
      final updated = await _adminApi.assignEmployeeGroup(
        token: token,
        employeeId: employee.id,
        groupId: groupId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _employees = _employees
            .map((e) => e.id == updated.id ? updated : e)
            .toList(growable: false);
      });
      _showSnack('Đã cập nhật nhóm cho nhân viên.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Không thể cập nhật nhóm cho nhân viên.');
    }
  }

  Future<void> _deleteGroupItem(GroupLite group) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _showSnack('Phiên đăng nhập đã hết hạn.');
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoá nhóm'),
        content: Text('Bạn có chắc muốn xoá nhóm "${group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }
    setState(() {
      _deletingGroup = true;
    });
    try {
      await _adminApi.deleteGroup(token: token, groupId: group.id);
      if (!mounted) {
        return;
      }
      await _refreshGroupsOnly();
      _showSnack('Đã xoá nhóm.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Không thể xoá nhóm.');
    } finally {
      if (mounted) {
        setState(() {
          _deletingGroup = false;
        });
      }
    }
  }

  Future<void> _showGroupActionsMenu(GroupLite group, Offset position) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: const [
        PopupMenuItem<String>(value: 'edit', child: Text('Chỉnh sửa')),
        PopupMenuItem<String>(value: 'delete', child: Text('Xoá')),
      ],
    );
    if (selected == 'edit') {
      await _showGroupEditorPanel(group: group);
      return;
    }
    if (selected == 'delete') {
      await _deleteGroupItem(group);
    }
  }

  Future<void> _showGroupEditorPanel({GroupLite? group}) async {
    await _showGroupEditorPanelExtracted(group: group);
  }

  Future<void> _pickLogsDate({required bool isFrom}) async {
    final initial = isFrom ? _logsFromDate : _logsToDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      if (isFrom) {
        _logsFromDate = picked;
      } else {
        _logsToDate = picked;
      }
      if (_logsFromDate.isAfter(_logsToDate)) {
        if (isFrom) {
          _logsToDate = picked;
        } else {
          _logsFromDate = picked;
        }
      }
      _logsPage = 1;
    });
    await _refreshLogsOnly();
  }

  Future<void> _exportAttendanceLogsCsv() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _showSnack('Phiên đăng nhập đã hết hạn.');
      return;
    }
    setState(() {
      _exportingDashboardCsv = true;
    });
    try {
      final report = await _adminApi.downloadAttendanceReport(
        token: token,
        fromDate: _logsFromDate,
        toDate: _logsToDate,
        groupId: _dashboardGroupId,
      );
      await saveBytesAsFile(bytes: report.bytes, fileName: report.fileName);
      if (!mounted) {
        return;
      }
      _showSnack('Xuất CSV thành công.');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Không thể xuất CSV. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() {
          _exportingDashboardCsv = false;
        });
      }
    }
  }

  StatusBadgeType _badgeTypeForStatus(String status) =>
      _badgeTypeForStatusStatic(status);

  static StatusBadgeType _badgeTypeForStatusStatic(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('late')) return StatusBadgeType.late;
    if (normalized.contains('early')) return StatusBadgeType.early;
    if (normalized.contains('overtime') || normalized.contains('ot')) {
      return StatusBadgeType.overtime;
    }
    if (normalized.contains('out')) return StatusBadgeType.outOfRange;
    if (normalized.contains('exception')) return StatusBadgeType.exception;
    return StatusBadgeType.onTime;
  }

  Widget _buildAttendanceLogsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAttendanceStatCards(),
        const SizedBox(height: 16),
        _buildAttendanceLogsFilterCard(),
        const SizedBox(height: 16),
        _buildAttendanceLogsTableCard(),
      ],
    );
  }

  Widget _buildAttendanceLogsFilterCard() {
    return _buildAttendanceFilterBarCard();
  }

  Widget _buildAttendanceLogsTableCard() {
    return _buildAttendanceTableCard();
  }

  Widget _buildAttendanceLogsSkeleton() {
    return _buildAttendanceTableSkeleton();
  }

  Widget _buildLogsPagination() {
    return _buildAttendancePagination();
  }

  Widget _buildEmployeesPage() {
    final total = _employees.length;
    final active = _employees.where(_isEmployeeActive).length;
    final inactive = total - active;

    return Column(
      key: _employeesSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 250,
              child: KpiCard(
                label: 'Tổng nhân viên',
                value: _loadingEmployees ? '--' : _formatThousands(total),
                icon: Icons.groups_outlined,
                iconColor: AppColors.primary,
                valueColor: AppColors.primary,
                loading: _loadingEmployees,
              ),
            ),
            SizedBox(
              width: 250,
              child: KpiCard(
                label: 'Đang hoạt động',
                value: _loadingEmployees ? '--' : _formatThousands(active),
                icon: Icons.check_circle_outline,
                iconColor: AppColors.success,
                valueColor: AppColors.success,
                loading: _loadingEmployees,
              ),
            ),
            SizedBox(
              width: 250,
              child: KpiCard(
                label: 'Không hoạt động',
                value: _loadingEmployees ? '--' : _formatThousands(inactive),
                icon: Icons.pause_circle_outline,
                iconColor: AppColors.textMuted,
                valueColor: AppColors.textMuted,
                loading: _loadingEmployees,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildEmployeesToolbarCard(),
        const SizedBox(height: 16),
        _buildEmployeesTableCard(),
      ],
    );
  }

  Widget _buildEmployeesToolbarCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 320,
            child: TextField(
              controller: _employeesSearchController,
              onChanged: (_) {
                _employeesPaginationNotifier.value = (
                  page: 1,
                  pageSize: _employeesPageSize,
                );
              },
              onSubmitted: (_) {
                _employeesPaginationNotifier.value = (
                  page: 1,
                  pageSize: _employeesPageSize,
                );
                _refreshEmployeesOnly();
              },
              decoration: InputDecoration(
                isDense: true,
                hintText: 'T\u00ecm nh\u00e2n vi\u00ean...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: IconButton(
                  onPressed: _loadingEmployees
                      ? null
                      : () {
                          _employeesPaginationNotifier.value = (
                            page: 1,
                            pageSize: _employeesPageSize,
                          );
                          _refreshEmployeesOnly();
                        },
                  icon: const Icon(Icons.search),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 250,
            child: DropdownButtonFormField<int?>(
              initialValue: _employeesGroupId,
              decoration: _decoration('Nhóm', Icons.groups_2_outlined),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Tất cả nhóm'),
                ),
                ..._dashboardGroups.map(
                  (group) => DropdownMenuItem<int?>(
                    value: group.id,
                    child: Text(group.name),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _employeesGroupId = value;
                });
                _employeesPaginationNotifier.value = (
                  page: 1,
                  pageSize: _employeesPageSize,
                );
                _refreshEmployeesOnly();
              },
            ),
          ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              initialValue: _employeesStatus,
              decoration: _decoration('Trạng thái', Icons.rule_outlined),
              items: const [
                DropdownMenuItem<String>(value: 'all', child: Text('Tất cả')),
                DropdownMenuItem<String>(
                  value: 'active',
                  child: Text('Hoạt động'),
                ),
                DropdownMenuItem<String>(
                  value: 'inactive',
                  child: Text('Không hoạt động'),
                ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _employeesStatus = value;
                });
                _employeesPaginationNotifier.value = (
                  page: 1,
                  pageSize: _employeesPageSize,
                );
                _refreshEmployeesOnly();
              },
            ),
          ),
          OutlinedButton.icon(
            onPressed: _downloadingReport ? null : _downloadReport,
            icon: _downloadingReport
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download_outlined),
            label: const Text('Xuất danh sách'),
          ),
          ElevatedButton.icon(
            onPressed: _showCreateEmployeeDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Thêm nhân viên'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeesTableCard() {
    return _buildEmployeeTableCardExtracted();
  }

  Widget _buildEmployeesTableSkeleton() {
    return _buildEmployeeTableSkeletonExtracted();
  }

  Widget _buildEmployeesPagination() {
    return _buildEmployeesPaginationExtracted();
  }

  Widget _buildGroupsPage() {
    return _buildGroupsPageExtracted();
  }

  Widget _buildGroupsToolbarCard() {
    return _buildGroupsToolbarCardExtracted();
  }

  Widget _buildGroupsGridCard() {
    return _buildGroupsGridCardExtracted();
  }

  Widget _buildGroupCard(GroupLite group, int index) {
    return _buildGroupCardExtracted(group, index);
  }

  Widget _buildGroupMiniStat(String label, String value) {
    return _buildGroupMiniStatExtracted(label, value);
  }

  Widget _buildUnassignedGroupPanel() {
    return _buildUnassignedGroupPanelExtracted();
  }

  Color _colorForGeofenceIndex(int index) {
    const palette = <Color>[
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      AppColors.danger,
      AppColors.overtime,
      AppColors.earlyTeal,
    ];
    return palette[index % palette.length];
  }

  Widget _buildGeofencesPage() {
    return _buildGeofencesPageExtracted();
  }

  Widget _buildGeofenceMapCard() {
    return _buildGeofenceMapCardExtracted();
  }

  Widget _buildGeofenceSidePanel() {
    return _buildGeofenceSidePanelExtracted();
  }

  Widget _buildGeofenceConfigForm(DashboardGeofenceItem selected) {
    return _buildGeofenceConfigFormExtracted(selected);
  }

  Widget _buildDashboardContent() {
    final summary = _dashboardSummary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 230,
              child: KpiCard(
                label: 'Tổng nhân viên',
                value: summary == null
                    ? '--'
                    : _formatThousands(summary.totalEmployees),
                subText: summary == null
                    ? null
                    : '+${_formatPercent(summary.employeeGrowthPercent)}% tháng này',
                subColor: const Color(0xFF16A34A),
                icon: Icons.people_outline,
                iconColor: const Color(0xFF1A56DB),
                loading: _loadingDashboardSummary,
              ),
            ),
            SizedBox(
              width: 230,
              child: KpiCard(
                label: 'Đã điểm danh',
                value: summary == null
                    ? '--'
                    : _formatThousands(summary.checkedIn),
                subText: summary == null
                    ? null
                    : 'Tỷ lệ ${_formatPercent(summary.attendanceRatePercent)}%',
                subColor: const Color(0xFF16A34A),
                icon: Icons.check_circle_outline,
                iconColor: const Color(0xFF16A34A),
                loading: _loadingDashboardSummary,
              ),
            ),
            SizedBox(
              width: 230,
              child: KpiCard(
                label: 'Điểm danh muộn',
                value: summary == null
                    ? '--'
                    : _formatThousands(summary.lateCount),
                subText: summary == null
                    ? null
                    : '${_formatPercent(summary.lateRatePercent)}% tổng số',
                valueColor: const Color(0xFFD97706),
                subColor: const Color(0xFFD97706),
                icon: Icons.schedule,
                iconColor: const Color(0xFFD97706),
                loading: _loadingDashboardSummary,
              ),
            ),
            SizedBox(
              width: 230,
              child: KpiCard(
                label: 'Ngoài vùng',
                value: summary == null
                    ? '--'
                    : _formatThousands(summary.outOfRangeCount),
                subText: 'Cần xem lại',
                valueColor: const Color(0xFFDC2626),
                subColor: const Color(0xFFDC2626),
                icon: Icons.location_off,
                iconColor: const Color(0xFFDC2626),
                loading: _loadingDashboardSummary,
              ),
            ),
            SizedBox(
              width: 230,
              child: KpiCard(
                label: 'Vùng địa lý',
                value: summary == null
                    ? '--'
                    : _formatThousands(summary.geofenceCount),
                subText: summary == null
                    ? null
                    : '${_formatThousands(summary.inactiveGeofenceCount)} không hoạt động',
                subColor: const Color(0xFF64748B),
                icon: Icons.map_outlined,
                iconColor: const Color(0xFF7C3AED),
                loading: _loadingDashboardSummary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildAttendanceTableCard(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 980) {
              return Column(
                children: [
                  _buildWeeklyChartCard(),
                  const SizedBox(height: 16),
                  _buildGeofenceListCard(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: _buildWeeklyChartCard()),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: _buildGeofenceListCard()),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _buildExceptionsCard(),
      ],
    );
  }

  Widget _buildAttendanceTableCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            if (_loadingDashboardLogs) _buildDashboardLogSkeleton(),
            if (!_loadingDashboardLogs && _dashboardLogs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('Chưa có dữ liệu hôm nay')),
              ),
            if (!_loadingDashboardLogs && _dashboardLogs.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    const Color(0xFFF8FAFC),
                  ),
                  columns: const [
                    DataColumn(label: Text('Nhân viên')),
                    DataColumn(label: Text('Phòng ban')),
                    DataColumn(label: Text('Ngày')),
                    DataColumn(label: Text('Giờ vào')),
                    DataColumn(label: Text('Giờ ra')),
                    DataColumn(label: Text('Trạng thái vị trí')),
                    DataColumn(label: Text('Trạng thái')),
                  ],
                  rows: _dashboardLogs
                      .map((row) {
                        final statusColor = _dashboardStatusColor(
                          row.attendanceStatus,
                        );
                        final inRange = row.locationStatus == 'inside';
                        final dateLabel = row.workDate == null
                            ? '--'
                            : DateFormat('dd/MM/yyyy').format(row.workDate!);
                        final checkInLabel = _format24hTimeLabel(
                          row.checkInTime,
                        );
                        final checkOutLabel = _format24hTimeLabel(
                          row.checkOutTime,
                        );
                        return DataRow(
                          cells: [
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(row.employeeName),
                                  Text(
                                    row.employeeCode,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(Text(row.departmentName)),
                            DataCell(Text(dateLabel)),
                            DataCell(
                              Text(
                                checkInLabel,
                                style: TextStyle(color: statusColor),
                              ),
                            ),
                            DataCell(
                              Text(
                                checkOutLabel,
                                style: TextStyle(
                                  color: checkOutLabel == '--'
                                      ? AppColors.textMuted
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  Icon(
                                    inRange
                                        ? Icons.location_on_outlined
                                        : Icons.location_off_outlined,
                                    size: 16,
                                    color: inRange
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    inRange ? 'Trong vùng' : 'Ngoài vùng',
                                    style: TextStyle(
                                      color: inRange
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              _StatusBadge(
                                label: _dashboardStatusLabel(
                                  row.attendanceStatus,
                                ),
                                color: statusColor,
                              ),
                            ),
                          ],
                        );
                      })
                      .toList(growable: false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardLogSkeleton() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        columns: const [
          DataColumn(label: Text('Nhân viên')),
          DataColumn(label: Text('Phòng ban')),
          DataColumn(label: Text('Ngày')),
          DataColumn(label: Text('Giờ vào')),
          DataColumn(label: Text('Giờ ra')),
          DataColumn(label: Text('Trạng thái vị trí')),
          DataColumn(label: Text('Trạng thái')),
        ],
        rows: List.generate(
          3,
          (_) => const DataRow(
            cells: [
              DataCell(_SkeletonCell(width: 130)),
              DataCell(_SkeletonCell(width: 80)),
              DataCell(_SkeletonCell(width: 72)),
              DataCell(_SkeletonCell(width: 48)),
              DataCell(_SkeletonCell(width: 48)),
              DataCell(_SkeletonCell(width: 88)),
              DataCell(_SkeletonCell(width: 72)),
            ],
          ),
        ),
      ),
    );
  }

  String _format24hTimeLabel(String value) {
    final raw = value.trim();
    if (raw.isEmpty || raw == '--') {
      return '--';
    }
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(raw)) {
      return raw;
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final local = parsed.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildWeeklyChartCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Xu hướng chấm công hàng tuần',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                _LegendDot(color: Color(0xFF16A34A), label: 'Đúng giờ'),
                SizedBox(width: 14),
                _LegendDot(color: Color(0xFFD97706), label: 'Đi muộn'),
                SizedBox(width: 14),
                _LegendDot(color: Color(0xFFDC2626), label: 'Ngoài vùng'),
              ],
            ),
            const SizedBox(height: 14),
            _MockWeeklyChart(
              data: _dashboardWeekly,
              loading: _loadingDashboardWeekly,
              error: _weeklyError,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeofenceListCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Khu vực địa lý đang hoạt động',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => _onShellNavTap(_AdminShellNav.geofences),
                  child: const Text('Xem bản đồ →'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loadingDashboardGeofences)
              ...List<Widget>.generate(
                3,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: _SkeletonRow(),
                ),
              ),
            if (!_loadingDashboardGeofences && _dashboardGeofences.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('Chưa có khu vực địa lý.'),
              ),
            if (!_loadingDashboardGeofences)
              ..._dashboardGeofences.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.location_on_outlined, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${item.memberCount} thành viên',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: item.active
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF94A3B8),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 4),
            _DashedBorderButton(
              onTap: () => _onShellNavTap(_AdminShellNav.geofences),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 18, color: Color(0xFF334155)),
                  SizedBox(width: 8),
                  Text(
                    'Thêm khu vực mới',
                    style: TextStyle(
                      color: Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExceptionsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Các ngoại lệ gần đây',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (_loadingDashboardExceptions)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (!_loadingDashboardExceptions && _dashboardExceptions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Không có ngoại lệ đang chờ duyệt.'),
              ),
            if (!_loadingDashboardExceptions)
              ..._dashboardExceptions.map((item) {
                final busy = _dashboardUpdatingExceptionIds.contains(item.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFE2E8F0),
                        child: Text(
                          item.initials,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              item.reason,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        item.timeLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: busy
                            ? null
                            : () => _handleDashboardExceptionAction(
                                item: item,
                                approve: true,
                              ),
                        borderRadius: BorderRadius.circular(999),
                        child: const _StatusBadge(
                          label: 'Chờ duyệt',
                          color: Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: busy
                            ? null
                            : () => _handleDashboardExceptionAction(
                                item: item,
                                approve: false,
                              ),
                        borderRadius: BorderRadius.circular(999),
                        child: const _StatusBadge(
                          label: 'Xem lại',
                          color: Color(0xFF1A56DB),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => _onShellNavTap(_AdminShellNav.exceptions),
              child: const Text('Xem tất cả ngoại lệ quản trị →'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentByNav() {
    switch (_activeNav) {
      case _AdminShellNav.dashboard:
        return _buildDashboardContent();
      case _AdminShellNav.logs:
        return _buildAttendanceLogsPage();
      case _AdminShellNav.employees:
        return _buildEmployeesPage();
      case _AdminShellNav.groups:
        return _buildGroupsPage();
      case _AdminShellNav.geofences:
        return _buildGeofencesPage();
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _MockWeeklyChart extends StatelessWidget {
  const _MockWeeklyChart({
    required this.data,
    required this.loading,
    this.error = false,
  });

  final List<DashboardWeeklyTrendItem> data;
  final bool loading;
  final bool error;

  @override
  Widget build(BuildContext context) {
    if (!loading && error) {
      return const SizedBox(
        height: 240,
        child: Center(
          child: Text(
            'Không thể tải dữ liệu xu hướng',
            style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          ),
        ),
      );
    }

    if (!loading && data.isEmpty) {
      return const SizedBox(
        height: 240,
        child: Center(
          child: Text(
            'Chưa có dữ liệu xu hướng',
            style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          ),
        ),
      );
    }

    const loadingPlaceholder = [
      DashboardWeeklyTrendItem(
        day: 'Thứ 2',
        onTime: 24,
        late: 24,
        outOfRange: 24,
      ),
      DashboardWeeklyTrendItem(
        day: 'Thứ 3',
        onTime: 24,
        late: 24,
        outOfRange: 24,
      ),
      DashboardWeeklyTrendItem(
        day: 'Thứ 4',
        onTime: 24,
        late: 24,
        outOfRange: 24,
      ),
      DashboardWeeklyTrendItem(
        day: 'Thứ 5',
        onTime: 24,
        late: 24,
        outOfRange: 24,
      ),
      DashboardWeeklyTrendItem(
        day: 'Thứ 6',
        onTime: 24,
        late: 24,
        outOfRange: 24,
      ),
    ];
    final chartData = loading ? loadingPlaceholder : data;

    final maxVal = loading
        ? 24
        : chartData.fold<int>(
            1,
            (m, item) => math.max(
              m,
              math.max(item.onTime, math.max(item.late, item.outOfRange)),
            ),
          );
    final maxY = (maxVal * 1.25).ceilToDouble();
    final step = (maxY / 4).ceilToDouble();
    final yLabels = [
      (maxY).toInt(),
      (step * 3).toInt(),
      (step * 2).toInt(),
      step.toInt(),
      0,
    ];

    return SizedBox(
      height: 240,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: yLabels
                  .map(
                    (v) => Text(
                      '$v',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: chartData.map((item) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final h = constraints.maxHeight;
                              return Stack(
                                children: [
                                  Positioned.fill(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: List.generate(
                                        5,
                                        (_) => Container(
                                          height: 1,
                                          color: const Color(0xFFF1F5F9),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        _MiniBar(
                                          height: h * (item.onTime / maxY),
                                          color: const Color(0xFF16A34A),
                                          loading: loading,
                                        ),
                                        const SizedBox(width: 4),
                                        _MiniBar(
                                          height: h * (item.late / maxY),
                                          color: const Color(0xFFD97706),
                                          loading: loading,
                                        ),
                                        const SizedBox(width: 4),
                                        _MiniBar(
                                          height: h * (item.outOfRange / maxY),
                                          color: const Color(0xFFDC2626),
                                          loading: loading,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.day,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.height,
    required this.color,
    required this.loading,
  });

  final double height;
  final Color color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      width: 10,
      height: height.clamp(8.0, 220.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
    if (!loading) {
      return bar;
    }
    return _PulsingOpacity(child: bar);
  }
}

class _PulsingOpacity extends StatefulWidget {
  const _PulsingOpacity({required this.child});

  final Widget child;

  @override
  State<_PulsingOpacity> createState() => _PulsingOpacityState();
}

class _PulsingOpacityState extends State<_PulsingOpacity>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1).animate(_controller),
      child: widget.child,
    );
  }
}

class _DashedBorderButton extends StatelessWidget {
  const _DashedBorderButton({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(color: const Color(0xFFCBD5E1), radius: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: child,
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dashWidth)
            .clamp(0.0, metric.length)
            .toDouble();
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _SkeletonCell extends StatefulWidget {
  const _SkeletonCell({required this.width});

  final double width;

  @override
  State<_SkeletonCell> createState() => _SkeletonCellState();
}

class _SkeletonCellState extends State<_SkeletonCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
      child: Container(
        width: widget.width,
        height: 12,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        children: [
          _SkeletonCell(width: 34),
          SizedBox(width: 10),
          Expanded(child: _SkeletonCell(width: 120)),
          SizedBox(width: 10),
          _SkeletonCell(width: 8),
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

class _ShellNavEntry {
  const _ShellNavEntry({
    required this.nav,
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });

  final _AdminShellNav nav;
  final IconData icon;
  final String label;
  final int badgeCount;
}

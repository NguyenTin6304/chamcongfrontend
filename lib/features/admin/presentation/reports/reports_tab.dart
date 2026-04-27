import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:birdle/core/download/file_downloader.dart';
import 'package:birdle/core/storage/token_storage.dart';
import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/widgets/common/kpi_card.dart';
import 'package:birdle/widgets/common/status_badge.dart';
import 'package:birdle/features/admin/data/admin_api.dart';
import 'package:birdle/features/admin/data/admin_data_cache.dart';

part 'widgets/reports_monthly_panel.dart';
part 'widgets/reports_filter_card.dart';
part 'widgets/reports_trend_card.dart';
part 'widgets/reports_donut_card.dart';
part 'widgets/reports_top_late_card.dart';
part 'widgets/reports_group_perf_card.dart';
part 'widgets/reports_heatmap_card.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  final _tokenStorage = TokenStorage();
  final _adminApi = const AdminApi();

  String? _token;
  List<GroupLite> _groups = const [];
  List<DashboardWeeklyTrendItem> _reportsTrends = const [];
  List<DashboardAttendanceLogItem> _reportsLogs = const [];
  List<DashboardAttendanceLogItem> _reportsLateTop = const [];

  // ── Sub-tab ───────────────────────────────────────────────────────────────
  int _activeSubTab = 0; // 0 = Chi tiết, 1 = Bảng chấm công

  // ── Chi tiết tab state ────────────────────────────────────────────────────
  DateTime _reportsMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int? _reportsGroupId;
  String _reportsStatus = 'all';
  String _reportsTrendPeriod = 'day';

  bool _loadingReportsTrends = false;
  bool _loadingReportsLogs = false;
  bool _loadingReportsLateTop = false;
  bool _exportingReportsExcel = false;

  // ── Bảng chấm công tab state ──────────────────────────────────────────────
  int _monthlyMonth = DateTime.now().month;
  int _monthlyYear  = DateTime.now().year;
  int? _monthlyGroupId;
  bool _exportingMonthly = false;

  // Memoisation caches
  List<_ReportCountItem>? _cachedTopLateItems;
  List<DashboardAttendanceLogItem>? _cachedTopLateLogsRef;
  List<DashboardAttendanceLogItem>? _cachedTopLateLateTopRef;
  List<_ReportGroupPerformanceItem>? _cachedGroupPerformanceItems;
  List<DashboardAttendanceLogItem>? _cachedGroupPerfLogsRef;
  Map<DateTime, int>? _cachedHeatmapCounts;
  List<DashboardAttendanceLogItem>? _cachedHeatmapLogsRef;
  DateTime? _cachedHeatmapMonth;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (!mounted) return;
    setState(() => _token = token);
    if (token == null || token.isEmpty) return;
    await Future.wait([
      _loadGroups(token),
      _loadReportsTrends(token),
      _loadReportsLogs(token),
      _loadReportsTopLate(token),
    ]);
  }

  DateTime get _reportsFromDate =>
      DateTime(_reportsMonth.year, _reportsMonth.month, 1);

  DateTime get _reportsToDate =>
      DateTime(_reportsMonth.year, _reportsMonth.month + 1, 0);

  Future<void> _loadGroups(String token) async {
    try {
      final groups = await _adminApi.listGroups(token);
      if (!mounted) return;
      setState(() {
        _groups = groups;
        if (_reportsGroupId != null &&
            !_groups.any((g) => g.id == _reportsGroupId)) {
          _reportsGroupId = null;
        }
      });
    } on UnauthorizedException {
      AdminDataCache.instance.sessionExpired.value = true;
    } on Object catch (_) {}
  }

  Future<void> _loadReportsTrends(String token) async {
    setState(() => _loadingReportsTrends = true);
    try {
      final data = await _adminApi.getDashboardWeeklyTrends(
        token: token,
        date: _reportsToDate,
        groupId: _reportsGroupId,
        status: _reportsStatus,
        period: _reportsTrendPeriod,
      );
      if (!mounted) return;
      setState(() => _reportsTrends = data);
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _reportsTrends = const []);
      _showSnack('Không thể tải xu hướng chấm công.');
    } finally {
      if (mounted) setState(() => _loadingReportsTrends = false);
    }
  }

  Future<void> _loadReportsLogs(String token) async {
    setState(() => _loadingReportsLogs = true);
    try {
      final result = await _adminApi.listDashboardAttendanceLogs(
        token: token,
        fromDate: _reportsFromDate,
        toDate: _reportsToDate,
        groupId: _reportsGroupId,
        status: _reportsStatus,
        limit: 4000,
      );
      if (!mounted) return;
      setState(() => _reportsLogs = result.items);
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _reportsLogs = const []);
      _showSnack('Không thể tải dữ liệu báo cáo.');
    } finally {
      if (mounted) setState(() => _loadingReportsLogs = false);
    }
  }

  Future<void> _loadReportsTopLate(String token) async {
    setState(() => _loadingReportsLateTop = true);
    try {
      final result = await _adminApi.listDashboardAttendanceLogs(
        token: token,
        fromDate: _reportsFromDate,
        toDate: _reportsToDate,
        groupId: _reportsGroupId,
        status: 'late',
        sort: 'count',
        limit: 5,
      );
      if (!mounted) return;
      setState(() => _reportsLateTop = result.items);
    } on Object catch (_) {
      if (!mounted) return;
      setState(() => _reportsLateTop = const []);
      _showSnack('Không thể tải top nhân viên vào muộn.');
    } finally {
      if (mounted) setState(() => _loadingReportsLateTop = false);
    }
  }

  Future<void> _onReportsFilterChanged() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await Future.wait([
      _loadReportsTrends(token),
      _loadReportsLogs(token),
      _loadReportsTopLate(token),
    ]);
  }

  Future<void> _onReportsTrendPeriodChanged(String period) async {
    setState(() => _reportsTrendPeriod = period);
    final token = _token;
    if (token == null || token.isEmpty) return;
    await _loadReportsTrends(token);
  }

  Future<void> _shiftReportsMonth(int delta) async {
    setState(() {
      _reportsMonth =
          DateTime(_reportsMonth.year, _reportsMonth.month + delta);
    });
    await _onReportsFilterChanged();
  }

  Future<void> _exportReportsExcel() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _showSnack('Phiên đăng nhập đã hết hạn.');
      return;
    }
    setState(() => _exportingReportsExcel = true);
    try {
      final report = await _adminApi.downloadAttendanceReport(
        token: token,
        fromDate: _reportsFromDate,
        toDate: _reportsToDate,
        groupId: _reportsGroupId,
      );
      await saveBytesAsFile(bytes: report.bytes, fileName: report.fileName);
      if (!mounted) return;
      _showSnack('Xuất báo cáo Excel thành công.');
    } on Object catch (_) {
      if (!mounted) return;
      _showSnack('Không thể xuất báo cáo Excel. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _exportingReportsExcel = false);
    }
  }

  Future<void> _exportMonthlyExcel() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _showSnack('Phiên đăng nhập đã hết hạn.');
      return;
    }
    setState(() => _exportingMonthly = true);
    try {
      final result = await _adminApi.downloadMonthlyAttendance(
        token: token,
        month: _monthlyMonth,
        year: _monthlyYear,
        groupId: _monthlyGroupId,
      );
      await saveBytesAsFile(bytes: result.bytes, fileName: result.fileName);
      if (!mounted) return;
      _showSnack('Xuất bảng chấm công thành công.');
    } on Exception catch (_) {
      if (!mounted) return;
      _showSnack('Không thể xuất bảng chấm công. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _exportingMonthly = false);
    }
  }

  void _shiftMonthlyMonth(int delta) {
    setState(() {
      var m = _monthlyMonth + delta;
      var y = _monthlyYear;
      if (m > 12) { m = 1;  y++; }
      if (m < 1)  { m = 12; y--; }
      _monthlyMonth = m;
      _monthlyYear  = y;
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _formatPercent(double value) =>
      value.toStringAsFixed(1).replaceAll('.0', '');

  String _formatThousands(int value) {
    final chars = value.toString().split('');
    final out = <String>[];
    for (var i = 0; i < chars.length; i++) {
      out.add(chars[i]);
      final remain = chars.length - i - 1;
      if (remain > 0 && remain % 3 == 0) out.add('.');
    }
    return out.join();
  }

  double _parseTotalHours(String value) {
    final raw = value.trim();
    if (raw.isEmpty || raw == '--') return 0;
    if (raw.contains(':')) {
      final parts = raw.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        return h + (m / 60);
      }
    }
    final stripped = raw.replaceAll(RegExp(r'[hH]$'), '').trim();
    final parsed = double.tryParse(stripped.replaceAll(',', '.')) ?? 0;
    return parsed < 0 ? 0 : parsed;
  }

  double _reportsTotalHours() {
    var total = 0.0;
    for (final row in _reportsLogs) {
      total += _parseTotalHours(row.totalHours);
    }
    return total;
  }

  int _countByBadgeType(
    List<DashboardAttendanceLogItem> rows,
    StatusBadgeType type,
  ) {
    return rows
        .where((row) => _badgeTypeForStatus(row.attendanceStatus) == type)
        .length;
  }

  StatusBadgeType _badgeTypeForStatus(String status) =>
      _badgeTypeForStatusS(status);

  static StatusBadgeType _badgeTypeForStatusS(String status) {
    final n = status.toLowerCase();
    if (n.contains('late')) return StatusBadgeType.late;
    if (n.contains('early')) return StatusBadgeType.early;
    if (n.contains('overtime') || n.contains('ot')) {
      return StatusBadgeType.overtime;
    }
    if (n.contains('out')) return StatusBadgeType.outOfRange;
    if (n.contains('exception')) return StatusBadgeType.exception;
    return StatusBadgeType.onTime;
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  List<DropdownMenuItem<int?>> _groupItems() {
    return [
      const DropdownMenuItem<int?>(value: null, child: Text('Tất cả nhóm')),
      for (final g in _groups)
        DropdownMenuItem<int?>(value: g.id, child: Text(g.name)),
    ];
  }

  Color _heatmapCellColor({required double ratio, required bool weekend}) {
    if (ratio <= 0) {
      return weekend
          ? AppColors.textMuted.withValues(alpha: 0.14)
          : AppColors.bgPage;
    }
    final base = Color.lerp(
      AppColors.bgPage,
      AppColors.success.withValues(alpha: 0.95),
      ratio.clamp(0, 1),
    )!;
    if (!weekend) return base;
    return Color.lerp(base, AppColors.textMuted.withValues(alpha: 0.25), 0.2)!;
  }

  // ── Memoised computations ─────────────────────────────────────────────────

  List<_ReportCountItem> _reportsTopLateItems() {
    if (_cachedTopLateItems != null &&
        identical(_cachedTopLateLogsRef, _reportsLogs) &&
        identical(_cachedTopLateLateTopRef, _reportsLateTop)) {
      return _cachedTopLateItems!;
    }
    final result = _computeTopLateItems(_reportsLogs, _reportsLateTop);
    _cachedTopLateLogsRef = _reportsLogs;
    _cachedTopLateLateTopRef = _reportsLateTop;
    _cachedTopLateItems = result;
    return result;
  }

  static List<_ReportCountItem> _computeTopLateItems(
    List<DashboardAttendanceLogItem> logs,
    List<DashboardAttendanceLogItem> lateTop,
  ) {
    final source = lateTop.isNotEmpty
        ? lateTop
        : logs
              .where(
                (row) =>
                    _badgeTypeForStatusS(row.attendanceStatus) ==
                    StatusBadgeType.late,
              )
              .toList(growable: false);
    final map = <String, _ReportCountItem>{};
    for (final row in source) {
      final key = '${row.employeeCode}_${row.employeeName}';
      final current = map[key];
      final nextCount = row.entryCount ?? 1;
      if (current == null) {
        map[key] = _ReportCountItem(
          name: row.employeeName,
          code: row.employeeCode,
          count: nextCount,
        );
      } else {
        map[key] = _ReportCountItem(
          name: current.name,
          code: current.code,
          count: current.count + nextCount,
        );
      }
    }
    final list = map.values.toList(growable: false);
    list.sort((a, b) => b.count.compareTo(a.count));
    return list.take(5).toList(growable: false);
  }

  List<_ReportGroupPerformanceItem> _reportsGroupPerformanceItems() {
    if (_cachedGroupPerformanceItems != null &&
        identical(_cachedGroupPerfLogsRef, _reportsLogs)) {
      return _cachedGroupPerformanceItems!;
    }
    final result = _computeGroupPerformanceItems(_reportsLogs);
    _cachedGroupPerfLogsRef = _reportsLogs;
    _cachedGroupPerformanceItems = result;
    return result;
  }

  static List<_ReportGroupPerformanceItem> _computeGroupPerformanceItems(
    List<DashboardAttendanceLogItem> logs,
  ) {
    final map = <String, _ReportGroupPerformanceItem>{};
    for (final row in logs) {
      final key = row.departmentName.trim().isEmpty
          ? 'Chưa xác định'
          : row.departmentName;
      final type = _badgeTypeForStatusS(row.attendanceStatus);
      final current =
          map[key] ??
          _ReportGroupPerformanceItem(
            groupName: key,
            onTime: 0,
            late: 0,
            outOfRange: 0,
          );
      map[key] = current.copyWith(
        onTime: current.onTime + (type == StatusBadgeType.onTime ? 1 : 0),
        late: current.late + (type == StatusBadgeType.late ? 1 : 0),
        outOfRange:
            current.outOfRange +
            (type == StatusBadgeType.outOfRange ? 1 : 0),
      );
    }
    final rows = map.values.toList(growable: false);
    rows.sort((a, b) => b.total.compareTo(a.total));
    return rows.take(6).toList(growable: false);
  }

  Map<DateTime, int> _reportsHeatmapCounts() {
    if (_cachedHeatmapCounts != null &&
        identical(_cachedHeatmapLogsRef, _reportsLogs) &&
        _cachedHeatmapMonth == _reportsMonth) {
      return _cachedHeatmapCounts!;
    }
    final result = _computeHeatmapCounts(_reportsLogs, _reportsMonth);
    _cachedHeatmapLogsRef = _reportsLogs;
    _cachedHeatmapMonth = _reportsMonth;
    _cachedHeatmapCounts = result;
    return result;
  }

  static Map<DateTime, int> _computeHeatmapCounts(
    List<DashboardAttendanceLogItem> logs,
    DateTime month,
  ) {
    final map = <DateTime, int>{};
    for (final row in logs) {
      final date = row.workDate;
      if (date == null) continue;
      if (date.year != month.year || date.month != month.month) continue;
      final key = DateTime(date.year, date.month, date.day);
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalLogs = _reportsLogs.length;
    final onTimeCount = _countByBadgeType(_reportsLogs, StatusBadgeType.onTime);
    final lateCount = _countByBadgeType(_reportsLogs, StatusBadgeType.late);
    final outOfRangeCount =
        _reportsLogs.where((r) => r.locationStatus == 'outside').length;
    final overtimeCount =
        _countByBadgeType(_reportsLogs, StatusBadgeType.overtime);
    final onTimeRate =
        totalLogs == 0 ? 0.0 : (onTimeCount * 100 / totalLogs);
    final outOfRangeRate =
        totalLogs == 0 ? 0.0 : (outOfRangeCount * 100 / totalLogs);
    final reportsTotalHours = _reportsTotalHours();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubTabBar(),
        const SizedBox(height: 16),
        if (_activeSubTab == 0) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: KpiCard(
                  label: 'Tổng lượt',
                  value: _loadingReportsLogs ? '--' : _formatThousands(totalLogs),
                  icon: Icons.fact_check_outlined,
                  iconColor: AppColors.primary,
                  valueColor: AppColors.primary,
                  loading: _loadingReportsLogs,
                ),
              ),
              SizedBox(
                width: 220,
                child: KpiCard(
                  label: 'Tỷ lệ đúng giờ',
                  value: _loadingReportsLogs
                      ? '--'
                      : '${_formatPercent(onTimeRate)}%',
                  icon: Icons.check_circle_outline,
                  iconColor: AppColors.success,
                  valueColor: AppColors.success,
                  loading: _loadingReportsLogs,
                ),
              ),
              SizedBox(
                width: 220,
                child: KpiCard(
                  label: 'Tổng giờ làm',
                  value: _loadingReportsLogs
                      ? '--'
                      : _formatPercent(reportsTotalHours),
                  icon: Icons.timer_outlined,
                  iconColor: AppColors.warning,
                  valueColor: AppColors.warning,
                  loading: _loadingReportsLogs,
                ),
              ),
              SizedBox(
                width: 220,
                child: KpiCard(
                  label: 'Tăng ca',
                  value: _loadingReportsLogs
                      ? '--'
                      : _formatThousands(overtimeCount),
                  icon: Icons.bolt_outlined,
                  iconColor: AppColors.overtime,
                  valueColor: AppColors.overtime,
                  loading: _loadingReportsLogs,
                ),
              ),
              SizedBox(
                width: 220,
                child: KpiCard(
                  label: 'Ngoài vùng',
                  value: _loadingReportsLogs
                      ? '--'
                      : '${_formatPercent(outOfRangeRate)}%',
                  icon: Icons.location_off_outlined,
                  iconColor: AppColors.danger,
                  valueColor: AppColors.danger,
                  loading: _loadingReportsLogs,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFilterCard(),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 1040) {
                return Column(
                  children: [
                    _buildTrendCard(),
                    const SizedBox(height: 16),
                    _buildStatusDonutCard(
                      onTimeCount: onTimeCount,
                      lateCount: lateCount,
                      outOfRangeCount: outOfRangeCount,
                      overtimeCount: overtimeCount,
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: _buildTrendCard()),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: _buildStatusDonutCard(
                      onTimeCount: onTimeCount,
                      lateCount: lateCount,
                      outOfRangeCount: outOfRangeCount,
                      overtimeCount: overtimeCount,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 1040) {
                return Column(
                  children: [
                    _buildTopLateCard(),
                    const SizedBox(height: 16),
                    _buildGroupPerformanceCard(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildTopLateCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildGroupPerformanceCard()),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _buildHeatmapCard(),
        ] else
          _buildMonthlyExportPanel(),
      ],
    );
  }

  Widget _buildSubTabBar() {
    const tabs = [('Chi tiết', 0), ('Bảng chấm công', 1)];
    return Row(
      children: tabs.map((tab) {
        final active = _activeSubTab == tab.$2;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => setState(() => _activeSubTab = tab.$2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.bgPage,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                tab.$1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.bgCard : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

// ── Private data models ───────────────────────────────────────────────────────

class _ReportCountItem {
  const _ReportCountItem({
    required this.name,
    required this.code,
    required this.count,
  });

  final String name;
  final String code;
  final int count;
}

class _ReportGroupPerformanceItem {
  const _ReportGroupPerformanceItem({
    required this.groupName,
    required this.onTime,
    required this.late,
    required this.outOfRange,
  });

  final String groupName;
  final int onTime;
  final int late;
  final int outOfRange;

  int get total => onTime + late + outOfRange;

  _ReportGroupPerformanceItem copyWith({
    int? onTime,
    int? late,
    int? outOfRange,
  }) {
    return _ReportGroupPerformanceItem(
      groupName: groupName,
      onTime: onTime ?? this.onTime,
      late: late ?? this.late,
      outOfRange: outOfRange ?? this.outOfRange,
    );
  }
}

class _DonutSegmentData {
  const _DonutSegmentData({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;
}

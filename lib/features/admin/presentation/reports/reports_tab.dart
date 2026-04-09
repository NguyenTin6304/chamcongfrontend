import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/download/file_downloader.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../widgets/common/kpi_card.dart';
import '../../../../widgets/common/status_badge.dart';
import '../../data/admin_api.dart';

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
  DashboardSummaryResult? _reportsSummary;
  List<DashboardWeeklyTrendItem> _reportsTrends = const [];
  List<DashboardAttendanceLogItem> _reportsLogs = const [];
  List<DashboardAttendanceLogItem> _reportsLateTop = const [];

  DateTime _reportsMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int? _reportsGroupId;
  String _reportsStatus = 'all';
  String _reportsTrendPeriod = 'day';

  bool _loadingReportsSummary = false;
  bool _loadingReportsTrends = false;
  bool _loadingReportsLogs = false;
  bool _loadingReportsLateTop = false;
  bool _exportingReportsExcel = false;

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
      _loadReportsSummary(token),
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
    } catch (_) {}
  }

  Future<void> _loadReportsSummary(String token) async {
    setState(() => _loadingReportsSummary = true);
    try {
      final data = await _adminApi.getDashboardSummary(
        token: token,
        date: _reportsFromDate,
        groupId: _reportsGroupId,
        status: _reportsStatus,
      );
      if (!mounted) return;
      setState(() => _reportsSummary = data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _reportsSummary = null);
      _showSnack('Không thể tải tổng quan báo cáo.');
    } finally {
      if (mounted) setState(() => _loadingReportsSummary = false);
    }
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
    } catch (_) {
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
    } catch (_) {
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
    } catch (_) {
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
      _loadReportsSummary(token),
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
    } catch (_) {
      if (!mounted) return;
      _showSnack('Không thể xuất báo cáo Excel. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _exportingReportsExcel = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

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
    return double.tryParse(raw.replaceAll(',', '.')) ?? 0;
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

  // ── Memoised computations ────────────────────────────────────────────────

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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final summary = _reportsSummary;
    final totalLogs = _reportsLogs.length;
    final onTimeCount = _countByBadgeType(_reportsLogs, StatusBadgeType.onTime);
    final lateCount = _countByBadgeType(_reportsLogs, StatusBadgeType.late);
    final outOfRangeCount =
        _countByBadgeType(_reportsLogs, StatusBadgeType.outOfRange);
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
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 220,
              child: KpiCard(
                label: 'Tổng lượt',
                value: _loadingReportsSummary
                    ? '--'
                    : _formatThousands(summary?.checkedIn ?? totalLogs),
                icon: Icons.fact_check_outlined,
                iconColor: AppColors.primary,
                valueColor: AppColors.primary,
                loading: _loadingReportsSummary,
              ),
            ),
            SizedBox(
              width: 220,
              child: KpiCard(
                label: 'Tỷ lệ đúng giờ',
                value: _loadingReportsSummary
                    ? '--'
                    : '${_formatPercent(summary?.attendanceRatePercent ?? onTimeRate)}%',
                icon: Icons.check_circle_outline,
                iconColor: AppColors.success,
                valueColor: AppColors.success,
                loading: _loadingReportsSummary,
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
                value: _loadingReportsSummary
                    ? '--'
                    : '${_formatPercent(outOfRangeRate)}%',
                icon: Icons.location_off_outlined,
                iconColor: AppColors.danger,
                valueColor: AppColors.danger,
                loading: _loadingReportsSummary,
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
      ],
    );
  }

  Widget _buildFilterCard() {
    final monthLabel = DateFormat('MM/yyyy').format(_reportsMonth);
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _shiftReportsMonth(-1),
                  icon: const Icon(Icons.chevron_left, size: 18),
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                Text(
                  monthLabel,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: () => _shiftReportsMonth(1),
                  icon: const Icon(Icons.chevron_right, size: 18),
                  constraints:
                      const BoxConstraints(minWidth: 28, minHeight: 28),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 250,
            child: DropdownButtonFormField<int?>(
              key: ValueKey<int?>(_reportsGroupId),
              initialValue: _reportsGroupId,
              decoration: _decoration('Nhóm', Icons.group_outlined),
              items: _groupItems(),
              onChanged: (value) {
                setState(() => _reportsGroupId = value);
                _onReportsFilterChanged();
              },
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              key: ValueKey<String>(_reportsStatus),
              initialValue: _reportsStatus,
              decoration: _decoration('Trạng thái', Icons.rule_outlined),
              items: const [
                DropdownMenuItem<String>(
                  value: 'all',
                  child: Text('Tất cả'),
                ),
                DropdownMenuItem<String>(
                  value: 'on_time',
                  child: Text('Đúng giờ'),
                ),
                DropdownMenuItem<String>(
                  value: 'late',
                  child: Text('Vào muộn'),
                ),
                DropdownMenuItem<String>(
                  value: 'out_of_range',
                  child: Text('Ngoài vùng'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _reportsStatus = value);
                _onReportsFilterChanged();
              },
            ),
          ),
          ElevatedButton.icon(
            onPressed: _exportingReportsExcel ? null : _exportReportsExcel,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: _exportingReportsExcel
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_outlined),
            label: const Text('Xuất báo cáo Excel'),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendCard() {
    const periodTabs = <(String, String)>[
      ('day', 'Ngày'),
      ('week', 'Tuần'),
      ('month', 'Tháng'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Xu hướng chấm công',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              Wrap(
                spacing: 6,
                children: periodTabs
                    .map((tab) {
                      final active = _reportsTrendPeriod == tab.$1;
                      return InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => _onReportsTrendPeriodChanged(tab.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primary
                                : AppColors.bgPage,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            tab.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: active
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              _LegendDot(color: AppColors.success, label: 'Đúng giờ'),
              SizedBox(width: 12),
              _LegendDot(color: AppColors.warning, label: 'Vào muộn'),
              SizedBox(width: 12),
              _LegendDot(color: AppColors.danger, label: 'Ngoài vùng'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: RepaintBoundary(
              child: _ReportsLineChart(
                data: _reportsTrends,
                loading: _loadingReportsTrends,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDonutCard({
    required int onTimeCount,
    required int lateCount,
    required int outOfRangeCount,
    required int overtimeCount,
  }) {
    final total = onTimeCount + lateCount + outOfRangeCount + overtimeCount;
    final segments = [
      _DonutSegmentData(
        label: 'Đúng giờ',
        count: onTimeCount,
        color: AppColors.success,
      ),
      _DonutSegmentData(
        label: 'Vào muộn',
        count: lateCount,
        color: AppColors.warning,
      ),
      _DonutSegmentData(
        label: 'Ngoài vùng',
        count: outOfRangeCount,
        color: AppColors.danger,
      ),
      _DonutSegmentData(
        label: 'Tăng ca',
        count: overtimeCount,
        color: AppColors.overtime,
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Phân bổ trạng thái',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 10),
          Center(
            child: RepaintBoundary(
              child: SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size.square(190),
                      painter: _DonutChartPainter(
                        segments: segments,
                        total: total,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatThousands(total),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'Tổng lượt',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...segments.map((segment) {
            final percent =
                total == 0 ? 0.0 : (segment.count * 100 / total);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: segment.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      segment.label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '${_formatPercent(percent)}% (${_formatThousands(segment.count)})',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTopLateCard() {
    final rows = _reportsTopLateItems();
    final maxCount =
        rows.isEmpty ? 1 : rows.map((e) => e.count).reduce(math.max);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top nhân viên đi muộn',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (_loadingReportsLateTop)
            const LinearProgressIndicator(minHeight: 2)
          else if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Chưa có dữ liệu đi muộn trong tháng này.'),
            )
          else
            ...rows.map((row) {
              final ratio = row.count / maxCount;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${row.name} (${row.code})',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${row.count} lượt',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        color: AppColors.warning,
                        backgroundColor: AppColors.bgPage,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildGroupPerformanceCard() {
    final rows = _reportsGroupPerformanceItems();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hiệu suất theo nhóm',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          if (_loadingReportsLogs)
            const LinearProgressIndicator(minHeight: 2)
          else if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Chưa có dữ liệu nhóm trong tháng này.'),
            )
          else
            ...rows.map((row) {
              final total = row.total == 0 ? 1 : row.total;
              final onTimeRatio = row.onTime / total;
              final lateRatio = row.late / total;
              final outRatio = row.outOfRange / total;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.groupName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Row(
                        children: [
                          Expanded(
                            flex: (onTimeRatio * 1000).round().clamp(0, 1000),
                            child: Container(
                              height: 10,
                              color: AppColors.success,
                            ),
                          ),
                          Expanded(
                            flex: (lateRatio * 1000).round().clamp(0, 1000),
                            child: Container(
                              height: 10,
                              color: AppColors.warning,
                            ),
                          ),
                          Expanded(
                            flex: (outRatio * 1000).round().clamp(0, 1000),
                            child: Container(
                              height: 10,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Đúng giờ ${row.onTime} · Vào muộn ${row.late} · Ngoài vùng ${row.outOfRange}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildHeatmapCard() {
    final counts = _reportsHeatmapCounts();
    final firstDay = DateTime(_reportsMonth.year, _reportsMonth.month, 1);
    final lastDay = DateTime(_reportsMonth.year, _reportsMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final offset = firstDay.weekday - DateTime.monday;
    final totalCells = (((offset + daysInMonth) / 7).ceil()) * 7;
    final maxCount = counts.isEmpty ? 1 : counts.values.reduce(math.max);
    const weekdayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mật độ chấm công',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: weekdayLabels
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
          if (_loadingReportsLogs)
            const LinearProgressIndicator(minHeight: 2)
          else
            RepaintBoundary(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: totalCells,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1.9,
                ),
                itemBuilder: (context, index) {
                  final day = index - offset + 1;
                  if (day <= 0 || day > daysInMonth) {
                    return const SizedBox.shrink();
                  }
                  final date = DateTime(
                    _reportsMonth.year,
                    _reportsMonth.month,
                    day,
                  );
                  final count = counts[date] ?? 0;
                  final weekend =
                      date.weekday == DateTime.saturday ||
                      date.weekday == DateTime.sunday;
                  final ratio = count / maxCount;
                  final color =
                      _heatmapCellColor(ratio: ratio, weekend: weekend);
                  final message =
                      '${DateFormat('dd/MM/yyyy').format(date)}: $count lượt';
                  return Tooltip(
                    message: message,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _showSnack(message),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: weekend
                                ? AppColors.textMuted.withValues(alpha: 0.25)
                                : AppColors.border,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontSize: weekend ? 10 : 11,
                              fontWeight: FontWeight.w600,
                              color: weekend
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Private data models ──────────────────────────────────────────────────────

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

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({required this.segments, required this.total});

  final List<_DonutSegmentData> segments;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.min(size.width, size.height) * 0.17;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: math.min(size.width, size.height) / 2 - stroke / 2,
    );
    final bgPaint = Paint()
      ..color = AppColors.bgPage
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, bgPaint);

    if (total <= 0) return;

    var start = -math.pi / 2;
    for (final segment in segments) {
      if (segment.count <= 0) continue;
      final sweep = (segment.count / total) * math.pi * 2;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    if (oldDelegate.total != total ||
        oldDelegate.segments.length != segments.length) {
      return true;
    }
    for (var i = 0; i < segments.length; i++) {
      if (segments[i].count != oldDelegate.segments[i].count ||
          segments[i].color != oldDelegate.segments[i].color) {
        return true;
      }
    }
    return false;
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

class _ReportsLineChart extends StatelessWidget {
  const _ReportsLineChart({required this.data, required this.loading});

  final List<DashboardWeeklyTrendItem> data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final chartData = loading
        ? const [
            DashboardWeeklyTrendItem(
              day: '1',
              onTime: 40,
              late: 20,
              outOfRange: 10,
            ),
            DashboardWeeklyTrendItem(
              day: '2',
              onTime: 35,
              late: 16,
              outOfRange: 9,
            ),
            DashboardWeeklyTrendItem(
              day: '3',
              onTime: 50,
              late: 14,
              outOfRange: 8,
            ),
            DashboardWeeklyTrendItem(
              day: '4',
              onTime: 42,
              late: 18,
              outOfRange: 10,
            ),
            DashboardWeeklyTrendItem(
              day: '5',
              onTime: 56,
              late: 15,
              outOfRange: 6,
            ),
          ]
        : data;

    if (!loading && chartData.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Không có dữ liệu xu hướng.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    final labelStride = chartData.length > 16
        ? 5
        : chartData.length > 10
            ? 2
            : 1;

    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, width: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: CustomPaint(
              painter: _ReportsLineChartPainter(
                data: chartData,
                loading: loading,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: chartData.asMap().entries
              .map(
                (entry) => Expanded(
                  child: Center(
                    child: Text(
                      entry.key % labelStride == 0 ||
                              entry.key == chartData.length - 1
                          ? entry.value.day
                          : '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _ReportsLineChartPainter extends CustomPainter {
  _ReportsLineChartPainter({required this.data, required this.loading});

  final List<DashboardWeeklyTrendItem> data;
  final bool loading;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.bgPage
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = (size.height - 16) * (i / 4) + 8;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (data.isEmpty) return;
    final maxValue = data
        .map((e) => math.max(e.onTime, math.max(e.late, e.outOfRange)))
        .reduce(math.max)
        .toDouble()
        .clamp(10, 1000)
        .toDouble();

    final onTimePoints = <Offset>[];
    final latePoints = <Offset>[];
    final outPoints = <Offset>[];

    final stepX = data.length <= 1 ? 0.0 : size.width / (data.length - 1);
    for (var i = 0; i < data.length; i++) {
      final x = data.length == 1 ? size.width / 2 : stepX * i;
      onTimePoints.add(
        Offset(
          x,
          size.height -
              ((data[i].onTime / maxValue) * (size.height - 16)) -
              8,
        ),
      );
      latePoints.add(
        Offset(
          x,
          size.height -
              ((data[i].late / maxValue) * (size.height - 16)) -
              8,
        ),
      );
      outPoints.add(
        Offset(
          x,
          size.height -
              ((data[i].outOfRange / maxValue) * (size.height - 16)) -
              8,
        ),
      );
    }

    _drawLine(canvas, onTimePoints, AppColors.success, loading);
    _drawLine(canvas, latePoints, AppColors.warning, loading);
    _drawLine(canvas, outPoints, AppColors.danger, loading);
  }

  void _drawLine(
    Canvas canvas,
    List<Offset> points,
    Color color,
    bool loading,
  ) {
    final linePaint = Paint()
      ..color = loading ? color.withValues(alpha: 0.5) : color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = linePaint.color;
    if (points.length == 1) {
      canvas.drawCircle(points.first, 2.5, dotPaint);
      return;
    }
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    for (final point in points) {
      canvas.drawCircle(point, 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ReportsLineChartPainter oldDelegate) {
    return oldDelegate.loading != loading || oldDelegate.data != data;
  }
}

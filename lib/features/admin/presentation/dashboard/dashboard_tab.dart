// ignore_for_file: unused_element, unused_field

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/download/file_downloader.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../widgets/common/kpi_card.dart';
import '../../data/admin_api.dart';
import '../../data/admin_data_cache.dart';
import '../exceptions/widgets/exception_ui_helpers.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({required this.onNavigateTo, super.key});

  final void Function(String section) onNavigateTo;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final _tokenStorage = TokenStorage();
  final _api = const AdminApi();

  String? _token;

  DashboardSummaryResult? _summary;
  List<DashboardAttendanceLogItem> _logs = const [];
  List<DashboardWeeklyTrendItem> _weekly = const [];
  List<DashboardGeofenceItem> _geofences = const [];
  List<DashboardExceptionItem> _exceptions = const [];

  final DateTime _date = DateTime.now();
  DateTime _weeklyMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int? _groupId;
  final String _status = 'all';

  bool _loadingSummary = false;
  bool _loadingLogs = false;
  bool _loadingWeekly = false;
  bool _weeklyError = false;
  bool _loadingGeofences = false;
  bool _loadingExceptions = false;
  bool _exportingCsv = false;

  static const int _dashboardExceptionLimit = 3;
  static const List<String> _dashboardExceptionTypes = <String>[
    'SUSPECTED_LOCATION_SPOOF',
    'AUTO_CLOSED',
    'MISSED_CHECKOUT',
    'LARGE_TIME_DEVIATION',
  ];
  static const List<String> _unresolvedExceptionStatuses = <String>[
    'PENDING_ADMIN',
    'PENDING_EMPLOYEE',
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) return;

    setState(() {
      _token = token;
    });

    await Future.wait<void>([
      AdminDataCache.instance.fetchGroups(token, _api),
      _loadSummary(token),
      _loadLogs(token),
      _loadWeekly(token),
      _loadGeofences(token),
      _loadExceptions(token),
    ]);
  }

  Future<void> _loadSummary(String token) async {
    setState(() {
      _loadingSummary = true;
    });
    try {
      final data = await _api.getDashboardSummary(
        token: token,
        date: _date,
        groupId: _groupId,
        status: _status,
      );
      if (!mounted) return;
      setState(() {
        _summary = data;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _summary = null;
      });
      _showSnack('Không thể tải số liệu tổng quan.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingSummary = false;
        });
      }
    }
  }

  Future<void> _loadLogs(String token) async {
    setState(() {
      _loadingLogs = true;
    });
    try {
      final result = await _api.listDashboardAttendanceLogs(
        token: token,
        fromDate: _date,
        toDate: _date,
        groupId: _groupId,
        status: _status,
        search: '',
        page: 1,
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _logs = result.items;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _logs = const [];
      });
      _showSnack('Không thể tải nhật ký chấm công.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingLogs = false;
        });
      }
    }
  }

  Future<void> _loadWeekly(String token) async {
    setState(() {
      _loadingWeekly = true;
      _weeklyError = false;
    });
    try {
      final rows = await _api.getDashboardWeeklyTrends(
        token: token,
        date: _weeklyMonth,
        groupId: _groupId,
        status: _status,
        period: 'month',
      );
      if (!mounted) return;
      setState(() {
        _weekly = rows;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weekly = const [];
        _weeklyError = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingWeekly = false;
        });
      }
    }
  }

  Future<void> _shiftWeeklyMonth(int delta) async {
    setState(() {
      _weeklyMonth = DateTime(_weeklyMonth.year, _weeklyMonth.month + delta);
    });
    final token = _token;
    if (token == null || token.isEmpty) return;
    await _loadWeekly(token);
  }

  Future<void> _loadGeofences(String token) async {
    setState(() {
      _loadingGeofences = true;
    });
    try {
      final rows = await _api.listDashboardGeofences(token: token);
      if (!mounted) return;
      setState(() {
        _geofences = rows;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _geofences = const [];
      });
      _showSnack('Không thể tải danh sách vùng địa lý.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingGeofences = false;
        });
      }
    }
  }

  Future<void> _loadExceptions(String token) async {
    setState(() {
      _loadingExceptions = true;
    });
    try {
      final rows = await _loadRecentUnresolvedExceptions(token);
      if (!mounted) return;
      setState(() {
        _exceptions = rows;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _exceptions = const [];
      });
      _showSnack('Không thể tải ngoại lệ chờ duyệt.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingExceptions = false;
        });
      }
    }
  }

  Future<List<DashboardExceptionItem>> _loadRecentUnresolvedExceptions(
    String token,
  ) async {
    final requests = <Future<List<AttendanceExceptionItem>>>[];
    for (final status in _unresolvedExceptionStatuses) {
      for (final type in _dashboardExceptionTypes) {
        requests.add(
          _loadExceptionRowsByTypeSafe(
            token: token,
            status: status,
            exceptionType: type,
          ),
        );
      }
    }

    final results = await Future.wait<List<AttendanceExceptionItem>>(requests);
    final merged = <int, AttendanceExceptionItem>{};
    for (final result in results) {
      for (final row in result) {
        merged[row.id] = row;
      }
    }

    final rows = merged.values.toList(growable: false)
      ..sort((a, b) {
        final aTime = a.createdAt ?? a.detectedAt ?? a.workDate;
        final bTime = b.createdAt ?? b.detectedAt ?? b.workDate;
        return bTime.compareTo(aTime);
      });

    return rows
        .take(_dashboardExceptionLimit)
        .map(_mapDashboardException)
        .toList(growable: false);
  }

  Future<List<AttendanceExceptionItem>> _loadExceptionRowsByTypeSafe({
    required String token,
    required String status,
    required String exceptionType,
  }) async {
    try {
      return await _api.listAttendanceExceptions(
        token: token,
        exceptionType: exceptionType,
        statusFilter: status,
      );
    } catch (_) {
      return const <AttendanceExceptionItem>[];
    }
  }

  DashboardExceptionItem _mapDashboardException(AttendanceExceptionItem item) {
    final timeSource = item.detectedAt ?? item.createdAt ?? item.workDate;
    return DashboardExceptionItem(
      id: item.id,
      initials: _nameToInitials(item.fullName),
      name: item.fullName,
      reason: exceptionTypeLabel(item.exceptionType),
      timeLabel: DateFormat('dd/MM HH:mm').format(timeSource.toLocal()),
      status: item.status,
    );
  }

  Future<void> _onFilterChanged() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await Future.wait([
      _loadSummary(token),
      _loadLogs(token),
      _loadWeekly(token),
    ]);
  }

  Future<void> _exportCsv() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _showSnack('Phiên đăng nhập đã hết hạn.');
      return;
    }
    setState(() {
      _exportingCsv = true;
    });
    try {
      final result = await _api.exportDashboardExcel(
        token: token,
        fromDate: _date,
        toDate: _date,
        groupId: _groupId,
        status: _status,
      );
      await saveBytesAsFile(bytes: result.bytes, fileName: result.fileName);
      if (!mounted) return;
      _showSnack('Xuất CSV thành công.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('Không thể xuất CSV. Vui lòng thử lại.');
    } finally {
      if (mounted) {
        setState(() {
          _exportingCsv = false;
        });
      }
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static String _statusLabel(String status) {
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

  static Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'late':
        return AppColors.warning;
      case 'out_of_range':
      case 'outofrange':
      case 'oor':
      case 'absent':
      case 'missing_checkin_anomaly':
        return AppColors.error;
      case 'missed_checkout':
      case 'pending_timesheet':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  static String _formatPercent(double value) {
    return value.toStringAsFixed(1).replaceAll('.0', '');
  }

  static String _format24hTimeLabel(String value) {
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

  static String _formatThousands(int value) {
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

  static String _nameToInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  Widget _buildDashboardContent() {
    final summary = _summary;
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
                valueColor:  AppColors.primary,
                subColor: AppColors.primary,
                icon: Icons.people_outline,
                iconColor: AppColors.primary,
                loading: _loadingSummary,
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
                valueColor:  AppColors.success,
                subColor: AppColors.success,
                icon: Icons.check_circle_outline,
                iconColor: AppColors.success,
                loading: _loadingSummary,
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
                valueColor: AppColors.warning,
                subColor: AppColors.warning,
                icon: Icons.schedule,
                iconColor: AppColors.warning,
                loading: _loadingSummary,
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
                valueColor:  AppColors.danger,
                subColor:  AppColors.danger,
                icon: Icons.location_off,
                iconColor: AppColors.danger,
                loading: _loadingSummary,
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
                valueColor: AppColors.overtime,
                subColor: AppColors.overtime,
                icon: Icons.map_outlined,
                iconColor: AppColors.overtime,
                loading: _loadingSummary,
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
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            if (_loadingLogs) _buildDashboardLogSkeleton(),
            if (!_loadingLogs && _logs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: Text('Chưa có dữ liệu hôm nay')),
              ),
            if (!_loadingLogs && _logs.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    AppColors.surface,
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
                  rows: _logs
                      .map((row) {
                        final statusColor = _statusColor(row.attendanceStatus);
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
                                      color: AppColors.textSecondary,
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
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    inRange ? 'Trong vùng' : 'Ngoài vùng',
                                    style: TextStyle(
                                      color: inRange
                                          ? AppColors.success
                                          : AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              _StatusBadge(
                                label: _statusLabel(row.attendanceStatus),
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
        headingRowColor: WidgetStateProperty.all(AppColors.surface),
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

  Widget _buildWeeklyChartCard() {
    final monthLabel = DateFormat('MM/yyyy').format(_weeklyMonth);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final monthPicker = Container(
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
                        onPressed: _loadingWeekly ? null : () => _shiftWeeklyMonth(-1),
                        icon: const Icon(Icons.chevron_left, size: 18),
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(minWidth: compact ? 64 : 72),
                        child: Text(
                          monthLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _loadingWeekly ? null : () => _shiftWeeklyMonth(1),
                        icon: const Icon(Icons.chevron_right, size: 18),
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                );

                return monthPicker;
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Xu hướng chấm công hàng tháng',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                _LegendDot(color: AppColors.success, label: 'Đúng giờ'),
                SizedBox(width: 14),
                _LegendDot(color: AppColors.warning, label: 'Đi muộn'),
                SizedBox(width: 14),
                _LegendDot(color: AppColors.error, label: 'Ngoài vùng'),
              ],
            ),
            const SizedBox(height: 14),
            _MockWeeklyChart(
              data: _weekly,
              loading: _loadingWeekly,
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
        side: const BorderSide(color: AppColors.border, width: 0.5),
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
                  onPressed: () => widget.onNavigateTo('geofences'),
                  child: const Text('Xem bản đồ →'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loadingGeofences)
              ...List<Widget>.generate(
                3,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: _SkeletonRow(),
                ),
              ),
            if (!_loadingGeofences && _geofences.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('Chưa có khu vực địa lý.'),
              ),
            if (!_loadingGeofences)
              ..._geofences.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
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
                                color: AppColors.textSecondary,
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
                              ? AppColors.success
                              : AppColors.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 4),
            _DashedBorderButton(
              onTap: () => widget.onNavigateTo('geofences'),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 18, color: AppColors.textPrimary),
                  SizedBox(width: 8),
                  Text(
                    'Thêm khu vực mới',
                    style: TextStyle(
                      color: AppColors.textPrimary,
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
        side: const BorderSide(color: AppColors.border, width: 0.5),
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
            if (_loadingExceptions)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (!_loadingExceptions && _exceptions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Không có ngoại lệ chưa được giải quyết.'),
              ),
            if (!_loadingExceptions)
              ..._exceptions.map((item) {
                final palette = exceptionStatusPalette(item.status);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.surface,
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
                                color: AppColors.textSecondary,
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
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(
                        label: exceptionStatusLabel(item.status),
                        backgroundColor: palette.bg,
                        textColor: palette.text,
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => widget.onNavigateTo('exceptions'),
              child: const Text('Xem tất cả ngoại lệ quản trị →'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildDashboardContent();
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    this.color,
    this.backgroundColor,
    this.textColor,
  });

  final String label;
  final Color? color;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final foreground = textColor ?? color ?? AppColors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? foreground.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
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
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final axisWidth = compact ? 32.0 : 36.0;
          final barWidth = compact ? 6.0 : 10.0;
          final barGap = compact ? 2.0 : 4.0;
          final columnPadding = compact ? 2.0 : 6.0;
          final labelFontSize = compact ? 10.0 : 12.0;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: axisWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: yLabels
                      .map(
                        (v) => FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$v',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              SizedBox(width: compact ? 4 : 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, chartConstraints) {
                    final minColumnWidth = chartData.length > 20
                        ? 26.0
                        : chartData.length > 10
                            ? 34.0
                            : (compact ? 44.0 : 56.0);
                    final chartWidth = math.max(
                      chartConstraints.maxWidth,
                      chartData.length * minColumnWidth,
                    );
                    final labelStride = chartData.length > 20
                        ? 5
                        : chartData.length > 12
                            ? 2
                            : 1;

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: chartWidth,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: chartData.asMap().entries.map((entry) {
                            final item = entry.value;
                            final showLabel =
                                entry.key % labelStride == 0 ||
                                entry.key == chartData.length - 1;
                            return SizedBox(
                              width: chartWidth / chartData.length,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: columnPadding),
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
                                                      color: AppColors.border,
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
                                                      width: barWidth,
                                                      height: h * (item.onTime / maxY),
                                                      color: AppColors.success,
                                                      loading: loading,
                                                    ),
                                                    SizedBox(width: barGap),
                                                    _MiniBar(
                                                      width: barWidth,
                                                      height: h * (item.late / maxY),
                                                      color: AppColors.warning,
                                                      loading: loading,
                                                    ),
                                                    SizedBox(width: barGap),
                                                    _MiniBar(
                                                      width: barWidth,
                                                      height: h * (item.outOfRange / maxY),
                                                      color: AppColors.error,
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
                                      showLabel ? item.day : '',
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: labelFontSize,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(growable: false),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
    required this.width,
    required this.height,
    required this.color,
    required this.loading,
  });

  final double width;
  final double height;
  final Color color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      width: width,
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
      painter: _DashedRRectPainter(color: AppColors.borderLight, radius: 10),
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
          color: AppColors.surface,
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
        border: Border.all(color: AppColors.border),
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

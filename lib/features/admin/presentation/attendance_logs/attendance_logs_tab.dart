import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' hide Path;

import 'package:birdle/core/config/app_config.dart';
import 'package:birdle/core/download/file_downloader.dart';
import 'package:birdle/core/storage/token_storage.dart';
import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';
import 'package:birdle/features/admin/data/admin_api.dart';
import 'package:birdle/features/admin/data/admin_data_cache.dart';
import 'package:birdle/widgets/common/kpi_card.dart';
import 'package:birdle/widgets/common/status_badge.dart';

class AttendanceLogsTab extends StatefulWidget {
  const AttendanceLogsTab({super.key});

  @override
  State<AttendanceLogsTab> createState() => _AttendanceLogsTabState();
}

class _AttendanceLogsTabState extends State<AttendanceLogsTab> {
  final _tokenStorage = TokenStorage();
  final _api = const AdminApi();

  String? _token;
  List<GroupLite> _groups = const [];
  List<DashboardAttendanceLogItem> _logs = const [];
  int _serverTotal = 0;
  bool _loading = false;
  bool _exportingCsv = false;

  int? _groupId;
  String _status = 'all';
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  String _search = '';
  int _page = 1;
  int _pageSize = 10;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) return;

    setState(() {
      _token = token;
    });

    await Future.wait([
      AdminDataCache.instance.fetchGroups(token, _api).then((groups) {
        if (!mounted) return;
        setState(() => _groups = groups);
      }),
      _loadLogs(token),
    ]);
  }

  Future<void> _reload() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await _loadLogs(token);
  }

  Future<void> _loadLogs(String token) async {
    setState(() => _loading = true);
    try {
      final result = await _api.listDashboardAttendanceLogs(
        token: token,
        fromDate: _fromDate,
        toDate: _toDate,
        groupId: _groupId,
        status: _status,
        search: _search,
        page: _page,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _logs = result.items;
        _serverTotal = result.total;
      });
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() {
        _logs = const [];
        _serverTotal = 0;
      });
      _showSnack('Không thể tải nhật ký chấm công.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportCsv() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _showSnack('Phiên đăng nhập đã hết hạn.');
      return;
    }
    setState(() => _exportingCsv = true);
    try {
      final report = await _api.downloadAttendanceReport(
        token: token,
        fromDate: _fromDate,
        toDate: _toDate,
        groupId: _groupId,
        status: _status,
        search: _search,
      );
      await saveBytesAsFile(bytes: report.bytes, fileName: report.fileName);
      if (!mounted) return;
      _showSnack('Xuất Excel thành công.');
    } on Exception catch (_) {
      if (!mounted) return;
      _showSnack('Không thể xuất Excel. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _fromDate : _toDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
      } else {
        _toDate = picked;
      }
      if (_fromDate.isAfter(_toDate)) {
        if (isFrom) {
          _toDate = picked;
        } else {
          _fromDate = picked;
        }
      }
      _page = 1;
    });
    await _reload();
  }

  int get _totalCount => _serverTotal;

  int get _totalPages {
    if (_totalCount == 0) return 1;
    return ((_totalCount - 1) ~/ _pageSize) + 1;
  }

  List<DropdownMenuItem<int?>> _groupItems() {
    final items = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(value: null, child: Text('Tất cả nhóm')),
    ];
    for (final g in _groups) {
      items.add(DropdownMenuItem<int?>(value: g.id, child: Text(g.name)));
    }
    return items;
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static StatusBadgeType _badgeTypeForStatus(String status) {
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

  static String _formatThousands(int value) {
    final chars = value.toString().split('');
    final out = <String>[];
    for (var i = 0; i < chars.length; i++) {
      out.add(chars[i]);
      final remain = chars.length - i - 1;
      if (remain > 0 && remain % 3 == 0) out.add('.');
    }
    return out.join();
  }

  static InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: const OutlineInputBorder(borderRadius: AppRadius.cardAll),
    );
  }

  // ── Detail modal ──────────────────────────────────────────────────────────

  Future<void> _showDetailModal(DashboardAttendanceLogItem item) async {
    final hasCheckIn = item.checkInLat != null && item.checkInLng != null;
    final hasCheckOut = item.checkOutLat != null && item.checkOutLng != null;

    // Determine map center and zoom.
    final double centerLat;
    final double centerLng;
    const double zoom = 15;
    if (hasCheckIn && hasCheckOut) {
      centerLat = (item.checkInLat! + item.checkOutLat!) / 2;
      centerLng = (item.checkInLng! + item.checkOutLng!) / 2;
    } else if (hasCheckIn) {
      centerLat = item.checkInLat!;
      centerLng = item.checkInLng!;
    } else if (hasCheckOut) {
      centerLat = item.checkOutLat!;
      centerLng = item.checkOutLng!;
    } else {
      centerLat = AppConfig.defaultMapCenterLat;
      centerLng = AppConfig.defaultMapCenterLng;
    }

    const tileUrl =
        'https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}.png?apiKey=${AppConfig.geoapifyApiKey}';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Chi tiết chấm công'),
          content: SizedBox(
            width: 760,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.employeeName} (${item.employeeCode})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text('Phòng ban: ${item.departmentName}'),
                Text(
                  'Ngày: ${item.workDate == null ? '--' : DateFormat('dd/MM/yyyy').format(item.workDate!)}',
                ),
                const SizedBox(height: 8),
                // Check-in / check-out row with location coords
                Row(
                  children: [
                    const Icon(Icons.login, size: 14, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text('Vào: ${item.checkInTime}'),
                    if (hasCheckIn)
                      Text(
                        '  (${item.checkInLat!.toStringAsFixed(5)}, ${item.checkInLng!.toStringAsFixed(5)})',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.logout, size: 14, color: AppColors.danger),
                    const SizedBox(width: 4),
                    Text('Ra: ${item.checkOutTime}'),
                    if (hasCheckOut)
                      Text(
                        '  (${item.checkOutLat!.toStringAsFixed(5)}, ${item.checkOutLng!.toStringAsFixed(5)})',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Map legend
                if (hasCheckIn || hasCheckOut)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        if (hasCheckIn) ...[
                          const Icon(Icons.location_on,
                              size: 14, color: AppColors.success),
                          const SizedBox(width: 2),
                          const Text('Vào',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.success)),
                          const SizedBox(width: 12),
                        ],
                        if (hasCheckOut) ...[
                          const Icon(Icons.location_on,
                              size: 14, color: AppColors.danger),
                          const SizedBox(width: 2),
                          const Text('Ra',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.danger)),
                        ],
                      ],
                    ),
                  ),
                if (!hasCheckIn && !hasCheckOut)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Không có dữ liệu vị trí GPS',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                ClipRRect(
                  borderRadius: AppRadius.cardAll,
                  child: SizedBox(
                    height: 220,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(centerLat, centerLng),
                        initialZoom: zoom,
                      ),
                      children: [
                        TileLayer(urlTemplate: tileUrl),
                        MarkerLayer(
                          markers: [
                            if (hasCheckIn)
                              Marker(
                                point: LatLng(
                                    item.checkInLat!, item.checkInLng!),
                                width: 36,
                                height: 48,
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _MapLabel(label: 'Vào', color: AppColors.success),
                                    Icon(Icons.location_on,
                                        color: AppColors.success, size: 28),
                                  ],
                                ),
                              ),
                            if (hasCheckOut)
                              Marker(
                                point: LatLng(
                                    item.checkOutLat!, item.checkOutLng!),
                                width: 36,
                                height: 48,
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _MapLabel(label: 'Ra', color: AppColors.danger),
                                    Icon(Icons.location_on,
                                        color: AppColors.danger, size: 28),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatCards(),
        const SizedBox(height: 16),
        _buildFilterCard(),
        const SizedBox(height: 16),
        _buildTableCard(),
      ],
    );
  }

  // ── Stat cards ────────────────────────────────────────────────────────────

  Widget _buildStatCards() {
    final total = _totalCount;
    final onTime = _logs
        .where((e) => _badgeTypeForStatus(e.attendanceStatus) == StatusBadgeType.onTime)
        .length;
    final late = _logs
        .where((e) => _badgeTypeForStatus(e.attendanceStatus) == StatusBadgeType.late)
        .length;
    final outOfRange = _logs
        .where((e) => _badgeTypeForStatus(e.attendanceStatus) == StatusBadgeType.outOfRange)
        .length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 250,
          child: KpiCard(
            label: 'Tổng lượt',
            value: _loading ? '--' : _formatThousands(total),
            icon: Icons.fact_check_outlined,
            iconColor: AppColors.primary,
            valueColor: AppColors.primary,
            loading: _loading,
          ),
        ),
        SizedBox(
          width: 250,
          child: KpiCard(
            label: 'Đúng giờ',
            value: _loading ? '--' : _formatThousands(onTime),
            icon: Icons.check_circle_outline,
            iconColor: AppColors.success,
            valueColor: AppColors.success,
            loading: _loading,
          ),
        ),
        SizedBox(
          width: 250,
          child: KpiCard(
            label: 'Vào muộn',
            value: _loading ? '--' : _formatThousands(late),
            icon: Icons.schedule,
            iconColor: AppColors.warning,
            valueColor: AppColors.warning,
            loading: _loading,
          ),
        ),
        SizedBox(
          width: 250,
          child: KpiCard(
            label: 'Ngoài vùng',
            value: _loading ? '--' : _formatThousands(outOfRange),
            icon: Icons.location_off_outlined,
            iconColor: AppColors.danger,
            valueColor: AppColors.danger,
            loading: _loading,
          ),
        ),
      ],
    );
  }

  // ── Filter bar ────────────────────────────────────────────────────────────

  Widget _buildFilterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: _loading ? null : () => _pickDate(isFrom: true),
            icon: const Icon(Icons.event_outlined),
            label: Text('Từ ${DateFormat('dd/MM/yyyy').format(_fromDate)}'),
          ),
          OutlinedButton.icon(
            onPressed: _loading ? null : () => _pickDate(isFrom: false),
            icon: const Icon(Icons.event_available_outlined),
            label: Text('Đến ${DateFormat('dd/MM/yyyy').format(_toDate)}'),
          ),
          SizedBox(
            width: 250,
            child: DropdownButtonFormField<int?>(
              key: ValueKey<int?>(_groupId),
              initialValue: _groupId,
              decoration: _decoration('Nhóm', Icons.group_outlined),
              items: _groupItems(),
              onChanged: _loading
                  ? null
                  : (value) {
                      setState(() {
                        _groupId = value;
                        _page = 1;
                      });
                      _reload();
                    },
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<String>(
              key: ValueKey<String>(_status),
              initialValue: _status,
              decoration: _decoration('Trạng thái', Icons.rule_outlined),
              items: const [
                DropdownMenuItem<String>(value: 'all', child: Text('Tất cả')),
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
              onChanged: _loading
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _status = value;
                        _page = 1;
                      });
                      _reload();
                    },
            ),
          ),
          SizedBox(
            width: 240,
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) {
                setState(() {
                  _search = _searchController.text.trim();
                  _page = 1;
                });
                _reload();
              },
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Tìm nhân viên...',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: IconButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _search = _searchController.text.trim();
                            _page = 1;
                          });
                          _reload();
                        },
                  icon: const Icon(Icons.search),
                ),
                border: const OutlineInputBorder(
                  borderRadius: AppRadius.iconBoxAll,
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: AppRadius.iconBoxAll,
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _exportingCsv ? null : _exportCsv,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.surface,
            ),
            icon: _exportingCsv
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.surface,
                    ),
                  )
                : const Icon(Icons.download_outlined),
            label: const Text('Xuất Excel'),
          ),
        ],
      ),
    );
  }

  // ── Table card ────────────────────────────────────────────────────────────

  Widget _buildTableCard() {
    final startIndex = (_page - 1) * _pageSize;

    return Card(
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading) _buildSkeleton(),
            if (!_loading && _logs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        color: AppColors.textMuted,
                        size: 28,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Chưa có dữ liệu',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_loading && _logs.isNotEmpty)
              _logs.length > 20
                  ? _buildVirtualizedTable(
                      logs: _logs,
                      startIndex: startIndex,
                    )
                  : _buildDataTable(logs: _logs, startIndex: startIndex),
            const SizedBox(height: 12),
            _buildPagination(),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable({
    required List<DashboardAttendanceLogItem> logs,
    required int startIndex,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.bgPage),
        headingTextStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.04,
        ),
        columns: const [
          DataColumn(label: Text('STT')),
          DataColumn(label: Text('NHÂN VIÊN')),
          DataColumn(label: Text('PHÒNG BAN')),
          DataColumn(label: Text('NGÀY')),
          DataColumn(label: Text('GIỜ VÀO')),
          DataColumn(label: Text('GIỜ RA')),
          DataColumn(label: Text('TỔNG GIỜ')),
          DataColumn(label: Text('TRẠNG THÁI')),
          DataColumn(label: Text('VỊ TRÍ')),
        ],
        rows: logs
            .asMap()
            .entries
            .map((entry) {
              final row = entry.value;
              final badgeType = _badgeTypeForStatus(row.attendanceStatus);
              final isLate = badgeType == StatusBadgeType.late;
              final isOutside = row.locationStatus.contains('out');
              final hasCheckout =
                  row.checkOutTime.trim().isNotEmpty && row.checkOutTime != '--';
              final stt = startIndex + entry.key + 1;

              return DataRow(
                onSelectChanged: (_) => _showDetailModal(row),
                cells: [
                  DataCell(Text('$stt')),
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.bgPage,
                          child: Text(
                            row.employeeName.trim().isNotEmpty
                                ? row.employeeName.trim()[0].toUpperCase()
                                : 'N',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(row.employeeName),
                            Text(
                              row.employeeCode,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text(row.departmentName)),
                  DataCell(
                    Text(
                      row.workDate == null
                          ? '--'
                          : DateFormat('dd/MM/yyyy').format(row.workDate!),
                    ),
                  ),
                  DataCell(
                    Text(
                      row.checkInTime,
                      style: TextStyle(
                        color: isLate ? AppColors.warning : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      hasCheckout ? row.checkOutTime : '--',
                      style: TextStyle(
                        color: hasCheckout
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(row.totalHours.trim().isEmpty ? '--' : row.totalHours),
                  ),
                  DataCell(StatusBadge(type: badgeType)),
                  DataCell(
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: isOutside ? AppColors.danger : AppColors.success,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOutside ? 'Ngoài vùng' : 'Trong vùng',
                          style: TextStyle(
                            color: isOutside
                                ? AppColors.danger
                                : AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            })
            .toList(growable: false),
      ),
    );
  }

  Widget _buildVirtualizedTable({
    required List<DashboardAttendanceLogItem> logs,
    required int startIndex,
  }) {
    const rowHeight = 64.0;
    const tableWidth = 1310.0;
    final maxHeight = (logs.length * rowHeight).clamp(280.0, 460.0).toDouble();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: tableWidth,
        child: Column(
          children: [
            Container(
              color: AppColors.bgPage,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: const Row(
                children: [
                  SizedBox(width: 50, child: _AttendanceHeaderText('STT')),
                  SizedBox(
                    width: 260,
                    child: _AttendanceHeaderText('NHÂN VIÊN'),
                  ),
                  SizedBox(
                    width: 120,
                    child: _AttendanceHeaderText('PHÒNG BAN'),
                  ),
                  SizedBox(width: 95, child: _AttendanceHeaderText('NGÀY')),
                  SizedBox(width: 90, child: _AttendanceHeaderText('GIỜ VÀO')),
                  SizedBox(width: 90, child: _AttendanceHeaderText('GIỜ RA')),
                  SizedBox(
                    width: 90,
                    child: _AttendanceHeaderText('TỔNG GIỜ'),
                  ),
                  SizedBox(
                    width: 120,
                    child: _AttendanceHeaderText('TRẠNG THÁI'),
                  ),
                  SizedBox(width: 120, child: _AttendanceHeaderText('VỊ TRÍ')),
                ],
              ),
            ),
            SizedBox(
              height: maxHeight,
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final row = logs[index];
                  final stt = startIndex + index + 1;
                  final badgeType = _badgeTypeForStatus(row.attendanceStatus);
                  final isLate = badgeType == StatusBadgeType.late;
                  final isOutside = row.locationStatus.contains('out');
                  final hasCheckout =
                      row.checkOutTime.trim().isNotEmpty &&
                      row.checkOutTime != '--';

                  return InkWell(
                    onTap: () => _showDetailModal(row),
                    child: Container(
                    height: rowHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.border,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 50, child: Text('$stt')),
                        SizedBox(
                          width: 260,
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.bgPage,
                                child: Text(
                                  row.employeeName.trim().isNotEmpty
                                      ? row.employeeName.trim()[0].toUpperCase()
                                      : 'N',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      row.employeeName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      row.employeeCode,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            row.departmentName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 95,
                          child: Text(
                            row.workDate == null
                                ? '--'
                                : DateFormat('dd/MM/yyyy').format(row.workDate!),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            row.checkInTime,
                            style: TextStyle(
                              color: isLate
                                  ? AppColors.warning
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            hasCheckout ? row.checkOutTime : '--',
                            style: TextStyle(
                              color: hasCheckout
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 90,
                          child: Text(
                            row.totalHours.trim().isEmpty
                                ? '--'
                                : row.totalHours,
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: StatusBadge(type: badgeType),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 10,
                                color: isOutside
                                    ? AppColors.danger
                                    : AppColors.success,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  isOutside ? 'Ngoài vùng' : 'Trong vùng',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isOutside
                                        ? AppColors.danger
                                        : AppColors.success,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.bgPage),
        headingTextStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
          letterSpacing: 0.04,
        ),
        columns: const [
          DataColumn(label: Text('STT')),
          DataColumn(label: Text('NHÂN VIÊN')),
          DataColumn(label: Text('PHÒNG BAN')),
          DataColumn(label: Text('NGÀY')),
          DataColumn(label: Text('GIỜ VÀO')),
          DataColumn(label: Text('GIỜ RA')),
          DataColumn(label: Text('TỔNG GIỜ')),
          DataColumn(label: Text('TRẠNG THÁI')),
          DataColumn(label: Text('VỊ TRÍ')),
        ],
        rows: List.generate(
          5,
          (_) => const DataRow(
            cells: [
              DataCell(_SkeletonCell(width: 20)),
              DataCell(_SkeletonCell(width: 150)),
              DataCell(_SkeletonCell(width: 80)),
              DataCell(_SkeletonCell(width: 72)),
              DataCell(_SkeletonCell(width: 48)),
              DataCell(_SkeletonCell(width: 48)),
              DataCell(_SkeletonCell(width: 56)),
              DataCell(_SkeletonCell(width: 80)),
              DataCell(_SkeletonCell(width: 88)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final total = _totalCount;
    final totalPages = _totalPages;
    final start = total == 0 ? 0 : ((_page - 1) * _pageSize) + 1;
    final end = total == 0 ? 0 : (_page * _pageSize).clamp(0, total);
    final pages = <int>{
      1,
      totalPages,
      _page - 1,
      _page,
      _page + 1,
    }.where((p) => p >= 1 && p <= totalPages).toList()..sort();

    return Row(
      children: [
        Text(
          'Hiển thị $start-$end trong $total bản ghi',
          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: _page > 1
              ? () {
                  setState(() => _page -= 1);
                  _reload();
                }
              : null,
          child: const Text('Trước'),
        ),
        const SizedBox(width: 6),
        ...pages.map((page) {
          final active = page == _page;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: SizedBox(
              width: 34,
              height: 34,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor:
                      active ? AppColors.primary : Colors.transparent,
                  foregroundColor:
                      active ? AppColors.surface : AppColors.textMuted,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.iconBoxAll,
                    side: BorderSide(color: AppColors.border),
                  ),
                ),
                onPressed: active
                    ? null
                    : () {
                        setState(() => _page = page);
                        _reload();
                      },
                child: Text('$page'),
              ),
            ),
          );
        }),
        const SizedBox(width: 6),
        OutlinedButton(
          onPressed: _page < totalPages
              ? () {
                  setState(() => _page += 1);
                  _reload();
                }
              : null,
          child: const Text('Sau'),
        ),
        const SizedBox(width: 10),
        DropdownButton<int>(
          value: _pageSize,
          items: const [
            DropdownMenuItem(value: 10, child: Text('10/trang')),
            DropdownMenuItem(value: 20, child: Text('20/trang')),
            DropdownMenuItem(value: 50, child: Text('50/trang')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _pageSize = value;
              _page = 1;
            });
            _reload();
          },
        ),
      ],
    );
  }
}

// ── Private helpers ───────────────────────────────────────────────────────────

class _MapLabel extends StatelessWidget {
  const _MapLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: AppRadius.smallAll,
      ),
      child: Text(
        label,
        style: AppTextStyles.captionBold.copyWith(
          color: AppColors.surface,
          fontSize: 10,
          height: 1.2,
        ),
      ),
    );
  }
}

class _AttendanceHeaderText extends StatelessWidget {
  const _AttendanceHeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.sectionLabel.copyWith(color: AppColors.textMuted),
    );
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
        decoration: const BoxDecoration(
          color: AppColors.border,
          borderRadius: AppRadius.iconBoxAll,
        ),
      ),
    );
  }
}

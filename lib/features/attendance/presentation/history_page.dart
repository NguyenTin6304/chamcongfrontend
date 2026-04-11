import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/responsive.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../data/attendance_api.dart';

class HistoryPageBody extends StatefulWidget {
  const HistoryPageBody({super.key, this.onNavigate});

  final ValueChanged<int>? onNavigate;

  @override
  State<HistoryPageBody> createState() => _HistoryPageBodyState();
}

class _HistoryPageBodyState extends State<HistoryPageBody> {
  final _tokenStorage = TokenStorage();
  final _attendanceApi = const AttendanceApi();

  String? _token;
  late DateTime _selectedMonth;
  late DateTime _selectedDate;
  List<AttendanceLogItem> _monthLogs = [];
  bool _isLoading = true;
  bool _isMonthlyView = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadData();
  }

  // ── Data Loading ──────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final token = await _tokenStorage.getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }
    setState(() => _token = token);
    await _loadMonthData(_selectedMonth, token);
  }

  Future<void> _loadMonthData(DateTime month, String token) async {
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 0);
    try {
      final logs = await _attendanceApi.getMyLogs(token, from: from, to: to);
      if (mounted) setState(() => _monthLogs = logs);
    } catch (_) {
      if (mounted) setState(() => _monthLogs = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Month Navigation ──────────────────────────────────────────────────────

  void _goToPrevMonth() {
    final prev = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    setState(() {
      _selectedMonth = prev;
      _selectedDate = prev;
      _isMonthlyView = false;
      _isLoading = true;
    });
    final token = _token;
    if (token != null) _loadMonthData(prev, token);
  }

  void _goToNextMonth() {
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    setState(() {
      _selectedMonth = next;
      _selectedDate = next;
      _isMonthlyView = false;
      _isLoading = true;
    });
    final token = _token;
    if (token != null) _loadMonthData(next, token);
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Chọn tháng xem lịch sử',
    );
    if (picked == null || !mounted) return;
    final newMonth = DateTime(picked.year, picked.month, 1);
    setState(() {
      _selectedMonth = newMonth;
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _isMonthlyView = false;
      _isLoading = true;
    });
    final token = _token;
    if (token != null) _loadMonthData(newMonth, token);
  }

  // ── Computed ──────────────────────────────────────────────────────────────

  List<AttendanceLogItem> _getLogsForDate(DateTime date) {
    return _monthLogs.where((log) {
      final dt = DateTime.tryParse(log.time)?.toLocal();
      if (dt == null) return false;
      return dt.year == date.year &&
          dt.month == date.month &&
          dt.day == date.day;
    }).toList()
      ..sort((a, b) {
        final ta = DateTime.tryParse(a.time) ?? DateTime(0);
        final tb = DateTime.tryParse(b.time) ?? DateTime(0);
        return ta.compareTo(tb);
      });
  }

  Color? _getDotColorForDate(DateTime date) {
    final logs = _getLogsForDate(date);
    if (logs.isEmpty) return null;

    if (logs.any((l) => l.isOutOfRange)) return AppColors.error;

    final inLogs = logs.where((l) => l.type.toUpperCase() == 'IN').toList();
    if (inLogs.any((l) => l.punctualityStatus?.toUpperCase() == 'LATE')) {
      return AppColors.warning;
    }

    final outLogs = logs.where((l) => l.type.toUpperCase() == 'OUT').toList();
    if (outLogs.any((l) => l.checkoutStatus?.toUpperCase() == 'LATE')) {
      return AppColors.overtime;
    }

    if (inLogs.any(
      (l) =>
          l.punctualityStatus?.toUpperCase() == 'ON_TIME' ||
          l.punctualityStatus?.toUpperCase() == 'EARLY',
    )) {
      return AppColors.success;
    }

    return null;
  }

  double _getPunctualityRate() {
    final dateGroups = <String, List<AttendanceLogItem>>{};
    for (final log in _monthLogs) {
      final dt = DateTime.tryParse(log.time)?.toLocal();
      if (dt == null) continue;
      final key = '${dt.year}-${dt.month}-${dt.day}';
      dateGroups.putIfAbsent(key, () => []).add(log);
    }
    if (dateGroups.isEmpty) return 0;

    int onTimeCount = 0;
    int totalWithIn = 0;
    for (final logs in dateGroups.values) {
      final inLogs = logs.where((l) => l.type.toUpperCase() == 'IN').toList();
      if (inLogs.isEmpty) continue;
      totalWithIn++;
      if (inLogs.any(
        (l) =>
            l.punctualityStatus?.toUpperCase() == 'ON_TIME' ||
            l.punctualityStatus?.toUpperCase() == 'EARLY',
      )) {
        onTimeCount++;
      }
    }
    if (totalWithIn == 0) return 0;
    return onTimeCount / totalWithIn;
  }

  Duration _getTotalWorkDuration() {
    final dateGroups = <String, List<AttendanceLogItem>>{};
    for (final log in _monthLogs) {
      final dt = DateTime.tryParse(log.time)?.toLocal();
      if (dt == null) continue;
      final key = '${dt.year}-${dt.month}-${dt.day}';
      dateGroups.putIfAbsent(key, () => []).add(log);
    }
    var total = Duration.zero;
    for (final logs in dateGroups.values) {
      total += _computePairDuration(logs);
    }
    return total;
  }

  Duration _computePairDuration(List<AttendanceLogItem> logs) {
    final sorted = [...logs]..sort((a, b) {
      final ta = DateTime.tryParse(a.time) ?? DateTime(0);
      final tb = DateTime.tryParse(b.time) ?? DateTime(0);
      return ta.compareTo(tb);
    });
    var total = Duration.zero;
    DateTime? inTime;
    for (final log in sorted) {
      final dt = DateTime.tryParse(log.time)?.toLocal();
      if (dt == null) continue;
      if (log.type.toUpperCase() == 'IN') {
        inTime = dt;
      } else if (log.type.toUpperCase() == 'OUT' && inTime != null) {
        final delta = dt.difference(inTime);
        if (!delta.isNegative) total += delta;
        inTime = null;
      }
    }
    return total;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMobileLayout(context.pagePadding),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Lịch sử chấm công',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.calendar_month_outlined,
              color: AppColors.primary,
            ),
            tooltip: 'Chọn tháng',
            onPressed: _pickMonth,
          ),
        ],
      ),
    );
  }

  // ── Mobile layout (single column) ─────────────────────────────────────────

  Widget _buildMobileLayout(double padding) {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: padding),
      children: [
        const SizedBox(height: 16),
        _buildKpiCards(context),
        const SizedBox(height: 16),
        _buildCalendarCard(),
        const SizedBox(height: 12),
        _buildDotLegend(),
        const SizedBox(height: 20),
        if (_isMonthlyView) ...[
          _buildMonthlyHeader(),
          ..._buildMonthlyItems(),
        ] else ...[
          _buildActivityHeader(),
          ..._buildDayActivityItems(_selectedDate),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  // ── KPI Cards ─────────────────────────────────────────────────────────────

  Widget _buildKpiCards(BuildContext context) {
    final rate = (_getPunctualityRate() * 100).round();
    final totalHours = _getTotalWorkDuration().inHours;
    final gap = context.cardGap;

    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            context: context,
            label: 'TỶ LỆ ĐÚNG GIỜ',
            value: '$rate',
            unit: '%',
            valueColor: AppColors.primary,
            unitColor: AppColors.primary,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          child: _buildKpiCard(
            context: context,
            label: 'TỔNG GIỜ CÔNG',
            value: '$totalHours',
            unit: 'h',
            valueColor: AppColors.textPrimary,
            unitColor: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required BuildContext context,
    required String label,
    required String value,
    required String unit,
    required Color valueColor,
    required Color unitColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: context.kpiSize,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 2),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: unitColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Calendar ──────────────────────────────────────────────────────────────

  Widget _buildCalendarCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildCalendarHeader(),
          const SizedBox(height: 12),
          _buildWeekdayRow(),
          const SizedBox(height: 4),
          _buildDateGrid(),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Tháng ${_selectedMonth.month} ${_selectedMonth.year}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        _navBtn(Icons.chevron_left, _goToPrevMonth),
        const SizedBox(width: 4),
        _navBtn(Icons.chevron_right, _goToNextMonth),
      ],
    );
  }

  Widget _navBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildWeekdayRow() {
    const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return Row(
      children: labels.map((l) {
        return Expanded(
          child: Center(
            child: Text(
              l,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateGrid() {
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final offset = firstDay.weekday - 1; // Mon=0 … Sun=6
    final today = DateTime.now();

    final cells = <Widget>[];

    for (var i = 0; i < offset; i++) {
      cells.add(
        _buildDayCell(
          firstDay.subtract(Duration(days: offset - i)),
          isCurrentMonth: false,
          today: today,
        ),
      );
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(
        _buildDayCell(
          DateTime(_selectedMonth.year, _selectedMonth.month, d),
          isCurrentMonth: true,
          today: today,
        ),
      );
    }
    final trailing = (7 - cells.length % 7) % 7;
    for (var i = 1; i <= trailing; i++) {
      cells.add(
        _buildDayCell(
          DateTime(_selectedMonth.year, _selectedMonth.month + 1, i),
          isCurrentMonth: false,
          today: today,
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.8,
      children: cells,
    );
  }

  Widget _buildDayCell(
    DateTime date, {
    required bool isCurrentMonth,
    required DateTime today,
  }) {
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isSelected = date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day;
    final dot = isCurrentMonth ? _getDotColorForDate(date) : null;

    final Color textColor;
    final Color? circleBg;

    if (!isCurrentMonth) {
      textColor = AppColors.textSecondary.withValues(alpha: 0.35);
      circleBg = null;
    } else if (isSelected) {
      textColor = Colors.white;
      circleBg = AppColors.primary;
    } else if (isToday) {
      textColor = AppColors.primary;
      circleBg = AppColors.primaryLight;
    } else {
      textColor = AppColors.textPrimary;
      circleBg = null;
    }

    return GestureDetector(
      onTap: isCurrentMonth
          ? () => setState(() {
                _selectedDate = date;
                _isMonthlyView = false;
              })
          : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: circleBg != null
                ? BoxDecoration(color: circleBg, shape: BoxShape.circle)
                : null,
            child: Center(
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isSelected || isToday ? FontWeight.w600 : FontWeight.w400,
                  color: textColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 6,
            width: 6,
            child: dot != null
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  // ── Dot Legend ────────────────────────────────────────────────────────────

  Widget _buildDotLegend() {
    return const Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        _LegendDot(color: AppColors.success, label: 'ĐÚNG GIỜ'),
        _LegendDot(color: AppColors.warning, label: 'VÀO MUỘN'),
        _LegendDot(color: AppColors.overtime, label: 'VỀ SỚM'),
        _LegendDot(color: AppColors.overtime, label: 'TĂNG CA'),
        _LegendDot(color: AppColors.error, label: 'NGOẠI LỆ'),
      ],
    );
  }

  // ── Activity Section ──────────────────────────────────────────────────────

  Widget _buildActivityHeader() {
    final d = _selectedDate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'HOẠT ĐỘNG NGÀY ${d.day} THÁNG ${d.month}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isMonthlyView = true),
            child: const Text(
              'Xem cả tháng',
              style: TextStyle(fontSize: 13, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDayActivityItems(DateTime date) {
    final logs = _getLogsForDate(date);
    if (logs.isEmpty) return [_buildEmptyState()];

    final inLogs = logs.where((l) => l.type.toUpperCase() == 'IN').toList();
    final outLogs = logs.where((l) => l.type.toUpperCase() == 'OUT').toList();
    final inLog = inLogs.isEmpty ? null : inLogs.first;
    final outLog = outLogs.isEmpty ? null : outLogs.last;

    final items = <Widget>[];
    if (inLog != null) {
      items.add(_buildCheckinItem(inLog));
      items.add(const SizedBox(height: 8));
    }
    if (outLog != null) {
      items.add(_buildCheckoutItem(outLog));
      items.add(const SizedBox(height: 8));
    }
    if (inLog != null || outLog != null) {
      items.add(_buildSummaryItem(date, inLog, outLog));
    }
    return items;
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: const [
          Icon(Icons.calendar_today_outlined, size: 48, color: AppColors.border),
          SizedBox(height: 12),
          Text(
            'Không có dữ liệu chấm công',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          SizedBox(height: 4),
          Text(
            'Ngày nghỉ hoặc chưa điểm danh',
            style: TextStyle(fontSize: 12, color: AppColors.border),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckinItem(AttendanceLogItem log) {
    final dt = DateTime.tryParse(log.time)?.toLocal();
    final timeStr = dt == null ? '--:--' : DateFormat('HH:mm').format(dt);
    final (Color sc, String sl) = switch (
      log.punctualityStatus?.toUpperCase()
    ) {
      'LATE' => (AppColors.warning, 'VÀO MUỘN'),
      'EARLY' => (AppColors.overtime, 'VỀ SỚM'),
      _ => (AppColors.success, 'ĐÚNG GIỜ'),
    };
    return _buildActivityRow(
      iconBg: AppColors.primaryLight,
      icon: Icons.login,
      iconColor: AppColors.primary,
      title: 'Giờ vào',
      subtitle: timeStr,
      statusColor: sc,
      statusLabel: sl,
      onTap: () => _showDetailSheet(log),
    );
  }

  Widget _buildCheckoutItem(AttendanceLogItem log) {
    final dt = DateTime.tryParse(log.time)?.toLocal();
    final timeStr = dt == null ? '--:--' : DateFormat('HH:mm').format(dt);
    final (Color sc, String sl) = switch (
      log.checkoutStatus?.toUpperCase()
    ) {
      'LATE' => (AppColors.overtime, 'TĂNG CA'),
      'EARLY' => (AppColors.warning, 'VỀ SỚM'),
      _ when log.isOutOfRange => (AppColors.error, 'NGOẠI VI'),
      _ => (AppColors.success, 'ĐÚNG GIỜ'),
    };
    return _buildActivityRow(
      iconBg: AppColors.errorLight,
      icon: Icons.logout,
      iconColor: AppColors.error,
      title: 'Giờ ra',
      subtitle: timeStr,
      statusColor: sc,
      statusLabel: sl,
      onTap: () => _showDetailSheet(log),
    );
  }

  Widget _buildSummaryItem(
    DateTime date,
    AttendanceLogItem? inLog,
    AttendanceLogItem? outLog,
  ) {
    final logs = [?inLog, ?outLog];
    final dur = _computePairDuration(logs);
    final durationText = 'Tổng ${dur.inHours} giờ ${dur.inMinutes % 60} phút';

    final punctuality = inLog?.punctualityStatus?.toUpperCase() ?? '';
    final checkoutSt = outLog?.checkoutStatus?.toUpperCase() ?? '';
    final (Color sc, String sl) = switch (punctuality) {
      'LATE' => (AppColors.warning, 'VÀO MUỘN'),
      'EARLY' when checkoutSt == 'LATE' => (AppColors.overtime, 'TĂNG CA'),
      'EARLY' => (AppColors.overtime, 'VỀ SỚM'),
      _ when checkoutSt == 'LATE' => (AppColors.overtime, 'TĂNG CA'),
      _ => (AppColors.success, 'ĐÚNG GIỜ'),
    };

    return _buildActivityRow(
      iconBg: AppColors.background,
      icon: Icons.calendar_today_outlined,
      iconColor: AppColors.textSecondary,
      title: 'Tổng kết ngày ${date.day}/${date.month}',
      subtitle: durationText,
      statusColor: sc,
      statusLabel: sl,
      onTap: null,
    );
  }

  Widget _buildActivityRow({
    required Color iconBg,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color statusColor,
    required String statusLabel,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 3, height: 30, color: statusColor),
                const SizedBox(width: 6),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Monthly View ──────────────────────────────────────────────────────────

  Widget _buildMonthlyHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'TẤT CẢ THÁNG ${_selectedMonth.month}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isMonthlyView = false),
            child: const Text(
              '← Về lịch',
              style: TextStyle(fontSize: 13, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMonthlyItems() {
    final dateGroups = <String, List<AttendanceLogItem>>{};
    for (final log in _monthLogs) {
      final dt = DateTime.tryParse(log.time)?.toLocal();
      if (dt == null) continue;
      final key =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      dateGroups.putIfAbsent(key, () => []).add(log);
    }
    if (dateGroups.isEmpty) return [_buildEmptyState()];

    final sortedKeys = dateGroups.keys.toList()..sort((a, b) => b.compareTo(a));
    final items = <Widget>[];
    for (final key in sortedKeys) {
      final dt = DateTime.tryParse(key);
      if (dt == null) continue;
      items.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Text(
            'Ngày ${dt.day} tháng ${dt.month}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
      items.addAll(_buildDayActivityItems(dt));
      items.add(const SizedBox(height: 4));
    }
    return items;
  }

  // ── Detail Sheet ──────────────────────────────────────────────────────────

  void _showDetailSheet(AttendanceLogItem log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LogDetailSheet(log: log),
    );
  }
}

// ── Private Widgets ───────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _LogDetailSheet extends StatelessWidget {
  const _LogDetailSheet({required this.log});

  final AttendanceLogItem log;

  @override
  Widget build(BuildContext context) {
    final isIn = log.type.toUpperCase() == 'IN';
    final dt = DateTime.tryParse(log.time)?.toLocal();
    final timeStr = dt == null
        ? '--:--'
        : DateFormat('HH:mm  dd/MM/yyyy').format(dt);
    final statusLabel = isIn
        ? _punctualityLabel(log.punctualityStatus)
        : _checkoutLabel(log.checkoutStatus);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isIn ? 'Chi tiết điểm danh vào' : 'Chi tiết điểm danh ra',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          // Detail rows
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                _detailRow('Thời gian', timeStr),
                _detailRow('Trạng thái', statusLabel),
                if (log.matchedGeofence != null)
                  _detailRow('Địa điểm', log.matchedGeofence!),
                if (log.distanceM != null)
                  _detailRow(
                    'Khoảng cách',
                    '${log.distanceM!.toStringAsFixed(0)}m từ điểm chấm công',
                  ),
                if (log.riskLevel != null &&
                    log.riskLevel!.toUpperCase() != 'LOW' &&
                    log.riskLevel!.isNotEmpty)
                  _detailRow('Mức rủi ro', log.riskLevel!.toUpperCase()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _punctualityLabel(String? s) => switch (s?.toUpperCase()) {
        'ON_TIME' => 'Đúng giờ',
        'LATE' => 'Vào muộn',
        'EARLY' => 'Vào sớm',
        _ => '—',
      };

  String _checkoutLabel(String? s) => switch (s?.toUpperCase()) {
        'ON_TIME' => 'Đúng giờ',
        'LATE' => 'Tăng ca',
        'EARLY' => 'Về sớm',
        _ => '—',
      };
}

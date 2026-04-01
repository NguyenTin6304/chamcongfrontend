part of '../../admin_page.dart';

extension _AttendanceTableX on _AdminPageState {
  Widget _buildAttendanceTableCard() {
    final logs = _logsCurrentPageItems;
    final startIndex = (_logsPage - 1) * _logsPageSize;

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
            if (_loadingDashboardLogs) _buildAttendanceLogsSkeleton(),
            if (!_loadingDashboardLogs && _dashboardLogs.isEmpty)
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
            if (!_loadingDashboardLogs && _dashboardLogs.isNotEmpty)
              logs.length > 20
                  ? _buildAttendanceVirtualizedTable(
                      logs: logs,
                      startIndex: startIndex,
                    )
                  : _buildAttendanceDataTable(
                      logs: logs,
                      startIndex: startIndex,
                    ),
            const SizedBox(height: 12),
            _buildLogsPagination(),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceDataTable({
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
          DataColumn(label: Text('PHÒNG BAN')),
          DataColumn(label: Text('NHÂN VIÊN')),
          DataColumn(label: Text('NGÀY')),
          DataColumn(label: Text('GIỜ VÀO')),
          DataColumn(label: Text('GIỜ RA')),
          DataColumn(label: Text('TỔNG GIỜ')),
          DataColumn(label: Text('TRẠNG THÁI')),
          DataColumn(label: Text('VỊ TRÍ')),
          DataColumn(label: Text('THAO TÁC')),
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
                          color:
                              isOutside ? AppColors.danger : AppColors.success,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOutside ? 'Ngoài vùng' : 'Trong vùng',
                          style: TextStyle(
                            color:
                                isOutside ? AppColors.danger : AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    IconButton(
                      tooltip: 'Xem chi tiết',
                      onPressed: () => _showAttendanceLogDetail(row),
                      icon: const Icon(
                        Icons.remove_red_eye_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              );
            })
            .toList(growable: false),
      ),
    );
  }

  Widget _buildAttendanceVirtualizedTable({
    required List<DashboardAttendanceLogItem> logs,
    required int startIndex,
  }) {
    const rowHeight = 64.0;
    const tableWidth = 1400.0;
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
                  SizedBox(width: 90, child: _AttendanceHeaderText('TỔNG GIỜ')),
                  SizedBox(
                    width: 120,
                    child: _AttendanceHeaderText('TRẠNG THÁI'),
                  ),
                  SizedBox(width: 120, child: _AttendanceHeaderText('VỊ TRÍ')),
                  SizedBox(
                    width: 90,
                    child: _AttendanceHeaderText('THAO TÁC'),
                  ),
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

                  return Container(
                    height: rowHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.border, width: 0.5),
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
                            row.totalHours.trim().isEmpty ? '--' : row.totalHours,
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
                        SizedBox(
                          width: 90,
                          child: IconButton(
                            tooltip: 'Xem chi tiết',
                            onPressed: () => _showAttendanceLogDetail(row),
                            icon: const Icon(
                              Icons.remove_red_eye_outlined,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildAttendanceTableSkeleton() {
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
          DataColumn(label: Text('THAO TÁC')),
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
              DataCell(_SkeletonCell(width: 30)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendancePagination() {
    final total = _logsTotalCount;
    final totalPages = _logsTotalPages;
    final start = total == 0 ? 0 : ((_logsPage - 1) * _logsPageSize) + 1;
    final end = total == 0 ? 0 : (_logsPage * _logsPageSize).clamp(0, total);
    final pages = <int>{
      1,
      totalPages,
      _logsPage - 1,
      _logsPage,
      _logsPage + 1,
    }.where((p) => p >= 1 && p <= totalPages).toList()..sort();

    return Row(
      children: [
        Text(
          'Hiển thị $start-$end trong $total bản ghi',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: _logsPage > 1
              ? () {
                  setState(() {
                    _logsPage -= 1;
                  });
                }
              : null,
          child: const Text('Trước'),
        ),
        const SizedBox(width: 6),
        ...pages.map((page) {
          final active = page == _logsPage;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: SizedBox(
              width: 34,
              height: 34,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: active
                      ? AppColors.primary
                      : Colors.transparent,
                  foregroundColor: active ? Colors.white : AppColors.textMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
                onPressed: active
                    ? null
                    : () {
                        setState(() {
                          _logsPage = page;
                        });
                      },
                child: Text('$page'),
              ),
            ),
          );
        }),
        const SizedBox(width: 6),
        OutlinedButton(
          onPressed: _logsPage < totalPages
              ? () {
                  setState(() {
                    _logsPage += 1;
                  });
                }
              : null,
          child: const Text('Sau'),
        ),
        const SizedBox(width: 10),
        DropdownButton<int>(
          value: _logsPageSize,
          items: const [
            DropdownMenuItem(value: 10, child: Text('10/trang')),
            DropdownMenuItem(value: 20, child: Text('20/trang')),
            DropdownMenuItem(value: 50, child: Text('50/trang')),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() {
              _logsPageSize = value;
              _logsPage = 1;
            });
          },
        ),
      ],
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
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.04,
      ),
    );
  }
}

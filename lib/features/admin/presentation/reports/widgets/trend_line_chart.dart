part of '../../admin_page.dart';

extension _ReportsTrendX on _AdminPageState {
  Widget _buildReportsPageExtracted() {
    final summary = _reportsSummary;
    final totalLogs = _reportsLogs.length;
    final onTimeCount = _countByBadgeType(_reportsLogs, StatusBadgeType.onTime);
    final lateCount = _countByBadgeType(_reportsLogs, StatusBadgeType.late);
    final outOfRangeCount = _countByBadgeType(
      _reportsLogs,
      StatusBadgeType.outOfRange,
    );
    final overtimeCount = _countByBadgeType(
      _reportsLogs,
      StatusBadgeType.overtime,
    );
    final onTimeRate = totalLogs == 0 ? 0.0 : (onTimeCount * 100 / totalLogs);
    final outOfRangeRate = totalLogs == 0
        ? 0.0
        : (outOfRangeCount * 100 / totalLogs);
    final reportsTotalHours = _reportsTotalHours();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportsTypeTabsCard(),
        const SizedBox(height: 16),
        _buildReportsFilterCard(),
        const SizedBox(height: 16),
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
                subText: 'Giờ',
                subColor: AppColors.textMuted,
                icon: Icons.timer_outlined,
                iconColor: AppColors.primary,
                loading: _loadingReportsLogs,
              ),
            ),
            SizedBox(
              width: 220,
              child: KpiCard(
                label: 'Tang ca',
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
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 1040) {
              return Column(
                children: [
                  _buildReportsTrendCard(),
                  const SizedBox(height: 16),
                  _buildReportsStatusDonutCard(
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
                Expanded(flex: 6, child: _buildReportsTrendCard()),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: _buildReportsStatusDonutCard(
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
                  _buildTopLateEmployeesCard(),
                  const SizedBox(height: 16),
                  _buildGroupPerformanceCard(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildTopLateEmployeesCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildGroupPerformanceCard()),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _buildReportsHeatmapCard(),
      ],
    );
  }

  Widget _buildReportsTypeTabsCardExtracted() {
    const tabs = <(String, String)>[
      ('overview', 'Tổng quan'),
      ('employee', 'Theo nhân viên'),
      ('group', 'Theo nhóm'),
      ('time', 'Theo thời gian'),
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tabs
            .map((tab) {
              final active = _reportsType == tab.$1;
              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => _onReportsTypeChanged(tab.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.bgPage,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tab.$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: active ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  Widget _buildReportsFilterCardExtracted() {
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
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
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
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
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
              items: _dashboardGroupItems(),
              onChanged: (value) {
                setState(() {
                  _reportsGroupId = value;
                });
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
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _reportsStatus = value;
                });
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

  Widget _buildReportsTrendCardExtracted() {
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
                  'Xu hướng chấm công theo ngày',
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
                            color:
                                active ? AppColors.primary : AppColors.bgPage,
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
}

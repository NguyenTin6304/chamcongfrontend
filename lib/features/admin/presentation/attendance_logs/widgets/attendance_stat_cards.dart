part of '../../admin_page.dart';

extension _AttendanceStatCardsX on _AdminPageState {
  Widget _buildAttendanceStatCards() {
    final total = _logsTotalCount;
    final onTime = _dashboardLogs
        .where(
          (e) =>
              _badgeTypeForStatus(e.attendanceStatus) == StatusBadgeType.onTime,
        )
        .length;
    final late = _dashboardLogs
        .where(
          (e) =>
              _badgeTypeForStatus(e.attendanceStatus) == StatusBadgeType.late,
        )
        .length;
    final outOfRange = _dashboardLogs
        .where(
          (e) =>
              _badgeTypeForStatus(e.attendanceStatus) ==
              StatusBadgeType.outOfRange,
        )
        .length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 250,
          child: KpiCard(
            label: 'Tổng lượt',
            value: _loadingDashboardLogs ? '--' : _formatThousands(total),
            icon: Icons.fact_check_outlined,
            iconColor: AppColors.primary,
            loading: _loadingDashboardLogs,
          ),
        ),
        SizedBox(
          width: 250,
          child: KpiCard(
            label: 'Đúng giờ',
            value: _loadingDashboardLogs ? '--' : _formatThousands(onTime),
            icon: Icons.check_circle_outline,
            iconColor: AppColors.success,
            valueColor: AppColors.success,
            loading: _loadingDashboardLogs,
          ),
        ),
        SizedBox(
          width: 250,
          child: KpiCard(
            label: 'Vào muộn',
            value: _loadingDashboardLogs ? '--' : _formatThousands(late),
            icon: Icons.schedule,
            iconColor: AppColors.warning,
            valueColor: AppColors.warning,
            loading: _loadingDashboardLogs,
          ),
        ),
        SizedBox(
          width: 250,
          child: KpiCard(
            label: 'Ngoài vùng',
            value: _loadingDashboardLogs ? '--' : _formatThousands(outOfRange),
            icon: Icons.location_off_outlined,
            iconColor: AppColors.danger,
            valueColor: AppColors.danger,
            loading: _loadingDashboardLogs,
          ),
        ),
      ],
    );
  }
}

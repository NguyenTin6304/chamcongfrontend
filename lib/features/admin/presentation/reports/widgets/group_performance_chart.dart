part of '../../admin_page.dart';

extension _GroupPerformanceChartX on _AdminPageState {
  Widget _buildGroupPerformanceCardExtracted() {
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
                      'Đúng giờ ${row.onTime} . Vào muộn ${row.late} . Ngoài vùng ${row.outOfRange}',
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
}

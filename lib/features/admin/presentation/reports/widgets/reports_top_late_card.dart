part of '../reports_tab.dart';

extension _ReportsTopLateCardX on _ReportsTabState {
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
}

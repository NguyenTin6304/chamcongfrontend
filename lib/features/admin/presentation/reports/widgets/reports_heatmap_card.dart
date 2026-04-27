part of '../reports_tab.dart';

extension _ReportsHeatmapCardX on _ReportsTabState {
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

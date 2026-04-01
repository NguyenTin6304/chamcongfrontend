part of '../../admin_page.dart';

extension _StatusDonutChartX on _AdminPageState {
  Widget _buildReportsStatusDonutCardExtracted({
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
        label: 'Tang ca',
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
            final percent = total == 0 ? 0.0 : (segment.count * 100 / total);
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
}

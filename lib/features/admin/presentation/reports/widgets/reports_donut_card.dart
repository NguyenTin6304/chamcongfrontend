part of '../reports_tab.dart';

extension _ReportsDonutCardX on _ReportsTabState {
  Widget _buildStatusDonutCard({
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
        label: 'Tăng ca',
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
            final percent =
                total == 0 ? 0.0 : (segment.count * 100 / total);
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

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({required this.segments, required this.total});

  final List<_DonutSegmentData> segments;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = math.min(size.width, size.height) * 0.17;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: math.min(size.width, size.height) / 2 - stroke / 2,
    );
    final bgPaint = Paint()
      ..color = AppColors.bgPage
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, bgPaint);

    if (total <= 0) return;

    var start = -math.pi / 2;
    for (final segment in segments) {
      if (segment.count <= 0) continue;
      final sweep = (segment.count / total) * math.pi * 2;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    if (oldDelegate.total != total ||
        oldDelegate.segments.length != segments.length) {
      return true;
    }
    for (var i = 0; i < segments.length; i++) {
      if (segments[i].count != oldDelegate.segments[i].count ||
          segments[i].color != oldDelegate.segments[i].color) {
        return true;
      }
    }
    return false;
  }
}

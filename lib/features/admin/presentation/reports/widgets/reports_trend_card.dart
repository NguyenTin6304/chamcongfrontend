part of '../reports_tab.dart';

extension _ReportsTrendCardX on _ReportsTabState {
  Widget _buildTrendCard() {
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
                  'Xu hướng chấm công',
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
                            color: active
                                ? AppColors.primary
                                : AppColors.bgPage,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            tab.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: active
                                  ? AppColors.bgCard
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _ReportsLineChart extends StatelessWidget {
  const _ReportsLineChart({required this.data, required this.loading});

  final List<DashboardWeeklyTrendItem> data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final chartData = loading
        ? const [
            DashboardWeeklyTrendItem(
              day: '1',
              onTime: 40,
              late: 20,
              outOfRange: 10,
            ),
            DashboardWeeklyTrendItem(
              day: '2',
              onTime: 35,
              late: 16,
              outOfRange: 9,
            ),
            DashboardWeeklyTrendItem(
              day: '3',
              onTime: 50,
              late: 14,
              outOfRange: 8,
            ),
            DashboardWeeklyTrendItem(
              day: '4',
              onTime: 42,
              late: 18,
              outOfRange: 10,
            ),
            DashboardWeeklyTrendItem(
              day: '5',
              onTime: 56,
              late: 15,
              outOfRange: 6,
            ),
          ]
        : data;

    if (!loading && chartData.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border, width: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Text(
          'Không có dữ liệu xu hướng.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    final labelStride = chartData.length > 16
        ? 5
        : chartData.length > 10
            ? 2
            : 1;

    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, width: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: CustomPaint(
              painter: _ReportsLineChartPainter(
                data: chartData,
                loading: loading,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: chartData.asMap().entries
              .map(
                (entry) => Expanded(
                  child: Center(
                    child: Text(
                      entry.key % labelStride == 0 ||
                              entry.key == chartData.length - 1
                          ? entry.value.day
                          : '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _ReportsLineChartPainter extends CustomPainter {
  _ReportsLineChartPainter({required this.data, required this.loading});

  final List<DashboardWeeklyTrendItem> data;
  final bool loading;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppColors.bgPage
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = (size.height - 16) * (i / 4) + 8;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (data.isEmpty) return;
    final maxValue = data
        .map((e) => math.max(e.onTime, math.max(e.late, e.outOfRange)))
        .reduce(math.max)
        .toDouble()
        .clamp(10, 1000)
        .toDouble();

    final onTimePoints = <Offset>[];
    final latePoints = <Offset>[];
    final outPoints = <Offset>[];

    final stepX = data.length <= 1 ? 0.0 : size.width / (data.length - 1);
    for (var i = 0; i < data.length; i++) {
      final x = data.length == 1 ? size.width / 2 : stepX * i;
      onTimePoints.add(
        Offset(
          x,
          size.height -
              ((data[i].onTime / maxValue) * (size.height - 16)) -
              8,
        ),
      );
      latePoints.add(
        Offset(
          x,
          size.height -
              ((data[i].late / maxValue) * (size.height - 16)) -
              8,
        ),
      );
      outPoints.add(
        Offset(
          x,
          size.height -
              ((data[i].outOfRange / maxValue) * (size.height - 16)) -
              8,
        ),
      );
    }

    _drawLine(canvas, onTimePoints, AppColors.success, loading);
    _drawLine(canvas, latePoints, AppColors.warning, loading);
    _drawLine(canvas, outPoints, AppColors.danger, loading);
  }

  void _drawLine(
    Canvas canvas,
    List<Offset> points,
    Color color,
    bool loading,
  ) {
    final linePaint = Paint()
      ..color = loading ? color.withValues(alpha: 0.5) : color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = linePaint.color;
    if (points.length == 1) {
      canvas.drawCircle(points.first, 2.5, dotPaint);
      return;
    }
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, linePaint);

    for (final point in points) {
      canvas.drawCircle(point, 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ReportsLineChartPainter oldDelegate) {
    return oldDelegate.loading != loading || oldDelegate.data != data;
  }
}

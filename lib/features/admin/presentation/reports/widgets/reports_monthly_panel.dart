part of '../reports_tab.dart';

extension _ReportsMonthlyPanelX on _ReportsTabState {
  Widget _buildMonthlyExportPanel() {
    final monthLabel =
        '${_monthlyMonth.toString().padLeft(2, '0')}/$_monthlyYear';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Xuất bảng chấm công tháng',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tải file Excel dạng ma trận nhân viên × ngày với đầy đủ ký hiệu V/S/K/L…',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          Wrap(
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
                      onPressed: () => _shiftMonthlyMonth(-1),
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
                      onPressed: () => _shiftMonthlyMonth(1),
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
                  key: ValueKey<int?>(_monthlyGroupId),
                  initialValue: _monthlyGroupId,
                  decoration: _decoration('Nhóm', Icons.group_outlined),
                  items: _groupItems(),
                  onChanged: (value) {
                    // ignore: invalid_use_of_protected_member
                    setState(() => _monthlyGroupId = value);
                  },
                ),
              ),
              ElevatedButton.icon(
                onPressed: _exportingMonthly ? null : _exportMonthlyExcel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.bgCard,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                icon: _exportingMonthly
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.bgCard,
                        ),
                      )
                    : const Icon(Icons.table_chart_outlined),
                label: const Text('Xuất bảng chấm công'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.6),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ký hiệu trong bảng',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _CodeChip(
                      code: 'V',
                      label: 'Đủ công tại VP',
                      color: AppColors.geofenceVpBg,
                    ),
                    _CodeChip(
                      code: 'S',
                      label: 'Đủ công tại Site',
                      color: AppColors.reportSiteLegend,
                    ),
                    _CodeChip(
                      code: 'X',
                      label: 'Đủ công (no geo)',
                      color: AppColors.reportNoGeoLegend,
                    ),
                    _CodeChip(
                      code: '1/2V',
                      label: '< 8h tại VP',
                      color: AppColors.reportHalfLegend,
                    ),
                    _CodeChip(
                      code: '1/2S',
                      label: '< 8h tại Site',
                      color: AppColors.reportHalfLegend,
                    ),
                    _CodeChip(
                      code: '1/2T',
                      label: 'Trễ / thiếu chấm',
                      color: AppColors.reportHalfLegend,
                    ),
                    _CodeChip(
                      code: 'K',
                      label: 'Vắng không lương',
                      color: AppColors.exceptionTabRejectedBorder,
                    ),
                    _CodeChip(
                      code: 'L',
                      label: 'Nghỉ lễ',
                      color: AppColors.reportHolidayLegend,
                    ),
                    _CodeChip(
                      code: 'P',
                      label: 'Nghỉ có lương',
                      color: AppColors.reportPaidLeaveLegend,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeChip extends StatelessWidget {
  const _CodeChip({
    required this.code,
    required this.label,
    required this.color,
  });

  final String code;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black12, width: 0.5),
          ),
          child: Text(
            code,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

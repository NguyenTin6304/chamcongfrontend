part of '../reports_tab.dart';

extension _ReportsFilterCardX on _ReportsTabState {
  Widget _buildFilterCard() {
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
              items: _groupItems(),
              onChanged: (value) {
                // ignore: invalid_use_of_protected_member
                setState(() => _reportsGroupId = value);
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
                if (value == null) return;
                // ignore: invalid_use_of_protected_member
                setState(() => _reportsStatus = value);
                _onReportsFilterChanged();
              },
            ),
          ),
          ElevatedButton.icon(
            onPressed: _exportingReportsExcel ? null : _exportReportsExcel,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.bgCard,
            ),
            icon: _exportingReportsExcel
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.bgCard,
                    ),
                  )
                : const Icon(Icons.download_outlined),
            label: const Text('Xuất báo cáo Excel'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:birdle/core/storage/token_storage.dart';
import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';
import 'package:birdle/features/admin/data/admin_api.dart';

class LeavesTab extends StatefulWidget {
  const LeavesTab({super.key});

  @override
  State<LeavesTab> createState() => _LeavesTabState();
}

class _LeavesTabState extends State<LeavesTab> {
  final _tokenStorage = TokenStorage();
  final _api = const AdminApi();

  String? _token;
  bool _loading = false;
  int _loadSeq = 0;

  String _filterStatus = 'ALL';
  int _filterYear = DateTime.now().year;
  int? _filterMonth;

  List<AdminLeaveRequestItem> _items = const [];
  final Set<int> _actioningIds = {};

  static const List<({String value, String label})> _statusOptions = [
    (value: 'ALL', label: 'Tất cả'),
    (value: 'PENDING', label: 'Chờ duyệt'),
    (value: 'APPROVED', label: 'Đã duyệt'),
    (value: 'REJECTED', label: 'Từ chối'),
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (!mounted) return;
    _token = token;
    await _load();
  }

  Future<void> _load() async {
    if (!mounted || _token == null) return;
    final seq = ++_loadSeq;
    setState(() => _loading = true);
    try {
      final items = await _api.getLeaveRequests(
        token: _token!,
        status: _filterStatus == 'ALL' ? null : _filterStatus,
        year: _filterYear,
        month: _filterMonth,
      );
      if (!mounted || seq != _loadSeq) return;
      setState(() => _items = items);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showApproveDialog(AdminLeaveRequestItem item) async {
    final noteCtrl = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Duyệt đơn nghỉ phép', style: AppTextStyles.sectionTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.employeeName} — ${_dateRangeLabel(item)}',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú (tuỳ chọn)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 255,
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text('Duyệt'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await _doApprove(item.id, noteCtrl.text.trim());
    } finally {
      noteCtrl.dispose();
    }
  }

  Future<void> _showRejectDialog(AdminLeaveRequestItem item) async {
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Từ chối đơn nghỉ phép', style: AppTextStyles.sectionTitle),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.employeeName} — ${_dateRangeLabel(item)}',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Lý do từ chối',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 255,
                  maxLines: 2,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Vui lòng nhập lý do' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huỷ'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(ctx, true);
                }
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Từ chối'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await _doReject(item.id, noteCtrl.text.trim());
    } finally {
      noteCtrl.dispose();
    }
  }

  Future<void> _doApprove(int id, String note) async {
    if (_token == null) return;
    setState(() => _actioningIds.add(id));
    try {
      await _api.approveLeaveRequest(
        token: _token!,
        leaveId: id,
        adminNote: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã duyệt đơn nghỉ phép')),
      );
      await _load();
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _actioningIds.remove(id));
    }
  }

  Future<void> _doReject(int id, String note) async {
    if (_token == null) return;
    setState(() => _actioningIds.add(id));
    try {
      await _api.rejectLeaveRequest(
        token: _token!,
        leaveId: id,
        adminNote: note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã từ chối đơn nghỉ phép')),
      );
      await _load();
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _actioningIds.remove(id));
    }
  }

  String _dateRangeLabel(AdminLeaveRequestItem item) {
    final fmt = DateFormat('dd/MM/yyyy');
    final start = fmt.format(item.startDate);
    final end = fmt.format(item.endDate);
    if (start == end) return start;
    return '$start – $end';
  }

  int _dayCount(AdminLeaveRequestItem item) {
    return item.endDate.difference(item.startDate).inDays + 1;
  }

  int get _total => _items.length;
  int get _pending => _items.where((e) => e.status == 'PENDING').length;
  int get _approved => _items.where((e) => e.status == 'APPROVED').length;
  int get _rejected => _items.where((e) => e.status == 'REJECTED').length;

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0,
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              label: 'Tổng đơn',
              count: _total,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatCard(
              label: 'Chờ duyệt',
              count: _pending,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatCard(
              label: 'Đã duyệt',
              count: _approved,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatCard(
              label: 'Từ chối',
              count: _rejected,
              color: AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterBar(),
        const Divider(height: 1),
        _buildStatsRow(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.event_busy_outlined,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Không có đơn nghỉ phép',
                            style: AppTextStyles.body
                                .copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.bgCard,
                          borderRadius: AppRadius.cardAll,
                          border: Border.all(
                            color: AppColors.border,
                            width: 0.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: AppRadius.cardAll,
                          child: Column(
                            children: [
                              const _TableHeader(),
                              const Divider(height: 1, color: AppColors.border),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: _items.length,
                                  separatorBuilder: (_, _) => const Divider(
                                    height: 1,
                                    color: AppColors.border,
                                  ),
                                  itemBuilder: (_, i) => _TableRow(
                                    item: _items[i],
                                    dayCount: _dayCount(_items[i]),
                                    actioning:
                                        _actioningIds.contains(_items[i].id),
                                    onApprove: () =>
                                        _showApproveDialog(_items[i]),
                                    onReject: () =>
                                        _showRejectDialog(_items[i]),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final years = List.generate(
      3,
      (i) => DateTime.now().year - 1 + i,
    );
    final months = [
      null,
      ...List.generate(12, (i) => i + 1),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Status filter
          SegmentedButton<String>(
            segments: _statusOptions
                .map(
                  (o) => ButtonSegment<String>(
                    value: o.value,
                    label: Text(o.label, style: AppTextStyles.chipText),
                  ),
                )
                .toList(growable: false),
            selected: {_filterStatus},
            onSelectionChanged: (v) {
              setState(() => _filterStatus = v.first);
              _load();
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.primary,
              selectedForegroundColor: AppColors.bgCard,
            ),
          ),
          // Year
          DropdownButton<int>(
            value: _filterYear,
            items: years
                .map(
                  (y) => DropdownMenuItem(
                    value: y,
                    child: Text('Năm $y', style: AppTextStyles.body),
                  ),
                )
                .toList(growable: false),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _filterYear = v);
              _load();
            },
            underline: const SizedBox.shrink(),
          ),
          // Month
          DropdownButton<int?>(
            value: _filterMonth,
            items: months
                .map(
                  (m) => DropdownMenuItem<int?>(
                    value: m,
                    child: Text(
                      m == null ? 'Tất cả tháng' : 'Tháng $m',
                      style: AppTextStyles.body,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (v) {
              setState(() => _filterMonth = v);
              _load();
            },
            underline: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Stat card ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count.toString(),
            style: AppTextStyles.sectionTitle.copyWith(color: color),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ── Table header ─────────────────────────────────────────────────────────────

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.caption.copyWith(color: AppColors.textMuted);
    return Container(
      color: AppColors.bgPage,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('Nhân viên', style: style)),
          Expanded(flex: 2, child: Text('Loại nghỉ', style: style)),
          Expanded(flex: 2, child: Text('Từ ngày', style: style)),
          Expanded(flex: 2, child: Text('Đến ngày', style: style)),
          SizedBox(
            width: 72,
            child: Text('Số ngày', style: style, textAlign: TextAlign.center),
          ),
          Expanded(flex: 2, child: Text('Trạng thái', style: style)),
          SizedBox(
            width: 80,
            child:
                Text('Thao tác', style: style, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

// ── Table row ────────────────────────────────────────────────────────────────

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.item,
    required this.dayCount,
    required this.actioning,
    required this.onApprove,
    required this.onReject,
  });

  final AdminLeaveRequestItem item;
  final int dayCount;
  final bool actioning;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  String get _statusLabel => switch (item.status) {
        'APPROVED' => 'Đã duyệt',
        'REJECTED' => 'Từ chối',
        _ => 'Chờ duyệt',
      };

  Color get _statusColor => switch (item.status) {
        'APPROVED' => AppColors.success,
        'REJECTED' => AppColors.danger,
        _ => AppColors.warning,
      };

  String get _typeLabel =>
      item.leaveType == 'PAID' ? 'Có lương' : 'Không lương';

  Color get _typeColor =>
      item.leaveType == 'PAID' ? AppColors.success : AppColors.warning;

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/'
      '${dt.year}';

  bool get _sameDay =>
      item.startDate.year == item.endDate.year &&
      item.startDate.month == item.endDate.month &&
      item.startDate.day == item.endDate.day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          // Nhân viên
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.employeeName, style: AppTextStyles.bodyBold),
                Text(
                  item.employeeCode,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          // Loại nghỉ
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: _typeColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.badgeAll,
                ),
                child: Text(
                  _typeLabel,
                  style: AppTextStyles.caption.copyWith(color: _typeColor),
                ),
              ),
            ),
          ),
          // Từ ngày
          Expanded(
            flex: 2,
            child: Text(_fmt(item.startDate), style: AppTextStyles.body),
          ),
          // Đến ngày
          Expanded(
            flex: 2,
            child: Text(
              _sameDay ? '—' : _fmt(item.endDate),
              style: AppTextStyles.body.copyWith(
                color:
                    _sameDay ? AppColors.textMuted : AppColors.textPrimary,
              ),
            ),
          ),
          // Số ngày
          SizedBox(
            width: 72,
            child: Text(
              '$dayCount ngày',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          ),
          // Trạng thái
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: _statusColor.withAlpha(26),
                  borderRadius: AppRadius.badgeAll,
                  border: Border.all(color: _statusColor),
                ),
                child: Text(
                  _statusLabel,
                  style:
                      AppTextStyles.badgeLabel.copyWith(color: _statusColor),
                ),
              ),
            ),
          ),
          // Thao tác
          SizedBox(
            width: 80,
            child: item.status != 'PENDING'
                ? const SizedBox.shrink()
                : actioning
                    ? const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: onApprove,
                            icon: const Icon(Icons.check_circle_outline),
                            color: AppColors.success,
                            tooltip: 'Duyệt',
                            iconSize: 20,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            style: IconButton.styleFrom(
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          IconButton(
                            onPressed: onReject,
                            icon: const Icon(Icons.cancel_outlined),
                            color: AppColors.danger,
                            tooltip: 'Từ chối',
                            iconSize: 20,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            style: IconButton.styleFrom(
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

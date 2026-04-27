import 'dart:async';
import 'dart:developer' as dev;

import 'package:flutter/material.dart';

import 'package:birdle/core/storage/token_storage.dart';
import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/core/theme/app_dimensions.dart';
import 'package:birdle/core/theme/app_text_styles.dart';
import 'package:birdle/features/attendance/data/attendance_api.dart';

// ── Helpers ────────────────────────────────────────────────────────────────

String _formatDate(DateTime dt) =>
    '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

String _leaveTypeLabel(String type) =>
    type == 'PAID' ? 'Nghỉ có lương' : 'Nghỉ không lương';

Color _statusColor(String status) => switch (status) {
      'APPROVED' => AppColors.success,
      'REJECTED' => AppColors.danger,
      _ => AppColors.warning,
    };

Color _statusBg(String status) => switch (status) {
      'APPROVED' => AppColors.successLight,
      'REJECTED' => AppColors.errorLight,
      _ => AppColors.warningLight,
    };

String _statusLabel(String status) => switch (status) {
      'APPROVED' => 'Đã duyệt',
      'REJECTED' => 'Từ chối',
      _ => 'Chờ duyệt',
    };

// ── Screen ─────────────────────────────────────────────────────────────────

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends State<LeaveRequestScreen> {
  final _tokenStorage = TokenStorage();
  final _api = const AttendanceApi();

  String? _token;
  List<LeaveRequestItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      unawaited(Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false));
      return;
    }
    setState(() => _token = token);
    await _load(token);
  }

  Future<void> _load(String token) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.getMyLeaveRequests(token: token);
      if (!mounted) return;
      setState(() => _items = items);
    } on Exception catch (e) {
      dev.log('load leaves: $e', name: 'LeaveRequestScreen');
      if (!mounted) return;
      setState(() => _error = 'Không thể tải danh sách đơn nghỉ phép.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm() async {
    final token = _token;
    if (token == null) return;

    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LeaveRequestFormDialog(token: token, api: _api),
    );

    if (submitted == true && mounted) {
      await _load(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Đơn nghỉ phép',
          style: AppTextStyles.headerTitle.copyWith(color: AppColors.textPrimary),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: AppColors.bgCard),
        label: Text(
          'Xin nghỉ',
          style: AppTextStyles.buttonLabel.copyWith(color: AppColors.bgCard),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: AppTextStyles.body.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () { if (_token != null) _load(_token!); },
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_available_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Chưa có đơn nghỉ phép nào.',
              style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Nhấn "Xin nghỉ" để tạo đơn mới.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 100),
      itemCount: _items.length,
      separatorBuilder: (context, i) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, i) => _LeaveCard(item: _items[i]),
    );
  }
}

// ── Card ───────────────────────────────────────────────────────────────────

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.item});
  final LeaveRequestItem item;

  @override
  Widget build(BuildContext context) {
    final sameDay = item.startDate == item.endDate ||
        (item.startDate.year == item.endDate.year &&
            item.startDate.month == item.endDate.month &&
            item.startDate.day == item.endDate.day);

    final dateRange = sameDay
        ? _formatDate(item.startDate)
        : '${_formatDate(item.startDate)} → ${_formatDate(item.endDate)}';

    final statusColor = _statusColor(item.status);
    final statusBg = _statusBg(item.status);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardAll,
        boxShadow: AppShadows.card,
        border: Border(left: BorderSide(color: statusColor, width: 3)),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _leaveTypeLabel(item.leaveType),
                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: AppRadius.badgeAll,
                ),
                child: Text(
                  _statusLabel(item.status),
                  style: AppTextStyles.badgeLabel.copyWith(color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textMuted),
              const SizedBox(width: AppSpacing.xs),
              Text(
                dateRange,
                style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          if (item.reason != null && item.reason!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              item.reason!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (item.adminNote != null && item.adminNote!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: const BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: AppRadius.smallAll,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.admin_panel_settings_outlined, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Admin: ${item.adminNote}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Form dialog ────────────────────────────────────────────────────────────

class _LeaveRequestFormDialog extends StatefulWidget {
  const _LeaveRequestFormDialog({required this.token, required this.api});
  final String token;
  final AttendanceApi api;

  @override
  State<_LeaveRequestFormDialog> createState() => _LeaveRequestFormDialogState();
}

class _LeaveRequestFormDialogState extends State<_LeaveRequestFormDialog> {
  String _leaveType = 'PAID';
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 3)),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      locale: const Locale('vi'),
      helpText: 'Chọn ngày nghỉ',
      cancelText: 'Huỷ',
      confirmText: 'Xác nhận',
    );
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    if (_startDate == null || _endDate == null) {
      setState(() => _error = 'Vui lòng chọn ngày nghỉ.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.api.submitLeaveRequest(
        token: widget.token,
        leaveType: _leaveType,
        startDate: _startDate!,
        endDate: _endDate!,
        reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        final msg = e.toString();
        _error = msg.contains('Exception:') ? msg.replaceFirst('Exception: ', '') : 'Gửi đơn thất bại. Vui lòng thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRange = _startDate != null && _endDate != null;
    final rangeText = hasRange
        ? (_startDate!.day == _endDate!.day &&
                _startDate!.month == _endDate!.month &&
                _startDate!.year == _endDate!.year
            ? _formatDate(_startDate!)
            : '${_formatDate(_startDate!)} → ${_formatDate(_endDate!)}')
        : 'Chưa chọn';

    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Gửi đơn nghỉ phép',
                style: AppTextStyles.headerTitle.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Leave type
              Text('Loại nghỉ', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  _TypeChip(
                    label: 'Nghỉ có lương',
                    selected: _leaveType == 'PAID',
                    color: AppColors.success,
                    onTap: () => setState(() => _leaveType = 'PAID'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _TypeChip(
                    label: 'Nghỉ không lương',
                    selected: _leaveType == 'UNPAID',
                    color: AppColors.warning,
                    onTap: () => setState(() => _leaveType = 'UNPAID'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Date range
              Text('Ngày nghỉ', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              InkWell(
                onTap: _submitting ? null : _pickDateRange,
                borderRadius: AppRadius.smallAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    border: Border.all(color: hasRange ? AppColors.primary : AppColors.border),
                    borderRadius: AppRadius.smallAll,
                    color: AppColors.bgPage,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: hasRange ? AppColors.primary : AppColors.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        rangeText,
                        style: AppTextStyles.body.copyWith(
                          color: hasRange ? AppColors.textPrimary : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Reason
              Text('Lý do (tuỳ chọn)', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _reasonCtrl,
                enabled: !_submitting,
                maxLines: 3,
                maxLength: 500,
                style: AppTextStyles.body,
                decoration: const InputDecoration(
                  hintText: 'Nhập lý do nghỉ phép...',
                  border: OutlineInputBorder(borderRadius: AppRadius.smallAll),
                  contentPadding: EdgeInsets.all(AppSpacing.md),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.error_outline, size: 15, color: AppColors.error),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        _error!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Huỷ'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.md),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bgCard),
                          )
                        : Text(
                            'Gửi đơn',
                            style: AppTextStyles.buttonLabel.copyWith(color: AppColors.bgCard),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.badgeAll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: AppRadius.badgeAll,
        ),
        child: Text(
          label,
          style: AppTextStyles.chipText.copyWith(
            color: selected ? color : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

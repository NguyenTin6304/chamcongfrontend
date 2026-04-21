import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';

import 'package:birdle/core/layout/responsive.dart';
import 'package:birdle/core/theme/app_colors.dart';
import 'package:birdle/features/attendance/data/attendance_api.dart';
import 'package:birdle/features/auth/data/auth_session_service.dart';
import 'package:birdle/widgets/common/deadline_chip.dart';

// ── Top-level helpers ──────────────────────────────────────────────────────

String _exceptionTypeLabel(String type) => switch (type) {
      'AUTO_CLOSED' => 'Tự động đóng ca',
      'MISSED_CHECKOUT' => 'Quên checkout',
      'LOCATION_RISK' || 'SUSPECTED_LOCATION_SPOOF' => 'Bất thường vị trí',
      'LARGE_TIME_DEVIATION' => 'Lệch giờ lớn',
      _ => type,
    };

String _translateSystemNote(String? note) {
  if (note == null || note.trim().isEmpty) return 'Không có thông tin';
  if (note.contains('auto closed session at cross-day cutoff')) {
    return 'Hệ thống tự động đóng ca vì bạn không checkout trước giờ giới hạn';
  }
  if (note.contains('GPS risk detected')) {
    return 'Phát hiện bất thường về vị trí GPS khi chấm công';
  }
  if (note.contains('MISSED_CHECKOUT')) {
    return 'Không có dữ liệu checkout sau giờ làm việc';
  }
  if (note.contains('LARGE_TIME_DEVIATION')) {
    return 'Thời gian chấm công lệch lớn so với ca làm việc';
  }
  return note.split('|').first.split('score=').first.trim();
}

String _formatDateTime(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _formatWorkDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '—';
  final dt = DateTime.tryParse(dateStr);
  if (dt == null) return dateStr;
  const weekdays = [
    '',
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];
  return '${weekdays[dt.weekday]}, '
      '${dt.day.toString().padLeft(2, '0')}/'
      '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

Color _statusBorderColor(String status) => switch (status) {
      'PENDING_EMPLOYEE' => AppColors.warning,
      'PENDING_ADMIN' => AppColors.primary,
      'APPROVED' => AppColors.success,
      'REJECTED' => AppColors.error,
      _ => AppColors.border,
    };

String _friendlyError(Exception e) {
  final msg = e.toString().toLowerCase();
  if (msg.contains('410')) return 'Đã hết hạn giải trình.';
  if (msg.contains('403')) return 'Không có quyền thực hiện.';
  if (msg.contains('401')) return 'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.';
  if (msg.contains('network') || msg.contains('socket') || msg.contains('connection')) {
    return 'Lỗi kết nối mạng. Vui lòng thử lại.';
  }
  return 'Có lỗi xảy ra. Vui lòng thử lại.';
}

Widget? _urgencyBanner(EmployeeExceptionItem item) {
  if (item.status != 'PENDING_EMPLOYEE') return null;
  final deadline = item.effectiveDeadline;
  if (deadline == null) return null;
  final remaining = deadline.difference(DateTime.now());
  if (remaining.isNegative || remaining.inHours >= 24) return null;

  final h = remaining.inHours;
  final m = remaining.inMinutes % 60;
  final label = h > 0 ? 'Còn ${h}g ${m}p để giải trình!' : 'Còn ${m}p để giải trình!';

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(12),
    decoration: const BoxDecoration(
      color: AppColors.badgeBgOutOfRange,
      border: Border(
        left: BorderSide(color: AppColors.error, width: 4),
      ),
    ),
    child: Row(
      children: [
        const Icon(Icons.warning_amber, color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Main Screen ────────────────────────────────────────────────────────────

class EmployeeExceptionsScreen extends StatefulWidget {
  const EmployeeExceptionsScreen({super.key});

  @override
  State<EmployeeExceptionsScreen> createState() =>
      _EmployeeExceptionsScreenState();
}

class _EmployeeExceptionsScreenState
    extends State<EmployeeExceptionsScreen> {
  final _authSession = AuthSessionService();
  final _api = const AttendanceApi();

  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _token;
  List<EmployeeExceptionItem> _exceptions = const [];
  EmployeeExceptionItem? _selected;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final token = await _resolveToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    await _loadExceptions(tokenOverride: token);
  }

  Future<String?> _resolveToken() async {
    try {
      final token = await _authSession.resolveAccessToken();
      if (!mounted) return null;
      if (token == null || token.isEmpty) {
        unawaited(
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false),
        );
        return null;
      }
      _token = token;
      return token;
    } on Exception catch (e) {
      if (!mounted) return null;
      setState(() => _error = _friendlyError(e));
      return null;
    }
  }

  Future<void> _loadExceptions({String? tokenOverride}) async {
    final token = tokenOverride ?? await _resolveToken();
    if (token == null || token.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.listMyExceptions(token);
      if (!mounted) return;
      final selectedId = _selected?.id;
      final nextSelected = selectedId == null
          ? (items.isNotEmpty ? items.first : null)
          : _firstWhereOrNull(items, selectedId);
      setState(() {
        _exceptions = items;
        _selected = nextSelected;
        _loading = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _selectException(EmployeeExceptionItem item) async {
    final token = await _resolveToken();
    if (token == null || token.isEmpty) return;
    setState(() {
      _selected = item;
      _error = null;
    });
    try {
      final detail = await _api.getMyExceptionDetail(
        token: token,
        exceptionId: item.id,
      );
      if (!mounted) return;
      setState(() {
        _selected = detail;
        _exceptions = _exceptions.map((e) => e.id == detail.id ? detail : e).toList();
      });
    } on Exception catch (e) {
      log('Failed to load exception detail: $e', name: 'ExceptionScreen');
    }
  }

  Future<void> _submitExplanation(String text) async {
    final token = await _resolveToken();
    final selected = _selected;
    if (token == null || selected == null || text.isEmpty) return;
    if (!selected.canEditExplanation || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final updated = await _api.submitExceptionExplanation(
        token: token,
        exceptionId: selected.id,
        explanation: text,
      );
      if (!mounted) return;
      setState(() {
        _selected = updated;
        _exceptions = _exceptions.map((e) => e.id == updated.id ? updated : e).toList();
        _submitting = false;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _openDetailPage(EmployeeExceptionItem item) async {
    final token = _token ?? await _resolveToken();
    if (token == null || !mounted) return;
    final updated = await Navigator.push<EmployeeExceptionItem>(
      context,
      MaterialPageRoute(
        builder: (_) => ExceptionDetailPage(item: item, token: token),
      ),
    );
    if (updated != null && mounted) _handleDetailReturn(updated);
  }

  void _handleDetailReturn(EmployeeExceptionItem updated) {
    setState(() {
      _exceptions =
          _exceptions.map((e) => e.id == updated.id ? updated : e).toList();
    });
  }

  EmployeeExceptionItem? _firstWhereOrNull(
    List<EmployeeExceptionItem> items,
    int id,
  ) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Ngoại lệ chấm công',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loading ? null : _loadExceptions,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _exceptions.isEmpty) {
      return _ErrorState(message: _error!, onRetry: _loadExceptions);
    }
    if (_exceptions.isEmpty) {
      return const _EmptyState();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Mobile: full-screen list, tap pushes ExceptionDetailPage
        if (width < AppBreakpoints.mobile) {
          return _ExceptionListBody(
            exceptions: _exceptions,
            selectedId: _selected?.id,
            onSelect: _openDetailPage,
          );
        }

        final detail = _ExceptionDetailPanel(
          key: ValueKey(_selected?.id),
          item: _selected,
          submitting: _submitting,
          error: _error,
          onSubmit: _submitExplanation,
        );

        // Desktop ≥ 900px: 380px list + AnimatedSwitcher detail
        if (width >= AppBreakpoints.tablet) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 380,
                child: _ExceptionListBody(
                  exceptions: _exceptions,
                  selectedId: _selected?.id,
                  onSelect: _selectException,
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: detail,
                ),
              ),
            ],
          );
        }

        // Tablet 600–899px: 300px list + detail
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 300,
              child: _ExceptionListBody(
                exceptions: _exceptions,
                selectedId: _selected?.id,
                onSelect: _selectException,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: detail),
          ],
        );
      },
    );
  }
}

// ── Exception List Body ────────────────────────────────────────────────────

class _ExceptionListBody extends StatelessWidget {
  const _ExceptionListBody({
    required this.exceptions,
    required this.selectedId,
    required this.onSelect,
  });

  final List<EmployeeExceptionItem> exceptions;
  final int? selectedId;
  final void Function(EmployeeExceptionItem) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Text(
            '${exceptions.length} ngoại lệ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: exceptions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = exceptions[index];
              return _ExceptionCard(
                key: ValueKey(item.id),
                item: item,
                isSelected: item.id == selectedId,
                onTap: () => onSelect(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Exception Card ─────────────────────────────────────────────────────────

class _ExceptionCard extends StatelessWidget {
  const _ExceptionCard({
    required this.item,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final EmployeeExceptionItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.15)
                : const Color(0x0F000000),
            blurRadius: isSelected ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: _statusBorderColor(item.status),
                    width: 4,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TypeIconBox(type: item.exceptionType),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _exceptionTypeLabel(item.exceptionType),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              _StatusBadge(status: item.status),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatWorkDate(item.workDate),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (item.status == 'PENDING_EMPLOYEE') ...[
                            const SizedBox(height: 8),
                            DeadlineChip(
                              deadline: item.effectiveDeadline,
                              compact: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Type Icon Box ──────────────────────────────────────────────────────────

class _TypeIconBox extends StatelessWidget {
  const _TypeIconBox({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final (icon, bg, fg) = switch (type) {
      'AUTO_CLOSED' => (Icons.schedule, AppColors.primaryLight, AppColors.primary),
      'MISSED_CHECKOUT' => (Icons.logout, AppColors.warningLight, AppColors.warning),
      'LOCATION_RISK' ||
      'SUSPECTED_LOCATION_SPOOF' =>
        (Icons.gps_off, AppColors.errorLight, AppColors.error),
      'LARGE_TIME_DEVIATION' =>
        (Icons.timer_off, AppColors.overtimeLight, AppColors.overtime),
      _ => (Icons.warning_amber, AppColors.warningLight, AppColors.warning),
    };
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: fg),
    );
  }
}

// ── Exception Detail Panel ─────────────────────────────────────────────────

class _ExceptionDetailPanel extends StatelessWidget {
  const _ExceptionDetailPanel({
    required this.item,
    required this.submitting,
    required this.onSubmit,
    this.error,
    super.key,
  });

  final EmployeeExceptionItem? item;
  final bool submitting;
  final String? error;
  final void Function(String) onSubmit;

  @override
  Widget build(BuildContext context) {
    final current = item;
    if (current == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt_outlined,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'Chọn một ngoại lệ để xem chi tiết',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _TypeIconBox(type: current.exceptionType),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _exceptionTypeLabel(current.exceptionType),
                style: TextStyle(
                  fontSize: context.h1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            _StatusBadge(status: current.status),
          ],
        ),
        const SizedBox(height: 20),
        if (_urgencyBanner(current) case final Widget banner?) ...[
          banner,
          const SizedBox(height: 4),
        ],
        if (context.isDesktop) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _DetailField(
                  label: 'LOẠI NGOẠI LỆ',
                  value: _exceptionTypeLabel(current.exceptionType),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DetailField(
                  label: 'NGÀY CÔNG',
                  value: _formatWorkDate(current.workDate),
                ),
              ),
            ],
          ),
        ] else ...[
          _DetailField(
            label: 'LOẠI NGOẠI LỆ',
            value: _exceptionTypeLabel(current.exceptionType),
          ),
          _DetailField(label: 'NGÀY CÔNG', value: _formatWorkDate(current.workDate)),
        ],
        _DetailField(
          label: 'LÝ DO HỆ THỐNG',
          value: _translateSystemNote(current.note),
        ),
        _DetailField(
          label: 'THỜI ĐIỂM PHÁT HIỆN',
          value: _formatDateTime(current.detectedAt),
        ),
        if (current.status == 'PENDING_EMPLOYEE') _DeadlineField(item: current),
        if (current.adminDecidedAt != null)
          _DetailField(
            label: 'NGÀY ADMIN QUYẾT ĐỊNH',
            value: _formatDateTime(current.adminDecidedAt),
          ),
        if (current.decidedByEmail != null && current.decidedByEmail!.isNotEmpty)
          _DetailField(label: 'NGƯỜI DUYỆT', value: current.decidedByEmail!),
        const SizedBox(height: 8),
        const Divider(color: AppColors.border),
        const SizedBox(height: 16),
        _ExplanationSection(
          key: ValueKey('explanation_${current.id}'),
          item: current,
          submitting: submitting,
          onSubmit: onSubmit,
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
        if (current.timeline.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text(
            'LỊCH SỬ XỬ LÝ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          for (final event in current.timeline)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 8, top: 4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${event.previousStatus ?? '—'} → ${event.nextStatus}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _formatDateTime(event.createdAt),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }
}

// ── Detail Field ───────────────────────────────────────────────────────────

class _DetailField extends StatelessWidget {
  const _DetailField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

// ── Deadline Field ─────────────────────────────────────────────────────────

class _DeadlineField extends StatelessWidget {
  const _DeadlineField({required this.item});

  final EmployeeExceptionItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'HẠN GIẢI TRÌNH',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DeadlineChip(deadline: item.effectiveDeadline),
              Text(
                _formatDateTime(item.effectiveDeadline),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Admin Note Block ───────────────────────────────────────────────────────

class _AdminNoteBlock extends StatelessWidget {
  const _AdminNoteBlock({required this.status, required this.note});

  final String status;
  final String note;

  @override
  Widget build(BuildContext context) {
    final isRejected = status == 'REJECTED';
    final color = isRejected ? AppColors.error : AppColors.success;
    final bgColor = isRejected ? AppColors.errorLight : AppColors.successLight;
    final label = isRejected ? 'LÝ DO TỪ CHỐI' : 'GHI CHÚ ADMIN';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(note, style: TextStyle(fontSize: 14, color: color)),
        ],
      ),
    );
  }
}

// ── Explanation Section ────────────────────────────────────────────────────

class _ExplanationSection extends StatefulWidget {
  const _ExplanationSection({
    required this.item,
    required this.submitting,
    required this.onSubmit,
    super.key,
  });

  final EmployeeExceptionItem item;
  final bool submitting;
  final void Function(String) onSubmit;

  @override
  State<_ExplanationSection> createState() => _ExplanationSectionState();
}

class _ExplanationSectionState extends State<_ExplanationSection> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.item.employeeExplanation ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      widget.item.canEditExplanation &&
      !widget.submitting &&
      _controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final status = item.status;

    if (item.canEditExplanation) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GIẢI TRÌNH CỦA BẠN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            minLines: 4,
            maxLines: 8,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              hintText: 'Nhập giải trình của bạn...',
              hintStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _canSubmit
                  ? () => widget.onSubmit(_controller.text.trim())
                  : null,
              icon: widget.submitting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.surface,
                      ),
                    )
                  : const Icon(Icons.send, size: 18),
              label: Text(widget.submitting ? 'Đang gửi...' : 'Gửi giải trình'),
            ),
          ),
        ],
      );
    }

    final deadlineExpired = status == 'EXPIRED' || item.isDeadlineExpired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (deadlineExpired) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Text(
              'Đã hết hạn giải trình',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (status == 'PENDING_ADMIN' ||
            status == 'APPROVED' ||
            status == 'REJECTED') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GIẢI TRÌNH ĐÃ GỬI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.employeeExplanation?.isNotEmpty == true
                      ? item.employeeExplanation!
                      : '—',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (item.adminNote != null && item.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _AdminNoteBlock(status: status, note: item.adminNote!),
          ],
        ],
      ],
    );
  }
}

// ── Status Badge ───────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  Color get _color => switch (status) {
        'PENDING_EMPLOYEE' => AppColors.warning,
        'PENDING_ADMIN' => AppColors.primary,
        'APPROVED' => AppColors.success,
        'REJECTED' => AppColors.error,
        _ => AppColors.textSecondary,
      };

  Color get _bgColor => switch (status) {
        'PENDING_EMPLOYEE' => AppColors.warningLight,
        'PENDING_ADMIN' => AppColors.primaryLight,
        'APPROVED' => AppColors.successLight,
        'REJECTED' => AppColors.errorLight,
        _ => AppColors.border,
      };

  String get _label => switch (status) {
        'PENDING_EMPLOYEE' => 'Chờ giải trình',
        'PENDING_ADMIN' => 'Chờ admin',
        'APPROVED' => 'Đã duyệt',
        'REJECTED' => 'Từ chối',
        'EXPIRED' => 'Quá hạn',
        _ => status,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 56,
            color: AppColors.textSecondary.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 16),
          const Text(
            'Không có ngoại lệ nào cần xử lý',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Error State ────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: onRetry,
              child: const Text('Tải lại'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Exception Detail Page (mobile route) ──────────────────────────────────

class ExceptionDetailPage extends StatefulWidget {
  const ExceptionDetailPage({
    required this.item,
    required this.token,
    super.key,
  });

  final EmployeeExceptionItem item;
  final String token;

  @override
  State<ExceptionDetailPage> createState() => _ExceptionDetailPageState();
}

class _ExceptionDetailPageState extends State<ExceptionDetailPage> {
  final _api = const AttendanceApi();

  late EmployeeExceptionItem _item;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    unawaited(_loadDetail());
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await _api.getMyExceptionDetail(
        token: widget.token,
        exceptionId: _item.id,
      );
      if (!mounted) return;
      setState(() => _item = detail);
    } on Exception catch (e) {
      log('Failed to reload exception detail: $e', name: 'ExceptionDetailPage');
    }
  }

  Future<void> _submit(String text) async {
    if (!_item.canEditExplanation || _submitting || text.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final updated = await _api.submitExceptionExplanation(
        token: widget.token,
        exceptionId: _item.id,
        explanation: text,
      );
      if (!mounted) return;
      Navigator.pop(context, updated);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Row(
          children: [
            _TypeIconBox(type: _item.exceptionType),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                _exceptionTypeLabel(_item.exceptionType),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          _StatusBadge(status: _item.status),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_urgencyBanner(_item) case final Widget banner?) ...[
            banner,
            const SizedBox(height: 4),
          ],
          _DetailField(
            label: 'LOẠI NGOẠI LỆ',
            value: _exceptionTypeLabel(_item.exceptionType),
          ),
          _DetailField(
            label: 'NGÀY CÔNG',
            value: _formatWorkDate(_item.workDate),
          ),
          _DetailField(
            label: 'LÝ DO HỆ THỐNG',
            value: _translateSystemNote(_item.note),
          ),
          _DetailField(
            label: 'THỜI ĐIỂM PHÁT HIỆN',
            value: _formatDateTime(_item.detectedAt),
          ),
          if (_item.status == 'PENDING_EMPLOYEE') _DeadlineField(item: _item),
          if (_item.adminDecidedAt != null)
            _DetailField(
              label: 'NGÀY ADMIN QUYẾT ĐỊNH',
              value: _formatDateTime(_item.adminDecidedAt),
            ),
          if (_item.decidedByEmail != null &&
              _item.decidedByEmail!.isNotEmpty)
            _DetailField(label: 'NGƯỜI DUYỆT', value: _item.decidedByEmail!),
          const SizedBox(height: 8),
          const Divider(color: AppColors.border),
          const SizedBox(height: 16),
          _ExplanationSection(
            key: ValueKey('detail_explanation_${_item.id}'),
            item: _item,
            submitting: _submitting,
            onSubmit: _submit,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

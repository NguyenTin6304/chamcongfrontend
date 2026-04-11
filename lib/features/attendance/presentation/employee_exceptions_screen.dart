import 'package:flutter/material.dart';

import '../../../core/storage/token_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../data/attendance_api.dart';

class EmployeeExceptionsScreen extends StatefulWidget {
  const EmployeeExceptionsScreen({super.key});

  @override
  State<EmployeeExceptionsScreen> createState() => _EmployeeExceptionsScreenState();
}

class _EmployeeExceptionsScreenState extends State<EmployeeExceptionsScreen> {
  final _tokenStorage = TokenStorage();
  final _api = const AttendanceApi();
  final _explanationController = TextEditingController();

  String? _token;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  List<EmployeeExceptionItem> _exceptions = const [];
  EmployeeExceptionItem? _selected;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _explanationController.dispose();
    super.dispose();
  }

  // ── Logic (unchanged) ────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      setState(() {
        _token = null;
        _loading = false;
        _error = 'Phiên đăng nhập không hợp lệ.';
      });
      return;
    }
    _token = token;
    await _loadExceptions();
  }

  Future<void> _loadExceptions() async {
    final token = _token;
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
      _syncExplanationController();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _selectException(EmployeeExceptionItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    setState(() {
      _selected = item;
      _error = null;
    });
    _syncExplanationController();
    try {
      final detail = await _api.getMyExceptionDetail(
        token: token,
        exceptionId: item.id,
      );
      if (!mounted) return;
      setState(() {
        _selected = detail;
        _exceptions =
            _exceptions.map((e) => e.id == detail.id ? detail : e).toList();
      });
      _syncExplanationController();
    } catch (_) {
      // List data is still useful; detail load can be retried by selecting again.
    }
  }

  Future<void> _submitExplanation() async {
    final token = _token;
    final selected = _selected;
    final explanation = _explanationController.text.trim();
    if (token == null || selected == null || !_canSubmit(selected) || explanation.isEmpty) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final updated = await _api.submitExceptionExplanation(
        token: token,
        exceptionId: selected.id,
        explanation: explanation,
      );
      if (!mounted) return;
      setState(() {
        _selected = updated;
        _exceptions =
            _exceptions.map((e) => e.id == updated.id ? updated : e).toList();
        _submitting = false;
      });
      _syncExplanationController();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = error.toString();
      });
    }
  }

  void _syncExplanationController() {
    final selected = _selected;
    _explanationController.text = selected?.employeeExplanation ?? '';
  }

  bool _canSubmit(EmployeeExceptionItem item) {
    return item.status == 'PENDING_EMPLOYEE' &&
        item.canSubmitExplanation &&
        item.employeeSubmittedAt == null &&
        !_submitting;
  }

  EmployeeExceptionItem? _firstWhereOrNull(List<EmployeeExceptionItem> items, int id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  // FIX 1 — translate raw system note to friendly Vietnamese
  String _translateSystemNote(String? note) {
    if (note == null || note.trim().isEmpty) return 'Không có thông tin';
    if (note.contains('auto closed session at cross-day cutoff')) {
      return 'Hệ thống tự động đóng ca vì bạn không checkout trước 04:00';
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
    // Fallback: strip technical parts
    return note.split('|').first.split('score=').first.trim();
  }

  // FIX 2 — friendly exception type labels
  String _translateExceptionType(String type) {
    return switch (type) {
      'AUTO_CLOSED' => 'Tự động đóng ca',
      'MISSED_CHECKOUT' => 'Quên checkout',
      'LOCATION_RISK' => 'Bất thường vị trí',
      'SUSPECTED_LOCATION_SPOOF' => 'Bất thường vị trí',
      'LARGE_TIME_DEVIATION' => 'Lệch giờ lớn',
      _ => type,
    };
  }

  // FIX 3 — unified date/time formatters
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
    const weekdays = ['', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    return '${weekdays[dt.weekday]}, '
        '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Color _borderColor(String status) {
    return switch (status) {
      'PENDING_EMPLOYEE' => AppColors.warning,
      'PENDING_ADMIN' => AppColors.primary,
      'APPROVED' => AppColors.success,
      'REJECTED' => AppColors.error,
      _ => AppColors.border,
    };
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
        final wide = constraints.maxWidth >= 900;
        final list = _buildExceptionList();
        final detail = _buildDetailPanel();
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 380, child: list),
              const VerticalDivider(width: 1),
              Expanded(child: detail),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(height: 420, child: list),
            const SizedBox(height: 16),
            detail,
          ],
        );
      },
    );
  }

  // FIX 2 — clean list cards
  Widget _buildExceptionList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _exceptions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _exceptions[index];
        final isSelected = item.id == _selected?.id;
        return GestureDetector(
          onTap: () => _selectException(item),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryLight : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : _borderColor(item.status).withValues(alpha: 0.4),
                width: isSelected ? 1.5 : 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _translateExceptionType(item.exceptionType),
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
              ],
            ),
          ),
        );
      },
    );
  }

  // FIX 4, 5, 6 — detail panel
  Widget _buildDetailPanel() {
    final item = _selected;

    // FIX 6 — empty state when nothing selected
    if (item == null) {
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

    final canSubmit = _canSubmit(item);
    final status = item.status;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Header row
        Row(
          children: [
            Expanded(
              child: Text(
                _translateExceptionType(item.exceptionType),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            _StatusBadge(status: status),
          ],
        ),
        const SizedBox(height: 20),

        // FIX 4 — detail fields with visual hierarchy
        _buildDetailField('LOẠI NGOẠI LỆ', _translateExceptionType(item.exceptionType)),
        _buildDetailField('NGÀY CÔNG', _formatWorkDate(item.workDate)),
        _buildDetailField('LÝ DO HỆ THỐNG', _translateSystemNote(item.note)),
        _buildDetailField('THỜI ĐIỂM PHÁT HIỆN', _formatDateTime(item.detectedAt)),
        if (status == 'PENDING_EMPLOYEE')
          _buildDetailField('HẠN GIẢI TRÌNH', _formatDateTime(item.expiresAt)),
        if (item.adminDecidedAt != null)
          _buildDetailField('NGÀY ADMIN QUYẾT ĐỊNH', _formatDateTime(item.adminDecidedAt)),
        if (item.decidedByEmail != null && item.decidedByEmail!.isNotEmpty)
          _buildDetailField('NGƯỜI DUYỆT', item.decidedByEmail!),

        const SizedBox(height: 8),
        const Divider(color: AppColors.border),
        const SizedBox(height: 16),

        // FIX 5 — explanation section
        _buildExplanationSection(item, canSubmit),

        // Error message
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ],

        // Timeline
        if (item.timeline.isNotEmpty) ...[
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
          for (final event in item.timeline)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 10, top: 4),
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

  // FIX 4 — info field with uppercase label above value
  Widget _buildDetailField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
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
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // FIX 5 — explanation section: editable vs read-only
  Widget _buildExplanationSection(EmployeeExceptionItem item, bool canSubmit) {
    final status = item.status;

    if (canSubmit) {
      // Active text area + submit button
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
            controller: _explanationController,
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
              hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              contentPadding: const EdgeInsets.all(14),
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
              onPressed: _explanationController.text.trim().isNotEmpty ? _submitExplanation : null,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send, size: 18),
              label: Text(_submitting ? 'Đang gửi...' : 'Gửi giải trình'),
            ),
          ),
        ],
      );
    }

    // Read-only: show submitted explanation if any
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (status == 'PENDING_ADMIN' || status == 'APPROVED' || status == 'REJECTED') ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
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
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          if (status == 'REJECTED' &&
              item.adminNote != null &&
              item.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.error, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'LÝ DO TỪ CHỐI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.adminNote!,
                    style: const TextStyle(fontSize: 14, color: AppColors.error),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Color _statusColor(String value) {
    return switch (value) {
      'PENDING_EMPLOYEE' => Colors.orange,
      'PENDING_ADMIN' => Colors.blue,
      'APPROVED' => Colors.green,
      'REJECTED' => Colors.red,
      'EXPIRED' => Colors.grey,
      _ => Colors.blueGrey,
    };
  }

  String _statusLabel(String value) {
    return switch (value) {
      'PENDING_EMPLOYEE' => 'Chờ giải trình',
      'PENDING_ADMIN' => 'Chờ admin',
      'APPROVED' => 'Đã duyệt',
      'REJECTED' => 'Từ chối',
      'EXPIRED' => 'Quá hạn',
      _ => value,
    };
  }
}

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
          const SizedBox(height: 14),
          const Text(
            'Không có ngoại lệ nào cần xử lý',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

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
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
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

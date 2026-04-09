import 'package:flutter/material.dart';

import '../../../core/storage/token_storage.dart';
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

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (!mounted) {
      return;
    }
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
    if (token == null || token.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api.listMyExceptions(token);
      if (!mounted) {
        return;
      }
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
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _selectException(EmployeeExceptionItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }
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
      if (!mounted) {
        return;
      }
      setState(() {
        _selected = detail;
        _exceptions = _exceptions.map((entry) => entry.id == detail.id ? detail : entry).toList();
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
      if (!mounted) {
        return;
      }
      setState(() {
        _selected = updated;
        _exceptions = _exceptions.map((entry) => entry.id == updated.id ? updated : entry).toList();
        _submitting = false;
      });
      _syncExplanationController();
    } catch (error) {
      if (!mounted) {
        return;
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ngoại lệ chấm công'),
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

  Widget _buildExceptionList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _exceptions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _exceptions[index];
        final selected = item.id == _selected?.id;
        return Card(
          elevation: selected ? 3 : 1,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            onTap: () => _selectException(item),
            title: Text(_exceptionTypeLabel(item.exceptionType)),
            subtitle: Text('Ngày: ${item.workDate}\n${item.note ?? 'Không có lý do bổ sung'}'),
            isThreeLine: true,
            trailing: _StatusBadge(status: item.status),
          ),
        );
      },
    );
  }

  Widget _buildDetailPanel() {
    final item = _selected;
    if (item == null) {
      return const Center(child: Text('Chọn một ngoại lệ để xem chi tiết.'));
    }
    final canSubmit = _canSubmit(item);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _exceptionTypeLabel(item.exceptionType),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            _StatusBadge(status: item.status),
          ],
        ),
        const SizedBox(height: 16),
        _InfoTile(label: 'Ngày công', value: item.workDate),
        _InfoTile(label: 'Lý do hệ thống', value: item.note ?? 'Không có'),
        _InfoTile(label: 'Thời điểm phát hiện', value: _formatDateTime(item.detectedAt)),
        _InfoTile(label: 'Hạn giải trình', value: _formatDateTime(item.expiresAt)),
        if (item.adminDecidedAt != null) _InfoTile(label: 'Ngày admin quyết định', value: _formatDateTime(item.adminDecidedAt)),
        if (item.decidedByEmail != null) _InfoTile(label: 'Người duyệt', value: item.decidedByEmail!),
        if (item.adminNote != null && item.adminNote!.isNotEmpty) _InfoTile(label: 'Ghi chú admin', value: item.adminNote!),
        const SizedBox(height: 20),
        Text('Giải trình của nhân viên', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _explanationController,
          enabled: canSubmit,
          minLines: 4,
          maxLines: 8,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: canSubmit ? 'Nhập giải trình...' : _disabledExplanationHint(item),
          ),
        ),
        const SizedBox(height: 12),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: canSubmit && _explanationController.text.trim().isNotEmpty ? _submitExplanation : null,
          icon: _submitting
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: Text(_submitting ? 'Đang gửi...' : 'Gửi giải trình'),
        ),
        if (item.timeline.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Lịch sử xử lý', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final event in item.timeline)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(event.eventType),
              subtitle: Text('${event.previousStatus ?? '-'} -> ${event.nextStatus}'),
              trailing: Text(_formatDateTime(event.createdAt)),
            ),
        ],
      ],
    );
  }

  String _disabledExplanationHint(EmployeeExceptionItem item) {
    if (item.employeeSubmittedAt != null) {
      return 'Đã gửi giải trình.';
    }
    if (item.status == 'EXPIRED') {
      return 'Đã qua hạn giải trình.';
    }
    return 'Không thể gửi giải trình ở trạng thái này.';
  }

  EmployeeExceptionItem? _firstWhereOrNull(List<EmployeeExceptionItem> items, int id) {
    for (final item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }
    final local = value.toLocal();
    final date = '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  String _exceptionTypeLabel(String value) {
    return switch (value) {
      'MISSED_CHECKOUT' => 'Thiếu checkout',
      'AUTO_CLOSED' => 'Tự động đóng ca',
      'SUSPECTED_LOCATION_SPOOF' => 'Nghi ngờ giả lập vị trí',
      'LARGE_TIME_DEVIATION' => 'Lệch thời gian lớn',
      _ => value,
    };
  }
}

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
          fontSize: 12,
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
      'PENDING_EMPLOYEE' => 'Chờ giải trình',
      'PENDING_ADMIN' => 'Chờ admin',
      'APPROVED' => 'Đã duyệt',
      'REJECTED' => 'Từ chối',
      'EXPIRED' => 'Quá hạn',
      _ => value,
    };
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Chưa có ngoại lệ cần xử lý.'));
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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tải lại'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/storage/token_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/admin/data/admin_api.dart';
import '../../../../widgets/common/status_badge.dart';
import 'pending_exception_card.dart';

class DateRange {
  const DateRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;
}

class ExceptionHistoryTable extends StatefulWidget {
  const ExceptionHistoryTable({
    required this.statusFilter,
    required this.dateRange,
    required this.groupId,
    super.key,
  });

  final String? statusFilter;
  final DateRange? dateRange;
  final String? groupId;

  @override
  State<ExceptionHistoryTable> createState() => _ExceptionHistoryTableState();
}

class _ExceptionHistoryTableState extends State<ExceptionHistoryTable> {
  final _tokenStorage = TokenStorage();
  final _api = const AdminApi();

  bool _loading = false;
  String? _token;
  List<AttendanceExceptionItem> _allRows = const [];

  int _page = 1;
  int _pageSize = 10;

  List<AttendanceExceptionItem> get _filteredRows {
    final status = (widget.statusFilter ?? 'all').toLowerCase();
    if (status == 'all') {
      return _allRows;
    }
    return _allRows.where((row) {
      final value = row.status.toLowerCase();
      if (status == 'pending') {
        return value.contains('open') || value.contains('pending');
      }
      if (status == 'approved') {
        return value.contains('resolve') || value.contains('approve');
      }
      if (status == 'rejected') {
        return value.contains('reject');
      }
      return true;
    }).toList(growable: false);
  }

  List<AttendanceExceptionItem> get _pageItems {
    final rows = _filteredRows;
    final start = ((_page - 1) * _pageSize).clamp(0, rows.length);
    final end = (_page * _pageSize).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  int get _totalPages {
    final rows = _filteredRows.length;
    if (rows == 0) {
      return 1;
    }
    return (rows / _pageSize).ceil();
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant ExceptionHistoryTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed = oldWidget.statusFilter != widget.statusFilter ||
        oldWidget.groupId != widget.groupId ||
        oldWidget.dateRange?.from != widget.dateRange?.from ||
        oldWidget.dateRange?.to != widget.dateRange?.to;
    if (changed) {
      _page = 1;
      _loadRows();
    }
  }

  Future<void> _bootstrap() async {
    final token = await _tokenStorage.getToken();
    if (!mounted) {
      return;
    }
    setState(() {
      _token = token;
    });
    await _loadRows();
  }

  Future<void> _loadRows() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      final groupId = int.tryParse(widget.groupId ?? '');
      final range = widget.dateRange;
      final rows = await _api.listAttendanceExceptions(
        token: token,
        fromDate: range?.from,
        toDate: range?.to,
        groupId: groupId,
        exceptionType: 'MISSED_CHECKOUT',
        statusFilter: null,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _allRows = rows;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _allRows = const [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Có lỗi xảy ra. Vui lòng thử lại.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  StatusBadgeType _mapBadgeType(String status) {
    final value = status.toLowerCase();
    if (value.contains('open') || value.contains('pending')) {
      return StatusBadgeType.exception;
    }
    if (value.contains('reject')) {
      return StatusBadgeType.outOfRange;
    }
    if (value.contains('resolve') || value.contains('approve')) {
      return StatusBadgeType.onTime;
    }
    return StatusBadgeType.exception;
  }

  ExceptionModel _toModel(AttendanceExceptionItem item) {
    return ExceptionModel(
      id: item.id,
      employeeName: item.fullName,
      employeeCode: item.employeeCode,
      departmentName: item.groupName ?? '--',
      exceptionType: item.exceptionType,
      status: item.status,
      workDate: item.workDate,
      checkInTime: item.sourceCheckinTime == null
          ? '--'
          : DateFormat('HH:mm').format(item.sourceCheckinTime!.toLocal()),
      checkOutTime: item.actualCheckoutTime == null
          ? '--'
          : DateFormat('HH:mm').format(item.actualCheckoutTime!.toLocal()),
      locationLabel: item.exceptionType.toLowerCase().contains('location')
          ? 'Ngoài vùng'
          : 'Trong vùng',
      reason: item.note?.trim().isNotEmpty == true
          ? item.note!.trim()
          : item.exceptionType,
      reviewerName: item.resolvedByEmail ?? '--',
      createdAt: item.createdAt,
    );
  }

  Widget _buildTypePill(String value) {
    final lower = value.toLowerCase();
    final color = lower.contains('location') ? AppColors.danger : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value.replaceAll('_', ' '),
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _pageItems;
    final total = _filteredRows.length;
    final start = total == 0 ? 0 : ((_page - 1) * _pageSize) + 1;
    final end = total == 0 ? 0 : (_page * _pageSize).clamp(0, total);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading)
              _buildSkeletonRows()
            else if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Chưa có dữ liệu',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.bgPage),
                  headingTextStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.04,
                  ),
                  columns: const [
                    DataColumn(label: Text('STT')),
                    DataColumn(label: Text('NHÂN VIÊN')),
                    DataColumn(label: Text('LOẠI NGOẠI LỆ')),
                    DataColumn(label: Text('NGÀY')),
                    DataColumn(label: Text('GIỜ VÀO')),
                    DataColumn(label: Text('GIỜ RA')),
                    DataColumn(label: Text('LÝ DO')),
                    DataColumn(label: Text('TRẠNG THÁI')),
                    DataColumn(label: Text('NGƯỜI DUYỆT')),
                  ],
                  rows: rows.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final model = _toModel(item);
                    return DataRow(
                      cells: [
                        DataCell(Text('${start + index}')),
                        DataCell(
                          Text('${model.employeeName} (${model.employeeCode})'),
                        ),
                        DataCell(_buildTypePill(model.exceptionType)),
                        DataCell(
                          Text(DateFormat('dd/MM/yyyy').format(model.workDate!)),
                        ),
                        DataCell(Text(model.checkInTime)),
                        DataCell(Text(model.checkOutTime)),
                        DataCell(Text(model.reason)),
                        DataCell(StatusBadge(type: _mapBadgeType(item.status))),
                        DataCell(Text(model.reviewerName)),
                      ],
                    );
                  }).toList(growable: false),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Hiển thị $start–$end trong $total ngoại lệ',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: _page > 1
                      ? () {
                          setState(() {
                            _page -= 1;
                          });
                        }
                      : null,
                  child: const Text('Trước'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _page < _totalPages
                      ? () {
                          setState(() {
                            _page += 1;
                          });
                        }
                      : null,
                  child: const Text('Sau'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonRows() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.bgPage),
        columns: const [
          DataColumn(label: Text('STT')),
          DataColumn(label: Text('NHÂN VIÊN')),
          DataColumn(label: Text('LOẠI NGOẠI LỆ')),
          DataColumn(label: Text('NGÀY')),
          DataColumn(label: Text('GIỜ VÀO')),
          DataColumn(label: Text('GIỜ RA')),
          DataColumn(label: Text('LÝ DO')),
          DataColumn(label: Text('TRẠNG THÁI')),
          DataColumn(label: Text('NGƯỜI DUYỆT')),
        ],
        rows: List.generate(
          3,
          (_) => const DataRow(
            cells: [
              DataCell(_SkeletonCell(width: 24)),
              DataCell(_SkeletonCell(width: 140)),
              DataCell(_SkeletonCell(width: 100)),
              DataCell(_SkeletonCell(width: 80)),
              DataCell(_SkeletonCell(width: 56)),
              DataCell(_SkeletonCell(width: 56)),
              DataCell(_SkeletonCell(width: 140)),
              DataCell(_SkeletonCell(width: 84)),
              DataCell(_SkeletonCell(width: 120)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonCell extends StatelessWidget {
  const _SkeletonCell({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}
